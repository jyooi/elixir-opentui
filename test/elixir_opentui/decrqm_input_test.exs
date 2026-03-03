defmodule ElixirOpentui.DecrqmInputTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Input

  describe "DECRQM response parsing" do
    test "parses mode 2026 status 1 (set)" do
      # \e[?2026;1$y
      [event] = Input.parse("\e[?2026;1$y")
      assert event.type == :capability
      assert event.capability == :decrqm
      assert event.mode == 2026
      assert event.status == 1
    end

    test "parses mode 2026 status 0 (not recognized)" do
      [event] = Input.parse("\e[?2026;0$y")
      assert event.type == :capability
      assert event.capability == :decrqm
      assert event.mode == 2026
      assert event.status == 0
    end

    test "parses mode 2026 status 2 (reset)" do
      [event] = Input.parse("\e[?2026;2$y")
      assert event.type == :capability
      assert event.capability == :decrqm
      assert event.mode == 2026
      assert event.status == 2
    end

    test "parses mode 2026 status 4 (permanently reset)" do
      [event] = Input.parse("\e[?2026;4$y")
      assert event.type == :capability
      assert event.capability == :decrqm
      assert event.mode == 2026
      assert event.status == 4
    end

    test "parses different mode (2004 bracketed paste)" do
      [event] = Input.parse("\e[?2004;1$y")
      assert event.type == :capability
      assert event.capability == :decrqm
      assert event.mode == 2004
      assert event.status == 1
    end

    test "DECRQM followed by regular key parses both events" do
      events = Input.parse("\e[?2026;1$ya")
      assert length(events) == 2

      [decrqm, key] = events
      assert decrqm.type == :capability
      assert decrqm.capability == :decrqm
      assert decrqm.mode == 2026

      assert key.type == :key
      assert key.key == "a"
    end

    test "DECRQM followed by kitty keyboard response parses both" do
      # DECRQM response + kitty keyboard query response
      events = Input.parse("\e[?2026;2$y\e[?5u")
      assert length(events) == 2

      [decrqm, kitty] = events
      assert decrqm.type == :capability
      assert decrqm.capability == :decrqm
      assert decrqm.mode == 2026
      assert decrqm.status == 2

      assert kitty.type == :capability
      assert kitty.capability == :kitty_keyboard
      assert kitty.value == 5
    end
  end
end
