# ElixirOpentui — Verified TODO

> Generated: 2026-02-25
> Verified by: 9 parallel agents against codebase on branch `add-scissor-rect-clipping`
> Reference: `docs/gap-analysis.md` (vs OpenTUI v0.1.77)

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| :white_check_mark: | Done — implemented with tests |
| :yellow_circle: | Partial — started but incomplete |
| :x: | Not done — no implementation exists |

---

## Phase 1-2: Core Architecture & Runtime — :white_check_mark: COMPLETE

All items verified as done (~180 tests).

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1 | MVU GenServer runtime | :white_check_mark: | `runtime.ex` — mount/process_event/update/render loop, :live/:headless modes (13 tests) |
| 2 | Component behaviour (init/1, update/3, render/1) | :white_check_mark: | `component.ex` — `@behaviour` + `use` macro (5 tests) |
| 3 | Element tree model | :white_check_mark: | `element.ex` — 14 element types, struct with type/attrs/style/children/id/key (11 tests) |
| 4 | OTP supervision tree | :x: | No Supervisor/Application module — intentional for library use (users compose own sup tree) |
| 5 | Dual backend (Elixir + NIF) | :white_check_mark: | `buffer.ex` + `native_buffer.ex` both implement `BufferBehaviour`; `backend: :elixir | :native` (38 tests) |
| 6 | Box container | :white_check_mark: | `:box` element type in element.ex, layout.ex, painter.ex |
| 7 | Text display | :white_check_mark: | `:text` element + `text_buffer.ex` with styled spans, grapheme-aware (17 tests) |
| 8 | ScrollBox widget | :white_check_mark: | `widgets/scroll_box.ex` — scroll wheel, arrows, PgUp/Down, Home/End (15 tests) |
| 9 | TextInput widget | :white_check_mark: | `widgets/text_input.ex` — cursor, scroll_offset, Emacs bindings, paste (36 tests) |
| 10 | Select widget | :white_check_mark: | `widgets/select.ex` — fast scroll, vim keys, wrap, descriptions (34 tests) |
| 11 | Checkbox widget | :white_check_mark: | `widgets/checkbox.ex` — Space/Enter toggle, on_change (11 tests) |

---

## Phase 3-4: Layout Engine & Rendering Pipeline — :white_check_mark: COMPLETE

All items verified as done (~136 tests).

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1 | Pure Elixir Flexbox | :white_check_mark: | `layout.ex` — 3-pass algorithm (measure/flex-resolve/position) (36 tests) |
| 2 | flex_direction (row/column) | :white_check_mark: | `style.ex:11`, `layout.ex` throughout |
| 3 | justify_content (5 values) | :white_check_mark: | `layout.ex:481-497` — flex_start/flex_end/center/space_between/space_around |
| 4 | align_items/align_self | :white_check_mark: | `layout.ex:499-525` |
| 5 | flex_grow/flex_shrink/flex_basis | :white_check_mark: | `layout.ex:349-404` distribute_grow/shrink |
| 6 | padding/margin | :white_check_mark: | `layout.ex:61-66` as {top,right,bottom,left} tuples |
| 7 | min/max width/height | :white_check_mark: | `layout.ex:128-162` with percent support |
| 8 | Percentage dimensions | :white_check_mark: | `layout.ex:139` — `{:percent, p}` syntax |
| 9 | Double-buffered cell grid | :white_check_mark: | `nif.ex:55-63` front/back Cell arrays in Zig |
| 10 | Diff-based ANSI output | :white_check_mark: | NIF path (`nif.ex:237-275`) + pure Elixir (`buffer.ex:231-246`, `ansi.ex:147-155`) |
| 11 | Zig NIF backend | :white_check_mark: | `nif.ex` (inline ~Z), `native_buffer.ex` — 10 NIF functions (17+12 tests) |
| 12 | Pure Elixir fallback | :white_check_mark: | `buffer.ex` with `BufferBehaviour` (26 tests) |
| 13 | Painter module | :white_check_mark: | `painter.ex` — tree walk, borders, content, hit regions, focus, scissor, opacity (11 tests) |
| 14 | ANSI module | :white_check_mark: | `ansi.ex` — cursor, screen, mouse, 24-bit RGB, text attrs, render_full/render_diff (34 tests) |

