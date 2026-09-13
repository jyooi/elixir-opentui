defmodule ElixirOpentui.EventManager do
  @moduledoc """
  Routes input events to the correct handlers based on focus state and hit-testing.

  Pure module — takes events and state, returns new state and list of actions.
  No side effects, no processes. The Runtime calls this to process events.

  Event flow:
  1. Tab/Shift+Tab → focus navigation
  2. Mouse events → hit-test buffer → resolve target → auto-focus on left click
  3. Resize events → resize action
  """

  alias ElixirOpentui.{Focus, Buffer, Element, Input}

  @type state :: %__MODULE__{
          focus: Focus.t(),
          tree: Element.t() | nil,
          buffer: Buffer.t() | nil
        }

  defstruct focus: %Focus{},
            tree: nil,
            buffer: nil

  @doc "Create an event manager from an element tree."
  @spec new(Element.t(), Buffer.t()) :: state()
  def new(tree, buffer) do
    %__MODULE__{focus: Focus.from_tree(tree), tree: tree, buffer: buffer}
  end

  @doc "Update the tree and buffer after a render."
  @spec update(state(), Element.t(), Buffer.t()) :: state()
  def update(state, tree, buffer) do
    %{state | tree: tree, buffer: buffer, focus: Focus.update_tree(state.focus, tree)}
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
        {state, []}
    end
  end

  # --- Mouse event processing ---

  defp process_mouse(state, event) do
    # Hit-test the buffer to find which element was clicked
    hit_id =
      if state.buffer do
        Buffer.get_hit_id(state.buffer, event.x, event.y)
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

    {state, [{:mouse, event}]}
  end
end
