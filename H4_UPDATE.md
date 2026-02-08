**FINAL POSITION: Two-Level MVU inside Single Runtime GenServer. Aligned with H1/H2/H3/H5. Initial research in H4_FINDINGS.md.**

**REVISION NOTE**: Original H4 proposed GenServer-per-widget. After H1 findings (single-GenServer runtime, components as data not processes), revised to component state as data inside one process. This matches LiveView's LiveComponent model exactly.

#### Core Model: Two-Level MVU in One Process

**Level 1 -- App MVU** (user writes): `init/1`, `update/2`, `render/1` on app model.
**Level 2 -- Component MVU** (framework provides): Same callbacks for widgets (Input, Select, ScrollBox). State keyed by component ID inside Runtime GenServer state.

```
Runtime GenServer State:
  app_model:        %{username: "", role: nil}       # Level 1
  component_states: %{username => %{cursor: 5, ...}} # Level 2
  dirty:            true                              # needs re-render?
```

#### Event Flow (Single Process)

1. Terminal event -> EventManager -> Runtime mailbox
2. Runtime routes to focused component's `update/2` (direct function call, no message passing)
3. Component returns new state + optional parent event (`{:input_changed, :username, "alice"}`)
4. If parent event: Runtime calls app's `update/2`
5. `dirty = true`
6. Next tick: `render/1` -> expand components -> layout (H3) -> paint -> Zig NIF (H2)

#### Re-Render Triggers

**Dirty flag + tick-based** (30-60 FPS). NOT immediate. NOT change-tracked. NOT VDOM-diffed.
- Events set `dirty: true`. Multiple events between ticks coalesce (rapid typing = one render).
- Full `%Element{}` tree rebuilt every dirty tick. Zig NIF handles cell-level diffing.
- No Elixir-side tree diffing needed -- NIF cell diff is sufficient and far simpler.

#### Rejected Alternatives (with rationale from research)

| Alternative | Why Rejected |
|------------|-------------|
| **Pure MVU** (Ratatouille) | No component-local state. 50+ widgets = unwieldy model. Elm community's top scaling complaint. |
| **React VDOM** reconciliation | Thousands of lines (key reconciliation, fibers). Solves browser problem (millions of DOM nodes) TUI doesn't have (~8K cells). |
| **SolidJS signals** | Needs mutable closures. Redundant in single-process model -- Runtime already knows all state. |
| **GenServer-per-widget** (my initial proposal) | Revised after H1. Process overhead + render coordination bottleneck. LiveView chose single-process for same reasons. |

#### Key Innovation Over Ratatouille

Component-local state alongside app state, same process, keyed by ID. User sees only semantic events. Exactly LiveView's LiveComponent pattern.

```elixir
# User never manages cursor/scroll/dropdown state:
def update(model, {:input_changed, :username, val}), do: %{model | username: val}
# vs Ratatouille where user must track cursor_pos, selection, scroll_offset, undo_stack...
```

#### Analyzed Frameworks

Ratatouille (pure MVU, limited), Bubbletea (MVU -> component trees at scale), ElixirOpentui React (VDOM too complex), ElixirOpentui Solid (signals need mutable closures), **Phoenix LiveView** (our direct model: process + LiveComponents), Scenic (GenServer-per-scene, validates concept but too heavy).

#### Testability

MVU callbacks are pure functions: `state = Input.update(state, {:key, :right}); assert state.cursor == 1`. Integration via TestRuntime (H1): `send_event` + `tick` + `get_component_state`. See H1 test infrastructure for full mapping.

**Confidence: HIGH** -- Validated by Phoenix LiveView, aligned with all hypotheses.
