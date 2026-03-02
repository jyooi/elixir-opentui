defmodule ElixirOpentui.Animation.EasingTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Animation.Easing

  # ── Boundary values: f(0) == 0 and f(1) == 1 for every curve ──

  @all_easings [
    :linear,
    :in_quad,
    :out_quad,
    :in_out_quad,
    :in_cubic,
    :out_cubic,
    :in_out_cubic,
    :in_expo,
    :out_expo,
    :in_out_expo,
    :in_sine,
    :out_sine,
    :in_out_sine,
    :in_circ,
    :out_circ,
    :in_out_circ,
    :in_back,
    :out_back,
    :in_out_back,
    :in_elastic,
    :out_elastic,
    :in_out_elastic,
    :in_bounce,
    :out_bounce,
    :in_out_bounce
  ]

  describe "boundary values" do
    for easing <- @all_easings do
      test "#{easing} at t=0.0 returns 0.0" do
        assert_in_delta Easing.apply(unquote(easing), 0.0), 0.0, 1.0e-10
      end

      test "#{easing} at t=1.0 returns 1.0" do
        assert_in_delta Easing.apply(unquote(easing), 1.0), 1.0, 1.0e-10
      end
    end
  end

  # ── Midpoint values for key curves ──

  describe "midpoint values" do
    test "linear at 0.5 returns 0.5" do
      assert Easing.apply(:linear, 0.5) == 0.5
    end

    test "in_quad at 0.5 returns 0.25" do
      assert_in_delta Easing.apply(:in_quad, 0.5), 0.25, 1.0e-10
    end

    test "out_quad at 0.5 returns 0.75" do
      assert_in_delta Easing.apply(:out_quad, 0.5), 0.75, 1.0e-10
    end

    test "in_out_quad at 0.5 returns 0.5" do
      assert_in_delta Easing.apply(:in_out_quad, 0.5), 0.5, 1.0e-10
    end

    test "in_cubic at 0.5 returns 0.125" do
      assert_in_delta Easing.apply(:in_cubic, 0.5), 0.125, 1.0e-10
    end

    test "out_cubic at 0.5 returns 0.875" do
      assert_in_delta Easing.apply(:out_cubic, 0.5), 0.875, 1.0e-10
    end

    test "in_out_cubic at 0.5 returns 0.5" do
      assert_in_delta Easing.apply(:in_out_cubic, 0.5), 0.5, 1.0e-10
    end

    test "in_circ at 0.5 returns ~0.134" do
      assert_in_delta Easing.apply(:in_circ, 0.5), 0.13397459621556135, 1.0e-6
    end

    test "out_circ at 0.5 returns ~0.866" do
      assert_in_delta Easing.apply(:out_circ, 0.5), 0.8660254037844386, 1.0e-6
    end

    test "in_out_circ at 0.5 returns 0.5" do
      assert_in_delta Easing.apply(:in_out_circ, 0.5), 0.5, 1.0e-6
    end

    test "in_back at 0.5 returns negative overshoot ~-0.0877" do
      assert_in_delta Easing.apply(:in_back, 0.5), -0.0876975, 1.0e-4
    end

    test "out_back at 0.5 returns overshoot ~1.0877" do
      assert_in_delta Easing.apply(:out_back, 0.5), 1.0876975, 1.0e-4
    end

    test "in_out_back at 0.5 returns 0.5" do
      assert_in_delta Easing.apply(:in_out_back, 0.5), 0.5, 1.0e-6
    end

    test "in_expo at 0.5 returns ~0.03125" do
      assert_in_delta Easing.apply(:in_expo, 0.5), 0.03125, 1.0e-4
    end

    test "out_expo at 0.5 returns ~0.96875" do
      assert_in_delta Easing.apply(:out_expo, 0.5), 0.96875, 1.0e-4
    end

    test "in_out_expo at 0.5 returns 0.5" do
      assert_in_delta Easing.apply(:in_out_expo, 0.5), 0.5, 1.0e-4
    end
  end

  # ── Monotonicity ──

  describe "monotonicity" do
    # These curves should be strictly monotonically increasing across [0, 1]
    @monotonic_curves @all_easings --
                        [
                          :in_back,
                          :out_back,
                          :in_out_back,
                          :in_elastic,
                          :out_elastic,
                          :in_out_elastic,
                          :in_bounce,
                          :out_bounce,
                          :in_out_bounce
                        ]

    for easing <- @monotonic_curves do
      test "#{easing} is monotonically increasing" do
        steps = for i <- 0..100, do: i / 100.0
        values = Enum.map(steps, &Easing.apply(unquote(easing), &1))

        values
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [a, b] ->
          assert b >= a,
                 "#{unquote(easing)} is not monotonically increasing: #{a} > #{b}"
        end)
      end
    end
  end

  # ── Parameterized back/overshoot curves ──

  describe "back easing overshoot" do
    test "in_back goes below 0.0 at some point" do
      values = for i <- 1..99, do: Easing.apply(:in_back, i / 100.0)
      assert Enum.any?(values, &(&1 < 0.0)), "in_back should overshoot below 0"
    end

    test "out_back goes above 1.0 at some point" do
      values = for i <- 1..99, do: Easing.apply(:out_back, i / 100.0)
      assert Enum.any?(values, &(&1 > 1.0)), "out_back should overshoot above 1"
    end

    test "in_out_back goes below 0.0 in the first half" do
      values = for i <- 1..49, do: Easing.apply(:in_out_back, i / 100.0)
      assert Enum.any?(values, &(&1 < 0.0)), "in_out_back should overshoot below 0 in first half"
    end

    test "in_out_back goes above 1.0 in the second half" do
      values = for i <- 51..99, do: Easing.apply(:in_out_back, i / 100.0)
      assert Enum.any?(values, &(&1 > 1.0)), "in_out_back should overshoot above 1 in second half"
    end
  end

  # ── Specific quarter/three-quarter values ──

  describe "quarter and three-quarter values" do
    test "linear at 0.25 returns 0.25" do
      assert Easing.apply(:linear, 0.25) == 0.25
    end

    test "linear at 0.75 returns 0.75" do
      assert Easing.apply(:linear, 0.75) == 0.75
    end

    test "in_quad at 0.25 returns 0.0625" do
      assert_in_delta Easing.apply(:in_quad, 0.25), 0.0625, 1.0e-10
    end

    test "in_quad at 0.75 returns 0.5625" do
      assert_in_delta Easing.apply(:in_quad, 0.75), 0.5625, 1.0e-10
    end

    test "out_quad at 0.25 returns 0.4375" do
      assert_in_delta Easing.apply(:out_quad, 0.25), 0.4375, 1.0e-10
    end

    test "out_quad at 0.75 returns 0.9375" do
      assert_in_delta Easing.apply(:out_quad, 0.75), 0.9375, 1.0e-10
    end

    test "in_cubic at 0.25 returns 0.015625" do
      assert_in_delta Easing.apply(:in_cubic, 0.25), 0.015625, 1.0e-10
    end

    test "in_cubic at 0.75 returns 0.421875" do
      assert_in_delta Easing.apply(:in_cubic, 0.75), 0.421875, 1.0e-10
    end
  end

  # ── Symmetry properties ──

  describe "symmetry" do
    test "in_quad and out_quad are symmetric: in_quad(t) + out_quad(1-t) == 1" do
      for i <- 0..100 do
        t = i / 100.0
        assert_in_delta Easing.apply(:in_quad, t) + Easing.apply(:out_quad, 1.0 - t), 1.0, 1.0e-10
      end
    end

    test "in_cubic and out_cubic are symmetric: in_cubic(t) + out_cubic(1-t) == 1" do
      for i <- 0..100 do
        t = i / 100.0

        assert_in_delta Easing.apply(:in_cubic, t) + Easing.apply(:out_cubic, 1.0 - t),
                        1.0,
                        1.0e-10
      end
    end

    test "in_out_quad is symmetric around (0.5, 0.5)" do
      for i <- 1..49 do
        t = i / 100.0

        assert_in_delta Easing.apply(:in_out_quad, t) + Easing.apply(:in_out_quad, 1.0 - t),
                        1.0,
                        1.0e-10
      end
    end

    test "in_out_cubic is symmetric around (0.5, 0.5)" do
      for i <- 1..49 do
        t = i / 100.0

        assert_in_delta Easing.apply(:in_out_cubic, t) + Easing.apply(:in_out_cubic, 1.0 - t),
                        1.0,
                        1.0e-10
      end
    end
  end

  # ── Expo edge cases ──

  describe "expo edge cases" do
    test "in_expo at very small t is near 0" do
      assert Easing.apply(:in_expo, 0.01) < 0.01
    end

    test "out_expo at very large t is near 1" do
      assert Easing.apply(:out_expo, 0.99) > 0.99
    end

    test "in_expo grows very slowly at the start" do
      v1 = Easing.apply(:in_expo, 0.1)
      v2 = Easing.apply(:in_expo, 0.2)
      # Both should be small for exponential-in
      assert v1 < 0.01
      assert v2 < 0.01
    end

    test "out_expo grows very quickly at the start" do
      v1 = Easing.apply(:out_expo, 0.1)
      # out_expo should jump fast
      assert v1 > 0.4
    end
  end

  # ── Range validation ──

  describe "range validation" do
    # Non-overshoot curves should stay within [0, 1]
    @bounded_curves @monotonic_curves

    for easing <- @bounded_curves do
      test "#{easing} stays within [0, 1]" do
        for i <- 0..100 do
          t = i / 100.0
          v = Easing.apply(unquote(easing), t)
          assert v >= -1.0e-10, "#{unquote(easing)} at #{t} went below 0: #{v}"
          assert v <= 1.0 + 1.0e-10, "#{unquote(easing)} at #{t} went above 1: #{v}"
        end
      end
    end
  end

  # ── Continuity: small input changes produce small output changes ──

  describe "continuity" do
    for easing <- @all_easings do
      test "#{easing} is continuous (small changes produce small outputs)" do
        step = 0.001
        max_jump = 0.05

        steps = for i <- 0..999, do: i * step
        values = Enum.map(steps, &Easing.apply(unquote(easing), &1))

        values
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [a, b] ->
          assert abs(b - a) < max_jump,
                 "#{unquote(easing)} has a discontinuity: jump of #{abs(b - a)}"
        end)
      end
    end
  end

  # ── Elastic easing overshoot ──

  describe "elastic easing overshoot" do
    test "in_elastic goes below 0.0 at some point" do
      values = for i <- 1..99, do: Easing.apply(:in_elastic, i / 100.0)
      assert Enum.any?(values, &(&1 < 0.0)), "in_elastic should overshoot below 0"
    end

    test "out_elastic goes above 1.0 at some point" do
      values = for i <- 1..99, do: Easing.apply(:out_elastic, i / 100.0)
      assert Enum.any?(values, &(&1 > 1.0)), "out_elastic should overshoot above 1"
    end

    test "in_out_elastic overshoots in both directions" do
      first_half = for i <- 1..49, do: Easing.apply(:in_out_elastic, i / 100.0)
      second_half = for i <- 51..99, do: Easing.apply(:in_out_elastic, i / 100.0)

      assert Enum.any?(first_half, &(&1 < 0.0)),
             "in_out_elastic should overshoot below 0 in first half"

      assert Enum.any?(second_half, &(&1 > 1.0)),
             "in_out_elastic should overshoot above 1 in second half"
    end
  end

  # ── Bounce easing ──

  describe "bounce easing" do
    test "out_bounce stays in [0, 1]" do
      for i <- 0..100 do
        t = i / 100.0
        v = Easing.apply(:out_bounce, t)
        assert v >= -1.0e-10, "out_bounce at #{t} went below 0: #{v}"
        assert v <= 1.0 + 1.0e-10, "out_bounce at #{t} went above 1: #{v}"
      end
    end

    test "in_bounce stays in [0, 1]" do
      for i <- 0..100 do
        t = i / 100.0
        v = Easing.apply(:in_bounce, t)
        assert v >= -1.0e-10, "in_bounce at #{t} went below 0: #{v}"
        assert v <= 1.0 + 1.0e-10, "in_bounce at #{t} went above 1: #{v}"
      end
    end

    test "in_out_bounce boundary values" do
      assert_in_delta Easing.apply(:in_out_bounce, 0.0), 0.0, 1.0e-10
      assert_in_delta Easing.apply(:in_out_bounce, 1.0), 1.0, 1.0e-10
      assert_in_delta Easing.apply(:in_out_bounce, 0.5), 0.5, 1.0e-10
    end
  end
end
