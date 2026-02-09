# LiveView Integration for ElixirOpentui

Research findings from a 5-agent scientific debate on how Phoenix LiveView should integrate with ElixirOpentui.

**Date**: 2026-02-09

## Documents

| File | Description |
|------|-------------|
| [Executive Summary](01-executive-summary.md) | Layered consensus and verdict for each hypothesis |
| [Hypothesis Details](02-hypotheses.md) | Full analysis of all 5 hypotheses with code examples |
| [Consensus Architecture](03-consensus-architecture.md) | Architecture diagram and implementation phases |
| [Debate Exchanges](04-debate-exchanges.md) | Key cross-agent debates and resolutions |
| [OpenTUI Precedent](05-opentui-precedent.md) | How OpenTUI solved the same problem in TypeScript |
| [Elm vs LiveView Comparison](06-elm-vs-liveview.md) | Current TEA/Elm model vs LiveView model |
| [LiveView as Authoring Layer](07-liveview-authoring-layer.md) | Using LiveView paradigm to author terminal UIs |

## Context

ElixirOpentui is a terminal UI framework with:
- Pure Elixir Flexbox layout engine
- MVU (Model-View-Update) runtime via GenServer
- Zig NIF for high-performance buffer rendering
- Component behaviour with init/update/render callbacks
- 425 tests across 6 implementation phases

The question: how should Phoenix LiveView integrate as a first-class citizen?

## Key Conclusion

LiveView integration is **not a single feature** but a **layered architecture**:

1. **API Alignment** (H2) — Adopt LiveView conventions in core component API
2. **Dual-Render** (H3) — Element tree renders to both terminal and HTML/CSS
3. **State Sync** (H4) — PubSub bridge for multi-user and web admin scenarios
4. **Terminal Transport** (H1) — xterm.js in browser for 100% fidelity fallback

This mirrors OpenTUI's pattern: framework-agnostic core + optional adapter packages.
