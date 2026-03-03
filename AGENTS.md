# Development Guide

## Widget Development

### Component contract

Widgets use the `ElixirOpentui.Component` behaviour:

- `init(props)` — return initial state from props map
- `update(msg, event, state)` — handle messages, return new state
- `render(state)` — return an `Element.t()` tree using the View DSL

### Adding a new widget

A new widget needs four integration points:

1. **Element type** — register the atom (e.g. `:mywidget`) in `Element`
2. **View macro** — add a macro so users can write `mywidget do...end`
3. **Layout measurement** — teach `Layout` how to measure/position the widget
4. **Painter rendering** — teach `Painter` how to draw it to the buffer

### Style system

Layout uses flexbox properties: `width`, `height`, `flex_grow`, `flex_shrink`, `flex_direction`, `padding`, `margin`, `gap`. Colors are `{r, g, b}` tuples. Borders: `:single`, `:double`, `:rounded`, `:heavy`.

### Key events

All key events must include `meta: false` in the map. Widgets pattern-match on this field — omitting it causes silent match failures.

### Testing

ExUnit with `async: true`. Use `describe` blocks to group related cases. Build element trees directly with `Element.new/3` for unit tests.

---

## Demo Creation

### DemoRunner protocol

Demo modules implement four callbacks for `DemoRunner.run/1`:

- `init(width, height)` — return initial state given terminal dimensions
- `handle_event(event, state)` — return `{:cont, new_state}` or `:quit`
- `render(state)` — return an `Element.t()` tree
- `focused_id(state)` — return the currently focused element's id

### Running demos

```
mix run demo/name.exs
```

### Terminal I/O

- Output: `:file.write("/dev/tty", iodata)` — bypasses the Erlang IO system
- Terminal size: `:io.columns()` / `:io.rows()` — not `tput` (subprocess setsid issue)
- Input: reader process calls `IO.getn("", 1)` in a loop, sends `{:byte, b}` messages
- Byte accumulation: 2ms timeout groups multi-byte escape sequences before `Input.parse`

---

## Zig NIF Development

### Zigler pattern

NIF modules use `use Zig` with these options:

- `otp_app: :elixir_opentui` — required
- `resources: [:ResourceName]` — Zig structs exposed as NIF resources
- `dependencies: [name: "./path"]` — vendored Zig dependencies
- `extra_modules: [alias: {dep, :module}]` — re-export modules from dependencies

Use the `~Z` sigil for inline Zig code within the module.

### Vendored Zig sources

Vendored code lives in `zig/`. The entry point for NIF imports from vendored deps is `nif-api.zig`, which re-exports the symbols zigler needs.

### Testing NIFs

Tag NIF-dependent tests with `@tag :nif`. NIF tests may need the compiled artifacts — ensure `mix compile` succeeds before running them.
