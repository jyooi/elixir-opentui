defmodule ElixirOpentui.Widgets.TextAreaTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.TextArea
  alias ElixirOpentui.EditBufferNIF

  # ── Helpers ──────────────────────────────────────────────────────────

  defp key_event(key, opts \\ []) do
    %{
      type: :key,
      key: key,
      ctrl: Keyword.get(opts, :ctrl, false),
      alt: Keyword.get(opts, :alt, false),
      shift: Keyword.get(opts, :shift, false),
      meta: Keyword.get(opts, :meta, false)
    }
  end

  defp get_text(state), do: EditBufferNIF.get_text(state.edit_buffer)

  defp get_cursor(state) do
    {row, col, offset} = EditBufferNIF.get_cursor(state.edit_buffer)
    %{row: row, col: col, offset: offset}
  end

  defp type_string(state, string) do
    string
    |> String.graphemes()
    |> Enum.reduce(state, fn ch, s -> TextArea.update(:key, key_event(ch), s) end)
  end

  defp move_to_end(state) do
    text = EditBufferNIF.get_text(state.edit_buffer)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, String.length(text))
    state
  end

  defp get_visual_cursor(state) do
    {vr, vc, _lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(state.editor_view)
    {vr, vc}
  end

  defp get_visual_cursor_full(state) do
    {vr, vc, lr, lc, offset} = EditBufferNIF.view_get_visual_cursor(state.editor_view)
    %{visual_row: vr, visual_col: vc, logical_row: lr, logical_col: lc, offset: offset}
  end

  defp select_right_n(state, n) do
    Enum.reduce(1..n, state, fn _, s ->
      TextArea.update(:key, key_event(:right, shift: true), s)
    end)
  end

  # ── Editing ─────────────────────────────────────────────────────────

  describe "editing" do
    test "init with default options" do
      state = TextArea.init(%{id: :ta})
      assert get_text(state) == ""
      assert state.id == :ta
      assert state.width == 40
      assert state.height == 10
      assert state.wrap == :word
    end

    test "init with multi-line text" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld"})
      assert get_text(state) == "hello\nworld"
    end

    test "init with custom dimensions" do
      state = TextArea.init(%{id: :ta, width: 80, height: 24})
      assert state.width == 80
      assert state.height == 24
    end

    test "init cursor at beginning" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      cursor = get_cursor(state)
      assert cursor.offset == 0
    end

    test "char insertion at beginning" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = TextArea.update(:key, key_event("a"), state)
      assert get_text(state) == "a"
    end

    test "multiple char insertion" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = type_string(state, "hello")
      assert get_text(state) == "hello"
    end

    test "char insertion in middle of text" do
      state = TextArea.init(%{id: :ta, value: "ac", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:right), state)
      state = TextArea.update(:key, key_event("b"), state)
      assert get_text(state) == "abc"
    end

    test "char insertion at end of multi-line text" do
      state = TextArea.init(%{id: :ta, value: "ab\ncd", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event("x"), state)
      assert get_text(state) == "ab\ncdx"
    end

    test "backspace deletes character before cursor" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:backspace), state)
      assert get_text(state) == "ab"
    end

    test "backspace at beginning of line joins lines" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 0)
      state = TextArea.update(:key, key_event(:backspace), state)
      assert get_text(state) == "helloworld"
    end

    test "backspace no-op at beginning of buffer" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:backspace), state)
      assert get_text(state) == "abc"
    end

    test "delete removes character at cursor" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:delete), state)
      assert get_text(state) == "bc"
    end

    test "delete no-op at end of buffer" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:delete), state)
      assert get_text(state) == "abc"
    end

    test "delete joins lines when at end of line" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 5)
      state = TextArea.update(:key, key_event(:delete), state)
      assert get_text(state) == "helloworld"
    end

    test "arrow key left from position 3" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 3)
      state = TextArea.update(:key, key_event(:left), state)
      cursor = get_cursor(state)
      assert cursor.offset == 2
    end

    test "arrow key left at beginning stays" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:left), state)
      cursor = get_cursor(state)
      assert cursor.offset == 0
    end

    test "arrow key right moves forward" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:right), state)
      cursor = get_cursor(state)
      assert cursor.offset == 1
    end

    test "arrow key right at end stays" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:right), state)
      cursor = get_cursor(state)
      assert cursor.offset == 3
    end

    test "arrow key up movement" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 3)
      state = TextArea.update(:key, key_event(:up), state)
      cursor = get_cursor(state)
      assert cursor.row == 0
    end

    test "arrow key down movement" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:down), state)
      cursor = get_cursor(state)
      assert cursor.row == 1
    end

    test "Ctrl+A moves to beginning of line" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 3)
      state = TextArea.update(:key, key_event("a", ctrl: true), state)
      cursor = get_cursor(state)
      assert cursor.col == 0
      assert cursor.row == 1
    end

    test "Ctrl+E moves to end of line" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 0)
      state = TextArea.update(:key, key_event("e", ctrl: true), state)
      cursor = get_cursor(state)
      assert cursor.row == 1
      assert cursor.col == 5
    end

    test "Ctrl+K deletes to end of line" do
      state = TextArea.init(%{id: :ta, value: "hello world\nsecond", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 5)
      state = TextArea.update(:key, key_event("k", ctrl: true), state)
      assert get_text(state) == "hello\nsecond"
    end

    test "Ctrl+U deletes to start of line" do
      state = TextArea.init(%{id: :ta, value: "hello world\nsecond", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 5)
      state = TextArea.update(:key, key_event("u", ctrl: true), state)
      assert get_text(state) == " world\nsecond"
      cursor = get_cursor(state)
      assert cursor.col == 0
    end

    test "newline insertion in middle" do
      state = TextArea.init(%{id: :ta, value: "helloworld", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 5)
      state = TextArea.update(:key, key_event(:enter), state)
      assert get_text(state) == "hello\nworld"
    end

    test "newline at beginning of buffer" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:enter), state)
      assert get_text(state) == "\nhello"
    end

    test "newline at end of buffer" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:enter), state)
      assert get_text(state) == "hello\n"
    end

    test "shift+backspace acts as backspace (kitty keyboard)" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:backspace, shift: true), state)
      assert get_text(state) == "ab"
    end

    test "shift+delete acts as delete (kitty keyboard)" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:delete, shift: true), state)
      assert get_text(state) == "bc"
    end

    test "Ctrl+B moves left (emacs binding)" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 2)
      state = TextArea.update(:key, key_event("b", ctrl: true), state)
      cursor = get_cursor(state)
      assert cursor.offset == 1
    end

    test "Ctrl+F moves right (emacs binding)" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = TextArea.update(:key, key_event("f", ctrl: true), state)
      cursor = get_cursor(state)
      assert cursor.offset == 1
    end

    test "Ctrl+D deletes forward (same as delete)" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = TextArea.update(:key, key_event("d", ctrl: true), state)
      assert get_text(state) == "bc"
    end

    test "Ctrl+K at end of line is no-op" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 5)
      state = TextArea.update(:key, key_event("k", ctrl: true), state)
      assert get_text(state) == "hello\nworld"
    end

    test "Ctrl+U at start of line is no-op" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      state = TextArea.update(:key, key_event("u", ctrl: true), state)
      assert get_text(state) == "hello\nworld"
    end

    test "Ctrl+K on second line deletes to end of that line only" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "Line 1 content\nLine 2 content\nLine 3 content",
          width: 40,
          height: 10
        })

      EditBufferNIF.set_cursor(state.edit_buffer, 1, 7)
      state = TextArea.update(:key, key_event("k", ctrl: true), state)
      assert get_text(state) == "Line 1 content\nLine 2 \nLine 3 content"
      cursor = get_cursor(state)
      assert cursor.col == 7
      assert cursor.row == 1
    end

    test "Ctrl+U on second line deletes to start of that line only" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "Line 1 content\nLine 2 content\nLine 3 content",
          width: 40,
          height: 10
        })

      EditBufferNIF.set_cursor(state.edit_buffer, 1, 7)
      state = TextArea.update(:key, key_event("u", ctrl: true), state)
      assert get_text(state) == "Line 1 content\ncontent\nLine 3 content"
      cursor = get_cursor(state)
      assert cursor.col == 0
      assert cursor.row == 1
    end

    test "Ctrl+K on first line from position 7" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "Line 1 content\nLine 2 content\nLine 3 content",
          width: 40,
          height: 10
        })

      EditBufferNIF.set_cursor(state.edit_buffer, 0, 7)
      state = TextArea.update(:key, key_event("k", ctrl: true), state)
      assert get_text(state) == "Line 1 \nLine 2 content\nLine 3 content"
      cursor = get_cursor(state)
      assert cursor.col == 7
      assert cursor.row == 0
    end

    test "Ctrl+U on first line from position 7" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "Line 1 content\nLine 2 content\nLine 3 content",
          width: 40,
          height: 10
        })

      EditBufferNIF.set_cursor(state.edit_buffer, 0, 7)
      state = TextArea.update(:key, key_event("u", ctrl: true), state)
      assert get_text(state) == "content\nLine 2 content\nLine 3 content"
      cursor = get_cursor(state)
      assert cursor.col == 0
      assert cursor.row == 0
    end

    test "modifiers suppress character insertion (ctrl)" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = TextArea.update(:key, key_event("x", ctrl: true), state)
      assert get_text(state) == ""
    end

    test "modifiers suppress character insertion (alt)" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = TextArea.update(:key, key_event("x", alt: true), state)
      assert get_text(state) == ""
    end

    test "modifiers suppress character insertion (meta)" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = TextArea.update(:key, key_event("x", meta: true), state)
      assert get_text(state) == ""
    end

    test "shift alone allows character insertion" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = TextArea.update(:key, key_event("A", shift: true), state)
      assert get_text(state) == "A"
    end

  end

  # ── Unicode / Emoji ─────────────────────────────────────────────────

  describe "unicode" do
    test "insert emoji character" do
      state = TextArea.init(%{id: :ta, value: "Hello", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(" "), state)
      state = TextArea.update(:paste, %{type: :paste, data: "🌟"}, state)
      assert get_text(state) == "Hello 🌟"
    end

    test "insert CJK characters" do
      state = TextArea.init(%{id: :ta, value: "Hello", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:paste, %{type: :paste, data: " 世界"}, state)
      assert get_text(state) == "Hello 世界"
    end

    test "cursor movement around emoji" do
      state = TextArea.init(%{id: :ta, value: "A🌟B", width: 40, height: 10})
      cursor = get_cursor(state)
      assert cursor.col == 0

      # Move past A
      state = TextArea.update(:key, key_event(:right), state)
      cursor = get_cursor(state)
      assert cursor.col == 1

      # Move past emoji (occupies 2 display-width columns)
      state = TextArea.update(:key, key_event(:right), state)
      cursor = get_cursor(state)
      assert cursor.col == 3

      # Move past B
      state = TextArea.update(:key, key_event(:right), state)
      cursor = get_cursor(state)
      assert cursor.col == 4
    end

    test "backspace deletes emoji" do
      state = TextArea.init(%{id: :ta, value: "A🌟B", width: 40, height: 10})
      # Position after emoji (col 3)
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 3)
      state = TextArea.update(:key, key_event(:backspace), state)
      assert get_text(state) == "AB"
    end

    test "delete forward removes emoji" do
      state = TextArea.init(%{id: :ta, value: "A🌟B", width: 40, height: 10})
      # Position at emoji (col 1)
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 1)
      state = TextArea.update(:key, key_event(:delete), state)
      assert get_text(state) == "AB"
    end
  end

  # ── Selection ───────────────────────────────────────────────────────

  describe "selection" do
    test "shift+right selects right" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:right, shift: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 0
      assert state.selection.focus == 1
    end

    test "shift+left selects left" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 5)
      state = TextArea.update(:key, key_event(:left, shift: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 5
      assert state.selection.focus == 4
    end

    test "multiple shift+right extends selection" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = select_right_n(state, 3)
      assert state.selection.anchor == 0
      assert state.selection.focus == 3
    end

    test "select all with Super+A" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      state = TextArea.update(:key, key_event("a", meta: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 0
      assert state.selection.focus == 11
    end

    test "delete selected text with backspace" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = select_right_n(state, 5)
      state = TextArea.update(:key, key_event(:backspace), state)
      assert get_text(state) == " world"
    end

    test "delete selected text with delete key" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = select_right_n(state, 5)
      state = TextArea.update(:key, key_event(:delete), state)
      assert get_text(state) == " world"
    end

    test "typing replaces selection" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event("a", meta: true), state)
      state = TextArea.update(:key, key_event("x"), state)
      assert get_text(state) == "x"
    end

    test "shift+up selects upward" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 3)
      state = TextArea.update(:key, key_event(:up, shift: true), state)
      assert state.selection != nil
      cursor = get_cursor(state)
      assert cursor.row == 0
    end

    test "shift+down selects downward" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:down, shift: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 0
      cursor = get_cursor(state)
      assert cursor.row == 1
    end

    test "selection with word movement forward" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:right, alt: true, shift: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 0
      assert state.selection.focus > 0
    end

    test "selection with word movement backward" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 11)
      state = TextArea.update(:key, key_event(:left, alt: true, shift: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 11
      assert state.selection.focus < 11
    end

    test "moving without shift clears selection" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = select_right_n(state, 2)
      assert state.selection != nil
      state = TextArea.update(:key, key_event(:right), state)
      assert state.selection == nil
    end

    test "left arrow collapses selection to start" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 1)
      state = select_right_n(state, 3)
      # Selection is 1..4
      assert state.selection.anchor == 1
      assert state.selection.focus == 4
      state = TextArea.update(:key, key_event(:left), state)
      assert state.selection == nil
      cursor = get_cursor(state)
      # Collapses to start of selection, then moves left
      assert cursor.offset == 0
    end

    test "right arrow collapses selection to end" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = select_right_n(state, 3)
      # Selection is 0..3
      assert state.selection.anchor == 0
      assert state.selection.focus == 3
      state = TextArea.update(:key, key_event(:right), state)
      assert state.selection == nil
      cursor = get_cursor(state)
      # Collapses to end of selection, then moves right
      assert cursor.offset == 4
    end

    test "Ctrl+Shift+A selects to line home" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 3)
      state = TextArea.update(:key, key_event("a", ctrl: true, shift: true), state)
      assert state.selection != nil
      cursor = get_cursor(state)
      assert cursor.col == 0
      assert cursor.row == 1
    end

    test "Ctrl+Shift+E selects to line end" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 0)
      state = TextArea.update(:key, key_event("e", ctrl: true, shift: true), state)
      assert state.selection != nil
      cursor = get_cursor(state)
      assert cursor.row == 1
    end

    test "select all then type replaces all text" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event("a", meta: true), state)
      state = type_string(state, "replaced")
      assert get_text(state) == "replaced"
    end

    test "select all then backspace clears text" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event("a", meta: true), state)
      state = TextArea.update(:key, key_event(:backspace), state)
      assert get_text(state) == ""
    end

    test "select all then delete clears text" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event("a", meta: true), state)
      state = TextArea.update(:key, key_event(:delete), state)
      assert get_text(state) == ""
    end

    test "selection with Super+Up selects to buffer home" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 8)
      state = TextArea.update(:key, key_event(:up, shift: true, meta: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 8
      assert state.selection.focus == 0
    end

    test "selection with Super+Down selects to buffer end" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:down, shift: true, meta: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 0
      assert state.selection.focus == 11
    end
  end

  # ── Undo/Redo ───────────────────────────────────────────────────────

  describe "undo/redo" do
    test "undo text insertion" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = type_string(state, "hello")
      assert get_text(state) == "hello"

      state = TextArea.update(:key, key_event("z", meta: true), state)
      undone_text = get_text(state)
      assert String.length(undone_text) < 5
    end

    test "redo after undo" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = type_string(state, "hello")

      state = TextArea.update(:key, key_event("z", meta: true), state)
      after_undo = get_text(state)

      state = TextArea.update(:key, key_event("z", meta: true, shift: true), state)
      after_redo = get_text(state)

      assert String.length(after_redo) > String.length(after_undo)
    end

    test "multiple undo operations" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = type_string(state, "base")
      state = type_string(state, " one")
      state = type_string(state, " two")
      assert get_text(state) == "base one two"

      state =
        Enum.reduce(1..8, state, fn _, s ->
          TextArea.update(:key, key_event("z", meta: true), s)
        end)

      text = get_text(state)
      assert String.length(text) < String.length("base one two")
    end

    test "undo clears selection" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:right, shift: true), state)
      assert state.selection != nil

      state = TextArea.update(:key, key_event("x"), state)

      state = TextArea.update(:key, key_event("z", meta: true), state)
      assert state.selection == nil
    end

    test "Ctrl+- also triggers undo" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = type_string(state, "hello")
      state = TextArea.update(:key, key_event("-", ctrl: true), state)
      assert String.length(get_text(state)) < 5
    end

    test "Ctrl+. also triggers redo" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = type_string(state, "hello")
      state = TextArea.update(:key, key_event("-", ctrl: true), state)
      after_undo = get_text(state)
      state = TextArea.update(:key, key_event(".", ctrl: true), state)
      assert String.length(get_text(state)) > String.length(after_undo)
    end

    test "undo after backspace restores deleted character" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:backspace), state)
      assert get_text(state) == "ab"
      state = TextArea.update(:key, key_event("z", meta: true), state)
      assert get_text(state) == "abc"
    end

    test "undo after delete forward restores deleted character" do
      state = TextArea.init(%{id: :ta, value: "abc", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:delete), state)
      assert get_text(state) == "bc"
      state = TextArea.update(:key, key_event("z", meta: true), state)
      assert get_text(state) == "abc"
    end
  end

  # ── Visual lines ────────────────────────────────────────────────────

  describe "visual lines" do
    test "word wrap mode is set" do
      state = TextArea.init(%{id: :ta, value: "", wrap: :word, width: 10, height: 5})
      assert state.wrap == :word
    end

    test "char wrap mode is set" do
      state = TextArea.init(%{id: :ta, value: "", wrap: :char, width: 10, height: 5})
      assert state.wrap == :char
    end

    test "none wrap mode is set" do
      state = TextArea.init(%{id: :ta, value: "", wrap: :none, width: 10, height: 5})
      assert state.wrap == :none
    end

    test "visual cursor navigation with wrapped text" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "one two three four five",
          wrap: :word,
          width: 10,
          height: 5
        })

      state = TextArea.update(:key, key_event(:down), state)
      {vr, _vc} = get_visual_cursor(state)
      assert vr >= 1
    end

    test "Alt+A moves to visual line start" do
      state =
        TextArea.init(%{id: :ta, value: "hello world", wrap: :word, width: 40, height: 10})

      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 5)
      state = TextArea.update(:key, key_event("a", alt: true), state)
      cursor = get_cursor(state)
      assert cursor.offset == 0
    end

    test "Alt+E moves to visual line end" do
      state =
        TextArea.init(%{id: :ta, value: "hello world", wrap: :word, width: 40, height: 10})

      state = TextArea.update(:key, key_event("e", alt: true), state)
      cursor = get_cursor(state)
      assert cursor.offset == 11
    end

    test "char wrap: visual line home goes to wrapped line start" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
          wrap: :char,
          width: 20,
          height: 10
        })

      # Position at col 22 (on second visual line)
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 22)
      state = TextArea.update(:key, key_event("a", alt: true), state)
      cursor = get_cursor(state)
      # Should go to col 20 (start of second visual line), not col 0
      assert cursor.col == 20
    end

    test "char wrap: visual line end goes to wrapped line end" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
          wrap: :char,
          width: 20,
          height: 10
        })

      # Position at col 5 (on first visual line)
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 5)
      state = TextArea.update(:key, key_event("e", alt: true), state)
      cursor = get_cursor(state)
      # Should go to col 19 (end of first visual line), not col 26 (end of logical line)
      assert cursor.col == 19
    end

    test "visual home differs from logical home when wrapped" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
          wrap: :char,
          width: 20,
          height: 10
        })

      # Position at col 22 (second visual line)
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 22)

      # Visual home -> col 20
      state = TextArea.update(:key, key_event("a", alt: true), state)
      visual_home_col = get_cursor(state).col
      assert visual_home_col == 20

      # Reposition
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 22)

      # Logical home -> col 0
      state = TextArea.update(:key, key_event("a", ctrl: true), state)
      logical_home_col = get_cursor(state).col
      assert logical_home_col == 0

      assert visual_home_col != logical_home_col
    end

    test "visual end differs from logical end when wrapped" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
          wrap: :char,
          width: 20,
          height: 10
        })

      # Position at col 5 (first visual line)
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 5)

      # Visual end -> col 19
      state = TextArea.update(:key, key_event("e", alt: true), state)
      visual_end_col = get_cursor(state).col
      assert visual_end_col == 19

      # Reposition
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 5)

      # Logical end -> col 26
      state = TextArea.update(:key, key_event("e", ctrl: true), state)
      logical_end_col = get_cursor(state).col
      assert logical_end_col == 26

      assert visual_end_col != logical_end_col
    end

    test "without wrapping, visual and logical home/end are the same" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "Hello World",
          wrap: :none,
          width: 40,
          height: 10
        })

      # Test home
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 6)
      state = TextArea.update(:key, key_event("a", alt: true), state)
      visual_home = get_cursor(state).col

      EditBufferNIF.set_cursor(state.edit_buffer, 0, 6)
      state = TextArea.update(:key, key_event("a", ctrl: true), state)
      logical_home = get_cursor(state).col
      assert visual_home == logical_home

      # Test end
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 6)
      state = TextArea.update(:key, key_event("e", alt: true), state)
      visual_end = get_cursor(state).col

      EditBufferNIF.set_cursor(state.edit_buffer, 0, 6)
      state = TextArea.update(:key, key_event("e", ctrl: true), state)
      logical_end = get_cursor(state).col
      assert visual_end == logical_end
    end

    test "word wrap navigates between visual lines correctly" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "Hello wonderful world of wrapped text",
          wrap: :word,
          width: 20,
          height: 10
        })

      # Position somewhere mid-text (after some wrapping)
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 25)

      vc = get_visual_cursor_full(state)
      assert vc.visual_row > 0

      # Visual home should go to start of that visual line (not col 0 of logical line)
      state = TextArea.update(:key, key_event("a", alt: true), state)
      sol_cursor = get_cursor(state)
      assert sol_cursor.col > 0

      # Visual end
      state = TextArea.update(:key, key_event("e", alt: true), state)
      eol_cursor = get_cursor(state)
      assert eol_cursor.col < 37
    end

    test "move cursor down through wrapped visual lines" do
      long_text =
        "This is a very long line that will definitely wrap into multiple visual lines when the viewport is small"

      state =
        TextArea.init(%{
          id: :ta,
          value: long_text,
          wrap: :word,
          width: 20,
          height: 10
        })

      # Start at beginning
      vc = get_visual_cursor_full(state)
      assert vc.visual_row == 0
      assert vc.visual_col == 0

      # Get total virtual line count
      total = EditBufferNIF.view_get_total_virtual_line_count(state.editor_view)
      assert total > 1

      # Move down through each wrapped line
      state =
        Enum.reduce(1..(total - 1), state, fn i, s ->
          s = TextArea.update(:key, key_event(:down), s)
          vc = get_visual_cursor_full(s)
          assert vc.visual_row == i
          assert vc.visual_col == 0
          s
        end)

      final_vc = get_visual_cursor_full(state)
      assert final_vc.visual_row == total - 1
    end

    test "select within visual line with Alt+Shift+E" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
          wrap: :char,
          width: 20,
          height: 10
        })

      EditBufferNIF.set_cursor(state.edit_buffer, 0, 10)

      state = TextArea.update(:key, key_event("e", alt: true, shift: true), state)
      assert state.selection != nil
    end
  end

  # ── Rendering ───────────────────────────────────────────────────────

  describe "rendering" do
    test "render/1 produces textarea element" do
      state = TextArea.init(%{id: :myarea, value: "test", width: 40, height: 10})
      element = TextArea.render(state)
      assert element.type == :textarea
    end

    test "element has correct id" do
      state = TextArea.init(%{id: :myarea, value: "test", width: 40, height: 10})
      element = TextArea.render(state)
      assert element.id == :myarea
    end

    test "element has lines attribute" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      element = TextArea.render(state)
      assert is_list(element.attrs.lines)
      assert length(element.attrs.lines) == 2
      assert hd(element.attrs.lines) == "hello"
    end

    test "element has cursor attributes" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      element = TextArea.render(state)
      assert is_integer(element.attrs.cursor_row)
      assert is_integer(element.attrs.cursor_col)
    end

    test "element has placeholder" do
      state = TextArea.init(%{id: :ta, value: "", placeholder: "Type here..."})
      element = TextArea.render(state)
      assert element.attrs.placeholder == "Type here..."
    end

    test "element has scroll_y" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      element = TextArea.render(state)
      assert is_integer(element.attrs.scroll_y)
    end

    test "render multi-line content shows visible lines" do
      lines = Enum.map_join(0..20, "\n", fn i -> "line #{i}" end)
      state = TextArea.init(%{id: :ta, value: lines, width: 40, height: 5})
      element = TextArea.render(state)
      assert length(element.attrs.lines) <= 5
    end

    test "selection renders as nil when no selection" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      element = TextArea.render(state)
      assert element.attrs.selection == nil
    end

    test "selection renders when selection exists" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = select_right_n(state, 2)
      element = TextArea.render(state)
      assert element.attrs.selection != nil
    end

    test "render element has width and height in style" do
      state = TextArea.init(%{id: :ta, value: "test", width: 80, height: 24})
      element = TextArea.render(state)
      # width/height are layout attrs, so they go into element.style, not element.attrs
      assert element.style.width == 80
      assert element.style.height == 24
    end

    test "content update reflects in render" do
      state = TextArea.init(%{id: :ta, value: "Initial", width: 40, height: 10})
      state = TextArea.update(:sync_value, %{value: "Updated"}, state)
      element = TextArea.render(state)
      assert hd(element.attrs.lines) == "Updated"
    end

    test "cursor position reflects in render after movement" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:down), state)
      element = TextArea.render(state)
      assert element.attrs.cursor_row > 0 or element.attrs.cursor_col >= 0
    end
  end

  # ── Events ──────────────────────────────────────────────────────────

  describe "events" do
    test "Alt+Enter triggers submit (no newline)" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:enter, alt: true), state)
      assert get_text(state) == "hello"
    end

    test "paste inserts text at cursor" do
      state = TextArea.init(%{id: :ta, value: "hello ", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:paste, %{type: :paste, data: "world"}, state)
      assert get_text(state) == "hello world"
    end

    test "paste at beginning inserts at start" do
      state = TextArea.init(%{id: :ta, value: "world", width: 40, height: 10})
      state = TextArea.update(:paste, %{type: :paste, data: "hello "}, state)
      assert get_text(state) == "hello world"
    end

    test "paste replaces selection" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event("a", meta: true), state)
      state = TextArea.update(:paste, %{type: :paste, data: "replaced"}, state)
      assert get_text(state) == "replaced"
    end

    test "paste multi-line text" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = TextArea.update(:paste, %{type: :paste, data: "line1\nline2\nline3"}, state)
      assert get_text(state) == "line1\nline2\nline3"
    end

    test "paste unicode text" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = TextArea.update(:paste, %{type: :paste, data: "Hello 🌟 World"}, state)
      assert get_text(state) == "Hello 🌟 World"
    end

    test "paste in middle of text" do
      state = TextArea.init(%{id: :ta, value: "ac", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 1)
      state = TextArea.update(:paste, %{type: :paste, data: "b"}, state)
      assert get_text(state) == "abc"
    end

    test "paste empty string is no-op" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = TextArea.update(:paste, %{type: :paste, data: ""}, state)
      assert get_text(state) == "hello"
    end

    test "resize updates dimensions" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = TextArea.update(:resize, %{width: 80, height: 24}, state)
      assert state.width == 80
      assert state.height == 24
    end

    test "sync_value replaces text" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = TextArea.update(:sync_value, %{value: "new text"}, state)
      assert get_text(state) == "new text"
    end

    test "sync_value clears selection" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:right, shift: true), state)
      assert state.selection != nil
      state = TextArea.update(:sync_value, %{value: "new"}, state)
      assert state.selection == nil
    end

    test "unknown message is no-op" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state2 = TextArea.update(:unknown, %{}, state)
      assert get_text(state2) == "hello"
    end

    test "mouse scroll up" do
      # Create text tall enough to scroll
      lines = Enum.map_join(0..30, "\n", fn i -> "line #{i}" end)
      state = TextArea.init(%{id: :ta, value: lines, width: 40, height: 5})

      # Scroll down first using mouse scroll
      state = TextArea.update(:mouse, %{type: :mouse, action: :scroll, direction: :down}, state)
      state = TextArea.update(:mouse, %{type: :mouse, action: :scroll, direction: :down}, state)
      scroll_before = state.scroll_y
      assert scroll_before > 0

      state = TextArea.update(:mouse, %{type: :mouse, action: :scroll, direction: :up}, state)
      assert state.scroll_y < scroll_before
    end

    test "mouse scroll down" do
      lines = Enum.map_join(0..30, "\n", fn i -> "line #{i}" end)
      state = TextArea.init(%{id: :ta, value: lines, width: 40, height: 5})

      state = TextArea.update(:mouse, %{type: :mouse, action: :scroll, direction: :down}, state)
      assert state.scroll_y >= 0
    end
  end

  # ── Word deletion ───────────────────────────────────────────────────

  describe "word deletion" do
    test "Ctrl+W deletes word backward from end" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event("w", ctrl: true), state)
      text = get_text(state)
      assert String.length(text) < 11
    end

    test "Ctrl+W no-op at beginning" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event("w", ctrl: true), state)
      assert get_text(state) == "hello world"
    end

    test "Alt+D deletes word forward" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event("d", alt: true), state)
      text = get_text(state)
      assert String.length(text) < 11
    end

    test "Ctrl+Shift+D deletes entire line" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld\nfoo", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 0)
      state = TextArea.update(:key, key_event("d", ctrl: true, shift: true), state)
      text = get_text(state)
      refute String.contains?(text, "world")
    end

    test "Ctrl+Backspace deletes word backward" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:backspace, ctrl: true), state)
      text = get_text(state)
      assert String.length(text) < 11
    end

    test "Alt+Backspace deletes word backward" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:backspace, alt: true), state)
      text = get_text(state)
      assert String.length(text) < 11
    end

    test "Alt+Delete deletes word forward" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:delete, alt: true), state)
      text = get_text(state)
      assert String.length(text) < 11
    end

    test "Ctrl+Delete deletes word forward" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:delete, ctrl: true), state)
      text = get_text(state)
      assert String.length(text) < 11
    end

    test "word deletion with selection deletes selection instead" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = select_right_n(state, 5)
      state = TextArea.update(:key, key_event("w", ctrl: true), state)
      assert get_text(state) == " world"
    end
  end

  # ── Word movement ───────────────────────────────────────────────────

  describe "word movement" do
    test "Alt+F moves to next word boundary" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event("f", alt: true), state)
      cursor = get_cursor(state)
      assert cursor.offset > 0
    end

    test "Alt+B moves to previous word boundary" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 11)
      state = TextArea.update(:key, key_event("b", alt: true), state)
      cursor = get_cursor(state)
      assert cursor.offset < 11
    end

    test "Ctrl+Right moves word forward" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:right, ctrl: true), state)
      cursor = get_cursor(state)
      assert cursor.offset > 0
    end

    test "Ctrl+Left moves word backward" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 11)
      state = TextArea.update(:key, key_event(:left, ctrl: true), state)
      cursor = get_cursor(state)
      assert cursor.offset < 11
    end

    test "Alt+Right moves word forward (alias)" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:right, alt: true), state)
      cursor = get_cursor(state)
      assert cursor.offset > 0
    end

    test "Alt+Left moves word backward (alias)" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 11)
      state = TextArea.update(:key, key_event(:left, alt: true), state)
      cursor = get_cursor(state)
      assert cursor.offset < 11
    end

    test "word movement at word boundaries continues to next word" do
      state = TextArea.init(%{id: :ta, value: "one two three", width: 40, height: 10})
      # Move forward twice to pass two words
      state = TextArea.update(:key, key_event("f", alt: true), state)
      first_pos = get_cursor(state).offset
      state = TextArea.update(:key, key_event("f", alt: true), state)
      second_pos = get_cursor(state).offset
      assert second_pos > first_pos
    end
  end

  # ── Buffer home/end ─────────────────────────────────────────────────

  describe "buffer home/end" do
    test "Home moves to beginning of buffer" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 8)
      state = TextArea.update(:key, key_event(:home), state)
      cursor = get_cursor(state)
      assert cursor.offset == 0
    end

    test "End moves to end of buffer" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:end), state)
      cursor = get_cursor(state)
      assert cursor.offset == 11
    end

    test "Shift+Home selects to beginning of buffer" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 8)
      state = TextArea.update(:key, key_event(:home, shift: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 8
      assert state.selection.focus == 0
    end

    test "Shift+End selects to end of buffer" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:end, shift: true), state)
      assert state.selection != nil
      assert state.selection.anchor == 0
      assert state.selection.focus == 11
    end

    test "Super+Up moves to buffer home" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld\nfoo", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:up, meta: true), state)
      cursor = get_cursor(state)
      assert cursor.offset == 0
    end

    test "Super+Down moves to buffer end" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld\nfoo", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:down, meta: true), state)
      cursor = get_cursor(state)
      assert cursor.offset == 15
    end
  end

  # ── Scroll / Viewport ──────────────────────────────────────────────

  describe "scroll/viewport" do
    test "viewport has valid dimensions after init" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      viewport = EditBufferNIF.view_get_viewport(state.editor_view)
      assert viewport != nil
      {_ox, _oy, w, h} = viewport
      assert w == 40
      assert h == 10
    end

    test "resize updates viewport" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = TextArea.update(:resize, %{width: 80, height: 24}, state)
      viewport = EditBufferNIF.view_get_viewport(state.editor_view)
      {_ox, _oy, w, h} = viewport
      assert w == 80
      assert h == 24
    end

    test "scrolling happens when cursor moves past viewport" do
      lines = Enum.map_join(0..30, "\n", fn i -> "line #{i}" end)
      state = TextArea.init(%{id: :ta, value: lines, width: 40, height: 5})
      # Navigate down past the viewport using widget key events
      state = TextArea.update(:key, key_event(:end), state)
      assert state.scroll_y > 0
    end

    test "virtual line count reflects wrapping" do
      long_text = String.duplicate("A", 100)

      state_wrapped =
        TextArea.init(%{id: :ta, value: long_text, wrap: :char, width: 20, height: 10})

      state_unwrapped =
        TextArea.init(%{id: :ta2, value: long_text, wrap: :none, width: 20, height: 10})

      wrapped_count =
        EditBufferNIF.view_get_total_virtual_line_count(state_wrapped.editor_view)

      unwrapped_count =
        EditBufferNIF.view_get_total_virtual_line_count(state_unwrapped.editor_view)

      assert wrapped_count > 1
      assert unwrapped_count == 1
    end

    test "scroll_y is 0 for content that fits in viewport" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      assert state.scroll_y == 0
    end

    test "viewport offset updates when navigating down" do
      lines = Enum.map_join(0..50, "\n", fn i -> "line #{i}" end)
      state = TextArea.init(%{id: :ta, value: lines, width: 40, height: 5})

      # Move to a line beyond viewport
      state = move_to_end(state)
      {_ox, oy, _w, _h} = EditBufferNIF.view_get_viewport(state.editor_view)
      assert oy > 0
    end
  end

  # ── Buffer operations ──────────────────────────────────────────────

  describe "buffer operations" do
    test "line count for multi-line text" do
      state = TextArea.init(%{id: :ta, value: "one\ntwo\nthree", width: 40, height: 10})
      count = EditBufferNIF.get_line_count(state.edit_buffer)
      assert count == 3
    end

    test "line count for single line" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      count = EditBufferNIF.get_line_count(state.edit_buffer)
      assert count == 1
    end

    test "line count for empty buffer" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      count = EditBufferNIF.get_line_count(state.edit_buffer)
      assert count == 1
    end

    test "cursor position after set_text" do
      state = TextArea.init(%{id: :ta, value: "hello world", width: 40, height: 10})
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 5)
      state = TextArea.update(:sync_value, %{value: "New"}, state)
      cursor = get_cursor(state)
      assert cursor.row == 0
      assert cursor.col == 0
    end

    test "get_text returns current buffer contents" do
      state = TextArea.init(%{id: :ta, value: "initial", width: 40, height: 10})
      assert get_text(state) == "initial"
      state = type_string(state, "prefix")
      assert get_text(state) == "prefixinitial"
    end

    test "visual cursor returns viewport-relative coordinates" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      vc = get_visual_cursor_full(state)
      assert vc.visual_row == 0
      assert vc.visual_col == 0
      assert vc.logical_row == 0
      assert vc.logical_col == 0
    end

    test "visual cursor updates after movement" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      state = TextArea.update(:key, key_event(:down), state)
      vc = get_visual_cursor_full(state)
      assert vc.visual_row == 1
      assert vc.logical_row == 1
    end

    test "delete_line removes current logical line" do
      state = TextArea.init(%{id: :ta, value: "one\ntwo\nthree", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 0)
      state = TextArea.update(:key, key_event("d", ctrl: true, shift: true), state)
      text = get_text(state)
      refute String.contains?(text, "two")
      assert EditBufferNIF.get_line_count(state.edit_buffer) == 2
    end

    test "goto_line moves to specified line" do
      state = TextArea.init(%{id: :ta, value: "one\ntwo\nthree", width: 40, height: 10})
      EditBufferNIF.goto_line(state.edit_buffer, 2)
      cursor = get_cursor(state)
      assert cursor.row == 2
    end
  end

  # ── Complex editing scenarios ──────────────────────────────────────

  describe "complex editing" do
    test "type, select all, delete, type again" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = type_string(state, "hello world")
      assert get_text(state) == "hello world"

      state = TextArea.update(:key, key_event("a", meta: true), state)
      state = TextArea.update(:key, key_event(:backspace), state)
      assert get_text(state) == ""

      state = type_string(state, "new text")
      assert get_text(state) == "new text"
    end

    test "type multi-line, navigate, insert in middle" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})
      state = type_string(state, "line1")
      state = TextArea.update(:key, key_event(:enter), state)
      state = type_string(state, "line2")
      state = TextArea.update(:key, key_event(:enter), state)
      state = type_string(state, "line3")
      assert get_text(state) == "line1\nline2\nline3"

      # Go to beginning of line2
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 0)
      state = type_string(state, ">>")
      assert get_text(state) == "line1\n>>line2\nline3"
    end

    test "select across lines and delete" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld", width: 40, height: 10})
      # Select from offset 3 to end of line 2
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 3)
      state = select_right_n(state, 5)
      # Selection covers "lo\nwo"
      state = TextArea.update(:key, key_event(:backspace), state)
      assert get_text(state) == "helrld"
    end

    test "paste replacing multi-line selection" do
      state = TextArea.init(%{id: :ta, value: "hello\nworld\nfoo", width: 40, height: 10})
      state = TextArea.update(:key, key_event("a", meta: true), state)
      state = TextArea.update(:paste, %{type: :paste, data: "replaced"}, state)
      assert get_text(state) == "replaced"
    end

    test "undo after Ctrl+K restores deleted text" do
      state = TextArea.init(%{id: :ta, value: "Hello World", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 6)
      state = TextArea.update(:key, key_event("k", ctrl: true), state)
      assert get_text(state) == "Hello "

      state = TextArea.update(:key, key_event("z", meta: true), state)
      assert get_text(state) == "Hello World"
    end

    test "undo after Ctrl+U restores deleted text" do
      state = TextArea.init(%{id: :ta, value: "Hello World", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 0, 6)
      state = TextArea.update(:key, key_event("u", ctrl: true), state)
      assert get_text(state) == "World"

      state = TextArea.update(:key, key_event("z", meta: true), state)
      assert get_text(state) == "Hello World"
    end

    test "multiple newlines create blank lines" do
      state = TextArea.init(%{id: :ta, value: "hello", width: 40, height: 10})
      state = move_to_end(state)
      state = TextArea.update(:key, key_event(:enter), state)
      state = TextArea.update(:key, key_event(:enter), state)
      state = TextArea.update(:key, key_event(:enter), state)
      assert get_text(state) == "hello\n\n\n"
      assert EditBufferNIF.get_line_count(state.edit_buffer) == 4
    end

    test "delete line from three-line text preserves others" do
      state = TextArea.init(%{id: :ta, value: "Line 1\nLine 2\nLine 3", width: 40, height: 10})
      EditBufferNIF.set_cursor(state.edit_buffer, 1, 0)
      state = TextArea.update(:key, key_event("d", ctrl: true, shift: true), state)
      assert get_text(state) == "Line 1\nLine 3"
    end

    test "wrap mode change preserves text content" do
      state =
        TextArea.init(%{
          id: :ta,
          value: "hello wonderful world",
          wrap: :char,
          width: 12,
          height: 10
        })

      assert state.wrap == :char
      assert get_text(state) == "hello wonderful world"

      # Changing wrap mode via reinit preserves content conceptually
      # (the widget doesn't have a runtime wrap mode setter, it's set at init)
      state2 =
        TextArea.init(%{
          id: :ta,
          value: get_text(state),
          wrap: :word,
          width: 12,
          height: 10
        })

      assert state2.wrap == :word
      assert get_text(state2) == "hello wonderful world"
    end
  end

  describe "Input.parse integration" do
    alias ElixirOpentui.Input

    test "Input.parse events are accepted by TextArea.update" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})

      [event] = Input.parse("x")
      state = TextArea.update(:key, event, state)

      assert get_text(state) == "x"
    end

    test "typing multiple characters via Input.parse" do
      state = TextArea.init(%{id: :ta, value: "", width: 40, height: 10})

      events = Input.parse("hello")
      state = Enum.reduce(events, state, fn e, s -> TextArea.update(:key, e, s) end)

      assert get_text(state) == "hello"
    end
  end
end
