defmodule ElixirOpentui.FocusColorsTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Buffer, Element, Layout, Painter, Color}

  defp paint_focused(tree, w, h) do
    {tagged, layout} = Layout.compute(tree, w, h)
    buf = Buffer.new(w, h)
    Painter.paint(tagged, layout, buf, focus_id: tree.id)
  end

  describe "border focus colors" do
    test "border uses focus_border_color when focused" do
      custom_color = {255, 0, 0, 255}

      tree =
        Element.new(:box,
          id: :box1,
          width: 10,
          height: 4,
          border: true,
          focus_border_color: custom_color
        )

      buf = paint_focused(tree, 10, 4)
      # Top-left corner cell should use custom focus color
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.fg == custom_color
    end

    test "border uses default blue when focus_border_color is nil" do
      tree = Element.new(:box, id: :box1, width: 10, height: 4, border: true)
      buf = paint_focused(tree, 10, 4)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.fg == {80, 160, 255, 255}
    end
  end

  describe "button focus colors" do
    test "button uses focus_fg/focus_bg when focused" do
      tree =
        Element.new(:button,
          id: :btn1,
          width: 6,
          height: 1,
          content: "OK",
          fg: {200, 200, 200, 255},
          bg: {50, 50, 50, 255},
          focus_fg: {0, 255, 0, 255},
          focus_bg: {0, 0, 128, 255}
        )

      buf = paint_focused(tree, 6, 1)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.fg == {0, 255, 0, 255}
      assert cell.bg == {0, 0, 128, 255}
    end

    test "button falls back to inversion when focus_fg/bg nil" do
      tree =
        Element.new(:button,
          id: :btn1,
          width: 6,
          height: 1,
          content: "OK",
          fg: {200, 200, 200, 255},
          bg: {50, 50, 50, 255}
        )

      buf = paint_focused(tree, 6, 1)
      cell = Buffer.get_cell(buf, 0, 0)
      # Focused: fg becomes old bg, bg becomes old fg (inversion)
      assert cell.fg == {50, 50, 50, 255}
      assert cell.bg == {200, 200, 200, 255}
    end
  end

  describe "input cursor color" do
    test "input cursor uses cursor_color from style" do
      custom_cursor = {255, 255, 0, 255}

      tree =
        Element.new(:input,
          id: :inp1,
          width: 10,
          height: 1,
          value: "hello",
          cursor_pos: 0,
          scroll_offset: 0,
          cursor_color: custom_cursor
        )

      buf = paint_focused(tree, 10, 1)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.bg == custom_cursor
    end
  end

  describe "select highlight color" do
    test "select highlight uses focus_bg from style" do
      custom_bg = {100, 200, 50, 255}

      tree =
        Element.new(:select,
          id: :sel1,
          width: 10,
          height: 3,
          options: ["A", "B", "C"],
          selected: 0,
          scroll_offset: 0,
          focus_bg: custom_bg
        )

      buf = paint_focused(tree, 10, 3)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.bg == custom_bg
    end
  end

  describe "checkbox focus color" do
    test "checkbox uses focus_fg from style" do
      custom_fg = {0, 200, 100, 255}

      tree =
        Element.new(:checkbox,
          id: :cb1,
          width: 10,
          height: 1,
          checked: true,
          label: "Opt",
          focus_fg: custom_fg
        )

      buf = paint_focused(tree, 10, 1)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.fg == custom_fg
    end
  end

  describe "textarea cursor color" do
    test "textarea cursor uses cursor_color from style" do
      custom_cursor = {128, 255, 128, 255}

      tree =
        Element.new(:textarea,
          id: :ta1,
          width: 10,
          height: 3,
          lines: ["hello"],
          cursor_row: 0,
          cursor_col: 0,
          cursor_color: custom_cursor
        )

      buf = paint_focused(tree, 10, 3)
      cell = Buffer.get_cell(buf, 0, 0)
      # Block cursor: bg should be cursor_color
      assert cell.bg == custom_cursor
    end
  end
end
