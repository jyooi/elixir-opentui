defmodule ElixirOpentui.NIFTest do
  use ExUnit.Case, async: true

  @moduletag :nif

  alias ElixirOpentui.NIF

  describe "init/2" do
    test "creates a FrameBuffer resource" do
      ref = NIF.init(80, 24)
      assert is_reference(ref)
    end

    test "creates 1x1 buffer" do
      ref = NIF.init(1, 1)
      assert is_reference(ref)
    end
  end

  describe "clear/1 and get_cell_data/3" do
    test "blank cell has space char and default colors" do
      ref = NIF.init(10, 5)
      # get_cell_data reads from front buffer — need to render first to swap
      # After init, front is blank, so get_cell_data returns blank
      {char, fr, fg, fb, br, bg, bb, attrs, hit_id} = NIF.get_cell_data(ref, 0, 0)
      assert char == " "
      assert {fr, fg, fb} == {255, 255, 255}
      assert {br, bg, bb} == {0, 0, 0}
      assert attrs == 0
      assert hit_id == 0
    end

    test "out of bounds returns nil" do
      ref = NIF.init(10, 5)
      assert NIF.get_cell_data(ref, 10, 0) == nil
      assert NIF.get_cell_data(ref, 0, 5) == nil
    end
  end

  describe "put_cells/2 + render_frame_capture/1" do
    test "CELL record round-trip" do
      ref = NIF.init(10, 5)
      NIF.clear(ref)

      # Write 'A' at (3, 2) with red fg, blue bg
      cell = <<1, 3::16-little, 2::16-little, ?A, 0, 0, 0, 255, 0, 0, 0, 0, 255, 0, 0::16-little>>
      NIF.put_cells(ref, cell)

      # Capture frame (diffs back vs front, produces ANSI, swaps)
      ansi = NIF.render_frame_capture(ref)
      assert is_binary(ansi)
      assert String.contains?(ansi, "A")

      # After swap, front should have 'A' at (3, 2)
      {char, fr, _fg, _fb, _br, _bg, bb, _attrs, _hit_id} = NIF.get_cell_data(ref, 3, 2)
      assert char == "A"
      assert fr == 255
      assert bb == 255
    end

    test "FILL record fills a rectangle" do
      ref = NIF.init(10, 5)
      NIF.clear(ref)

      # Fill 3x2 rect at (1,1) with '#', green fg, black bg
      fill =
        <<2, 1::16-little, 1::16-little, 3::16-little, 2::16-little, ?#, 0, 0, 0, 0, 255, 0, 0, 0,
          0, 0>>

      NIF.put_cells(ref, fill)
      _ansi = NIF.render_frame_capture(ref)

      # Check all cells in the rect
      for x <- 1..3, y <- 1..2 do
        {char, _fr, fg, _fb, _br, _bg, _bb, _attrs, _hit} = NIF.get_cell_data(ref, x, y)
        assert char == "#", "Expected '#' at (#{x}, #{y})"
        assert fg == 255
      end

      # Cell outside rect should be blank
      {char, _, _, _, _, _, _, _, _} = NIF.get_cell_data(ref, 0, 0)
      assert char == " "
    end

    test "HIT record sets hit_id" do
      ref = NIF.init(10, 5)
      NIF.clear(ref)

      # Set hit_id 42 on 2x1 rect at (5, 3)
      hit = <<3, 5::16-little, 3::16-little, 2::16-little, 1::16-little, 42::16-little>>
      NIF.put_cells(ref, hit)
      _ansi = NIF.render_frame_capture(ref)

      assert NIF.get_hit_id(ref, 5, 3) == 42
      assert NIF.get_hit_id(ref, 6, 3) == 42
      assert NIF.get_hit_id(ref, 4, 3) == nil
    end

    test "batch protocol with multiple records" do
      ref = NIF.init(10, 5)
      NIF.clear(ref)

      # Two CELL records + one HIT
      batch = <<
        1,
        0::16-little,
        0::16-little,
        ?X,
        0,
        0,
        0,
        200,
        200,
        200,
        50,
        50,
        50,
        0,
        0::16-little,
        1,
        1::16-little,
        0::16-little,
        ?Y,
        0,
        0,
        0,
        200,
        200,
        200,
        50,
        50,
        50,
        0,
        0::16-little,
        3,
        0::16-little,
        0::16-little,
        2::16-little,
        1::16-little,
        7::16-little
      >>

      NIF.put_cells(ref, batch)
      _ansi = NIF.render_frame_capture(ref)

      {char_x, _, _, _, _, _, _, _, _} = NIF.get_cell_data(ref, 0, 0)
      {char_y, _, _, _, _, _, _, _, _} = NIF.get_cell_data(ref, 1, 0)
      assert char_x == "X"
      assert char_y == "Y"
      assert NIF.get_hit_id(ref, 0, 0) == 7
      assert NIF.get_hit_id(ref, 1, 0) == 7
    end
  end

  describe "render_frame_capture/1" do
    test "no changes produces empty output" do
      ref = NIF.init(5, 3)
      # Front and back are identical (both blank)
      ansi = NIF.render_frame_capture(ref)
      assert ansi == ""
    end

    test "captures ANSI with cursor move and SGR" do
      ref = NIF.init(5, 3)
      NIF.clear(ref)

      cell =
        <<1, 2::16-little, 1::16-little, ?Z, 0, 0, 0, 128, 64, 32, 10, 20, 30, 0, 0::16-little>>

      NIF.put_cells(ref, cell)
      ansi = NIF.render_frame_capture(ref)

      # Should contain ESC[row;colH cursor move (1-based: row=2, col=3)
      assert String.contains?(ansi, "\e[2;3H")
      # Should contain SGR with fg 128;64;32
      assert String.contains?(ansi, "38;2;128;64;32")
      # Should contain the character
      assert String.contains?(ansi, "Z")
      # Should end with SGR reset
      assert String.ends_with?(ansi, "\e[0m")
    end
  end

  describe "to_strings/1" do
    test "returns list of row strings from front buffer" do
      ref = NIF.init(5, 2)
      # Front is blank — all spaces
      rows = NIF.to_strings(ref)
      assert rows == ["     ", "     "]
    end

    test "reflects content after render" do
      ref = NIF.init(5, 2)
      NIF.clear(ref)

      # Write "Hi" at row 0
      batch = <<
        1,
        0::16-little,
        0::16-little,
        ?H,
        0,
        0,
        0,
        255,
        255,
        255,
        0,
        0,
        0,
        0,
        0::16-little,
        1,
        1::16-little,
        0::16-little,
        ?i,
        0,
        0,
        0,
        255,
        255,
        255,
        0,
        0,
        0,
        0,
        0::16-little
      >>

      NIF.put_cells(ref, batch)
      _ansi = NIF.render_frame_capture(ref)

      rows = NIF.to_strings(ref)
      assert hd(rows) == "Hi   "
    end
  end

  describe "resize/3" do
    test "changes buffer dimensions" do
      ref = NIF.init(10, 5)
      NIF.resize(ref, 20, 10)

      # Should be able to access new dimensions
      assert NIF.get_cell_data(ref, 19, 9) != nil
      assert NIF.get_cell_data(ref, 20, 10) == nil
    end
  end

  describe "get_hit_id/3" do
    test "returns nil for no hit" do
      ref = NIF.init(10, 5)
      assert NIF.get_hit_id(ref, 0, 0) == nil
    end

    test "returns nil for out of bounds" do
      ref = NIF.init(10, 5)
      assert NIF.get_hit_id(ref, 100, 100) == nil
    end
  end

  describe "dim/inverse attrs round-trip" do
    test "NIF backend dim/inverse round-trip through attrs byte" do
      ref = NIF.init(10, 5)
      NIF.clear(ref)

      # attrs byte: bold(1) | dim(16) | inverse(32) = 49
      attrs = Bitwise.bor(1, Bitwise.bor(16, 32))

      cell =
        <<1, 0::16-little, 0::16-little, ?X, 0, 0, 0, 255, 255, 255, 0, 0, 0, attrs,
          0::16-little>>

      NIF.put_cells(ref, cell)
      ansi = NIF.render_frame_capture(ref)

      assert String.contains?(ansi, "X")
      # SGR should contain ;1 (bold), ;2 (dim), ;7 (inverse)
      assert String.contains?(ansi, ";1")
      assert String.contains?(ansi, ";2")
      assert String.contains?(ansi, ";7")

      # Verify get_cell_data returns correct attrs
      {_char, _fr, _fg, _fb, _br, _bg, _bb, stored_attrs, _hit} = NIF.get_cell_data(ref, 0, 0)
      assert Bitwise.band(stored_attrs, 1) != 0
      assert Bitwise.band(stored_attrs, 16) != 0
      assert Bitwise.band(stored_attrs, 32) != 0
    end
  end

  describe "available?/0" do
    test "returns true when NIF is loaded" do
      assert NIF.available?() == true
    end
  end
end
