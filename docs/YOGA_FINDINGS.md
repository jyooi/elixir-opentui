# Yoga Layout Engine Integration: 5-Agent Debate Findings

**Date**: 2026-02-10
**Method**: 5-agent scientific debate with cross-examination
**Question**: What is the best way to integrate Facebook's Yoga layout engine into ElixirOpentui?

## Consensus: KEEP PURE ELIXIR — Do Not Integrate Yoga

**Vote: 5/5 agents recommend against Yoga integration for this project.**

All five agents — including the three that investigated NIF/port approaches — concluded that the current pure Elixir layout engine is the right architecture. The debate was not close.

---

## The Five Hypotheses

| # | Approach | Agent | Feasibility | Verdict |
|---|----------|-------|-------------|---------|
| H1 | Zig NIF wrapping Yoga C API via Zigler | h1-zig-nif | 6/10 | Conditionally feasible, but C++20 through Zigler is unproven |
| H2 | Rustler NIF with yoga-rs | h2-rustler | 5/10 | **REJECTED** — yoga-rs abandoned, maintainer recommends Taffy |
| H3 | Port-based (separate OS process) | h3-port | 5/10 | **REJECTED** — 4-8x slower than pure Elixir due to IPC overhead |
| H4 | Keep/enhance pure Elixir engine | h4-pure-elixir | 9/10 | **RECOMMENDED** — fast, simple, sufficient for TUI |
| H5 | Direct C NIF or existing library | h5-direct-c | 6/10 | Feasible but redundant with Zig toolchain, defers to H1 or H4 |

---

## Key Evidence

### 1. No Existing BEAM Yoga Bindings Exist (H5)

H5 conducted an exhaustive search across hex.pm, GitHub, and the broader ecosystem. **No Elixir or Erlang Yoga bindings have ever been published.** Any integration is 100% greenfield work — there is no shortcut.

### 2. yoga-rs is Effectively Abandoned (H2)

- Last substantive commit: December 2022
- Stuck on pre-Yoga 3.0 (Yoga 3.0 released March 2024 with breaking changes)
- Only 368 downloads/week, 157 stars
- **The maintainer explicitly recommends Taffy (pure Rust) instead**
- Adding Rust alongside the existing Zig toolchain = unjustified dual-toolchain complexity

### 3. Port-Based Integration is Slower Than Pure Elixir (H3)

The port approach was mathematically eliminated:

| Component | Latency |
|-----------|---------|
| Serialization (Elixir side) | ~30-80us |
| IPC overhead (port write) | ~50-100us |
| Yoga computation | ~10-30us |
| Result serialization (C side) | ~10-20us |
| IPC return (port read) | ~50-100us |
| Deserialization (Elixir side) | ~20-40us |
| **Total** | **~200-400us** |
| **Current pure Elixir** | **~50us** |

The IPC overhead alone exceeds the entire current layout computation time. Additionally, intrinsic text measurement callbacks across the port boundary would add ~10ms for 100 text nodes — a dealbreaker.

Fault isolation (the port approach's only advantage) solves a non-problem: layout is pure deterministic computation with no I/O, no unbounded allocation, and no crash-prone failure modes.

### 4. Zig NIF is Feasible but Unproven at Scale (H1)

The most viable NIF approach reuses the existing Zigler toolchain:
- Yoga has a clean C API (`extern "C"` wrapped) with ~60 functions
- Zig's `@cImport` can consume C headers
- Zigler 0.15.2 has `c:` options for C/C++ compilation

**Critical unknown**: Yoga requires **C++20**. No one has ever compiled a C++20 library of Yoga's size (~30+ source files, 8+ subdirectories) through Zigler. The bundled Zig/Clang version may not support all required C++20 features.

Build complexity: 8/10. Maintenance burden: 7/10.

Even if it works, NIF tree serialization overhead (converting `%Element{}` to `YGNode` via ~5N NIF crossings per layout pass) would likely negate much of the raw C++ speed advantage for typical TUI workloads.

### 5. The Missing Features Don't Matter for TUI (H4)

H4 delivered the decisive analysis. The current engine's gaps vs Yoga:

| Missing Feature | TUI Relevance | Why |
|-----------------|---------------|-----|
| flex-wrap | LOW | Terminal width is fixed/known; no responsive reflow needed |
| align-content | LOW | Only meaningful with flex-wrap (a no-op without it) |
| RTL direction | LOW | Terminal RTL rendering is broken industry-wide |
| aspect-ratio | ZERO | Meaningless in character grids (cells are not square) |
| order | LOW | Just reorder children in code |
| flex-direction reverse | LOW | Just reverse children list |
| space_evenly | TRIVIAL | ~5 lines to add |

**Yoga does NOT support CSS Grid** — it is Flexbox-only, just like our engine.

### 6. Enhancement Cost is Low (H4)

To reach near-Yoga parity in pure Elixir:

| Feature | LOC | Complexity |
|---------|-----|-----------|
| space_evenly | ~5 | Trivial |
| flex-direction reverse | ~20 | Trivial |
| order | ~30 | Low |
| gap as percentage | ~10 | Trivial |
| flex-wrap | ~150-200 | Moderate |
| align-content | ~80 | Moderate |
| RTL direction | ~50 | Low |
| position: static | ~15 | Trivial |
| box-sizing: content-box | ~20 | Low |
| display: contents | ~40 | Low |
| **TOTAL** | **~420-470** | **Moderate** |

This brings layout.ex from 574 to ~1000 lines — within the original architecture estimate of 800-1200 lines.

Compare to ANY NIF approach: 200-500+ LOC wrapper code PLUS external toolchain, cross-platform builds, serialization protocol, and upstream dependency tracking.

### 7. Industry Consensus: Custom Layout Engines (H4)

| TUI Framework | Language | Layout Engine | Uses Yoga? |
|---------------|----------|---------------|-----------|
| Ratatui | Rust | Custom constraint solver | No |
| BubbleTea/Lipgloss | Go | Custom string-based | No |
| Textual | Python | Custom CSS subset | No |
| Cursive | Rust | Custom box model | No |
| tview | Go | Custom flex-like | No |
| **Ink** | **JS** | **Yoga (via WASM)** | **Yes** |

**5 of 6 major TUI frameworks use custom layout engines.** Ink is the sole exception, and it uses Yoga because it's a React renderer (leveraging React Native's ecosystem), not because Yoga is the right tool for TUI layout.

