# Demo Development

## DemoRunner Protocol

Demo modules implement four callbacks for `DemoRunner.run/1` (`lib/elixir_opentui/demo/demo_runner.ex`):

- `init(cols, rows)` — return initial state given terminal dimensions
- `handle_event(event, state)` — return `{:cont, new_state}` or `:quit`
- `render(state)` — return an `Element.t()` tree
- `focused_id(state)` — return the currently focused element's id or nil

Optional: `handle_tick(dt, state)` for live/animated demos (return `{:cont, new_state}` or `:quit`).

## Running Demos

```
mix run demo/name.exs
```

Demo scripts must use `mix run`, not bare `elixir`.

## Terminal I/O Patterns

- **Output**: `:file.write("/dev/tty", iodata)` — bypasses the Erlang IO system for direct ANSI output
- **Terminal size**: `:io.columns()` / `:io.rows()` — not `tput` (subprocess setsid issue)
- **Input**: reader process calls `IO.getn("", 1)` in a loop, sends `{:byte, b}` messages
- **Byte accumulation**: 2ms timeout groups multi-byte escape sequences before `Input.parse`

## BEAM Terminal I/O Gotcha

`:os.cmd("stty ...")` always fails with ENXIO because `erl_child_setup` calls `setsid()`, detaching child processes from the controlling terminal. Raw mode requires `:shell.start_interactive({:noshell, :raw})` (OTP 28+).

Similarly, Port.open children lose `/dev/tty` access — resolve the real device path (e.g. `/dev/pts/3`) via `/proc/self/fd/`.
