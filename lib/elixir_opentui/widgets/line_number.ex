defmodule ElixirOpentui.Widgets.LineNumber do
  @moduledoc """
  Line number gutter widget.

  Displays line numbers alongside content, with support for per-line colors,
  line signs (before/after markers), auto-width calculation, and custom
  line number mappings.

  ## Props
  - `:line_count` — total number of lines (required)
  - `:scroll_offset` — first visible line index (default 0)
  - `:visible_lines` — number of visible lines (default: line_count)
  - `:id` — element id (required for focus)
  - `:min_width` — minimum gutter width in columns (default: 3)
  - `:padding_right` — padding after line number (default: 1)
  - `:line_number_offset` — offset added to line numbers for display (default: 0)
  - `:line_colors` — map of line_index => color for gutter highlighting
  - `:line_signs` — map of line_index => %{before: str, before_color: color, after: str, after_color: color}
  - `:hide_line_numbers` — MapSet of line indices to hide numbers for
  - `:line_numbers` — map of line_index => custom display number
  - `:show_line_numbers` — whether to show the gutter (default: true)
  - `:line_sources` — list mapping visual lines to logical lines (for wrapped text)
  """

  use ElixirOpentui.Component

  alias ElixirOpentui.TextBuffer

  @impl true
  def init(props) do
    %{
      line_count: Map.get(props, :line_count, 0),
      scroll_offset: Map.get(props, :scroll_offset, 0),
      visible_lines: Map.get(props, :visible_lines),
      id: Map.get(props, :id),
      min_width: Map.get(props, :min_width, 3),
      padding_right: Map.get(props, :padding_right, 1),
      line_number_offset: Map.get(props, :line_number_offset, 0),
      line_colors: Map.get(props, :line_colors, %{}),
      line_signs: Map.get(props, :line_signs, %{}),
      hide_line_numbers: Map.get(props, :hide_line_numbers, MapSet.new()),
      line_numbers: Map.get(props, :line_numbers, %{}),
      show_line_numbers: Map.get(props, :show_line_numbers, true),
      line_sources: Map.get(props, :line_sources)
    }
  end

  @impl true
  def update({:set_line_count, count}, _event, state) do
    %{state | line_count: count}
  end

  def update({:set_scroll_offset, offset}, _event, state) do
    %{state | scroll_offset: offset}
  end

  def update({:set_line_colors, colors}, _event, state) do
    %{state | line_colors: colors}
  end

  def update({:set_line_signs, signs}, _event, state) do
    %{state | line_signs: signs}
  end

  def update({:set_line_sign, line, sign}, _event, state) do
    %{state | line_signs: Map.put(state.line_signs, line, sign)}
  end

  def update({:clear_line_sign, line}, _event, state) do
    %{state | line_signs: Map.delete(state.line_signs, line)}
  end

  def update({:set_line_color, line, color}, _event, state) do
    %{state | line_colors: Map.put(state.line_colors, line, color)}
  end

  def update({:clear_line_color, line}, _event, state) do
    %{state | line_colors: Map.delete(state.line_colors, line)}
  end

  def update({:set_hide_line_numbers, set}, _event, state) do
    %{state | hide_line_numbers: set}
  end

  def update({:set_line_numbers, map}, _event, state) do
    %{state | line_numbers: map}
  end

  def update({:set_show_line_numbers, show}, _event, state) do
    %{state | show_line_numbers: show}
  end

  def update({:set_line_number_offset, offset}, _event, state) do
    %{state | line_number_offset: offset}
  end

  def update({:set_line_sources, sources}, _event, state) do
    %{state | line_sources: sources}
  end

  def update(_, _, state), do: state

  @impl true
  def update_props(prev_props, new_props, state) do
    state
    |> sync_prop(prev_props, new_props, :line_count, 0)
    |> sync_prop(prev_props, new_props, :scroll_offset, 0)
    |> sync_prop(prev_props, new_props, :visible_lines, nil)
    |> sync_prop(prev_props, new_props, :id, nil)
    |> sync_prop(prev_props, new_props, :min_width, 3)
    |> sync_prop(prev_props, new_props, :padding_right, 1)
    |> sync_prop(prev_props, new_props, :line_number_offset, 0)
    |> sync_prop(prev_props, new_props, :line_colors, %{})
    |> sync_prop(prev_props, new_props, :line_signs, %{})
    |> sync_prop(prev_props, new_props, :hide_line_numbers, MapSet.new())
    |> sync_prop(prev_props, new_props, :line_numbers, %{})
    |> sync_prop(prev_props, new_props, :show_line_numbers, true)
    |> sync_prop(prev_props, new_props, :line_sources, nil)
  end

  @impl true
  def render(state) do
    import ElixirOpentui.View, only: [line_number: 1]

    line_number(
      id: state.id,
      line_count: state.line_count,
      scroll_offset: state.scroll_offset,
      visible_lines: state.visible_lines || state.line_count,
      min_width: state.min_width,
      padding_right: state.padding_right,
      line_number_offset: state.line_number_offset,
      line_colors: state.line_colors,
      line_signs: state.line_signs,
      hide_line_numbers: state.hide_line_numbers,
      line_numbers: state.line_numbers,
      show_line_numbers: state.show_line_numbers,
      line_sources: state.line_sources,
      gutter_width: calculate_gutter_width(state)
    )
  end

  @doc """
  Calculate the gutter width based on line count and configuration.
  """
  @spec calculate_gutter_width(map()) :: non_neg_integer()
  def calculate_gutter_width(state) do
    max_line_num = max_display_line_number(state)
    digits = if max_line_num > 0, do: digits_count(max_line_num), else: 1
    max_before = max_sign_width(state.line_signs, :before)
    max_after = max_sign_width(state.line_signs, :after)
    base_width = max(state.min_width, digits + state.padding_right + 1)
    base_width + max_before + max_after
  end

  defp max_display_line_number(state) do
    base_max = state.line_count + state.line_number_offset

    custom_max =
      state.line_numbers
      |> Map.values()
      |> Enum.max(fn -> 0 end)

    max(base_max, custom_max)
  end

  defp max_sign_width(signs, field) when field in [:before, :after] do
    signs
    |> Map.values()
    |> Enum.reduce(0, fn sign, acc ->
      text = Map.get(sign, field)

      if text do
        max(acc, TextBuffer.display_width(text))
      else
        acc
      end
    end)
  end

  defp sync_prop(state, prev_props, new_props, key, default) do
    if prop_changed?(prev_props, new_props, key) do
      Map.put(state, key, Map.get(new_props, key, default))
    else
      state
    end
  end

  defp prop_changed?(prev_props, new_props, key) do
    prev_has? = Map.has_key?(prev_props, key)
    new_has? = Map.has_key?(new_props, key)

    prev_has? != new_has? or (prev_has? and Map.get(prev_props, key) != Map.get(new_props, key))
  end

  defp digits_count(n) when n <= 0, do: 1
  defp digits_count(n), do: trunc(:math.log10(n)) + 1
end
