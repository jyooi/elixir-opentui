defmodule ElixirOpentui.Animation.TimelineTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Animation.Timeline

  describe "Basic Animation" do
    test "should animate a single property" do
      tl =
        Timeline.new(duration: 1000)
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
        Timeline.new(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.add(:y, from: 0, to: 200, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50
      assert Timeline.value(tl, :y) == 100
    end

    test "should handle easing functions" do
      tl =
        Timeline.new(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, ease: :linear)
        |> Timeline.play()

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50
    end
  end

  describe "Timeline Control" do
    setup do
      tl =
        Timeline.new(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)

      %{tl: tl}
    end

    test "should not advance before play", %{tl: tl} do
      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 0
    end

    test "should animate when played", %{tl: tl} do
      tl = tl |> Timeline.play() |> Timeline.advance(500)
      assert Timeline.value(tl, :x) == 50
    end

    test "should play again when calling play() on a finished non-looping timeline", %{tl: tl} do
      tl = tl |> Timeline.play() |> Timeline.advance(1000)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.finished?(tl)

      tl = Timeline.play(tl)
      refute Timeline.finished?(tl)

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.finished?(tl)
    end
  end

  describe "Looping" do
    test "should loop timeline when loop is true" do
      tl =
        Timeline.new(duration: 1000, loop: true)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 50
    end

    test "should loop a finite number of times" do
      tl =
        Timeline.new(duration: 1000, loop: 2)
        |> Timeline.add(:x, from: 0, to: 100)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1500)
      assert Timeline.value(tl, :x) == 50
      refute Timeline.finished?(tl)

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.finished?(tl)
    end

    test "should not loop when loop is false" do
      tl =
        Timeline.new(duration: 1000, loop: false)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1000)
      assert Timeline.value(tl, :x) == 100
      assert Timeline.finished?(tl)

      tl = Timeline.advance(tl, 500)
      assert Timeline.value(tl, :x) == 100
    end

    test "timeline-level alternate reverses items on each timeline loop" do
      tl =
        Timeline.new(duration: 1000, loop: true, alternate: true)
        |> Timeline.add(:x, from: 0, to: 100)
        |> Timeline.play()
        |> Timeline.advance(1250)

      assert Timeline.value(tl, :x) == 75
    end
  end

  describe "Timing Precision" do
    test "should account for overshoot when animation starts late" do
      tl =
        Timeline.new(duration: 2000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, ease: :linear, start_time: 50)
        |> Timeline.play()

      tl = Timeline.advance(tl, 66)
      assert_in_delta Timeline.value(tl, :x), 1.6, 0.1
    end

    test "should handle multiple animations with different start time overshoots" do
      tl =
        Timeline.new(duration: 3000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, ease: :linear, start_time: 30)
        |> Timeline.add(:y, from: 0, to: 200, duration: 1000, ease: :linear, start_time: 80)
        |> Timeline.play()

      tl = Timeline.advance(tl, 100)

      assert_in_delta Timeline.value(tl, :x), 7, 0.1
      assert_in_delta Timeline.value(tl, :y), 4, 0.1
    end

    test "should handle zero duration animations with overshoot" do
      tl =
        Timeline.new(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 0, start_time: 50)
        |> Timeline.play()

      tl = Timeline.advance(tl, 66)
      assert Timeline.value(tl, :x) == 100
    end

    test "should maintain precision across multiple frame updates at 30fps" do
      tl =
        Timeline.new(duration: 2000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000, ease: :linear, start_time: 50)
        |> Timeline.play()

      frame_time = 33.33

      tl = Timeline.advance(tl, frame_time)
      assert Timeline.value(tl, :x) == 0

      tl = Timeline.advance(tl, frame_time)
      assert_in_delta Timeline.value(tl, :x), 1.67, 0.1

      tl = Timeline.advance(tl, frame_time)
      assert_in_delta Timeline.value(tl, :x), 5, 0.1

      tl = Enum.reduce(1..29, tl, fn _, acc -> Timeline.advance(acc, frame_time) end)
      assert_in_delta Timeline.value(tl, :x), 100, 1
    end
  end

  describe "Edge Cases" do
    test "should handle zero duration" do
      tl =
        Timeline.new(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 0)
        |> Timeline.play()

      tl = Timeline.advance(tl, 1)
      assert Timeline.value(tl, :x) == 100
    end

    test "should handle negative deltaTime gracefully" do
      tl =
        Timeline.new(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, -100)
      assert Timeline.value(tl, :x) == 0
    end

    test "should handle very large deltaTime" do
      tl =
        Timeline.new(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 1000)
        |> Timeline.play()

      tl = Timeline.advance(tl, 10_000)
      assert Timeline.value(tl, :x) == 100
    end

    test "value/2 raises on unknown property" do
      tl =
        Timeline.new()
        |> Timeline.add(:x, from: 0, to: 1, duration: 100)
        |> Timeline.play()

      assert_raise ArgumentError, ~r/unknown timeline property/, fn ->
        Timeline.value(tl, :nonexistent)
      end
    end

    test "value returns from-value before animation starts" do
      tl =
        Timeline.new(duration: 1000)
        |> Timeline.add(:x, from: 42, to: 100, duration: 500, start_time: 500)

      assert Timeline.value(tl, :x) == 42
    end
  end

  describe "Easing Integration" do
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
          Timeline.new(duration: 1000)
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

  describe "Target Value Persistence" do
    test "should not reset values when animation has not started yet" do
      tl =
        Timeline.new(duration: 1000)
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
        Timeline.new(duration: 1000)
        |> Timeline.add(:x, from: 0, to: 100, duration: 500)
        |> Timeline.play()

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 50

      tl = Timeline.advance(tl, 250)
      assert Timeline.value(tl, :x) == 100

      tl = tl |> Timeline.advance(100) |> Timeline.advance(100) |> Timeline.advance(100)
      assert Timeline.value(tl, :x) == 100
    end

    test "should preserve final values across timeline loops" do
      tl =
        Timeline.new(duration: 1000, loop: true)
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

  describe "Multiple Animations" do
    test "should handle multiple animations on the same property at different times" do
      tl =
        Timeline.new(duration: 5000)
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

    test "should handle overlapping animations on different properties" do
      tl =
        Timeline.new(duration: 3000)
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
        Timeline.new(duration: 3000)
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
end
