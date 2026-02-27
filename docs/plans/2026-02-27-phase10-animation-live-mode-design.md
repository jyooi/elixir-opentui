# Phase 10: Animation & Live Mode — Design Document

> Date: 2026-02-27
> Status: Approved
> Upstream Reference: OpenTUI v0.1.84 (`packages/core/src/animation/Timeline.ts`, `renderer.ts`)

---

## Overview

Add three capabilities to ElixirOpentui:
1. **Timeline API** — functional animation engine with easing, looping, alternation, nested timelines
2. **Continuous render mode** — tick-based render loop in Runtime with configurable FPS
3. **Pause/resume/suspend** — terminal state management for shell-out scenarios

## Architecture Decisions

### Functional timelines, no GenServer engine

Timelines are pure structs stored in component state. No singleton engine process.
Runtime broadcasts `{:tick, dt}` to all mounted components. Components that don't
care about ticks have a catch-all clause — zero cost.

### 3-state FSM

```
:idle ←→ :running ←→ :suspended
```

- `:idle` — event-driven only (current behavior, default)
- `:running` — tick loop active at target FPS
- `:suspended` — tick loop stopped, terminal left raw mode

### `_live` flag convention

Components set `%{state | _live: true}` when animating, clear it when done.
Runtime checks all component states after each tick. When no `_live: true` flags
exist and no explicit `start/1`, transitions `:running` → `:idle`.

Mirrors the existing `_pending` pattern for component-to-app messaging.

### Wall-clock dt, graceful degradation

Delta time is wall-clock based. If a frame takes >33ms at 30fps target,
next tick fires with `delay = max(1, target - elapsed)`. Effective FPS drops
naturally. No fixed timestep, no frame skipping.

### Replace interruption policy

Starting a new animation on the same property replaces the current one.
New animation's `from` starts at the current interpolated value.

### Animatable properties in v1

App-interpreted only. Timeline produces float values via `Timeline.value/2`.
Components use floats in `render/1` as: opacity (natively supported), position
offsets, toggle thresholds. No framework-level color interpolation in v1.

---

## Component Integration

### Pseudocode: Animated component

```elixir
defmodule FadeInPanel do
  use ElixirOpentui.Component
  alias ElixirOpentui.Animation.Timeline

  def init(_props) do
    tl = Timeline.new(duration: 300)
         |> Timeline.add(:opacity, from: 0.0, to: 1.0, easing: :ease_out)
         |> Timeline.play()
    %{timeline: tl, _live: true}
  end

  def update({:tick, dt}, _event, state) do
    tl = Timeline.advance(state.timeline, dt)
    %{state | timeline: tl, _live: not Timeline.finished?(tl)}
  end

  # Interruption: replace with new animation from current value
  def update(:toggle, _event, state) do
    current = Timeline.value(state.timeline, :opacity)
    target = if current > 0.5, do: 0.0, else: 1.0
    tl = Timeline.new(duration: 300)
         |> Timeline.add(:opacity, from: current, to: target, easing: :ease_in_out)
         |> Timeline.play()
    %{state | timeline: tl, _live: true}
  end

  def update(_, _, state), do: state

  def render(state) do
    import ElixirOpentui.View
    opacity = Timeline.value(state.timeline, :opacity)
    box opacity: opacity do
      text(content: "Hello!")
    end
  end
end
```

### Tick delivery in Runtime

```elixir
defp handle_tick(state, dt) do
  # Tick app module
  new_app_state = state.app_module.update({:tick, dt}, nil, state.app_state)
  state = %{state | app_state: new_app_state}

  # Tick all mounted components
  new_comp_states = Map.new(state.component_states, fn {id, comp} ->
    new_comp_state = comp.module.update({:tick, dt}, nil, comp.state)
    {id, %{comp | state: new_comp_state}}
  end)

  %{state | component_states: new_comp_states}
end
```

### DemoRunner integration

Optional `handle_tick/2` callback. DemoRunner reads `Map.get(state, :_live, false)`
to switch between event-driven (`after :infinity`) and tick-based (`after ~33ms`).

---

## Module Design

### `ElixirOpentui.Animation.Timeline` (~220 LOC)

Pure functional struct. No side effects.

