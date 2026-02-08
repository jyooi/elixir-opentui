defmodule ElixirOpentui.NativeBufferTest do
  use ExUnit.Case, async: true

  @moduletag :nif

  alias ElixirOpentui.NativeBuffer

  describe "new/3" do
    test "creates a native buffer" do
      buf = NativeBuffer.new(80, 24)
      assert buf.cols == 80
      assert buf.rows == 24
      assert is_reference(buf.ref)
    end
  end

  describe "draw_char/6 and flush/1" do
    test "draws a character and reads it back after render" do
      buf = NativeBuffer.new(10, 5)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.draw_char(buf, 3, 2, "A", {255, 0, 0, 255}, {0, 0, 255, 255})
      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)

      cell = NativeBuffer.get_cell(buf, 3, 2)
      assert cell.char == "A"
      assert cell.fg == {255, 0, 0, 255}
      assert cell.bg == {0, 0, 255, 255}
    end
  end

  describe "draw_text/6" do
    test "draws a string horizontally" do
      buf = NativeBuffer.new(10, 3)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.draw_text(buf, 1, 0, "Hi!", {255, 255, 255, 255}, {0, 0, 0, 255})
      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)

      rows = NativeBuffer.to_strings(buf)
      assert String.starts_with?(hd(rows), " Hi!")
    end
  end

  describe "fill_rect/8" do
    test "fills a rectangular region" do
      buf = NativeBuffer.new(10, 5)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.fill_rect(buf, 2, 1, 3, 2, "#", {0, 255, 0, 255}, {0, 0, 0, 255})
      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)

      for x <- 2..4, y <- 1..2 do
        cell = NativeBuffer.get_cell(buf, x, y)
        assert cell.char == "#", "Expected '#' at (#{x}, #{y})"
      end

      cell = NativeBuffer.get_cell(buf, 0, 0)
      assert cell.char == " "
    end
  end

  describe "set_hit_region/6 and get_hit_id/3" do
    test "maps atom hit_id through u16" do
      buf = NativeBuffer.new(10, 5)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.set_hit_region(buf, 1, 1, 3, 2, :my_button)
      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)

      assert NativeBuffer.get_hit_id(buf, 1, 1) == :my_button
      assert NativeBuffer.get_hit_id(buf, 3, 2) == :my_button
      assert NativeBuffer.get_hit_id(buf, 0, 0) == nil
    end

    test "multiple different hit_ids" do
      buf = NativeBuffer.new(10, 5)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.set_hit_region(buf, 0, 0, 2, 1, :btn_a)
      buf = NativeBuffer.set_hit_region(buf, 5, 0, 2, 1, :btn_b)
      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)

      assert NativeBuffer.get_hit_id(buf, 0, 0) == :btn_a
      assert NativeBuffer.get_hit_id(buf, 1, 0) == :btn_a
      assert NativeBuffer.get_hit_id(buf, 5, 0) == :btn_b
      assert NativeBuffer.get_hit_id(buf, 6, 0) == :btn_b
      assert NativeBuffer.get_hit_id(buf, 3, 0) == nil
    end
  end

  describe "clear/1" do
    test "clears back buffer and ops" do
      buf = NativeBuffer.new(5, 3)
      buf = NativeBuffer.draw_char(buf, 0, 0, "X", {255, 0, 0, 255}, {0, 0, 0, 255})
      buf = NativeBuffer.clear(buf)
      assert buf.ops == []
    end
  end

  describe "to_strings/1" do
    test "returns list of row strings from front buffer" do
      buf = NativeBuffer.new(5, 2)
      rows = NativeBuffer.to_strings(buf)
      assert rows == ["     ", "     "]
    end

    test "reflects content after render" do
      buf = NativeBuffer.new(5, 2)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.draw_text(buf, 0, 0, "AB", {255, 255, 255, 255}, {0, 0, 0, 255})
      {buf, _ansi} = NativeBuffer.render_frame_capture(buf)

      rows = NativeBuffer.to_strings(buf)
      assert hd(rows) == "AB   "
    end
  end

  describe "render_frame_capture/1" do
    test "returns ANSI binary" do
      buf = NativeBuffer.new(10, 3)
      buf = NativeBuffer.clear(buf)
      buf = NativeBuffer.draw_char(buf, 0, 0, "Z", {128, 64, 32, 255}, {10, 20, 30, 255})
      {_buf, ansi} = NativeBuffer.render_frame_capture(buf)

      assert is_binary(ansi)
      assert String.contains?(ansi, "Z")
      assert String.contains?(ansi, "\e[1;1H")
    end

    test "no changes produces empty output" do
      buf = NativeBuffer.new(5, 3)
      {_buf, ansi} = NativeBuffer.render_frame_capture(buf)
      assert ansi == ""
    end
  end

  describe "diff/2" do
    test "raises error" do
      buf = NativeBuffer.new(5, 3)
      assert_raise RuntimeError, ~r/render_frame/, fn -> NativeBuffer.diff(buf, buf) end
    end
  end
end
