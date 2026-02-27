defmodule ElixirOpentui.Widgets.TabSelect do
  @moduledoc """
  Horizontal tab selection widget.

  Displays a row of tabs with optional underline indicator, description line,
  and scroll arrows. Navigated with left/right arrows or `[`/`]` keys.

  ## Props
  - `:options` — list of tab maps `%{name: "", description: nil, value: nil}` or strings
  - `:selected` — currently selected index (default 0)
  - `:on_change` — message tag sent as `{tag, selected_index}` on navigation
  - `:on_select` — message tag sent as `{tag, selected_index, option}` on Enter
  - `:id` — element id (required for focus)
  - `:tab_width` — width of each tab in columns (default: 20)
  - `:width` — total width of the widget (default: 60)
  - `:wrap_selection` — wrap at bounds (default: false)
  - `:show_description` — show selected tab's description (default: true)
  - `:show_underline` — show underline indicator (default: true)
  - `:show_scroll_arrows` — show scroll arrows when tabs overflow (default: true)
  """

  use ElixirOpentui.Component

  @impl true
  def init(props) do
    options =
      props
      |> Map.get(:options, [])
      |> Enum.map(&normalize_option/1)

    tab_width = Map.get(props, :tab_width, 20)
    width = Map.get(props, :width, 60)
    max_visible = max(1, div(width, tab_width))

    %{
      options: options,
      selected: Map.get(props, :selected, 0),
      scroll_offset: 0,
      on_change: Map.get(props, :on_change),
      on_select: Map.get(props, :on_select),
      id: Map.get(props, :id),
      tab_width: tab_width,
      width: width,
      max_visible_tabs: max_visible,
      wrap_selection: Map.get(props, :wrap_selection, false),
      show_description: Map.get(props, :show_description, true),
      show_underline: Map.get(props, :show_underline, true),
      show_scroll_arrows: Map.get(props, :show_scroll_arrows, true),
      _pending: []
    }
  end

  @impl true
  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update({:set_options, options}, _event, state) do
    normalized = Enum.map(options, &normalize_option/1)

    %{
      state
      | options: normalized,
        selected: min(state.selected, max(0, length(normalized) - 1))
    }
    |> update_scroll_offset()
  end

  def update({:set_selected, idx}, _event, state) do
    new_idx = clamp(idx, 0, max(0, length(state.options) - 1))

    if new_idx == state.selected do
      state
    else
      %{state | selected: new_idx}
      |> update_scroll_offset()
      |> emit_change()
    end
  end

  def update(_, _, state), do: state

  @impl true
  def render(state) do
    alias ElixirOpentui.Element

    Element.new(:tab_select,
      id: state.id,
      options: state.options,
      selected: state.selected,
      scroll_offset: state.scroll_offset,
      tab_width: state.tab_width,
      show_description: state.show_description,
      show_underline: state.show_underline,
      show_scroll_arrows: state.show_scroll_arrows
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

  defp handle_key(%{key: :left}, state), do: move_left(state)
  defp handle_key(%{key: :right}, state), do: move_right(state)
  defp handle_key(%{key: "["}, state), do: move_left(state)
  defp handle_key(%{key: "]"}, state), do: move_right(state)
  defp handle_key(%{key: :enter}, state), do: emit_select(state)
  defp handle_key(_, state), do: state

  # --- Movement ---

  defp move_left(state) do
    max_idx = max(0, length(state.options) - 1)

    new_idx =
      cond do
        state.selected > 0 -> state.selected - 1
        state.wrap_selection and length(state.options) > 0 -> max_idx
        true -> state.selected
      end

    if new_idx == state.selected do
      state
    else
      %{state | selected: new_idx}
      |> update_scroll_offset()
      |> emit_change()
    end
  end

  defp move_right(state) do
    max_idx = max(0, length(state.options) - 1)

    new_idx =
      cond do
        state.selected < max_idx -> state.selected + 1
        state.wrap_selection and length(state.options) > 0 -> 0
        true -> state.selected
      end

    if new_idx == state.selected do
      state
    else
      %{state | selected: new_idx}
      |> update_scroll_offset()
      |> emit_change()
    end
  end

  # --- Scroll offset ---

  defp update_scroll_offset(state) do
    half_visible = div(state.max_visible_tabs, 2)
    max_scroll = max(0, length(state.options) - state.max_visible_tabs)

    new_offset =
      state.selected
      |> Kernel.-(half_visible)
      |> max(0)
      |> min(max_scroll)

    %{state | scroll_offset: new_offset}
  end

  # --- Event emission ---

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

  defp clamp(val, lo, hi), do: max(lo, min(hi, val))
end
