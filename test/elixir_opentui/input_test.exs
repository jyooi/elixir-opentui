defmodule ElixirOpentui.InputTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Input

  describe "regular characters" do
    test "parses single ASCII character" do
      [event] = Input.parse("a")
      assert event.type == :key
      assert event.key == "a"
      assert event.ctrl == false
      assert event.alt == false
      assert event.shift == false
      assert event.meta == false
    end

    test "uppercase sets shift flag" do
      [event] = Input.parse("A")
      assert event.key == "A"
      assert event.shift == true
    end

    test "parses multiple characters" do
      events = Input.parse("abc")
      assert length(events) == 3
      assert Enum.map(events, & &1.key) == ["a", "b", "c"]
    end

    test "parses UTF-8 characters" do
      [event] = Input.parse("é")
      assert event.key == "é"
    end

    test "parses space" do
      [event] = Input.parse(" ")
      assert event.key == " "
    end
  end

  describe "control keys" do
    test "Ctrl+A through Ctrl+Z" do
      [event] = Input.parse(<<1>>)
      assert event.key == "a"
      assert event.ctrl == true
    end

    test "Ctrl+C" do
      [event] = Input.parse(<<3>>)
      assert event.key == "c"
      assert event.ctrl == true
    end

    test "Tab (Ctrl+I)" do
      [event] = Input.parse(<<9>>)
      assert event.key == :tab
    end

    test "Enter (Ctrl+M / CR)" do
      [event] = Input.parse(<<13>>)
      assert event.key == :enter
    end

    test "Enter (LF)" do
      [event] = Input.parse(<<10>>)
      assert event.key == :enter
    end

    test "Backspace (127)" do
      [event] = Input.parse(<<127>>)
      assert event.key == :backspace
    end
  end

  describe "escape key" do
    test "bare escape" do
      [event] = Input.parse("\e")
      assert event.key == :escape
    end
  end

  describe "arrow keys" do
    test "up arrow" do
      [event] = Input.parse("\e[A")
      assert event.key == :up
    end

    test "down arrow" do
      [event] = Input.parse("\e[B")
      assert event.key == :down
    end

    test "right arrow" do
      [event] = Input.parse("\e[C")
      assert event.key == :right
    end

    test "left arrow" do
      [event] = Input.parse("\e[D")
      assert event.key == :left
    end
  end

  describe "navigation keys" do
    test "home" do
      [event] = Input.parse("\e[H")
      assert event.key == :home
    end

    test "end" do
      [event] = Input.parse("\e[F")
      assert event.key == :end
    end

    test "home via tilde" do
      [event] = Input.parse("\e[1~")
      assert event.key == :home
    end

    test "end via tilde" do
      [event] = Input.parse("\e[4~")
      assert event.key == :end
    end

    test "insert" do
      [event] = Input.parse("\e[2~")
      assert event.key == :insert
    end

    test "delete" do
      [event] = Input.parse("\e[3~")
      assert event.key == :delete
    end

    test "page up" do
      [event] = Input.parse("\e[5~")
      assert event.key == :page_up
    end

    test "page down" do
      [event] = Input.parse("\e[6~")
      assert event.key == :page_down
    end
  end

  describe "function keys" do
    test "F1-F4 via SS3" do
      assert [%{key: :f1}] = Input.parse("\eOP")
      assert [%{key: :f2}] = Input.parse("\eOQ")
      assert [%{key: :f3}] = Input.parse("\eOR")
      assert [%{key: :f4}] = Input.parse("\eOS")
    end

    test "F5-F12 via CSI tilde" do
      assert [%{key: :f5}] = Input.parse("\e[15~")
      assert [%{key: :f6}] = Input.parse("\e[17~")
      assert [%{key: :f7}] = Input.parse("\e[18~")
      assert [%{key: :f8}] = Input.parse("\e[19~")
      assert [%{key: :f9}] = Input.parse("\e[20~")
      assert [%{key: :f10}] = Input.parse("\e[21~")
      assert [%{key: :f11}] = Input.parse("\e[23~")
      assert [%{key: :f12}] = Input.parse("\e[24~")
    end
  end

  describe "modified keys" do
    test "Shift+Up" do
      [event] = Input.parse("\e[1;2A")
      assert event.key == :up
      assert event.shift == true
      assert event.ctrl == false
      assert event.alt == false
      assert event.meta == false
    end

    test "Alt+Up" do
      [event] = Input.parse("\e[1;3A")
      assert event.key == :up
      assert event.alt == true
    end

    test "Ctrl+Up" do
      [event] = Input.parse("\e[1;5A")
      assert event.key == :up
      assert event.ctrl == true
    end

    test "Ctrl+Shift+Right" do
      [event] = Input.parse("\e[1;6C")
      assert event.key == :right
      assert event.ctrl == true
      assert event.shift == true
    end

    test "Shift+Tab (backtab)" do
      [event] = Input.parse("\e[Z")
      assert event.key == :tab
      assert event.shift == true
    end
  end

  describe "Alt+key" do
    test "Alt+a" do
      [event] = Input.parse("\ea")
      assert event.key == "a"
      assert event.alt == true
    end

    test "Alt+A (shift)" do
      [event] = Input.parse("\eA")
      assert event.key == "A"
      assert event.alt == true
      assert event.shift == true
    end
  end

  describe "SGR mouse events" do
    test "left click at (5, 10)" do
      [event] = Input.parse("\e[<0;6;11M")
      assert event.type == :mouse
      assert event.action == :press
      assert event.button == :left
      assert event.x == 5
      assert event.y == 10
    end

    test "left release" do
      [event] = Input.parse("\e[<0;1;1m")
      assert event.type == :mouse
      assert event.action == :release
      assert event.button == :left
      assert event.x == 0
      assert event.y == 0
    end

    test "right click" do
      [event] = Input.parse("\e[<2;1;1M")
      assert event.action == :press
      assert event.button == :right
    end

    test "middle click" do
      [event] = Input.parse("\e[<1;1;1M")
      assert event.action == :press
      assert event.button == :middle
    end

    test "scroll up" do
      [event] = Input.parse("\e[<64;5;5M")
      assert event.action == :scroll_up
    end

    test "scroll down" do
      [event] = Input.parse("\e[<65;5;5M")
      assert event.action == :scroll_down
    end

    test "mouse move (motion)" do
      [event] = Input.parse("\e[<32;10;20M")
      assert event.action == :move
      assert event.button == :left
    end

    test "mouse with ctrl modifier" do
      [event] = Input.parse("\e[<16;1;1M")
      assert event.ctrl == true
    end

    test "mouse with alt modifier" do
      [event] = Input.parse("\e[<8;1;1M")
      assert event.alt == true
    end

    test "mouse with shift modifier" do
      [event] = Input.parse("\e[<4;1;1M")
      assert event.shift == true
    end
  end

  describe "bracketed paste" do
    test "parses paste event" do
      [event] = Input.parse("\e[200~Hello World\e[201~")
      assert event.type == :paste
      assert event.data == "Hello World"
    end

    test "paste with special characters" do
      [event] = Input.parse("\e[200~line1\nline2\e[201~")
      assert event.data == "line1\nline2"
    end
  end

  describe "mixed input" do
    test "key followed by mouse event" do
      events = Input.parse("a\e[<0;1;1M")
      assert length(events) == 2
      assert hd(events).type == :key
      assert List.last(events).type == :mouse
    end

    test "multiple escape sequences" do
      events = Input.parse("\e[A\e[B\e[C")
      assert length(events) == 3
      assert Enum.map(events, & &1.key) == [:up, :down, :right]
    end
  end
end
