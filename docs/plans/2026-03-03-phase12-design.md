# Phase 12 Design — DX & Polish

> Generated: 2026-03-03
> Method: 3-agent adversarial debate (pragmatist, user-advocate, perfectionist)
> Status: Consensus reached

---

## Debate Summary

Three agents with opposing perspectives debated the best approach for Phase 12:

- **Pragmatist**: Ship fast, minimal docs, Hex.pm first
- **User-advocate**: New user journey first, examples before publishing
- **Perfectionist**: Comprehensive docs, do it right or don't do it

After 2+ rounds of debate with evidence from Ratatouille, Bubbletea, Phoenix, Nx, and open source research, the team converged on ~90% agreement.

---

## Consensus: Phase 12 Priority Order

1. **README + `package/0` + Getting Started guide + Hex.pm publish** — one atomic task (~1 day)
2. **12c: Example apps** — counter, todo, chat curated from existing demos (same week, 0.1.1)
3. **12d: Per-component keybinding customization** — actual feature work
4. **12b: `mix opentui.new`** — deferred (YAGNI for a library dependency)

---

## Consensus: README Structure (~150-200 lines)

```
1. Hero section
   - One-paragraph pitch
   - Screenshot or asciinema GIF of widget gallery

2. Code example (the "sell")
   - ~20-25 line counter app showing init/update/render + View DSL
   - Copy-pasteable, runnable

3. Features
   - 6-8 bullet points: widgets, Zig NIF, flexbox layout, animation, syntax highlighting, markdown

4. Installation
   - mix.exs deps block
   - OTP 28+ requirement callout
   - `mix zig.get` prerequisite

5. Quick start
   - 3 commands: deps.get → zig.get → mix run examples/counter.exs

6. Examples
   - Links to counter, todo, chat with one-line descriptions
   - Link to demo/ directory for exploration

7. How it works
   - One paragraph: Elm Architecture + View DSL + Zig NIF rendering

8. Documentation
   - Link to HexDocs Getting Started guide

9. License
```

---

## Consensus: Documentation Strategy

### Tier 1 — Ships with v0.1.0 (blocks publish)

- README as structured above
- `package/0` metadata in mix.exs (description, links, license)
- One lean Getting Started guide in `guides/` (~50-80 lines)
  - "Build a Counter in 5 Minutes"
  - Shows up automatically on HexDocs
- @moduledoc on entry module (ElixirOpentui) — HexDocs landing page

### Tier 2 — Ships same week (v0.1.1)

- 3 progressive example apps (counter → todo → chat)
  - Built FROM existing demo/ files, reshaped for pedagogical clarity
  - Inline comments explaining the MVU pattern
- @moduledoc improvements on top 5-10 public modules
- demo/ directory cleanup + READMEs

### Tier 3 — Community-driven (v0.2.0+)

- Cookbook/patterns guide (driven by real user questions)
- Widget-by-widget reference with screenshots
- Architecture overview
- Performance benchmarks (Zig NIF vs pure Elixir)
- Comparison to Ratatouille/alternatives
- `mix opentui.new` generator (if demand materializes)

---

## Key Arguments That Shaped Consensus

1. **"You only get one Hex.pm launch"** — README and publish must be atomic. The Hex.pm page gets indexed permanently. (user-advocate, adopted by all)

2. **Ratatouille is the incumbent** — 775 stars, decent README, abandoned. Our docs must clearly signal "this is the maintained, better alternative." (perfectionist, adopted by all)

3. **"We're not Jose Valim"** — Nx shipped minimal docs because of name recognition. Unknown projects must earn trust through documentation quality. (perfectionist, adopted by pragmatist)

4. **Progressive examples beat "real apps"** — counter → todo → chat teaches the framework in layers. A 500-line file browser is impressive but pedagogically useless. (user-advocate, adopted by perfectionist)

5. **Cookbook should be user-driven** — Writing comprehensive docs for an API that will change in 0.2.0 creates maintenance burden. Let community questions drive what gets documented. (pragmatist, adopted by perfectionist)

6. **Getting Started guide is 30 min of high-ROI work** — Bridges the gap between "what is this" and "I built something." Not worth deferring. (perfectionist, adopted by pragmatist)

---

## Remaining Disagreement

**Should examples block Hex.pm publish?**

- Pragmatist + Perfectionist: No. Publish with README + Getting Started guide. Examples follow in 0.1.1 same week.
- User-advocate: Yes. Examples → README → publish. "The fastest path to real users is not the fastest path to `mix hex.publish`."

**Resolution**: Majority rules — publish first, examples follow. The existing 17 demo/ scripts serve as interim examples, linked from README.

---

## Research Sources

- Ratatouille README structure (counter-app-first pattern)
- Bubbletea adoption model (40K stars from examples + tutorial, not comprehensive docs)
- Phoenix 1.8 generator simplification (DX friction affects all skill levels)
- UC Irvine 2024 study: 91% of developers use documentation for adoption decisions
