defmodule ElixirOpentui.BufferTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Buffer
  alias ElixirOpentui.Color

  describe "new/2" do
    test "creates buffer with correct dimensions" do
      buf = Buffer.new(80, 24)
      assert buf.cols == 80
      assert buf.rows == 24
    end

    test "cells default to space with white-on-black" do
      buf = Buffer.new(10, 5)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.char == " "
      assert cell.fg == {255, 255, 255, 255}
      assert cell.bg == {0, 0, 0, 255}
    end
  end

  describe "get_cell/3 and put_cell/4" do
    test "get returns nil for out of bounds" do
      buf = Buffer.new(10, 5)
      assert Buffer.get_cell(buf, -1, 0) == nil
      assert Buffer.get_cell(buf, 10, 0) == nil
      assert Buffer.get_cell(buf, 0, 5) == nil
    end

    test "put and get round-trip" do
      buf = Buffer.new(10, 5)

      cell = %{
        char: "X",
        fg: Color.red(),
        bg: Color.blue(),
        bold: true,
        italic: false,
        underline: false,
        strikethrough: false,
        hit_id: nil
      }

      buf = Buffer.put_cell(buf, 3, 2, cell)
      assert Buffer.get_cell(buf, 3, 2) == cell
    end

    test "put out of bounds is no-op" do
      buf = Buffer.new(10, 5)

      cell = %{
        char: "X",
        fg: Color.red(),
        bg: Color.blue(),
        bold: false,
        italic: false,
        underline: false,
        strikethrough: false,
        hit_id: nil
      }

      buf2 = Buffer.put_cell(buf, 100, 100, cell)
      assert buf2 == buf
    end
  end

  describe "draw_char/6" do
    test "writes character at position" do
      buf = Buffer.new(10, 5)
      buf = Buffer.draw_char(buf, 0, 0, "A", Color.white(), Color.black())
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.char == "A"
      assert cell.fg == Color.white()
      assert cell.bg == Color.black()
    end
  end

  describe "draw_char_blend/6" do
    test "blends with existing cell" do
      buf = Buffer.new(10, 5)
      buf = Buffer.draw_char(buf, 0, 0, " ", Color.blue(), Color.blue())

      buf =
        Buffer.draw_char_blend(
          buf,
          0,
          0,
          "X",
          Color.rgba(255, 0, 0, 128),
          Color.rgba(255, 0, 0, 128)
        )

      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.char == "X"
      # Result should be a blend of red and blue
      {r, _g, b, _a} = cell.fg
      assert r > 100
      assert b > 0
    end

    test "preserves text attributes through blend" do
      buf = Buffer.new(10, 5)
      buf = Buffer.draw_char(buf, 0, 0, " ", Color.blue(), Color.blue())

      buf =
        Buffer.draw_char_blend(
          buf,
          0,
          0,
          "B",
          Color.rgba(255, 0, 0, 128),
          Color.rgba(255, 0, 0, 128),
          bold: true,
          italic: true
        )

      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.char == "B"
      assert cell.bold == true
      assert cell.italic == true
    end

    test "blend without attrs defaults to no attributes" do
      buf = Buffer.new(10, 5)
      buf = Buffer.draw_char(buf, 0, 0, " ", Color.blue(), Color.blue())

      buf =
        Buffer.draw_char_blend(
          buf,
          0,
          0,
          "X",
          Color.rgba(255, 0, 0, 128),
          Color.rgba(255, 0, 0, 128)
        )

      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.bold == false
      assert cell.italic == false
    end
  end

  describe "draw_text/6" do
    test "writes string horizontally" do
      buf = Buffer.new(10, 5)
      buf = Buffer.draw_text(buf, 0, 0, "Hello", Color.white(), Color.black())
      assert Buffer.get_cell(buf, 0, 0).char == "H"
      assert Buffer.get_cell(buf, 1, 0).char == "e"
      assert Buffer.get_cell(buf, 2, 0).char == "l"
      assert Buffer.get_cell(buf, 3, 0).char == "l"
      assert Buffer.get_cell(buf, 4, 0).char == "o"
    end

    test "truncates at buffer edge" do
      buf = Buffer.new(3, 1)
      buf = Buffer.draw_text(buf, 0, 0, "Hello", Color.white(), Color.black())
      assert Buffer.get_cell(buf, 0, 0).char == "H"
      assert Buffer.get_cell(buf, 1, 0).char == "e"
      assert Buffer.get_cell(buf, 2, 0).char == "l"
    end
  end

  describe "fill_rect/8" do
    test "fills rectangular area" do
      buf = Buffer.new(10, 5)
      buf = Buffer.fill_rect(buf, 1, 1, 3, 2, "#", Color.green(), Color.red())

      for x <- 1..3, y <- 1..2 do
        cell = Buffer.get_cell(buf, x, y)
        assert cell.char == "#", "cell at (#{x},#{y}) should be '#'"
        assert cell.fg == Color.green()
        assert cell.bg == Color.red()
      end

      # Outside the rect should be unchanged
      assert Buffer.get_cell(buf, 0, 0).char == " "
    end
  end

  describe "hit regions" do
    test "set and get hit_id" do
      buf = Buffer.new(10, 5)
      buf = Buffer.set_hit_region(buf, 2, 1, 3, 2, :my_button)
      assert Buffer.get_hit_id(buf, 2, 1) == :my_button
      assert Buffer.get_hit_id(buf, 4, 2) == :my_button
      assert Buffer.get_hit_id(buf, 0, 0) == nil
    end
  end

  describe "clear/1" do
    test "resets all cells to blank" do
      buf = Buffer.new(10, 5)
      buf = Buffer.draw_char(buf, 0, 0, "X", Color.red(), Color.blue())
      buf = Buffer.clear(buf)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.char == " "
    end
  end

  describe "resize/3" do
    test "creates new buffer with different size" do
      buf = Buffer.new(10, 5)
      buf = Buffer.resize(buf, 20, 10)
      assert buf.cols == 20
      assert buf.rows == 10
    end
  end

  describe "to_strings/1" do
    test "returns list of row strings" do
      buf = Buffer.new(5, 2)
      buf = Buffer.draw_text(buf, 0, 0, "Hello", Color.white(), Color.black())
      buf = Buffer.draw_text(buf, 0, 1, "World", Color.white(), Color.black())
      rows = Buffer.to_strings(buf)
      assert rows == ["Hello", "World"]
    end

    test "blank buffer returns spaces" do
      buf = Buffer.new(3, 2)
      rows = Buffer.to_strings(buf)
      assert rows == ["   ", "   "]
    end
  end

  describe "dim and inverse cell attributes" do
    test "buffer cell stores dim and inverse" do
      buf = Buffer.new(10, 5)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.dim == false
      assert cell.inverse == false

      custom_cell = %{cell | dim: true, inverse: true}
      buf = Buffer.put_cell(buf, 0, 0, custom_cell)
      stored = Buffer.get_cell(buf, 0, 0)
      assert stored.dim == true
      assert stored.inverse == true
    end
  end

  describe "diff/2" do
    test "empty diff for identical buffers" do
      buf = Buffer.new(5, 3)
      assert Buffer.diff(buf, buf) == []
    end

    test "detects changed cells" do
      buf1 = Buffer.new(5, 3)
      buf2 = Buffer.draw_char(buf1, 2, 1, "X", Color.red(), Color.blue())
      changes = Buffer.diff(buf1, buf2)
      assert length(changes) == 1
      [{x, y, cell}] = changes
      assert x == 2
      assert y == 1
      assert cell.char == "X"
    end

    test "different dimensions returns empty diff" do
      buf1 = Buffer.new(5, 3)
      buf2 = Buffer.new(10, 5)
      assert Buffer.diff(buf1, buf2) == []
    end
  end

  describe "blink and hidden attrs" do
    test "blank cell has blink: false and hidden: false" do
      buf = Buffer.new(5, 3)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.blink == false
      assert cell.hidden == false
    end

    test "draw_char with attrs sets blink and hidden" do
      buf = Buffer.new(5, 3)

      buf =
        Buffer.draw_char(buf, 0, 0, "X", Color.white(), Color.black(), blink: true, hidden: true)

      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.char == "X"
      assert cell.blink == true
      assert cell.hidden == true
    end

    test "draw_char with attrs sets all 8 attributes" do
      buf = Buffer.new(5, 3)

      attrs = [
        bold: true,
        italic: true,
        underline: true,
        strikethrough: true,
        dim: true,
        inverse: true,
        blink: true,
        hidden: true
      ]

      buf = Buffer.draw_char(buf, 0, 0, "A", Color.white(), Color.black(), attrs)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.bold == true
      assert cell.italic == true
      assert cell.underline == true
      assert cell.strikethrough == true
      assert cell.dim == true
      assert cell.inverse == true
      assert cell.blink == true
      assert cell.hidden == true
    end

    test "draw_text with attrs propagates to all chars" do
      buf = Buffer.new(10, 1)
      buf = Buffer.draw_text(buf, 0, 0, "Hi", Color.white(), Color.black(), bold: true)
      assert Buffer.get_cell(buf, 0, 0).bold == true
      assert Buffer.get_cell(buf, 1, 0).bold == true
      assert Buffer.get_cell(buf, 2, 0).bold == false
    end

    test "fill_rect with attrs propagates to all cells" do
      buf = Buffer.new(5, 3)
      buf = Buffer.fill_rect(buf, 0, 0, 3, 2, ".", Color.white(), Color.black(), italic: true)
      assert Buffer.get_cell(buf, 0, 0).italic == true
      assert Buffer.get_cell(buf, 2, 1).italic == true
      assert Buffer.get_cell(buf, 3, 0).italic == false
    end
  end
end
