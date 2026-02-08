# ElixirOpentui -> Elixir: Investigation Findings

## Status: Investigation In Progress

## ElixirOpentui Summary (TypeScript, ~8.4k stars)
- **Core**: Component-based TUI framework with imperative API
- **Rendering**: Native Zig rendering layer, FPS-controlled render loop
- **Layout**: Yoga layout engine (CSS Flexbox for terminals)
- **Components**: Box, Text, Input, Textarea, Select, TabSelect, ScrollBox, Code, Markdown, Diff, Slider, FrameBuffer, ASCIIFont
- **Bindings**: React reconciler, SolidJS reconciler, Core (imperative)
- **Events**: Mouse (click, drag, scroll, hover), Keyboard (keypress, paste), Focus management
- **Colors**: RGBA with alpha blending, hex/CSS names/ints
- **Architecture**: Renderable tree, VNode constructs (deferred instantiation), delegate() for composite components

## Elixir TUI Ecosystem (Prior Art)
- **Ratatouille** - Elm-architecture, most established, uses ex_termbox NIF
- **Raxol** - Component-based, newer
- **Garnish** - Terminal UI framework
- **ElementTUI** - Uses elixir_make, NIF-based
- **TermUI** - Direct mode, component-based
- **term_ui** - Framework for terminal UIs

---

## Hypotheses Under Investigation

### H1: OTP Architecture (Agent: architect)
_Hypothesis: OTP supervision trees with GenServer-per-component provide the ideal architecture for an Elixir TUI framework._

**Findings:**

#### Position: REVISED -- Hybrid architecture, NOT pure GenServer-per-component

After investigating all five existing Elixir TUI frameworks and BEAM process characteristics, I conclude that **GenServer-per-component is the wrong default**. The ideal architecture is a **single-GenServer runtime with OTP supervision at the application level**.

#### Evidence from Existing Frameworks

**1. Ratatouille (805 stars, most mature):**
- Single Task process as runtime loop (`use Task, restart: :transient`)
- Entire application model lives in one recursive `loop/1` function
- EventManager and Window are separate GenServers
- Components are pure data -- View DSL builds element trees as plain structs
- No per-component processes. Default interval: 500ms (2 FPS).

**2. Garnish (51 stars, SSH-focused):**
- One process per SSH connection via `:ssh_server_channel` behaviour
- Within a connection: single-process Elm architecture (init/handle_key/render)
- Components are pure view elements, not processes

**3. TermUI (125 stars, newest):**
- Actually implements GenServer-per-component via `TermUI.ComponentServer`
- Has `TermUI.ComponentSupervisor` (DynamicSupervisor)
- Central `TermUI.Runtime` GenServer coordinates at 16ms intervals (60 FPS)
- Uses `gen_stage` for event backpressure
- Most complex architecture; newest and least battle-tested

**4. Raxol (31 stars):**
- Elm Architecture core with component wrappers
- Not process-per-component

**5. Phoenix LiveView (gold standard comparison):**
- One GenServer per user connection, NOT per component
- LiveComponents are render functions with state tracked in parent process
- Most battle-tested Elixir UI-over-processes system

#### BEAM Process Overhead Analysis

| Metric | Value | Source |
|--------|-------|--------|
| Process memory | 327 words (~2.6KB) minimum | Erlang docs OTP 27 |
| GenServer realistic overhead | ~3-5KB per process | Includes OTP state/mailbox |
| Local message send | ~0.1-0.5 us | BEAM benchmarks |
| GenServer.call round-trip | ~1-5 us | Includes scheduling |
| 100 components x call | 100-500 us (0.3-1.5% of 33ms) | Calculated |
| 1000 components x call | 1-5 ms (3-15% of 33ms) | **Problematic** |

#### Why GenServer-Per-Component Fails for TUI

1. **Render coordination bottleneck**: At 30 FPS, all component states must be collected within 33ms. Sequential GenServer.call = serial bottleneck. Parallel Task.async_stream = coordination overhead. Both degrade with component count.

2. **State consistency**: Component A renders at T=0, Component B at T=5ms. The rendered tree is temporally inconsistent. A single process renders atomically.

3. **Supervision false promise**: If a Text component crashes, what does "restart it" mean? You need to re-render the whole tree anyway. Supervision adds nothing for stateless display components.

4. **Counter-evidence from LiveView**: The most successful Elixir UI framework deliberately chose one process per connection, not per component.

5. **GenServer bottleneck pattern**: A GenServer handles one message at a time. When the render loop needs to read 100+ component states, each component GenServer becomes a serialization point. The well-documented "avoiding GenServer bottlenecks" pattern from production systems (Cogini, Duffel, Klarna) shows this causes latency spikes under load.

#### Recommended Architecture

```
Application Supervisor (one_for_one)
|
+-- TUI.Runtime (GenServer)
|     - Holds full component tree as data
|     - Render tick via Process.send_after at 16-33ms
|     - Events processed synchronously in handle_info
|     - Calls NIF renderer with computed diff
|     - Stateful component state in map within GenServer state
|
+-- TUI.EventManager (GenServer)
|     - Reads terminal input (stdin or NIF)
|     - Parses escape sequences into structured events
|     - Sends events to Runtime via message passing
|
+-- TUI.AsyncSupervisor (DynamicSupervisor)
      - For async operations (HTTP, file I/O, timers)
      - Task processes send results back to Runtime
      - THIS is where OTP supervision shines
```

