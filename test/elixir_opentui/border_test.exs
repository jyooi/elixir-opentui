defmodule ElixirOpentui.BorderTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Border, Buffer, Element, Layout, Painter}

  describe "chars/1" do
    test "returns correct chars for :single" do
      c = Border.chars(:single)
      assert c.tl == "┌"
      assert c.tr == "┐"
      assert c.bl == "└"
      assert c.br == "┘"
      assert c.h == "─"
      assert c.v == "│"
    end

    test "returns correct chars for :double" do
      c = Border.chars(:double)
      assert c.tl == "╔"
      assert c.tr == "╗"
      assert c.bl == "╚"
      assert c.br == "╝"
      assert c.h == "═"
      assert c.v == "║"
    end

    test "returns correct chars for :rounded" do
      c = Border.chars(:rounded)
      assert c.tl == "╭"
      assert c.tr == "╮"
      assert c.bl == "╰"
      assert c.br == "╯"
      assert c.h == "─"
      assert c.v == "│"
    end

    test "returns correct chars for :heavy" do
      c = Border.chars(:heavy)
      assert c.tl == "┏"
      assert c.tr == "┓"
      assert c.bl == "┗"
      assert c.br == "┛"
      assert c.h == "━"
      assert c.v == "┃"
    end

    test "raises FunctionClauseError for unknown style" do
      assert_raise FunctionClauseError, fn -> Border.chars(:dubble) end
    end
  end

  describe "valid?/1" do
    test "returns true for known styles" do
      assert Border.valid?(:single)
      assert Border.valid?(:double)
      assert Border.valid?(:rounded)
      assert Border.valid?(:heavy)
    end

    test "returns false for unknown styles" do
      refute Border.valid?(:dashed)
      refute Border.valid?("single")
    end
  end

  describe "styles/0" do
    test "returns all four styles" do
      assert Border.styles() == [:single, :double, :rounded, :heavy]
    end
  end

  describe "border style painting" do
    defp paint_box(opts) do
      tree = Element.new(:box, [width: 10, height: 4, border: true] ++ opts)
      {tagged, layout} = Layout.compute(tree, 10, 4)
      buf = Buffer.new(10, 4)
      Painter.paint(tagged, layout, buf) |> Buffer.to_strings()
    end

    test "single border (default) paints ┌┐└┘─│" do
      rows = paint_box([])
      assert String.contains?(hd(rows), "┌")
      assert String.contains?(hd(rows), "┐")
      assert String.contains?(List.last(rows), "└")
      assert String.contains?(List.last(rows), "┘")
    end

    test "double border paints ╔╗╚╝═║" do
      rows = paint_box(border_style: :double)
      assert String.contains?(hd(rows), "╔")
      assert String.contains?(hd(rows), "╗")
      assert String.contains?(hd(rows), "═")
      assert String.contains?(List.last(rows), "╚")
      assert String.contains?(List.last(rows), "╝")
      assert String.contains?(Enum.at(rows, 1), "║")
    end

    test "rounded border paints ╭╮╰╯─│" do
      rows = paint_box(border_style: :rounded)
      assert String.contains?(hd(rows), "╭")
      assert String.contains?(hd(rows), "╮")
      assert String.contains?(List.last(rows), "╰")
      assert String.contains?(List.last(rows), "╯")
    end

    test "heavy border paints ┏┓┗┛━┃" do
      rows = paint_box(border_style: :heavy)
      assert String.contains?(hd(rows), "┏")
      assert String.contains?(hd(rows), "┓")
      assert String.contains?(hd(rows), "━")
      assert String.contains?(List.last(rows), "┗")
      assert String.contains?(List.last(rows), "┛")
      assert String.contains?(Enum.at(rows, 1), "┃")
    end

    test "border: false ignores border_style" do
      tree = Element.new(:box, width: 10, height: 4, border: false, border_style: :double)
      {tagged, layout} = Layout.compute(tree, 10, 4)
      buf = Buffer.new(10, 4)
      rows = Painter.paint(tagged, layout, buf) |> Buffer.to_strings()
      refute String.contains?(hd(rows), "╔")
    end

    test "border: true without border_style defaults to single" do
      rows = paint_box([])
      assert String.contains?(hd(rows), "┌")
    end
  end

  describe "border title" do
    defp paint_titled_box(title, opts \\ []) do
      all_opts = [width: 20, height: 4, border: true, border_title: title] ++ opts
      tree = Element.new(:box, all_opts)
      {tagged, layout} = Layout.compute(tree, 20, 4)
      buf = Buffer.new(20, 4)
      Painter.paint(tagged, layout, buf) |> Buffer.to_strings()
    end

    test "left-aligned title (default)" do
      rows = paint_titled_box("Test")
      top = hd(rows)
      # Title appears near the start after the corner
      assert String.contains?(top, " Test ")
    end

    test "center-aligned title" do
      rows = paint_titled_box("Hi", border_title_align: :center)
      top = hd(rows)
      assert String.contains?(top, " Hi ")
    end

    test "right-aligned title" do
      rows = paint_titled_box("Hi", border_title_align: :right)
      top = hd(rows)
      assert String.contains?(top, " Hi ")
    end

    test "title truncated when too long" do
      rows = paint_titled_box("This is a very long title that exceeds width")
      top = hd(rows)
      # Should not overflow the box width of 20
      assert String.length(top) <= 20
      # Should still contain some text
      assert String.contains?(top, "This is")
    end

    test "no title when border_title is nil" do
      tree = Element.new(:box, width: 20, height: 4, border: true)
      {tagged, layout} = Layout.compute(tree, 20, 4)
      buf = Buffer.new(20, 4)
      rows = Painter.paint(tagged, layout, buf) |> Buffer.to_strings()
      top = hd(rows)
      assert String.starts_with?(top, "┌")
      # Top border is corners + horizontal lines, no title text
      inner = String.slice(top, 1, 18)
      assert inner == String.duplicate("─", 18)
    end

    test "title works with double border style" do
      rows = paint_titled_box("Settings", border_style: :double)
      top = hd(rows)
      assert String.contains?(top, "╔")
      assert String.contains?(top, " Settings ")
    end
  end

  describe "border title right-alignment corner safety" do
    test "right-aligned title on narrow box preserves corners" do
      tree =
        Element.new(:box,
          width: 8,
          height: 3,
          border: true,
          border_title: "Hi",
          border_title_align: :right
        )

      {tagged, layout} = Layout.compute(tree, 8, 3)
      buf = Buffer.new(8, 3)
      rows = Painter.paint(tagged, layout, buf) |> Buffer.to_strings()
      top = hd(rows)

      assert String.at(top, 0) == "┌"
      assert String.at(top, 7) == "┐"
      assert String.contains?(top, " Hi ")
    end

    test "center-aligned title on narrow box preserves corners" do
      tree =
        Element.new(:box,
          width: 8,
          height: 3,
          border: true,
          border_title: "Hi",
          border_title_align: :center
        )

      {tagged, layout} = Layout.compute(tree, 8, 3)
      buf = Buffer.new(8, 3)
      rows = Painter.paint(tagged, layout, buf) |> Buffer.to_strings()
      top = hd(rows)

      assert String.at(top, 0) == "┌"
      assert String.at(top, 7) == "┐"
    end
  end
end
