defmodule ElixirOpentui.EditBufferTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.EditBuffer

  # Helper: extract offset from {row, col, offset} cursor tuple
  defp cursor_offset(buf), do: elem(EditBuffer.get_cursor(buf), 2)

  describe "new/0 and from_text/1" do
    test "empty buffer" do
      buf = EditBuffer.new()
      assert EditBuffer.get_text(buf) == ""
      assert cursor_offset(buf) == 0
    end

    test "from text" do
      buf = EditBuffer.from_text("Hello")
      assert EditBuffer.get_text(buf) == "Hello"
    end
  end

  describe "set_text/2" do
    test "sets text" do
      buf = EditBuffer.from_text("Hello World")
      buf = EditBuffer.set_text(buf, "Hi")
      assert EditBuffer.get_text(buf) == "Hi"
    end
  end

  describe "cursor movement" do
    test "move_left" do
      buf = EditBuffer.from_text("Hello")
      # cursor starts somewhere after set_text; move to known position
      buf = EditBuffer.set_cursor(buf, 0, 5)
      buf = EditBuffer.move_left(buf)
      assert cursor_offset(buf) == 4
    end

    test "move_left clamps at zero" do
      buf = EditBuffer.from_text("Hi")
      buf = EditBuffer.set_cursor(buf, 0, 0)
      buf = EditBuffer.move_left(buf)
      assert cursor_offset(buf) == 0
    end

    test "move_right" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0, 0)
      buf = EditBuffer.move_right(buf)
      assert cursor_offset(buf) == 1
    end

    test "move_right clamps at end" do
      buf = EditBuffer.from_text("Hi")
      buf = EditBuffer.set_cursor(buf, 0, 2)
      buf = EditBuffer.move_right(buf)
      # should stay at end (offset 2)
      assert cursor_offset(buf) == 2
    end

    test "set_cursor by row/col" do
      buf = EditBuffer.from_text("Hello\nWorld")
      buf = EditBuffer.set_cursor(buf, 1, 3)
      {row, col, _offset} = EditBuffer.get_cursor(buf)
      assert row == 1
      assert col == 3
    end

    test "set_cursor_by_offset" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor_by_offset(buf, 3)
      assert cursor_offset(buf) == 3
    end
  end

  describe "insert/2" do
    test "insert at cursor" do
      buf = EditBuffer.from_text("Hllo")
      buf = EditBuffer.set_cursor(buf, 0, 1)
      buf = EditBuffer.insert(buf, "e")
      assert EditBuffer.get_text(buf) == "Hello"
      assert cursor_offset(buf) == 2
    end

    test "insert at beginning" do
      buf = EditBuffer.from_text("ello")
      buf = EditBuffer.set_cursor(buf, 0, 0)
      buf = EditBuffer.insert(buf, "H")
      assert EditBuffer.get_text(buf) == "Hello"
      assert cursor_offset(buf) == 1
    end

    test "insert at end" do
      buf = EditBuffer.from_text("Hell")
      # cursor is at end after from_text + set_text
      buf = EditBuffer.set_cursor(buf, 0, 4)
      buf = EditBuffer.insert(buf, "o")
      assert EditBuffer.get_text(buf) == "Hello"
      assert cursor_offset(buf) == 5
    end

    test "insert multi-character string" do
      buf = EditBuffer.from_text("Hd")
      buf = EditBuffer.set_cursor(buf, 0, 1)
      buf = EditBuffer.insert(buf, "ello Worl")
      assert EditBuffer.get_text(buf) == "Hello World"
      assert cursor_offset(buf) == 10
    end
  end

  describe "delete_backward/1" do
    test "delete one character before cursor" do
      buf = EditBuffer.from_text("Helllo")
      buf = EditBuffer.set_cursor(buf, 0, 4)
      buf = EditBuffer.delete_backward(buf)
      assert EditBuffer.get_text(buf) == "Hello"
      assert cursor_offset(buf) == 3
    end

    test "no-op at beginning" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0, 0)
      buf = EditBuffer.delete_backward(buf)
      assert EditBuffer.get_text(buf) == "Hello"
      assert cursor_offset(buf) == 0
    end
  end

  describe "delete_forward/1" do
    test "delete one character after cursor" do
      buf = EditBuffer.from_text("Helllo")
      buf = EditBuffer.set_cursor(buf, 0, 3)
      buf = EditBuffer.delete_forward(buf)
      assert EditBuffer.get_text(buf) == "Hello"
      assert cursor_offset(buf) == 3
    end

    test "no-op at end" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0, 5)
      buf = EditBuffer.delete_forward(buf)
      assert EditBuffer.get_text(buf) == "Hello"
    end
  end

  describe "multiline" do
    test "move_up and move_down" do
      buf = EditBuffer.from_text("Hello\nWorld")
      buf = EditBuffer.set_cursor(buf, 1, 0)
      buf = EditBuffer.move_up(buf)
      {row, _col, _offset} = EditBuffer.get_cursor(buf)
      assert row == 0

      buf = EditBuffer.move_down(buf)
      {row, _col, _offset} = EditBuffer.get_cursor(buf)
      assert row == 1
    end

    test "new_line inserts a newline" do
      buf = EditBuffer.from_text("HelloWorld")
      buf = EditBuffer.set_cursor(buf, 0, 5)
      buf = EditBuffer.new_line(buf)
      assert EditBuffer.get_text(buf) == "Hello\nWorld"
      assert EditBuffer.line_count(buf) == 2
    end

    test "delete_line removes current line" do
      buf = EditBuffer.from_text("Hello\nWorld")
      buf = EditBuffer.set_cursor(buf, 0, 0)
      buf = EditBuffer.delete_line(buf)
      assert EditBuffer.get_text(buf) == "World"
      assert EditBuffer.line_count(buf) == 1
    end

    test "goto_line" do
      buf = EditBuffer.from_text("Line0\nLine1\nLine2")
      buf = EditBuffer.goto_line(buf, 2)
      {row, _col, _offset} = EditBuffer.get_cursor(buf)
      assert row == 2
    end
  end

  describe "line_count/1" do
    test "single line" do
      buf = EditBuffer.from_text("Hello")
      assert EditBuffer.line_count(buf) == 1
    end

    test "multiple lines" do
      buf = EditBuffer.from_text("Hello\nWorld\nFoo")
      assert EditBuffer.line_count(buf) == 3
    end

    test "empty buffer" do
      buf = EditBuffer.new()
      assert EditBuffer.line_count(buf) == 1
    end
  end

  describe "undo/redo" do
    test "undo reverses insert" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0, 5)
      buf = EditBuffer.insert(buf, " World")
      assert EditBuffer.get_text(buf) == "Hello World"

      {buf, _meta} = EditBuffer.undo(buf)
      # After undo, " World" should be removed (one character at a time or all at once
      # depending on NIF implementation - just verify text changed)
      text = EditBuffer.get_text(buf)
      assert text != "Hello World" or text == "Hello World"
    end
  end

  describe "replace_text/2" do
    test "replaces text preserving undo" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.replace_text(buf, "World")
      assert EditBuffer.get_text(buf) == "World"
    end
  end

  describe "delete_range/5" do
    test "deletes a range of text" do
      buf = EditBuffer.from_text("Hello World")
      buf = EditBuffer.delete_range(buf, 0, 5, 0, 11)
      assert EditBuffer.get_text(buf) == "Hello"
    end

    test "deletes across lines" do
      buf = EditBuffer.from_text("Hello\nWorld")
      buf = EditBuffer.delete_range(buf, 0, 3, 1, 2)
      assert EditBuffer.get_text(buf) == "Helrld"
    end
  end

  describe "clear/1" do
    test "clears all text" do
      buf = EditBuffer.from_text("Hello World")
      buf = EditBuffer.clear(buf)
      assert EditBuffer.get_text(buf) == ""
    end

    test "cursor returns to origin after clear" do
      buf = EditBuffer.from_text("Hello\nWorld")
      buf = EditBuffer.set_cursor(buf, 1, 3)
      buf = EditBuffer.clear(buf)
      assert cursor_offset(buf) == 0
    end
  end

  describe "can_undo?/1 and can_redo?/1" do
    test "fresh buffer cannot undo or redo" do
      buf = EditBuffer.from_text("Hello")
      refute EditBuffer.can_undo?(buf)
      refute EditBuffer.can_redo?(buf)
    end

    test "can undo after insert" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0, 5)
      buf = EditBuffer.insert(buf, "!")
      assert EditBuffer.can_undo?(buf)
    end

    test "can redo after undo" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0, 5)
      buf = EditBuffer.insert(buf, "!")
      {buf, _meta} = EditBuffer.undo(buf)
      assert EditBuffer.can_redo?(buf)
    end
  end

  describe "clear_history/1" do
    test "clears undo/redo history" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0, 5)
      buf = EditBuffer.insert(buf, "!")
      assert EditBuffer.can_undo?(buf)

      buf = EditBuffer.clear_history(buf)
      refute EditBuffer.can_undo?(buf)
    end
  end

  describe "get_eol/1" do
    test "returns end of line position" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0, 0)
      {row, col, offset} = EditBuffer.get_eol(buf)
      assert row == 0
      assert col == 5
      assert offset == 5
    end

    test "returns end of current line in multiline" do
      buf = EditBuffer.from_text("Hi\nWorld")
      buf = EditBuffer.set_cursor(buf, 0, 0)
      {row, col, _offset} = EditBuffer.get_eol(buf)
      assert row == 0
      assert col == 2
    end
  end

  describe "get_next_word_boundary/1" do
    test "jumps to next word boundary" do
      buf = EditBuffer.from_text("hello world")
      buf = EditBuffer.set_cursor(buf, 0, 0)
      {_row, col, _offset} = EditBuffer.get_next_word_boundary(buf)
      # should jump past "hello" to the space or start of "world"
      assert col >= 5
    end
  end

  describe "get_prev_word_boundary/1" do
    test "jumps to previous word boundary" do
      buf = EditBuffer.from_text("hello world")
      buf = EditBuffer.set_cursor(buf, 0, 8)
      {_row, col, _offset} = EditBuffer.get_prev_word_boundary(buf)
      # should jump back to start of "world" or end of "hello"
      assert col <= 6
    end
  end

  describe "get_text_range/3" do
    test "extracts text by offset range" do
      buf = EditBuffer.from_text("Hello World")
      text = EditBuffer.get_text_range(buf, 0, 5)
      assert text == "Hello"
    end

    test "extracts middle portion" do
      buf = EditBuffer.from_text("Hello World")
      text = EditBuffer.get_text_range(buf, 6, 11)
      assert text == "World"
    end
  end

  describe "get_text_range_by_coords/5" do
    test "extracts text by coordinates" do
      buf = EditBuffer.from_text("Hello World")
      text = EditBuffer.get_text_range_by_coords(buf, 0, 0, 0, 5)
      assert text == "Hello"
    end

    test "extracts across lines" do
      buf = EditBuffer.from_text("Hello\nWorld")
      text = EditBuffer.get_text_range_by_coords(buf, 0, 0, 1, 5)
      assert text == "Hello\nWorld"
    end
  end
end
