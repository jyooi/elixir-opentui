---
name: verify-runtime-tick-loop
description: Model-check the tick loop of ElixirOpentui.Runtime with TLC, and add the state chart file of each PR. Use when a change touches lib/elixir_opentui/runtime.ex, when you open a PR, or when elixir scripts/check_verification.exs fails.
---

# Verify the Runtime tick loop

`ElixirOpentui.Runtime` runs a tick loop that drives animations.
Callers start, stop, suspend, and resume it, and a timer sends the tick messages.
`RuntimeTick.tla` is a TLA+ model of that loop.
TLC checks three rules about the loop for every order of calls and timer expiry within the bounds below.

## Why this target and this tool

The tick loop is the code in this repository with the most behavior that moves between states.
It has three loop states, nested suspends, live references, `_live` states, and a timer whose message can wait behind calls.
Its bugs come from orders of calls and timer expiry that unit tests rarely reach.
The first run of the model found two such bugs, and a replay against the real process confirmed each one.

Two other areas were candidates:

- The Zig NIF text engine, where a memory fault stops the VM. A model of call orders does not answer that question, and no verifier for Zig code runs in this repository.
- `ElixirOpentui.Input.parse/1`. Tests with generated input fit a parser better than a model of states.

The question for the tick loop is whether events can occur in a bad order.
A model checker over a small model answers that question at the lowest cost, so the tool is TLA+ with TLC.
TLC 1.7.4 is one pinned jar file that needs only Java.
The real-code test `test/elixir_opentui/runtime_tick_model_test.exs` connects the model to the real `Runtime` process.

## Run the check

```sh
elixir scripts/check_verification.exs
```

The check needs Java 11 or later, `curl`, `git`, and a project that `mix test` can compile.
The first run downloads TLC 1.7.4 into `~/.cache/tla2tools/1.7.4/`, or into `$XDG_CACHE_HOME/tla2tools/1.7.4/` when that variable is set.
The check compares the SHA-256 of the jar file with `record.json` on each run.
The `Verify` step of `.github/workflows/ci.yml` runs the same command on each PR.
The test command of `.no-mistakes.yaml` runs it after `mix test`.

The check fails in each of these cases, and it names the cause:

1. This skill or `record.json` is missing.
2. A verified file changed, and its SHA-256 in `record.json` did not. The verified files are each covered file, `RuntimeTick.tla`, and `RuntimeTick.cfg`.
3. TLC finds a violation of a property with the status `holds`, or a recorded finding no longer breaks.
4. TLC does not catch the recorded break of a property with the status `holds`.
5. The real-code test fails.
6. The change adds or changes no state chart file with the name of the branch.
7. A state chart file has no Mermaid chart and no "No state change" note.
8. A state chart file has a Mermaid chart, and no SVG image is beside it.
9. The SVG image names a chart digest that is not the digest of the chart text.

The check finds the change from the merge base of `HEAD` and `origin/main` to `HEAD`.
It reads the committed chart files, so commit the chart file and its image before you run it.
It does not check cases 6 to 9 when `HEAD` has no change from `origin/main`, for example on `main`.
In CI, the check gets the branch name from `GITHUB_HEAD_REF`.
On a detached `HEAD` with no branch name, the check accepts any chart file that the change adds or changes.

## Tell if a change touches verified code

`record.json` lists each covered file, the functions in it, and its SHA-256.
The check compares the full file, so any edit of `lib/elixir_opentui/runtime.ex` stops the check until you confirm the model.
For an edit that the table below does not name, confirm that the model does not change, and record the new digest.

| Code in `lib/elixir_opentui/runtime.ex` | Action or operator in `RuntimeTick.tla` |
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

Also look for new code that changes the same state in other places.
Examples are a new handler that changes `control_state`, `suspend_count`, `live_refs`, `explicit_start`, or `tick_timer_ref`, and a new sender of tick messages.
A change to rendering, layout, focus, or the agent actions does not change what the model describes.

## Properties

