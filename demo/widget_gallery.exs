# Widget Gallery — All 4 Widgets in One View
# Run: mix run demo/widget_gallery.exs
#
# Tab to navigate between widgets, interact with each.
# Press Ctrl+C to exit.

defmodule WidgetGallery do
  alias ElixirOpentui.Widgets.{TextInput, Checkbox, Select, ScrollBox}
  alias ElixirOpentui.Color

  # Focus order: text_input -> select -> checkbox_1 -> checkbox_2 -> scroll_box
  @focus_order [:text_input, :lang_select, :check_dark, :check_notify, :scroller]
  @focus_labels %{
    text_input: "TextInput",
    lang_select: "Select",
    check_dark: "Checkbox (Dark mode)",
    check_notify: "Checkbox (Notifications)",
    scroller: "ScrollBox"
  }

  @scroll_content (for i <- 1..20 do
    "Line #{String.pad_leading("#{i}", 2)}: " <> Enum.at([
      "The quick brown fox jumps",
      "Pack my box with five dozen",
      "How vexingly quick daft zebras",
      "The five boxing wizards jump"
    ], rem(i - 1, 4))
  end)

  @languages ["Elixir", "Rust", "Zig", "TypeScript", "Python", "Go"]
  @scroll_viewport 5

  def init(cols, rows) do
    %{
      cols: cols,
      rows: rows,
      focus_idx: 0,
      text_input: TextInput.init(%{id: :text_input, placeholder: "Type something...", width: min(36, cols - 14)}),
      select: Select.init(%{id: :lang_select, options: @languages, selected: 0, visible_count: 4}),
      check_dark: Checkbox.init(%{id: :check_dark, label: "Dark mode", checked: true}),
      check_notify: Checkbox.init(%{id: :check_notify, label: "Notifications", checked: false}),
      scroll: ScrollBox.init(%{id: :scroller, content_height: length(@scroll_content), height: @scroll_viewport})
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true}, _state), do: :quit

  def handle_event(%{type: :key, key: :tab, shift: true}, state) do
    new_idx = rem(state.focus_idx - 1 + length(@focus_order), length(@focus_order))
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key, key: :tab}, state) do
    new_idx = rem(state.focus_idx + 1, length(@focus_order))
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key} = event, state) do
    focused = Enum.at(@focus_order, state.focus_idx)
    new_state = route_key(focused, event, state)
    {:cont, new_state}
  end

  def handle_event(%{type: :paste} = event, state) do
    focused = Enum.at(@focus_order, state.focus_idx)
    if focused == :text_input do
      {:cont, %{state | text_input: TextInput.update(:paste, event, state.text_input)}}
    else
      {:cont, state}
    end
  end

  def handle_event(%{type: :mouse, action: action} = event, state)
      when action in [:scroll_up, :scroll_down] do
    focused = Enum.at(@focus_order, state.focus_idx)
    if focused == :scroller do
      {:cont, %{state | scroll: ScrollBox.update(:mouse, event, state.scroll)}}
    else
      {:cont, state}
    end
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(20, 20, 35)
    fg = Color.rgb(200, 200, 200)
    dim = Color.rgb(100, 100, 100)
    accent = Color.rgb(100, 220, 100)
    divider_fg = Color.rgb(60, 60, 80)
    panel_w = min(54, state.cols - 4)
    content_w = panel_w - 6

    focused = Enum.at(@focus_order, state.focus_idx)
    focused_label = Map.get(@focus_labels, focused, "")

    ti = state.text_input
    sel = state.select
    scroll_y = state.scroll.scroll_y
    visible_lines = Enum.slice(@scroll_content, scroll_y, @scroll_viewport)

    panel id: :gallery, title: "Widget Gallery", width: panel_w, height: 30,
          border: true, fg: fg, bg: bg do

      text(content: "Tab: next widget | Shift+Tab: prev | Ctrl+C: quit", fg: dim, bg: bg)
      text(content: "")

      # ── TextInput ──
      label(content: section_label(:text_input, focused, "TextInput"), fg: accent, bg: bg)
      input(
        id: :text_input,
        value: ti.value,
        placeholder: ti.placeholder,
        cursor_pos: ti.cursor_pos,
        scroll_offset: ti.scroll_offset,
        width: ti.width,
        height: 1,
        bg: Color.rgb(40, 40, 60),
        fg: fg
      )
      text(content: "")

      # ── Select ──
      label(content: section_label(:lang_select, focused, "Select"), fg: accent, bg: bg)
      select(
        id: :lang_select,
        options: @languages,
        selected: sel.selected,
        scroll_offset: sel.scroll_offset,
        height: sel.visible_count,
        width: content_w,
        fg: fg,
        bg: bg
      )
      text(content: "")

      # ── Checkboxes ──
      label(content: section_label_multi([:check_dark, :check_notify], focused, "Checkboxes"), fg: accent, bg: bg)
      checkbox(id: :check_dark, checked: state.check_dark.checked, label: state.check_dark.label, fg: fg, bg: bg)
      checkbox(id: :check_notify, checked: state.check_notify.checked, label: state.check_notify.label, fg: fg, bg: bg)
      text(content: "")

      # ── ScrollBox ──
      label(content: section_label(:scroller, focused, "ScrollBox"), fg: accent, bg: bg)
      scroll_box id: :scroller, scroll_y: scroll_y, height: @scroll_viewport do
        for line <- visible_lines do
          text(content: String.slice(line, 0, content_w), fg: fg, bg: bg)
        end
      end
      text(content: "")

      text(content: String.duplicate("─", panel_w - 4), fg: divider_fg, bg: bg)
      text(content: " Focus: #{focused_label}", fg: Color.rgb(80, 160, 255), bg: bg)
    end
  end

  def focused_id(state), do: Enum.at(@focus_order, state.focus_idx)

  # --- Private ---

  defp route_key(:text_input, event, state) do
    %{state | text_input: TextInput.update(:key, event, state.text_input)}
  end

  defp route_key(:lang_select, event, state) do
    %{state | select: Select.update(:key, event, state.select)}
  end

  defp route_key(:check_dark, event, state) do
    %{state | check_dark: Checkbox.update(:key, event, state.check_dark)}
  end

  defp route_key(:check_notify, event, state) do
    %{state | check_notify: Checkbox.update(:key, event, state.check_notify)}
  end

  defp route_key(:scroller, event, state) do
    %{state | scroll: ScrollBox.update(:key, event, state.scroll)}
  end

  defp section_label(id, focused, name) do
    if id == focused, do: "> #{name}", else: "  #{name}"
  end

  defp section_label_multi(ids, focused, name) do
    if focused in ids, do: "> #{name}", else: "  #{name}"
  end
end

ElixirOpentui.Demo.DemoRunner.run(WidgetGallery)