```elixir
%Timeline{
  duration: non_neg_integer(),     # total ms
  items: [item()],                 # animation/callback/sync items
  state: :idle | :playing | :paused | :complete,
  elapsed: float(),                # current position in ms
  loop: boolean() | pos_integer(), # true = infinite, integer = count
  alternate: boolean(),            # reverse on alternate loops
  loop_count: non_neg_integer(),   # current loop iteration
  auto_play: boolean(),
  values: %{atom() => float()},    # current interpolated values
  on_start: fun() | nil,
  on_complete: fun() | nil,
  on_loop: fun() | nil,
  on_update: fun() | nil
}
```

**Item types:**
- Animation: `%{type: :animation, property: atom, from: float, to: float, easing: atom, duration: integer, delay: integer, loop: ...}`
- Callback: `%{type: :callback, at: integer, fun: fun(), fired: boolean}`
- Sync: `%{type: :sync, timeline: Timeline.t()}`

**Public API:**
- `new(opts)` — create timeline
- `add(tl, property, opts)` — add property animation
- `call(tl, at, fun)` — add callback at time position
- `sync(tl, child_timeline)` — add nested timeline
- `play(tl)` — start playing
- `pause(tl)` — pause
- `restart(tl)` — reset and play
- `advance(tl, dt)` — advance by dt milliseconds, returns new timeline
- `value(tl, property)` — get current interpolated value
- `finished?(tl)` — true when complete (not looping)

### `ElixirOpentui.Animation.Easing` (~90 LOC)

16 pure easing functions matching upstream:

```
linear, in_quad, out_quad, in_out_quad,
in_expo, out_expo, in_out_expo,
in_sine, out_sine, in_out_sine,
in_bounce, out_bounce, in_out_bounce,
in_circ, out_circ, in_out_circ
```

Plus parameterized: `in_back/1`, `out_back/1`, `in_out_back/1`, `in_elastic/1`, `out_elastic/1`

All: `(float) -> float` where input/output are 0.0..1.0 progress.

### Runtime modifications (~80 LOC)

New state fields:
```elixir
control_state: :idle,          # FSM state
target_fps: 30,                # configurable
target_frame_time: 33,         # 1000 / target_fps
last_tick_time: 0,             # monotonic ms
live_request_count: 0,         # ref counter
explicit_start: false          # explicit start() was called
```

New public API:
- `start(server)` — explicit start, transitions to :running
- `stop(server)` — explicit stop, transitions to :idle
- `request_live(server)` — increment live counter, auto-start if idle
- `drop_live(server)` — decrement live counter, auto-stop if 0
- `suspend(server)` — transition to :suspended
- `resume(server)` — restore prior state

New `handle_info(:tick, state)`:
```
now = monotonic_time()
dt = now - last_tick_time
state = handle_tick(state, dt)     # advance all components
state = do_render(state)           # full pipeline
if not any_live?(state) and not explicit_start:
  transition to :idle
else:
  elapsed = monotonic_time() - now
  delay = max(1, target_frame_time - elapsed)
  Process.send_after(self(), :tick, delay)
```

### Terminal modifications (~30 LOC)

New functions:
- `suspend(server)` — calls leave internally, saves state
- `resume(server)` — calls enter internally, restores state

### DemoRunner modifications (~20 LOC)

- Read `_live` flag from demo state
- Dynamic `after` timeout: `:infinity` when not live, `~33ms` when live
- Call `handle_tick/2` on demo module when ticking

---

## Implementation Order

1. `Animation.Easing` — pure functions, no dependencies
2. `Animation.Timeline` — pure struct, depends on Easing
3. Runtime tick loop — depends on Timeline for integration testing
4. Terminal suspend/resume — independent, can parallel with #3
5. DemoRunner tick support — depends on #3
6. Demo script — depends on all above

---

## Test Plan

| Test file | Count | Focus |
|-----------|-------|-------|
| `animation/easing_test.exs` | ~80 | All 16 easing curves, boundary values |
| `animation/timeline_test.exs` | ~150 | Ported from upstream's 150+ test cases |
| `runtime_tick_test.exs` | ~30 | FSM transitions, tick delivery, _live flag |
| `terminal_suspend_test.exs` | ~10 | Suspend/resume state management |
| Integration in existing tests | ~10 | Ensure no regressions |

Total new tests: ~280

---

## Risks

- **Pipeline performance at 30fps**: Unknown. NIF backend should be fine.
  Pure Elixir backend may struggle with large trees. Mitigation: profile
  after implementation, optimize hot paths, consider dirty-scheduling paint.
- **Nested timeline timing precision**: Complex looping + alternation +
  nested sync has subtle edge cases. Mitigated by porting upstream's
  precision test suite.
