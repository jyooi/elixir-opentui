defmodule ElixirOpentui.Animation.Timeline do
  @moduledoc """
  Pure functional animation timeline.

  A Timeline holds a list of animation items, callbacks, and nested timelines.
  It advances forward in time via `advance/2`, producing interpolated values
  that components read via `value/2`.

  Timelines are plain structs stored in component state — no GenServer needed.
  """

  alias ElixirOpentui.Animation.Easing

  @type state :: :idle | :playing | :paused | :complete

  @type item ::
          %{
            type: :animation,
            property: atom(),
            from: float(),
            to: float(),
            easing: atom(),
            duration: non_neg_integer(),
            delay: non_neg_integer(),
            loop: boolean() | pos_integer(),
            alternate: boolean(),
            loop_count: non_neg_integer()
          }
          | %{
              type: :callback,
              at: non_neg_integer(),
              fun: (-> any()),
              fired: boolean()
            }
          | %{
              type: :sync,
              timeline: t()
            }

  @type t :: %__MODULE__{
          duration: non_neg_integer(),
          items: [item()],
          state: state(),
          elapsed: float(),
          loop: boolean() | pos_integer(),
          alternate: boolean(),
          loop_count: non_neg_integer(),
          auto_play: boolean(),
          values: %{optional(atom()) => float()},
          on_start: (-> any()) | nil,
          on_complete: (-> any()) | nil,
          on_loop: (-> any()) | nil,
          on_update: (-> any()) | nil,
          started: boolean()
        }

  defstruct duration: 0,
            items: [],
            state: :idle,
            elapsed: 0.0,
            loop: false,
            alternate: false,
            loop_count: 0,
            auto_play: true,
            values: %{},
            on_start: nil,
            on_complete: nil,
            on_loop: nil,
            on_update: nil,
            on_pause: nil,
            started: false

  @doc "Create a new timeline with optional configuration."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      duration: Keyword.get(opts, :duration, 0),
      loop: Keyword.get(opts, :loop, false),
      alternate: Keyword.get(opts, :alternate, false),
      auto_play: Keyword.get(opts, :auto_play, true),
      on_start: Keyword.get(opts, :on_start),
      on_complete: Keyword.get(opts, :on_complete),
      on_loop: Keyword.get(opts, :on_loop),
      on_update: Keyword.get(opts, :on_update),
      on_pause: Keyword.get(opts, :on_pause)
    }
  end

  @doc "Add a property animation to the timeline."
  @spec add(t(), atom(), keyword()) :: t()
  def add(%__MODULE__{} = tl, property, opts \\ []) do
    item = build_animation_item(tl, property, opts)
    values = Map.put_new(tl.values, property, normalize(item.from + 0.0))
    tl = %{tl | items: tl.items ++ [item], values: values}
    maybe_derive_duration(tl)
  end

  defp build_animation_item(tl, property, opts) do
    %{
      type: :animation,
      property: property,
      from: Keyword.get(opts, :from, 0.0),
      to: Keyword.get(opts, :to, 1.0),
      easing: Keyword.get(opts, :ease, Keyword.get(opts, :easing, :linear)),
      duration: Keyword.get(opts, :duration, tl.duration),
      delay: Keyword.get(opts, :start_time, Keyword.get(opts, :delay, 0)),
      loop: Keyword.get(opts, :loop, false),
      alternate: Keyword.get(opts, :alternate, false),
      loop_delay: Keyword.get(opts, :loop_delay, 0),
      loop_count: 0,
      on_start: Keyword.get(opts, :on_start),
      on_complete: Keyword.get(opts, :on_complete),
      on_loop: Keyword.get(opts, :on_loop),
      on_update: Keyword.get(opts, :on_update),
      once: false,
      started: false,
      completed: false,
      prev_elapsed: 0.0
    }
  end

  @doc "Add a callback that fires when the timeline reaches `at` milliseconds."
  def call(%__MODULE__{} = tl, at, fun) when is_integer(at) and is_function(fun, 0) do
    item = %{type: :callback, at: at, fun: fun, fired: false}
    tl = %{tl | items: tl.items ++ [item]}
    maybe_derive_duration(tl)
  end

  def call(%__MODULE__{} = tl, at, fun) when is_integer(at) and is_function(fun, 1) do
    wrapper = fn -> fun.(%{elapsed: at}) end
    call(tl, at, wrapper)
  end

  # Support (fun, at) arg order (upstream TypeScript convention)
  def call(%__MODULE__{} = tl, fun, at) when is_function(fun) and is_integer(at) do
    call(tl, at, fun)
  end

  @doc "Add a nested (synced) child timeline at a given start offset."
  def sync(%__MODULE__{} = tl, %__MODULE__{} = child, start_at) when is_number(start_at) do
    item = %{type: :sync, timeline: child, start_at: start_at}
    tl = %{tl | items: tl.items ++ [item]}
    maybe_derive_duration(tl)
  end

  @doc "Add a nested (synced) child timeline."
  def sync(%__MODULE__{} = tl, %__MODULE__{} = child) do
    sync(tl, child, 0)
  end

  @doc "Add a one-shot animation that plays from the current elapsed position. Not reset on loop."
  def once(%__MODULE__{} = tl, property, opts \\ []) do
    opts = Keyword.put_new(opts, :start_time, trunc(tl.elapsed))
    item = build_animation_item(tl, property, opts)
    item = Map.put(item, :once, true)
    values = Map.put_new(tl.values, property, normalize(item.from + 0.0))
    %{tl | items: tl.items ++ [item], values: values}
  end

  @doc "Get the current elapsed time, clamped to duration for non-looping timelines."
  def current_time(%__MODULE__{state: :idle}), do: 0

  def current_time(%__MODULE__{loop: loop, elapsed: elapsed, duration: dur}) when loop != false do
    if dur > 0, do: :erlang.float(rem(trunc(elapsed), dur)), else: 0.0
  end

  def current_time(%__MODULE__{elapsed: elapsed, duration: dur}) do
    min(elapsed, dur * 1.0)
  end

  @doc "Set the timeline to playing state."
  @spec play(t()) :: t()
  def play(%__MODULE__{state: :complete} = tl), do: restart(tl)

  def play(%__MODULE__{} = tl) do
    tl = %{tl | state: :playing}
    play_synced_children(tl)
  end

  @doc "Pause the timeline."
  @spec pause(t()) :: t()
  def pause(%__MODULE__{} = tl) do
    tl = %{tl | state: :paused}
    tl = pause_synced_children(tl)
    if tl.on_pause, do: tl.on_pause.()
    tl
  end

  @doc "Reset elapsed to 0 and set to playing."
  @spec restart(t()) :: t()
  def restart(%__MODULE__{} = tl) do
    items = Enum.map(tl.items, &reset_item/1)

    %{
      tl
      | state: :playing,
        elapsed: 0.0,
        loop_count: 0,
        items: items,
        started: false,
        values: %{}
    }
  end

  @doc "Advance the timeline by `dt` milliseconds. Returns updated timeline."
  @spec advance(t(), number()) :: t()
  def advance(%__MODULE__{state: state} = tl, _dt) when state != :playing, do: tl

  def advance(%__MODULE__{} = tl, dt) when dt < 0, do: tl

  def advance(%__MODULE__{} = tl, dt) do
    tl = maybe_fire_on_start(tl)
    new_elapsed = tl.elapsed + dt

    # Evaluate all items at new elapsed time (pass dt for on_update delta_time)
    {items, values} = evaluate_items(tl.items, new_elapsed, tl.values, dt)
    tl = %{tl | items: items, values: values, elapsed: new_elapsed}

    # Fire on_update callback
    tl = maybe_fire_on_update(tl)

    # Handle timeline completion / looping
    handle_completion(tl)
  end

  @doc "Get the current interpolated value for a property."
  @spec value(t(), atom()) :: float()
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

  @doc "Returns true when the timeline is currently playing."
  @spec playing?(t()) :: boolean()
  def playing?(%__MODULE__{state: :playing}), do: true
  def playing?(_), do: false

  # --- Private helpers ---

  defp maybe_derive_duration(%{duration: 0, items: items} = tl) do
    max_end =
      items
      |> Enum.map(&item_end_time/1)
      |> Enum.max(fn -> 0 end)

    %{tl | duration: max_end}
  end

  defp maybe_derive_duration(tl), do: tl

  defp item_end_time(%{type: :animation, delay: delay, duration: dur}), do: delay + dur
  defp item_end_time(%{type: :callback, at: at}), do: at

  defp item_end_time(%{type: :sync, timeline: child, start_at: start_at}),
    do: start_at + child.duration

  defp item_end_time(%{type: :sync, timeline: child}), do: child.duration
  defp item_end_time(_), do: 0

  defp evaluate_items(items, elapsed, values, dt) do
    Enum.map_reduce(items, values, fn item, acc_values ->
      evaluate_item(item, elapsed, acc_values, dt)
    end)
  end

  defp evaluate_item(
         %{type: :animation, once: true, completed: true} = item,
         _elapsed,
         values,
         _dt
       ) do
    {item, values}
  end

  defp evaluate_item(%{type: :animation} = item, elapsed, values, dt) do
    effective_elapsed = elapsed - item.delay

    if effective_elapsed < 0 do
      # Not started — only set initial value if no other animation is actively setting it
      values = Map.put_new(values, item.property, normalize(item.from + 0.0))
      {item, values}
    else
      # Fire per-animation on_start callback
      item =
        if not Map.get(item, :started, false) do
          if item.on_start, do: item.on_start.()
          Map.put(item, :started, true)
        else
          item
        end

      prev_loop_count = item.loop_count
      {progress, item, direction} = compute_animation_progress(item, effective_elapsed)

      # Check if animation is done (non-looping at end, or finite loops exhausted)
      animation_done =
        cond do
          Map.get(item, :completed, false) -> false
          not should_loop_animation?(item) and progress >= 1.0 -> true
          is_integer(item.loop) and item.loop_count >= item.loop -> true
          true -> false
        end

      # Fire per-animation on_loop callback (but not on the final completion cycle)
      if not animation_done and item.loop_count > prev_loop_count and item.on_loop do
        for _ <- 1..(item.loop_count - prev_loop_count), do: item.on_loop.()
      end

      # Interpolation: direction handles alternation (swap from/to on odd cycles)
      eased = Easing.apply(item.easing, progress)

      {interp_from, interp_to} =
        if item.alternate and rem(direction, 2) == 1 do
          {item.to, item.from}
        else
          {item.from, item.to}
        end

      interpolated = normalize(interp_from + (interp_to - interp_from) * eased)
      values = Map.put(values, item.property, interpolated)

      # Fire on_update BEFORE marking completion (so last frame gets an update)
      item =
        if item.on_update != nil and not Map.get(item, :completed, false) do
          item.on_update.(%{
            delta_time: normalize(round(dt)),
            elapsed: normalize(round(effective_elapsed)),
            current_time: normalize(round(elapsed)),
            progress: normalize(progress),
            value: interpolated
          })

          item
        else
          item
        end

      item =
        if animation_done do
          if item.on_complete, do: item.on_complete.()
          Map.put(item, :completed, true)
        else
          item
        end

      {item, values}
    end
  end

  defp evaluate_item(
         %{type: :callback, fired: false, at: at, fun: fun} = item,
         elapsed,
         values,
         _dt
       )
       when elapsed >= at do
    fun.()
    {%{item | fired: true}, values}
  end

  defp evaluate_item(%{type: :callback} = item, _elapsed, values, _dt) do
    {item, values}
  end

  defp evaluate_item(%{type: :sync, timeline: child} = item, elapsed, values, _dt) do
    start_at = Map.get(item, :start_at, 0)
    effective_elapsed = elapsed - start_at

    if effective_elapsed < 0 do
      # Not started — still merge child's initial values (from-values)
      merged_values = Map.merge(values, child.values)
      {item, merged_values}
    else
      # Auto-play child if it hasn't started yet
      child = if child.state == :idle and child.auto_play, do: play(child), else: child

      if child.state == :playing do
        child_target =
          if child.loop,
            do: effective_elapsed * 1.0,
            else: min(effective_elapsed, child.duration * 1.0)

        dt = max(child_target - child.elapsed, 0)
        new_child = advance(child, dt)
        merged_values = Map.merge(values, new_child.values)
        {%{item | timeline: new_child}, merged_values}
      else
        # Even if child is paused/complete, keep its values visible
        merged_values = Map.merge(values, child.values)
        {item, merged_values}
      end
    end
  end

  defp compute_animation_progress(item, effective_elapsed) do
    dur = max(item.duration, 1)
    loop_delay = Map.get(item, :loop_delay, 0)
    cycle = dur + loop_delay

    if should_loop_animation?(item) and effective_elapsed >= dur do
      # Check finite loop exhaustion first
      if is_integer(item.loop) do
        n = item.loop
        exhaustion_time = (n - 1) * cycle + dur

        if effective_elapsed >= exhaustion_time do
          # All loops done — clamp at final value with correct direction
          direction = n - 1
          {1.0, %{item | loop_count: n}, direction}
        else
          compute_looping_progress(item, effective_elapsed, dur, cycle, loop_delay)
        end
      else
        compute_looping_progress(item, effective_elapsed, dur, cycle, loop_delay)
      end
    else
      progress = clamp(effective_elapsed / dur, 0.0, 1.0)
      {progress, item, 0}
    end
  end

  defp compute_looping_progress(item, effective_elapsed, dur, cycle, loop_delay) do
    loop_count = if cycle > 0, do: trunc(effective_elapsed / cycle), else: 0
    remaining = effective_elapsed - loop_count * cycle
    item = %{item | loop_count: loop_count}

    cond do
      remaining == 0 and loop_count > 0 ->
        # Exact cycle boundary — show end of previous cycle
        direction = loop_count - 1
        {1.0, item, direction}

      remaining >= dur and loop_delay > 0 ->
        # In the delay gap between runs — hold at end value
        direction = loop_count
        {1.0, item, direction}

      true ->
        direction = loop_count
        raw_progress = clamp(remaining / dur, 0.0, 1.0)
        {raw_progress, item, direction}
    end
  end

  defp should_loop_animation?(%{loop: false}), do: false
  defp should_loop_animation?(%{loop: _}), do: true

  defp handle_completion(%{elapsed: elapsed, duration: dur} = tl)
       when dur > 0 and elapsed >= dur do
    cond do
      tl.loop == true ->
        # Infinite loop
        overshoot = elapsed - dur
        items = Enum.map(tl.items, &reset_item/1)

        if overshoot > 0 do
          once_values = collect_once_values(tl)

          tl = %{
            tl
            | elapsed: 0.0,
              loop_count: tl.loop_count + 1,
              items: items,
              started: false,
              values: once_values
          }

          maybe_fire_on_loop(tl) |> advance(overshoot)
        else
          # Exact boundary — preserve values from last frame, just reset items for next loop
          tl = %{tl | elapsed: 0.0, loop_count: tl.loop_count + 1, items: items, started: false}
          maybe_fire_on_loop(tl)
        end

      is_integer(tl.loop) and tl.loop_count + 1 < tl.loop ->
        # Finite loop, not yet exhausted
        overshoot = elapsed - dur
        items = Enum.map(tl.items, &reset_item/1)

        if overshoot > 0 do
          once_values = collect_once_values(tl)

          tl = %{
            tl
            | elapsed: 0.0,
              loop_count: tl.loop_count + 1,
              items: items,
              started: false,
              values: once_values
          }

          maybe_fire_on_loop(tl) |> advance(overshoot)
        else
          tl = %{tl | elapsed: 0.0, loop_count: tl.loop_count + 1, items: items, started: false}
          maybe_fire_on_loop(tl)
        end

      true ->
        # Complete
        tl = %{tl | state: :complete, elapsed: dur * 1.0}
        {items, values} = evaluate_items(tl.items, dur * 1.0, tl.values, 0)
        tl = %{tl | items: items, values: values}
        maybe_fire_on_complete(tl)
    end
  end

  defp handle_completion(tl), do: tl

  defp reset_item(%{type: :animation, once: true} = item) do
    # Once-animations survive timeline loops — don't reset
    item
  end

  defp reset_item(%{type: :animation} = item) do
    %{item | loop_count: 0, started: false, completed: false, prev_elapsed: 0.0}
  end

  defp reset_item(%{type: :callback} = item) do
    %{item | fired: false}
  end

  defp reset_item(%{type: :sync, timeline: child} = item) do
    # Reset child to idle so auto_play can re-trigger
    items = Enum.map(child.items, &reset_item/1)

    child = %{
      child
      | state: :idle,
        elapsed: 0.0,
        loop_count: 0,
        items: items,
        started: false,
        values: %{}
    }

    %{item | timeline: child}
  end

  defp reset_item(item), do: item

  defp collect_once_values(tl) do
    Enum.reduce(tl.items, %{}, fn
      %{type: :animation, once: true, property: prop}, acc ->
        case Map.get(tl.values, prop) do
          nil -> acc
          val -> Map.put(acc, prop, val)
        end

      _, acc ->
        acc
    end)
  end

  defp play_synced_children(%{items: items} = tl) do
    items =
      Enum.map(items, fn
        %{type: :sync, timeline: child} = item -> %{item | timeline: play(child)}
        item -> item
      end)

    %{tl | items: items}
  end

  defp pause_synced_children(%{items: items} = tl) do
    items =
      Enum.map(items, fn
        %{type: :sync, timeline: child} = item -> %{item | timeline: pause(child)}
        item -> item
      end)

    %{tl | items: items}
  end

  defp maybe_fire_on_start(%{started: true} = tl), do: tl

  defp maybe_fire_on_start(%{on_start: nil} = tl), do: %{tl | started: true}

  defp maybe_fire_on_start(%{on_start: fun} = tl) do
    fun.()
    %{tl | started: true}
  end

  defp maybe_fire_on_complete(%{on_complete: nil} = tl), do: tl

  defp maybe_fire_on_complete(%{on_complete: fun} = tl) do
    fun.()
    tl
  end

  defp maybe_fire_on_loop(%{on_loop: nil} = tl), do: tl

  defp maybe_fire_on_loop(%{on_loop: fun} = tl) do
    fun.()
    tl
  end

  defp maybe_fire_on_update(%{on_update: nil} = tl), do: tl

  defp maybe_fire_on_update(%{on_update: fun} = tl) when is_function(fun, 0) do
    fun.()
    tl
  end

  defp maybe_fire_on_update(%{on_update: fun} = tl) when is_function(fun, 1) do
    fun.(%{elapsed: tl.elapsed, values: tl.values})
    tl
  end

  defp clamp(v, lo, hi), do: max(lo, min(hi, v))

  defp normalize(v) when is_float(v) do
    r = round(v)
    if abs(v - r) < 1.0e-9, do: r, else: v
  end

  defp normalize(v), do: v
end
