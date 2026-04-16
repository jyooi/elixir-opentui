# Agent API

A semantic layer over ElixirOpentui that lets AI agents (or any programmatic
driver) observe and control a running TUI without parsing ANSI. Agents read
a JSON-friendly snapshot of the UI and dispatch high-level actions.

## At a glance

```elixir
{:ok, rt} = ElixirOpentui.Runtime.start_link([])
:ok = ElixirOpentui.Runtime.mount(rt, MyApp)

# Observe
snap = ElixirOpentui.Runtime.snapshot(rt)
email = ElixirOpentui.Runtime.find_widget(rt, :email)

# Act
:ok = ElixirOpentui.Runtime.dispatch(rt, {:set_value, :email, "hi@example.com"})
:ok = ElixirOpentui.Runtime.dispatch(rt, {:toggle, :remember_me})
:ok = ElixirOpentui.Runtime.dispatch(rt, {:click, :submit})
```

`dispatch/2` is synchronous — the next `snapshot/1` reflects the action's
effect with no polling needed.

## Public API

| Function | Purpose |
|---|---|
| `Runtime.start_link(opts)` | Start a Runtime GenServer. `opts` accepts `cols:`, `rows:`, `mode: :headless \| :live`, `backend: :elixir \| :zig`. |
| `Runtime.mount(server, app_module, props \\ %{})` | Initialize with a root component module. |
| `Runtime.snapshot(server)` | Return the full semantic snapshot. |
| `Runtime.dispatch(server, action)` | Apply one action. Returns `:ok`. |
| `Runtime.find_widget(server, id)` | Lookup one widget by id. Returns the node or `nil`. |
| `Accessibility.find_node(snapshot, id)` | Pure lookup helper for a snapshot you already have. |

## Snapshot shape

```elixir
%{
  focused_id: :email,              # id of the currently-focused widget, or nil
  frame: 17,                       # monotonic frame counter
  root: %{
    id: :login,
    type: :panel,
    role: :container,
    focused: false,
    visible: true,
    state: %{title: "Sign In"},    # per-type fields, see below
    children: [ ... ]              # nested node_snapshot()s
  }
}
```

### Scope — what appears in the tree

The walker prunes structural noise and keeps three kinds of nodes:

- **Focusable widgets**: `:input`, `:button`, `:select`, `:checkbox`,
  `:scroll_box`, `:textarea`, `:tab_select`.
- **Static text**: `:text`, `:label` — kept so agents see the labels next to
  inputs.
- **Titled containers**: `:panel` (or any element) with `border_title` set —
  provides section context like "Settings" vs. "Profile".

Plain structural `:box`es without titles collapse; their children spread up
to the nearest meaningful ancestor. This keeps a 50-widget UI from emitting
hundreds of nodes.

### Roles

`role` is a stable ARIA-ish label decoupled from internal `type`:

| type | role |
|---|---|
| `:input`, `:textarea` | `:textbox` |
| `:select` | `:listbox` |
| `:checkbox` | `:checkbox` |
| `:button` | `:button` |
| `:scroll_box` | `:scrollable` |
| `:tab_select` | `:tablist` |
| `:text`, `:label` | `:text` |
| anything else | `:container` |

### Per-widget `state` fields

| type | state fields |
|---|---|
| `:input` | `%{value: String.t, placeholder: String.t}` |
| `:textarea` | `%{placeholder: String.t, value: :via_edit_buffer}` — value is held in a NIF-backed buffer; fetch separately if needed |
| `:select` | `%{options: [String.t], selected: non_neg_integer}` |
| `:checkbox` | `%{checked: boolean, label: String.t}` |
| `:button` | `%{label: String.t}` |
| `:scroll_box` | `%{scroll_top: non_neg_integer}` |
| `:tab_select` | `%{tabs: [String.t], selected: non_neg_integer}` |
| `:text`, `:label` | `%{content: String.t}` |
| titled container | `%{title: String.t}` |
| plain container | `%{}` |

