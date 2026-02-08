**FINAL POSITION: Two-Level MVU inside Single Runtime GenServer (partially supports hypothesis)**

**REVISION**: Originally proposed GenServer-per-widget. After H1 convergence on single-GenServer runtime, revised to: component state as data (not processes) inside one Runtime GenServer. This matches Phoenix LiveView's LiveComponent model. The research below on reactivity models remains valid -- only the process architecture changed.

Pure Elm/MVU is deeply idiomatic for Elixir but insufficient alone for complex TUIs. The recommended architecture is a **two-level MVU with component-local state** -- app-level MVU + component-level MVU, both as function callbacks inside a single Runtime process.

#### 1. Analysis of Existing Reactivity Models

**Ratatouille (Elixir) -- Pure Elm Architecture:**
- Three callbacks: `init/1`, `update/2`, `render/1`. Single model holds ALL state.
- Runtime calls `render/1` after every `update/2`. Subscriptions and Commands for async.
- **Limitation**: No component-local state. Input cursor position, Select open/closed, ScrollBox offset -- ALL in single model. With 50+ widgets, model and update become unwieldy.
- **Limitation**: No component lifecycle. Components are pure view functions rebuilt every render.
- **Strength**: Extremely predictable. Pure function of state. Pattern matching on messages is elegant Elixir.

**Bubbletea (Go) -- Elm Architecture at Scale:**
- Same MVU: `Init()`, `Update(msg) -> (Model, Cmd)`, `View() -> string`
- Scales via nested models: parent contains child models, routes messages down.
- "Model Stack" architecture (bubblon) for independent model composition.
- **Key insight**: Non-trivial Bubbletea apps build a tree of models. Root becomes message router + screen compositor. Effectively component-based architecture wearing an MVU coat.

**ElixirOpentui -- React Reconciler:**
- Custom `react-reconciler` host config translating VDOM ops to Renderable tree mutations.
- Each Renderable has own state and lifecycle. Component catalogue maps JSX tags to constructors.
- **Strength**: Component-local state is natural. Input manages own cursor. Parent never needs to know.
- **Cost**: VDOM diffing overhead. Reconciliation is complex to implement correctly.

**ElixirOpentui -- SolidJS Reconciler:**
- Signal-based fine-grained reactivity. Components run ONCE, then reactive bindings update specific nodes.
- **Key insight**: Signals reduce DOM mutations by 99.9% vs VDOM in benchmarks. But for TUI cells, the gap is much smaller since terminal "DOM" is already a flat cell grid.

**Phoenix LiveView -- Server-Side Reactivity:**
- State in socket assigns (GenServer process). HEEx with change tracking re-renders only changed assigns.
- LiveComponents provide component-local state within a parent LiveView.
- **Directly relevant**: Each LiveView IS a process with own state. LiveComponents = component-local state. This IS our proposed hybrid.

**Scenic (Elixir) -- Graph-Based UI:**
- Each Scene is a GenServer managing a Graph. `push_graph/1` sends to ViewPort.
- Components are Scenes started as child processes. State via `assign/2`.
- **Validates**: Process-per-component works in Elixir for UI. Scenes communicate via events/messages.

#### 2. Proposed Architecture: Hierarchical MVU + Process-Based Components

```
                    App Process (GenServer)
                    +-- Model: %AppState{}, update/2, render/1
                    |
                    +-- Input Widget (GenServer)
                    |   +-- Local: cursor_pos, selection, buffer
                    |   +-- Emits: {:input_changed, id, value}
                    |
                    +-- Select Widget (GenServer)
                    |   +-- Local: open?, highlighted_index
                    |   +-- Emits: {:selection_changed, id, value}
                    |
                    +-- ScrollBox Widget (GenServer)
                        +-- Local: scroll_offset, viewport_size
                        +-- Emits: {:scroll_changed, id, offset}
```

- **App level**: Pure MVU. Single model + update + render. The Ratatouille pattern.
- **Widget level**: Each interactive widget is a GenServer with local state. Handles own events internally. Emits semantic events upward.
- **Bridge**: Render function references widgets by ID. Runtime manages lifecycle (start on render, stop on removal). Widget events arrive as messages to app's `update/2`.

**Elixir code sketch:**
```elixir
defmodule MyApp do
  use ExTUI.App

  def init(_ctx), do: %{username: "", role: nil}

  def update(model, msg) do
    case msg do
      {:input_changed, :username, val} -> %{model | username: val}
      {:selection_changed, :role, val} -> %{model | role: val}
      _ -> model
    end
  end

  def render(model) do
    view do
      panel title: "Form" do
        input id: :username, value: model.username, placeholder: "Name"
        select id: :role, options: ["admin", "user"], value: model.role
      end
      label content: "Hello, #{model.username} (#{model.role})"
    end
  end
end
```

#### 3. Why Not Pure MVU?

- **50+ interactive components**: Model becomes map of maps. Update needs dozens of clauses for widget-internal state.
- **Widget reusability**: Reusable Input in pure MVU requires parent to manage ALL state (cursor, selection, scroll, undo). This is the Elm community's top complaint about nested TEA boilerplate.
- **Elm community consensus**: Richard Feldman says "keep one model as long as you can" but acknowledges local state is sometimes needed, suggesting Web Components as escape hatch. In Elixir, **GenServer processes ARE our escape hatch**.

#### 4. Why Not React-Style VDOM Reconciliation?

- **Implementation complexity**: Correct VDOM reconciler is thousands of lines (key reconciliation, fiber scheduling, effect ordering). Years to mature.
- **Unnecessary for TUI**: ~2000-8000 cells. VDOM solves a browser problem (millions of DOM nodes) we don't have.
- **Non-idiomatic**: VDOM relies on reference equality, memoization hints. These don't translate to immutable Elixir data.

#### 5. Why Not Pure Signal-Based Reactivity?

- **Signals need mutable subscriptions**: SolidJS works via mutable closures. Elixir's immutability means process-per-signal -- viable but complex without proportional benefit at TUI scale.
- **Compile-time transformation**: SolidJS power comes from compiler. Marginal benefit when "DOM" is a cell grid.
- **However**: The CONCEPT maps well. Each widget process IS a signal -- holds state, notifies renderer on change.

#### 6. Key Design Decisions

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| App-level state | MVU (model + update + render) | Idiomatic, predictable, testable |
| Widget-internal state | Process-local (GenServer) | Encapsulation, reusability, lifecycle |
| State notification | Message passing | Native Elixir, no framework magic |
| View diffing | Structural diff on view tree | Simpler than VDOM, sufficient for TUI |
| Subscriptions | GenServer + PubSub | Timers, events, external data = messages |
| Async ops | Task + message back | Same as Ratatouille Commands, LiveView assign_async |

#### 7. Precedent Validation

- **Scenic**: GenServer-per-scene with Graph rendering in Elixir. Validates process-per-component.
- **Phoenix LiveView**: Process with assigns + LiveComponents for local state. Almost exactly our hybrid.
- **Bubbletea at scale**: Nested models converge toward component trees anyway.
- **Ratatouille**: Proves MVU works for simpler TUIs. Our proposal extends it.

**Confidence: HIGH** -- Hybrid validated by multiple production systems across languages.