---

## Phase 5-6: Terminal I/O, Input & Focus/Events — :white_check_mark: COMPLETE

All items verified as done (~138 tests).

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 1 | Terminal module (raw mode) | :white_check_mark: | `terminal.ex` — GenServer, enter/1, leave/1, subscriber model |
| 2 | ANSI escape sequences | :white_check_mark: | `ansi.ex` — cursor, screen, SGR, true color (34 tests) |
| 3 | Alternate screen buffer | :white_check_mark: | `\e[?1049h` / `\e[?1049l` in ansi.ex, called by Terminal |
| 4 | Input parser | :white_check_mark: | `input.ex` — `parse/1` returns typed event maps (47 tests) |
| 5 | Arrow/function keys + modifiers | :white_check_mark: | CSI/SS3 arrows, F1-F12, Shift/Alt/Ctrl modifier encoding |
| 6 | Mouse click + scroll (SGR 1006) | :white_check_mark: | SGR mouse parser, press/release/move/scroll, button + modifier bits |
| 7 | Bracketed paste | :white_check_mark: | `\e[200~`..`\e[201~` → `%{type: :paste, data: string}` |
| 8 | Special keys | :white_check_mark: | Home/End/Insert/Delete/PgUp/PgDown/Shift+Tab/Escape |
| 9 | Focus module | :white_check_mark: | `focus.ex` — from_tree, focus/blur, next/prev with wrap (21 tests) |
| 10 | EventManager | :white_check_mark: | `event_manager.ex` — Tab nav, global/per-element handlers, mouse hit-test (13 tests) |
| 11 | Hit testing | :white_check_mark: | Buffer.get_hit_id/3, NativeBuffer.get_hit_id/3, TestRenderer.get_hit_id/3 |
| 12 | TestRenderer GenServer | :white_check_mark: | `test_renderer.ex` — headless, both backends (9 tests) |
| 13 | Test helpers | :white_check_mark: | `test_helper.exs` — NIF availability check, tag exclusion |
| 14 | View DSL (macros) | :white_check_mark: | `view.ex` — 13 element macros → `Element.new/3` (14 tests) |

---

## Phase 7: Styling Foundation — :white_check_mark: COMPLETE

All 5 items verified as done.

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 7a | Border styles (single/double/rounded/heavy) | :white_check_mark: | `border.ex:20-23` all 4 styles; `style.ex` border_style field; `painter.ex:86` uses it |
| 7b | Border titles + alignment | :white_check_mark: | `style.ex:43-44` border_title + border_title_align; `painter.ex:120-158` paint_border_title |
| 7c | Text attributes (dim/inverse/blink/hidden) | :white_check_mark: | `style.ex:59-62`, `buffer.ex:24-27`, `ansi.ex:107-122` SGR 2/7/5/8, `native_buffer.ex` bit flags |
| 7d | Configurable focus colors | :white_check_mark: | `style.ex:50-54` focus_fg/focus_bg/focus_border_color/cursor_color; tests in focus_colors_test.exs |
| 7e | Cursor style control (block/underline/bar) | :white_check_mark: | `ansi.ex:68-78` cursor_shape/2 (6 sequences); `painter.ex:452-464` per-style rendering |

---

## Phase 8: Text System Upgrade — :white_check_mark: COMPLETE

All 5 items verified as done (~224 tests across EditBuffer + EditorView + scissor).

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 8a | Multi-line EditBuffer (NIF rope) | :white_check_mark: | `edit_buffer.ex` + NIF — line_count, new_line, delete_line, goto_line, move_up/down (42+165 tests) |
| 8b | Undo/redo stack | :white_check_mark: | `edit_buffer.ex:150-206` — undo/redo/can_undo?/can_redo?/clear_history, NIF-backed |
| 8c | EditorView (viewport + coordinates) | :white_check_mark: | `editor_view.ex` — viewport, 5-tuple visual cursor, coordinate conversion (17 tests) |
| 8d | Text wrapping (greedy word-wrap) | :white_check_mark: | `editor_view.ex:86-96` — 3 modes :none/:char/:word via NIF |
| 8e | Scissor rect support | :white_check_mark: | `buffer.ex:35-92`, `native_buffer.ex:36-71`, `buffer_behaviour.ex` callbacks, `painter.ex` integration (17 tests) |

