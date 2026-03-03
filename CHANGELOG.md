# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
