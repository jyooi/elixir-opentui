defmodule ElixirOpentui.Accessibility do
  @moduledoc """
  Semantic snapshot of the UI for agent / programmatic consumption.

  Unlike `Buffer` / `NativeBuffer` (which produce cells), this module produces
  a tree of semantic nodes: widget type, id, role, current value, focus state.
  Agents read `snapshot/1` to perceive the UI and dispatch actions through
  `Runtime` to act on it — no ANSI parsing required.

  ## Why this is NOT a BufferBehaviour

  The buffer abstraction is coordinate-based (draw_char, fill_rect). An agent
  tree is structural (parent/child) and semantic (role/value/state). Forcing
  it through BufferBehaviour would throw away the very information agents need.
  """

  alias ElixirOpentui.{Element, Runtime}

  # Widgets a user can interact with. Mirrors Focus.@focusable_types — the
  # authoritative list of "interactive surface" in this framework.
  @focusable_types [:input, :button, :select, :checkbox, :scroll_box, :textarea, :tab_select]

  # Static text nodes carry label context for neighboring inputs.
  @text_types [:text, :label]

  @type role ::
          :textbox
          | :listbox
          | :checkbox
          | :button
          | :scrollable
          | :tablist
          | :text
          | :container

  @type node_snapshot :: %{
          id: term() | nil,
          type: Element.element_type(),
          role: role(),
          focused: boolean(),
          visible: boolean(),
          # Widget-specific fields (value, options, checked, ...) go here.
          # Shape is defined by widget_fields/3 — see TODO below.
          state: map(),
          children: [node_snapshot()]
        }

  @type t :: %{
          focused_id: term() | nil,
          frame: non_neg_integer(),
          root: node_snapshot()
        }

  @typedoc """
  Actions an agent can dispatch via `Runtime.dispatch/2`.

  **Semantic** actions mutate widget state directly (and fire their on_change
  callbacks exactly as a human interaction would). **Key/mouse passthrough**
  actions route through EventManager unchanged — use them to reach widget
  behaviors bound to specific keystrokes (e.g. Ctrl+K in TextInput).
  """
  # Semantic
  @type action ::
          {:focus, term()}
          | {:set_value, term(), String.t()}
          | {:select_index, term(), non_neg_integer()}
          | {:toggle, term()}
          | {:set_checked, term(), boolean()}
          | {:click, term()}
          # Passthrough
          | {:key, map()}
          | {:mouse, map()}
          | {:paste, String.t()}

  @doc """
  Produce a semantic snapshot of the current UI.

  Called with the Runtime's model. Walks the element tree, merges in the
  current component state for each widget, and returns a JSON-serializable map.
  """
  @spec snapshot(Runtime.model()) :: t()
  def snapshot(%{tree: nil}), do: %{focused_id: nil, frame: 0, root: nil}

  def snapshot(%{tree: tree, component_states: states, event_manager: em, frame_count: frame}) do
    focused_id = if em, do: em.focus.focused_id, else: nil

    # If the tree is itself meaningful (e.g. titled panel), walk already emits
    # it as a single node — use it directly as root to avoid double-wrapping.
    # Otherwise, synthesize a root from the tree's own type + the walked children.
    root =
      case walk(tree, states, focused_id) do
        [only] ->
          only

        multiple ->
          %{
            id: tree.id,
            type: tree.type,
            role: role_for(tree.type),
            focused: false,
            visible: true,
            state: widget_fields(tree.type, tree, %{}),
            children: multiple
          }
      end

    %{focused_id: focused_id, frame: frame, root: root}
  end

  @doc """
  Find a node in a snapshot by its id. Convenience for agents that want a
  single widget instead of walking the tree.
  """
  @spec find_node(t() | node_snapshot() | nil, term()) :: node_snapshot() | nil
  def find_node(%{root: root}, id), do: find_node(root, id)
  def find_node(%{id: node_id} = node, id) when node_id == id, do: node

  def find_node(%{children: children}, id) do
    Enum.find_value(children, &find_node(&1, id))
  end

  def find_node(_, _), do: nil

  # Recursive walker. Returns a LIST of nodes so non-meaningful containers
  # can collapse into their parent (spreading their children upward).
  # Scope: focusable widgets + static text + containers with a border_title.
  defp walk(%Element{} = el, states, focused_id) do
    child_nodes = Enum.flat_map(el.children, &walk(&1, states, focused_id))

    if meaningful?(el) do
      [
        %{
          id: el.id,
          type: el.type,
          role: role_for(el.type),
          focused: el.id != nil and el.id == focused_id,
          visible: not Map.get(el.attrs, :hidden, false),
          state: widget_fields(el.type, el, widget_state_for(states, el.id)),
          children: child_nodes
        }
      ]
    else
      child_nodes
    end
  end

  # component_states stores {module, state, props} wrappers keyed by id —
  # unwrap the inner state map here so widget_fields/3 sees widget fields directly.
  defp widget_state_for(states, id) do
    case Map.get(states, id) do
      %{state: s} when is_map(s) -> s
      _ -> %{}
    end
  end

  defp meaningful?(%Element{type: t}) when t in @focusable_types, do: true
  defp meaningful?(%Element{type: t}) when t in @text_types, do: true
  defp meaningful?(%Element{style: %{border_title: title}}) when is_binary(title), do: true
  defp meaningful?(_), do: false

  # Map element type -> ARIA-ish role. Stable vocabulary for agents.
  defp role_for(:input), do: :textbox
  defp role_for(:textarea), do: :textbox
  defp role_for(:select), do: :listbox
  defp role_for(:checkbox), do: :checkbox
  defp role_for(:button), do: :button
  defp role_for(:scroll_box), do: :scrollable
  defp role_for(:tab_select), do: :tablist
  defp role_for(type) when type in [:text, :label], do: :text
  defp role_for(_), do: :container

  # Per-widget public field sets. Decisions locked by AskUserQuestion:
  #   - cursor_pos / scroll_offset omitted (agents work at value level)
  #   - labels resolve via attrs[:label] first, then first child :text
  #   - :select exposes full options list every snapshot

  defp widget_fields(:input, _el, state) do
    %{
      value: Map.get(state, :value, ""),
      placeholder: Map.get(state, :placeholder, "")
    }
  end

  defp widget_fields(:textarea, _el, state) do
    # TextArea stores text in a NIF-backed edit buffer. Extracting the full
    # value requires a NIF call — punt until we confirm the right accessor.
    # For now, expose placeholder + a marker so agents know a value exists.
    %{
      placeholder: Map.get(state, :placeholder, ""),
      value: :via_edit_buffer
    }
  end

  defp widget_fields(:select, _el, state) do
    %{
      options: state |> Map.get(:options, []) |> Enum.map(&option_name/1),
      selected: Map.get(state, :selected, 0)
    }
  end

  defp widget_fields(:checkbox, el, state) do
    %{
      checked: Map.get(state, :checked, false),
      label: label_of(el, state)
    }
  end

  defp widget_fields(:button, el, state) do
    %{label: label_of(el, state)}
  end

  defp widget_fields(:scroll_box, _el, state) do
    %{scroll_top: Map.get(state, :scroll_top, 0)}
  end

  defp widget_fields(:tab_select, _el, state) do
    %{
      tabs: state |> Map.get(:tabs, []) |> Enum.map(&tab_label/1),
      selected: Map.get(state, :selected, 0)
    }
  end

  defp widget_fields(type, el, _state) when type in @text_types do
    %{content: Map.get(el.attrs, :content, "")}
  end

  # Fallback: expose border_title for titled containers; otherwise empty.
  defp widget_fields(_type, %Element{style: %{border_title: title}}, _state)
       when is_binary(title),
       do: %{title: title}

  defp widget_fields(_type, _el, _state), do: %{}

  # attrs[:label] wins; else widget state.label; else first :text child content.
  defp label_of(%Element{attrs: %{label: label}}, _state) when is_binary(label), do: label
  defp label_of(_el, %{label: label}) when is_binary(label) and label != "", do: label

  defp label_of(%Element{children: children}, _state) do
    case Enum.find(children, &match?(%Element{type: t} when t in [:text, :label], &1)) do
      %Element{attrs: %{content: content}} when is_binary(content) -> content
      _ -> ""
    end
  end

  defp option_name(%{name: name}), do: name
  defp option_name(name) when is_binary(name), do: name
  defp option_name(other), do: inspect(other)

  defp tab_label(%{label: label}), do: label
  defp tab_label(label) when is_binary(label), do: label
  defp tab_label(other), do: inspect(other)
end
