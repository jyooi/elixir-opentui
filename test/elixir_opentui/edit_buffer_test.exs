defmodule ElixirOpentui.EditBufferTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.EditBuffer

  describe "new/0 and from_text/1" do
    test "empty buffer" do
      buf = EditBuffer.new()
      assert EditBuffer.get_text(buf) == ""
      assert EditBuffer.get_cursor(buf) == 0
    end

    test "from text - cursor at end" do
      buf = EditBuffer.from_text("Hello")
      assert EditBuffer.get_text(buf) == "Hello"
      assert EditBuffer.get_cursor(buf) == 5
    end
  end

  describe "set_text/2" do
    test "sets text and clamps cursor" do
      buf = EditBuffer.from_text("Hello World")
      assert EditBuffer.get_cursor(buf) == 11
      buf = EditBuffer.set_text(buf, "Hi")
      assert EditBuffer.get_text(buf) == "Hi"
      assert EditBuffer.get_cursor(buf) == 2
    end

    test "clears selection" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.select(buf, 1, 3)
      buf = EditBuffer.set_text(buf, "New")
      assert buf.selection_start == nil
      assert buf.selection_end == nil
    end
  end

  describe "cursor movement" do
    test "set_cursor clamps to valid range" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, -5)
      assert EditBuffer.get_cursor(buf) == 0

      buf = EditBuffer.set_cursor(buf, 100)
      assert EditBuffer.get_cursor(buf) == 5
    end

    test "move_left" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.move_left(buf)
      assert EditBuffer.get_cursor(buf) == 4

      buf = EditBuffer.move_left(buf, 3)
      assert EditBuffer.get_cursor(buf) == 1
    end

    test "move_left clamps at zero" do
      buf = EditBuffer.from_text("Hi")
      buf = EditBuffer.set_cursor(buf, 0)
      buf = EditBuffer.move_left(buf, 5)
      assert EditBuffer.get_cursor(buf) == 0
    end

    test "move_right" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0)
      buf = EditBuffer.move_right(buf)
      assert EditBuffer.get_cursor(buf) == 1
    end

    test "move_right clamps at length" do
      buf = EditBuffer.from_text("Hi")
      buf = EditBuffer.move_right(buf, 10)
      assert EditBuffer.get_cursor(buf) == 2
    end

    test "move_home" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.move_home(buf)
      assert EditBuffer.get_cursor(buf) == 0
    end

    test "move_end" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0)
      buf = EditBuffer.move_end(buf)
      assert EditBuffer.get_cursor(buf) == 5
    end
  end

  describe "insert/2" do
    test "insert at cursor" do
      buf = EditBuffer.from_text("Hllo")
      buf = EditBuffer.set_cursor(buf, 1)
      buf = EditBuffer.insert(buf, "e")
      assert EditBuffer.get_text(buf) == "Hello"
      assert EditBuffer.get_cursor(buf) == 2
    end

    test "insert at beginning" do
      buf = EditBuffer.from_text("ello")
      buf = EditBuffer.set_cursor(buf, 0)
      buf = EditBuffer.insert(buf, "H")
      assert EditBuffer.get_text(buf) == "Hello"
      assert EditBuffer.get_cursor(buf) == 1
    end

    test "insert at end" do
      buf = EditBuffer.from_text("Hell")
      buf = EditBuffer.insert(buf, "o")
      assert EditBuffer.get_text(buf) == "Hello"
      assert EditBuffer.get_cursor(buf) == 5
    end

    test "insert multi-character string" do
      buf = EditBuffer.from_text("Hd")
      buf = EditBuffer.set_cursor(buf, 1)
      buf = EditBuffer.insert(buf, "ello Worl")
      assert EditBuffer.get_text(buf) == "Hello World"
      assert EditBuffer.get_cursor(buf) == 10
    end
  end

  describe "delete_backward/2" do
    test "delete one character before cursor" do
      buf = EditBuffer.from_text("Helllo")
      buf = EditBuffer.set_cursor(buf, 4)
      buf = EditBuffer.delete_backward(buf)
      assert EditBuffer.get_text(buf) == "Hello"
      assert EditBuffer.get_cursor(buf) == 3
    end

    test "no-op at beginning" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.set_cursor(buf, 0)
      buf = EditBuffer.delete_backward(buf)
      assert EditBuffer.get_text(buf) == "Hello"
      assert EditBuffer.get_cursor(buf) == 0
    end

    test "delete multiple characters" do
      buf = EditBuffer.from_text("Hello World")
      buf = EditBuffer.delete_backward(buf, 6)
      assert EditBuffer.get_text(buf) == "Hello"
      assert EditBuffer.get_cursor(buf) == 5
    end
  end

  describe "delete_forward/2" do
    test "delete one character after cursor" do
      buf = EditBuffer.from_text("Helllo")
      buf = EditBuffer.set_cursor(buf, 3)
      buf = EditBuffer.delete_forward(buf)
      assert EditBuffer.get_text(buf) == "Hello"
      assert EditBuffer.get_cursor(buf) == 3
    end

    test "no-op at end" do
      buf = EditBuffer.from_text("Hello")
      buf = EditBuffer.delete_forward(buf)
      assert EditBuffer.get_text(buf) == "Hello"
    end

    test "delete multiple characters" do
      buf = EditBuffer.from_text("Hello World")
      buf = EditBuffer.set_cursor(buf, 5)
      buf = EditBuffer.delete_forward(buf, 6)
      assert EditBuffer.get_text(buf) == "Hello"
    end
  end

  describe "selection" do
    test "select range" do
      buf = EditBuffer.from_text("Hello World")
      buf = EditBuffer.select(buf, 6, 11)
      assert EditBuffer.get_selection(buf) == "World"
    end

    test "reversed selection normalizes" do
      buf = EditBuffer.from_text("Hello World")
      buf = EditBuffer.select(buf, 11, 6)
      assert EditBuffer.get_selection(buf) == "World"
    end

    test "no selection returns nil" do
      buf = EditBuffer.from_text("Hello")
      assert EditBuffer.get_selection(buf) == nil
    end

    test "delete_selection" do
      buf = EditBuffer.from_text("Hello World")
      buf = EditBuffer.select(buf, 5, 11)
      buf = EditBuffer.delete_selection(buf)
      assert EditBuffer.get_text(buf) == "Hello"
      assert EditBuffer.get_cursor(buf) == 5
    end

    test "clamps to text boundaries" do
      buf = EditBuffer.from_text("Hi")
      buf = EditBuffer.select(buf, -5, 100)
      assert EditBuffer.get_selection(buf) == "Hi"
    end
  end

  describe "length/1" do
    test "returns grapheme count" do
      buf = EditBuffer.from_text("Hello")
      assert EditBuffer.length(buf) == 5
    end

    test "Unicode aware" do
      buf = EditBuffer.from_text("世界")
      assert EditBuffer.length(buf) == 2
    end
  end
end
