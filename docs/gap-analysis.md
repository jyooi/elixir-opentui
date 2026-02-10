# Gap Analysis: ElixirOpentui vs anomalyco/opentui

> Generated: 2026-02-10
> OpenTUI reference version: v0.1.77 (8.4k stars, 67 contributors, MIT License)
> ElixirOpentui: 425 tests, 25 modules, 6 phases complete

## Executive Summary

ElixirOpentui has achieved **solid foundational parity** with OpenTUI's core architecture: MVU runtime, flexbox layout, double-buffered rendering with Zig NIF, terminal I/O, focus management, and basic widgets. However, significant gaps remain in **advanced components** (Code/Diff/Markdown/Textarea), **text system sophistication** (rope data structure, undo/redo, text selection), **animation**, **terminal capability detection**, and **developer experience** tooling.

### Parity Score Card

| Category | ElixirOpentui | OpenTUI | Parity |
|----------|:---:|:---:|:---:|
| Architecture (runtime model) | MVU GenServer | Imperative OOP | **Equivalent** (different paradigm) |
| Layout engine | Pure Elixir Flexbox | Yoga (C via FFI) | **~90%** |
| Rendering pipeline | Zig NIF double-buffer | Zig double-buffer | **~85%** |
| Terminal I/O & input | ANSI/xterm parser | ANSI + Kitty + capability detection | **~65%** |
| Core widgets (Box, Text, Input, Select, Checkbox, ScrollBox) | 4 widgets | 4 equivalent widgets | **~75%** |
| Advanced widgets (Code, Diff, Markdown, Textarea, TabSelect) | Placeholders only | Full implementations | **~10%** |
| Text system (rope, undo/redo, selection) | Basic EditBuffer | Rope + undo/redo + selection + EditorView | **~30%** |
| Styling (borders, attributes, themes) | Basic | Rich (multiple border styles, themes, focus colors) | **~55%** |
| Animation & timeline | None | Timeline API with easing | **0%** |
| Framework integration | Elixir DSL only | React + SolidJS + Core imperative | **N/A** (different ecosystem) |
| Testing infrastructure | Headless TestRenderer | Test renderer + snapshot testing | **~70%** |
| Developer experience | 2 demos | CLI scaffolding, AI skills, examples, console overlay | **~25%** |

---

## 1. Architecture Comparison

### What's Equivalent

Both projects share the same core architectural DNA:

| Aspect | OpenTUI | ElixirOpentui |
|--------|---------|---------------|
| **Language split** | TypeScript (API) + Zig (native perf) | Elixir (API) + Zig (NIF perf) |
| **Buffer model** | Double-buffered cell grid, diff-based output | Double-buffered cell grid, diff-based output |
| **Layout** | Yoga flexbox (C lib) | Pure Elixir Flexbox Lite |
| **Component model** | `Renderable` class hierarchy | `Component` behaviour + `Element` structs |
| **Event routing** | Focused component receives keys; hit-test for mouse | Same: `EventManager` + `Focus` module |
| **Native perf layer** | Zig via `dlopen` FFI | Zig via Zigler NIF |

### Architectural Differences (Not Gaps)

| OpenTUI | ElixirOpentui | Assessment |
|---------|---------------|------------|
| Imperative OOP (`new BoxRenderable(ctx, opts)`) | Functional MVU (`Element.new(:box, opts)`) | **Elixir advantage** — immutable state, easier testing |
| Framework reconcilers (React, SolidJS) | Elixir macro DSL + Component behaviour | **Different ecosystems** — Elixir has LiveView integration path |
| Single-threaded event loop | OTP GenServer with supervision | **Elixir advantage** — fault tolerance, hot code upgrade |
| No built-in test renderer | Headless `TestRenderer` GenServer | **Elixir advantage** — first-class testing |

---

## 2. Component Gap Matrix

### Core Components