`cursor_pos` and `scroll_offset` on text widgets are **not** exposed —
agents should think in values, not keystrokes.

## Action vocabulary

Actions split into two groups:

### Semantic — direct widget mutation

| Action | Effect |
|---|---|
| `{:focus, id}` | Move focus to widget `id`. |
| `{:set_value, id, string}` | Replace a `:input` / `:textarea` value. Fires `on_change`. |
| `{:select_index, id, n}` | Set a `:select`'s selected index. |
| `{:toggle, id}` | Flip a `:checkbox`. |
| `{:set_checked, id, bool}` | Set a `:checkbox` to a specific state. |
| `{:click, id}` | Focus the target and fire its action. For `:button` with `on_click:` attr, the app message is dispatched. |

### Passthrough — raw events

For widget behaviors bound to specific keystrokes (e.g. `Ctrl+K` kill-line
in `TextInput`). The event shape matches what `ElixirOpentui.Input.parse`
produces.

| Action | Notes |
|---|---|
| `{:key, event}` | `event = %{type: :key, key: key, ctrl:, alt:, shift:, meta: false}`. `key` is an atom for special keys (`:enter`, `:tab`, `:backspace`, …) or a single-char string for printables. |
| `{:mouse, event}` | `event = %{type: :mouse, x:, y:, button:, action:, ...}`. |
| `{:paste, data}` | `data` is a binary. |

Unknown actions are silently dropped (no error). Check `snapshot` after
dispatch to confirm the effect.

## The canonical agent loop

```elixir
def act(rt, action) do
  :ok = ElixirOpentui.Runtime.dispatch(rt, action)
  ElixirOpentui.Runtime.snapshot(rt)
end

# Agent session
initial = ElixirOpentui.Runtime.snapshot(rt)
# ... agent reads initial, decides on action ...
after_click = act(rt, {:click, :login})
# ... agent observes outcome ...
```

For multi-turn agents driving a live Runtime over a network, dispatch and
snapshot can be exposed over TCP / Unix socket / HTTP without any framework
support beyond these two functions.

## Wiring a button so `{:click, :id}` has an effect

`:button` is a bare element with no built-in component state. To make
clicks do something, give it an `on_click:` attr — the Runtime fires that
atom as a message to the app's `update/3` on Enter, Space, or agent click:

```elixir
def render(state) do
  import ElixirOpentui.View

  box do
    button(id: :submit, label: "Submit", on_click: :submit_clicked)
  end
end

def update(:submit_clicked, _event, state) do
  %{state | submitted: true}
end
```

Without `on_click:`, agent `{:click, id}` only moves focus.

## Observing app state

The snapshot covers **widget** state (what's on screen). Business-logic
state in your app module's struct is separate. For now, use:

```elixir
:sys.get_state(rt).app_state
```

This is a test/introspection convenience. Expose a domain-specific getter
on your app if you need this in production.

## Gotchas

- **ID uniqueness matters for focus routing.** If a container (e.g. panel)
  and a focusable child (e.g. button) share the same id, most things still
  work — but make distinct ids a habit. Focus-driven lookups filter by
  widget type, so `{:click, :login}` still finds the button even if a panel
  also has `id: :login`.
- **Dispatch is synchronous, not a cast.** A follow-up `snapshot/1` will
  observe the effect without any delay. No need to sleep.
- **`:textarea` values are opaque in the snapshot.** The marker
  `value: :via_edit_buffer` indicates text exists in a NIF-backed buffer.
  Call the relevant `EditBufferNIF` accessor directly if you need the
  string — this is a deliberate tradeoff to avoid NIF calls on every frame.
- **Tab navigation goes through `EventManager`, not components.**
  `{:key, %{key: :tab, ...}}` moves focus; it is not delivered to the
  focused widget as a keystroke.
- **`focused_id` can be `nil`** before any focus has been set. Dispatch
  `{:focus, some_id}` first if your agent flow depends on having a
  focused widget.
