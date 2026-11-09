# Zig NIF Development

## Zigler Pattern

NIF modules use `use Zig` with these options:

- `otp_app: :elixir_opentui` — required
- `resources: [:ResourceName]` — Zig structs exposed as NIF resources
- `dependencies: [name: "./path"]` — vendored Zig dependencies
- `extra_modules: [alias: {dep, :module}]` — re-export modules from dependencies

Use the `~Z` sigil for inline Zig code within the module.

## Vendored Zig Sources

Vendored code lives in `zig/opentui/`. The entry point for NIF imports is `zig/opentui/nif-api.zig`, which re-exports the symbols zigler needs.

## Elixir Access

There are no Elixir wrapper structs. `TextArea` holds the raw resource references and calls `EditBufferNIF` directly. Only add a NIF function when a widget needs it.

## Testing

Tag NIF-dependent tests with `@tag :nif`. Test files at `test/elixir_opentui/<module>_test.exs`. Ensure `mix compile` succeeds before running NIF tests.

## Force Source Compilation

A normal build downloads the prebuilt NIF of the last release.
That build ignores local changes to the Zig code in `edit_buffer_nif.ex` and `zig/opentui/`.
Compile from source to test such changes:

```
ZIGLER_PRECOMPILE_FORCE_RECOMPILE=true mix test
```

Tests that need the Zig code of the repository have the `:nif_source` tag.
`test/test_helper.exs` excludes that tag unless `ZIGLER_PRECOMPILE_FORCE_RECOMPILE=true` is set.
CI sets it.

Zig 0.15.2 cannot link an executable against a C runtime that has `.sframe` sections (binutils 2.45 and later).
On such a system the source build stops with `unhandled relocation type R_X86_64_PC64`.
