defmodule ElixirOpentui.CanvasTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Canvas
  alias ElixirOpentui.Color

  @white Color.white()
  @black Color.black()
  @red Color.red()
  @blue Color.blue()

  describe "new/2" do
    test "creates canvas with correct dimensions" do
      c = Canvas.new(10, 5)
      assert c.width == 10
      assert c.height == 5
    end

    test "starts with empty cells" do
      c = Canvas.new(20, 10)
      assert c.cells == %{}
    end

    test "zero dimensions" do
      c = Canvas.new(0, 0)
      assert c.width == 0
      assert c.height == 0
      assert c.cells == %{}
    end
  end

  describe "set_cell/6" do
    test "adds entry at position" do
      c = Canvas.new(10, 10) |> Canvas.set_cell(3, 2, "X", @white, @black)
      assert c.cells[{3, 2}] == {"X", @white, @black}
    end

    test "overwriting same position replaces cell" do
      c =
        Canvas.new(10, 10)
        |> Canvas.set_cell(5, 5, "A", @white, @black)
        |> Canvas.set_cell(5, 5, "B", @red, @blue)

      assert c.cells[{5, 5}] == {"B", @red, @blue}
      assert map_size(c.cells) == 1
    end

    test "out-of-bounds cells are stored" do
      c = Canvas.new(5, 5) |> Canvas.set_cell(10, 10, "*", @white, @black)
      assert c.cells[{10, 10}] == {"*", @white, @black}
    end

    test "negative coordinates are stored" do
      c = Canvas.new(5, 5) |> Canvas.set_cell(-1, -2, "N", @white, @black)
      assert c.cells[{-1, -2}] == {"N", @white, @black}
    end

    test "multiple cells at different positions" do
      c =
        Canvas.new(10, 10)
        |> Canvas.set_cell(0, 0, "A", @white, @black)
        |> Canvas.set_cell(1, 0, "B", @white, @black)
        |> Canvas.set_cell(0, 1, "C", @white, @black)

      assert map_size(c.cells) == 3
      assert c.cells[{0, 0}] == {"A", @white, @black}
      assert c.cells[{1, 0}] == {"B", @white, @black}
      assert c.cells[{0, 1}] == {"C", @white, @black}
    end
  end

  describe "draw_text/6" do
    test "creates one cell per grapheme" do
      c = Canvas.new(20, 5) |> Canvas.draw_text(0, 0, "Hello", @white, @black)
      assert map_size(c.cells) == 5
      assert c.cells[{0, 0}] == {"H", @white, @black}
      assert c.cells[{1, 0}] == {"e", @white, @black}
      assert c.cells[{2, 0}] == {"l", @white, @black}
      assert c.cells[{3, 0}] == {"l", @white, @black}
      assert c.cells[{4, 0}] == {"o", @white, @black}
    end

    test "empty text adds no cells" do
      c = Canvas.new(10, 5) |> Canvas.draw_text(0, 0, "", @white, @black)
      assert c.cells == %{}
    end

    test "starts at given x offset" do
      c = Canvas.new(20, 5) |> Canvas.draw_text(5, 3, "AB", @red, @black)
      assert c.cells[{5, 3}] == {"A", @red, @black}
      assert c.cells[{6, 3}] == {"B", @red, @black}
    end

    test "multi-byte Unicode: correct cell count per visible grapheme" do
      c = Canvas.new(20, 5) |> Canvas.draw_text(0, 0, "café", @white, @black)
      assert map_size(c.cells) == 4
      assert c.cells[{3, 0}] == {"é", @white, @black}
    end

    test "emoji graphemes" do
      c = Canvas.new(20, 5) |> Canvas.draw_text(0, 0, "★●", @white, @black)
      assert map_size(c.cells) == 2
      assert c.cells[{0, 0}] == {"★", @white, @black}
      assert c.cells[{1, 0}] == {"●", @white, @black}
    end
  end

  describe "fill_rect/8" do
    test "creates w*h cells" do
      c = Canvas.new(20, 20) |> Canvas.fill_rect(2, 3, 4, 3, "#", @white, @blue)
      assert map_size(c.cells) == 12

      for dx <- 0..3, dy <- 0..2 do
        assert c.cells[{2 + dx, 3 + dy}] == {"#", @white, @blue}
      end
    end

    test "zero width produces no cells" do
      c = Canvas.new(10, 10) |> Canvas.fill_rect(0, 0, 0, 5, "#", @white, @black)
      assert c.cells == %{}
    end

    test "zero height produces no cells" do
      c = Canvas.new(10, 10) |> Canvas.fill_rect(0, 0, 5, 0, "#", @white, @black)
      assert c.cells == %{}
    end

    test "1x1 rect creates one cell" do
      c = Canvas.new(10, 10) |> Canvas.fill_rect(3, 4, 1, 1, ".", @red, @black)
      assert map_size(c.cells) == 1
      assert c.cells[{3, 4}] == {".", @red, @black}
    end
  end

  describe "clear/1" do
    test "resets cells to empty map" do
      c =
        Canvas.new(10, 10)
        |> Canvas.set_cell(0, 0, "A", @white, @black)
        |> Canvas.set_cell(5, 5, "B", @white, @black)
        |> Canvas.clear()

      assert c.cells == %{}
    end

    test "preserves dimensions" do
      c = Canvas.new(20, 15) |> Canvas.set_cell(0, 0, "X", @white, @black) |> Canvas.clear()
      assert c.width == 20
      assert c.height == 15
    end
  end

  describe "composing operations" do
    test "draw_text then set_cell overwrites" do
      c =
        Canvas.new(10, 5)
        |> Canvas.draw_text(0, 0, "ABC", @white, @black)
        |> Canvas.set_cell(1, 0, "X", @red, @blue)

      assert c.cells[{0, 0}] == {"A", @white, @black}
      assert c.cells[{1, 0}] == {"X", @red, @blue}
      assert c.cells[{2, 0}] == {"C", @white, @black}
    end

    test "fill_rect then draw_text overwrites rect cells" do
      c =
        Canvas.new(10, 5)
        |> Canvas.fill_rect(0, 0, 5, 1, ".", @white, @black)
        |> Canvas.draw_text(1, 0, "Hi", @red, @blue)

      assert c.cells[{0, 0}] == {".", @white, @black}
      assert c.cells[{1, 0}] == {"H", @red, @blue}
      assert c.cells[{2, 0}] == {"i", @red, @blue}
      assert c.cells[{3, 0}] == {".", @white, @black}
    end
  end
end
