defmodule ElixirOpentui.EventManager do
  @moduledoc """
  Routes input events to the correct handlers based on focus state and hit-testing.

  Pure module — takes events and state, returns new state and list of actions.
  No side effects, no processes. The Runtime calls this to process events.

  Event flow:
  1. Key events → focused element's handler (if any)
  2. Mouse events → hit-test buffer → resolve target → dispatch to handler
  3. Tab/Shift+Tab → focus navigation (built-in)
  4. Global key bindings → checked before focused element
  """

  alias ElixirOpentui.{Focus, Buffer, NativeBuffer, Element, Input}

  @type handler :: (Input.event(), term() -> {:noreply, term()} | {:update, term(), term()})

  @type state :: %__MODULE__{
          focus: Focus.t(),
          handlers: %{optional(term()) => handler()},
          global_handlers: [handler()],
          tree: Element.t() | nil,
          buffer: Buffer.t() | NativeBuffer.t() | nil
        }

  defstruct focus: %Focus{},
            handlers: %{},
            global_handlers: [],
            tree: nil,
            buffer: nil

  @doc "Create an event manager from an element tree."
  @spec new(Element.t(), Buffer.t()) :: state()
  def new(tree, buffer) do
    %__MODULE__{
      focus: Focus.from_tree(tree),
      handlers: %{},
      global_handlers: [],
      tree: tree,
      buffer: buffer
    }
  end

  @doc "Update the tree and buffer after a render."
  @spec update(state(), Element.t(), Buffer.t()) :: state()
  def update(state, tree, buffer) do
    %{state | tree: tree, buffer: buffer, focus: Focus.update_tree(state.focus, tree)}
  end

  @doc "Register an event handler for a specific element id."
  @spec register_handler(state(), term(), handler()) :: state()
  def register_handler(state, id, handler) do
    %{state | handlers: Map.put(state.handlers, id, handler)}
  end

  @doc "Register a global key handler (checked before focused element)."
  @spec register_global_handler(state(), handler()) :: state()
  def register_global_handler(state, handler) do
    %{state | global_handlers: state.global_handlers ++ [handler]}
  end

  @doc """
  Process an input event. Returns {new_state, actions} where actions
  is a list of side effects for the Runtime to execute.
  """
  @spec process(state(), Input.event()) :: {state(), [term()]}
  def process(state, %{type: :key} = event) do
    process_key(state, event)
  end

  def process(state, %{type: :mouse} = event) do
    process_mouse(state, event)
  end

  def process(state, %{type: :paste} = event) do
    dispatch_to_focused(state, event)
  end

  def process(state, %{type: :resize} = event) do
    {state, [{:resize, event.cols, event.rows}]}
  end

  def process(state, _event), do: {state, []}

  # --- Key event processing ---

  defp process_key(state, event) do
    # Tab navigation
    cond do
      event.key == :tab and not event.shift and not event.ctrl ->
        new_focus = Focus.focus_next(state.focus)
        new_state = %{state | focus: new_focus}
        {new_state, [{:focus_changed, new_focus.focused_id}]}

      event.key == :tab and event.shift and not event.ctrl ->
        new_focus = Focus.focus_prev(state.focus)
        new_state = %{state | focus: new_focus}
        {new_state, [{:focus_changed, new_focus.focused_id}]}

      true ->
        # Try global handlers first
        case try_global_handlers(state, event) do
          {:handled, state, actions} ->
            {state, actions}

          :not_handled ->
            dispatch_to_focused(state, event)
        end
    end
  end

  # --- Mouse event processing ---

  defp process_mouse(state, event) do
    # Hit-test the buffer to find which element was clicked
    hit_id =
      if state.buffer do
        buffer_mod(state.buffer).get_hit_id(state.buffer, event.x, event.y)
      end

    # Auto-focus on left click
    state =
      if event.action == :press and event.button == :left and hit_id != nil do
        case Focus.resolve_focus_target(state.tree, hit_id) do
          nil -> state
          target_id -> %{state | focus: Focus.focus(state.focus, target_id)}
        end
      else
        state
      end

    # Dispatch to the hit element's handler
    if hit_id && Map.has_key?(state.handlers, hit_id) do
      handler = state.handlers[hit_id]
      dispatch_handler(state, handler, event)
    else
      {state, [{:mouse, event}]}
    end
  end

  # --- Dispatch helpers ---

  defp dispatch_to_focused(state, event) do
    case state.focus.focused_id do
      nil ->
        {state, []}

      id ->
        case Map.get(state.handlers, id) do
          nil -> {state, []}
          handler -> dispatch_handler(state, handler, event)
        end
    end
  end

  defp dispatch_handler(state, handler, event) do
    case handler.(event, state) do
      {:noreply, new_state} -> {new_state, []}
      {:update, new_state, msg} -> {new_state, [{:update, msg}]}
      _ -> {state, []}
    end
  end

  defp try_global_handlers(state, event) do
    Enum.reduce_while(state.global_handlers, :not_handled, fn handler, _acc ->
      case handler.(event, state) do
        {:noreply, new_state} -> {:halt, {:handled, new_state, []}}
        {:update, new_state, msg} -> {:halt, {:handled, new_state, [{:update, msg}]}}
        _ -> {:cont, :not_handled}
      end
    end)
  end

  defp buffer_mod(%Buffer{}), do: Buffer
  defp buffer_mod(%NativeBuffer{}), do: NativeBuffer
end
