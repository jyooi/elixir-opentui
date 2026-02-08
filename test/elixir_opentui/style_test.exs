defmodule ElixirOpentui.StyleTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Style

  describe "defaults" do
    test "default style values" do
      style = %Style{}
      assert style.flex_direction == :column
      assert style.flex_grow == 0
      assert style.flex_shrink == 1
      assert style.flex_basis == :auto
      assert style.justify_content == :flex_start
      assert style.align_items == :stretch
      assert style.align_self == :auto
      assert style.width == :auto
      assert style.height == :auto
      assert style.padding == {0, 0, 0, 0}
      assert style.margin == {0, 0, 0, 0}
      assert style.gap == 0
      assert style.position == :relative
      assert style.border == false
      assert style.opacity == 1.0
      assert style.overflow == :visible
      assert style.z_index == 0
    end
  end

  describe "from_attrs/1" do
    test "sets flex properties" do
      style = Style.from_attrs(flex_direction: :row, flex_grow: 1, flex_shrink: 0)
      assert style.flex_direction == :row
      assert style.flex_grow == 1
      assert style.flex_shrink == 0
    end

    test "sets dimensions" do
      style = Style.from_attrs(width: 40, height: 10)
      assert style.width == 40
      assert style.height == 10
    end

    test "percentage dimensions" do
      style = Style.from_attrs(width: {:percent, 50})
      assert style.width == {:percent, 50}
    end

    test "normalizes integer padding to quad tuple" do
      style = Style.from_attrs(padding: 2)
      assert style.padding == {2, 2, 2, 2}
    end

    test "preserves quad tuple padding" do
      style = Style.from_attrs(padding: {1, 2, 3, 4})
      assert style.padding == {1, 2, 3, 4}
    end

    test "normalizes integer margin" do
      style = Style.from_attrs(margin: 3)
      assert style.margin == {3, 3, 3, 3}
    end

    test "sets position type and offsets" do
      style = Style.from_attrs(position: :absolute, top: 5, left: 10)
      assert style.position == :absolute
      assert style.top == 5
      assert style.left == 10
    end

    test "sets border" do
      style = Style.from_attrs(border: true)
      assert style.border == true
    end

    test "sets colors" do
      fg = {255, 0, 0, 255}
      bg = {0, 0, 255, 255}
      style = Style.from_attrs(fg: fg, bg: bg)
      assert style.fg == fg
      assert style.bg == bg
    end

    test "sets opacity" do
      style = Style.from_attrs(opacity: 0.5)
      assert style.opacity == 0.5
    end

    test "sets justify and align" do
      style = Style.from_attrs(justify_content: :center, align_items: :flex_end)
      assert style.justify_content == :center
      assert style.align_items == :flex_end
    end
  end
end