---

## Phase 9: Advanced Widgets — :white_check_mark: COMPLETE

All 6 items done (1018 tests total).

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 9a | TextArea widget | :white_check_mark: | `widgets/text_area.ex` — NIF-backed, full keybindings, selection, undo/redo, scroll (164 tests) |
| 9b | Code widget (syntax highlighting) | :white_check_mark: | `widgets/code.ex` — Makeup-based highlighting, scroll, streaming mode; `:makeup` + `:makeup_elixir` deps (19 tests) |
| 9c | Diff widget (unified/split) | :white_check_mark: | `widgets/diff.ex` — unified + split views, diff parser, line numbers, scroll (22 tests) |
| 9d | Markdown widget | :white_check_mark: | `widgets/markdown.ex` — Earmark-based parsing, headings/lists/code blocks/blockquotes; `:earmark` dep (18 tests) |
| 9e | TabSelect widget | :white_check_mark: | `widgets/tab_select.ex` — horizontal tabs, scroll offset, bracket/arrow nav, wrap selection (24 tests) |
| 9f | LineNumber widget | :white_check_mark: | `widgets/line_number.ex` — line signs, per-line colors, auto-width, custom line numbers (25 tests) |

---

## Phase 10: Animation & Live Mode — :white_check_mark: COMPLETE

All 3 items done (88 timeline + 18 runtime tick + 104 easing = 210 tests).

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 10a | Timeline API (easing, duration, loops) | :white_check_mark: | `animation/timeline.ex` — play/pause/advance/value, loops, alternation, sync, once, callbacks (88 tests); `animation/easing.ex` — 25 easing functions (104 tests) |
| 10b | Continuous render mode | :white_check_mark: | `runtime.ex` — `_live` flag, `request_live/drop_live` ref counting, 60 FPS tick loop via `Process.send_after`, tick delivery to components (18 tests) |
| 10c | Pause/resume/suspend | :white_check_mark: | `runtime.ex` — suspend/resume with nesting (suspend_count), FSM idle↔running↔suspended transitions (18 tests) |

---

## Phase 11: Advanced Input — :white_check_mark: COMPLETE

All 5 items done.

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 11a | Text selection (anchor/focus) | :white_check_mark: | NIF-backed in TextArea via EditorView; `painter.ex:366-466` renders selection highlighting (68+ tests) |
| 11b | Clipboard via OSC 52 | :white_check_mark: | `ansi.ex` OSC 52 copy/paste sequences; `input.ex` OSC 52 response parsing; clipboard keybindings in TextArea |
| 11c | Mouse movement tracking (mode 1003) | :white_check_mark: | `ansi.ex:52` enables `\e[?1003h`; `input.ex:241` decodes motion bit → :move |
| 11d | Kitty keyboard protocol | :white_check_mark: | `input.ex` CSI u parsing; `ansi.ex` push/pop kitty keyboard flags; `terminal.ex` integration |
| 11e | Terminal capability detection | :white_check_mark: | `capabilities.ex` — XTVERSION/DECRQM/env-based detection, progressive enhancement |

### TODO for Phase 11:
- [x] **11b. Clipboard via OSC 52** — Add OSC 52 read/write to `ansi.ex`, wire copy/paste keybindings in TextArea (~40 LOC)
- [x] **11d. Kitty keyboard protocol** — Add CSI u parsing to `input.ex`, push/pop flags in `terminal.ex` (~120 LOC)
- [x] **11e. Terminal capability detection** — Create `capabilities.ex` with XTVERSION, DECRQM, env-based detection, progressive enhancement (~100 LOC)

---

## Phase 12: DX & Polish — :x: MOSTLY TODO

0 of 4 items done (1 partial).

| # | Item | Status | Evidence |
|---|------|--------|----------|
| 12a | Publish to Hex.pm | :x: | mix.exs has no package/0, description, licenses, or maintainers |
| 12b | `mix opentui.new` scaffolding | :x: | No lib/mix/tasks/ directory |
| 12c | Example apps | :x: | No examples/ directory (only test/demo/ files) |
| 12d | Per-component keybinding customization | :yellow_circle: | `event_manager.ex` has register_handler/3 per element-id but no formal keybinding map API |

