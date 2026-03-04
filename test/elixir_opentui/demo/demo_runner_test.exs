defmodule ElixirOpentui.Demo.DemoRunnerTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.ANSI
  alias ElixirOpentui.Demo.DemoRunner

  # --- Source inspection tests ---
  #
  # These tests verify internal implementation details that cannot be tested
  # behaviorally without a real TTY (terminal mode switching, event loop
  # timing logic). They're intentionally kept as source inspection with
  # this justification: the cooked mode transition and tick scheduling are
  # side-effectful operations deeply embedded in the event loop that only
  # execute in a live terminal session.

  describe "cooked mode cleanup" do
    # Source inspection: restore_terminal requires a real tty fd; we can't
    # call :shell.start_interactive from ExUnit without disrupting the test
    # runner's own terminal state.
    test "DemoRunner after block includes :cooked transition" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ ":shell.start_interactive({:noshell, :cooked})"
    end
  end

  describe "configurable tick interval" do
    # Source inspection: the tick interval is used inside the receive loop
    # which requires a spawned input reader and real tty. Testing the actual
    # timing would be fragile and non-deterministic.
    test "source uses _tick_interval from state" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ "_tick_interval"
      assert source =~ "Map.get(state, :_tick_interval, 33)"
    end

    test "source uses real wall-clock dt" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ "System.monotonic_time(:millisecond)"
      assert source =~ "_last_tick"
      refute source =~ "dt = wait_ms"
    end

    test "initializes _last_tick before loop" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ "Map.put_new(state, :_last_tick, System.monotonic_time(:millisecond))"
    end

    test "compensates sleep for render time" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ "tick_interval - time_spent"
      assert source =~ "max(1,"
    end
  end

  describe "tick starvation fix" do
    # Source inspection: starvation logic is inside the recursive event
    # handler which requires the full event loop to exercise.
    test "empty-events base case does NOT reset _last_tick" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")

      refute source =~ ~r/handle_events.*\[\].*do\s*\n\s*state = Map\.put\(state, :_last_tick/s,
             "handle_events([], ...) must not reset _last_tick unconditionally"
    end

    test "empty-events base case checks tick due and fires inline" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")
      assert source =~ "time_since_tick >= tick_interval"
      assert source =~ "tick_and_render(demo_mod, dt, state, renderer, ctx)"
    end

    test "live demos skip per-event rendering" do
      source = File.read!("lib/elixir_opentui/demo/demo_runner.ex")

      assert source =~ ~r/if Map\.get\(new_state, :_live, false\) do\s*\n\s*\{renderer, ctx\}/s,
             "live demos should skip rendering in handle_events event clause"
    end
  end

  # --- Behavioral tests ---

  describe "restore_terminal_sequences/0" do
    test "returns all critical cleanup escape codes" do
      sequences = DemoRunner.restore_terminal_sequences()
      binary = IO.iodata_to_binary(sequences)

      assert binary =~ "\e[=0u", "should contain set_kitty_keyboard(0)"
      assert binary =~ "\e[<u", "should contain pop_kitty_keyboard"
      assert binary =~ "\e[>4;0m", "should contain disable_modify_other_keys"
      assert binary =~ "\e[?2004l", "should contain disable_paste"
      assert binary =~ "\e[?1006l", "should contain disable SGR mouse"
      assert binary =~ "\e[?1003l", "should contain disable all-motion mouse"
      assert binary =~ "\e[?1000l", "should contain disable basic mouse"
      assert binary =~ "\e[?1049l", "should contain leave_alt_screen"
    end

    test "set_kitty_keyboard(0) appears before pop_kitty_keyboard" do
      binary = IO.iodata_to_binary(DemoRunner.restore_terminal_sequences())

      set_pos = :binary.match(binary, "\e[=0u") |> elem(0)
      pop_pos = :binary.match(binary, "\e[<u") |> elem(0)
      assert set_pos < pop_pos, "set_kitty_keyboard(0) must come before pop"
    end

    test "disable_mouse appears twice (before and after leave_alt_screen)" do
      binary = IO.iodata_to_binary(DemoRunner.restore_terminal_sequences())

      alt_screen_pos = :binary.match(binary, "\e[?1049l") |> elem(0)

      all_mouse_positions =
        :binary.matches(binary, "\e[?1000l")
        |> Enum.map(&elem(&1, 0))

      assert length(all_mouse_positions) == 2,
             "disable_mouse should appear twice (before and after leave_alt_screen)"

      last_mouse_pos = List.last(all_mouse_positions)

      assert last_mouse_pos > alt_screen_pos,
             "second disable_mouse must come after leave_alt_screen"
    end

    test "produces the same sequence as directly calling ANSI functions" do
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

      actual = IO.iodata_to_binary(DemoRunner.restore_terminal_sequences())

      assert actual == expected
    end
  end

  describe "demo module protocol" do
    defmodule TestDemo do
      @moduledoc false

      def init(cols, rows) do
        %{cols: cols, rows: rows, counter: 0}
      end

      def handle_event(%{key: "q"}, _state), do: :quit

      def handle_event(_event, state) do
        {:cont, %{state | counter: state.counter + 1}}
      end

      def render(state) do
        import ElixirOpentui.View
        text(content: "Count: #{state.counter}")
      end

      def focused_id(_state), do: nil
    end

    test "init/2 returns a map state" do
      state = TestDemo.init(80, 24)
      assert is_map(state)
      assert state.cols == 80
      assert state.rows == 24
    end

    test "handle_event returns {:cont, state} for normal events" do
      state = TestDemo.init(80, 24)
      result = TestDemo.handle_event(%{key: :up, type: :key, meta: false}, state)
      assert {:cont, new_state} = result
      assert new_state.counter == 1
    end

    test "handle_event returns :quit for quit events" do
      state = TestDemo.init(80, 24)
      assert :quit = TestDemo.handle_event(%{key: "q"}, state)
    end

    test "render/1 returns an Element" do
      state = TestDemo.init(80, 24)
      element = TestDemo.render(state)
      assert %ElixirOpentui.Element{} = element
    end

    test "focused_id/1 returns nil or an atom" do
      state = TestDemo.init(80, 24)
      result = TestDemo.focused_id(state)
      assert is_nil(result) or is_atom(result)
    end
  end
end
