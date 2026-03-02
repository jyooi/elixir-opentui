defmodule ElixirOpentui.Animation.TimelineTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Animation.Timeline

  # Helper to create a fresh timeline with defaults.
  # Our Timeline is a functional struct — every operation returns a new timeline.
  defp new_timeline(opts \\ []) do
    Timeline.new(opts)
  end

  # Helper to advance and read a value in one step.
  defp advance_and_read(tl, dt, key) do
    tl = Timeline.advance(tl, dt)
    {Timeline.value(tl, key), tl}
  end

  # ── Basic Animation ───────────────────────────────────────────────────

  describe "Basic Animation" do
    test "should animate a single property" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 0)
      assert Timeline.value(tl, :x) == 0

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
    end

    test "should animate multiple properties" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.add(:y, from: 0, to: 200, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50
      assert Timeline.value(tl, :y) == 100
    end

    test "should handle easing functions" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, ease: :linear)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50
    end
  end

  # ── Timeline Control ──────────────────────────────────────────────────

  describe "Timeline Control" do
    setup do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)

      %{tl: tl}
    end

    test "should start paused when autoplay is false", %{tl: tl} do
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 0
    end

    test "should animate when played", %{tl: tl} do
      tl = tl |> Timeline.play() |> Timeline.advance(500)
      assert Timeline.value(tl, :x) == 50
    end

    test "should pause animation", %{tl: tl} do
      tl = tl |> Timeline.play() |> Timeline.advance(250)
      assert Timeline.value(tl, :x) == 25

      tl = tl |> Timeline.pause() |> Timeline.advance(250)
      assert Timeline.value(tl, :x) == 25
    end

    test "should restart animation", %{tl: tl} do
      tl = tl |> Timeline.play() |> Timeline.advance(500)
      assert Timeline.value(tl, :x) == 50

      tl = tl |> Timeline.restart() |> Timeline.advance(250)
      assert Timeline.value(tl, :x) == 25
    end

    test "should play again when calling play() on a finished non-looping timeline", %{tl: tl} do
      tl = tl |> Timeline.play() |> Timeline.advance(1000)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.playing?(tl) == false

      tl = Timeline.play(tl)
      assert Timeline.playing?(tl) == true

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.playing?(tl) == false
    end

    test "should call on_pause callback when timeline is paused" do
      ref = make_ref()
      test_pid = self()

      tl =
        new_timeline(
          duration: 1000,
          on_pause: fn -> send(test_pid, {:paused, ref}) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()
        |> Timeline.advance(500)

      assert Timeline.value(tl, :x) == 50

      tl = Timeline.pause(tl)
      assert_received {:paused, ^ref}
      assert Timeline.playing?(tl) == false

      tl = Timeline.pause(tl)
      assert_received {:paused, ^ref}

      tl = tl |> Timeline.play() |> Timeline.pause()
      assert_received {:paused, ^ref}
    end

    test "should not call on_pause callback when timeline completes naturally" do
      test_pid = self()
      pause_ref = make_ref()
      complete_ref = make_ref()

      tl =
        new_timeline(
          duration: 1000,
          on_pause: fn -> send(test_pid, {:paused, pause_ref}) end,
          on_complete: fn -> send(test_pid, {:completed, complete_ref}) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 500)
        |> Timeline.play()
        |> Timeline.advance(1000)

      assert Timeline.playing?(tl) == false
      refute_received {:paused, ^pause_ref}
      assert_received {:completed, ^complete_ref}
    end
  end

  # ── Looping ───────────────────────────────────────────────────────────

  describe "Looping" do
    test "should loop timeline when loop is true" do
      tl =
        new_timeline(duration: 1000, loop: true)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50
    end

    test "should not loop when loop is false" do
      tl =
        new_timeline(duration: 1000, loop: false)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.playing?(tl) == false

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
    end
  end

  # ── Individual Animation Loops ────────────────────────────────────────

  describe "Individual Animation Loops" do
    test "should loop individual animation specified number of times" do
      test_pid = self()

      tl =
        new_timeline(duration: 5000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          loop: 3,
          on_complete: fn -> send(test_pid, :anim_complete) end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100
      refute_received :anim_complete

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100
      refute_received :anim_complete

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100
      assert_received :anim_complete

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100
      # No second complete
      refute_received :anim_complete
    end

    test "should handle loop delay" do
      tl =
        new_timeline(duration: 5000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, loop: 2, loop_delay: 500)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100

      # Mid loop-delay
      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 100

      # End of delay + into second run
      tl = tl |> Timeline.advance(250) |> Timeline.advance(500)
      assert Timeline.value(tl, :x) == 50
    end
  end

  # ── Alternating Animations ───────────────────────────────────────────

  describe "Alternating Animations" do
    test "should alternate direction with each loop" do
      tl =
        new_timeline(duration: 5000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, loop: 3, alternate: true)
        |> Timeline.play()

      # Forward first half
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50

      # Forward complete
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100

      # Reverse halfway
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50

      # Reverse complete
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 0

      # Forward again
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
    end

    test "should handle alternating with loop delay" do
      tl =
        new_timeline(duration: 5000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          loop: 2,
          alternate: true,
          loop_delay: 500
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100

      # In loop delay
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100

      # Reverse direction
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 0
    end

    test "should handle alternating animations with looping parent timeline" do
      tl =
        new_timeline(duration: 3000, loop: true)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          loop: 2,
          alternate: true,
          start_time: 500
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      first_loop_start_value = Timeline.value(tl, :x)

      tl =
        tl
        |> Timeline.advance(500)
        |> Timeline.advance(500)
        |> Timeline.advance(500)
        |> Timeline.advance(500)
        |> Timeline.advance(500)

      # After 3000ms total, timeline loops — currentTime resets
      assert Timeline.current_time(tl) == 0

      tl = Timeline.advance(tl, 500)
      second_loop_start_value = Timeline.value(tl, :x)

      assert second_loop_start_value == first_loop_start_value
    end
  end

  # ── Timeline Sync ────────────────────────────────────────────────────

  describe "Timeline Sync" do
    test "should sync sub-timelines to main timeline" do
      sub_tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:value, from: 0, to: 100, duration: 1000)

      main_tl =
        new_timeline(duration: 3000)
        |> Timeline.sync(sub_tl, 1000)
        |> Timeline.play()

      main_tl = Timeline.advance(main_tl, 500)
      assert Timeline.value(main_tl, :value) == 0

      main_tl = Timeline.advance(main_tl, 500)
      assert Timeline.value(main_tl, :value) == 0

      main_tl = Timeline.advance(main_tl, 500)
      assert Timeline.value(main_tl, :value) == 50

      main_tl = Timeline.advance(main_tl, 500)
      assert Timeline.value(main_tl, :value) == 100

      main_tl = Timeline.advance(main_tl, 500)
      assert Timeline.value(main_tl, :value) == 100
    end

    test "should restart completed sub-timelines when main timeline loops" do
      test_pid = self()

      sub_tl =
        new_timeline(duration: 300)
        |> Timeline.add(:value,
          from: 0,
          to: 100,
          duration: 300,
          on_complete: fn -> send(test_pid, :sub_complete) end
        )

      main_tl =
        new_timeline(duration: 1000, loop: true)
        |> Timeline.sync(sub_tl, 200)
        |> Timeline.play()

      main_tl = Timeline.advance(main_tl, 200)
      assert Timeline.value(main_tl, :value) == 0

      main_tl = Timeline.advance(main_tl, 150)
      assert Timeline.value(main_tl, :value) == 50

      main_tl = Timeline.advance(main_tl, 150)
      assert Timeline.value(main_tl, :value) == 100
      assert_received :sub_complete

      # Continue to loop boundary
      main_tl = Timeline.advance(main_tl, 500)
      assert Timeline.current_time(main_tl) == 0

      # Second loop: sub starts again at offset 200
      main_tl = Timeline.advance(main_tl, 200)

      main_tl = Timeline.advance(main_tl, 150)
      assert Timeline.value(main_tl, :value) == 50

      main_tl = Timeline.advance(main_tl, 150)
      assert Timeline.value(main_tl, :value) == 100
      assert_received :sub_complete
    end

    test "should pause sub-timelines when main timeline is paused" do
      sub_tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:value, from: 0, to: 50, duration: 800)

      main_tl =
        new_timeline(duration: 3000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 2000)
        |> Timeline.sync(sub_tl, 500)
        |> Timeline.play()

      main_tl = Timeline.advance(main_tl, 250)
      assert_in_delta Timeline.value(main_tl, :x), 12.5, 0.1
      assert Timeline.value(main_tl, :value) == 0

      main_tl = Timeline.advance(main_tl, 500)
      assert_in_delta Timeline.value(main_tl, :x), 37.5, 0.1
      assert_in_delta Timeline.value(main_tl, :value), 15.625, 0.1

      # Pause main
      main_tl = Timeline.pause(main_tl)
      assert Timeline.playing?(main_tl) == false

      # Advance while paused — nothing should change
      main_tl = Timeline.advance(main_tl, 400)
      assert_in_delta Timeline.value(main_tl, :x), 37.5, 0.1
      assert_in_delta Timeline.value(main_tl, :value), 15.625, 0.1

      # Resume
      main_tl = Timeline.play(main_tl)
      assert Timeline.playing?(main_tl) == true

      main_tl = Timeline.advance(main_tl, 200)
      assert_in_delta Timeline.value(main_tl, :x), 47.5, 0.1
      assert_in_delta Timeline.value(main_tl, :value), 28.125, 0.1
    end
  end

  # ── Callbacks ─────────────────────────────────────────────────────────

  describe "Callbacks" do
    test "should execute call callbacks at specified times" do
      test_pid = self()

      tl =
        new_timeline(duration: 2000)
        |> Timeline.call(fn -> send(test_pid, {:call, 0}) end, 0)
        |> Timeline.call(fn -> send(test_pid, {:call, 1000}) end, 1000)
        |> Timeline.call(fn -> send(test_pid, {:call, 1500}) end, 1500)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      assert_received {:call, 0}
      refute_received {:call, 1000}

      tl = Timeline.advance(tl, 500)
      assert_received {:call, 1000}
      refute_received {:call, 1500}

      _tl = Timeline.advance(tl, 500)
      assert_received {:call, 1500}
    end

    test "should trigger onStart callback correctly" do
      test_pid = self()

      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 500,
          start_time: 200,
          on_start: fn -> send(test_pid, :started) end
        )
        |> Timeline.play()

      refute_received :started

      tl = Timeline.advance(tl, 100)
      refute_received :started
      assert Timeline.value(tl, :x) == 0

      tl = Timeline.advance(tl, 150)
      assert_received :started
      assert_in_delta Timeline.value(tl, :x), 10, 0.1
    end

    test "should trigger onLoop callback correctly for individual animation loops" do
      test_pid = self()

      tl =
        new_timeline(duration: 5000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 500,
          loop: 3,
          loop_delay: 100,
          on_loop: fn -> send(test_pid, :looped) end,
          on_complete: fn -> send(test_pid, :completed) end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      refute_received :looped

      tl = Timeline.advance(tl, 100)
      assert_received :looped

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      refute_received :looped

      tl = Timeline.advance(tl, 100)
      assert_received :looped

      _tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      assert_received :completed
    end
  end

  # ── Complex Looping Scenarios ─────────────────────────────────────────

  describe "Complex Looping Scenarios" do
    test "should correctly reset and re-run finite-looped animation when parent timeline loops" do
      test_pid = self()

      tl =
        new_timeline(duration: 2000, loop: true)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 500,
          loop: 2,
          loop_delay: 100,
          start_time: 500,
          on_start: fn -> send(test_pid, :anim_start) end,
          on_loop: fn -> send(test_pid, :anim_loop) end,
          on_complete: fn -> send(test_pid, :anim_complete) end
        )
        |> Timeline.play()

      # t=500: animation starts
      tl = Timeline.advance(tl, 500)
      assert_received :anim_start

      # t=1000: first run complete
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      refute_received :anim_loop

      # t=1100: loop delay ends, loop callback fires
      tl = Timeline.advance(tl, 100)
      assert_received :anim_loop

      # t=1600: second run complete
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      assert_received :anim_complete

      # Continue to timeline loop boundary at t=2000
      tl = Timeline.advance(tl, 100)
      # skip remaining
      tl = Timeline.advance(tl, 300)
      assert Timeline.current_time(tl) == 0

      # Second timeline loop: animation re-starts at offset 500
      tl = Timeline.advance(tl, 500)
      assert_received :anim_start
      assert Timeline.value(tl, :x) == 0

      # Second run of second loop
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      refute_received :anim_loop

      tl = Timeline.advance(tl, 100)
      assert_received :anim_loop

      _tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      assert_received :anim_complete
    end
  end

  # ── Timing Precision ──────────────────────────────────────────────────

  describe "Timing Precision - Animation Start Time Overshoot" do
    test "should account for overshoot when animation starts late" do
      tl =
        new_timeline(duration: 2000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, ease: :linear, start_time: 50)
        |> Timeline.play()

      tl = Timeline.advance(tl, 66)
      assert_in_delta Timeline.value(tl, :x), 1.6, 0.1
    end

    test "should handle multiple animations with different start time overshoots" do
      tl =
        new_timeline(duration: 3000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, ease: :linear, start_time: 30)
        |> Timeline.add(:y, from: 0, to: 200, duration: 1000, ease: :linear, start_time: 80)
        |> Timeline.play()

      tl = Timeline.advance(tl, 100)

      assert_in_delta Timeline.value(tl, :x), 7, 0.1
      assert_in_delta Timeline.value(tl, :y), 4, 0.1
    end

    test "should handle zero duration animations with overshoot" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 0, start_time: 50)
        |> Timeline.play()

      tl = Timeline.advance(tl, 66)
      assert Timeline.value(tl, :x) == 100
    end
  end

  describe "Timing Precision - Loop Delay Precision" do
    test "should account for overshoot in loop delays" do
      tl =
        new_timeline(duration: 5000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          loop: 3,
          loop_delay: 500,
          ease: :linear
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100

      # Overshoot: 516ms past end of first run, 500ms delay => 16ms into second run
      tl = Timeline.advance(tl, 516)
      assert_in_delta Timeline.value(tl, :x), 1.6, 0.1
    end

    test "should handle multiple loop delay overshoots" do
      tl =
        new_timeline(duration: 10_000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          loop: 4,
          loop_delay: 300,
          ease: :linear
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100

      # 333ms past end, delay is 300ms, so 33ms into next run
      tl = Timeline.advance(tl, 333)
      assert_in_delta Timeline.value(tl, :x), 3.3, 0.1

      tl = Timeline.advance(tl, 967)
      assert Timeline.value(tl, :x) == 100

      tl = Timeline.advance(tl, 350)
      assert_in_delta Timeline.value(tl, :x), 5, 0.1
    end

    test "should handle alternating animations with loop delay overshoot" do
      tl =
        new_timeline(duration: 8000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          loop: 3,
          alternate: true,
          loop_delay: 400,
          ease: :linear
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100

      # 450ms past end, delay 400ms, 50ms into reverse
      tl = Timeline.advance(tl, 450)
      assert Timeline.value(tl, :x) == 95

      tl = Timeline.advance(tl, 950)
      assert Timeline.value(tl, :x) == 0

      # 425ms past end, delay 400ms, 25ms into forward
      tl = Timeline.advance(tl, 425)
      assert_in_delta Timeline.value(tl, :x), 2.5, 0.1
    end
  end

  describe "Timing Precision - Synced Timeline Precision" do
    test "should account for overshoot when starting synced timelines" do
      sub_tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:value, from: 0, to: 100, duration: 1000, ease: :linear)

      main_tl =
        new_timeline(duration: 3000)
        |> Timeline.sync(sub_tl, 500)
        |> Timeline.play()

      # 533ms total, sub starts at 500ms => 33ms into sub
      main_tl = Timeline.advance(main_tl, 533)
      assert_in_delta Timeline.value(main_tl, :value), 3.3, 0.1
    end

    test "should handle multiple synced timelines with different overshoot amounts" do
      sub_tl1 =
        new_timeline(duration: 1000)
        |> Timeline.add(:value1, from: 0, to: 100, duration: 1000, ease: :linear)

      sub_tl2 =
        new_timeline(duration: 1500)
        |> Timeline.add(:value2, from: 0, to: 200, duration: 1500, ease: :linear)

      main_tl =
        new_timeline(duration: 5000)
        |> Timeline.sync(sub_tl1, 300)
        |> Timeline.sync(sub_tl2, 800)
        |> Timeline.play()

      # 850ms total: sub1 started at 300 => 550ms in, sub2 started at 800 => 50ms in
      main_tl = Timeline.advance(main_tl, 850)
      assert_in_delta Timeline.value(main_tl, :value1), 55, 0.1
      assert_in_delta Timeline.value(main_tl, :value2), 6.67, 0.2
    end
  end

  describe "Timing Precision - Complex Precision Scenarios" do
    test "should handle alternating animation with main timeline loop and overshoot" do
      tl =
        new_timeline(duration: 3000, loop: true)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 800,
          loop: 2,
          alternate: true,
          loop_delay: 200,
          ease: :linear,
          start_time: 500
        )
        |> Timeline.play()

      # 3100ms: timeline loops at 3000, so we're at t=100 in second loop
      tl = Timeline.advance(tl, 3100)
      assert Timeline.value(tl, :x) == 0

      # t=550 in second loop: 50ms past animation start
      tl = Timeline.advance(tl, 450)
      assert_in_delta Timeline.value(tl, :x), 6.25, 0.1

      tl = Timeline.advance(tl, 750 + 250)
      assert_in_delta Timeline.value(tl, :x), 93.75, 0.1
    end

    test "should maintain precision across multiple frame updates at 30fps" do
      tl =
        new_timeline(duration: 2000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          ease: :linear,
          start_time: 50
        )
        |> Timeline.play()

      frame_time = 33.33

      tl = Timeline.advance(tl, frame_time)
      assert Timeline.value(tl, :x) == 0

      tl = Timeline.advance(tl, frame_time)
      assert_in_delta Timeline.value(tl, :x), 1.67, 0.1

      tl = Timeline.advance(tl, frame_time)
      assert_in_delta Timeline.value(tl, :x), 5, 0.1

      # Advance 29 more frames
      tl = Enum.reduce(1..29, tl, fn _, acc -> Timeline.advance(acc, frame_time) end)
      assert_in_delta Timeline.value(tl, :x), 100, 1
    end
  end

  # ── Edge Cases ────────────────────────────────────────────────────────

  describe "Edge Cases" do
    test "should handle zero duration" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 0)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1)
      assert Timeline.value(tl, :x) == 100
    end

    test "should handle negative deltaTime gracefully" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, -100)
      assert Timeline.value(tl, :x) == 0
    end

    test "should handle very large deltaTime" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 10_000)
      assert Timeline.value(tl, :x) == 100
    end
  end

  # ── Easing Function Integration ───────────────────────────────────────

  describe "New Easing Function Tests" do
    @easing_test_cases [
      {:in_circ, 0.13397459621556135},
      {:out_circ, 0.8660254037844386},
      {:in_out_circ, 0.5},
      {:in_back, -0.0876975},
      {:out_back, 1.0876975},
      {:in_out_back, 0.5}
    ]

    for {easing, mid_value} <- [
          {:in_circ, 0.13397459621556135},
          {:out_circ, 0.8660254037844386},
          {:in_out_circ, 0.5},
          {:in_back, -0.0876975},
          {:out_back, 1.0876975},
          {:in_out_back, 0.5}
        ] do
      test "should animate correctly with #{easing} easing" do
        easing = unquote(easing)
        mid_value = unquote(mid_value)

        tl =
          new_timeline(duration: 1000)
          |> Timeline.add(:x, from: 0, to: 100, duration: 1000, ease: easing)
          |> Timeline.play()

        tl = Timeline.advance(tl, 0)
        assert_in_delta Timeline.value(tl, :x), 0, 0.001

        tl = Timeline.advance(tl, 500)
        assert_in_delta Timeline.value(tl, :x), 100 * mid_value, 0.001

        tl = Timeline.advance(tl, 500)
        assert_in_delta Timeline.value(tl, :x), 100, 0.001
      end
    end
  end

  # ── DeltaTime in Callbacks ────────────────────────────────────────────

  describe "DeltaTime in onUpdate Callbacks" do
    test "should provide correct deltaTime to onUpdate callbacks" do
      test_pid = self()

      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          on_update: fn info -> send(test_pid, {:dt, info.delta_time}) end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 16)
      assert_received {:dt, 16}

      tl = Timeline.advance(tl, 33)
      assert_received {:dt, 33}

      _tl = Timeline.advance(tl, 50)
      assert_received {:dt, 50}
    end

    test "should provide deltaTime across multiple animation loops" do
      test_pid = self()

      tl =
        new_timeline(duration: 5000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 500,
          loop: 3,
          loop_delay: 100,
          on_update: fn info -> send(test_pid, {:dt, info.delta_time}) end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 25)
      tl = Timeline.advance(tl, 30)
      tl = Timeline.advance(tl, 445)
      tl = Timeline.advance(tl, 35)
      tl = Timeline.advance(tl, 65)
      _tl = Timeline.advance(tl, 40)

      assert_received {:dt, 25}
      assert_received {:dt, 30}
      assert_received {:dt, 445}
      assert_received {:dt, 35}
      assert_received {:dt, 65}
      assert_received {:dt, 40}
    end

    test "should provide deltaTime to synced sub-timeline animations" do
      test_pid = self()

      sub_tl =
        new_timeline(duration: 500)
        |> Timeline.add(:value,
          from: 0,
          to: 50,
          duration: 500,
          on_update: fn info -> send(test_pid, {:sub_dt, info.delta_time}) end
        )

      main_tl =
        new_timeline(duration: 2000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          on_update: fn info -> send(test_pid, {:main_dt, info.delta_time}) end
        )
        |> Timeline.sync(sub_tl, 300)
        |> Timeline.play()

      main_tl = Timeline.advance(main_tl, 200)
      assert_received {:main_dt, 200}
      refute_received {:sub_dt, _}

      # 350ms total: sub starts at 300, so sub gets 50ms
      main_tl = Timeline.advance(main_tl, 150)
      assert_received {:main_dt, 150}
      assert_received {:sub_dt, 50}

      _main_tl = Timeline.advance(main_tl, 100)
      assert_received {:main_dt, 100}
      assert_received {:sub_dt, 100}
    end

    test "should handle deltaTime correctly when animation starts mid-frame" do
      test_pid = self()

      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 500,
          start_time: 250,
          on_update: fn info -> send(test_pid, {:dt, info.delta_time}) end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 200)
      refute_received {:dt, _}

      tl = Timeline.advance(tl, 100)
      assert_received {:dt, 100}

      _tl = Timeline.advance(tl, 150)
      assert_received {:dt, 150}
    end

    test "should provide correct deltaTime for zero duration animations" do
      test_pid = self()

      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 0,
          on_update: fn info -> send(test_pid, {:dt, info.delta_time}) end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 50)
      assert_received {:dt, 50}
      assert Timeline.value(tl, :x) == 100

      _tl = Timeline.advance(tl, 25)
      refute_received {:dt, _}
    end

    test "should provide consistent deltaTime during alternating animations" do
      test_pid = self()

      tl =
        new_timeline(duration: 3000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 500,
          loop: 2,
          alternate: true,
          on_update: fn info ->
            send(test_pid, {:dt, info.delta_time, info.progress})
          end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 125)
      _tl = Timeline.advance(tl, 375)

      assert_received {:dt, 250, progress1}
      assert progress1 == 0.5

      assert_received {:dt, 250, progress2}
      assert progress2 == 1

      assert_received {:dt, 125, progress3}
      assert progress3 == 0.25

      assert_received {:dt, 375, progress4}
      assert progress4 == 1
    end
  end

  # ── onUpdate Callback Frequency and Correctness ──────────────────────

  describe "onUpdate Callback Frequency and Correctness" do
    test "should provide correct progress values in onUpdate callbacks" do
      test_pid = self()

      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          ease: :linear,
          on_update: fn info ->
            send(test_pid, {:update, info.progress, info.value})
          end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 0)
      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      _tl = Timeline.advance(tl, 250)

      assert_received {:update, 0, 0}
      assert_received {:update, 0.25, 25}
      assert_received {:update, 0.5, 50}
      assert_received {:update, 0.75, 75}
      assert_received {:update, 1, 100}
    end

    test "should call onUpdate for each animation in a looping scenario without duplicates" do
      test_pid = self()

      tl =
        new_timeline(duration: 3000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 500,
          loop: 3,
          on_update: fn info -> send(test_pid, {:update, info.progress}) end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      _tl = Timeline.advance(tl, 250)

      updates = collect_messages({:update, :_})
      assert length(updates) == 6
      assert Enum.map(updates, fn {:update, p} -> p end) == [0.5, 1, 0.5, 1, 0.5, 1]
    end

    test "should call onUpdate correctly for alternating animations" do
      test_pid = self()

      tl =
        new_timeline(duration: 3000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 500,
          loop: 3,
          alternate: true,
          on_update: fn info ->
            send(test_pid, {:update, info.value, info.progress})
          end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      tl = Timeline.advance(tl, 250)
      _tl = Timeline.advance(tl, 250)

      updates = collect_messages({:update, :_, :_})
      assert length(updates) == 6

      values = Enum.map(updates, fn {:update, v, _p} -> v end)
      assert values == [50, 100, 50, 0, 50, 100]

      progresses = Enum.map(updates, fn {:update, _v, p} -> p end)
      assert progresses == [0.5, 1, 0.5, 1, 0.5, 1]
    end

    test "should not call onUpdate multiple times for zero duration animations" do
      test_pid = self()

      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 0,
          on_update: fn info -> send(test_pid, {:update, info.progress}) end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 50)
      tl = Timeline.advance(tl, 100)
      _tl = Timeline.advance(tl, 200)

      updates = collect_messages({:update, :_})
      assert length(updates) == 1
      assert [{:update, 1}] = updates
    end

    test "should not call onUpdate after animation completes" do
      test_pid = self()

      tl =
        new_timeline(duration: 2000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 500,
          on_update: fn _info -> send(test_pid, :updated) end,
          on_complete: fn -> send(test_pid, :completed) end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 250)
      assert_received :updated
      refute_received :completed
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 250)
      assert_received :updated
      assert_received :completed
      assert Timeline.value(tl, :x) == 100

      tl = Timeline.advance(tl, 300)
      tl = Timeline.advance(tl, 400)
      _tl = Timeline.advance(tl, 500)

      refute_received :updated
      refute_received :completed
    end

    test "should provide correct deltaTime and timing information in onUpdate" do
      test_pid = self()

      tl =
        new_timeline(duration: 2000)
        |> Timeline.add(:x,
          from: 0,
          to: 100,
          duration: 1000,
          start_time: 300,
          on_update: fn info ->
            send(test_pid, {:timing, info.delta_time, info.current_time})
          end
        )
        |> Timeline.play()

      tl = Timeline.advance(tl, 200)
      refute_received {:timing, _, _}

      tl = Timeline.advance(tl, 150)
      tl = Timeline.advance(tl, 200)
      tl = Timeline.advance(tl, 300)
      _tl = Timeline.advance(tl, 450)

      assert_received {:timing, 150, 350}
      assert_received {:timing, 200, 550}
      assert_received {:timing, 300, 850}
      assert_received {:timing, 450, 1300}
    end
  end

  # ── Target Value Persistence ──────────────────────────────────────────

  describe "Target Value Persistence" do
    test "should not reset values when animation has not started yet" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 75, to: 100, duration: 300, start_time: 500)
        |> Timeline.play()

      tl = Timeline.advance(tl, 100)
      assert Timeline.value(tl, :x) == 75

      tl = Timeline.advance(tl, 200)
      assert Timeline.value(tl, :x) == 75

      tl = Timeline.advance(tl, 300)
      assert_in_delta Timeline.value(tl, :x), 83.33, 0.1
    end

    test "should preserve final values after animation completes" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 500)
        |> Timeline.play()

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 100

      tl = Timeline.advance(tl, 100)
      tl = Timeline.advance(tl, 100)
      tl = Timeline.advance(tl, 100)
      assert Timeline.value(tl, :x) == 100
    end

    test "should preserve final values across timeline loops" do
      tl =
        new_timeline(duration: 1000, loop: true)
        |> Timeline.add(:value, from: 0, to: 100, duration: 600)
        |> Timeline.play()

      tl = Timeline.advance(tl, 600)
      assert Timeline.value(tl, :value) == 100

      # Gap between animation end (600) and timeline loop (1000)
      tl = Timeline.advance(tl, 400)
      assert Timeline.value(tl, :value) == 100

      # Into second loop — 300ms past loop start
      tl = Timeline.advance(tl, 300)
      assert Timeline.value(tl, :value) == 50
    end

    test "should preserve original initial values across timeline loops" do
      tl =
        new_timeline(duration: 1000, loop: true)
        |> Timeline.add(:value, from: 0, to: 100, duration: 600)
        |> Timeline.play()

      tl = Timeline.advance(tl, 600)
      assert Timeline.value(tl, :value) == 100

      tl = Timeline.advance(tl, 400)
      assert Timeline.value(tl, :value) == 100

      tl = Timeline.advance(tl, 300)
      assert Timeline.value(tl, :value) == 50
    end
  end

  # ── Multiple Animations on Same Property ──────────────────────────────

  describe "Multiple Animations on Same Property" do
    test "should handle multiple animations on the same property at different times" do
      tl =
        new_timeline(duration: 5000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 100, start_time: 0)
        |> Timeline.add(:x, from: 100, to: 50, duration: 100, start_time: 200)
        |> Timeline.play()

      assert Timeline.value(tl, :x) == 0

      tl = Timeline.advance(tl, 50)
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 50)
      assert Timeline.value(tl, :x) == 100

      tl = Timeline.advance(tl, 50)
      assert Timeline.value(tl, :x) == 100

      tl = Timeline.advance(tl, 100)
      assert Timeline.value(tl, :x) == 75

      tl = Timeline.advance(tl, 50)
      assert Timeline.value(tl, :x) == 50
    end

    test "should handle multiple sequential animations on different properties" do
      tl =
        new_timeline(duration: 5000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, start_time: 0)
        |> Timeline.add(:y, from: 0, to: 50, duration: 500, start_time: 1500)
        |> Timeline.add(:z, from: 0, to: 200, duration: 1000, start_time: 3000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 0)
      assert Timeline.value(tl, :x) == 0
      assert Timeline.value(tl, :y) == 0
      assert Timeline.value(tl, :z) == 0

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50
      assert Timeline.value(tl, :y) == 0
      assert Timeline.value(tl, :z) == 0

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 0
      assert Timeline.value(tl, :z) == 0

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 0
      assert Timeline.value(tl, :z) == 0

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 0
      assert Timeline.value(tl, :z) == 0

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 25
      assert Timeline.value(tl, :z) == 0

      tl = tl |> Timeline.advance(250) |> Timeline.advance(500)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 50
      assert Timeline.value(tl, :z) == 0

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 50
      assert Timeline.value(tl, :z) == 0

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 50
      assert Timeline.value(tl, :z) == 100

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 50
      assert Timeline.value(tl, :z) == 200

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 50
      assert Timeline.value(tl, :z) == 200
    end

    test "should handle overlapping animations on different properties" do
      tl =
        new_timeline(duration: 3000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, start_time: 0)
        |> Timeline.add(:y, from: 0, to: 50, duration: 1000, start_time: 500)
        |> Timeline.add(:scale, from: 1, to: 2, duration: 1000, start_time: 800)
        |> Timeline.play()

      tl = Timeline.advance(tl, 600)
      assert Timeline.value(tl, :x) == 60
      assert_in_delta Timeline.value(tl, :y), 5, 0.1
      assert Timeline.value(tl, :scale) == 1

      tl = Timeline.advance(tl, 400)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 25
      assert_in_delta Timeline.value(tl, :scale), 1.2, 0.01

      tl = Timeline.advance(tl, 600)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 50
      assert_in_delta Timeline.value(tl, :scale), 1.8, 0.01

      tl = Timeline.advance(tl, 400)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.value(tl, :y) == 50
      assert Timeline.value(tl, :scale) == 2
    end

    test "should handle multiple animations with different easing functions" do
      tl =
        new_timeline(duration: 3000)
        |> Timeline.add(:a, from: 0, to: 100, duration: 1000, ease: :linear, start_time: 0)
        |> Timeline.add(:b, from: 0, to: 100, duration: 1000, ease: :in_quad, start_time: 500)
        |> Timeline.add(:c, from: 0, to: 100, duration: 1000, ease: :in_expo, start_time: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :a) == 50
      assert Timeline.value(tl, :b) == 0
      assert Timeline.value(tl, :c) == 0

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :a) == 100
      assert Timeline.value(tl, :b) == 25
      assert Timeline.value(tl, :c) == 0

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :a) == 100
      assert Timeline.value(tl, :b) == 100
      c_val = Timeline.value(tl, :c)
      assert c_val > 0 and c_val < 50

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :a) == 100
      assert Timeline.value(tl, :b) == 100
      assert Timeline.value(tl, :c) == 100
    end
  end

  # ── Scene00 Reproduction Bug ──────────────────────────────────────────

  describe "Scene00 Reproduction Bug" do
    test "should execute callbacks at position 0 again when timeline loops" do
      test_pid = self()

      tl =
        new_timeline(duration: 1000, loop: true)
        |> Timeline.call(fn -> send(test_pid, :reset_callback) end, 0)
        |> Timeline.add(:x, from: 0, to: 100, duration: 500, start_time: 200)
        |> Timeline.play()

      tl = Timeline.advance(tl, 0)
      assert_received :reset_callback
      assert Timeline.value(tl, :x) == 0

      tl = Timeline.advance(tl, 200)
      assert Timeline.value(tl, :x) == 0

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 50

      # Cross loop boundary: 575ms more => total 1025ms => loops to 25ms
      tl = Timeline.advance(tl, 575)
      assert Timeline.current_time(tl) == 25
      assert_received :reset_callback
      assert Timeline.value(tl, :x) == 0

      tl = Timeline.advance(tl, 175)
      assert Timeline.value(tl, :x) == 0

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 50
    end

    test "should execute callbacks at position 0 again when nested sub-timeline loops" do
      test_pid = self()

      sub_tl =
        new_timeline(duration: 1000, loop: true)
        |> Timeline.call(fn -> send(test_pid, :sub_reset) end, 0)
        |> Timeline.add(:x, from: 0, to: 100, duration: 500, start_time: 200)

      main_tl =
        new_timeline(duration: 3000)
        |> Timeline.sync(sub_tl, 500)
        |> Timeline.play()

      main_tl = Timeline.advance(main_tl, 400)
      refute_received :sub_reset

      main_tl = Timeline.advance(main_tl, 100)
      assert_received :sub_reset

      main_tl = Timeline.advance(main_tl, 200)
      assert Timeline.value(main_tl, :x) == 0

      main_tl = Timeline.advance(main_tl, 250)
      assert Timeline.value(main_tl, :x) == 50

      # Cross sub-timeline loop boundary
      main_tl = main_tl |> Timeline.advance(550) |> Timeline.advance(25)
      assert_received :sub_reset
      assert Timeline.value(main_tl, :x) == 0

      main_tl = Timeline.advance(main_tl, 200)
      assert_in_delta Timeline.value(main_tl, :x), 5, 0.1

      main_tl = Timeline.advance(main_tl, 225)
      assert Timeline.value(main_tl, :x) == 50
    end

    test "should restart animations at position 0 again when nested sub-timeline loops" do
      test_pid = self()

      sub_tl =
        new_timeline(duration: 1000, loop: true)
        |> Timeline.add(:value,
          from: 0,
          to: 100,
          duration: 500,
          start_time: 0,
          on_start: fn -> send(test_pid, :anim_start) end
        )

      main_tl =
        new_timeline(duration: 3000)
        |> Timeline.sync(sub_tl, 500)
        |> Timeline.play()

      main_tl = Timeline.advance(main_tl, 400)
      refute_received :anim_start

      main_tl = Timeline.advance(main_tl, 100)
      assert_received :anim_start
      assert Timeline.value(main_tl, :value) == 0

      main_tl = Timeline.advance(main_tl, 250)
      assert Timeline.value(main_tl, :value) == 50

      main_tl = Timeline.advance(main_tl, 250)
      assert Timeline.value(main_tl, :value) == 100

      # Cross sub-timeline loop boundary
      main_tl = main_tl |> Timeline.advance(500) |> Timeline.advance(25)
      assert_received :anim_start
      assert_in_delta Timeline.value(main_tl, :value), 5, 0.1

      main_tl = Timeline.advance(main_tl, 225)
      assert Timeline.value(main_tl, :value) == 50

      main_tl = Timeline.advance(main_tl, 250)
      assert Timeline.value(main_tl, :value) == 100
    end
  end

  # ── Timeline onComplete Callback ─────────────────────────────────────

  describe "Timeline onComplete Callback" do
    test "should call onComplete when timeline finishes (non-looping)" do
      test_pid = self()

      tl =
        new_timeline(
          duration: 1000,
          loop: false,
          on_complete: fn -> send(test_pid, :complete) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 500)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      refute_received :complete
      assert Timeline.playing?(tl) == true

      tl = Timeline.advance(tl, 500)
      assert_received :complete
      assert Timeline.playing?(tl) == false

      _tl = Timeline.advance(tl, 1000)
      refute_received :complete
    end

    test "should not call onComplete for looping timelines" do
      test_pid = self()

      tl =
        new_timeline(
          duration: 1000,
          loop: true,
          on_complete: fn -> send(test_pid, :complete) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 500)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      refute_received :complete
      assert Timeline.playing?(tl) == true

      tl = Timeline.advance(tl, 1000)
      refute_received :complete
      assert Timeline.playing?(tl) == true

      _tl = Timeline.advance(tl, 2000)
      refute_received :complete
    end

    test "should call onComplete again when timeline is restarted and completes" do
      test_pid = self()

      tl =
        new_timeline(
          duration: 1000,
          loop: false,
          on_complete: fn -> send(test_pid, :complete) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 800)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert_received :complete
      assert Timeline.playing?(tl) == false

      tl = Timeline.restart(tl)
      assert Timeline.playing?(tl) == true

      _tl = Timeline.advance(tl, 1000)
      assert_received :complete
    end

    test "should not call onComplete when timeline is paused before completion" do
      test_pid = self()

      tl =
        new_timeline(
          duration: 1000,
          loop: false,
          on_complete: fn -> send(test_pid, :complete) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 800)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      refute_received :complete
      assert Timeline.playing?(tl) == true

      tl = Timeline.pause(tl)
      _tl = Timeline.advance(tl, 1000)
      refute_received :complete
    end

    test "should call onComplete when playing again after pause reaches completion" do
      test_pid = self()

      tl =
        new_timeline(
          duration: 1000,
          loop: false,
          on_complete: fn -> send(test_pid, :complete) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 800)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      tl = Timeline.pause(tl)
      tl = Timeline.advance(tl, 1000)
      refute_received :complete

      tl = Timeline.play(tl)
      tl = Timeline.advance(tl, 500)
      assert_received :complete
      assert Timeline.playing?(tl) == false
    end

    test "should call onComplete with correct timing when timeline has overshoot" do
      test_pid = self()

      tl =
        new_timeline(
          duration: 1000,
          loop: false,
          on_complete: fn -> send(test_pid, :complete) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 800)
        |> Timeline.play()

      _tl = Timeline.advance(tl, 1200)
      assert_received :complete
    end

    test "should work correctly with synced sub-timelines" do
      test_pid = self()

      sub_tl =
        new_timeline(
          duration: 1000,
          on_complete: fn -> send(test_pid, :sub_complete) end
        )
        |> Timeline.add(:value, from: 0, to: 100, duration: 800)

      main_tl =
        new_timeline(
          duration: 2000,
          on_complete: fn -> send(test_pid, :main_complete) end
        )
        |> Timeline.add(:x, from: 0, to: 50, duration: 1500)
        |> Timeline.sync(sub_tl, 500)
        |> Timeline.play()

      main_tl = Timeline.advance(main_tl, 1300)
      refute_received :sub_complete
      refute_received :main_complete

      _main_tl = Timeline.advance(main_tl, 700)
      assert_received :sub_complete
      assert_received :main_complete
    end

    test "should handle onComplete with timeline that has only callbacks" do
      test_pid = self()

      tl =
        new_timeline(
          duration: 500,
          on_complete: fn -> send(test_pid, :complete) end
        )
        |> Timeline.call(fn -> send(test_pid, :callback_fired) end, 200)
        |> Timeline.play()

      tl = Timeline.advance(tl, 300)
      assert_received :callback_fired
      refute_received :complete
      assert Timeline.playing?(tl) == true

      _tl = Timeline.advance(tl, 200)
      assert_received :complete
    end

    test "should handle onComplete when timeline duration is shorter than animations" do
      test_pid = self()

      tl =
        new_timeline(
          duration: 800,
          on_complete: fn -> send(test_pid, :complete) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 800)
      assert_received :complete
      # Animation is 80% done when timeline completes
      assert Timeline.value(tl, :x) == 80
    end

    test "should not call onComplete multiple times on same completion" do
      test_pid = self()

      tl =
        new_timeline(
          duration: 500,
          on_complete: fn -> send(test_pid, :complete) end
        )
        |> Timeline.add(:x, from: 0, to: 100, duration: 300)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      assert_received :complete

      tl = Timeline.advance(tl, 100)
      tl = Timeline.advance(tl, 200)
      _tl = Timeline.advance(tl, 500)
      refute_received :complete
    end
  end

  # ── Once Method ──────────────────────────────────────────────────────

  describe "Once Method" do
    test "should execute once animation immediately" do
      tl =
        new_timeline(duration: 2000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)

      assert_raise ArgumentError, ~r/unknown timeline property/, fn ->
        Timeline.value(tl, :x)
      end

      tl = Timeline.once(tl, :x, from: 0, to: 100, duration: 500)

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 100
    end

    test "should not re-execute once animation when timeline loops" do
      test_pid = self()

      tl =
        new_timeline(duration: 1000, loop: true)
        |> Timeline.play()

      tl = Timeline.advance(tl, 200)

      tl =
        Timeline.once(tl, :x,
          from: 0,
          to: 100,
          duration: 300,
          on_start: fn -> send(test_pid, :once_start) end,
          on_complete: fn -> send(test_pid, :once_complete) end
        )

      tl = Timeline.advance(tl, 300)
      assert Timeline.value(tl, :x) == 100
      assert_received :once_start
      assert_received :once_complete

      # Loop boundary
      tl = Timeline.advance(tl, 500)
      assert Timeline.current_time(tl) == 0

      tl = Timeline.advance(tl, 500)
      # Should NOT re-trigger
      refute_received :once_start
      refute_received :once_complete
    end
  end

  # ── State and Inspection ─────────────────────────────────────────────

  describe "State and Inspection" do
    test "playing? returns false initially" do
      tl = new_timeline(duration: 1000)
      assert Timeline.playing?(tl) == false
    end

    test "playing? returns true after play" do
      tl = new_timeline(duration: 1000) |> Timeline.play()
      assert Timeline.playing?(tl) == true
    end

    test "playing? returns false after pause" do
      tl = new_timeline(duration: 1000) |> Timeline.play() |> Timeline.pause()
      assert Timeline.playing?(tl) == false
    end

    test "playing? returns false after completion" do
      tl =
        new_timeline(duration: 100)
        |> Timeline.add(:x, from: 0, to: 100, duration: 100)
        |> Timeline.play()
        |> Timeline.advance(200)

      assert Timeline.playing?(tl) == false
    end

    test "current_time returns 0 initially" do
      tl = new_timeline(duration: 1000)
      assert Timeline.current_time(tl) == 0
    end

    test "current_time advances correctly" do
      tl = new_timeline(duration: 1000) |> Timeline.play() |> Timeline.advance(300)
      assert Timeline.current_time(tl) == 300
    end

    test "current_time wraps on loop" do
      tl =
        new_timeline(duration: 1000, loop: true)
        |> Timeline.play()
        |> Timeline.advance(1500)

      assert Timeline.current_time(tl) == 500
    end

    test "current_time clamps at duration for non-looping" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.play()
        |> Timeline.advance(2000)

      assert Timeline.current_time(tl) == 1000
    end

    test "value/2 raises on unknown property" do
      tl =
        new_timeline()
        |> Timeline.add(:x, from: 0, to: 1, duration: 100)
        |> Timeline.play()

      assert_raise ArgumentError, ~r/unknown timeline property/, fn ->
        Timeline.value(tl, :nonexistent)
      end
    end

    test "value returns from-value before animation starts" do
      tl =
        new_timeline(duration: 1000)
        |> Timeline.add(:x, from: 42, to: 100, duration: 500, start_time: 500)

      assert Timeline.value(tl, :x) == 42
    end
  end

  # ── Helper to collect messages from mailbox ──

  defp collect_messages(pattern) do
    collect_messages(pattern, [])
  end

  defp collect_messages({tag, :_}, acc) do
    receive do
      {^tag, val} -> collect_messages({tag, :_}, [{tag, val} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp collect_messages({tag, :_, :_}, acc) do
    receive do
      {^tag, v1, v2} -> collect_messages({tag, :_, :_}, [{tag, v1, v2} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
