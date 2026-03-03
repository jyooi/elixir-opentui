defmodule ElixirOpentui.PainterZIndexTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Element, Buffer, Layout, Painter, Color}

  defp paint(tree, w \\ 10, h \\ 5) do
    {tagged, layout_results} = Layout.compute(tree, w, h)
    buffer = Buffer.new(w, h)
    Painter.paint(tagged, layout_results, buffer)
  end

  describe "z-index ordering" do
    test "higher z-index paints on top of lower z-index" do
      red = Color.red()
      blue = Color.blue()

      tree =
        Element.new(:box, [width: 10, height: 5], [
          Element.new(:box, width: 4, height: 3, bg: red, position: :absolute, z_index: 1),
          Element.new(:box, width: 4, height: 3, bg: blue, position: :absolute, z_index: 2)
        ])

      buf = paint(tree)
      cell = Buffer.get_cell(buf, 1, 1)
      assert cell.bg == blue
    end

    test "higher z-index wins regardless of child order" do
      red = Color.red()
      blue = Color.blue()

      # blue is first child but has higher z-index — should still paint on top
      tree =
        Element.new(:box, [width: 10, height: 5], [
          Element.new(:box, width: 4, height: 3, bg: blue, position: :absolute, z_index: 5),
          Element.new(:box, width: 4, height: 3, bg: red, position: :absolute, z_index: 1)
        ])

      buf = paint(tree)
      cell = Buffer.get_cell(buf, 1, 1)
      assert cell.bg == blue
    end

    test "equal z-index preserves child order (last child wins)" do
      red = Color.red()
      blue = Color.blue()

      tree =
        Element.new(:box, [width: 10, height: 5], [
          Element.new(:box, width: 4, height: 3, bg: red, position: :absolute, z_index: 0),
          Element.new(:box, width: 4, height: 3, bg: blue, position: :absolute, z_index: 0)
        ])

      buf = paint(tree)
      cell = Buffer.get_cell(buf, 1, 1)
      assert cell.bg == blue
    end

    test "negative z-index paints behind siblings" do
      red = Color.red()
      blue = Color.blue()

      tree =
        Element.new(:box, [width: 10, height: 5], [
          Element.new(:box, width: 4, height: 3, bg: red, position: :absolute, z_index: -1),
          Element.new(:box, width: 4, height: 3, bg: blue, position: :absolute, z_index: 0)
        ])

      buf = paint(tree)
      cell = Buffer.get_cell(buf, 1, 1)
      assert cell.bg == blue
    end

    test "z-index only affects siblings (parent-scoped)" do
      red = Color.red()
      green = Color.green()

      # First child has a nested grandchild with z_index: 99,
      # but the first child itself has z_index: 0.
      # Second child has z_index: 1 — should paint on top of first child's area.
      tree =
        Element.new(:box, [width: 10, height: 5], [
          Element.new(:box, [width: 4, height: 3, position: :absolute, z_index: 0], [
            Element.new(:box, width: 4, height: 3, bg: red, z_index: 99)
          ]),
          Element.new(:box, width: 4, height: 3, bg: green, position: :absolute, z_index: 1)
        ])

      buf = paint(tree)
      cell = Buffer.get_cell(buf, 1, 1)
      assert cell.bg == green
    end
  end
end
