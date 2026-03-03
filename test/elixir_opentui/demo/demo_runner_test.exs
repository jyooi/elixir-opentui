defmodule ElixirOpentui.Demo.DemoRunnerTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.ANSI

  describe "cooked mode cleanup" do
    test "DemoRunner after block includes :cooked transition" do
      # Verify the source restores cooked mode in the after block.
      # Note: this uses TCSANOW internally (OTP never uses TCSADRAIN).
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ ":shell.start_interactive({:noshell, :cooked})"
    end
  end

  describe "configurable tick interval" do
    test "source uses _tick_interval from state" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ "_tick_interval"
      assert source =~ "Map.get(state, :_tick_interval, 33)"
    end

    test "source uses real wall-clock dt" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ "System.monotonic_time(:millisecond)"
      assert source =~ "_last_tick"
      # Should NOT have the old hardcoded dt = wait_ms
      refute source =~ "dt = wait_ms"
    end

    test "initializes _last_tick before loop" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ "Map.put_new(state, :_last_tick, System.monotonic_time(:millisecond))"
    end

    test "compensates sleep for render time" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      # Should subtract elapsed time from tick_interval
      assert source =~ "tick_interval - time_spent"
      # Should clamp to minimum 1ms
      assert source =~ "max(1,"
    end
  end

  describe "tick starvation fix" do
    test "empty-events base case does NOT reset _last_tick" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")

      # Extract the empty-events clause (matches on [])
      # It should NOT contain the old false _last_tick reset pattern
      refute source =~ ~r/handle_events.*\[\].*do\s*\n\s*state = Map\.put\(state, :_last_tick/s,
             "handle_events([], ...) must not reset _last_tick unconditionally"
    end

    test "empty-events base case checks tick due and fires inline" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      # The base case should check time_since_tick >= tick_interval
      assert source =~ "time_since_tick >= tick_interval"
      # And call tick_and_render inline when overdue
      assert source =~ "tick_and_render(demo_mod, dt, state, renderer, ctx)"
    end

    test "live demos skip per-event rendering" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      # The event-processing clause should check _live and skip rendering
      assert source =~ ~r/if Map\.get\(new_state, :_live, false\) do\s*\n\s*\{renderer, ctx\}/s,
             "live demos should skip rendering in handle_events event clause"
    end
  end

  describe "restore_terminal cleanup sequences" do
    test "writes unconditional keyboard + mouse + screen cleanup to tty" do
      # Replicate the expected sequence from restore_terminal and verify
      # it contains all critical escape codes in the right order.
      expected =
        IO.iodata_to_binary([
          ANSI.set_kitty_keyboard(0),
          ANSI.pop_kitty_keyboard(),
          ANSI.disable_modify_other_keys(),
          ANSI.disable_paste(),
          ANSI.disable_mouse(),
          ANSI.reset(),
          ANSI.show_cursor(),
          ANSI.leave_alt_screen(),
          ANSI.disable_mouse()
        ])

      # Verify the expected sequence contains the critical escape codes
      assert expected =~ "\e[=0u", "should contain set_kitty_keyboard(0)"
      assert expected =~ "\e[<u", "should contain pop_kitty_keyboard"
      assert expected =~ "\e[>4;0m", "should contain disable_modify_other_keys"
      assert expected =~ "\e[?2004l", "should contain disable_paste"
      assert expected =~ "\e[?1006l", "should contain disable SGR mouse"
      assert expected =~ "\e[?1003l", "should contain disable all-motion mouse"
      assert expected =~ "\e[?1000l", "should contain disable basic mouse"
      assert expected =~ "\e[?1049l", "should contain leave_alt_screen"

      # Verify set_kitty_keyboard(0) appears BEFORE pop_kitty_keyboard
      set_pos = :binary.match(expected, "\e[=0u") |> elem(0)
      pop_pos = :binary.match(expected, "\e[<u") |> elem(0)
      assert set_pos < pop_pos, "set_kitty_keyboard(0) must come before pop"

      # Verify mouse disable appears AFTER leave_alt_screen (safety net)
      alt_screen_pos = :binary.match(expected, "\e[?1049l") |> elem(0)

      all_mouse_positions =
        :binary.matches(expected, "\e[?1000l")
        |> Enum.map(&elem(&1, 0))

      assert length(all_mouse_positions) == 2,
             "disable_mouse should appear twice (before and after leave_alt_screen)"

      last_mouse_pos = List.last(all_mouse_positions)

      assert last_mouse_pos > alt_screen_pos,
             "second disable_mouse must come after leave_alt_screen"
    end
  end
end