| Component | OpenTUI | ElixirOpentui | Gap | Priority |
|-----------|:---:|:---:|:---:|:---:|
| **Box** (container) | `BoxRenderable` | `Element :box` | Parity | - |
| **Text** (display) | `TextRenderable` + `TextNodeRenderable` | `Element :text` + `TextBuffer` | Minor gap (no hierarchical TextNode) | Low |
| **ScrollBox** | `ScrollBoxRenderable` (scissor rect clipping) | `Widgets.ScrollBox` | Parity | - |
| **Input** (single-line) | `InputRenderable` (cursor styles, validation, maxLength) | `Widgets.TextInput` (basic cursor, scroll offset) | Moderate gap | Medium |
| **Select** (vertical list) | `SelectRenderable` (j/k nav, fast scroll, ASCII font, descriptions) | `Widgets.Select` (arrow nav, page nav) | Minor gap | Low |
| **Checkbox** | No dedicated widget | `Widgets.Checkbox` | **ElixirOpentui ahead** | - |

### Missing Components (Not Implemented)

| Component | OpenTUI Features | ElixirOpentui Status | Priority |
|-----------|------------------|---------------------|----------|
| **Textarea** (multi-line editor) | Rope-based EditBuffer, undo/redo, word nav, selection, extmarks API, Emacs/macOS keybindings | `:input` element exists, `EditBuffer` has cursor but no multi-line widget | **Critical** |
| **Code** (syntax highlighting) | Tree-sitter integration, streaming mode, concealment, async highlighting, language injection | `:code` element type defined, unimplemented | **High** |
| **Diff** (unified/split viewer) | Unified + split views, syntax highlighting, line numbers, configurable colors, word wrap | `:diff` element type defined, unimplemented | **High** |
| **Markdown** (renderer) | `marked` library integration, formatted terminal output | `:markdown` element type defined, unimplemented | **Medium** |
| **TabSelect** (horizontal tabs) | Horizontal tab bar, scroll arrows, underline indicator, descriptions | Not present | **Medium** |
| **ASCIIFont** (art text) | 4 font styles (tiny/block/shade/slick), gradient colors, measurement API | Demo only (`claude_animation.exs` has bitmap font) | **Low** |
| **LineNumber** (gutter) | Line signs, per-line colors, diagnostic markers, auto-width | Not present | **Medium** |
| **Slider** | Slider input component | Not present | **Low** |
| **Image** | `ImageRenderable` via Jimp | Not present | **Low** |
| **Console** (debug overlay) | Captures console.log/warn/error, toggle, scroll, resize | Not present | **Low** |
| **FrameBuffer** (pixel-level) | Direct cell access, alpha blending, custom graphics | `Buffer` has cell access but no dedicated renderable | **Low** |

---

## 3. Text System Gap

This is one of the **largest architectural gaps**. OpenTUI's text system is significantly more sophisticated.

| Feature | OpenTUI | ElixirOpentui | Gap |
|---------|---------|---------------|-----|
| **Data structure** | Rope (Zig) — O(log n) inserts | Flat string in `EditBuffer` | **Large** |
| **Undo/redo** | Native stack in Zig, transaction grouping, configurable depth | Not implemented | **Large** |
| **EditorView** | Viewport management, cursor coordinate calc, search ops | Not implemented | **Large** |
| **Text wrapping** | Multiple strategies (greedy, optimal), container-aware | Not implemented in EditBuffer | **Large** |
| **Text selection** | Anchor/focus model, directional, cross-component | Range in EditBuffer but not surfaced to widgets | **Moderate** |
| **Coordinate systems** | Linear (rope index) + 2D (row/col) with conversion | Single cursor position | **Large** |
| **Styled text** | `TextNodeRenderable` hierarchical tree, `t` template literals | `TextBuffer` with flat spans | **Moderate** |
| **Extmarks API** | Programmatic text range decoration | Not present | **Large** |

### Impact

The text system gap blocks:
- **Textarea widget** — needs multi-line editing, wrapping, undo/redo
- **Code widget** — needs styled text ranges for syntax tokens
- **Diff widget** — needs line-level text management
- **Text selection** — needs anchor/focus model across components

### Recommended Approach

