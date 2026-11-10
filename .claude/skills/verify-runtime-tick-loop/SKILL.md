---
name: verify-runtime-tick-loop
description: "Check a change to the tick loop of ElixirOpentui.Runtime against its verified rules. Use when a change touches start, stop, request_live, drop_live, suspend, resume, the :tick handler, or the tick timer in lib/elixir_opentui/runtime.ex."
---

# Verify the Runtime tick loop

`ElixirOpentui.Runtime` runs a tick loop that drives animations.
Callers start, stop, suspend, and resume it, and a timer sends the `:tick` messages.
This skill checks three rules about that loop for every order of calls and timer expiry in a small model.

## The rules

| Rule | Plain sentence | Harm when it breaks |
|---|---|---|
| `SuspendedExactlyWhileSuspendCalls` | The runtime is suspended exactly while a `suspend` call has no `resume` yet. | Animations run while the app gave the terminal to another program. |
| `OneTickChain` | At most one tick is on the way at a time. | Ticks arrive two times as fast until the next stop. |
| `TicksWhenDue` | When ticks are wanted and the runtime is not suspended, a tick is on the way. | Animations stop until the next event. |

"Ticks are wanted" means `should_tick?/1` is true: some state has `_live`, a live reference exists, or `start/1` was the last explicit call.
"A tick on the way" means an armed timer, or a tick message of the current timer in the mailbox.

## Does your change touch the verified code

Run the check when your diff changes one of these parts of `lib/elixir_opentui/runtime.ex`.

| Code | Model action or operator in `RuntimeTick.tla` |
|---|---|
| `handle_call(:start_tick, ...)` | `HandleStart` |
| `handle_call(:stop_tick, ...)` | `HandleStop`, `StopUnlessWanted` |
| `handle_call(:request_live, ...)` | `HandleRequestLive` |
| `handle_call({:drop_live, ref}, ...)` | `HandleDropLive`, `StopUnlessWanted` |
| `handle_call(:suspend, ...)` | `HandleSuspend` |
| `handle_call(:resume, ...)` | `HandleResume` |
| `handle_info({:timeout, ref, :tick}, ...)`, `tick_all/2` | `HandleTick`, `HandleStaleTick` |
| `render_and_reconcile/1` and each handler that calls it | `HandleEvent` |
| `start_tick_loop/1` | `StartLoop` |
| `cancel_tick_timer/1` | `CancelTimer`, `WithStaleTick` |
| `stop_tick_loop/1` | `StopLoop` |
| `reconcile_tick_loop/1` | `Reconcile` |
| `schedule_tick/1`, `:erlang.start_timer/3` | `held = "armed"`, `orphans`, `TimerFires` |
| `should_tick?/1`, `any_live?/1` | `ShouldTick` |

Also run it when you add a handler that changes `control_state`, `suspend_count`, `live_refs`, `explicit_start`, or `tick_timer_ref`.
A change to rendering, layout, focus, or the agent actions does not touch the verified code.

Sync commit: `21ff604` (the verification described the code at this commit).
Run `git diff 21ff604 -- lib/elixir_opentui/runtime.ex` to see what changed after it.

## Run the check

```sh
verification/runtime_tick/check.sh
```

The run takes about 5 seconds.
It needs Java, `curl` for the first run, and a compiled project.
It downloads TLC 1.7.4 one time and checks the SHA-256 of the file.
Set `TLA2TOOLS_JAR` to use a local `tla2tools.jar`.

The script does two things.
First it checks each rule in the model `verification/runtime_tick/RuntimeTick.tla` with TLC.
Then it runs `test/elixir_opentui/runtime_tick_model_test.exs` against the real `Runtime` process.
That test applies every sequence of 4 calls.
It also checks that a stop and a start behind an expired tick timer leave one tick chain.
The replay test of each known finding goes in the same file with the tag `:known_finding`.

`verification/runtime_tick/expected.txt` records which rules hold and which rules break at the sync commit.
The script exits with 0 when the result is the same as that record.
A line with `<== CHANGED` shows a difference.

## Read a result

Read every model result with the `/statechart` skill.
Give it `RuntimeTick.tla`, `RuntimeTick.cfg`, and the view `verification/runtime_tick/view.mjs`.
It shows the shortest path to each rule break in plain words.

Then decide what a `CHANGED` line means.

1. **The real-code test fails on a rule that holds.**
   Your change broke the rule in the code.
   The failure message gives the shortest sequence of calls.
   This is a real bug, so correct the code.
2. **The model breaks a rule that the record says holds, after you changed the model.**
   Replay the path from `/statechart` against the real `Runtime`, one call for each step.
   Use `:sys.suspend/1` and `:sys.resume/1` to put calls in the mailbox in the order of the path.
   If the replay shows the break, it is a real bug.
   If the replay does not show the break, the model is wrong, so correct the model.
3. **A rule that the record says breaks now holds.**
   Your change corrected a known finding.
   See "Update the verification".

Never weaken a rule or the model to get a pass.

## Known findings at the sync commit

None. All three rules hold.

The first run of this check found two breaks, and the code has a guard for each one now.
Keep these guards when you change the code.

1. `TicksWhenDue` broke on `request_live/1`, then `stop/1`.
   `stop/1` stopped the loop although a live reference existed.
   The guard: `handle_call(:stop_tick, ...)` calls `stop_tick_loop/1` only when `should_tick?/1` is false.
2. `OneTickChain` broke when a `stop` and a `start` waited in the mailbox and the tick timer expired.
   `Process.cancel_timer/2` cannot remove a tick message that is already in the mailbox.
   That message started a second tick chain, and ticks came two times as fast.
   The guard: each tick message carries the reference of its timer, because `schedule_tick/1` uses `:erlang.start_timer/3`.
   The tick handler accepts only a message whose reference equals `tick_timer_ref`.
   In the model, `CancelTimer` marks the old message as `"stale"`, and `HandleStaleTick` drops it.

When the owner decides to keep a new finding open, give its replay test the tag `:known_finding`.
`test/test_helper.exs` excludes that tag, so `mix test` stays green.
Record the rule as `breaks` in `expected.txt`.

## Update the verification

When your change to the covered code is intended, do these steps in order.

1. Change the matching action or operator in `RuntimeTick.tla` to describe the new code. Use the table above.
2. Run the check.
3. If you corrected a known finding, change its line in `expected.txt` to `holds`. Remove the `:known_finding` tag from its test, so that `mix test` runs it.
4. If you added a new rule, add the invariant to `RuntimeTick.tla`, `RuntimeTick.cfg`, and `expected.txt`. Make the rule fail one time on a broken variant of the code, to prove that it can fail.
5. Confirm that each row of the table above still points to code that exists.
6. Only then change the sync commit in this file to the new commit.

## Scope

The model treats each `handle_call`, `handle_cast`, and `handle_info` as one step.
That is correct, because a GenServer handles one message at a time.

The bounds are small:

- At most 3 calls wait in the mailbox.
- At most 2 suspends are nested.
- At most 1 live reference exists.
- At most 1 timer exists without an owner.

A pass covers every order of events inside those bounds, not larger ones.
The real-code test covers every sequence of 4 calls, with no race between a call and the timer.

The model does not cover these things:

- The time between ticks, the `dt` value, and `last_tick_time`.
- What `update/3` and `render/1` do, other than a free choice of `_live` on each event and each tick.
- A crash in app code, and a restart of the process.
- `ElixirOpentui.DemoRunner`, which has its own loop and does not use `Runtime`.

For verification that is out of step after changes that did not run this check, use `/maintain-formal-verification-skill`.
