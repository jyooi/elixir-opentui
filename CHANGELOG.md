# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- A fresh build with a prebuilt NIF failed with `File.CopyError`, because `priv/lib` did not exist.
- `EditBufferNIF.get_text/1`, `view_get_selected_text/1` and `view_get_visible_lines/1` leaked
  their result on each call. `TextArea` leaked memory on each render and each edit.
- An editor view did not keep its edit buffer alive. The VM crashed when the buffer was
  garbage collected first. The view destructor now also frees the view internals.
- The Hex package included the local `zig/opentui/.zig-cache` directory.
- `TextInput` ignored characters outside ASCII.
- `Timeline.play/1` on a completed timeline cleared the values, so `value/2` raised until
  the next `advance/2`.
- `Markdown` got one row for each block from `Layout`, not one row for each rendered line.
- `Runtime.dispatch/2` dropped `{:paste, data}`. It now goes to the focused widget.
- `Runtime.start/1`, `request_live/1` and `stop/1` ended a suspension.
- The accessibility snapshot reported no tabs for `:tab_select`, `scroll_top: 0` for
  `:scroll_box`, an empty label for a button with `content:`, and `visible: true` for
  hidden elements.
- `Input.parse/1`: Alt with a multi-byte character gave an invalid key, Escape then DEL was
  not Alt+Backspace, and wheel left and right were reported as button presses. They are
  now `:scroll_left` and `:scroll_right`.
- `Buffer.diff/2` raised for a zero-size buffer.
- Line number colors got the opacity two times.

### Changed

- `Markdown.render/1` sets `:line_count` in place of `:block_count`.
- `Code.render/1` does not set the unused `:lines` attr.

## [0.2.0] - 2026-09-13

### Removed

- **BREAKING:** unused public API, cut after the 2026-09-13 over-engineering audit:
  - `Animation.Timeline`: `call/3`, `sync/2,3`, `once/3`, `pause/1`, `restart/1`,
    `playing?/1`, `current_time/1`, the `on_start`, `on_complete`, `on_loop`,
    `on_update` and `on_pause` callbacks, the `auto_play` option, and the per-item
    `loop`, `alternate` and `loop_delay` options of `add/3`. `new/1`, `add/3`,
    `play/1`, `advance/2`, `value/2` and `finished?/1` stay, as do timeline-level
    `loop` and `alternate`.
  - `ElixirOpentui.EditBuffer` and `ElixirOpentui.EditorView` wrapper modules.
    `TextArea` calls `EditBufferNIF` directly.
  - `EditBufferNIF.available?/0` and 16 NIF functions: `replace_text`, `goto_line`,
    `delete_range`, `eb_clear`, `can_undo`, `can_redo`, `clear_history`,
    `get_eol_eb`, `get_next_word_boundary_eb`, `get_prev_word_boundary_eb`,
    `get_text_range`, `get_text_range_by_coords`, `move_cursor_up`,
    `move_cursor_down`, `view_get_selection` and `view_set_cursor_by_offset`.
    The NIF source changed, so the v0.1.1 prebuilt binaries do not work with
    0.2.0 source. v0.2.0 ships its own prebuilt binaries, and `mix compile`
    downloads them for the listed platforms.
  - `ElixirOpentui.TestRenderer` and `ElixirOpentui.TestHelpers`. Use
    `Runtime` headless mode.
  - The `:pixel` ASCII font.
  - `Widgets.LineNumber`. Use the `line_number` element. The gutter width math
    now lives in `Layout`, and the `:gutter_width` attr still overrides it.
  - `TextBuffer` styled-span API: the struct, `new/0`, `from_text/1`,
    `from_spans/1`, `styled/2`, `concat/1`, `to_plain/1`, `graphemes/1`,
    `style_at/2`, `append/3`, `slice/3`, and the struct clauses of
    `grapheme_count/1` and `display_width/1`. The string helpers stay.
  - Widget options that `Painter` never read: `Diff` `:filetype`, `Code`
    `:wrap_mode`, `:streaming` (and `{:set_streaming, _}`) and
    `:line_number_offset`, and the `Markdown` fallback parser used when
    `earmark_parser` is not installed. `Markdown` now requires `earmark_parser`.
  - `EventManager` handler registry: `register_handler/3`,
    `register_global_handler/2`, the `handlers` and `global_handlers` fields,
    and paste dispatch.
  - `Element.count/1`, `map/2`, `reduce/3`, `find_by_id/2` and the `key` field.
  - `Buffer.draw_char_blend/7`, `Buffer.capture_rect/5`, `Canvas.fill_rect/8`,
    `Canvas.clear/1`, `ANSI.save_cursor/0`, `ANSI.restore_cursor/0`,
    `ANSI.cursor_shape/2`, `Color.yellow/0`, `Color.cyan/0`, `Color.magenta/0`,
    and the `Capabilities` fields `color_support`, `terminal_program`, `tmux`
    and `term`. `Capabilities.detect_env/0` takes no arguments now.
