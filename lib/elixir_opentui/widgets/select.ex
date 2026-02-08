defmodule ElixirOpentui.Widgets.Select do
  @moduledoc """
  Selection list widget.

  Displays a list of options, allows arrow key navigation,
  and emits on_change when the selected item changes.

  ## Props
  - `:options` — list of option strings
  - `:selected` — currently selected index (default 0)
  - `:on_change` — message tag sent as `{tag, selected_index}`
  - `:id` — element id (required for focus)
  """

  use ElixirOpentui.Component

  @impl true
  def init(props) do
    options = Map.get(props, :options, [])

    %{
      options: options,
      selected: Map.get(props, :selected, 0),
      scroll_offset: 0,
      on_change: Map.get(props, :on_change),
      id: Map.get(props, :id),
      visible_count: Map.get(props, :visible_count, length(options))
    }
  end

  @impl true
  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update({:set_options, options}, _event, state) do
    %{state | options: options, selected: min(state.selected, max(0, length(options) - 1))}
  end

  def update({:set_selected, idx}, _event, state) do
    %{state | selected: clamp(idx, 0, length(state.options) - 1)}
  end

  def update(_, _, state), do: state

  @impl true
  def render(state) do
    import ElixirOpentui.View

    select(
      id: state.id,
      options: state.options,
      selected: state.selected,
      scroll_offset: state.scroll_offset
    )
  end

  # --- Key handling ---

  defp handle_key(%{key: :up}, state) do
    new_idx = max(0, state.selected - 1)
    state = %{state | selected: new_idx}
    adjust_scroll(state)
  end

  defp handle_key(%{key: :down}, state) do
    max_idx = max(0, length(state.options) - 1)
    new_idx = min(max_idx, state.selected + 1)
    state = %{state | selected: new_idx}
    adjust_scroll(state)
  end

  defp handle_key(%{key: :home}, state) do
    %{state | selected: 0, scroll_offset: 0}
  end

  defp handle_key(%{key: :end}, state) do
    max_idx = max(0, length(state.options) - 1)
    state = %{state | selected: max_idx}
    adjust_scroll(state)
  end

  defp handle_key(%{key: :page_up}, state) do
    new_idx = max(0, state.selected - state.visible_count)
    state = %{state | selected: new_idx}
    adjust_scroll(state)
  end

  defp handle_key(%{key: :page_down}, state) do
    max_idx = max(0, length(state.options) - 1)
    new_idx = min(max_idx, state.selected + state.visible_count)
    state = %{state | selected: new_idx}
    adjust_scroll(state)
  end

  defp handle_key(_, state), do: state

  # --- Helpers ---

  defp adjust_scroll(state) do
    vc = state.visible_count

    scroll =
      cond do
        state.selected < state.scroll_offset -> state.selected
        state.selected >= state.scroll_offset + vc -> state.selected - vc + 1
        true -> state.scroll_offset
      end

    %{state | scroll_offset: max(0, scroll)}
  end

  defp clamp(val, lo, hi), do: max(lo, min(hi, val))
end
