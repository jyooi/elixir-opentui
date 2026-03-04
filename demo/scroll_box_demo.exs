# ScrollBox Interactive Demo
# Run: mix run demo/scroll_box_demo.exs
#
# Scrollable container with 30 lines of content.
# Up/Down arrows, PgUp/PgDown, Home/End, mouse scroll.
# Press Ctrl+C to exit.

defmodule ScrollBoxDemo do
  alias ElixirOpentui.Widgets.ScrollBox
  alias ElixirOpentui.Color

  @viewport_height 12
  @content_lines (for i <- 1..30 do
    prefix = String.pad_leading("#{i}", 2, " ")
    text = case rem(i, 5) do
      1 -> "The quick brown fox jumps over the lazy dog"
      2 -> "Pack my box with five dozen liquor jugs"
      3 -> "How vexingly quick daft zebras jump"
      4 -> "The five boxing wizards jump quickly"
      0 -> "Sphinx of black quartz, judge my vow"
    end
    "#{prefix}. #{text}"
  end)

  def init(cols, rows) do
    %{
      cols: cols,
      rows: rows,
      scroll: ScrollBox.init(%{
        id: :scroller,
        content_height: length(@content_lines),
        height: @viewport_height
      })
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true, meta: false}, _state), do: :quit

  def handle_event(%{type: :key} = event, state) do
    new_scroll = ScrollBox.update(:key, event, state.scroll)
    {:cont, %{state | scroll: new_scroll}}
  end

  def handle_event(%{type: :mouse, action: action} = event, state)
      when action in [:scroll_up, :scroll_down] do
    new_scroll = ScrollBox.update(:mouse, event, state.scroll)
    {:cont, %{state | scroll: new_scroll}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(20, 20, 35)
    fg = Color.rgb(200, 200, 200)
    panel_w = min(56, state.cols - 4)
    content_w = panel_w - 6

    scroll_y = state.scroll.scroll_y
    total = length(@content_lines)
    max_scroll = max(0, total - @viewport_height)

    # Visible content lines
    visible = Enum.slice(@content_lines, scroll_y, @viewport_height)

    # Text-based scrollbar
    scrollbar_chars = build_scrollbar(@viewport_height, scroll_y, total)

    # Pre-compute status strings (must be outside macro block)
    pct = if max_scroll > 0, do: trunc(scroll_y / max_scroll * 100), else: 0
    position_str = " Line #{scroll_y + 1}-#{min(scroll_y + @viewport_height, total)} of #{total} (#{pct}%)"

    bar_w = panel_w - 8
    filled = if max_scroll > 0, do: max(1, trunc(scroll_y / max_scroll * bar_w)), else: 0
    bar_str = " [" <> String.duplicate("=", filled) <> String.duplicate(" ", bar_w - filled) <> "]"

    panel id: :main, title: "ScrollBox Demo", width: panel_w, height: @viewport_height + 10,
          border: true, fg: fg, bg: bg do

      text(content: "Up/Down, PgUp/PgDown, Home/End, Mouse scroll", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "Ctrl+C to quit", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "")

      # Content area with scrollbar
      scroll_box id: :scroller, scroll_y: scroll_y, height: @viewport_height do
        for {line, idx} <- Enum.with_index(visible) do
          sb_char = Enum.at(scrollbar_chars, idx, " ")
          padded = String.pad_trailing(String.slice(line, 0, content_w - 2), content_w - 2)
          text(content: padded <> " " <> sb_char, fg: fg, bg: bg)
        end
      end

      text(content: "")
      text(content: String.duplicate("─", panel_w - 4), fg: Color.rgb(60, 60, 80), bg: bg)
      text(content: position_str, fg: Color.rgb(100, 100, 120), bg: bg)
      text(content: bar_str, fg: Color.rgb(80, 160, 255), bg: bg)
    end
  end

  def focused_id(_state), do: :scroller

  defp build_scrollbar(viewport_h, scroll_y, total) do
    if total <= viewport_h do
      List.duplicate(" ", viewport_h)
    else
      thumb_size = max(1, trunc(viewport_h * viewport_h / total))
      max_scroll = total - viewport_h
      thumb_pos = if max_scroll > 0, do: trunc(scroll_y / max_scroll * (viewport_h - thumb_size)), else: 0

      for i <- 0..(viewport_h - 1) do
        if i >= thumb_pos and i < thumb_pos + thumb_size, do: "█", else: "│"
      end
    end
  end
end

ElixirOpentui.Demo.DemoRunner.run(ScrollBoxDemo)
