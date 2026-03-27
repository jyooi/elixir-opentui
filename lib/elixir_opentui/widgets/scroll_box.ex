defmodule ElixirOpentui.Widgets.ScrollBox do
  @moduledoc """
  Scrollable container widget.

  Wraps children in a scrollable viewport. Handles scroll wheel,
  arrow keys, and Page Up/Down.

  ## Props
  - `:content_height` — total content height (for scroll bounds)
  - `:id` — element id (required for focus)
  """

  use ElixirOpentui.Component

  @impl true
  def init(props) do
    %{
      scroll_y: 0,
      content_height: Map.get(props, :content_height, 0),
      viewport_height: Map.get(props, :height, 10),
      id: Map.get(props, :id)
    }
  end

  @impl true
  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update(:mouse, %{type: :mouse, action: :scroll_up}, state) do
    scroll_by(state, -3)
  end

  def update(:mouse, %{type: :mouse, action: :scroll_down}, state) do
    scroll_by(state, 3)
  end

  def update({:set_scroll, y}, _event, state) do
    %{state | scroll_y: clamp(y, 0, max_scroll(state))}
  end

  def update({:set_content_height, h}, _event, state) do
    new_state = %{state | content_height: h}
    %{new_state | scroll_y: clamp(new_state.scroll_y, 0, max_scroll(new_state))}
  end

  def update(_, _, state), do: state

  @impl true
  def update_props(prev_props, new_props, state) do
    state =
      state
      |> sync_prop(prev_props, new_props, :content_height, :content_height, 0)
      |> sync_prop(prev_props, new_props, :height, :viewport_height, 10)
      |> sync_prop(prev_props, new_props, :id, :id, nil)

    %{state | scroll_y: clamp(state.scroll_y, 0, max_scroll(state))}
  end

  @impl true
  def render(state) do
    import ElixirOpentui.View

    scroll_box(
      id: state.id,
      scroll_y: state.scroll_y,
      height: state.viewport_height
    )
  end

  defp handle_key(%{key: :up}, state), do: scroll_by(state, -1)
  defp handle_key(%{key: :down}, state), do: scroll_by(state, 1)
  defp handle_key(%{key: :page_up}, state), do: scroll_by(state, -state.viewport_height)
  defp handle_key(%{key: :page_down}, state), do: scroll_by(state, state.viewport_height)
  defp handle_key(%{key: :home}, state), do: %{state | scroll_y: 0}
  defp handle_key(%{key: :end}, state), do: %{state | scroll_y: max_scroll(state)}
  defp handle_key(_, state), do: state

  defp scroll_by(state, delta) do
    new_y = clamp(state.scroll_y + delta, 0, max_scroll(state))
    %{state | scroll_y: new_y}
  end

  defp max_scroll(state) do
    max(0, state.content_height - state.viewport_height)
  end

  defp sync_prop(state, prev_props, new_props, prop_key, state_key, default) do
    if prop_changed?(prev_props, new_props, prop_key) do
      Map.put(state, state_key, Map.get(new_props, prop_key, default))
    else
      state
    end
  end

  defp prop_changed?(prev_props, new_props, key) do
    prev_has? = Map.has_key?(prev_props, key)
    new_has? = Map.has_key?(new_props, key)

    prev_has? != new_has? or (prev_has? and Map.get(prev_props, key) != Map.get(new_props, key))
  end

  defp clamp(val, lo, hi), do: max(lo, min(hi, val))
end
