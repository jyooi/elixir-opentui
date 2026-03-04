defmodule ElixirOpentui.PainterFocusTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Element, Buffer, Layout, Painter}

  defp paint_focused(tree, w, h, focus_id) do
    {tagged, layout_results} = Layout.compute(tree, w, h)
    buffer = Buffer.new(w, h)
    Painter.paint(tagged, layout_results, buffer, focus_id: focus_id)
  end

  describe "focused input cursor" do
    test "shows cursor block when focused" do
      tree =
        Element.new(:box, [width: 20, height: 3], [
          Element.new(:input, id: :inp, value: "hello", width: 15)
        ])

      buf = paint_focused(tree, 20, 3, :inp)
      cursor_cell = Buffer.get_cell(buf, 5, 0)
      assert cursor_cell.bg == {200, 200, 200, 255}
    end

    test "no cursor when unfocused" do
      tree =
        Element.new(:box, [width: 20, height: 3], [
          Element.new(:input, id: :inp, value: "hello", width: 15)
        ])

      buf = paint_focused(tree, 20, 3, nil)
      cursor_cell = Buffer.get_cell(buf, 5, 0)
      assert cursor_cell.bg != {200, 200, 200, 255}
    end

    test "empty input shows cursor at start when focused" do
      tree =
        Element.new(:box, [width: 20, height: 3], [
          Element.new(:input, id: :inp, value: "", placeholder: "Type...", width: 15)
        ])

      buf = paint_focused(tree, 20, 3, :inp)
      cursor_cell = Buffer.get_cell(buf, 0, 0)
      assert cursor_cell.bg == {200, 200, 200, 255}
    end
  end

  describe "focused button inversion" do
    test "button inverts fg/bg when focused" do
      tree =
        Element.new(:box, [width: 20, height: 3], [
          Element.new(:button, id: :btn, content: "OK", width: 5, height: 1)
        ])

      unfocused_buf = paint_focused(tree, 20, 3, nil)
      focused_buf = paint_focused(tree, 20, 3, :btn)

      unfocused_cell = Buffer.get_cell(unfocused_buf, 0, 0)
      focused_cell = Buffer.get_cell(focused_buf, 0, 0)

      assert unfocused_cell.fg == focused_cell.bg
      assert unfocused_cell.bg == focused_cell.fg
    end
  end

  describe "select rendering" do
    test "renders options" do
      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:select, id: :sel, options: ["Alpha", "Bravo", "Charlie"])
        ])

      buf = paint_focused(tree, 20, 5, nil)
      assert Buffer.get_cell(buf, 0, 0).char == "A"
      assert Buffer.get_cell(buf, 0, 1).char == "B"
      assert Buffer.get_cell(buf, 0, 2).char == "C"
    end

    test "highlights selected when focused" do
      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:select, id: :sel, options: ["Alpha", "Bravo", "Charlie"], selected: 1)
        ])

      buf = paint_focused(tree, 20, 5, :sel)
      selected_cell = Buffer.get_cell(buf, 0, 1)
      unselected_cell = Buffer.get_cell(buf, 0, 0)
      assert selected_cell.bg == {60, 120, 200, 255}
      assert unselected_cell.bg != {60, 120, 200, 255}
    end
  end

  describe "checkbox rendering" do
    test "unchecked checkbox" do
      tree =
        Element.new(:box, [width: 20, height: 3], [
          Element.new(:checkbox, id: :cb, label: "Accept", checked: false)
        ])

      buf = paint_focused(tree, 20, 3, nil)
      assert Buffer.get_cell(buf, 0, 0).char == "["
      assert Buffer.get_cell(buf, 1, 0).char == " "
      assert Buffer.get_cell(buf, 2, 0).char == "]"
    end

    test "checked checkbox" do
      tree =
        Element.new(:box, [width: 20, height: 3], [
          Element.new(:checkbox, id: :cb, label: "Accept", checked: true)
        ])

      buf = paint_focused(tree, 20, 3, nil)
      assert Buffer.get_cell(buf, 0, 0).char == "["
      assert Buffer.get_cell(buf, 1, 0).char == "x"
      assert Buffer.get_cell(buf, 2, 0).char == "]"
    end

    test "checkbox label text" do
      tree =
        Element.new(:box, [width: 20, height: 3], [
          Element.new(:checkbox, id: :cb, label: "Accept", checked: false)
        ])

      buf = paint_focused(tree, 20, 3, nil)
      assert Buffer.get_cell(buf, 4, 0).char == "A"
      assert Buffer.get_cell(buf, 5, 0).char == "c"
    end

    test "focused checkbox highlights" do
      tree =
        Element.new(:box, [width: 20, height: 3], [
          Element.new(:checkbox, id: :cb, label: "Accept", checked: false)
        ])

      buf = paint_focused(tree, 20, 3, :cb)
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.fg == {80, 160, 255, 255}
    end
  end
end
