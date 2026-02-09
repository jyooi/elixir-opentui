# TextArea Interactive Demo
# Run: mix run demo/text_area_demo.exs
#
# Multi-line text editor with word wrap, selection, undo/redo.
# Type text, use arrow keys, Shift+arrows to select, Ctrl+Z undo, Ctrl+C to exit.

defmodule TextAreaDemo do
  alias ElixirOpentui.Widgets.TextArea
  alias ElixirOpentui.EditBufferNIF
  alias ElixirOpentui.Color

  def init(cols, rows) do
    ta_width = min(60, cols - 6)
    ta_height = max(5, rows - 12)

    %{
      cols: cols,
      rows: rows,
      textarea: TextArea.init(%{
        id: :editor,
        placeholder: "Start typing here...",
        width: ta_width,
        height: ta_height,
        wrap: :word,
        value: ""
      })
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true}, _state), do: :quit

  def handle_event(%{type: :key} = event, state) do
    new_ta = TextArea.update(:key, event, state.textarea)
    {:cont, %{state | textarea: new_ta}}
  end

  def handle_event(%{type: :paste} = event, state) do
    new_ta = TextArea.update(:paste, event, state.textarea)
    {:cont, %{state | textarea: new_ta}}
  end

  def handle_event(%{type: :mouse} = event, state) do
    new_ta = TextArea.update(:mouse, event, state.textarea)
    {:cont, %{state | textarea: new_ta}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    ta = state.textarea
    ta_element = TextArea.render(ta)

    text_content = EditBufferNIF.get_text(ta.edit_buffer)
    {row, col, offset} = EditBufferNIF.get_cursor(ta.edit_buffer)
    line_count = EditBufferNIF.get_line_count(ta.edit_buffer)
    char_count = String.length(text_content)

    sel_info = if ta.selection && ta.selection.anchor != ta.selection.focus do
      sel_len = abs(ta.selection.focus - ta.selection.anchor)
      " | Sel: #{sel_len}"
    else
      ""
    end

    panel_w = min(64, state.cols - 2)

    panel id: :main, title: "TextArea Demo", width: panel_w, height: state.rows - 2,
          border: true, fg: Color.rgb(200, 200, 200), bg: Color.rgb(20, 20, 35) do
      [
        text(content: " Ctrl+C quit | Shift+arrows select | Ctrl+Z undo",
             fg: Color.rgb(100, 100, 120), bg: Color.rgb(20, 20, 35)),
        text(content: ""),
        ta_element,
        text(content: ""),
        text(content: String.duplicate("─", panel_w - 4),
             fg: Color.rgb(60, 60, 80), bg: Color.rgb(20, 20, 35)),
        text(content: " Ln #{row + 1}, Col #{col} | Off #{offset} | Lines #{line_count} | Chars #{char_count}#{sel_info}",
             fg: Color.rgb(120, 120, 150), bg: Color.rgb(20, 20, 35))
      ]
    end
  end

  def focused_id(_state), do: :editor
end

ElixirOpentui.DemoRunner.run(TextAreaDemo)
