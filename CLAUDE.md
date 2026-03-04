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

## Code Consistency Protocol

- Scan surrounding files (same directory + parent) for existing patterns before any code change
- If you detect conflicting patterns → STOP and ask the human which is canonical

## Domain Docs

Read these on-demand when working in a specific area:

- [Canonical Patterns](docs/canonical-patterns.md) — naming, types, and code conventions
- [Widget Development](docs/widget-development.md) — component contract, integration points, style system
- [Demo Development](docs/demo-development.md) — DemoRunner protocol, terminal I/O patterns
- [Zig NIF Development](docs/zig-nif-development.md) — zigler pattern, vendored sources, wrappers
- [Releasing](docs/releasing.md) — prebuilt NIF release workflow
