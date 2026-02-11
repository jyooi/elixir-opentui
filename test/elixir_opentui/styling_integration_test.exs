defmodule ElixirOpentui.StylingIntegrationTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{ANSI, Buffer, Element, Layout, Painter}

  describe "full pipeline: Element -> Layout -> Painter -> Buffer -> ANSI" do
    test "double border with title renders correct ANSI output" do
      tree = Element.new(:box, width: 20, height: 5, border: true,
               border_style: :double, border_title: "Test", bold: true)
      {tagged, layout} = Layout.compute(tree, 20, 5)
      buf = Buffer.new(20, 5)
      buf = Painter.paint(tagged, layout, buf)
      ansi = IO.iodata_to_binary(ANSI.render_full(buf))

      assert String.contains?(ansi, "╔")
      assert String.contains?(ansi, "Test")
    end

    test "text element with bold/italic renders correct cell attrs" do
      tree = Element.new(:text, width: 10, height: 1, content: "Hello",
               bold: true, italic: true)
      {tagged, layout} = Layout.compute(tree, 10, 1)
      buf = Buffer.new(10, 1)
      buf = Painter.paint(tagged, layout, buf)

      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.char == "H"
      assert cell.bold == true
      assert cell.italic == true
      assert cell.underline == false
    end

    test "focused input with cursor_color renders custom color" do
      cursor_color = {255, 128, 0, 255}
      tree = Element.new(:input, id: :inp, width: 10, height: 1,
               value: "test", cursor_pos: 0, scroll_offset: 0,
               cursor_color: cursor_color)
      {tagged, layout} = Layout.compute(tree, 10, 1)
      buf = Buffer.new(10, 1)
      buf = Painter.paint(tagged, layout, buf, focus_id: :inp)

      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.bg == cursor_color
    end

    test "rounded border renders correct corner chars" do
      tree = Element.new(:box, width: 10, height: 4, border: true,
               border_style: :rounded)
      {tagged, layout} = Layout.compute(tree, 10, 4)
      buf = Buffer.new(10, 4)
      buf = Painter.paint(tagged, layout, buf)

      rows = Buffer.to_strings(buf)
      assert String.contains?(hd(rows), "╭")
      assert String.contains?(hd(rows), "╮")
      assert String.contains?(List.last(rows), "╰")
      assert String.contains?(List.last(rows), "╯")
    end

    test "blink and hidden attrs propagate through pipeline" do
      tree = Element.new(:text, width: 5, height: 1, content: "Hi",
               blink: true, hidden: true)
      {tagged, layout} = Layout.compute(tree, 5, 1)
      buf = Buffer.new(5, 1)
      buf = Painter.paint(tagged, layout, buf)

      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.blink == true
      assert cell.hidden == true

      ansi = IO.iodata_to_binary(ANSI.render_full(buf))
      # SGR codes: 5=blink, 8=hidden (appear in the SGR sequence)
      assert String.contains?(ansi, "5;")
      assert String.contains?(ansi, "8;")
    end
  end
end