**Component state model:**
- **Stateless (Box, Text)**: Pure functions. Props in, render elements out.
- **Stateful (Input, Select, ScrollBox)**: State in map within Runtime GenServer state, keyed by component ID.
- **Async effects**: Tasks under DynamicSupervisor. Results sent to Runtime. Fault-tolerant.

**Render loop**: `Process.send_after(self(), :tick, @frame_interval)` in Runtime. Each tick: check dirty flag, compute layout, diff, render via NIF.

**Event routing**: Runtime walks focus chain to find target component, calls handler function in same process (no message passing overhead).

#### Scalability Escape Hatches

If a single Runtime GenServer becomes a bottleneck (unlikely for TUI with <1000 components):
- Move read-heavy component state to ETS with `:protected` access
- Use `persistent_term` for truly static configuration
- Split event parsing into a separate GenServer (already in the architecture)

#### Testing Architecture: How OTP Maps to Test Infrastructure

The single-GenServer Runtime is **highly testable** -- more so than GenServer-per-component, because all state is accessible from one process.

**ElixirOpentui test infrastructure mapping:**

| ElixirOpentui Test Concept | Elixir Equivalent | OTP Mechanism |
|---|---|---|
| `createTestRenderer(cols, rows)` | `TestRuntime.start_link(root: Comp, cols: 80, rows: 24)` | GenServer under ExUnit test process |
| `renderOnce()` | `TestRuntime.tick(runtime)` | `GenServer.call(runtime, :tick)` -- synchronous |
| `mockMouse.click(x, y)` | `TestRuntime.send_event(runtime, {:mouse, :click, x, y})` | `GenServer.call` for sync processing |
| `MockInput.keyPress("a")` | `TestRuntime.send_event(runtime, {:key, ?a})` | Events are plain data |
| Frame capture | `TestRuntime.capture_frame(runtime)` | NIF returns ANSI instead of writing stdout |
| `renderer.element` (tree) | `TestRuntime.get_tree(runtime)` | `GenServer.call` returns element structs |

**Key testing advantages of single-GenServer architecture:**

