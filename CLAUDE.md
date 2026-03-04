# ElixirOpentui

Terminal UI framework for Elixir with a Zig NIF backend.

## Setup (non-obvious)

- Requires **OTP 28+** (uses `:shell.start_interactive/1`)
- Run `mix zig.get` before first compile to download the Zig toolchain
- **Prebuilt NIFs**: `mix compile` auto-downloads prebuilt `.so` files when shasums are populated in `lib/elixir_opentui/precompiled.ex`. Falls back to source compilation for unlisted platforms.

## Undiscoverable gotchas

- **BEAM terminal I/O**: `:os.cmd("stty ...")` always fails (ENXIO) because `erl_child_setup` calls `setsid()`. Raw mode requires `:shell.start_interactive({:noshell, :raw})`.
- **View DSL scoping**: Variables assigned inside `panel do...end` blocks have macro scoping issues. Compute values BEFORE the block, not inside it. `for` comprehensions are fine.
- **Key events**: All key events from `Input.parse` MUST include `meta: false` — widgets pattern-match on it.
- **Demo scripts**: Must run via `mix run demo/name.exs`, not bare `elixir`.

## Releasing prebuilt NIFs

1. Trigger the **Precompile NIFs** workflow (`workflow_dispatch`) with the version tag (e.g. `v0.1.0`)
2. Workflow compiles 8 platforms, uploads to draft GitHub release, updates `precompiled.ex`, and opens a PR automatically
3. Merge the auto-PR with updated shasums
4. Tag: `git pull && git tag vX.Y.Z && git push origin vX.Y.Z`
5. Undraft: `gh release edit vX.Y.Z --draft=false`
6. Publish: `mix hex.publish && mix hex.publish docs`
7. Force source compilation (for local testing): `ZIGLER_PRECOMPILE_FORCE_RECOMPILE=true mix compile`

## Code Consistency Protocol

### Before ANY Code Change

1. Scan surrounding files (same directory + parent) for existing patterns
2. If you detect conflicting patterns → STOP and ask the human which is canonical
3. Never introduce a third pattern to "resolve" two existing ones
4. Never silently adopt one pattern over another

### For Full Audits

Run the full team audit prompt (4 specialized teammates):

- Teammate 1: Naming & Style
- Teammate 2: Architecture & Patterns
- Teammate 3: Types, Schema & Validation
- Teammate 4: Dead Code & Testing
Always require inter-agent cross-referencing before synthesis.
Always stop for human confirmation before generating fixes.

### Canonical Patterns (updated 2026-03-04)

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

See `AGENTS.md` for domain-specific development guidance (widgets, demos, NIFs).
