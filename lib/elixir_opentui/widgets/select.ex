defmodule ElixirOpentui.Widgets.Select do
  @moduledoc """
  Selection list widget.

  Displays a list of options, allows arrow/vim key navigation,
  and emits on_change/on_select messages to the parent via `_pending`.

  ## Props (mount-time only)
  - `:options` — list of option strings or maps `%{name: "", description: nil, value: nil}`
  - `:selected` — currently selected index (default 0)
  - `:on_change` — message tag sent as `{tag, selected_index}` on navigation
  - `:on_select` — message tag sent as `{tag, selected_index, option}` on Enter
  - `:id` — element id (required for focus)
  - `:visible_count` — visible rows (default: option count)
  - `:wrap_selection` — wrap at bounds (default: false)
  - `:fast_scroll_step` — Shift+Up/Down step size (default: 5)
  - `:show_description` — show option descriptions (default: false)
  - `:show_scroll_indicator` — show scroll indicator (default: false)
  - `:item_spacing` — blank lines between items (default: 0)
  """

  use ElixirOpentui.Component

  @impl true
  def init(props) do
    options =
      props
      |> Map.get(:options, [])
      |> Enum.map(&normalize_option/1)

    %{
      options: options,
      selected: Map.get(props, :selected, 0),
      scroll_offset: 0,
      on_change: Map.get(props, :on_change),
      on_select: Map.get(props, :on_select),
      id: Map.get(props, :id),
      visible_count: Map.get(props, :visible_count, length(options)),
      wrap_selection: Map.get(props, :wrap_selection, false),
      fast_scroll_step: Map.get(props, :fast_scroll_step, 5),
      show_description: Map.get(props, :show_description, false),
      show_scroll_indicator: Map.get(props, :show_scroll_indicator, false),
      item_spacing: Map.get(props, :item_spacing, 0),
      _pending: []
    }
  end

  @impl true
  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update({:set_options, options}, _event, state) do
    normalized = Enum.map(options, &normalize_option/1)
    %{state | options: normalized, selected: min(state.selected, max(0, length(normalized) - 1))}
  end

  def update({:set_selected, idx}, _event, state) do
    %{state | selected: clamp(idx, 0, length(state.options) - 1)}
    |> emit_change()
  end

  def update(_, _, state), do: state

  @impl true
  def update_props(prev_props, new_props, state) do
    options =
      new_props
      |> Map.get(:options, [])
      |> Enum.map(&normalize_option/1)

    state = %{
      state
      | id: Map.get(new_props, :id),
        on_change: Map.get(new_props, :on_change),
        on_select: Map.get(new_props, :on_select),
        visible_count: Map.get(new_props, :visible_count, length(options)),
        wrap_selection: Map.get(new_props, :wrap_selection, false),
        fast_scroll_step: Map.get(new_props, :fast_scroll_step, 5),
        show_description: Map.get(new_props, :show_description, false),
        show_scroll_indicator: Map.get(new_props, :show_scroll_indicator, false),
        item_spacing: Map.get(new_props, :item_spacing, 0)
    }

    {state, needs_scroll_adjust?} =
      if prop_changed?(prev_props, new_props, :options) do
        selected = min(state.selected, max(0, length(options) - 1))
        {%{state | options: options, selected: selected}, true}
      else
        {state, false}
      end

    {state, needs_scroll_adjust?} =
      if prop_changed?(prev_props, new_props, :selected) do
        selected = clamp(Map.get(new_props, :selected, 0), 0, max(0, length(state.options) - 1))
        {%{state | selected: selected}, true}
      else
        {state, needs_scroll_adjust?}
      end

    if needs_scroll_adjust? or
         prop_changed?(prev_props, new_props, :visible_count) or
         prop_changed?(prev_props, new_props, :show_description) or
         prop_changed?(prev_props, new_props, :item_spacing) do
      adjust_scroll(state)
    else
      state
    end
  end

  @impl true
  def render(state) do
    import ElixirOpentui.View, only: [select: 1]

    select(
      id: state.id,
      options: state.options,
      selected: state.selected,
      scroll_offset: state.scroll_offset,
      show_description: state.show_description,
      show_scroll_indicator: state.show_scroll_indicator,
      item_spacing: state.item_spacing
    )
  end

  # --- Option normalization ---

  defp normalize_option(%{name: _} = opt) do
    Map.merge(%{name: "", description: nil, value: nil}, opt)
  end

  defp normalize_option(string) when is_binary(string) do
    %{name: string, description: nil, value: nil}
  end

  # --- Key handling ---

  defp handle_key(%{key: :up, shift: true}, state) do
    move_by(state, -state.fast_scroll_step)
  end

  defp handle_key(%{key: :down, shift: true}, state) do
    move_by(state, state.fast_scroll_step)
  end

  defp handle_key(%{key: :up}, state), do: move_by(state, -1)
  defp handle_key(%{key: :down}, state), do: move_by(state, 1)

  # Vim keybindings
  defp handle_key(%{key: "k", ctrl: false}, state), do: move_by(state, -1)
  defp handle_key(%{key: "j", ctrl: false}, state), do: move_by(state, 1)

  defp handle_key(%{key: :enter}, state) do
    emit_select(state)
  end

  defp handle_key(%{key: :home}, state) do
    if state.selected == 0 do
      state
    else
      %{state | selected: 0, scroll_offset: 0} |> emit_change()
    end
  end

  defp handle_key(%{key: :end}, state) do
    max_idx = max(0, length(state.options) - 1)

    if state.selected == max_idx do
      state
    else
      %{state | selected: max_idx} |> adjust_scroll() |> emit_change()
    end
  end

  defp handle_key(%{key: :page_up}, state) do
    visible_items = visible_item_count(state)
    move_by(state, -visible_items)
  end

  defp handle_key(%{key: :page_down}, state) do
    visible_items = visible_item_count(state)
    move_by(state, visible_items)
  end

  defp handle_key(_, state), do: state

  # --- Movement ---

  defp move_by(state, delta) do
    max_idx = max(0, length(state.options) - 1)
    new_idx = state.selected + delta

    new_idx =
      if state.wrap_selection do
        cond do
          new_idx < 0 -> max_idx
          new_idx > max_idx -> 0
          true -> new_idx
        end
      else
        clamp(new_idx, 0, max_idx)
      end

    if new_idx == state.selected do
      state
    else
      state = %{state | selected: new_idx}
      state |> adjust_scroll() |> emit_change()
    end
  end

  # --- Helpers ---

  defp rows_per_item(state) do
    base = 1
    desc = if state.show_description, do: 1, else: 0
    base + desc + state.item_spacing
  end

  defp visible_item_count(state) do
    rpi = rows_per_item(state)
    if rpi > 0, do: max(1, div(state.visible_count, rpi)), else: state.visible_count
  end

  defp adjust_scroll(state) do
    vc = visible_item_count(state)

    scroll =
      cond do
        state.selected < state.scroll_offset -> state.selected
        state.selected >= state.scroll_offset + vc -> state.selected - vc + 1
        true -> state.scroll_offset
      end

    %{state | scroll_offset: max(0, scroll)}
  end

  defp emit_change(state) do
    if state.on_change do
      %{state | _pending: [{state.on_change, state.selected} | state._pending]}
    else
      state
    end
  end

  defp emit_select(state) do
    if state.on_select do
      option = Enum.at(state.options, state.selected)
      %{state | _pending: [{state.on_select, state.selected, option} | state._pending]}
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
