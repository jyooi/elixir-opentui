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

## Elixir NIF Wrappers

- `EditBuffer` — struct wrapping the NIF resource reference
- `EditorView` — struct wrapping the NIF resource reference

Both require `@enforce_keys` (canonical pattern). Access the NIF module directly (`EditBufferNIF`) — no adapter layer.

## Testing

Tag NIF-dependent tests with `@tag :nif`. Test files at `test/elixir_opentui/<module>_test.exs`. Ensure `mix compile` succeeds before running NIF tests.

## Force Source Compilation

Skip prebuilt NIFs for local testing:

```
ZIGLER_PRECOMPILE_FORCE_RECOMPILE=true mix compile
```
