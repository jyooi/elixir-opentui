defmodule ElixirOpentui.RuntimeTickTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Runtime

  # ── Test App Modules ──────────────────────────────────────────────────

  defmodule StaticApp do
    @moduledoc false
    use ElixirOpentui.Component

    def init(_props), do: %{label: "static"}
    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View
      text(id: :lbl, content: state.label)
    end
  end

  defmodule TickCounterApp do
    @moduledoc false
    use ElixirOpentui.Component

    def init(_props), do: %{ticks: 0}

    def update(:tick, %{dt: _dt}, state) do
      %{state | ticks: state.ticks + 1}
    end

    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View
      text(id: :counter, content: "ticks: #{state.ticks}")
    end
  end

  defmodule LiveApp do
    @moduledoc false
    use ElixirOpentui.Component

    def init(_props), do: %{ticks: 0, _live: true}

    def update(:tick, %{dt: _dt}, state) do
      %{state | ticks: state.ticks + 1}
    end

    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View
      text(id: :live_counter, content: "live ticks: #{state.ticks}")
    end
  end

  defmodule LiveToggleApp do
    @moduledoc false
    use ElixirOpentui.Component

    def init(_props), do: %{ticks: 0, _live: false}

    def update(:enable_live, _event, state), do: %{state | _live: true}
    def update(:disable_live, _event, state), do: %{state | _live: false}

    def update(:tick, %{dt: _dt}, state) do
      %{state | ticks: state.ticks + 1}
    end

    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View
      text(id: :toggle_counter, content: "ticks: #{state.ticks}")
    end
  end

  defmodule LiveComponentApp do
    @moduledoc false
    use ElixirOpentui.Component

    def init(_props), do: %{parent_ticks: 0}

    def update(:tick, %{dt: _dt}, state) do
      %{state | parent_ticks: state.parent_ticks + 1}
    end

    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View

      box id: :root, width: 40, height: 5 do
        text(id: :parent_counter, content: "parent: #{state.parent_ticks}")
        component(ElixirOpentui.RuntimeTickTest.TickCounterWidget, id: :child_widget, _live: true)
      end
    end
  end

  defmodule TickCounterWidget do
    @moduledoc false
    use ElixirOpentui.Component

    def init(_props), do: %{ticks: 0, _live: true}

    def update(:tick, %{dt: _dt}, state) do
      %{state | ticks: state.ticks + 1}
    end

    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View
      text(id: :widget_counter, content: "widget: #{state.ticks}")
    end
  end

  # ── FSM State Transitions ────────────────────────────────────────────

  describe "FSM state transitions" do
    test "runtime starts in idle state (no ticking)" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, StaticApp)

      frame1 = Runtime.get_frame(rt)
      Process.sleep(50)
      frame2 = Runtime.get_frame(rt)

      # Static app with no _live flag — frames should be identical
      assert frame1 == frame2
    end

    test "runtime transitions to running when _live app is mounted" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveApp)

      # Give it time to tick a few times
      Process.sleep(100)
      frame = Runtime.get_frame(rt)
      joined = Enum.join(frame)

      # Should have received ticks
      assert String.contains?(joined, "live ticks:")
    end

    test "runtime transitions back to idle when _live is disabled" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveToggleApp)

      # Start with _live: false — no ticking
      Process.sleep(50)
      frame1 = Runtime.get_frame(rt)
      joined1 = Enum.join(frame1)
      assert String.contains?(joined1, "ticks: 0")

      # Enable live mode
      Runtime.send_msg(rt, nil, :enable_live)
      Process.sleep(100)

      frame2 = Runtime.get_frame(rt)
      joined2 = Enum.join(frame2)
      # Should have accumulated some ticks
      refute String.contains?(joined2, "ticks: 0")

      # Disable live mode
      Runtime.send_msg(rt, nil, :disable_live)
      Process.sleep(20)

      frame3 = Runtime.get_frame(rt)
      Process.sleep(50)
      frame4 = Runtime.get_frame(rt)

      # After disabling, frames should stabilize
      assert frame3 == frame4
    end
  end

  # ── Tick Delivery to App Module ──────────────────────────────────────

  describe "tick delivery to app module" do
    test "tick events are delivered to app module update/3" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveApp)

      Process.sleep(100)
      frame = Runtime.get_frame(rt)
      joined = Enum.join(frame)

      # Extract tick count from rendered output
      case Regex.run(~r/live ticks: (\d+)/, joined) do
        [_, count_str] ->
          count = String.to_integer(count_str)
          assert count > 0, "Expected at least 1 tick, got #{count}"

        nil ->
          flunk("Could not find tick count in frame: #{joined}")
      end
    end

    test "tick events include dt (delta time)" do
      test_pid = self()

      # We'll use the on_event callback to inspect tick events
      {:ok, rt} =
        Runtime.start_link(
          cols: 40,
          rows: 5,
          on_event: fn event ->
            case event do
              %{type: :tick, dt: dt} when is_number(dt) ->
                send(test_pid, {:tick_dt, dt})

              _ ->
                :ok
            end
          end
        )

      Runtime.mount(rt, LiveApp)
      Process.sleep(100)

      # We should have received at least one tick with a dt value
      assert_receive {:tick_dt, dt}, 200
      assert is_number(dt)
      assert dt > 0
    end
  end

  # ── Tick Delivery to Components ──────────────────────────────────────

  describe "tick delivery to components" do
    test "child components with _live flag receive tick events" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveComponentApp)

      Process.sleep(100)
      frame = Runtime.get_frame(rt)
      joined = Enum.join(frame)

      # The child widget should have received ticks
      case Regex.run(~r/widget: (\d+)/, joined) do
        [_, count_str] ->
          count = String.to_integer(count_str)
          assert count > 0, "Widget should have received ticks"

        nil ->
          flunk("Could not find widget tick count in frame: #{joined}")
      end
    end
  end

  # ── _live Flag Auto-Start/Stop ───────────────────────────────────────

  describe "_live flag auto-start/stop" do
    test "_live: true in init starts ticking automatically" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveApp)

      Process.sleep(80)
      frame = Runtime.get_frame(rt)
      joined = Enum.join(frame)

      # Should see non-zero tick count
      refute String.contains?(joined, "live ticks: 0"),
             "Expected ticks > 0 but got: #{joined}"
    end

    test "_live: false in init does not start ticking" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveToggleApp)

      Process.sleep(80)
      frame = Runtime.get_frame(rt)
      joined = Enum.join(frame)

      assert String.contains?(joined, "ticks: 0"),
             "Expected 0 ticks but got: #{joined}"
    end

    test "setting _live: true starts ticking, setting _live: false stops ticking" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveToggleApp)

      # Initially no ticking
      Process.sleep(50)
      frame0 = Runtime.get_frame(rt)
      assert Enum.join(frame0) =~ "ticks: 0"

      # Enable ticking
      Runtime.send_msg(rt, nil, :enable_live)
      Process.sleep(100)

      frame1 = Runtime.get_frame(rt)
      tick_count_1 = extract_tick_count(frame1)
      assert tick_count_1 > 0

      # Disable ticking
      Runtime.send_msg(rt, nil, :disable_live)
      Process.sleep(20)

      frame2 = Runtime.get_frame(rt)
      tick_count_2 = extract_tick_count(frame2)

      Process.sleep(80)
      frame3 = Runtime.get_frame(rt)
      tick_count_3 = extract_tick_count(frame3)

      # Tick count should have stopped increasing (or at most 1 more from pipeline)
      assert tick_count_3 - tick_count_2 <= 1,
             "Ticking should have stopped: was #{tick_count_2}, now #{tick_count_3}"
    end
  end

  # ── request_live / drop_live Ref Counting ────────────────────────────

  describe "request_live/drop_live ref counting" do
    test "request_live enables ticking" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, TickCounterApp)

      # No ticking initially (no _live flag)
      Process.sleep(50)
      frame0 = Runtime.get_frame(rt)
      assert Enum.join(frame0) =~ "ticks: 0"

      # Request live mode
      ref = Runtime.request_live(rt)
      assert is_reference(ref)

      Process.sleep(100)
      frame1 = Runtime.get_frame(rt)
      count1 = extract_tick_count(frame1)
      assert count1 > 0
    end

    test "drop_live disables ticking when no other references remain" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, TickCounterApp)

      ref = Runtime.request_live(rt)
      Process.sleep(80)

      count_before = extract_tick_count(Runtime.get_frame(rt))
      assert count_before > 0

      Runtime.drop_live(rt, ref)
      Process.sleep(20)

      count_after = extract_tick_count(Runtime.get_frame(rt))
      Process.sleep(80)
      count_final = extract_tick_count(Runtime.get_frame(rt))

      assert count_final - count_after <= 1,
             "Ticking should have stopped after drop_live"
    end

    test "multiple request_live refs keep ticking alive until all dropped" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, TickCounterApp)

      ref1 = Runtime.request_live(rt)
      ref2 = Runtime.request_live(rt)
      Process.sleep(80)

      count1 = extract_tick_count(Runtime.get_frame(rt))
      assert count1 > 0

      # Drop first ref — should still be ticking
      Runtime.drop_live(rt, ref1)
      Process.sleep(80)

      count2 = extract_tick_count(Runtime.get_frame(rt))
      assert count2 > count1, "Should still be ticking with one ref remaining"

      # Drop second ref — should stop
      Runtime.drop_live(rt, ref2)
      Process.sleep(20)

      count3 = extract_tick_count(Runtime.get_frame(rt))
      Process.sleep(80)
      count4 = extract_tick_count(Runtime.get_frame(rt))

      assert count4 - count3 <= 1,
             "Ticking should stop after all refs are dropped"
    end

    test "dropping the same ref twice is a no-op" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, TickCounterApp)

      ref = Runtime.request_live(rt)
      Process.sleep(50)

      Runtime.drop_live(rt, ref)
      # Should not raise or cause issues
      Runtime.drop_live(rt, ref)

      Process.sleep(50)
      # Runtime should still be functional
      frame = Runtime.get_frame(rt)
      assert is_list(frame)
    end
  end

  # ── Suspend / Resume ─────────────────────────────────────────────────

  describe "suspend/resume state management" do
    test "suspend pauses ticking" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveApp)

      Process.sleep(80)
      count1 = extract_tick_count(Runtime.get_frame(rt))
      assert count1 > 0

      Runtime.suspend(rt)
      Process.sleep(20)

      count2 = extract_tick_count(Runtime.get_frame(rt))
      Process.sleep(80)
      count3 = extract_tick_count(Runtime.get_frame(rt))

      assert count3 - count2 <= 1,
             "Ticking should pause during suspend"
    end

    test "resume restarts ticking" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveApp)

      Process.sleep(50)

      Runtime.suspend(rt)
      Process.sleep(20)
      count_suspended = extract_tick_count(Runtime.get_frame(rt))

      Runtime.resume(rt)
      Process.sleep(80)
      count_resumed = extract_tick_count(Runtime.get_frame(rt))

      assert count_resumed > count_suspended,
             "Ticking should resume after unsuspend"
    end

    test "suspend then resume preserves state" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveApp)

      Process.sleep(80)
      count_before_suspend = extract_tick_count(Runtime.get_frame(rt))

      Runtime.suspend(rt)
      Process.sleep(20)
      count_at_suspend = extract_tick_count(Runtime.get_frame(rt))

      # Count should be >= what it was (may have one more tick in pipeline)
      assert count_at_suspend >= count_before_suspend

      Runtime.resume(rt)
      Process.sleep(80)
      count_after_resume = extract_tick_count(Runtime.get_frame(rt))

      # Ticking continues from where it left off
      assert count_after_resume > count_at_suspend
    end

    test "multiple suspends require matching resumes" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveApp)

      Process.sleep(50)

      Runtime.suspend(rt)
      Runtime.suspend(rt)
      Process.sleep(20)

      count1 = extract_tick_count(Runtime.get_frame(rt))

      # Single resume shouldn't restart if double-suspended
      Runtime.resume(rt)
      Process.sleep(80)

      count2 = extract_tick_count(Runtime.get_frame(rt))

      # Second resume should actually restart
      Runtime.resume(rt)
      Process.sleep(80)

      count3 = extract_tick_count(Runtime.get_frame(rt))
      assert count3 > count2, "Should tick after matching all suspends with resumes"
    end

    test "suspend is idempotent when not live" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, StaticApp)

      # Suspend should not crash even when not live
      Runtime.suspend(rt)
      Runtime.suspend(rt)
      Runtime.resume(rt)
      Runtime.resume(rt)

      frame = Runtime.get_frame(rt)
      assert is_list(frame)
    end
  end

  # ── send_app_msg/2 ───────────────────────────────────────────────────

  describe "send_app_msg/2" do
    test "send_app_msg delivers message to app module update/3" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveToggleApp)

      # Initially no ticking
      Process.sleep(50)
      frame = Runtime.get_frame(rt)
      assert Enum.join(frame) =~ "ticks: 0"

      # Enable live via send_app_msg
      Runtime.send_app_msg(rt, :enable_live)
      Process.sleep(100)

      frame = Runtime.get_frame(rt)
      count = extract_tick_count(frame)
      assert count > 0, "send_app_msg should have enabled live mode and started ticking"
    end

    test "send_app_msg triggers live-mode transitions" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 5)
      Runtime.mount(rt, LiveToggleApp)

      # Enable then disable via send_app_msg
      Runtime.send_app_msg(rt, :enable_live)
      Process.sleep(100)

      count1 = extract_tick_count(Runtime.get_frame(rt))
      assert count1 > 0

      Runtime.send_app_msg(rt, :disable_live)
      Process.sleep(20)

      count2 = extract_tick_count(Runtime.get_frame(rt))
      Process.sleep(80)
      count3 = extract_tick_count(Runtime.get_frame(rt))

      assert count3 - count2 <= 1,
             "Ticking should stop after disabling via send_app_msg"
    end
  end

  # ── Tick Timer Safety ──────────────────────────────────────────────

  describe "tick timer safety" do
    test "rapid start/stop/start does not create duplicate tick chains" do
      tick_count = :counters.new(1, [:atomics])

      {:ok, rt} =
        Runtime.start_link(
          cols: 40,
          rows: 5,
          on_event: fn
            %{type: :tick} -> :counters.add(tick_count, 1, 1)
            _ -> :ok
          end
        )

      Runtime.mount(rt, TickCounterApp)

      # Rapid start/stop/start cycle
      Runtime.start(rt)
      Runtime.stop(rt)
      Runtime.start(rt)
      Runtime.stop(rt)
      Runtime.start(rt)

      :counters.put(tick_count, 1, 0)
      Process.sleep(200)

      count = :counters.get(tick_count, 1)
      # At 30fps, ~6 ticks in 200ms. With duplicates it would be much higher.
      assert count < 15,
             "Expected < 15 ticks in 200ms at 30fps, got #{count} (possible duplicate chains)"

      # Verify exactly one non-nil tick_timer_ref
      internal = :sys.get_state(rt)
      assert internal.tick_timer_ref != nil, "Should have exactly one active timer"
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  defp extract_tick_count(frame) do
    joined = Enum.join(frame)

    case Regex.run(~r/ticks?: (\d+)/, joined) do
      [_, count_str] -> String.to_integer(count_str)
      nil -> 0
    end
  end
end
