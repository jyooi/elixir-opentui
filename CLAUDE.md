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

1. Create a `release/vX.Y.Z` branch
2. Trigger the **Precompile NIFs** workflow (`workflow_dispatch`) with the version tag
3. Copy the shasum keyword list from CI output into `lib/elixir_opentui/precompiled.ex`
4. Commit the updated shasums, tag with `vX.Y.Z`, push tag
5. Force source compilation: `ZIGLER_PRECOMPILE_FORCE_RECOMPILE=true mix compile`

See `AGENTS.md` for domain-specific development guidance (widgets, demos, NIFs).