"Ticks are wanted" means that `should_tick?/1` is true.
Then `start/1` was the last explicit call, a live reference exists, or a state has `_live: true`.
"A tick on the way" means an armed timer, or a tick message of the current timer in the mailbox.

| Property | Status | Rule in plain words | Harm when it breaks |
|---|---|---|---|
| `SuspendedExactlyWhileSuspendCalls` | holds | The runtime is suspended exactly while a `suspend` call has no `resume` yet. | Animations run while the app gives the terminal to another program. |
| `OneTickChain` | holds | At most one tick is on the way at a time. | Ticks arrive two times as fast until the next stop. |
| `TicksWhenDue` | holds | When ticks are wanted and the runtime is not suspended, a tick is on the way. | Animations stop until the next event. |

A property can have the status `finding`.
It then breaks on the current code, the check expects it to break, and the check fails when it stops breaking.
No property has this status now.

Each property with the status `holds` has a recorded break in `record.json`.
The `code` field says which change of the real code the break stands for.
The check applies the break to a copy of the model in a temporary folder, and TLC must find the violation.
The break never changes a file in the repository.

| Property | Recorded break in the words of the code |
|---|---|
| `SuspendedExactlyWhileSuspendCalls` | `start_tick_loop/1` starts the loop when `suspend_count` is above 0. |
| `OneTickChain` | The tick handler accepts a tick message of a cancelled timer. |
| `TicksWhenDue` | `handle_call(:stop_tick, ...)` calls `stop_tick_loop/1` also when `should_tick?/1` is true. |

## Known findings

None. All three rules hold.

The first run of the model found two breaks, and the code has a guard for each one now.
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

When the owner decides to keep a new finding open, do these steps:

1. Set the status of the property to `finding` in `record.json`, and remove its break.
2. Add a replay test of the finding to `test/elixir_opentui/runtime_tick_model_test.exs` with the tag `:known_finding`.
   `test/test_helper.exs` excludes that tag, so `mix test` and the check stay green.

## Read a result

Read every TLC result with the `/statechart` skill.
Give it `RuntimeTick.tla`, `RuntimeTick.cfg`, and the view `view.mjs` from this folder.
For a property that breaks, it gives the shortest path in plain words.

Then decide what the failure means.

1. **The real-code test fails on a property that holds.**
   Your change broke the rule in the code.
   The failure message gives a sequence of calls that breaks the rule. It is not always the shortest one.
   This is a real bug, so correct the code.
2. **TLC breaks a property that holds, after you changed the model.**
   Replay the path against the real `Runtime`, with one call for each step.
   Use `:sys.suspend/1` and `:sys.resume/1` to put calls in the mailbox in the order of the path.
   If the replay shows the break, report it as a real bug in the words of the code.
   If a step of the path cannot occur in the code, the model is wrong. Correct the model, and say what was wrong.
3. **TLC does not catch a recorded break.**
   The property cannot fail on the model, so correct the model or the property.
4. **A recorded finding no longer breaks.**
   Your change corrected the finding. See "Update the verification for an intended change".

Never weaken a property or the model to get a pass.

## Update the verification for an intended change

1. Read the diff of `lib/elixir_opentui/runtime.ex`, and decide if the change alters what the model describes.
2. Change `RuntimeTick.tla` and the table in "Tell if a change touches verified code" from the code, before you run the check. Keep one GenServer message as one action.
3. Change a property only when the promise changed on purpose. Cite the evidence, such as a test, a doc, or a commit message.
4. Run the check, and read each failure as "Read a result" tells you.
5. Copy each new SHA-256 that the check prints into `record.json`.
6. When the model no longer contains the `find` text of a break, write a new break for the same guard.
7. When a finding no longer breaks, set its status to `holds`, and record a break for it. Remove the `:known_finding` tag from its replay test.
8. For a new property, add the invariant to `RuntimeTick.tla`, to the `INVARIANTS` list of `RuntimeTick.cfg`, and to `record.json` with a break. Keep the order of `record.json` in the config.
9. Run the check again until it passes.

