defmodule ElixirOpentui.KittyInputTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Input

  describe "Kitty CSI u: basic keys" do
    test "lowercase 'a' (codepoint 97)" do
      [event] = Input.parse("\e[97u")
      assert event.type == :key
      assert event.key == "a"
      assert event.ctrl == false
      assert event.alt == false
      assert event.shift == false
      assert event.meta == false
    end

    test "enter (codepoint 13)" do
      [event] = Input.parse("\e[13u")
      assert event.key == :enter
    end

    test "backspace (codepoint 127)" do
      [event] = Input.parse("\e[127u")
      assert event.key == :backspace
    end

    test "escape (codepoint 27)" do
      [event] = Input.parse("\e[27u")
      assert event.key == :escape
    end

    test "tab (codepoint 9)" do
      [event] = Input.parse("\e[9u")
      assert event.key == :tab
    end

    test "space (codepoint 32)" do
      [event] = Input.parse("\e[32u")
      assert event.key == " "
    end

    test "uppercase 'A' (codepoint 65)" do
      [event] = Input.parse("\e[65u")
      assert event.key == "A"
    end

    test "digit '1' (codepoint 49)" do
      [event] = Input.parse("\e[49u")
      assert event.key == "1"
    end

    test "semicolon (codepoint 59)" do
      [event] = Input.parse("\e[59u")
      assert event.key == ";"
    end

    test "codepoint 0 returns :unknown" do
      [event] = Input.parse("\e[0u")
      assert event.key == :unknown
    end

    test "bare CSI u with no codepoint returns :unknown" do
      [event] = Input.parse("\e[u")
      assert event.key == :unknown
    end
  end

  describe "Kitty CSI u: modifiers" do
    test "shift (modifier 2)" do
      [event] = Input.parse("\e[97;2u")
      assert event.key == "a"
      assert event.shift == true
      assert event.ctrl == false
      assert event.alt == false
      assert event.meta == false
    end

    test "alt (modifier 3)" do
      [event] = Input.parse("\e[97;3u")
      assert event.key == "a"
      assert event.alt == true
      assert event.shift == false
    end

    test "ctrl (modifier 5)" do
      [event] = Input.parse("\e[97;5u")
      assert event.key == "a"
      assert event.ctrl == true
      assert event.shift == false
      assert event.alt == false
    end

    test "ctrl+shift (modifier 6)" do
      [event] = Input.parse("\e[97;6u")
      assert event.key == "a"
      assert event.ctrl == true
      assert event.shift == true
      assert event.alt == false
    end

    test "super/meta (modifier 9)" do
      [event] = Input.parse("\e[97;9u")
      assert event.key == "a"
      assert event.meta == true
      assert event.shift == false
      assert event.ctrl == false
      assert event.alt == false
    end

    test "alt+shift (modifier 4)" do
      [event] = Input.parse("\e[97;4u")
      assert event.key == "a"
      assert event.alt == true
      assert event.shift == true
    end

    test "ctrl+alt (modifier 7)" do
      [event] = Input.parse("\e[97;7u")
      assert event.key == "a"
      assert event.ctrl == true
      assert event.alt == true
    end

    test "ctrl+alt+shift (modifier 8)" do
      [event] = Input.parse("\e[97;8u")
      assert event.key == "a"
      assert event.ctrl == true
      assert event.alt == true
      assert event.shift == true
    end

    test "no modifier (modifier 1 = none)" do
      [event] = Input.parse("\e[97;1u")
      assert event.key == "a"
      assert event.ctrl == false
      assert event.alt == false
      assert event.shift == false
      assert event.meta == false
    end
  end

  describe "Kitty CSI u: event types" do
    test "press event (event_type 1)" do
      [event] = Input.parse("\e[97;1:1u")
      assert event.key == "a"
      assert event.event_type == :press
    end

    test "repeat event (event_type 2)" do
      [event] = Input.parse("\e[97;1:2u")
      assert event.key == "a"
      assert event.event_type == :repeat
    end

    test "release event (event_type 3)" do
      [event] = Input.parse("\e[97;1:3u")
      assert event.key == "a"
      assert event.event_type == :release
    end

    test "no event_type field when not specified" do
      [event] = Input.parse("\e[97u")
      refute Map.has_key?(event, :event_type)
    end

    test "ctrl+shift with release event" do
      [event] = Input.parse("\e[97;6:3u")
      assert event.key == "a"
      assert event.ctrl == true
      assert event.shift == true
      assert event.event_type == :release
    end

    test "modifier with press event" do
      [event] = Input.parse("\e[9;5:1u")
      assert event.key == :tab
      assert event.ctrl == true
      assert event.event_type == :press
    end
  end

  describe "Kitty CSI u: PUA functional keys" do
    test "escape (57344)" do
      [event] = Input.parse("\e[57344u")
      assert event.key == :escape
    end

    test "enter (57345)" do
      [event] = Input.parse("\e[57345u")
      assert event.key == :enter
    end

    test "tab (57346)" do
      [event] = Input.parse("\e[57346u")
      assert event.key == :tab
    end

    test "backspace (57347)" do
      [event] = Input.parse("\e[57347u")
      assert event.key == :backspace
    end

    test "insert (57348)" do
      [event] = Input.parse("\e[57348u")
      assert event.key == :insert
    end

    test "delete (57349)" do
      [event] = Input.parse("\e[57349u")
      assert event.key == :delete
    end

    test "arrows" do
      assert [%{key: :left}] = Input.parse("\e[57350u")
      assert [%{key: :right}] = Input.parse("\e[57351u")
      assert [%{key: :up}] = Input.parse("\e[57352u")
      assert [%{key: :down}] = Input.parse("\e[57353u")
    end

    test "page up/down" do
      assert [%{key: :page_up}] = Input.parse("\e[57354u")
      assert [%{key: :page_down}] = Input.parse("\e[57355u")
    end

    test "home/end" do
      assert [%{key: :home}] = Input.parse("\e[57356u")
      assert [%{key: :end}] = Input.parse("\e[57357u")
    end

    test "F1 (57364)" do
      [event] = Input.parse("\e[57364u")
      assert event.key == :f1
    end

    test "F12 (57375)" do
      [event] = Input.parse("\e[57375u")
      assert event.key == :f12
    end
  end

  describe "Kitty CSI u: PUA special keys" do
    test "caps_lock (57358)" do
      [event] = Input.parse("\e[57358u")
      assert event.key == :caps_lock
    end

    test "num_lock (57360)" do
      [event] = Input.parse("\e[57360u")
      assert event.key == :num_lock
    end

    test "menu (57363)" do
      [event] = Input.parse("\e[57363u")
      assert event.key == :menu
    end

    test "F13 (57376)" do
      [event] = Input.parse("\e[57376u")
      assert event.key == :f13
    end

    test "F35 (57398)" do
      [event] = Input.parse("\e[57398u")
      assert event.key == :f35
    end

    test "keypad 0 (57399)" do
      [event] = Input.parse("\e[57399u")
      assert event.key == :kp_0
    end

    test "keypad enter (57414)" do
      [event] = Input.parse("\e[57414u")
      assert event.key == :kp_enter
    end

    test "media play/pause (57430)" do
      [event] = Input.parse("\e[57430u")
      assert event.key == :media_play_pause
    end

    test "mute volume (57440)" do
      [event] = Input.parse("\e[57440u")
      assert event.key == :mute_volume
    end

    test "left_shift modifier key (57441)" do
      [event] = Input.parse("\e[57441u")
      assert event.key == :left_shift
    end

    test "left_control modifier key (57442)" do
      [event] = Input.parse("\e[57442u")
      assert event.key == :left_control
    end

    test "left_alt modifier key (57443)" do
      [event] = Input.parse("\e[57443u")
      assert event.key == :left_alt
    end

    test "right_super modifier key (57450)" do
      [event] = Input.parse("\e[57450u")
      assert event.key == :right_super
    end
  end

  describe "Kitty CSI u: sub-parameters (shifted codepoint, base layout)" do
    test "shifted codepoint is ignored (primary codepoint used)" do
      # \e[97:65;2u — codepoint 97 ('a'), shifted codepoint 65 ('A'), shift modifier
      [event] = Input.parse("\e[97:65;2u")
      assert event.key == "a"
      assert event.shift == true
    end

    test "base layout codepoint is ignored" do
      # \e[97:65:113u — codepoint 97, shifted 65, base layout 113
      [event] = Input.parse("\e[97:65:113u")
      assert event.key == "a"
    end
  end

  describe "Kitty CSI u: Unicode" do
    test "accented character é (codepoint 233)" do
      [event] = Input.parse("\e[233u")
      assert event.key == "é"
    end

    test "emoji codepoint (128512 = 😀)" do
      [event] = Input.parse("\e[128512u")
      assert event.key == "😀"
    end

    test "CJK character (codepoint 20013 = 中)" do
      [event] = Input.parse("\e[20013u")
      assert event.key == "中"
    end
  end

  describe "Kitty capability query response" do
    test "parses \\e[?5u as capability event" do
      [event] = Input.parse("\e[?5u")
      assert event.type == :capability
      assert event.capability == :kitty_keyboard
      assert event.value == 5
    end

    test "parses \\e[?0u (no flags)" do
      [event] = Input.parse("\e[?0u")
      assert event.type == :capability
      assert event.capability == :kitty_keyboard
      assert event.value == 0
    end

    test "parses \\e[?31u (all flags)" do
      [event] = Input.parse("\e[?31u")
      assert event.type == :capability
      assert event.capability == :kitty_keyboard
      assert event.value == 31
    end

    test "capability event mixed with key events" do
      events = Input.parse("\e[?5u\e[97u")
      assert length(events) == 2
      assert hd(events).type == :capability
      assert List.last(events).type == :key
      assert List.last(events).key == "a"
    end
  end

  describe "enhanced legacy sequences with event_type" do
    test "Ctrl+Up with press event_type" do
      [event] = Input.parse("\e[1;5:1A")
      assert event.key == :up
      assert event.ctrl == true
      assert event.event_type == :press
    end

    test "Ctrl+Right with release event_type" do
      [event] = Input.parse("\e[1;5:3C")
      assert event.key == :right
      assert event.ctrl == true
      assert event.event_type == :release
    end

    test "Shift+Home with repeat event_type" do
      [event] = Input.parse("\e[1;2:2H")
      assert event.key == :home
      assert event.shift == true
      assert event.event_type == :repeat
    end

    test "Ctrl+Delete with press event_type" do
      [event] = Input.parse("\e[3;5:1~")
      assert event.key == :delete
      assert event.ctrl == true
      assert event.event_type == :press
    end

    test "Shift+F5 with event_type" do
      [event] = Input.parse("\e[15;2:1~")
      assert event.key == :f5
      assert event.shift == true
      assert event.event_type == :press
    end
  end

  describe "modifyOtherKeys format: \\e[27;mod;keycode~" do
    test "Ctrl+a" do
      [event] = Input.parse("\e[27;5;97~")
      assert event.key == "a"
      assert event.ctrl == true
      assert event.shift == false
      assert event.alt == false
    end

    test "Shift+Enter" do
      [event] = Input.parse("\e[27;2;13~")
      assert event.key == :enter
      assert event.shift == true
    end

    test "Alt+Escape" do
      [event] = Input.parse("\e[27;3;27~")
      assert event.key == :escape
      assert event.alt == true
    end

    test "Ctrl+space" do
      [event] = Input.parse("\e[27;5;32~")
      assert event.key == " "
      assert event.ctrl == true
    end

    test "Ctrl+Shift+a" do
      [event] = Input.parse("\e[27;6;97~")
      assert event.key == "a"
      assert event.ctrl == true
      assert event.shift == true
    end

    test "Ctrl+backspace" do
      [event] = Input.parse("\e[27;5;127~")
      assert event.key == :backspace
      assert event.ctrl == true
    end

    test "Alt+tab" do
      [event] = Input.parse("\e[27;3;9~")
      assert event.key == :tab
      assert event.alt == true
    end

    test "printable ASCII: Ctrl+[ (91)" do
      [event] = Input.parse("\e[27;5;91~")
      assert event.key == "["
      assert event.ctrl == true
    end

    test "unknown keycode returns :unknown" do
      [event] = Input.parse("\e[27;5;0~")
      assert event.key == :unknown
      assert event.ctrl == true
    end
  end

  describe "modified tilde bugfix (regression tests)" do
    test "Shift+PageUp (was silently dropping modifier)" do
      [event] = Input.parse("\e[5;2~")
      assert event.key == :page_up
      assert event.shift == true
    end

    test "Ctrl+Delete" do
      [event] = Input.parse("\e[3;5~")
      assert event.key == :delete
      assert event.ctrl == true
    end

    test "Alt+Insert" do
      [event] = Input.parse("\e[2;3~")
      assert event.key == :insert
      assert event.alt == true
    end

    test "Shift+PageDown" do
      [event] = Input.parse("\e[6;2~")
      assert event.key == :page_down
      assert event.shift == true
    end

    test "Ctrl+Home (via tilde)" do
      [event] = Input.parse("\e[1;5~")
      assert event.key == :home
      assert event.ctrl == true
    end

    test "Ctrl+F5" do
      [event] = Input.parse("\e[15;5~")
      assert event.key == :f5
      assert event.ctrl == true
    end

    test "Shift+F12" do
      [event] = Input.parse("\e[24;2~")
      assert event.key == :f12
      assert event.shift == true
    end
  end

  describe "backward compatibility" do
    test "legacy arrow keys still work" do
      assert [%{key: :up}] = Input.parse("\e[A")
      assert [%{key: :down}] = Input.parse("\e[B")
      assert [%{key: :right}] = Input.parse("\e[C")
      assert [%{key: :left}] = Input.parse("\e[D")
    end

    test "legacy tilde keys still work" do
      assert [%{key: :home}] = Input.parse("\e[1~")
      assert [%{key: :insert}] = Input.parse("\e[2~")
      assert [%{key: :delete}] = Input.parse("\e[3~")
      assert [%{key: :end}] = Input.parse("\e[4~")
      assert [%{key: :page_up}] = Input.parse("\e[5~")
      assert [%{key: :page_down}] = Input.parse("\e[6~")
    end

    test "legacy function keys still work" do
      assert [%{key: :f1}] = Input.parse("\eOP")
      assert [%{key: :f5}] = Input.parse("\e[15~")
      assert [%{key: :f12}] = Input.parse("\e[24~")
    end

    test "legacy modified arrows still work" do
      [event] = Input.parse("\e[1;2A")
      assert event.key == :up
      assert event.shift == true
    end

    test "legacy control characters still work" do
      [event] = Input.parse(<<1>>)
      assert event.key == "a"
      assert event.ctrl == true
    end

    test "legacy tab and enter" do
      assert [%{key: :tab}] = Input.parse(<<9>>)
      assert [%{key: :enter}] = Input.parse(<<13>>)
    end

    test "legacy backspace" do
      assert [%{key: :backspace}] = Input.parse(<<127>>)
    end

    test "legacy bare escape" do
      assert [%{key: :escape}] = Input.parse("\e")
    end

    test "legacy shift+tab (backtab)" do
      [event] = Input.parse("\e[Z")
      assert event.key == :tab
      assert event.shift == true
    end

    test "legacy mouse events still work" do
      [event] = Input.parse("\e[<0;6;11M")
      assert event.type == :mouse
      assert event.action == :press
      assert event.button == :left
    end

    test "legacy bracketed paste still works" do
      [event] = Input.parse("\e[200~Hello\e[201~")
      assert event.type == :paste
      assert event.data == "Hello"
    end

    test "legacy events do not have :event_type field" do
      [event] = Input.parse("\e[A")
      refute Map.has_key?(event, :event_type)
    end
  end

  describe "Kitty disambiguates Tab from Ctrl+I" do
    test "Tab via Kitty (codepoint 9, no modifier)" do
      [event] = Input.parse("\e[9u")
      assert event.key == :tab
      assert event.ctrl == false
    end

    test "Ctrl+I via Kitty (codepoint 105, ctrl modifier)" do
      [event] = Input.parse("\e[105;5u")
      assert event.key == "i"
      assert event.ctrl == true
    end

    test "Enter via Kitty (codepoint 13, no modifier)" do
      [event] = Input.parse("\e[13u")
      assert event.key == :enter
      assert event.ctrl == false
    end

    test "Ctrl+M via Kitty (codepoint 109, ctrl modifier)" do
      [event] = Input.parse("\e[109;5u")
      assert event.key == "m"
      assert event.ctrl == true
    end
  end

  describe "multiple Kitty events in one chunk" do
    test "two key events" do
      events = Input.parse("\e[97u\e[98u")
      assert length(events) == 2
      assert Enum.map(events, & &1.key) == ["a", "b"]
    end

    test "Kitty event followed by legacy event" do
      events = Input.parse("\e[97u\e[A")
      assert length(events) == 2
      assert hd(events).key == "a"
      assert List.last(events).key == :up
    end

    test "Kitty event followed by mouse event" do
      events = Input.parse("\e[97u\e[<0;1;1M")
      assert length(events) == 2
      assert hd(events).type == :key
      assert List.last(events).type == :mouse
    end
  end
end
