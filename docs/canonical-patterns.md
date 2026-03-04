# Canonical Patterns

## Before ANY Code Change

1. Scan surrounding files (same directory + parent) for existing patterns
2. If you detect conflicting patterns → STOP and ask the human which is canonical
3. Never introduce a third pattern to "resolve" two existing ones
4. Never silently adopt one pattern over another

## Canonical Patterns Table (updated 2026-03-04)

| Area | Canonical Pattern | Notes |
|------|-------------------|-------|
| Section comments | `# --- Section Name ---` (ASCII) | No Unicode box-drawing characters |
| Widget events | `_pending` list (drained by Runtime) | Not `send(self(), ...)` |
| Scroll events | `:scroll_up` / `:scroll_down` action atoms | Not `:scroll` + `:direction` |
| NIF wrappers | Direct module access (`EditBufferNIF`) | No adapter layer needed |
| Widget render | View DSL macros (`panel do...end`) | Canonical for all widgets |
| Focusable types | Listed in `@focusable_types` in `focus.ex` | Includes `:tab_select` |
| Error tuples | `{:error, :reason_atom}` | Not bare `:error` |
| Boolean helpers | `foo?` (no `is_` prefix unless guard) | Elixir convention |
| `@type` specs | Must match all `defstruct` fields | Enforced by audit |
| `@enforce_keys` | Required on NIF wrapper structs | EditBuffer, EditorView |
| Test paths | `test/elixir_opentui/<module>_test.exs` | Mirror `lib/` structure |
| Display widgets | No `_pending` in init state | Only interactive widgets use `_pending` |
| `font_name` type | Only implemented fonts (`:tiny`, `:block`, `:pixel`) | No phantom types |
| Buffer coordinates | Two-tier: `u32` cell ops, `i32` viewport ops | Matches upstream OpenTUI |