## Scope

The model treats each `handle_call`, `handle_cast`, and `handle_info` as one step.
That is correct, because a GenServer handles one message at a time.

`RuntimeTick.cfg` sets these bounds:

- At most 3 calls wait in the mailbox.
- At most 2 suspends are nested.
- At most 1 live reference exists.
- At most 1 timer exists without an owner.

A pass covers every order of events inside those bounds, not larger ones.
The real-code test applies every sequence of 4 calls, with no race between a call and the timer.
It also checks that a stop and a start behind an expired tick timer leave one tick chain.

The check does not cover these things:

- The time between ticks, the `dt` value, and `last_tick_time`.
- What `update/3` and `render/1` do, other than a free choice of `_live` on each event and each tick.
- A crash in app code, and a restart of the process.
- The terminal side of `suspend/1` and `resume/1`.
- `ElixirOpentui.DemoRunner`, which has its own loop and does not use `Runtime`.

## Sync commit

`syncCommit` in `record.json` is the main commit at which a person last confirmed that the model describes the covered code.
This repository squash-merges each PR, so a commit of a PR branch is not on main after the merge.
On a PR branch, keep `syncCommit` at a main commit.
The SHA-256 digests in `record.json` name the exact content that the model describes.
The newest main commit that the record describes is the newest main commit where each covered file has its recorded digest.
Move `syncCommit` only after you confirm that the model describes the code at the new commit.

## State chart file of each PR

Each PR adds one state chart file to `charts/` in this skill folder.
The file name is the branch name with the extension `.md`.
A hyphen replaces each character that is not a letter, a digit, `.`, `_`, or `-`.
For example, the branch `fm/elixir-opentui-verification-setup` has the file `charts/fm-elixir-opentui-verification-setup.md`.
A later PR from the same branch name changes that file.

The check runs before the PR exists, so it reads only the committed chart file and its SVG image.
After the pipeline pushes the branch, post one PR comment that shows the SVG image at the pushed commit and links the chart file.
For the image, write `![State chart](https://github.com/<owner>/<repo>/blob/<commit>/<image path>?raw=true)`.
Link the chart file at the same commit.
No check depends on that comment.
Do not add the chart to the PR text, because the pipeline writes the full PR text again on each run.

The chart shows only the states that the PR changes, and the states around them that a reader needs to follow the change.
It does not show the full application.
The chart must define each class that it applies with a `classDef` line, because a Mermaid viewer ignores a class with no definition.

Write the TLA+ model of the chart in a scratch folder outside the repository, and draw it with the `/statechart` skill.
When the PR changes the tick loop, start from a copy of `RuntimeTick.tla` with smaller bounds.
When the PR changes no behavior that moves between states, write "No state change" at the start of a line.
Add one sentence that says why.

### Image of the chart

Each chart file with a Mermaid chart also has an SVG image beside it.
A person can read an SVG image at any zoom.
Render the Mermaid text to an SVG file as the render guide of the `/statechart` skill says.
Give the image the base name of the chart file and the extension `.svg`, in the same folder.
Show the image in the chart file with a relative link above the Mermaid text, such as `![State chart](fm-elixir-opentui-verification-setup.svg)`.

The image must name the chart digest as `Chart digest: <digest>`, for example in a `desc` element at the start of the SVG.
The chart digest is the SHA-256 of the lines between the line `` ```mermaid `` and the closing fence, with each line end.
The check compares the digest in the image with the digest of the chart text, and it does not render.
When the two differ, the image is older than the chart text, so render the image again and write the new digest.
The check prints the expected digest when it fails.
A "No state change" note needs no image.

## Package

The `package/0` function of `mix.exs` lists the files of the Hex package.
That list does not include `.claude` or `scripts`, so this skill, the model, the charts, and the check do not ship.
Keep it that way when you change the list.

For verification that is out of step after changes that did not run this check, use `/maintain-formal-verification-skill`.
