defmodule ElixirOpentui.OpacityTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Element, Buffer, Layout, Painter, Color}

  defp paint(tree, w, h) do
    {tagged, layout_results} = Layout.compute(tree, w, h)
    buffer = Buffer.new(w, h)
    Painter.paint(tagged, layout_results, buffer)
  end

  describe "opacity defaults" do
    test "default opacity is 1.0" do
      el = Element.new(:box)
      assert el.style.opacity == 1.0
    end
  end

  describe "opacity clamping" do
    test "opacity 0.0 makes colors transparent" do
      color = Color.with_opacity({255, 0, 0, 255}, 0.0)
      assert elem(color, 3) == 0
    end

    test "opacity 1.0 keeps colors unchanged" do
      color = Color.with_opacity({255, 0, 0, 255}, 1.0)
      assert color == {255, 0, 0, 255}
    end

    test "opacity 0.5 halves alpha" do
      color = Color.with_opacity({255, 0, 0, 255}, 0.5)
      assert elem(color, 3) == 128
    end
  end

  describe "opacity rendering" do
    test "full opacity renders normally" do
      tree = Element.new(:box, width: 5, height: 3, bg: Color.red(), opacity: 1.0)
      buf = paint(tree, 5, 3)
      cell = Buffer.get_cell(buf, 2, 1)
      assert cell.bg == Color.red()
    end

    test "zero opacity background has zero alpha" do
      tree = Element.new(:box, width: 5, height: 3, bg: Color.red(), opacity: 0.0)
      buf = paint(tree, 5, 3)
      cell = Buffer.get_cell(buf, 2, 1)
      {_r, _g, _b, a} = cell.bg
      assert a == 0
    end

    test "half opacity reduces alpha" do
      tree = Element.new(:box, width: 5, height: 3, bg: Color.red(), opacity: 0.5)
      buf = paint(tree, 5, 3)
      cell = Buffer.get_cell(buf, 2, 1)
      {_r, _g, _b, a} = cell.bg
      assert a == 128
    end

    test "nested opacity compounds" do
      tree =
        Element.new(:box, [width: 10, height: 5, opacity: 0.5], [
          Element.new(:box, width: 10, height: 5, bg: Color.red(), opacity: 0.5)
        ])

      buf = paint(tree, 10, 5)
      cell = Buffer.get_cell(buf, 5, 2)
      {_r, _g, _b, a} = cell.bg
      # 0.5 * 0.5 = 0.25 => 255 * 0.25 = ~64
      assert a in 63..65
    end
  end
end
