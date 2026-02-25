defmodule ElixirOpentui.ScissorTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Buffer
  alias ElixirOpentui.NativeBuffer

  @white {255, 255, 255, 255}
  @black {0, 0, 0, 255}

  # ── Buffer scissor tests ──────────────────────────────────────────────

  describe "Buffer push_scissor clips draw_char" do
    test "outside rect — cell unchanged" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 2, 2, 4, 4)
      buf = Buffer.draw_char(buf, 0, 0, "X", @white, @black)
      assert Buffer.get_cell(buf, 0, 0).char == " "
    end

    test "inside rect — cell written" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 2, 2, 4, 4)
      buf = Buffer.draw_char(buf, 3, 3, "X", @white, @black)
      assert Buffer.get_cell(buf, 3, 3).char == "X"
    end
  end

  describe "Buffer draw_text clipping" do
    test "clipped at scissor right boundary — partial text" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 2, 0, 3, 1)
      buf = Buffer.draw_text(buf, 0, 0, "ABCDEF", @white, @black)
      # draw_text writes A@0, B@1, C@2, D@3, E@4, F@5
      # scissor {2,0,3,1} allows x in [2,4], y=0
      assert Buffer.get_cell(buf, 0, 0).char == " "
      assert Buffer.get_cell(buf, 1, 0).char == " "
      assert Buffer.get_cell(buf, 2, 0).char == "C"
      assert Buffer.get_cell(buf, 3, 0).char == "D"
      assert Buffer.get_cell(buf, 4, 0).char == "E"
      assert Buffer.get_cell(buf, 5, 0).char == " "
    end

    test "clipped at scissor left boundary — skipped chars" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 3, 0, 5, 1)
      buf = Buffer.draw_text(buf, 0, 0, "ABCDEF", @white, @black)
      assert Buffer.get_cell(buf, 2, 0).char == " "
      assert Buffer.get_cell(buf, 3, 0).char == "D"
      assert Buffer.get_cell(buf, 4, 0).char == "E"
    end
  end

  describe "Buffer fill_rect clipping" do
    test "clipped to scissor bounds" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 1, 1, 3, 3)
      buf = Buffer.fill_rect(buf, 0, 0, 5, 5, "#", @white, @black)
      # Outside scissor
      assert Buffer.get_cell(buf, 0, 0).char == " "
      assert Buffer.get_cell(buf, 4, 4).char == " "
      # Inside scissor
      assert Buffer.get_cell(buf, 1, 1).char == "#"
      assert Buffer.get_cell(buf, 3, 3).char == "#"
    end
  end

  describe "Buffer nested scissor" do
    test "intersects correctly — inner rect within outer" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 1, 1, 6, 6)
      buf = Buffer.push_scissor(buf, 3, 3, 6, 6)
      # Intersection: {max(1,3), max(1,3), min(7,9)-3, min(7,9)-3} = {3,3,4,4}
      buf = Buffer.draw_char(buf, 2, 2, "X", @white, @black)
      assert Buffer.get_cell(buf, 2, 2).char == " "

      buf = Buffer.draw_char(buf, 3, 3, "Y", @white, @black)
      assert Buffer.get_cell(buf, 3, 3).char == "Y"

      buf = Buffer.draw_char(buf, 6, 6, "Z", @white, @black)
      assert Buffer.get_cell(buf, 6, 6).char == "Z"
    end

    test "non-overlapping rects clip everything" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 0, 0, 3, 3)
      buf = Buffer.push_scissor(buf, 5, 5, 3, 3)
      # Empty intersection
      buf = Buffer.draw_char(buf, 1, 1, "X", @white, @black)
      assert Buffer.get_cell(buf, 1, 1).char == " "

      buf = Buffer.draw_char(buf, 6, 6, "Y", @white, @black)
      assert Buffer.get_cell(buf, 6, 6).char == " "
    end
  end

  describe "Buffer pop_scissor" do
    test "restores previous clip region" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 1, 1, 3, 3)
      buf = Buffer.push_scissor(buf, 2, 2, 1, 1)
      # Inner scissor: only {2,2,1,1}
      buf = Buffer.draw_char(buf, 1, 1, "X", @white, @black)
      assert Buffer.get_cell(buf, 1, 1).char == " "

      buf = Buffer.pop_scissor(buf)
      # Back to outer scissor: {1,1,3,3}
      buf = Buffer.draw_char(buf, 1, 1, "Y", @white, @black)
      assert Buffer.get_cell(buf, 1, 1).char == "Y"
    end
  end

  describe "Buffer empty scissor stack" do
    test "uses full buffer bounds (default behavior)" do
      buf = Buffer.new(5, 5)
      buf = Buffer.draw_char(buf, 2, 2, "X", @white, @black)
      assert Buffer.get_cell(buf, 2, 2).char == "X"

      buf = Buffer.draw_char(buf, 10, 10, "Y", @white, @black)
      assert Buffer.get_cell(buf, 10, 10) == nil
    end
  end

  describe "Buffer zero-dimension scissor" do
    test "zero width clips everything" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 2, 2, 0, 5)
      buf = Buffer.draw_char(buf, 2, 3, "X", @white, @black)
      assert Buffer.get_cell(buf, 2, 3).char == " "
    end

    test "zero height clips everything" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 2, 2, 5, 0)
      buf = Buffer.draw_char(buf, 3, 2, "X", @white, @black)
      assert Buffer.get_cell(buf, 3, 2).char == " "
    end
  end

  # ── NativeBuffer scissor tests ────────────────────────────────────────

  @moduletag :nif

  describe "NativeBuffer scissor" do
    @tag :nif
    test "draw_char respects scissor — ops not encoded when clipped" do
      buf = NativeBuffer.new(10, 10)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.push_scissor(buf, 2, 2, 3, 3)

      # Outside scissor — should not encode
      buf = NativeBuffer.draw_char(buf, 0, 0, "X", @white, @black)
      # Inside scissor — should encode
      buf = NativeBuffer.draw_char(buf, 3, 3, "Y", @white, @black)

      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)
      assert NativeBuffer.get_cell(buf, 0, 0).char == " "
      assert NativeBuffer.get_cell(buf, 3, 3).char == "Y"
    end

    @tag :nif
    test "fill_rect clipped to scissor bounds" do
      buf = NativeBuffer.new(10, 10)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.push_scissor(buf, 1, 1, 3, 3)
      buf = NativeBuffer.fill_rect(buf, 0, 0, 5, 5, "#", @white, @black)

      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)
      # Outside scissor
      assert NativeBuffer.get_cell(buf, 0, 0).char == " "
      assert NativeBuffer.get_cell(buf, 4, 4).char == " "
      # Inside scissor
      assert NativeBuffer.get_cell(buf, 1, 1).char == "#"
      assert NativeBuffer.get_cell(buf, 3, 3).char == "#"
    end

    @tag :nif
    test "nested scissor matches Buffer behavior" do
      buf = NativeBuffer.new(10, 10)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.push_scissor(buf, 1, 1, 6, 6)
      buf = NativeBuffer.push_scissor(buf, 3, 3, 6, 6)

      buf = NativeBuffer.draw_char(buf, 2, 2, "X", @white, @black)
      buf = NativeBuffer.draw_char(buf, 3, 3, "Y", @white, @black)

      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)
      assert NativeBuffer.get_cell(buf, 2, 2).char == " "
      assert NativeBuffer.get_cell(buf, 3, 3).char == "Y"
    end
  end

  # ── Hit region clipping ───────────────────────────────────────────────

  describe "Buffer hit region clipping" do
    test "set_hit_region clipped by scissor" do
      buf = Buffer.new(10, 10)
      buf = Buffer.push_scissor(buf, 2, 2, 3, 3)
      buf = Buffer.set_hit_region(buf, 0, 0, 6, 6, :my_button)

      # Outside scissor — no hit_id
      assert Buffer.get_hit_id(buf, 0, 0) == nil
      assert Buffer.get_hit_id(buf, 1, 1) == nil
      assert Buffer.get_hit_id(buf, 5, 5) == nil

      # Inside scissor — hit_id set
      assert Buffer.get_hit_id(buf, 2, 2) == :my_button
      assert Buffer.get_hit_id(buf, 4, 4) == :my_button
    end
  end

  describe "NativeBuffer hit region clipping" do
    @tag :nif
    test "set_hit_region clipped by scissor" do
      buf = NativeBuffer.new(10, 10)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.push_scissor(buf, 2, 2, 3, 3)
      buf = NativeBuffer.set_hit_region(buf, 0, 0, 6, 6, :my_button)

      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)

      # Outside scissor — no hit_id
      assert NativeBuffer.get_hit_id(buf, 0, 0) == nil
      assert NativeBuffer.get_hit_id(buf, 1, 1) == nil

      # Inside scissor — hit_id set
      assert NativeBuffer.get_hit_id(buf, 2, 2) == :my_button
      assert NativeBuffer.get_hit_id(buf, 4, 4) == :my_button
    end
  end

  # ── Integration: Painter + ScrollBox ──────────────────────────────────

  describe "ScrollBox integration" do
    test "children extending beyond bounds are clipped" do
      alias ElixirOpentui.Element
      alias ElixirOpentui.Layout
      alias ElixirOpentui.Painter

      # scroll_box at 5x3 with a child text that's wider than the box
      tree =
        Element.new(:scroll_box, [id: :sbox], [
          Element.new(:text, [id: :txt, content: "ABCDEFGHIJ"], [])
        ])

      # Layout returns {tagged_tree, layout_results}
      {tagged, layout} = Layout.compute(tree, 5, 3)

      buf = Buffer.new(10, 10)
      buf = Painter.paint(tagged, layout, buf)

      # Text should be clipped to scroll_box bounds (width 5)
      # Characters beyond x=4 should not appear
      strings = Buffer.to_strings(buf)
      row = Enum.at(strings, 0)
      visible = String.slice(row, 0, 5)
      beyond = String.slice(row, 5, 5)

      assert String.trim(visible) != ""
      assert String.trim(beyond) == ""
    end
  end
end
