# Widget Development

## Component Contract

Widgets use the `ElixirOpentui.Component` behaviour (`lib/elixir_opentui/component.ex`):

- `init(props)` — return initial state from props map
- `update(msg, event, state)` — handle messages, return new state
- `render(state)` — return an `Element.t()` tree using the View DSL

## Adding a New Widget

A new widget needs four integration points:

1. **Element type** — register the atom (e.g. `:mywidget`) in `lib/elixir_opentui/element.ex`
2. **View macro** — add a macro in `lib/elixir_opentui/view.ex` so users can write `mywidget do...end`
3. **Layout measurement** — teach `lib/elixir_opentui/layout.ex` how to measure/position the widget
4. **Painter rendering** — teach `lib/elixir_opentui/painter.ex` how to draw it to the buffer
5. **Focus** (if interactive) — add the type to `@focusable_types` in `lib/elixir_opentui/focus.ex`

## Style System

Layout uses flexbox properties: `width`, `height`, `flex_grow`, `flex_shrink`, `flex_direction`, `padding`, `margin`, `gap`. Colors are `{r, g, b}` tuples. Borders: `:single`, `:double`, `:rounded`, `:heavy`.

## Key Events

All key events must include `meta: false` in the map. Widgets pattern-match on this field — omitting it causes silent match failures.

## `_pending` Pattern

Interactive widgets accumulate events in a `_pending` list that is drained by Runtime. Display-only widgets (e.g. text, markdown) must NOT have `_pending` in their init state.

## Existing Widgets

11 widgets in `lib/elixir_opentui/widgets/`: TextInput, Checkbox, Select, ScrollBox, TextArea, Code, Diff, Markdown, TabSelect, LineNumber, BigText.

## Testing

Build element trees directly with `Element.new/3` for unit tests. Test files mirror `lib/` structure at `test/elixir_opentui/<module>_test.exs`.
