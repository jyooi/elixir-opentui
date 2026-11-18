## State chart

This PR adds the check procedure for the verification of the `Runtime` tick loop, so the chart shows that loop and nothing more.
TLC drew it from a scratch copy of `RuntimeTick.tla` with one waiting call, one suspend, and one live reference (360 states).
No rule breaks in this chart.

![State chart of the Runtime tick loop](fm-elixir-opentui-verification-setup.svg)

```mermaid
---
title: "Runtime tick loop: start, stop, live, suspend, and resume"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: stopped
    lg1: ticking
    lg2: suspended
  }
  class lg0 tan
  class lg1 teal
  class lg2 purple
  s0: Not ticking
  s1: Suspended
  s2: Ticking
  s3: Suspended, a leftover tick is on the way
  s4: Not ticking, a leftover tick is on the way
  [*] --> s0
  s0 --> s2: an event turns live mode on or you call request_live or you call start
  s0 --> s1: you call suspend
  s1 --> s0: you call resume [while the runtime wants no ticks]
  s2 --> s0: you call stop [while nothing else wants ticks] or you call drop_live [while nothing else wants ticks] or an event turns live mode off [while nothing else wants ticks] or a tick runs, and the runtime wants no more ticks
  s2 --> s3: you call suspend
  s3 --> s2: you call resume [while the runtime wants ticks]
  s3 --> s1: you call stop [while nothing else wants ticks] or the runtime drops the leftover tick or you call drop_live [while nothing else wants ticks]
  s1 --> s2: you call resume [while the runtime wants ticks]
  s3 --> s4: you call resume [while the runtime wants no ticks]
  s4 --> s2: an event turns live mode on or you call request_live or you call start
  s4 --> s0: you call stop [while nothing else wants ticks] or the runtime drops the leftover tick
  s4 --> s3: you call suspend
  classDef tan fill:#e5d9ce,color:#1f1f1f
  classDef teal fill:#bfe3df,color:#1f1f1f
  classDef purple fill:#e3d5ff,color:#1f1f1f
  class s0 tan
  class s1 purple
  class s2 teal
  class s3 purple
  class s4 tan
```

How to read the chart:

- The runtime wants ticks when `start/1` was the last explicit call, when a live reference exists, or when a state has `_live: true`.
- A "leftover tick" is the message of a timer that `suspend/1` did not cancel.
  The runtime drops that message, because the tick loop does not run.
- A stop with a live reference or a live state keeps the runtime in "Ticking".
  That step stays in one chart state, so the chart does not draw it.

The chart does not draw steps that stay in one chart state, such as a tick that runs while the runtime wants ticks.
It does not draw the tick of a cancelled timer, because that case needs two calls that wait in the mailbox.
The check covers that case with up to three waiting calls.
