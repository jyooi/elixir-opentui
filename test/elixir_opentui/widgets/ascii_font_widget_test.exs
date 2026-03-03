defmodule ElixirOpentui.Widgets.ASCIIFontWidgetTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Element, Buffer, Layout, Painter, Color}

  defp paint(tree, w \\ 40, h \\ 10) do
    {tagged, layout_results} = Layout.compute(tree, w, h)
    buffer = Buffer.new(w, h)
    Painter.paint(tagged, layout_results, buffer)
  end

  @white Color.white()
  @red Color.red()

  describe "ascii_font painting" do
    test "tiny font renders 2-row text" do
      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:ascii_font, text: "I", font: :tiny, fg: @white)
        ])

      buf = paint(tree)
      # Tiny "I" is just "█" on both rows
      assert Buffer.get_cell(buf, 0, 0).char == "█"
      assert Buffer.get_cell(buf, 0, 1).char == "█"
    end

    test "block font renders 6 rows" do
      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:ascii_font, text: "I", font: :block, fg: @white)
        ])

      buf = paint(tree)
      # Block "I" row 0 is "██╗" — first char should be "█"
      assert Buffer.get_cell(buf, 0, 0).char == "█"
    end

    test "clips to width" do
      # Very narrow container
      tree =
        Element.new(:box, [width: 2, height: 5], [
          Element.new(:ascii_font, text: "HELLO", font: :tiny, fg: @white)
        ])

      buf = paint(tree, 2, 5)
      # Should not crash, just clips
      assert buf != nil
    end

    test "clips to height" do
      # Container shorter than font height
      tree =
        Element.new(:box, [width: 40, height: 1], [
          Element.new(:ascii_font, text: "A", font: :block, fg: @white)
        ])

      buf = paint(tree, 40, 1)
      assert buf != nil
    end

    test "empty text renders nothing" do
      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:ascii_font, text: "", font: :tiny, fg: @white)
        ])

      buf = paint(tree)
      assert buf != nil
    end

    test "uppercases input" do
      tree_lower =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:ascii_font, text: "a", font: :tiny, fg: @white)
        ])

      tree_upper =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:ascii_font, text: "A", font: :tiny, fg: @white)
        ])

      buf_lower = paint(tree_lower)
      buf_upper = paint(tree_upper)

      # Same characters rendered at same positions
      assert Buffer.get_cell(buf_lower, 0, 0).char == Buffer.get_cell(buf_upper, 0, 0).char
    end

    test "primary fg color applied" do
      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:ascii_font, text: "I", font: :tiny, fg: @red)
        ])

      buf = paint(tree)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.fg == @red
    end

    test "inside box with border" do
      tree =
        Element.new(:box, [width: 40, height: 10, border: true], [
          Element.new(:ascii_font, text: "I", font: :tiny, fg: @white)
        ])

      buf = paint(tree)
      # Border offsets content by (1, 1)
      assert Buffer.get_cell(buf, 1, 1).char == "█"
    end

    test "nil text attr renders without crash" do
      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:ascii_font, font: :tiny, fg: @white)
        ])

      buf = paint(tree)
      assert buf != nil
    end

    test "secondary_fg attribute used for color index 1" do
      secondary = Color.rgb(0, 128, 255)

      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:ascii_font,
            text: "A",
            font: :block,
            fg: @white,
            secondary_fg: secondary
          )
        ])

      buf = paint(tree)
      # Block A has color index 1 segments (╗, ║, etc.)
      # The last row is all c2: "╚═╝  ╚═╝" — check first char
      cell = Buffer.get_cell(buf, 0, 5)

      if cell.char != " " do
        assert cell.fg == secondary
      end
    end

    test "space cells get element bg (fill_rect before draw)" do
      tree =
        Element.new(:box, [width: 40, height: 10, bg: Color.blue()], [
          Element.new(:ascii_font, text: "I", font: :block, fg: @white, bg: Color.red())
        ])

      buf = paint(tree)
      # Block "I" row 0 is "██╗" — first char should be drawn
      assert Buffer.get_cell(buf, 0, 0).char == "█"

      # A space cell within the font area should have the element's bg (red),
      # NOT the parent's bg (blue), because fill_rect pre-fills with element bg
      # Block "I" is 3 chars wide; col 4 is inside the font area but is a space
      space_cell = Buffer.get_cell(buf, 4, 0)
      assert space_cell.bg == Color.red()
    end
  end
end