- `ElixirOpentui.Terminal` GenServer and the `:terminal` option of `ElixirOpentui.Runtime`. Demos drive the terminal through `ElixirOpentui.DemoRunner`.
- **BREAKING:** the native render backend. `ElixirOpentui.NativeBuffer`,
  `ElixirOpentui.NIF` (the FrameBuffer NIF), and `ElixirOpentui.BufferBehaviour`
  are gone. The `backend:` option on `Runtime.start_link/1`, `Renderer.new/3`,
  and `TestRenderer.start_link/1` is gone, as are the `Renderer` `back`,
  `native_buf`, and `backend` fields. The pure Elixir `Buffer` is the only
  render path. `EditBufferNIF` stays because `TextArea` needs it.
- The `claude_animation` and `frame_buffer_demo` demos.
- The `space_dodge`, `checkbox_demo`, `select_demo`, `text_input_demo`, `scroll_box_demo`, `potion_lab`, `agent_driven_form`, and `agent_preferences` demos. `widget_gallery` and `agent_playground` cover them.
- The `example_app/tui_todo` Mix scaffold. Its `todo.exs` now lives at `demo/todo.exs`.

### Changed

- **Breaking:** `ElixirOpentui.Demo.DemoRunner` is now `ElixirOpentui.DemoRunner`.

## [0.1.1] - 2026-04-01

### Fixed

- Component prop reconciliation now correctly updates child component properties
- Live tick timing improvements for smoother animations
- Precompiled NIF download URL now uses compile-time version correctly

### Added

- `Color.hsl/3` helper function for HSL color values
- `tui_todo` example app — a complete todo list TUI application

### Changed

- Standardized demo code comments to ASCII format
- Improved key event pattern matching consistency across demos and example app
- Refactored CLAUDE.md and AGENTS.md for progressive disclosure

[0.2.0]: https://github.com/jyooi/elixir-opentui/releases/tag/v0.2.0
[0.1.1]: https://github.com/jyooi/elixir-opentui/releases/tag/v0.1.1

## [0.1.0] - 2026-03-04

Initial public release.

### Added

- **View DSL** — declarative macros (`panel`, `row`, `column`, `text`) for building terminal UI trees
- **Elm-inspired architecture** — `init/handle_event/render` pattern via `ElixirOpentui.Component`
- **11 widgets** — TextInput, TextArea, Select, TabSelect, Checkbox, ScrollBox, Code (syntax highlighting), Markdown, Diff, LineNumber, and ScrollHelper
- **Flexbox-inspired layout engine** — rows, columns, padding, margin, grow/shrink, alignment, percentage sizing, min/max constraints
- **Zig NIF rendering backend** — double-buffered, diff-based terminal output for minimal flicker
- **Pure Elixir fallback renderer** — everything works without the NIF, just slower
- **Animation system** — timeline-based with 25 easing functions, ~30 FPS live mode
- **Full input handling** — keyboard events, mouse support (SGR 1006), paste detection, Kitty keyboard protocol
- **Terminal capability detection** — progressive enhancement based on terminal features
- **Syntax highlighting** — via Makeup, supports Elixir and TypeScript
- **Markdown rendering** — via Earmark, with headings, lists, code blocks, and blockquotes
- **Precompiled NIF binaries** for 8 platforms (x86_64/aarch64 Linux gnu/musl, macOS, FreeBSD)
- **17 runnable demo examples** in `demo/`
- **57 test files** covering widgets, layout, rendering, input parsing, and animation

[0.1.0]: https://github.com/jyooi/elixir-opentui/releases/tag/v0.1.0
