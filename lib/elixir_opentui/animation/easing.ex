defmodule ElixirOpentui.Animation.Easing do
  @moduledoc """
  Easing functions for animation curves.

  All functions take a progress float `t` in the range 0.0..1.0
  and return an eased value, typically also in 0.0..1.0 (some
  functions like `:in_back` and `:in_elastic` may overshoot).
  """

  import Kernel, except: [apply: 2]

  @spec apply(atom(), float()) :: float()

  def apply(:linear, t), do: t

  # Quadratic
  def apply(:in_quad, t), do: t * t
  def apply(:out_quad, t), do: 1.0 - (1.0 - t) * (1.0 - t)

  def apply(:in_out_quad, t) when t < 0.5, do: 2.0 * t * t
  def apply(:in_out_quad, t), do: 1.0 - (-2.0 * t + 2.0) ** 2 / 2.0

  # Cubic
  def apply(:in_cubic, t), do: t * t * t
  def apply(:out_cubic, t), do: 1.0 - (1.0 - t) ** 3

  def apply(:in_out_cubic, t) when t < 0.5, do: 4.0 * t * t * t
  def apply(:in_out_cubic, t), do: 1.0 - (-2.0 * t + 2.0) ** 3 / 2.0

  # Exponential
  def apply(:in_expo, t) when t <= 0.0, do: 0.0
  def apply(:in_expo, t) when t >= 1.0, do: 1.0
  def apply(:in_expo, t), do: :math.pow(2.0, 10.0 * t - 10.0)

  def apply(:out_expo, t) when t >= 1.0, do: 1.0
  def apply(:out_expo, t), do: 1.0 - :math.pow(2.0, -10.0 * t)

  def apply(:in_out_expo, t) when t <= 0.0, do: 0.0
  def apply(:in_out_expo, t) when t >= 1.0, do: 1.0

  def apply(:in_out_expo, t) when t < 0.5,
    do: :math.pow(2.0, 20.0 * t - 10.0) / 2.0

  def apply(:in_out_expo, t),
    do: (2.0 - :math.pow(2.0, -20.0 * t + 10.0)) / 2.0

  # Sine
  def apply(:in_sine, t), do: 1.0 - :math.cos(t * :math.pi() / 2.0)
  def apply(:out_sine, t), do: :math.sin(t * :math.pi() / 2.0)
  def apply(:in_out_sine, t), do: -((:math.cos(:math.pi() * t) - 1.0) / 2.0)

  # Circular
  def apply(:in_circ, t), do: 1.0 - :math.sqrt(1.0 - t * t)
  def apply(:out_circ, t), do: :math.sqrt(1.0 - (t - 1.0) ** 2)

  def apply(:in_out_circ, t) when t < 0.5,
    do: (1.0 - :math.sqrt(1.0 - (2.0 * t) ** 2)) / 2.0

  def apply(:in_out_circ, t),
    do: (:math.sqrt(1.0 - (-2.0 * t + 2.0) ** 2) + 1.0) / 2.0

  # Back (overshoot)
  @back_s 1.70158

  def apply(:in_back, t) do
    (@back_s + 1.0) * t * t * t - @back_s * t * t
  end

  def apply(:out_back, t) do
    t1 = t - 1.0
    1.0 + (@back_s + 1.0) * t1 * t1 * t1 + @back_s * t1 * t1
  end

  def apply(:in_out_back, t) when t < 0.5 do
    s = @back_s * 1.525
    (2.0 * t) ** 2 * ((s + 1.0) * 2.0 * t - s) / 2.0
  end

  def apply(:in_out_back, t) do
    s = @back_s * 1.525
    (2.0 * t - 2.0) ** 2 * ((s + 1.0) * (2.0 * t - 2.0) + s) / 2.0 + 1.0
  end

  # Elastic
  @elastic_c 2.0 * :math.pi() / 3.0

  def apply(:in_elastic, t) when t <= 0.0, do: 0.0
  def apply(:in_elastic, t) when t >= 1.0, do: 1.0

  def apply(:in_elastic, t) do
    -:math.pow(2.0, 10.0 * t - 10.0) * :math.sin((10.0 * t - 10.75) * @elastic_c)
  end

  def apply(:out_elastic, t) when t <= 0.0, do: 0.0
  def apply(:out_elastic, t) when t >= 1.0, do: 1.0

  def apply(:out_elastic, t) do
    :math.pow(2.0, -10.0 * t) * :math.sin((10.0 * t - 0.75) * @elastic_c) + 1.0
  end

  @elastic_c2 2.0 * :math.pi() / 4.5

  def apply(:in_out_elastic, t) when t <= 0.0, do: 0.0
  def apply(:in_out_elastic, t) when t >= 1.0, do: 1.0

  def apply(:in_out_elastic, t) when t < 0.5 do
    -(:math.pow(2.0, 20.0 * t - 10.0) * :math.sin((20.0 * t - 11.125) * @elastic_c2)) / 2.0
  end

  def apply(:in_out_elastic, t) do
    :math.pow(2.0, -20.0 * t + 10.0) * :math.sin((20.0 * t - 11.125) * @elastic_c2) / 2.0 +
      1.0
  end

  # Bounce
  def apply(:out_bounce, t) do
    cond do
      t < 1.0 / 2.75 ->
        7.5625 * t * t

      t < 2.0 / 2.75 ->
        t1 = t - 1.5 / 2.75
        7.5625 * t1 * t1 + 0.75

      t < 2.5 / 2.75 ->
        t1 = t - 2.25 / 2.75
        7.5625 * t1 * t1 + 0.9375

      true ->
        t1 = t - 2.625 / 2.75
        7.5625 * t1 * t1 + 0.984375
    end
  end

  def apply(:in_bounce, t) do
    1.0 - apply(:out_bounce, 1.0 - t)
  end

  def apply(:in_out_bounce, t) when t < 0.5 do
    (1.0 - apply(:out_bounce, 1.0 - 2.0 * t)) / 2.0
  end

  def apply(:in_out_bounce, t) do
    (1.0 + apply(:out_bounce, 2.0 * t - 1.0)) / 2.0
  end
end