1. **No Process.sleep needed**: `GenServer.call` is synchronous. `TestRuntime.tick(runtime)` processes all pending events and renders before returning. Zero race conditions (same pattern as TermUI's `Runtime.sync/2`).

2. **Dependency injection for IO**: Runtime accepts renderer and event source as init args:
```elixir
# Production: Runtime.start_link(root: MyApp, renderer: RenderNif, events: StdinReader)
# Test:       Runtime.start_link(root: MyApp, renderer: TestCapture, events: TestEvents)
```

3. **Direct component state inspection**: All state in one GenServer state map:
```elixir
state = TestRuntime.get_component_state(runtime, "my_input")
assert state.value == "hello"
```

4. **Deterministic lifecycle testing**: Components are functions called by Runtime. No process startup races. Destroy-during-render is testable because render runs synchronously.

5. **Focus/event routing**: Focus chain is data. Tests verify routing by sending events and checking which component handled them.

6. **Async effects**: Tasks under DynamicSupervisor need `TestRuntime.flush_async(runtime)` helper to await completion before assertions.

#### Conclusion

**H1 is PARTIALLY SUPPORTED.** OTP supervision is valuable at the application level (Runtime, EventManager, AsyncSupervisor) but GenServer-per-component is an anti-pattern for TUI rendering. The process-per-X pattern works for independent connections (Phoenix channels, SSH sessions) but fails for tightly-coupled render trees needing frame-consistent state. Follow LiveView's proven model: one GenServer owns the UI state, with OTP providing fault tolerance around it.

### H2: Rendering Strategy (Agent: renderer)
_Hypothesis: A NIF-based native rendering layer (Zig/Rust) is necessary for competitive performance, as pure Elixir ANSI rendering will be too slow for 30+ FPS._

**Findings:**

#### What ElixirOpentui's Zig Layer Actually Does
ElixirOpentui uses a three-tier architecture: TypeScript (component logic) -> FFI -> Zig (rendering hot path). The Zig layer handles:
1. **Double-buffered cell arrays** - Two buffers (current frame, next frame) of fixed-size cell structs
2. **Frame diffing** - Cell-by-cell comparison to identify only changed regions
3. **ANSI escape sequence generation** - With run-length encoding (adjacent identical styles combine into one escape command)
4. **Buffered stdout write** - Single batched write per frame to minimize syscalls and flicker
5. **Hit grid computation** - Screen coordinate -> component ID mapping for mouse events
6. **Native text buffer** - Rope data structure for efficient text editing

The TypeScript layer handles component tree traversal, Yoga layout calculation, and event routing. This division achieves sub-millisecond frame times and 60+ FPS.

#### Performance Analysis: Can Pure Elixir Hit 30 FPS?

**Data volume calculation (per frame):**
- Typical terminal: 80x24 = 1,920 cells (small) to 200x60 = 12,000 cells (large)
- Per cell: character (1-4 bytes UTF-8) + fg color (4 bytes RGBA) + bg color (4 bytes) + attributes (1 byte) ~= 13 bytes
- Total buffer size: 25KB (small) to 156KB (large)
- ANSI output per full redraw: ~20 bytes/cell average = 38KB to 240KB
- With diffing (typical 5-15% change): 2KB to 36KB actual output per frame

**33ms budget (30 FPS) breakdown (revised after H3 layout findings):**
1. Element tree construction (render callback): ~100us
2. Layout calculation: ~50us (pure Elixir, per H3 -- 500 nodes at ~100ns/node)
3. Painter tree walk + cells binary construction: ~200us
4. NIF clear + put_cells: ~21us (memset + memcpy in Zig)
5. NIF render_frame (diff + ANSI gen + stdout write): ~300us
6. Total: ~671us per frame = well under 1ms = 1490 FPS theoretical max

**Pure Elixir feasibility assessment:**
- IO.write with iodata/IO lists is well-optimized in BEAM -- zero-copy, no intermediate strings
- Elixir binary pattern matching is efficient for cell comparison
- IO.ANSI module provides escape sequence primitives
- BEAM IO subsystem uses port drivers for stdout (efficient kernel-level writes)
- Raxol claims ~500us per frame for pure Elixir rendering on Windows, ~50us with termbox2 NIF on Unix

**Verdict: Pure Elixir CAN likely achieve 30 FPS for most TUI scenarios, BUT a Zig NIF provides a meaningful performance margin.**

The critical insight: buffer diffing on 12,000 cells is a tight loop comparing struct fields. In Zig, this is a cache-friendly linear scan completing in microseconds. In Elixir, each cell comparison involves pattern matching on immutable terms with potential GC pressure. The gap widens with complex UIs and high refresh rates.

#### Recommended Architecture: Hybrid with Zig NIF for Rendering Hot Path

**NIF boundary (Zig side):**
- Double-buffered cell grid (owned by NIF, not copied across boundary)
- Frame diff algorithm (cell-by-cell comparison)
- ANSI escape sequence generation with RLE optimization
- Batched stdout write
- Hit grid for mouse targeting

**Elixir side:**
- Component tree and lifecycle management
- Event routing and input parsing (keyboard/mouse via StdinBuffer equivalent)
- Layout calculation (delegated to Yoga NIF or Elixir-side -- see H3)
- Application state and business logic
- Render scheduling (GenServer-based render loop with configurable FPS cap)

**Full rendering pipeline (DSL -> terminal):**
```
%Element{} tree   ->  Layout NIF    ->  Painter (Elixir)  ->  Render NIF  ->  Terminal
(api-design DSL)     (Yoga/custom)     (protocol dispatch)   (diff+flush)    (stdout)
```

1. DSL produces `%Element{}` tree (pure data, H5)
2. Layout NIF computes positions: `%LayoutNode{id, x, y, w, h}` (H3)
3. Elixir `Painter` protocol dispatches on element type, collects cells into binary
4. `RenderNif.put_cells(ref, binary)` -- ONE NIF crossing for all cells
5. `RenderNif.render_frame(ref)` -- diff + ANSI + stdout write

Step 3 (Painter) is in Elixir because element painting is polymorphic dispatch (box draws borders, text draws characters, input draws cursor). The NIF handles the tight loops (diffing, ANSI gen, stdout).

**NIF API surface (thin boundary):**
```
# Elixir calls into Zig NIF:
RenderNif.init(cols, rows) -> ref           # Initialize double buffer
RenderNif.put_cell(ref, x, y, char, fg, bg, attrs) # Write single cell
RenderNif.put_cells(ref, cells_binary)      # Batch write (preferred, one NIF crossing)
RenderNif.fill_rect(ref, x, y, w, h, char, fg, bg, attrs) # Fill rectangle (backgrounds/borders)
RenderNif.render_frame(ref) -> :ok          # Diff + generate ANSI + write stdout
RenderNif.resize(ref, cols, rows) -> :ok    # Handle terminal resize
RenderNif.get_hit_id(ref, x, y) -> id       # Mouse hit testing
RenderNif.clear(ref) -> :ok                 # Clear next buffer
```

**Why Zig specifically:**
- ElixirOpentui's existing Zig code (~30% of codebase) can be partially reused
- Zigler library provides excellent Elixir-Zig integration with dirty scheduler support
- Zig's comptime and no hidden allocations make NIF safety easier to guarantee
- Zig can directly include C headers (erl_nif.h) via @cImport

#### NIF Safety Considerations
- **Dirty CPU scheduler**: Frame rendering should use `dirty_cpu` mode. A full diff+render on 12K cells takes <1ms in Zig but we want the safety margin. Dirty CPU schedulers don't block BEAM's normal schedulers.
- **No long-running NIF risk**: Each render_frame call is bounded by screen size (max ~12K cells). Even worst case is well under 1ms in native code.
- **Crash protection**: Zig's safety checks (bounds checking, null safety) prevent most crash vectors. If the NIF does crash, it takes down the BEAM -- but this is mitigable via the "sacrificial node" pattern (run rendering in a separate Erlang node supervised by the main node).
- **Memory ownership**: Cell buffers live in NIF-managed memory, not BEAM heap. Only small iodata crosses the boundary for put_cell calls. The render_frame NIF writes directly to stdout, no data returns to Elixir.
- **Zigler integration**: Zigler v0.15+ provides threaded mode, dirty_cpu/dirty_io modes, and automatic type marshalling. It compiles Zig inline within Elixir modules.

#### Comparison with Prior Art
| Framework | Rendering | Approach | Performance |
|-----------|-----------|----------|-------------|
| ElixirOpentui | Zig NIF (from TypeScript via FFI) | Double buffer + diff + RLE ANSI | 60+ FPS |
| Ratatouille | ex_termbox C NIF (termbox lib) | Cell grid via NIF, batch present() | ~30 FPS |
| Raxol | termbox2 NIF (Unix) / pure Elixir (Win) | Dual backend | 50us (NIF) / 500us (pure) per frame |
| Garnish | Pure Elixir (forked from Ratatouille view code) | ANSI escape sequences via IO.write | Adequate for SSH apps |
| libvaxis (Zig) | Pure Zig | Double buffer, buffered writer, no terminfo | 60+ FPS |

#### Testing Strategy for the Rendering NIF

ElixirOpentui's buffer.test.ts covers Unicode encoding, drawChar, alpha blending, and cell operations -- all tightly coupled to the native layer. Here's the strategy for testing the Zig NIF from Elixir ExUnit:

**1. NIF inspection functions (test-only API surface):**
```
RenderNif.get_cell(ref, x, y) -> {char, fg, bg, attrs}  # Read cell from buffer
RenderNif.get_buffer_snapshot(ref) -> binary             # Dump entire buffer
RenderNif.render_frame_capture(ref) -> iodata            # Return ANSI output instead of writing stdout
```
The key: `render_frame` normally writes to stdout. `render_frame_capture` returns the ANSI output as a binary for assertion in tests. This enables exact escape sequence verification.

**2. Three test levels:**

| Level | What | How | Maps to ElixirOpentui tests |
|-------|------|-----|----------------------|
| NIF unit | Cell ops, diffing, ANSI gen | ExUnit + get_cell/get_buffer_snapshot | buffer.test.ts |
| Integration | Full pipeline (tree->layout->buffer->ANSI) | TestRenderer with captured output | renderable.test.ts |
| Visual regression | ANSI output matches snapshots | render_frame_capture + snapshot files | Manual/CI |

**3. TestRenderer (Elixir equivalent of createTestRenderer):**
```elixir
defmodule ElixirOpentui.TestRenderer do
  def create(cols \\ 80, rows \\ 24) do
    ref = RenderNif.init(cols, rows)
    %TestRenderer{ref: ref, cols: cols, rows: rows, frames: []}
  end

  def render_once(tr, view_tree) do
    # Layout tree -> walk tree -> populate NIF buffer -> capture ANSI
    ansi = RenderNif.render_frame_capture(tr.ref)
    %{tr | frames: [ansi | tr.frames]}
  end

  def assert_cell(tr, x, y, expected_char) do
    {char, _, _, _} = RenderNif.get_cell(tr.ref, x, y)
    assert char == expected_char
  end

  def assert_text_at(tr, x, y, expected_string) do
    # Read consecutive cells, compare string
  end
end
```

**4. Buffer test mapping (buffer.test.ts -> ExUnit):**
- **Unicode**: put_cell with CJK/emoji, verify get_cell returns correct codepoint + wide-char flag
- **drawChar**: put_cell at positions, verify via get_cell read-back
- **Alpha blending**: put_cell with RGBA alpha < 255 over existing cell, verify blended color via get_cell
- **Diff correctness**: populate buffer, render, change one cell, render again -- verify output only contains the changed cell's escape sequence
- **Resize**: resize buffer, verify new dimensions, verify old content handled correctly

**5. Frame diff test example:**
```elixir
test "diff only emits changes" do
  tr = TestRenderer.create(10, 5)
  for x <- 0..9, y <- 0..4, do: RenderNif.put_cell(tr.ref, x, y, ?A, fg, bg, 0)
  full_output = RenderNif.render_frame_capture(tr.ref)

  RenderNif.put_cell(tr.ref, 5, 3, ?B, fg, bg, 0)
  diff_output = RenderNif.render_frame_capture(tr.ref)

  assert byte_size(diff_output) < byte_size(full_output) / 5
  assert diff_output =~ "B"
end
```

**6. Zig-native tests (complementary):**
Zig's built-in test framework should also cover core algorithms. These run during `mix compile` via Zigler and catch bugs before the Elixir boundary:
```zig
test "diff detects single cell change" {
    var buf = Buffer.init(10, 5);
    // fill, swap, change one cell, compute diff
    try std.testing.expectEqual(diff.changed_count, 1);
}
```

**7. Hit grid tests (renderer.mouse.test.ts mapping):**
```elixir
test "hit grid maps coordinates to component IDs" do
  tr = TestRenderer.create(80, 24)
  # Render view with positioned components carrying hit IDs
  assert RenderNif.get_hit_id(tr.ref, 5, 3) == :button_a
  assert RenderNif.get_hit_id(tr.ref, 40, 10) == :panel_b
  assert RenderNif.get_hit_id(tr.ref, 0, 0) == nil
end
```

#### Position Statement
**The hypothesis is PARTIALLY SUPPORTED.** A NIF is not strictly *necessary* for 30 FPS -- pure Elixir can likely achieve it for simple to moderate UIs. However, a Zig NIF is strongly *recommended* because:
1. It provides 10-100x headroom on the rendering hot path, enabling 60+ FPS
2. It enables reuse of ElixirOpentui's battle-tested Zig rendering code
3. The NIF boundary is clean and narrow (5-7 functions + test helpers), minimizing safety risk
4. It keeps the BEAM focused on what it does best (concurrency, state, events) while native code handles what it does best (tight loops over contiguous memory)
5. Dirty schedulers make the integration safe for BEAM scheduling
6. The data volume is small enough that NIF overhead is negligible relative to rendering work
7. The NIF is fully testable from ExUnit via inspection functions and output capture

### H3: Layout Engine (Agent: layout)
_Hypothesis: We must port or bind to Yoga layout engine for true Flexbox support. A simpler custom layout system would be insufficient._

**Findings:**

**VERDICT: REJECTED -- We do NOT need Yoga. Pure Elixir "Flexbox Lite" recommended, Taffy (Rust NIF) as optional Phase 2. Full details in H3_FINDINGS.md.**

ElixirOpentui uses ~10 Yoga properties (flexDirection, flexGrow/Shrink, justify/align, gap, padding, margin, width/height, absolute position). Absent: flex-wrap, align-content, order, grid, float. Terminal simplifies dramatically: monospace grid, integer coords, no reflow.

**Options**: Yoga C NIF rejected (slowest: 191-4896 ns/node, complex FFI, C++ crash risk). Taffy Rust NIF good fallback (39-1098 ns/node, Rustler-safe). **Pure Elixir recommended** (<600 lines for core flexbox per reference TS impl, 3-pass algo).

**Performance**: 500 nodes at ~100ns/node = 50us = 0.15% of 33ms frame budget. Layout is NOT the bottleneck. Keep in Elixir for debuggability.

**Caching**: Dirty-flag propagation + hash-keyed cache = >90% hit rate.

**Architecture**: Phase 1 pure Elixir (~800-1200 lines). Phase 2 Taffy NIF if flex-wrap/grid needed.

**Cross-hypothesis**: Pure function fits H1 single-GenServer. Separate from H2 Zig render NIF (not bottleneck). Props via H5 DSL keywords.

### H4: Reactivity Model (Agent: reactivity)
_Hypothesis: An Elm-architecture (Model-View-Update) like Ratatouille is more idiomatic for Elixir than React-like reconciliation or SolidJS-like signals._

**Findings:**

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

### H5: API Design (Agent: api-design)
_Hypothesis: We should design an idiomatic Elixir API using macros/DSL rather than mirroring ElixirOpentui's TypeScript API directly._

**Findings:**

**VERDICT: CONFIRMED -- An idiomatic Elixir DSL is strongly preferred over mirroring the TypeScript API. A layered approach with a low-level functional core + macro DSL + optional sigil template layer is recommended.**

#### Prior Art Analysis

**1. Ratatouille (Elm-arch TUI)**
- Uses `import Ratatouille.View` for a macro-based DSL
- Elements are functions/macros that produce `%Element{}` structs
- Multiple forms: `label()`, `label(content: "hi")`, `label do ... end`, `label([size: 12], [child()])`
- Views are plain Elixir data -- structs with `:tag`, `:attributes`, `:children`
- DSL is syntactic sugar over struct construction; no magic
- Strengths: familiar to Elixir devs, composable, works with `for`/`case`/`if`
- Weaknesses: limited components, 12-column grid only, no flexbox

**2. Scenic (OpenGL UI framework)**
- `Graph.build() |> text("Hello", translate: {20,80}) |> button("Click")` pipeline API
- Compile-time graph building via `@graph` module attributes
- Components are GenServers (`use Scenic.Scene` / `use Scenic.Component`)
- `push_graph/1` sends graph to viewport for rendering
- `Graph.modify/3` for targeted updates by ID
- Strengths: compile-time optimization, pipeline-friendly, clear lifecycle
- Weaknesses: manual positioning (transforms not layout), imperative feel

**3. Phoenix LiveView HEEx**
- `~H` sigil for HTML-aware templates with Elixir expressions in `{...}`
- Function components: any function taking `assigns` returning `~H`
- `attr/3` macro for declarative attribute declarations with types/defaults
- `slot/3` macro for named slot definitions
- Diff-tracking aware -- only re-renders changed assigns
- Strengths: familiar HTML-like syntax, excellent tooling, battle-tested

**4. Surface**
- Extends LiveView with `~F` sigil and `.sface` template files
- `prop`, `data`, `slot` macros for declarative component API
- Compile-time validation and type checking
- Strengths: strongest component model in Elixir ecosystem

#### Proposed API Design: Three Layers

**Layer 1: Functional Core (data-oriented, no macros)**
```elixir
alias ElixirOpentui.Element, as: E

E.box([width: 40, padding: 2], [
  E.text([content: "Hello, World!", bold: true]),
  E.text([content: "Press q to quit", color: :dim])
])
# Returns: %Element{tag: :box, attrs: %{width: 40, padding: 2}, children: [...]}
```
This is the foundation. Everything compiles down to `%Element{}` structs. Any Elixir dev can build UIs by constructing data directly. This mirrors how Ratatouille works under the hood.

**Layer 2: Macro DSL (ergonomic, the primary API)**
```elixir
import ElixirOpentui.View

view do
  box width: 40, padding: 2, direction: :column do
    text content: "Hello, World!", bold: true
    text content: "Press q to quit", color: :dim
  end
end

# All standard Elixir control flow works naturally:
box direction: :row do
  for tab <- @tabs do
    box padding_x: 2, border: (if tab == @active, do: :bold, else: :normal) do
      text content: tab.label
    end
  end
end

# Multiple forms (same as Ratatouille):
text(content: "simple")                    # just attributes
text do ... end                             # block with children
text([bold: true], [text(content: "hi")])  # explicit attrs + children list
```

**Layer 3: TUI Sigil (optional, template-style -- NOT v1 priority)**
```elixir
~TUI"""
<box width={40} padding={2} direction="column">
  <text bold>Hello, World!</text>
  <text color="dim">Press q to quit</text>
</box>
"""
```
Provides migration path for LiveView/HEEx developers. Low priority for v1.

#### Component Definition: Two-Tier Model (aligned with H1 + H4)

Per H4's hybrid MVU + H1's single-Runtime, two component tiers:

**Tier 1: `use ElixirOpentui.App` -- MVU at app level (single Runtime GenServer)**
```elixir
defmodule MyApp do
  use ElixirOpentui.App
  def init(_ctx), do: %{username: "", count: 0}
  def update(model, msg) do
    case msg do
      {:input_changed, :username, val} -> %{model | username: val}
      :increment -> %{model | count: model.count + 1}
      _ -> model
    end
  end
  def render(model) do
    view do
      box direction: :column, gap: 1 do
        input id: :username, value: model.username, placeholder: "Name"
        text content: "Hello, #{model.username}! Count: #{model.count}"
        button on_click: :increment do text content: "+" end
      end
    end
  end
end
```

**Tier 2: `use ElixirOpentui.Widget` -- GenServer for interactive widgets**
```elixir
defmodule ElixirOpentui.Widgets.Input do
  use ElixirOpentui.Widget
  attr :value, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :on_change, :event

  def init(attrs), do: %{cursor: 0, buffer: attrs.value}
  def handle_event(%{key: char}, state) when is_binary(char) do
    new_buf = String.slice(state.buffer, 0, state.cursor) <> char <>
              String.slice(state.buffer, state.cursor..-1//1)
    new_state = %{state | buffer: new_buf, cursor: state.cursor + 1}
    emit({:on_change, new_state.buffer})
    new_state
  end
  def render(state, _attrs), do: text(content: state.buffer, cursor: state.cursor)
end
```

**Architecture:**
- **App** (Tier 1): Single Runtime GenServer with MVU callbacks. Per H1 (LiveView model).
- **Widgets** (Tier 2): Separate GenServer per interactive widget (Input, Select, ScrollBox). Local state for cursor/scroll/selection. Emits semantic events upward. Runtime manages lifecycle. Per H4 (hybrid MVU).
- **Display elements** (Box, Text, Label): Pure data structs from DSL. No process, no state.

#### Event Handling: Message-Based + Callbacks

```elixir
# Message-based (idiomatic Elixir, works with OTP)
def update(state, {:event, %{key: :enter}}), do: ...

# Callback-based (attribute-driven, for simple cases)
text_input placeholder: "Search...",
  on_change: fn value -> send(self(), {:search, value}) end,
  on_submit: :search_submitted
```

Atoms as event names (`:search_submitted`) become messages to the component's `update/2`.

#### Protocol for Custom Renderables

```elixir
defprotocol ElixirOpentui.Renderable do
  @spec render(t) :: ElixirOpentui.Element.t()
  def render(term)
end

defimpl ElixirOpentui.Renderable, for: MyApp.User do
  import ElixirOpentui.View
  def render(user) do
    box direction: :row, gap: 2 do
      text content: user.name, bold: true
      text content: user.email, color: :dim
    end
  end
end
```

#### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Primary API | Macro DSL (Layer 2) | Matches Ratatouille, Scenic, ExUnit -- idiomatic Elixir |
| Data representation | `%Element{}` structs | Immutable, inspectable, serializable, testable |
| Attributes | Keyword lists | Elixir convention: `[width: 40, bold: true]` |
| Children | Block (`do/end`) or list | Both supported like Ratatouille |
| Components | Behaviour + macro | `use ElixirOpentui.Component` like `use GenServer` |
| Events | Messages (atoms/tuples) | OTP-native, composable with GenServer |
| Custom rendering | Protocol | `Renderable` protocol for extensibility |
| Layout props | CSS-like keywords | `:direction`, `:justify`, `:align`, `:gap`, `:padding` |
| TypeScript mirror? | **No** | Elixir devs expect DSLs, not `Box({width: 40}, Text({content: "Hello"}))` |

#### Why NOT Mirror TypeScript

ElixirOpentui TS: `Box({width: 40}, Text({content: "Hello"}))`
Naive Elixir: `box(%{width: 40}, [text(%{content: "Hello"})])`

This would be unidiomatic because:
1. Elixir uses keyword lists not maps for options: `[width: 40]` not `%{width: 40}`
2. Elixir has `do/end` blocks making nesting natural
3. Elixir frameworks universally use DSL macros (ExUnit, Phoenix, Ecto, Scenic)
4. The TS API works within JS constraints; Elixir has different strengths
5. Macro DSL enables compile-time validation that direct functions cannot

#### Test API Design (ElixirOpentui test suite equivalents)

ElixirOpentui's test infra uses `createTestRenderer`, `mockMouse`, `mockInput`, `renderOnce`, and frame capture. Here's the Elixir equivalent:

**TestRenderer -- headless rendering for assertions**
```elixir
defmodule ElixirOpentui.Test do
  defmacro __using__(_opts) do
    quote do
      import ElixirOpentui.Test
      import ElixirOpentui.View
    end
  end

  def create_test_renderer(opts \\ []) do
    cols = Keyword.get(opts, :cols, 80)
    rows = Keyword.get(opts, :rows, 24)
    ElixirOpentui.TestRenderer.start_link(cols: cols, rows: rows)
  end

  def render_once(renderer, element),
    do: ElixirOpentui.TestRenderer.render(renderer, element)

  def get_frame(renderer),
    do: ElixirOpentui.TestRenderer.get_frame(renderer)

  def get_cell(renderer, x, y),
    do: ElixirOpentui.TestRenderer.get_cell(renderer, x, y)

  defmacro assert_frame_contains(renderer, text) do
    quote do
      frame = ElixirOpentui.Test.get_frame(unquote(renderer))
      joined = Enum.join(frame)
      assert String.contains?(joined, unquote(text)),
        "Expected frame to contain #{inspect(unquote(text))}\nFrame:\n#{Enum.join(frame, "\n")}"
    end
  end
end
```

**MockInput and MockMouse**
```elixir
defmodule ElixirOpentui.Test.MockInput do
  def send_key(renderer, key), do: inject(renderer, {:key, key})
  def send_key(renderer, key, mods), do: inject(renderer, {:key, key, mods})
  def send_text(renderer, text), do: inject(renderer, {:text, text})
  def send_paste(renderer, content), do: inject(renderer, {:paste, content})
  defp inject(renderer, event), do: ElixirOpentui.TestRenderer.inject_event(renderer, event)
end

defmodule ElixirOpentui.Test.MockMouse do
  def click(renderer, x, y), do: inject(renderer, :click, x, y)
  def scroll(renderer, x, y, dir, amt \\ 3), do: inject(renderer, {:scroll, dir, amt}, x, y)
  def move(renderer, x, y), do: inject(renderer, :move, x, y)
  def drag(renderer, {x1,y1}, {x2,y2}) do
    inject(renderer, :press, x1, y1)
    inject(renderer, :move, x2, y2)
    inject(renderer, :release, x2, y2)
  end
  defp inject(renderer, type, x, y),
    do: ElixirOpentui.TestRenderer.inject_event(renderer, {:mouse, type, x, y})
end
```

**Example test mapping from ElixirOpentui TS to Elixir**
```elixir
# TS: const renderer = createTestRenderer({cols: 40, rows: 10})
#     renderer.render(Box({width: 20}, Text({content: "Hello"})))
#     expect(renderer.getFrame()).toContain("Hello")

defmodule MyApp.BoxTest do
  use ExUnit.Case, async: true
  use ElixirOpentui.Test

  test "renders text inside a box" do
    {:ok, r} = create_test_renderer(cols: 40, rows: 10)
    render_once(r, box(width: 20, do: text(content: "Hello")))
    assert_frame_contains(r, "Hello")
  end

  test "handles mouse click on button" do
    {:ok, r} = create_test_renderer()
    render_once(r, button(on_click: :clicked, do: text(content: "Click me")))
    MockMouse.click(r, 5, 0)
    render_once(r, button(on_click: :clicked, do: text(content: "Click me")))
    assert_received {:event, :clicked}
  end
end
```

**ElixirOpentui test file -> Elixir module mapping**

| ElixirOpentui Test | Elixir Equivalent | Approach |
|---|---|---|
| `buffer.test.ts` | `ElixirOpentui.BufferTest` | NIF cell write/read via Elixir wrapper |
| `renderable.test.ts` | `ElixirOpentui.ElementTest` | Pure `%Element{}` struct tree ops |
| `yoga-setters.test.ts` | `ElixirOpentui.Layout.YogaTest` | NIF integration; compare layout outputs |
| `renderer.input.test.ts` | `ElixirOpentui.Input.ParserTest` | Pure function: binary -> event structs |
| `renderer.mouse.test.ts` | `ElixirOpentui.MouseTest` | MockMouse + TestRenderer hit testing |
| `renderer.focus.test.ts` | `ElixirOpentui.FocusTest` | MockInput tab/focus assertions |
| `scrollbox.test.ts` (x3) | `ElixirOpentui.ScrollBoxTest` | TestRenderer + large content scrolling |
| `opacity.test.ts` | `ElixirOpentui.OpacityTest` | Buffer NIF alpha blending |
| `editbuffer.test.ts` | `ElixirOpentui.EditBufferTest` | Pure data: text buffer operations |

**Testing principles:**
1. `async: true` -- TestRenderer is per-test, no shared state
2. No real terminal -- virtual buffer, never touches stdout
3. Process isolation -- each test starts its own renderer process
4. NIF testable directly -- pure input->output for buffer/layout functions
5. `assert_received` for event dispatch testing

---

## Debate Log

### Cross-Agent Challenges & Resolutions
- **architect vs reactivity**: H1 proposed ALL state in single GenServer. H4 proposed widget GenServers for Input/Select/ScrollBox. **Final resolution (architect wins)**: ALL component state in a map within the single Runtime GenServer, NOT separate processes. Key evidence: LiveView's LiveComponents are NOT processes -- they're state tracked in the parent LiveView process. Widget state (cursor position, scroll offset, dropdown open/closed) keyed by component ID in Runtime state map. Same encapsulation, zero process overhead, atomic render snapshots.
- **renderer vs layout**: H2 estimated layout at 1-5ms. H3 demonstrated ~50us for 500 nodes. **Resolution**: Layout stays in pure Elixir, rendering hot path stays in Zig NIF. Only ONE NIF in the pipeline.
- **renderer vs architect**: H2 proposed dirty_cpu for NIF. H1 pointed out single GenServer is sole NIF caller. **Resolution**: Synchronous NIF (not dirty_cpu) since render completes in <1ms. Dirty_cpu reserved as future escape hatch.
- **api-design vs layout**: DSL attribute naming for layout props. **Resolution**: CSS-like keywords: `direction: :row`, `flex_grow: 1`, `justify: :center`, `align: :stretch`, `gap: 2`.
- **all agents**: Components as data vs processes. **Consensus**: ALL components are data, NOT processes. Stateless elements (Box, Text) are pure `%Element{}` structs. Stateful widgets (Input, Select, ScrollBox) have state in a map within the Runtime GenServer, keyed by component ID. `use ElixirOpentui.Component` defines a behaviour whose callbacks the Runtime calls directly -- no DynamicSupervisor needed.

---

## Consensus

**STATUS: CONSENSUS REACHED**

### Final Architecture

```
%Element{} tree (DSL) -> Pure Elixir Layout (~50us) -> Painter Protocol -> Zig RenderNif (<1ms) -> stdout
    ^                                                                              |
    |                                                                              |
Runtime GenServer (MVU) <-- events <-- EventManager (Elixir) <-- stdin
    |
    +-- Component state map: %{component_id => %{cursor: _, scroll: _, ...}}
```

### Verdicts Summary

| Hypothesis | Verdict | Decision |
|-----------|---------|----------|
| H1: OTP GenServer-per-component | REVISED | Single Runtime GenServer, ALL component state in one process |
| H2: NIF-based rendering | PARTIALLY SUPPORTED | Zig NIF for rendering hot path (recommended, not required) |
| H3: Yoga layout engine | REJECTED | Pure Elixir "Flexbox Lite" (~800-1200 lines) |
| H4: Elm-architecture | REVISED | Two-level MVU: app-level + component-level state, all in one process |
| H5: Elixir DSL | CONFIRMED | Three-layer API: functional core + macro DSL + optional sigil |

### Key Architectural Decisions

1. **Runtime**: Single GenServer with MVU pattern (init/update/render). App state as map. Render tick via `Process.send_after/3`.
2. **Rendering**: Zig NIF with narrow API: `init`, `put_cells`, `render_frame`, `resize`, `get_hit_id`, `clear`, plus test-only: `render_frame_capture`, `get_cell`, `get_buffer_snapshot`.
3. **Layout**: Pure Elixir flexbox subset. 3-pass algorithm (measure -> flex-resolve -> position). Dirty-flag caching. Taffy NIF as Phase 2 fallback.
4. **Components**: `use ElixirOpentui.Component` behaviour with `init/1`, `update/2`, `render/2`. ALL components are data, NOT processes. Widget state keyed by component ID in Runtime state map.
5. **API**: Macro DSL (`import ElixirOpentui.View`), `%Element{}` structs, keyword list attributes, `do/end` blocks for children.
6. **Events**: Message-based (atoms/tuples). Widget callbacks return semantic events to Runtime. EventManager parses stdin into structured events.
7. **Testing**: `TestRenderer` GenServer per test (`async: true`), `MockInput`/`MockMouse`, `render_frame_capture` for headless ANSI output, `assert_frame_contains` macro. All 27 ElixirOpentui test files mapped to Elixir equivalents.

### Implementation Phases

**Phase 1: Foundation**
- `%Element{}` struct and View DSL macros
- RGBA color module
- Pure Elixir Flexbox Lite layout engine
- TestRenderer infrastructure

**Phase 2: Rendering**
- Zig NIF: double buffer, cell grid, diff, ANSI generation
- Painter protocol: Element tree -> NIF cell buffer
- Synchronous render pipeline

**Phase 3: Input & Events**
- EventManager: stdin parsing (keyboard, mouse, escape sequences)
- Focus management and event routing
- Hit grid integration

**Phase 4: Components**
- `use ElixirOpentui.Component` behaviour and macro
- Runtime GenServer with MVU loop
- Widget GenServers (Input, Select, ScrollBox)
- DynamicSupervisor for widget lifecycle

**Phase 5: Full Component Library**
- Box, Text, Input, Textarea, Select, TabSelect
- ScrollBox, ScrollBar, Slider
- Code (syntax highlighting), Markdown, Diff
- ASCIIFont, FrameBuffer

### Test Suite Plan (27 ElixirOpentui tests -> Elixir ExUnit)

| Priority | ElixirOpentui Test | Elixir Module | Phase |
|----------|-------------|---------------|-------|
| 1 | buffer.test.ts | ElixirOpentui.BufferTest | 2 |
| 1 | text-buffer.test.ts | ElixirOpentui.TextBufferTest | 1 |
| 1 | edit-buffer.test.ts | ElixirOpentui.EditBufferTest | 1 |
| 2 | renderable.test.ts | ElixirOpentui.ElementTest | 1 |
| 2 | opacity.test.ts | ElixirOpentui.OpacityTest | 2 |
| 2 | yoga-setters.test.ts | ElixirOpentui.LayoutTest | 1 |
| 2 | absolute-positioning.snapshot.test.ts | ElixirOpentui.Layout.AbsoluteTest | 1 |
| 3 | renderer.input.test.ts | ElixirOpentui.Input.ParserTest | 3 |
| 3 | renderer.mouse.test.ts | ElixirOpentui.MouseTest | 3 |
| 3 | renderer.focus.test.ts | ElixirOpentui.FocusTest | 3 |
| 3 | renderer.selection.test.ts | ElixirOpentui.SelectionTest | 3 |
| 4 | scrollbox.test.ts | ElixirOpentui.ScrollBoxTest | 4 |
| 4 | scrollbox-culling-bug.test.ts | ElixirOpentui.ScrollBox.CullingTest | 4 |
| 4 | scrollbox-hitgrid.test.ts | ElixirOpentui.ScrollBox.HitGridTest | 4 |
| 4 | console.test.ts | ElixirOpentui.ConsoleTest | 5 |
| 5 | renderer.control.test.ts | ElixirOpentui.Renderer.ControlTest | 2 |
| 5 | renderer.idle.test.ts | ElixirOpentui.Renderer.IdleTest | 2 |
| 5 | renderer.destroy-during-render.test.ts | ElixirOpentui.Renderer.DestroyTest | 2 |
| 5 | renderer.kitty-flags.test.ts | ElixirOpentui.Input.KittyTest | 3 |
| 5 | renderer.palette.test.ts | ElixirOpentui.ColorTest | 2 |
| 5 | renderer.useMouse.test.ts | ElixirOpentui.MouseConfigTest | 3 |
| 5 | wrap-resize-perf.test.ts | ElixirOpentui.PerfTest | 5 |
| 5 | renderable.snapshot.test.ts | ElixirOpentui.SnapshotTest | 5 |
