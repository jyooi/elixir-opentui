# Executive Summary

## 5-Agent Scientific Debate

Five specialized agents each advocated a distinct hypothesis for LiveView integration. After cross-agent debate, rebuttals, and evidence gathering, they reached a **layered consensus** — the hypotheses are complementary layers, not competing approaches.

## Verdicts

| # | Hypothesis | Verdict | Rationale |
|---|-----------|---------|-----------|
| H2 | Component API Alignment | **ADOPT** | Foundational. Split `update/3` into `update/2` + `handle_event/3`. Zero new deps. |
| H3 | Dual-Render Architecture | **ADOPT** (primary) | Element tree → HTML/CSS adapter, following OpenTUI's reconciler pattern. |
| H4 | State Orchestrator (PubSub) | **ADOPT** (enhancement) | Enables multi-user sync, web admin panels. ~200 lines, entirely optional. |
| H1 | Terminal Transport (xterm.js) | **SECONDARY** | Quick win for terminal-in-browser. 100% fidelity but limited web UX. |
| H5 | TUI-Styled Web Components | **SUBSUMED by H3** | The HTML adapter approach is correct; terminal styling is just a CSS theme. |

## Why Layered?

Each hypothesis addresses a different concern:

- **H2**: How do developers write components? (API surface)
- **H3**: How does the UI reach the browser? (rendering output)
- **H4**: How do multiple clients share state? (coordination)
- **H1**: How do existing terminal apps run in a browser? (transport)

These concerns are orthogonal — implementing one doesn't preclude another.

## Core Principle

**Phoenix must NOT be a dependency of `elixir_opentui`.**

LiveView integration lives in a separate `elixir_opentui_live` package, following OpenTUI's pattern where `@opentui/core` has zero dependencies on React or SolidJS.
