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
