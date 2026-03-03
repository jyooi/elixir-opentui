defmodule ElixirOpentui.Widgets.FrameBufferWidgetTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Element, Buffer, Layout, Painter, Color, Canvas}

  defp paint(tree, w \\ 20, h \\ 10) do
    {tagged, layout_results} = Layout.compute(tree, w, h)
    buffer = Buffer.new(w, h)
    Painter.paint(tagged, layout_results, buffer)
  end

  @white Color.white()
  @black Color.black()
  @red Color.red()
  @blue Color.blue()

  describe "frame_buffer painting" do
    test "set_cell renders at correct absolute position" do
      canvas = Canvas.new(10, 5) |> Canvas.set_cell(3, 2, "X", @white, @black)

      tree =
        Element.new(:box, [width: 20, height: 10], [
          Element.new(:frame_buffer, buffer: canvas, width: 10, height: 5)
        ])

      buf = paint(tree)
      cell = Buffer.get_cell(buf, 3, 2)
      assert cell.char == "X"
    end

    test "draw_text renders at correct positions" do
      canvas = Canvas.new(10, 5) |> Canvas.draw_text(0, 0, "Hello", @white, @black)

      tree =
        Element.new(:box, [width: 20, height: 10], [
          Element.new(:frame_buffer, buffer: canvas, width: 10, height: 5)
        ])

      buf = paint(tree)
      assert Buffer.get_cell(buf, 0, 0).char == "H"
      assert Buffer.get_cell(buf, 1, 0).char == "e"
      assert Buffer.get_cell(buf, 4, 0).char == "o"
    end

    test "fill_rect renders correctly" do
      canvas = Canvas.new(10, 5) |> Canvas.fill_rect(1, 1, 3, 2, "#", @red, @blue)

      tree =
        Element.new(:box, [width: 20, height: 10], [
          Element.new(:frame_buffer, buffer: canvas, width: 10, height: 5)
        ])

      buf = paint(tree)
      cell = Buffer.get_cell(buf, 2, 2)
      assert cell.char == "#"
      assert cell.fg == @red
      assert cell.bg == @blue
    end

    test "clips to element bounds" do
      # Cell at (15, 3) is outside 10-wide canvas — should not render
      canvas =
        Canvas.new(10, 5)
        |> Canvas.set_cell(15, 3, "X", @white, @black)
        |> Canvas.set_cell(2, 2, "Y", @white, @black)

      tree =
        Element.new(:box, [width: 20, height: 10], [
          Element.new(:frame_buffer, buffer: canvas, width: 10, height: 5)
        ])

      buf = paint(tree)
      # Y should render, X should be clipped
      assert Buffer.get_cell(buf, 2, 2).char == "Y"
      # Position 15,3 should have default space char
      assert Buffer.get_cell(buf, 15, 3).char == " "
    end

    test "renders with border offset" do
      canvas = Canvas.new(10, 5) |> Canvas.set_cell(0, 0, "A", @white, @black)

      tree =
        Element.new(:box, [width: 20, height: 10, border: true], [
          Element.new(:frame_buffer, buffer: canvas, width: 10, height: 5)
        ])

      buf = paint(tree)
      # Border adds 1,1 offset
      assert Buffer.get_cell(buf, 1, 1).char == "A"
    end

    test "nil buffer renders without crash" do
      tree =
        Element.new(:box, [width: 20, height: 10], [
          Element.new(:frame_buffer, width: 10, height: 5)
        ])

      buf = paint(tree)
      assert buf != nil
    end

    test "empty canvas renders without crash" do
      canvas = Canvas.new(10, 5)

      tree =
        Element.new(:box, [width: 20, height: 10], [
          Element.new(:frame_buffer, buffer: canvas, width: 10, height: 5)
        ])

      buf = paint(tree)
      assert buf != nil
    end

    test "composited with other widgets" do
      canvas = Canvas.new(10, 3) |> Canvas.set_cell(0, 0, "*", @white, @black)

      tree =
        Element.new(:box, [width: 20, height: 10], [
          Element.new(:text, content: "Title"),
          Element.new(:frame_buffer, buffer: canvas, width: 10, height: 3)
        ])

      buf = paint(tree)
      # Text at row 0
      assert Buffer.get_cell(buf, 0, 0).char == "T"
      # Canvas at row 1 (stacked below text)
      assert Buffer.get_cell(buf, 0, 1).char == "*"
    end

    test "zero-size canvas does not crash" do
      canvas = Canvas.new(0, 0)

      tree =
        Element.new(:box, [width: 20, height: 10], [
          Element.new(:frame_buffer, buffer: canvas, width: 0, height: 0)
        ])

      buf = paint(tree)
      assert buf != nil
    end

    test "canvas with fg color" do
      canvas = Canvas.new(10, 5) |> Canvas.set_cell(0, 0, "C", @red, @blue)

      tree =
        Element.new(:box, [width: 20, height: 10], [
          Element.new(:frame_buffer, buffer: canvas, width: 10, height: 5)
        ])

      buf = paint(tree)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.char == "C"
      assert cell.fg == @red
      assert cell.bg == @blue
    end
  end
end