### 8. Performance is a Non-Issue (H4)

- Current engine: **~50us for 500 nodes** = 0.3% of a 16ms frame budget (60fps)
- Real TUI apps rarely exceed 200-300 nodes
- The bottleneck in TUI rendering is **terminal I/O** (writing ANSI sequences), not layout computation
- NIF serialization overhead would likely negate any computational speedup

---

## Cross-Examination Highlights

### H5 challenged H1:
> "Can Zigler actually link against a pre-built C++ library like Yoga? Have you confirmed @cImport works with Yoga's C headers given it's a C++ library underneath?"

H1's rebuttal (post-debate): **`@cImport` is a non-issue by design.** Zig's `translate-c` parses headers as C (not C++), so `__cplusplus` is undefined and Yoga's `YG_EXTERN_C_BEGIN` macros expand to nothing — the function declarations are parsed as plain C. This is exactly how Yoga's C API is designed for non-C++ consumers.

H1 identified two viable strategies: (A) compile Yoga's C++ sources within Zigler using `c: [src: ..., link_libcpp: true]` (Zig bundles Clang 19, which supports C++20), or (B) pre-build Yoga as a static library via CMake and link it in. Strategy B sidesteps the C++20-through-Zigler concern entirely. Updated feasibility: **7/10** (raised from 6/10).

The remaining risks are build complexity (enumerating ~30 .cpp files across 8 subdirectories) and vendoring/tracking Yoga releases — not fundamental technical blockers.

### H5 challenged H4:
> "At what point does CSS non-compliance become a real problem for a TUI framework?"

H4 responded: Never, because (a) terminal UIs don't need web-grade layout features, (b) the missing features can be added incrementally for ~420 LOC, and (c) every competing TUI framework except Ink uses custom layout.

### H3 self-eliminated:
H3's own math showed port-based Yoga would be 4-8x SLOWER than the current engine, calling it "the worst of both worlds."

### H2 self-eliminated:
H2 discovered yoga-rs is abandoned and the maintainer recommends Taffy. Adding Rust alongside Zig was deemed "unjustified engineering complexity."

---

## Final Recommendation

### Primary: Keep and Enhance Pure Elixir Layout Engine

The current 574-line Elixir "Flexbox Lite" engine should remain the layout engine. It is:
- **Fast enough**: ~50us for 500 nodes (0.3% of frame budget)
- **Feature-complete enough**: Implements everything real TUI apps need
- **Simple**: Zero external dependencies, fully debuggable, any Elixir dev can contribute
- **Extensible**: ~420-470 LOC to reach near-Yoga parity if ever needed

### Suggested Enhancements (Low Priority)
1. `justify_content: :space_evenly` — 5 lines, do it anytime
2. `flex_direction: :row_reverse / :column_reverse` — 20 lines
3. `flex-wrap` — 150-200 lines, only if users demand it

### Fallback: Zig NIF (If Requirements Change)

If future requirements demand:
- Full CSS Flexbox compliance for web-parity APIs
- Layout trees with 5000+ nodes per frame
- Sub-10us layout for complex trees

Then the Zig NIF approach (H1) is the recommended integration path, contingent on a proof-of-concept confirming Zigler can compile Yoga's C++20 sources. Steps:
1. Build a minimal POC: Compile Yoga via Zigler's `c:` option with `link_libcpp: true`
2. Design a batch binary protocol (like existing `put_cells`) to minimize NIF crossings
3. Vendor Yoga source files (~30 .cpp files)

### Approaches to Avoid
- **Rustler/yoga-rs**: Dead library, dual toolchain
- **Port-based**: Performance regression, serialization complexity
- **Direct C NIF**: Redundant with existing Zig toolchain

---

## Appendix: Agent Scoring Summary

| Criterion | H1 (Zig NIF) | H2 (Rustler) | H3 (Port) | H4 (Pure Elixir) | H5 (Direct C) |
|-----------|---------------|---------------|-----------|-------------------|----------------|
| Feasibility | 6/10 | 5/10 | 5/10 | 9/10 | 6/10 |
| Build Complexity | 8/10 | 9/10 | 6/10 | 1/10 | 7/10 |
| Performance | 7/10 | 7/10 | 4/10 | 8/10 | 7/10 |
| Maintenance | 7/10 | 8/10 | 7/10 | 2/10 | 6/10 |
| **Self-Recommendation** | Conditional | No | No | **Yes** | No (defers) |

*Build Complexity and Maintenance: higher = worse. Performance: higher = better.*
