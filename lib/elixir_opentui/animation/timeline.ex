defmodule ElixirOpentui.Animation.Timeline do
  @moduledoc """
  Pure functional animation timeline.

  A Timeline holds a list of property animations. It advances forward in
  time via `advance/2`, producing interpolated values that components read
  via `value/2`.

  Timelines are plain structs stored in component state, no GenServer needed.
  """

  alias ElixirOpentui.Animation.Easing

  @type state :: :idle | :playing | :complete

  @type item :: %{
          property: atom(),
          from: number(),
          to: number(),
          easing: atom(),
          duration: non_neg_integer(),
          delay: non_neg_integer()
        }

  @type t :: %__MODULE__{
          duration: non_neg_integer(),
          items: [item()],
          state: state(),
          elapsed: float(),
          loop: boolean() | pos_integer(),
          alternate: boolean(),
          loop_count: non_neg_integer(),
          values: %{optional(atom()) => number()}
        }

  defstruct duration: 0,
            items: [],
            state: :idle,
            elapsed: 0.0,
            loop: false,
            alternate: false,
            loop_count: 0,
            values: %{}

  @doc "Create a new timeline. Options: `:duration`, `:loop`, `:alternate`."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      duration: Keyword.get(opts, :duration, 0),
      loop: Keyword.get(opts, :loop, false),
      alternate: Keyword.get(opts, :alternate, false)
    }
  end

  @doc "Add a property animation to the timeline."
  @spec add(t(), atom(), keyword()) :: t()
  def add(%__MODULE__{} = tl, property, opts \\ []) do
    item = %{
      property: property,
      from: Keyword.get(opts, :from, 0.0),
      to: Keyword.get(opts, :to, 1.0),
      easing: Keyword.get(opts, :ease, Keyword.get(opts, :easing, :linear)),
      duration: Keyword.get(opts, :duration, tl.duration),
      delay: Keyword.get(opts, :start_time, Keyword.get(opts, :delay, 0))
    }

    values = Map.put_new(tl.values, property, normalize(item.from + 0.0))
    maybe_derive_duration(%{tl | items: tl.items ++ [item], values: values})
  end

  @doc "Set the timeline to playing state. A completed timeline starts over."
  @spec play(t()) :: t()
  def play(%__MODULE__{state: :complete} = tl) do
    %{tl | state: :playing, elapsed: 0.0, loop_count: 0, values: %{}}
  end

  def play(%__MODULE__{} = tl), do: %{tl | state: :playing}

  @doc "Advance the timeline by `dt` milliseconds. Returns updated timeline."
  @spec advance(t(), number()) :: t()
  def advance(%__MODULE__{state: state} = tl, _dt) when state != :playing, do: tl

  def advance(%__MODULE__{} = tl, dt) when dt < 0, do: tl

  def advance(%__MODULE__{} = tl, dt) do
    new_elapsed = tl.elapsed + dt
    values = evaluate_items(tl.items, new_elapsed, tl.values)
    handle_completion(%{tl | values: values, elapsed: new_elapsed})
  end

  @doc "Get the current interpolated value for a property."
  @spec value(t(), atom()) :: number()
  def value(%__MODULE__{values: values}, property) do
    case Map.fetch(values, property) do
      {:ok, v} -> v
      :error -> raise ArgumentError, "unknown timeline property: #{inspect(property)}"
    end
  end

  @doc "Returns true when the timeline has completed (not looping)."
  @spec finished?(t()) :: boolean()
  def finished?(%__MODULE__{state: :complete}), do: true
  def finished?(_), do: false

  # --- Private helpers ---

  defp maybe_derive_duration(%{duration: 0, items: items} = tl) do
    max_end =
      items
      |> Enum.map(fn %{delay: delay, duration: dur} -> delay + dur end)
      |> Enum.max(fn -> 0 end)

    %{tl | duration: max_end}
  end

  defp maybe_derive_duration(tl), do: tl

  defp evaluate_items(items, elapsed, values) do
    Enum.reduce(items, values, &evaluate_item(&1, elapsed, &2))
  end

  defp evaluate_item(item, elapsed, values) do
    effective_elapsed = elapsed - item.delay

    if effective_elapsed < 0 do
      # Not started: only set the initial value when nothing else has set it
      Map.put_new(values, item.property, normalize(item.from + 0.0))
    else
      progress = clamp(effective_elapsed / max(item.duration, 1), 0.0, 1.0)
      eased = Easing.apply(item.easing, progress)
      Map.put(values, item.property, normalize(item.from + (item.to - item.from) * eased))
    end
  end

  defp handle_completion(%{elapsed: elapsed, duration: dur} = tl)
       when dur > 0 and elapsed >= dur do
    cond do
      tl.loop == true ->
        loop(tl)

      is_integer(tl.loop) and tl.loop_count + 1 < tl.loop ->
        loop(tl)

      true ->
        %{
          tl
          | state: :complete,
            elapsed: dur * 1.0,
            values: evaluate_items(tl.items, dur * 1.0, tl.values)
        }
    end
  end

  defp handle_completion(tl), do: tl

  defp loop(%{elapsed: elapsed, duration: dur} = tl) do
    overshoot = elapsed - dur

    items =
      if tl.alternate, do: Enum.map(tl.items, &%{&1 | from: &1.to, to: &1.from}), else: tl.items

    tl = %{tl | elapsed: 0.0, loop_count: tl.loop_count + 1, items: items}

    # Exact boundary: preserve values from the last frame
    if overshoot > 0, do: advance(%{tl | values: %{}}, overshoot), else: tl
  end

  defp clamp(v, lo, hi), do: max(lo, min(hi, v))

  defp normalize(v) when is_float(v) do
    r = round(v)
    if abs(v - r) < 1.0e-9, do: r, else: v
  end

  defp normalize(v), do: v
end
