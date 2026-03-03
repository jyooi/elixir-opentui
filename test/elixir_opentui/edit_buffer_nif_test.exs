defmodule ElixirOpentui.EditBufferNIFTest do
  use ExUnit.Case, async: true

  @moduletag :nif

  alias ElixirOpentui.EditBufferNIF

  # ═══════════════════════════════════════════════════════════════════════════
  # Edit Buffer Tests
  # ═══════════════════════════════════════════════════════════════════════════

  describe "edit buffer: create and text" do
    test "create returns a reference" do
      buf = EditBufferNIF.create()
      assert is_reference(buf)
    end

    test "new buffer has empty text" do
      buf = EditBufferNIF.create()
      assert EditBufferNIF.get_text(buf) == ""
    end

    test "set_text and get_text round-trip" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello world")
      assert EditBufferNIF.get_text(buf) == "hello world"
    end

    test "set_text overwrites previous content" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "first")
      EditBufferNIF.set_text(buf, "second")
      assert EditBufferNIF.get_text(buf) == "second"
    end

    test "set_text with empty string" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "something")
      EditBufferNIF.set_text(buf, "")
      assert EditBufferNIF.get_text(buf) == ""
    end

    test "replace_text replaces content" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      EditBufferNIF.replace_text(buf, "world")
      assert EditBufferNIF.get_text(buf) == "world"
    end

    test "set_text with multi-line content" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "line1\nline2\nline3")
      assert EditBufferNIF.get_text(buf) == "line1\nline2\nline3"
    end

    test "set_text with trailing newline" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\n")
      assert EditBufferNIF.get_text(buf) == "hello\n"
    end
  end

  describe "edit buffer: cursor" do
    test "new buffer cursor at origin" do
      buf = EditBufferNIF.create()
      {row, col, offset} = EditBufferNIF.get_cursor(buf)
      assert row == 0
      assert col == 0
      assert offset == 0
    end

    test "set_cursor and get_cursor round-trip" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\nworld")
      EditBufferNIF.set_cursor(buf, 1, 3)
      {row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 1
      assert col == 3
    end

    test "set_cursor to beginning of second line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\nworld")
      EditBufferNIF.set_cursor(buf, 1, 0)
      {row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 1
      assert col == 0
    end

    test "set_cursor_by_offset" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello world")
      EditBufferNIF.set_cursor_by_offset(buf, 5)
      {_row, _col, offset} = EditBufferNIF.get_cursor(buf)
      assert offset == 5
    end

    test "set_cursor_by_offset to 0" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      EditBufferNIF.set_cursor_by_offset(buf, 3)
      EditBufferNIF.set_cursor_by_offset(buf, 0)
      {_row, _col, offset} = EditBufferNIF.get_cursor(buf)
      assert offset == 0
    end

    test "cursor position after set_text" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      {row, col, _offset} = EditBufferNIF.get_cursor(buf)
      # After set_text, cursor should be at position 0,0
      assert row == 0
      assert col == 0
    end
  end

  describe "edit buffer: cursor movement" do
    test "move_cursor_right advances cursor" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      EditBufferNIF.set_cursor(buf, 0, 0)
      EditBufferNIF.move_cursor_right(buf)
      {_row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert col == 1
    end

    test "move_cursor_left moves cursor back" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      EditBufferNIF.set_cursor(buf, 0, 3)
      EditBufferNIF.move_cursor_left(buf)
      {_row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert col == 2
    end

    test "move_cursor_left at beginning stays at beginning" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      EditBufferNIF.set_cursor(buf, 0, 0)
      EditBufferNIF.move_cursor_left(buf)
      {row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 0
      assert col == 0
    end

    test "move_cursor_right at end stays at end" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hi")
      EditBufferNIF.set_cursor(buf, 0, 2)
      EditBufferNIF.move_cursor_right(buf)
      {row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 0
      assert col == 2
    end

    test "move_cursor_down moves to next line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\nworld")
      EditBufferNIF.set_cursor(buf, 0, 0)
      EditBufferNIF.move_cursor_down(buf)
      {row, _col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 1
    end

    test "move_cursor_up moves to previous line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\nworld")
      EditBufferNIF.set_cursor(buf, 1, 0)
      EditBufferNIF.move_cursor_up(buf)
      {row, _col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 0
    end

    test "move_cursor_up on first line stays" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\nworld")
      EditBufferNIF.set_cursor(buf, 0, 0)
      EditBufferNIF.move_cursor_up(buf)
      {row, _col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 0
    end

    test "move_cursor_down on last line stays" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\nworld")
      EditBufferNIF.set_cursor(buf, 1, 0)
      EditBufferNIF.move_cursor_down(buf)
      {row, _col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 1
    end

    test "multiple right moves" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abcde")
      EditBufferNIF.set_cursor(buf, 0, 0)
      for _ <- 1..3, do: EditBufferNIF.move_cursor_right(buf)
      {_row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert col == 3
    end

    test "move right then left returns to same position" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      EditBufferNIF.set_cursor(buf, 0, 2)
      EditBufferNIF.move_cursor_right(buf)
      EditBufferNIF.move_cursor_left(buf)
      {_row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert col == 2
    end
  end

  describe "edit buffer: insert char" do
    test "insert single character" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "")
      EditBufferNIF.insert_char(buf, "a")
      assert EditBufferNIF.get_text(buf) == "a"
    end

    test "insert at beginning" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "bc")
      EditBufferNIF.set_cursor(buf, 0, 0)
      EditBufferNIF.insert_char(buf, "a")
      assert EditBufferNIF.get_text(buf) == "abc"
    end

    test "insert in middle" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "ac")
      EditBufferNIF.set_cursor(buf, 0, 1)
      EditBufferNIF.insert_char(buf, "b")
      assert EditBufferNIF.get_text(buf) == "abc"
    end

    test "insert multiple characters sequentially" do
      buf = EditBufferNIF.create()
      EditBufferNIF.insert_char(buf, "h")
      EditBufferNIF.insert_char(buf, "e")
      EditBufferNIF.insert_char(buf, "l")
      EditBufferNIF.insert_char(buf, "l")
      EditBufferNIF.insert_char(buf, "o")
      assert EditBufferNIF.get_text(buf) == "hello"
    end

    test "insert moves cursor forward" do
      buf = EditBufferNIF.create()
      EditBufferNIF.insert_char(buf, "a")
      {_row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert col == 1
    end

    test "insert multi-byte string" do
      buf = EditBufferNIF.create()
      EditBufferNIF.insert_char(buf, "hello")
      assert EditBufferNIF.get_text(buf) == "hello"
    end
  end

  describe "edit buffer: delete" do
    test "delete_char_backward removes char before cursor" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abc")
      EditBufferNIF.set_cursor(buf, 0, 3)
      EditBufferNIF.delete_char_backward(buf)
      assert EditBufferNIF.get_text(buf) == "ab"
    end

    test "delete_char_backward in middle" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abc")
      EditBufferNIF.set_cursor(buf, 0, 2)
      EditBufferNIF.delete_char_backward(buf)
      assert EditBufferNIF.get_text(buf) == "ac"
    end

    test "delete_char_forward removes char at cursor" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abc")
      EditBufferNIF.set_cursor(buf, 0, 0)
      EditBufferNIF.delete_char_forward(buf)
      assert EditBufferNIF.get_text(buf) == "bc"
    end

    test "delete_char_forward in middle" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abc")
      EditBufferNIF.set_cursor(buf, 0, 1)
      EditBufferNIF.delete_char_forward(buf)
      assert EditBufferNIF.get_text(buf) == "ac"
    end

    test "delete_char_backward moves cursor back" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abc")
      EditBufferNIF.set_cursor(buf, 0, 3)
      EditBufferNIF.delete_char_backward(buf)
      {_row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert col == 2
    end

    test "delete_char_forward keeps cursor position" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abc")
      EditBufferNIF.set_cursor(buf, 0, 1)
      EditBufferNIF.delete_char_forward(buf)
      {_row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert col == 1
    end

    test "delete all characters one by one backward" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abc")
      EditBufferNIF.set_cursor(buf, 0, 3)
      EditBufferNIF.delete_char_backward(buf)
      EditBufferNIF.delete_char_backward(buf)
      EditBufferNIF.delete_char_backward(buf)
      assert EditBufferNIF.get_text(buf) == ""
    end
  end

  describe "edit buffer: multi-line editing" do
    test "new_line inserts newline" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "helloworld")
      EditBufferNIF.set_cursor(buf, 0, 5)
      EditBufferNIF.new_line(buf)
      assert EditBufferNIF.get_text(buf) == "hello\nworld"
    end

    test "new_line at beginning" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      EditBufferNIF.set_cursor(buf, 0, 0)
      EditBufferNIF.new_line(buf)
      assert EditBufferNIF.get_text(buf) == "\nhello"
    end

    test "new_line at end" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      EditBufferNIF.set_cursor(buf, 0, 5)
      EditBufferNIF.new_line(buf)
      assert EditBufferNIF.get_text(buf) == "hello\n"
    end

    test "new_line moves cursor to next line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "helloworld")
      EditBufferNIF.set_cursor(buf, 0, 5)
      EditBufferNIF.new_line(buf)
      {row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 1
      assert col == 0
    end

    test "goto_line moves cursor to specified line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "line1\nline2\nline3")
      EditBufferNIF.goto_line(buf, 2)
      {row, _col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 2
    end

    test "goto_line 0 moves to first line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "line1\nline2\nline3")
      EditBufferNIF.goto_line(buf, 2)
      EditBufferNIF.goto_line(buf, 0)
      {row, _col, _offset} = EditBufferNIF.get_cursor(buf)
      assert row == 0
    end

    test "delete_line removes current line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "line1\nline2\nline3")
      EditBufferNIF.set_cursor(buf, 1, 0)
      EditBufferNIF.delete_line(buf)
      text = EditBufferNIF.get_text(buf)
      refute String.contains?(text, "line2")
    end

    test "multiple new_lines create multiple lines" do
      buf = EditBufferNIF.create()
      EditBufferNIF.new_line(buf)
      EditBufferNIF.new_line(buf)
      EditBufferNIF.new_line(buf)
      assert EditBufferNIF.get_line_count(buf) == 4
    end
  end

  describe "edit buffer: line count" do
    test "empty buffer has 1 line" do
      buf = EditBufferNIF.create()
      assert EditBufferNIF.get_line_count(buf) == 1
    end

    test "single line text has 1 line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      assert EditBufferNIF.get_line_count(buf) == 1
    end

    test "two lines" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\nworld")
      assert EditBufferNIF.get_line_count(buf) == 2
    end

    test "three lines" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "a\nb\nc")
      assert EditBufferNIF.get_line_count(buf) == 3
    end

    test "trailing newline adds a line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\n")
      assert EditBufferNIF.get_line_count(buf) == 2
    end

    test "line count after insert new_line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      assert EditBufferNIF.get_line_count(buf) == 1
      EditBufferNIF.set_cursor(buf, 0, 5)
      EditBufferNIF.new_line(buf)
      assert EditBufferNIF.get_line_count(buf) == 2
    end
  end

  describe "edit buffer: unicode" do
    test "ASCII round-trip" do
      buf = EditBufferNIF.create()
      text = "Hello, World! 0123456789"
      EditBufferNIF.set_text(buf, text)
      assert EditBufferNIF.get_text(buf) == text
    end

    test "CJK characters round-trip" do
      buf = EditBufferNIF.create()
      text = "你好世界"
      EditBufferNIF.set_text(buf, text)
      assert EditBufferNIF.get_text(buf) == text
    end

    test "emoji round-trip" do
      buf = EditBufferNIF.create()
      text = "Hello 🌍🎉"
      EditBufferNIF.set_text(buf, text)
      assert EditBufferNIF.get_text(buf) == text
    end

    test "mixed unicode round-trip" do
      buf = EditBufferNIF.create()
      text = "Hello 你好 🌍"
      EditBufferNIF.set_text(buf, text)
      assert EditBufferNIF.get_text(buf) == text
    end

    test "multi-byte insert" do
      buf = EditBufferNIF.create()
      EditBufferNIF.insert_char(buf, "日")
      EditBufferNIF.insert_char(buf, "本")
      assert EditBufferNIF.get_text(buf) == "日本"
    end

    test "accented characters round-trip" do
      buf = EditBufferNIF.create()
      text = "café résumé"
      EditBufferNIF.set_text(buf, text)
      assert EditBufferNIF.get_text(buf) == text
    end

    test "special symbols round-trip" do
      buf = EditBufferNIF.create()
      text = "→ ← ↑ ↓ ★ ♠ ♣"
      EditBufferNIF.set_text(buf, text)
      assert EditBufferNIF.get_text(buf) == text
    end
  end

  describe "edit buffer: undo/redo" do
    test "undo after insert returns to previous state" do
      buf = EditBufferNIF.create()
      EditBufferNIF.insert_char(buf, "a")
      EditBufferNIF.undo(buf)
      assert EditBufferNIF.get_text(buf) == ""
    end

    test "redo restores undone change" do
      buf = EditBufferNIF.create()
      EditBufferNIF.insert_char(buf, "a")
      EditBufferNIF.undo(buf)
      assert EditBufferNIF.get_text(buf) == ""
      EditBufferNIF.redo(buf)
      assert EditBufferNIF.get_text(buf) == "a"
    end

    test "undo on empty buffer returns nil" do
      buf = EditBufferNIF.create()
      result = EditBufferNIF.undo(buf)
      assert result == nil
    end

    test "redo with nothing to redo returns nil" do
      buf = EditBufferNIF.create()
      result = EditBufferNIF.redo(buf)
      assert result == nil
    end

    test "multiple undos" do
      buf = EditBufferNIF.create()
      EditBufferNIF.insert_char(buf, "a")
      EditBufferNIF.insert_char(buf, "b")
      EditBufferNIF.insert_char(buf, "c")
      EditBufferNIF.undo(buf)
      EditBufferNIF.undo(buf)
      EditBufferNIF.undo(buf)
      assert EditBufferNIF.get_text(buf) == ""
    end

    test "undo then insert clears redo stack" do
      buf = EditBufferNIF.create()
      EditBufferNIF.insert_char(buf, "a")
      EditBufferNIF.undo(buf)
      EditBufferNIF.insert_char(buf, "b")
      # redo should return nil since we branched
      result = EditBufferNIF.redo(buf)
      assert result == nil
      assert EditBufferNIF.get_text(buf) == "b"
    end

    test "undo after delete_char_backward" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abc")
      EditBufferNIF.set_cursor(buf, 0, 3)
      EditBufferNIF.delete_char_backward(buf)
      assert EditBufferNIF.get_text(buf) == "ab"
      EditBufferNIF.undo(buf)
      assert EditBufferNIF.get_text(buf) == "abc"
    end

    test "undo after new_line" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "helloworld")
      EditBufferNIF.set_cursor(buf, 0, 5)
      EditBufferNIF.new_line(buf)
      assert EditBufferNIF.get_text(buf) == "hello\nworld"
      EditBufferNIF.undo(buf)
      assert EditBufferNIF.get_text(buf) == "helloworld"
    end
  end

  describe "edit buffer: edge cases" do
    test "operations on empty buffer" do
      buf = EditBufferNIF.create()
      assert EditBufferNIF.get_text(buf) == ""
      assert EditBufferNIF.get_line_count(buf) == 1
      {row, col, offset} = EditBufferNIF.get_cursor(buf)
      assert row == 0
      assert col == 0
      assert offset == 0
    end

    test "cursor at boundaries after operations" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "ab")
      EditBufferNIF.set_cursor(buf, 0, 0)
      EditBufferNIF.move_cursor_left(buf)
      {_row, col, _offset} = EditBufferNIF.get_cursor(buf)
      assert col == 0
    end

    test "insert into empty buffer" do
      buf = EditBufferNIF.create()
      EditBufferNIF.insert_char(buf, "x")
      assert EditBufferNIF.get_text(buf) == "x"
    end

    test "repeated set_text" do
      buf = EditBufferNIF.create()

      for i <- 1..10 do
        text = "iteration #{i}"
        EditBufferNIF.set_text(buf, text)
        assert EditBufferNIF.get_text(buf) == text
      end
    end

    test "large text round-trip" do
      buf = EditBufferNIF.create()
      text = String.duplicate("abcdefghij\n", 100)
      EditBufferNIF.set_text(buf, text)
      assert EditBufferNIF.get_text(buf) == text
    end

    test "set_cursor_by_offset across newline boundary" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "abc\ndef")
      # offset 4 = 'd' on second line
      EditBufferNIF.set_cursor_by_offset(buf, 4)
      {row, col, offset} = EditBufferNIF.get_cursor(buf)
      assert offset == 4
      assert row == 1
      assert col == 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # Editor View Tests
  # ═══════════════════════════════════════════════════════════════════════════

  defp create_view(text \\ "", width \\ 40, height \\ 10) do
    buf = EditBufferNIF.create()
    if text != "", do: EditBufferNIF.set_text(buf, text)
    view = EditBufferNIF.create_editor_view(buf, width, height)
    {buf, view}
  end

  describe "editor view: create and viewport" do
    test "create_editor_view returns a reference" do
      {_buf, view} = create_view()
      assert is_reference(view)
    end

    test "get_viewport returns dimensions" do
      {_buf, view} = create_view("hello", 40, 10)
      result = EditBufferNIF.view_get_viewport(view)
      assert is_tuple(result)
      {_ox, _oy, w, h} = result
      assert w == 40
      assert h == 10
    end

    test "set_viewport_size changes dimensions" do
      {_buf, view} = create_view("hello", 40, 10)
      EditBufferNIF.view_set_viewport_size(view, 80, 24)
      {_ox, _oy, w, h} = EditBufferNIF.view_get_viewport(view)
      assert w == 80
      assert h == 24
    end

    test "viewport starts at origin" do
      {_buf, view} = create_view("hello")
      {ox, oy, _w, _h} = EditBufferNIF.view_get_viewport(view)
      assert ox == 0
      assert oy == 0
    end

    test "small viewport" do
      {_buf, view} = create_view("hello", 5, 3)
      {_ox, _oy, w, h} = EditBufferNIF.view_get_viewport(view)
      assert w == 5
      assert h == 3
    end
  end

  describe "editor view: visual cursor" do
    test "initial visual cursor at origin" do
      {_buf, view} = create_view("hello")
      {vr, vc, lr, lc, offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 0
      assert vc == 0
      assert lr == 0
      assert lc == 0
      assert offset == 0
    end

    test "visual cursor after moving right" do
      {buf, view} = create_view("hello")
      EditBufferNIF.move_cursor_right(buf)
      EditBufferNIF.move_cursor_right(buf)
      {_vr, vc, _lr, lc, offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vc == 2
      assert lc == 2
      assert offset == 2
    end

    test "visual cursor on second line" do
      {buf, view} = create_view("hello\nworld")
      EditBufferNIF.set_cursor(buf, 1, 3)
      {vr, vc, lr, lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 1
      assert vc == 3
      assert lr == 1
      assert lc == 3
    end

    test "visual cursor tracks insert" do
      {buf, view} = create_view("")
      EditBufferNIF.insert_char(buf, "abc")
      {_vr, vc, _lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vc == 3
    end
  end

  describe "editor view: wrap modes" do
    test "set wrap mode none" do
      {_buf, view} = create_view("hello world test")
      EditBufferNIF.view_set_wrap_mode(view, 0)
      # Should not raise
      count = EditBufferNIF.view_get_total_virtual_line_count(view)
      assert count >= 1
    end

    test "set wrap mode char" do
      {_buf, view} = create_view("hello world this is a test", 10, 5)
      EditBufferNIF.view_set_wrap_mode(view, 1)
      count = EditBufferNIF.view_get_total_virtual_line_count(view)
      # 26 chars in width 10 should wrap to at least 3 virtual lines
      assert count >= 3
    end

    test "set wrap mode word" do
      {_buf, view} = create_view("hello world this is a test", 10, 5)
      EditBufferNIF.view_set_wrap_mode(view, 2)
      count = EditBufferNIF.view_get_total_virtual_line_count(view)
      assert count >= 2
    end

    test "no wrap mode gives 1 virtual line per logical line" do
      {_buf, view} = create_view("short", 40, 10)
      EditBufferNIF.view_set_wrap_mode(view, 0)
      count = EditBufferNIF.view_get_total_virtual_line_count(view)
      assert count == 1
    end

    test "char wrap with multi-line text" do
      {_buf, view} = create_view("abcdefghij\nklmnopqrst", 5, 10)
      EditBufferNIF.view_set_wrap_mode(view, 1)
      count = EditBufferNIF.view_get_total_virtual_line_count(view)
      # Each 10-char line should wrap to 2 virtual lines in width 5
      assert count >= 4
    end

    test "invalid wrap mode defaults to none" do
      {_buf, view} = create_view("hello")
      # mode 99 should default to none
      EditBufferNIF.view_set_wrap_mode(view, 99)
      count = EditBufferNIF.view_get_total_virtual_line_count(view)
      assert count >= 1
    end
  end

  describe "editor view: visual cursor movement" do
    test "move_down_visual on single line stays" do
      {_buf, view} = create_view("hello")
      EditBufferNIF.view_move_down_visual(view)
      {vr, _vc, _lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 0
    end

    test "move_up_visual on first line stays" do
      {_buf, view} = create_view("hello\nworld")
      EditBufferNIF.view_move_up_visual(view)
      {vr, _vc, _lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 0
    end

    test "move_down_visual to next line" do
      {_buf, view} = create_view("hello\nworld")
      EditBufferNIF.view_move_down_visual(view)
      {vr, _vc, lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 1
      assert lr == 1
    end

    test "move_down then up returns to original" do
      {_buf, view} = create_view("hello\nworld")
      EditBufferNIF.view_move_down_visual(view)
      EditBufferNIF.view_move_up_visual(view)
      {vr, _vc, lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 0
      assert lr == 0
    end

    test "move_down_visual multiple lines" do
      {_buf, view} = create_view("line1\nline2\nline3\nline4")
      EditBufferNIF.view_move_down_visual(view)
      EditBufferNIF.view_move_down_visual(view)
      {vr, _vc, lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 2
      assert lr == 2
    end

    test "move_down_visual with char wrap" do
      {_buf, view} = create_view("abcdefghij", 5, 10)
      EditBufferNIF.view_set_wrap_mode(view, 1)
      EditBufferNIF.view_move_down_visual(view)
      {vr, _vc, _lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      # Should move to the wrapped portion of the same logical line
      assert vr == 1
    end
  end

  describe "editor view: scroll and viewport" do
    test "scroll margin can be set" do
      {_buf, view} = create_view("hello\nworld")
      # Should not raise
      EditBufferNIF.view_set_scroll_margin(view, 0.2)
    end

    test "viewport scrolls when cursor moves beyond visible area" do
      lines = Enum.map_join(1..30, "\n", &"line #{&1}")
      {_buf, view} = create_view(lines, 40, 5)
      # Move down many lines
      for _ <- 1..20, do: EditBufferNIF.view_move_down_visual(view)
      {_ox, oy, _w, _h} = EditBufferNIF.view_get_viewport(view)
      assert oy > 0
    end

    test "viewport updates after resize" do
      {_buf, view} = create_view("hello", 40, 10)
      EditBufferNIF.view_set_viewport_size(view, 20, 5)
      {_ox, _oy, w, h} = EditBufferNIF.view_get_viewport(view)
      assert w == 20
      assert h == 5
    end
  end

  describe "editor view: total virtual line count" do
    test "single line no wrap" do
      {_buf, view} = create_view("hello", 40, 10)
      EditBufferNIF.view_set_wrap_mode(view, 0)
      assert EditBufferNIF.view_get_total_virtual_line_count(view) == 1
    end

    test "multiple lines no wrap" do
      {_buf, view} = create_view("a\nb\nc", 40, 10)
      EditBufferNIF.view_set_wrap_mode(view, 0)
      assert EditBufferNIF.view_get_total_virtual_line_count(view) == 3
    end

    test "wrapping increases virtual line count" do
      {_buf, view} = create_view("abcdefghijklmnopqrst", 5, 10)
      EditBufferNIF.view_set_wrap_mode(view, 1)
      count = EditBufferNIF.view_get_total_virtual_line_count(view)
      # 20 chars / 5 width = 4 virtual lines
      assert count == 4
    end

    test "empty buffer has 1 virtual line" do
      {_buf, view} = create_view("", 40, 10)
      assert EditBufferNIF.view_get_total_virtual_line_count(view) == 1
    end
  end

  describe "editor view: selection" do
    test "no selection initially" do
      {_buf, view} = create_view("hello world")
      assert EditBufferNIF.view_get_selection(view) == nil
    end

    test "set and get selection" do
      {_buf, view} = create_view("hello world")
      EditBufferNIF.view_set_selection(view, 0, 5)
      {start_off, end_off} = EditBufferNIF.view_get_selection(view)
      assert start_off == 0
      assert end_off == 5
    end

    test "reset selection clears it" do
      {_buf, view} = create_view("hello world")
      EditBufferNIF.view_set_selection(view, 0, 5)
      EditBufferNIF.view_reset_selection(view)
      assert EditBufferNIF.view_get_selection(view) == nil
    end

    test "get_selected_text returns selected portion" do
      {_buf, view} = create_view("hello world")
      EditBufferNIF.view_set_selection(view, 0, 5)
      assert EditBufferNIF.view_get_selected_text(view) == "hello"
    end

    test "get_selected_text with no selection returns empty" do
      {_buf, view} = create_view("hello world")
      assert EditBufferNIF.view_get_selected_text(view) == ""
    end

    test "set selection in middle of text" do
      {_buf, view} = create_view("hello world")
      EditBufferNIF.view_set_selection(view, 6, 11)
      assert EditBufferNIF.view_get_selected_text(view) == "world"
    end

    test "delete_selected_text removes selection" do
      {buf, view} = create_view("hello world")
      EditBufferNIF.view_set_selection(view, 5, 11)
      EditBufferNIF.view_delete_selected_text(view)
      assert EditBufferNIF.get_text(buf) == "hello"
    end

    test "selection after delete is cleared" do
      {_buf, view} = create_view("hello world")
      EditBufferNIF.view_set_selection(view, 5, 11)
      EditBufferNIF.view_delete_selected_text(view)
      assert EditBufferNIF.view_get_selection(view) == nil
    end

    test "select entire text" do
      {_buf, view} = create_view("hello")
      EditBufferNIF.view_set_selection(view, 0, 5)
      assert EditBufferNIF.view_get_selected_text(view) == "hello"
    end

    test "overwrite selection" do
      {_buf, view} = create_view("hello world")
      EditBufferNIF.view_set_selection(view, 0, 3)
      EditBufferNIF.view_set_selection(view, 2, 7)
      {start_off, end_off} = EditBufferNIF.view_get_selection(view)
      assert start_off == 2
      assert end_off == 7
    end

    test "select across newline" do
      {_buf, view} = create_view("hello\nworld")
      EditBufferNIF.view_set_selection(view, 3, 9)
      text = EditBufferNIF.view_get_selected_text(view)
      assert text == "lo\nwor"
    end

    test "delete selected text across newline" do
      {buf, view} = create_view("hello\nworld")
      EditBufferNIF.view_set_selection(view, 3, 9)
      EditBufferNIF.view_delete_selected_text(view)
      assert EditBufferNIF.get_text(buf) == "helld"
    end
  end

  describe "editor view: cursor by offset" do
    test "view_set_cursor_by_offset moves cursor" do
      {_buf, view} = create_view("hello world")
      EditBufferNIF.view_set_cursor_by_offset(view, 6)
      {_vr, vc, _lr, lc, offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert offset == 6
      assert vc == 6
      assert lc == 6
    end

    test "view_set_cursor_by_offset to beginning" do
      {_buf, view} = create_view("hello world")
      EditBufferNIF.view_set_cursor_by_offset(view, 5)
      EditBufferNIF.view_set_cursor_by_offset(view, 0)
      {_vr, vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert offset == 0
      assert vc == 0
    end

    test "view_set_cursor_by_offset to second line" do
      {_buf, view} = create_view("hello\nworld")
      # offset 6 = 'w' on second line
      EditBufferNIF.view_set_cursor_by_offset(view, 6)
      {vr, vc, lr, _lc, offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert offset == 6
      assert vr == 1
      assert lr == 1
      assert vc == 0
    end
  end

  describe "editor view: word boundaries" do
    test "get_next_word_boundary from beginning" do
      {_buf, view} = create_view("hello world")
      {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_next_word_boundary(view)
      # Should jump past "hello" to the space or "world"
      assert offset > 0
    end

    test "get_prev_word_boundary from end" do
      {buf, view} = create_view("hello world")
      EditBufferNIF.set_cursor(buf, 0, 11)
      {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_prev_word_boundary(view)
      # Should jump back to beginning of "world"
      assert offset < 11
    end

    test "get_next_word_boundary at end stays" do
      {buf, view} = create_view("hello")
      EditBufferNIF.set_cursor(buf, 0, 5)
      {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_next_word_boundary(view)
      assert offset == 5
    end

    test "get_prev_word_boundary at beginning stays" do
      {_buf, view} = create_view("hello")
      {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_prev_word_boundary(view)
      assert offset == 0
    end

    test "word boundary across multiple words" do
      {_buf, view} = create_view("one two three")
      # From beginning, next word boundary should skip past "one"
      {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_next_word_boundary(view)
      assert offset >= 3
    end
  end

  describe "editor view: line boundaries" do
    test "get_eol returns end of logical line" do
      {_buf, view} = create_view("hello\nworld")
      {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_eol(view)
      # End of first line "hello" is offset 5
      assert offset == 5
    end

    test "get_eol on second line" do
      {buf, view} = create_view("hello\nworld")
      EditBufferNIF.set_cursor(buf, 1, 0)
      {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_eol(view)
      # End of "world" is offset 11
      assert offset == 11
    end

    test "get_visual_sol returns start of visual line" do
      {buf, view} = create_view("hello\nworld")
      EditBufferNIF.set_cursor(buf, 0, 3)
      {_vr, vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_sol(view)
      assert offset == 0
      assert vc == 0
    end

    test "get_visual_eol returns end of visual line" do
      {_buf, view} = create_view("hello\nworld")
      {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_eol(view)
      # Visual end of first line
      assert offset == 5
    end

    test "get_visual_sol on second line" do
      {buf, view} = create_view("hello\nworld")
      EditBufferNIF.set_cursor(buf, 1, 3)
      {_vr, vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_sol(view)
      assert offset == 6
      assert vc == 0
    end

    test "visual_sol with char wrap" do
      {buf, view} = create_view("abcdefghij", 5, 10)
      EditBufferNIF.view_set_wrap_mode(view, 1)
      # Move cursor to wrapped portion
      EditBufferNIF.set_cursor(buf, 0, 7)
      {_vr, vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_sol(view)
      # Visual start of the second wrapped line should be offset 5
      assert offset == 5
      assert vc == 0
    end

    test "visual_eol with char wrap" do
      {_buf, view} = create_view("abcdefghij", 5, 10)
      EditBufferNIF.view_set_wrap_mode(view, 1)
      # Cursor at beginning, visual EOL points to last char of first wrap segment
      {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_eol(view)
      assert offset == 4
    end
  end

  describe "editor view: combined operations" do
    test "insert then check view cursor" do
      {buf, view} = create_view("")
      EditBufferNIF.insert_char(buf, "hello")
      {_vr, vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vc == 5
      assert offset == 5
    end

    test "insert newline and navigate" do
      {buf, view} = create_view("")
      EditBufferNIF.insert_char(buf, "line1")
      EditBufferNIF.new_line(buf)
      EditBufferNIF.insert_char(buf, "line2")
      {vr, _vc, lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 1
      assert lr == 1
    end

    test "select and delete then check text" do
      {buf, view} = create_view("abcdef")
      EditBufferNIF.view_set_selection(view, 2, 4)
      EditBufferNIF.view_delete_selected_text(view)
      assert EditBufferNIF.get_text(buf) == "abef"
    end

    test "undo reflects in view" do
      {buf, view} = create_view("")
      EditBufferNIF.insert_char(buf, "hello")
      EditBufferNIF.undo(buf)
      {_vr, vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert offset == 0
      assert vc == 0
    end

    test "wrap mode change updates virtual line count" do
      {_buf, view} = create_view("abcdefghijklmnopqrst", 5, 10)
      EditBufferNIF.view_set_wrap_mode(view, 0)
      count_no_wrap = EditBufferNIF.view_get_total_virtual_line_count(view)
      EditBufferNIF.view_set_wrap_mode(view, 1)
      count_char_wrap = EditBufferNIF.view_get_total_virtual_line_count(view)
      assert count_char_wrap > count_no_wrap
    end

    test "selection with unicode text" do
      {_buf, view} = create_view("hello world")
      EditBufferNIF.view_set_selection(view, 0, 5)
      text = EditBufferNIF.view_get_selected_text(view)
      assert text == "hello"
    end

    test "viewport after many inserts" do
      {buf, view} = create_view("", 40, 5)

      for i <- 1..20 do
        EditBufferNIF.insert_char(buf, "line #{i}")
        EditBufferNIF.new_line(buf)
      end

      {_ox, oy, _w, _h} = EditBufferNIF.view_get_viewport(view)
      # Viewport should have scrolled down
      assert oy > 0
    end
  end

  describe "editor view: edge cases" do
    test "view on empty buffer" do
      {_buf, view} = create_view("")
      {vr, vc, lr, lc, offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 0
      assert vc == 0
      assert lr == 0
      assert lc == 0
      assert offset == 0
    end

    test "view_get_total_virtual_line_count empty" do
      {_buf, view} = create_view("")
      assert EditBufferNIF.view_get_total_virtual_line_count(view) == 1
    end

    test "selection on empty text" do
      {_buf, view} = create_view("")
      EditBufferNIF.view_set_selection(view, 0, 0)
      assert EditBufferNIF.view_get_selected_text(view) == ""
    end

    test "reset selection when none set" do
      {_buf, view} = create_view("hello")
      # Should not raise
      EditBufferNIF.view_reset_selection(view)
      assert EditBufferNIF.view_get_selection(view) == nil
    end

    test "move up visual on empty buffer" do
      {_buf, view} = create_view("")
      EditBufferNIF.view_move_up_visual(view)
      {vr, vc, _lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 0
      assert vc == 0
    end

    test "move down visual on empty buffer" do
      {_buf, view} = create_view("")
      EditBufferNIF.view_move_down_visual(view)
      {vr, vc, _lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 0
      assert vc == 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # GC Safety Tests (Fix #2/#3: destructors + dangling reference prevention)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "gc safety" do
    test "EditorView survives after EditBuffer ref is dropped" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello world")
      view = EditBufferNIF.create_editor_view(buf, 40, 10)

      # Drop all Elixir references to EditBuffer
      buf = nil
      _ = buf
      :erlang.garbage_collect()

      # EditorView should still work — its nested resource ref keeps EditBuffer alive
      {vr, vc, _lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(view)
      assert vr == 0
      assert vc == 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # Right-Sized Allocation Tests (Fix #1)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "right-sized allocations" do
    test "large text round-trips correctly" do
      buf = EditBufferNIF.create()
      large_text = String.duplicate("abcdefghij\n", 10_000)
      EditBufferNIF.set_text(buf, large_text)
      assert EditBufferNIF.get_text(buf) == large_text
    end

    test "empty buffer get_text returns empty string" do
      buf = EditBufferNIF.create()
      assert EditBufferNIF.get_text(buf) == ""
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # Display Width Tests (Fix #4)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "get_text_display_width" do
    test "ASCII text width equals grapheme count" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello")
      assert EditBufferNIF.get_text_display_width(buf) == 5
    end

    test "multiline text includes newlines in weight" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hello\nworld")
      # weight = display_width(5) + newline(1) + display_width(5) = 11
      assert EditBufferNIF.get_text_display_width(buf) == 11
    end

    test "CJK characters are double-width" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "你好世界")
      # 4 CJK chars × 2 display-width = 8
      assert EditBufferNIF.get_text_display_width(buf) == 8
    end

    test "empty buffer returns 0" do
      buf = EditBufferNIF.create()
      assert EditBufferNIF.get_text_display_width(buf) == 0
    end

    test "mixed ASCII and CJK" do
      buf = EditBufferNIF.create()
      EditBufferNIF.set_text(buf, "hi你好")
      # 2 ASCII + 2 CJK × 2 = 6
      assert EditBufferNIF.get_text_display_width(buf) == 6
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # Visible Lines Tests (Fix #5)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "view_get_visible_lines" do
    test "returns lines for simple text" do
      {_buf, view} = create_view("hello\nworld", 40, 10)
      lines = EditBufferNIF.view_get_visible_lines(view)
      assert is_list(lines)
      assert length(lines) == 2
      assert Enum.at(lines, 0) == "hello"
      assert Enum.at(lines, 1) == "world"
    end

    test "returns empty list for empty buffer" do
      {_buf, view} = create_view("", 40, 10)
      lines = EditBufferNIF.view_get_visible_lines(view)
      assert is_list(lines)
    end

    test "char wrap splits long lines" do
      {_buf, view} = create_view("abcdefghij", 5, 10)
      EditBufferNIF.view_set_wrap_mode(view, 1)
      lines = EditBufferNIF.view_get_visible_lines(view)
      assert length(lines) == 2
      assert Enum.at(lines, 0) == "abcde"
      assert Enum.at(lines, 1) == "fghij"
    end

    test "word wrap respects word boundaries" do
      {_buf, view} = create_view("hello world", 8, 10)
      EditBufferNIF.view_set_wrap_mode(view, 2)
      lines = EditBufferNIF.view_get_visible_lines(view)
      assert length(lines) >= 2
      assert Enum.at(lines, 0) =~ "hello"
    end

    test "no wrap mode returns logical lines" do
      {_buf, view} = create_view("hello\nworld\nfoo", 40, 10)
      EditBufferNIF.view_set_wrap_mode(view, 0)
      lines = EditBufferNIF.view_get_visible_lines(view)
      assert length(lines) == 3
      assert Enum.at(lines, 0) == "hello"
      assert Enum.at(lines, 1) == "world"
      assert Enum.at(lines, 2) == "foo"
    end

    test "viewport slices visible region only" do
      text = Enum.map_join(1..20, "\n", &"line#{&1}")
      {_buf, view} = create_view(text, 40, 5)
      EditBufferNIF.view_set_wrap_mode(view, 0)
      lines = EditBufferNIF.view_get_visible_lines(view)
      # Viewport is 5 lines tall, should return at most 5 lines
      assert length(lines) <= 5
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # Selection Visual Coords Tests (Fix #6)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "view_selection_visual_coords" do
    test "returns 4-tuple of coordinates" do
      {_buf, view} = create_view("hello world", 40, 10)
      result = EditBufferNIF.view_selection_visual_coords(view, 0, 5)
      assert is_tuple(result)
      assert tuple_size(result) == 4
    end

    test "single line selection" do
      {_buf, view} = create_view("hello world", 40, 10)
      {sr, sc, er, ec} = EditBufferNIF.view_selection_visual_coords(view, 0, 5)
      assert sr == 0
      assert sc == 0
      assert er == 0
      assert ec == 5
    end

    test "multi-line selection" do
      {_buf, view} = create_view("hello\nworld", 40, 10)
      # Select from offset 0 ("h") to offset 8 ("or" in "world")
      # "hello\n" = 6 chars, so offset 8 = "wo" in "world"
      {sr, _sc, er, _ec} = EditBufferNIF.view_selection_visual_coords(view, 0, 8)
      assert sr == 0
      assert er == 1
    end

    test "zero-length selection" do
      {_buf, view} = create_view("hello", 40, 10)
      {sr, sc, er, ec} = EditBufferNIF.view_selection_visual_coords(view, 3, 3)
      assert sr == er
      assert sc == ec
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # Viewport Scroll Tests (Fix #8)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "view_set_viewport" do
    test "sets viewport and reads it back" do
      text = Enum.map_join(1..20, "\n", &"line#{&1}")
      {_buf, view} = create_view(text, 40, 5)

      EditBufferNIF.view_set_viewport(view, 0, 3, 40, 5)
      {ox, oy, w, h} = EditBufferNIF.view_get_viewport(view)
      assert ox == 0
      assert oy == 3
      assert w == 40
      assert h == 5
    end

    test "scrolled viewport returns different visible lines" do
      text = Enum.map_join(1..20, "\n", &"line#{&1}")
      {_buf, view} = create_view(text, 40, 3)
      EditBufferNIF.view_set_wrap_mode(view, 0)

      # Get lines at top
      lines_top = EditBufferNIF.view_get_visible_lines(view)

      # Move cursor down to line 7 so viewport follows, then set viewport to line 5
      for _ <- 1..7, do: EditBufferNIF.view_move_down_visual(view)
      EditBufferNIF.view_set_viewport(view, 0, 5, 40, 3)
      lines_scrolled = EditBufferNIF.view_get_visible_lines(view)

      assert lines_top != lines_scrolled
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # wrap_mode_int/1 Tests (Fix #14)
  # ═══════════════════════════════════════════════════════════════════════════

  describe "wrap_mode_int" do
    test "maps :none to 0" do
      assert EditBufferNIF.wrap_mode_int(:none) == 0
    end

    test "maps :char to 1" do
      assert EditBufferNIF.wrap_mode_int(:char) == 1
    end

    test "maps :word to 2" do
      assert EditBufferNIF.wrap_mode_int(:word) == 2
    end

    test "raises on invalid mode" do
      assert_raise KeyError, fn ->
        EditBufferNIF.wrap_mode_int(:invalid)
      end
    end
  end
end
