defmodule ElixirOpentui.ANSITest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{ANSI, Buffer}

  describe "cursor control" do
    test "move_to generates correct escape sequence" do
      assert IO.iodata_to_binary(ANSI.move_to(0, 0)) == "\e[1;1H"
      assert IO.iodata_to_binary(ANSI.move_to(5, 10)) == "\e[11;6H"
    end

    test "hide/show cursor" do
      assert IO.iodata_to_binary(ANSI.hide_cursor()) == "\e[?25l"
      assert IO.iodata_to_binary(ANSI.show_cursor()) == "\e[?25h"
    end

    test "save/restore cursor" do
      assert IO.iodata_to_binary(ANSI.save_cursor()) == "\e7"
      assert IO.iodata_to_binary(ANSI.restore_cursor()) == "\e8"
    end
  end

  describe "screen control" do
    test "clear screen" do
      assert IO.iodata_to_binary(ANSI.clear_screen()) == "\e[2J"
    end

    test "alt screen" do
      assert IO.iodata_to_binary(ANSI.enter_alt_screen()) == "\e[?1049h"
      assert IO.iodata_to_binary(ANSI.leave_alt_screen()) == "\e[?1049l"
    end

    test "reset" do
      assert IO.iodata_to_binary(ANSI.reset()) == "\e[0m"
    end
  end

  describe "mouse mode" do
    test "enable/disable mouse" do
      enable = IO.iodata_to_binary(ANSI.enable_mouse())
      assert String.contains?(enable, "\e[?1000h")
      assert String.contains?(enable, "\e[?1006h")

      disable = IO.iodata_to_binary(ANSI.disable_mouse())
      assert String.contains?(disable, "\e[?1000l")
      assert String.contains?(disable, "\e[?1006l")
    end
  end

  describe "SGR color sequences" do
    test "generates truecolor fg/bg" do
      white = {255, 255, 255, 255}
      black = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(white, black, false, false, false, false))
      assert String.contains?(result, "38;2;255;255;255")
      assert String.contains?(result, "48;2;0;0;0")
    end

    test "includes bold attribute" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, true, false, false, false))
      assert String.contains?(result, "1;")
    end

    test "includes italic attribute" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, false, true, false, false))
      assert String.contains?(result, "3;")
    end

    test "includes underline attribute" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, false, false, true, false))
      assert String.contains?(result, "4;")
    end

    test "includes strikethrough attribute" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, false, false, false, true))
      assert String.contains?(result, "9;")
    end

    test "combined attributes" do
      fg = {255, 0, 0, 255}
      bg = {0, 0, 255, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, true, true, true, false))
      assert String.contains?(result, "1")
      assert String.contains?(result, "3")
      assert String.contains?(result, "4")
      assert String.contains?(result, "38;2;255;0;0")
      assert String.contains?(result, "48;2;0;0;255")
    end
  end

  describe "dim and inverse attributes" do
    test "dim attribute renders SGR code 2" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, false, false, false, false, true, false))
      assert String.contains?(result, "2;")
    end

    test "inverse attribute renders SGR code 7" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, false, false, false, false, false, true))
      assert String.contains?(result, "7;")
    end

    test "dim + bold combines correctly" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, true, false, false, false, true, false))
      assert String.contains?(result, "1")
      assert String.contains?(result, "2")
    end
  end

  describe "blink and hidden attributes" do
    test "blink attribute renders SGR code 5" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, false, false, false, false, false, false, true, false))
      assert String.contains?(result, "5;")
    end

    test "hidden attribute renders SGR code 8" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, false, false, false, false, false, false, false, true))
      assert String.contains?(result, "8;")
    end

    test "blink + hidden combines correctly" do
      fg = {255, 255, 255, 255}
      bg = {0, 0, 0, 255}
      result = IO.iodata_to_binary(ANSI.sgr(fg, bg, false, false, false, false, false, false, true, true))
      assert String.contains?(result, "5")
      assert String.contains?(result, "8")
    end
  end

  describe "cursor shape" do
    test "block cursor shape (steady)" do
      assert IO.iodata_to_binary(ANSI.cursor_shape(:block)) == "\e[2 q"
    end

    test "underline cursor shape (steady)" do
      assert IO.iodata_to_binary(ANSI.cursor_shape(:underline)) == "\e[4 q"
    end

    test "bar cursor shape (steady)" do
      assert IO.iodata_to_binary(ANSI.cursor_shape(:bar)) == "\e[6 q"
    end

    test "block cursor shape (blinking)" do
      assert IO.iodata_to_binary(ANSI.cursor_shape(:block, blink: true)) == "\e[1 q"
    end

    test "underline cursor shape (blinking)" do
      assert IO.iodata_to_binary(ANSI.cursor_shape(:underline, blink: true)) == "\e[3 q"
    end

    test "bar cursor shape (blinking)" do
      assert IO.iodata_to_binary(ANSI.cursor_shape(:bar, blink: true)) == "\e[5 q"
    end
  end

  describe "full frame rendering" do
    test "renders a simple buffer" do
      buf = Buffer.new(3, 1)
      buf = Buffer.draw_text(buf, 0, 0, "Hi!", {255, 255, 255, 255}, {0, 0, 0, 255})
      result = IO.iodata_to_binary(ANSI.render_full(buf))

      assert String.contains?(result, "H")
      assert String.contains?(result, "i")
      assert String.contains?(result, "!")
    end

    test "positions cursor for each row" do
      buf = Buffer.new(5, 2)
      result = IO.iodata_to_binary(ANSI.render_full(buf))
      assert String.contains?(result, "\e[1;1H")
      assert String.contains?(result, "\e[2;1H")
    end
  end

  describe "diff rendering" do
    test "empty diff produces no output" do
      result = IO.iodata_to_binary(ANSI.render_diff([]))
      assert result == ""
    end

    test "single cell change" do
      cell = %{
        char: "X",
        fg: {255, 0, 0, 255},
        bg: {0, 0, 0, 255},
        bold: false,
        italic: false,
        underline: false,
        strikethrough: false,
        dim: false,
        inverse: false,
        blink: false,
        hidden: false,
        hit_id: nil
      }

      result = IO.iodata_to_binary(ANSI.render_diff([{5, 3, cell}]))
      assert String.contains?(result, "\e[4;6H")
      assert String.contains?(result, "X")
    end

    test "consecutive changes grouped" do
      white = {255, 255, 255, 255}
      black = {0, 0, 0, 255}

      cell_a = %{char: "A", fg: white, bg: black, bold: false, italic: false, underline: false, strikethrough: false, dim: false, inverse: false, blink: false, hidden: false, hit_id: nil}
      cell_b = %{char: "B", fg: white, bg: black, bold: false, italic: false, underline: false, strikethrough: false, dim: false, inverse: false, blink: false, hidden: false, hit_id: nil}

      result = IO.iodata_to_binary(ANSI.render_diff([{0, 0, cell_a}, {1, 0, cell_b}]))
      assert String.contains?(result, "A")
      assert String.contains?(result, "B")
      count = result |> String.split("\e[") |> length()
      assert count < 6
    end
  end

  describe "frame wrapper" do
    test "wraps content with cursor hide/show" do
      result = IO.iodata_to_binary(ANSI.frame("hello"))
      assert String.starts_with?(result, "\e[?25l")
      assert String.ends_with?(result, "\e[?25h")
      assert String.contains?(result, "hello")
    end
  end
end
