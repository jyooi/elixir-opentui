defmodule ElixirOpentui.Focus do
  @moduledoc """
  Focus management for the element tree.

  Tracks which element is currently focused, supports tab navigation
  (next/prev focusable), and resolves focus targets from mouse clicks
  by walking up the tree to find the nearest focusable ancestor.

  Focus state is a simple value — no process needed. The Runtime
  holds the current focus state in its model.
  """

  alias ElixirOpentui.Element

  @type t :: %__MODULE__{
          focused_id: term() | nil,
          focusable_ids: [term()],
          focus_order: [term()]
        }

  defstruct focused_id: nil, focusable_ids: [], focus_order: []

  @focusable_types [:input, :button, :select, :checkbox, :scroll_box, :textarea, :tab_select]

  @doc "Build focus state from an element tree."
  @spec from_tree(Element.t()) :: t()
  def from_tree(tree) do
    ids = collect_focusable(tree, [])

    %__MODULE__{
      focused_id: nil,
      focusable_ids: ids,
      focus_order: ids
    }
  end

  @doc "Set focus to a specific element id."
  @spec focus(t(), term()) :: t()
  def focus(state, id) do
    if id in state.focusable_ids do
      %{state | focused_id: id}
    else
      state
    end
  end

  @doc "Clear focus."
  @spec blur(t()) :: t()
  def blur(state), do: %{state | focused_id: nil}

  @doc "Move focus to the next focusable element (Tab)."
  @spec focus_next(t()) :: t()
  def focus_next(%{focus_order: []} = state), do: state

  def focus_next(%{focused_id: nil, focus_order: [first | _]} = state) do
    %{state | focused_id: first}
  end

  def focus_next(%{focused_id: current, focus_order: order} = state) do
    case Enum.find_index(order, &(&1 == current)) do
      nil -> %{state | focused_id: hd(order)}
      idx -> %{state | focused_id: Enum.at(order, rem(idx + 1, length(order)))}
    end
  end

  @doc "Move focus to the previous focusable element (Shift+Tab)."
  @spec focus_prev(t()) :: t()
  def focus_prev(%{focus_order: []} = state), do: state

  def focus_prev(%{focused_id: nil, focus_order: order} = state) do
    %{state | focused_id: List.last(order)}
  end

  def focus_prev(%{focused_id: current, focus_order: order} = state) do
    case Enum.find_index(order, &(&1 == current)) do
      nil -> %{state | focused_id: List.last(order)}
      0 -> %{state | focused_id: List.last(order)}
      idx -> %{state | focused_id: Enum.at(order, idx - 1)}
    end
  end

  @doc "Resolve focus target from a hit_id by walking up the tree."
  @spec resolve_focus_target(Element.t(), term()) :: term() | nil
  def resolve_focus_target(tree, hit_id) do
    case find_path_to_id(tree, hit_id) do
      nil ->
        nil

      path ->
        Enum.find(path, fn el ->
          el.type in @focusable_types or
            el.attrs[:focusable] == true
        end)
        |> case do
          nil -> nil
          el -> el.id
        end
    end
  end

  @doc "Update focus state when the tree changes (e.g., elements added/removed)."
  @spec update_tree(t(), Element.t()) :: t()
  def update_tree(state, tree) do
    new_ids = collect_focusable(tree, [])

    focused =
      if state.focused_id in new_ids do
        state.focused_id
      else
        nil
      end

    %{state | focusable_ids: new_ids, focus_order: new_ids, focused_id: focused}
  end

  # --- Private helpers ---

  defp collect_focusable(%Element{} = el, acc) do
    acc =
      if el.id != nil and (el.type in @focusable_types or el.attrs[:focusable] == true) do
        acc ++ [el.id]
      else
        acc
      end

    Enum.reduce(el.children, acc, &collect_focusable/2)
  end

  # Find the path from root to the element with the given id (reversed: element first, root last)
  defp find_path_to_id(%Element{id: id} = el, target_id) when id == target_id do
    [el]
  end

  defp find_path_to_id(%Element{children: children} = el, target_id) do
    Enum.find_value(children, fn child ->
      case find_path_to_id(child, target_id) do
        nil -> nil
        path -> path ++ [el]
      end
    end)
  end
end
