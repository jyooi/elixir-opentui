# Gap Analysis: ElixirElixirOpentui vs anomalyco/opentui

## Context
ElixirElixirOpentui is an Elixir port inspired by [anomalyco/opentui](https://github.com/anomalyco/opentui) (TypeScript+Zig, 8.3k stars, v0.1.76). This analysis identifies features present in the reference project that are missing or incomplete in ElixirElixirOpentui.

---

## Feature Parity Summary

| Category | ElixirElixirOpentui | ElixirOpentui (reference) | Gap |
|----------|:---:|:---:|:---:|
| Core layout (flexbox) | ~90% | 100% | Minor |
| Basic widgets | ~70% | 100% | Moderate |
| Styling | ~60% | 100% | Moderate |
| Input handling | ~75% | 100% | Moderate |
| Rendering pipeline | ~85% | 100% | Minor |
| Advanced features | ~20% | 100% | **Large** |
| Developer experience | ~40% | 100% | **Large** |

---

## 1. Missing Widgets / Components

### High Priority (core functionality)
| Widget | ElixirOpentui | ElixirElixirOpentui | Notes |
|--------|---------|---------------|-------|
| **TextArea** (multi-line input) | Yes | No | Only single-line `TextInput` exists. `EditBuffer` has cursor but no multi-line support |
| **Code** (syntax highlighting) | Yes (Tree-sitter) | Placeholder only | `:code` element type defined but unimplemented |
| **Diff viewer** | Yes (unified/split) | Placeholder only | `:diff` element type defined but unimplemented |
| **Markdown renderer** | Yes | Placeholder only | `:markdown` element type defined but unimplemented |

### Medium Priority (nice to have)
| Widget | ElixirOpentui | ElixirElixirOpentui | Notes |
|--------|---------|---------------|-------|
| **TabSelect** | Yes | No | Tab-based horizontal selection |
| **AsciiFont** | Yes | No (demo only) | ASCII art text rendering. Demo has bitmap font but not as a reusable widget |
| **LineNumber** | Yes (with diagnostics) | No | Line numbers with diff/diagnostic indicators |

---

## 2. Layout Gaps

| Feature | ElixirOpentui | ElixirElixirOpentui | Priority |
|---------|---------|---------------|----------|
| `column-reverse`, `row-reverse` | Yes (Yoga) | No | Low |
| `space-evenly` justify | Yes | No (has space_between, space_around) | Low |
| `baseline` alignment | Yes | No | Low |
| `flex-wrap` | Yes (Yoga) | No | Medium |
| Layout engine | Yoga (C lib via FFI) | Pure Elixir (~50us/500 nodes) | N/A - different approach, both valid |

**Assessment:** Layout is nearly feature-complete. The missing features are rarely used in TUI contexts. `flex-wrap` is the most impactful gap.

---

## 3. Styling Gaps

| Feature | ElixirOpentui | ElixirElixirOpentui | Priority |
|---------|---------|---------------|----------|
| **Multiple border styles** (single/double/rounded/heavy) | Yes | Single only (box-drawing `+-\|`) | **High** |
| **Border title** + title alignment | Yes | No | Medium |
| **DIM** text attribute | Yes | No | Low |
| **BLINK** text attribute | Yes | No | Low |
| **INVERSE** text attribute | Yes | No | Medium |
| **HIDDEN** text attribute | Yes | No | Low |
| Rich text template literals | Yes (`t\`...\``) | No | Medium |
| Per-component focus colors | Yes (focusedBgColor, cursorColor) | Hardcoded blue | Medium |
| Theme/color scheme system | Implicit | No | Medium |

**Assessment:** Border styles and border titles are the most visible gaps. The additional text attributes (dim, inverse) are easy wins.

---

## 4. Input Handling Gaps

| Feature | ElixirOpentui | ElixirElixirOpentui | Priority |
|---------|---------|---------------|----------|
| **Kitty Keyboard Protocol** | Yes | No (ANSI/xterm only) | Medium |
| **modifyOtherKeys** protocol | Yes | No | Low |
| **Mouse movement tracking** | Yes | No (click/scroll only) | Medium |
| **Drag support** | Yes | No | Low |
| **Text selection + clipboard** | Yes | No | **High** |
| Custom input sequence handlers | Yes | No | Low |
| **Cursor style control** (block/line/underline/blink) | Yes | No | Medium |

**Assessment:** Text selection + clipboard is the biggest user-facing gap. Kitty keyboard protocol enables more key combinations in modern terminals.

---

## 5. Rendering Gaps

| Feature | ElixirOpentui | ElixirElixirOpentui | Priority |
|---------|---------|---------------|----------|
| **Continuous FPS render mode** | Yes (start/stop) | No (event-driven only) | Medium |
| **Live mode** for animations | Yes (requestLive/dropLive) | No | **High** |
| **Pause/resume/suspend** | Yes | No | Medium |
| **Debug overlay** (FPS/stats) | Yes | No | Low |
| Cursor position control | Yes | Partial (hide/show only) | Medium |

**Assessment:** Animation/live render mode is the biggest gap for building dynamic UIs.

---

## 6. Advanced Features Gaps (Largest Gap Area)

| Feature | ElixirOpentui | ElixirElixirOpentui | Priority |
|---------|---------|---------------|----------|
| **Animation Timeline API** | Yes (easing, duration, loops, pause) | No | **High** |
| **Tree-sitter syntax highlighting** | Yes (multi-language) | No | **High** (for Code widget) |
| **Console/debug overlay** | Yes (built-in) | No | Low |
| **Text selection + clipboard** | Yes | No | **High** |
| **Delegate pattern** (focus routing) | Yes | No | Medium |
| **React reconciler** | Yes (@opentui/react) | N/A (Elixir) | N/A |
| **SolidJS renderer** | Yes (@opentui/solid) | N/A (Elixir) | N/A |
| `bun create tui` scaffolding | Yes | No `mix` template | Low |

---

## 7. What ElixirElixirOpentui Has That ElixirOpentui Doesn't

These are unique strengths, not gaps:

| Feature | Notes |
|---------|-------|
| **Headless TestRenderer** | GenServer-based testing without a terminal |
| **Pure Elixir fallback** | Works without NIF/Zig compilation |
| **OTP supervision** | Can integrate into OTP application trees |
| **MVU architecture** | Functional, message-passing state management |
| **EditBuffer with selection** | Range-based selection model (not yet surfaced to widgets) |
| **Hot code upgrade path** | OTP release upgrade capability |

---

## Implementation Plan (Phases 7-10)

**Execution order:** Phase 7 → 8 → 9 → 10 (styling foundations enable widgets; widgets benefit from animation)

---

### Phase 7: Styling & Polish (~40 tests)

**7a. Border styles** — `lib/open_tui/border.ex` (new)
- Define border style maps: `:single` (current `+-|`→`┌─┐│└┘`), `:double` (`╔═╗║╚╝`), `:rounded` (`╭─╮│╰╯`), `:heavy` (`┏━┓┃┗┛`)
- Add `:border_style` attr to `Style` struct (default `:single`)
- Update `Painter.draw_border/4` to use style-specific characters
- Update NIF `Cell` if border chars need wider encoding

**7b. Border titles** — modify `Painter`
- Add `:title` and `:title_align` (`:left`/`:center`/`:right`) attrs to `Style`
- Render title text inline in top border, respecting alignment
- Truncate with `...` if title exceeds border width

**7c. Additional text attributes** — modify `Buffer`, `NIF`, `ANSI`
- Add `:dim`, `:inverse`, `:blink`, `:hidden` to cell attrs bitfield
- Add ANSI SGR codes: dim=2, blink=5, inverse=7, hidden=8
- Update NIF `Cell.attrs` u8 bitfield (currently: bold=1, italic=2, underline=4, strikethrough=8 → add dim=16, inverse=32, blink=64, hidden=128)

**7d. Configurable focus colors**
- Add `:focus_border_color`, `:focus_bg_color` to `Style` struct
- Replace hardcoded `{80, 160, 255, 255}` in `Painter` with per-element style lookup
- Fallback to default blue if not set

**7e. Cursor style control** — modify `ANSI`
- Add `ANSI.cursor_style/2` (`:block`/`:line`/`:underline`, blink: bool)
- ANSI sequences: `\e[1 q` (blink block), `\e[2 q` (steady block), `\e[3 q` (blink underline), etc.

**Files to modify:** `style.ex`, `painter.ex`, `buffer.ex`, `nif.ex` (Zig), `ansi.ex`, `native_buffer.ex`
**New file:** `lib/open_tui/border.ex`

---

### Phase 8: Missing Widgets (~60 tests)

**8a. TextArea** — `lib/open_tui/widgets/text_area.ex` (new)
- Multi-line input using `EditBuffer` extended for line handling
- Props: `value` (string with `\n`), `placeholder`, `on_change`, `width`, `height`, `id`
- State: `cursor_row`, `cursor_col`, `scroll_y`, `scroll_x`, lines list
- Keys: arrows (line-aware), Enter (newline), Backspace/Delete (line joining), Home/End, Ctrl+K/U, Page Up/Down
- Render: visible window of lines with cursor highlight
- **Depends on:** Phase 7 border styles for frame

**8b. TabSelect** — `lib/open_tui/widgets/tab_select.ex` (new)
- Horizontal tab bar with keyboard navigation
- Props: `tabs` (list of labels), `selected` (index), `on_change`, `id`
- Keys: Left/Right arrows, Home/End
- Render: `[ Tab1 | Tab2 | Tab3 ]` with selected tab highlighted
- Intrinsic width = sum of tab widths + separators

**8c. Code display** — `lib/open_tui/widgets/code.ex` (new)
- Syntax-highlighted code display (read-only)
- Props: `content` (string), `language` (atom), `show_line_numbers` (bool), `id`
- Highlighting strategy: use `Makeup` (Elixir library) for tokenization + custom theme→Color mapping
- Scroll support via ScrollBox composition
- Render: line numbers (optional) + colored tokens

**8d. Markdown** — `lib/open_tui/widgets/markdown.ex` (new)
- Terminal markdown rendering
- Props: `content` (markdown string), `width`, `id`
- Parse with `Earmark` (Elixir library) → render headings (bold), lists (bullets), code blocks (bg color), emphasis, links
- Scroll support via ScrollBox composition

**8e. Diff viewer** — `lib/open_tui/widgets/diff.ex` (new)
- Unified diff display
- Props: `old_text`, `new_text`, `mode` (`:unified`/`:split`), `id`
- Use Myers diff algorithm (or Elixir `String.myers_difference/2`)
- Render: `+` lines green bg, `-` lines red bg, context lines default
- Line numbers on both sides for split mode

**8f. LineNumber** — `lib/open_tui/widgets/line_number.ex` (new)
- Line number gutter
- Props: `count`, `current_line`, `diagnostics` (list of `{line, :error/:warning/:info}`)
- Render: right-aligned numbers, highlight current, diagnostic markers

**Files to create:** 6 new widget files under `lib/open_tui/widgets/`
**Files to modify:** `element.ex` (intrinsic sizes), `layout.ex` (content sizing), `painter.ex` (render dispatch), `view.ex` (DSL macros)
**Dependencies:** `makeup` (hex), `earmark` (hex) — add to `mix.exs`

---

### Phase 9: Animation & Live Mode (~30 tests)

**9a. Timeline API** — `lib/open_tui/animation.ex` (new)
- `Animation.timeline/1` creates a timeline with easing, duration, loop options
- Easing functions: `:linear`, `:ease_in`, `:ease_out`, `:ease_in_out`, `:bounce`
- `Animation.value/2` returns interpolated value at current time
- `Animation.tick/2` advances timeline by delta_ms
- Pure functional (no process) — integrates with Runtime's render loop

**9b. Continuous render mode** — modify `Runtime`
- Add `Runtime.start_live/1` and `Runtime.stop_live/1`
- When live: `Process.send_after(self(), :tick, round(1000 / target_fps))`
- `:tick` handler: advance animations, re-render, schedule next tick
- Configurable `target_fps` (default 30)

**9c. Pause/resume** — modify `Runtime`
- `Runtime.pause/1` — stops tick loop, keeps state
- `Runtime.resume/1` — restarts tick loop
- `Runtime.suspend/1` — pause + restore terminal (for shell-out)

**Files to create:** `lib/open_tui/animation.ex`
**Files to modify:** `runtime.ex`

---

### Phase 10: Advanced Input (~25 tests)

**10a. Text selection model** — `lib/open_tui/selection.ex` (new)
- Selection range: `{start_x, start_y, end_x, end_y}`
- Mouse drag tracking: mousedown starts selection, mousemove extends, mouseup finalizes
- `Selection.selected_text/2` extracts text from buffer within range
- Clipboard integration via OSC 52 escape sequence (`\e]52;c;base64_text\a`)

**10b. Mouse movement tracking** — modify `Terminal`, `ANSI`, `Input`
- Add `ANSI.enable_mouse_movement/0` (SGR mode 1003 for all motion)
- Parse movement events in `Input` (same SGR format, action `:move`)
- Route movement events through `EventManager` (new `:mouse_move` handler)

**10c. Kitty Keyboard Protocol** — modify `Input`, `Terminal`
- Enable with `\e[>1u` (push flags), disable with `\e[<u` (pop)
- Parse enhanced key events: `\e[{key};{modifiers}u` format
- Map to existing key event structure with richer modifier info
- Feature detection: query terminal support before enabling

**10d. Cursor style control** — already added ANSI sequences in Phase 7e
- Wire cursor style to `TextInput` and `TextArea` (line cursor for insert mode)
- Add `:cursor_style` to `Style` struct

**Files to create:** `lib/open_tui/selection.ex`
**Files to modify:** `input.ex`, `terminal.ex`, `ansi.ex`, `event_manager.ex`, `style.ex`

---

## Verification
- Run `mix test` after each phase to confirm no regressions
- Each phase should maintain the pattern of comprehensive test coverage (matching existing ~412 tests)
- Demo app (`demo/`) should be updated to showcase new features
