# LineNumber Interactive Demo
# Run: mix run demo/line_number_demo.exs
#
# Line number gutter with colors, signs, and hidden lines.
# Up/Down to scroll, 'n' to toggle line numbers.
# Press Ctrl+C to exit.

defmodule LineNumberDemo do
  alias ElixirOpentui.Color

  @total_lines 40
  @viewport 16

  @sample_lines (for i <- 1..40 do
    case rem(i, 6) do
      1 -> "defmodule Example do"
      2 -> "  def hello(name) do"
      3 -> "    IO.puts(\"Hello, \#{name}!\")"
      4 -> "  end"
      5 -> ""
      0 -> "  # Section #{div(i, 6) + 1}"
    end
  end)

  # Highlight lines 3, 10, 25 with special colors
  @line_colors %{
    2 => Color.rgb(60, 40, 40),
    9 => Color.rgb(40, 60, 40),
    24 => Color.rgb(40, 40, 60)
  }

  # Breakpoint markers on lines 3 and 10
  @line_signs %{
    2 => %{before: "●", before_color: Color.rgb(255, 80, 80)},
    9 => %{before: "▶", before_color: Color.rgb(80, 255, 80)},
    24 => %{before: "◆", before_color: Color.rgb(80, 80, 255)}
  }

  def init(cols, rows) do
    %{
      cols: cols,
      rows: rows,
      scroll_offset: 0,
      show_line_numbers: true
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true}, _state), do: :quit

  def handle_event(%{type: :key, key: "n", ctrl: false, meta: false}, state) do
    {:cont, %{state | show_line_numbers: !state.show_line_numbers}}
  end

  def handle_event(%{type: :key, key: :up}, state) do
    {:cont, %{state | scroll_offset: max(0, state.scroll_offset - 1)}}
  end

  def handle_event(%{type: :key, key: :down}, state) do
    max_scroll = max(0, @total_lines - @viewport)
    {:cont, %{state | scroll_offset: min(max_scroll, state.scroll_offset + 1)}}
  end

  def handle_event(%{type: :key, key: :page_up}, state) do
    {:cont, %{state | scroll_offset: max(0, state.scroll_offset - @viewport)}}
  end

  def handle_event(%{type: :key, key: :page_down}, state) do
    max_scroll = max(0, @total_lines - @viewport)
    {:cont, %{state | scroll_offset: min(max_scroll, state.scroll_offset + @viewport)}}
  end

  def handle_event(%{type: :key, key: :home}, state) do
    {:cont, %{state | scroll_offset: 0}}
  end

  def handle_event(%{type: :key, key: :end}, state) do
    max_scroll = max(0, @total_lines - @viewport)
    {:cont, %{state | scroll_offset: max_scroll}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(20, 20, 35)
    fg = Color.rgb(200, 200, 200)
    panel_w = min(70, state.cols - 4)

    scroll_y = state.scroll_offset
    max_scroll = max(0, @total_lines - @viewport)
    pct = if max_scroll > 0, do: trunc(scroll_y / max_scroll * 100), else: 0
    position_str = "Line #{scroll_y + 1}-#{min(scroll_y + @viewport, @total_lines)} of #{@total_lines} (#{pct}%)"
    toggle_str = "Line numbers: #{if state.show_line_numbers, do: "ON", else: "OFF"}"

    visible = Enum.slice(@sample_lines, scroll_y, @viewport)

    panel id: :main, title: "LineNumber Demo", width: panel_w, height: @viewport + 8,
          border: true, fg: fg, bg: bg do

      text(content: "Up/Down/PgUp/PgDown/Home/End to scroll, 'n' to toggle line numbers", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "Ctrl+C to quit", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "")

      box direction: :row do
        line_number(
          id: :gutter,
          line_count: @total_lines,
          scroll_offset: scroll_y,
          visible_lines: @viewport,
          line_colors: @line_colors,
          line_signs: @line_signs,
          show_line_numbers: state.show_line_numbers
        )

        box do
          for {line, _idx} <- Enum.with_index(visible) do
            text(content: " " <> line, fg: fg, bg: bg)
          end
        end
      end

      text(content: "")
      text(content: String.duplicate("─", panel_w - 4), fg: Color.rgb(60, 60, 80), bg: bg)
      text(content: " #{position_str}", fg: Color.rgb(100, 100, 120), bg: bg)
      text(content: " #{toggle_str}", fg: Color.rgb(80, 160, 255), bg: bg)
    end
  end

  def focused_id(_state), do: :gutter
end

ElixirOpentui.Demo.DemoRunner.run(LineNumberDemo)