Rather than porting OpenTUI's Zig rope, leverage Elixir strengths:
1. Use `:array`-backed line list (gap buffer pattern) for multi-line editing
2. Implement undo/redo as a stack of change operations (Elixir's immutable data makes this natural)
3. Build `EditorView` as a pure module managing viewport state
4. Use existing `TextBuffer` spans model for syntax highlighting overlay

---

## 4. Layout Gaps

| Feature | OpenTUI (Yoga) | ElixirOpentui (Flexbox Lite) | Priority |
|---------|----------------|------------------------------|----------|
| `flex-wrap` | Yes | No | **Medium** |
| `column-reverse`, `row-reverse` | Yes | No | Low |
| `space-evenly` justify | Yes | No (`space_between`, `space_around` exist) | Low |
| `baseline` alignment | Yes | No | Low |
| Percentage-based min/max | Yes | Partial | Low |
| `aspect-ratio` | Yes | No | Low |

**Assessment:** Layout is **~90% feature-complete**. `flex-wrap` is the only meaningful gap for real TUI applications. The pure Elixir approach (~50us/500 nodes) is a valid trade-off vs Yoga's C FFI complexity.

---

## 5. Styling Gaps

| Feature | OpenTUI | ElixirOpentui | Priority |
|---------|---------|---------------|----------|
| **Border styles** (single/double/rounded/heavy) | 4+ styles via box-drawing chars | Single style only (`+-\|`) | **High** |
| **Border title** + alignment (left/center/right) | Yes | No | **High** |
| **Text attributes: DIM** | SGR code 2 | No | Medium |
| **Text attributes: INVERSE** | SGR code 7 | No | Medium |
| **Text attributes: BLINK** | SGR code 5 | No | Low |
| **Text attributes: HIDDEN** | SGR code 8 | No | Low |
| **Per-component focus colors** | `focusedBackgroundColor`, `focusedTextColor`, `cursorColor`, `cursorStyle` | Hardcoded blue in Painter | **Medium** |
| **Theme/color scheme system** | SyntaxStyle objects, per-component color configs | No theming system | Medium |
| **Rich text template** | `t` tagged template with `bold()`, `fg()`, `underline()` helpers | No equivalent DSL | Low |

**Assessment:** Border styles and titles are the most impactful visual gaps. They're also relatively straightforward to implement (~100 LOC for a Border module).

---

## 6. Input & Terminal Gaps

| Feature | OpenTUI | ElixirOpentui | Priority |
|---------|---------|---------------|----------|
| **Kitty Keyboard Protocol** | Full support (push/pop flags, enhanced sequences) | No (ANSI/xterm only) | **Medium** |
| **Terminal capability detection** | XTVERSION, DECRQM queries, env detection, progressive enhancement | No capability detection | **Medium** |
| **Mouse movement tracking** | SGR mode 1003 (all motion events) | Click + scroll only (mode 1006) | Medium |
| **Mouse drag** | Yes (mousedown → mousemove → mouseup) | No | Low |
| **Text selection + clipboard** | Anchor/focus selection, OSC 52 clipboard | EditBuffer has selection range but not wired to widgets or clipboard | **High** |
| **Cursor style control** | Block/underline/bar, blink options (DECTCEM) | Show/hide only | Medium |
| **Custom keybinding system** | `keyBindings` + `keyAliasMap` per component, runtime updates | Global handlers only via EventManager | Medium |
| **Bracketed paste** | Full support with `handlePaste()` callback | Parsed in Input module but not routed to widgets | Low |
| **modifyOtherKeys protocol** | Yes | No | Low |
| **Synchronized output** | Mode 2026 support | No | Low |
| **Focus tracking** | Mode 1004 (terminal focus in/out) | No | Low |

**Assessment:** Text selection + clipboard is the biggest user-facing gap. Kitty keyboard protocol and terminal capability detection improve the experience in modern terminals but aren't blocking.

---

## 7. Rendering Pipeline Gaps

| Feature | OpenTUI | ElixirOpentui | Priority |
|---------|---------|---------------|----------|
| **Scissor rect (clipping)** | OptimizedBuffer has scissor stack for viewport clipping | No scissor support in Buffer/NativeBuffer | **High** |
| **Opacity stack** | Push/pop opacity for nested transparency | Single-level opacity blending in Painter | Medium |
| **Continuous render mode** | `renderer.start()` for FPS-based loop | Event-driven only (render on state change) | **High** |
| **Timeline/animation API** | Duration, easing (linear, ease-in/out, bounce), loops, pause | No animation system | **High** |
| **Pause/resume/suspend** | Pause render loop, suspend for shell-out | No (Terminal has raw mode toggle) | Medium |
| **Debug/FPS overlay** | Built-in console overlay with stats | No | Low |
| **z-index ordering** | Yoga z-index + render order | Painter's algorithm (tree order) only | Low |

**Assessment:** Scissor rects are critical for proper ScrollBox clipping. Animation/timeline is the biggest capability gap for building dynamic UIs.

---

## 8. Developer Experience Gaps

| Feature | OpenTUI | ElixirOpentui | Priority |
|---------|---------|---------------|----------|
| **Scaffolding** | `bun create tui` | No `mix` template | Low |
| **AI coding skill** | OpenTUI skill for Claude/OpenCode | No | Low |
| **Example apps** | Multiple examples with install script | 2 demos | Medium |
| **Console overlay** | Built-in debug overlay (toggle, scroll, resize) | No | Low |
| **React DevTools** | Optional WebSocket integration | N/A | N/A |
| **Published docs** | opentui.com with getting-started, API docs | FINDINGS.md only | Medium |
| **Package distribution** | npm with platform-specific binaries | Not published to Hex | Medium |
| **Snapshot testing** | Test renderer + snapshot comparison | TestRenderer exists but no snapshot tooling | Low |

---

## 9. Unique ElixirOpentui Strengths

Features that ElixirOpentui has but OpenTUI doesn't:

| Feature | Significance |
|---------|-------------|
| **Headless TestRenderer GenServer** | First-class testing without terminal — OpenTUI's test renderer is less integrated |
| **Pure Elixir fallback** | Works without Zig/NIF compilation — OpenTUI requires Zig for all builds |
| **OTP supervision tree** | Fault-tolerant runtime with restart strategies |
| **Hot code upgrade** | OTP release upgrades without stopping the UI |
| **MVU (functional) architecture** | Immutable state, easier reasoning, no mutation bugs |
| **Checkbox widget** | OpenTUI has no dedicated checkbox component |
| **LiveView integration path** | Research documented for Phoenix LiveView TUI rendering |
| **Dual backend** | Runtime-switchable pure Elixir or NIF backend via `:backend` option |

---

## 10. Recommended Implementation Roadmap

Ordered by impact and dependency chain:

### Phase 7: Styling Foundation (~40 tests, ~1 week)

**Why first:** Visual polish that all subsequent widgets benefit from.

| Task | Files | LOC Est. |
|------|-------|----------|
| 7a. Border styles (single/double/rounded/heavy) | New: `border.ex`; Modify: `painter.ex`, `style.ex` | ~120 |
| 7b. Border titles + alignment | Modify: `painter.ex`, `style.ex` | ~60 |
| 7c. Text attributes (dim, inverse, blink, hidden) | Modify: `buffer.ex`, `nif.ex`, `ansi.ex`, `native_buffer.ex` | ~80 |
| 7d. Configurable focus colors | Modify: `style.ex`, `painter.ex` | ~50 |
| 7e. Cursor style control (block/underline/bar) | Modify: `ansi.ex` | ~30 |

### Phase 8: Text System Upgrade (~50 tests, ~2 weeks)

**Why second:** Unblocks Textarea, Code, and Diff widgets.

| Task | Files | LOC Est. |
|------|-------|----------|
| 8a. Multi-line EditBuffer (gap buffer or line list) | Modify: `edit_buffer.ex` | ~200 |
| 8b. Undo/redo stack | Modify: `edit_buffer.ex` | ~100 |
| 8c. EditorView (viewport, coordinate conversion) | New: `editor_view.ex` | ~150 |
| 8d. Text wrapping (greedy word-wrap) | Modify: `text_buffer.ex` or new module | ~100 |
| 8e. Scissor rect support in Buffer/NativeBuffer | Modify: `buffer.ex`, `nif.ex`, `native_buffer.ex` | ~120 |

### Phase 9: Advanced Widgets (~80 tests, ~3 weeks)

**Why third:** Largest feature gap; depends on Phase 8 text system.

| Task | Files | LOC Est. |
|------|-------|----------|
| 9a. Textarea widget (multi-line editor) | New: `widgets/textarea.ex` | ~250 |
| 9b. Code widget (syntax highlighting via Makeup) | New: `widgets/code.ex`; Add dep: `makeup` | ~200 |
| 9c. Diff widget (unified/split views) | New: `widgets/diff.ex` | ~250 |
| 9d. Markdown widget (via Earmark) | New: `widgets/markdown.ex`; Add dep: `earmark` | ~180 |
| 9e. TabSelect widget | New: `widgets/tab_select.ex` | ~120 |
| 9f. LineNumber widget | New: `widgets/line_number.ex` | ~80 |

### Phase 10: Animation & Live Mode (~30 tests, ~1 week)

| Task | Files | LOC Est. |
|------|-------|----------|
| 10a. Timeline API (easing, duration, loops) | New: `animation.ex` | ~150 |
| 10b. Continuous render mode in Runtime | Modify: `runtime.ex` | ~60 |
| 10c. Pause/resume/suspend | Modify: `runtime.ex`, `terminal.ex` | ~40 |

### Phase 11: Advanced Input (~35 tests, ~1 week)

| Task | Files | LOC Est. |
|------|-------|----------|
| 11a. Text selection (anchor/focus model) | New: `selection.ex` | ~120 |
| 11b. Clipboard via OSC 52 | Modify: `ansi.ex`, `terminal.ex` | ~40 |
| 11c. Mouse movement tracking (mode 1003) | Modify: `input.ex`, `ansi.ex`, `event_manager.ex` | ~60 |
| 11d. Kitty keyboard protocol | Modify: `input.ex`, `terminal.ex` | ~120 |
| 11e. Terminal capability detection | New: `capabilities.ex` | ~100 |

### Phase 12: DX & Polish (~20 tests, ~1 week)

| Task | Files | LOC Est. |
|------|-------|----------|
| 12a. Publish to Hex.pm | `mix.exs`, README | ~20 |
| 12b. `mix opentui.new` scaffolding template | New: Mix task | ~100 |
| 12c. Example apps (counter, todo, chat) | New: `examples/` | ~300 |
| 12d. Per-component keybinding customization | Modify: `event_manager.ex` | ~80 |

---

## 11. Effort Estimate Summary

| Phase | Tests | Est. LOC | Deps on |
|-------|-------|----------|---------|
| 7: Styling | ~40 | ~340 | None |
| 8: Text System | ~50 | ~670 | None |
| 9: Widgets | ~80 | ~1,080 | Phase 8 |
| 10: Animation | ~30 | ~250 | None |
| 11: Input | ~35 | ~440 | None |
| 12: DX | ~20 | ~500 | Phases 7-11 |
| **Total** | **~255** | **~3,280** | |

Post-implementation: **~680 tests total** (425 current + ~255 new)

---

## 12. Features Explicitly Out of Scope

These OpenTUI features don't apply to the Elixir ecosystem:

| Feature | Reason |
|---------|--------|
| React reconciler (`@opentui/react`) | No React in Elixir; LiveView integration is the equivalent |
| SolidJS reconciler (`@opentui/solid`) | No SolidJS in Elixir |
| Vue reconciler (`@opentui/vue`) | No Vue in Elixir |
| `bun` build system | Elixir uses `mix` |
| npm package distribution | Elixir uses Hex.pm |
| 3D rendering (WebGPU/Three.js) | Not applicable to Elixir TUI |
| React DevTools integration | N/A |
| `dlopen` FFI | Elixir uses Zigler NIF (equivalent) |

---

## References

- OpenTUI repository: https://github.com/anomalyco/opentui
- OpenTUI docs: https://opentui.com/docs/getting-started
- DeepWiki architecture: https://deepwiki.com/anomalyco/opentui
- npm package: https://www.npmjs.com/package/@opentui/core
- ElixirOpentui findings: `FINDINGS.md`, `H3_FINDINGS.md`, `H4_FINDINGS.md`
- LiveView integration research: `docs/liveview-integration/`