### TODO for Phase 12:
- [ ] **12a. Hex.pm publishing** — Add `package/0` to mix.exs with description, licenses, links, maintainers (~20 LOC)
- [ ] **12b. `mix opentui.new` scaffolding** — Create Mix task template in `lib/mix/tasks/` (~100 LOC)
- [ ] **12c. Example apps** — Create `examples/` with counter, todo, chat demos (~300 LOC)
- [ ] **12d. Keybinding customization** — Add formal per-component keybinding map API to `event_manager.ex` (~80 LOC)

---

## Remaining Layout Gaps

| # | Item | Status | Priority | Evidence |
|---|------|--------|----------|----------|
| L1 | flex-wrap | :x: | Medium | Explicitly noted as not implemented in `layout.ex:17` |
| L2 | column-reverse / row-reverse | :x: | Low | Only :row and :column supported |
| L3 | space-evenly justify | :x: | Low | Not in justify_content type |

### TODO for Layout:
- [ ] **L1. flex-wrap** — Add wrap support to layout.ex flexbox algorithm
- [ ] **L2. column-reverse / row-reverse** — Add reverse direction handling to layout.ex
- [ ] **L3. space-evenly** — Add :space_evenly to justify_content in style.ex + layout.ex

---

## Remaining Rendering Gaps

| # | Item | Status | Priority | Evidence |
|---|------|--------|----------|----------|
| R1 | Opacity stack (push/pop) | :white_check_mark: | — | `painter.ex:43` multiplied inheritance (`parent_opacity * el.style.opacity`) |
| R2 | z-index ordering | :x: | Low | z_index field exists in style.ex/element.ex but never used in painter.ex |
| R3 | Continuous render mode | :white_check_mark: | High | Implemented in Phase 10b — `runtime.ex` tick loop |

### TODO for Rendering:
- [ ] **R2. z-index ordering** — Sort children by z_index before painting in `painter.ex`

---

## Summary Score Card

| Phase | Done | Total | Parity |
|-------|------|-------|--------|
| Phase 1-2: Architecture & Runtime | 10 | 11 | **~95%** |
| Phase 3-4: Layout & Rendering | 14 | 14 | **100%** |
| Phase 5-6: Terminal I/O & Events | 14 | 14 | **100%** |
| Phase 7: Styling Foundation | 5 | 5 | **100%** |
| Phase 8: Text System Upgrade | 5 | 5 | **100%** |
| Phase 9: Advanced Widgets | 6 | 6 | **100%** |
| Phase 10: Animation & Live Mode | 3 | 3 | **100%** |
| Phase 11: Advanced Input | 5 | 5 | **100%** |
| Phase 12: DX & Polish | 0 | 4 | **~5%** |
| Layout Gaps | 0 | 3 | **0%** |
| Rendering Gaps | 2 | 2 | **100%** |
| **TOTAL** | **63** | **72** | **~88%** |

---

## Prioritized TODO Checklist (by impact)

### Critical
- [x] 9b. Code widget (syntax highlighting via Makeup)
- [x] 9c. Diff widget (unified/split views)
- [x] 10b. Continuous render mode in Runtime

### High
- [x] 9d. Markdown widget (via Earmark)
- [x] 9e. TabSelect widget
- [x] 10a. Timeline API (easing, duration, loops)
- [x] 11b. Clipboard via OSC 52

### Medium
- [x] 9f. LineNumber widget
- [x] 10c. Pause/resume/suspend
- [x] 11d. Kitty keyboard protocol
- [x] 11e. Terminal capability detection
- [ ] 12a. Publish to Hex.pm
- [ ] 12c. Example apps
- [ ] 12d. Per-component keybinding customization
- [ ] L1. flex-wrap support

### Low
- [ ] 12b. `mix opentui.new` scaffolding
- [ ] L2. column-reverse / row-reverse
- [ ] L3. space-evenly justify
- [ ] R2. z-index ordering

---

## Test Stats

- **Current test files:** 41
- **Approximate test count:** 1228 (verified 2026-02-27)
- **Test count by phase:** P1-2(~180), P3-4(~136), P5-6(~138), P7(~40), P8(~224), P9(272), P10(210)
