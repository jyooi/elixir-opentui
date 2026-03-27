defmodule ElixirOpentui.PainterTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Element, Buffer, Layout, Painter, Color}

  defp paint(tree, w \\ 20, h \\ 5) do
    {tagged, layout_results} = Layout.compute(tree, w, h)
    buffer = Buffer.new(w, h)
    Painter.paint(tagged, layout_results, buffer)
  end

  describe "text rendering" do
    test "paints text content" do
      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:text, content: "Hello")
        ])

      buf = paint(tree)
      rows = Buffer.to_strings(buf)
      assert String.starts_with?(hd(rows), "Hello")
    end

    test "truncates text to available width" do
      tree =
        Element.new(:box, [width: 3, height: 1], [
          Element.new(:text, content: "Hello World")
        ])

      buf = paint(tree, 3, 1)
      rows = Buffer.to_strings(buf)
      assert hd(rows) == "Hel"
    end

    test "truncates text by display width" do
      tree =
        Element.new(:box, [width: 2, height: 1], [
          Element.new(:text, content: "A界B")
        ])

      buf = paint(tree, 2, 1)
      rows = Buffer.to_strings(buf)
      assert hd(rows) == "A "
    end
  end

  describe "background painting" do
    test "fills element background" do
      bg_color = Color.blue()
      tree = Element.new(:box, width: 5, height: 3, bg: bg_color)
      buf = paint(tree, 5, 3)
      cell = Buffer.get_cell(buf, 2, 1)
      assert cell.bg == bg_color
    end

    test "nested background overrides parent" do
      tree =
        Element.new(:box, [width: 20, height: 5, bg: Color.blue()], [
          Element.new(:box, width: 10, height: 3, bg: Color.red())
        ])

      buf = paint(tree)
      # Inside the child box
      inner_cell = Buffer.get_cell(buf, 5, 0)
      assert inner_cell.bg == Color.red()
    end
  end

  describe "border painting" do
    test "draws box-drawing characters" do
      tree = Element.new(:box, width: 10, height: 5, border: true)
      buf = paint(tree, 10, 5)

      assert Buffer.get_cell(buf, 0, 0).char == "┌"
      assert Buffer.get_cell(buf, 9, 0).char == "┐"
      assert Buffer.get_cell(buf, 0, 4).char == "└"
      assert Buffer.get_cell(buf, 9, 4).char == "┘"
      assert Buffer.get_cell(buf, 1, 0).char == "─"
      assert Buffer.get_cell(buf, 0, 1).char == "│"
    end

    test "border with child content inside" do
      tree =
        Element.new(:box, [width: 20, height: 5, border: true], [
          Element.new(:text, content: "Inside")
        ])

      buf = paint(tree)
      # Content should start at (1, 1)
      assert Buffer.get_cell(buf, 1, 1).char == "I"
      assert Buffer.get_cell(buf, 2, 1).char == "n"
    end
  end

  describe "panel title" do
    test "renders title on top border" do
      tree = Element.new(:panel, width: 20, height: 5, border: true, title: "Info")
      buf = paint(tree, 20, 5)
      # Title should appear near top-left
      assert Buffer.get_cell(buf, 2, 0).char == "I"
      assert Buffer.get_cell(buf, 3, 0).char == "n"
      assert Buffer.get_cell(buf, 4, 0).char == "f"
      assert Buffer.get_cell(buf, 5, 0).char == "o"
    end
  end

  describe "hit regions" do
    test "interactive elements set hit_id" do
      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:button, id: :btn, content: "Click", width: 10, height: 1)
        ])

      buf = paint(tree)
      assert Buffer.get_hit_id(buf, 0, 0) == :btn
    end

    test "non-interactive elements have nil hit_id" do
      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:text, content: "No hit")
        ])

      buf = paint(tree)
      assert Buffer.get_hit_id(buf, 0, 0) == nil
    end
  end

  describe "input rendering" do
    test "renders value" do
      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:input, id: :name, value: "John", width: 15)
        ])

      buf = paint(tree)
      assert Buffer.get_cell(buf, 0, 0).char == "J"
      assert Buffer.get_cell(buf, 1, 0).char == "o"
    end

    test "renders placeholder when value is empty" do
      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:input, id: :name, value: "", placeholder: "Name", width: 15)
        ])

      buf = paint(tree)
      assert Buffer.get_cell(buf, 0, 0).char == "N"
    end

    test "renders visible slice using display columns" do
      tree =
        Element.new(:box, [width: 3, height: 5], [
          Element.new(:input, id: :name, value: "A界B", scroll_offset: 2, width: 3)
        ])

      buf = paint(tree, 3, 5)
      rows = Buffer.to_strings(buf)
      assert hd(rows) == " B "
    end
  end
end
