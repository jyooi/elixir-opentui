### H3: Layout Engine (Agent: layout)
_Hypothesis: We must port or bind to Yoga layout engine for true Flexbox support. A simpler custom layout system would be insufficient._

**Findings:**

**VERDICT: REJECTED -- We do NOT need Yoga. A pure Elixir "Flexbox Lite" covering the TUI-relevant subset is recommended, with Taffy (Rust NIF) as optional Phase 2.**

#### 1. What ElixirOpentui Actually Uses from Yoga

ElixirOpentui uses these Yoga/Flexbox properties:
- `flexDirection` (row, column), `flexGrow`, `flexShrink`, `flexBasis`
- `justifyContent` (flex-start, flex-end, center, space-between, space-around)
- `alignItems`, `alignSelf` (flex-start, flex-end, center, stretch)
- `width`, `height` (fixed, percentage, "100%"), `gap`, `padding`, `margin`
- `position: absolute` (for overlays)

ABSENT from TUI usage: `flex-wrap`, `align-content`, `order`, CSS `grid`, `float`, `inline-block`.

#### 2. Options Evaluated

**Yoga C NIF -- NOT RECOMMENDED**: ~8,280 lines C++. Complex FFI (must mirror entire node tree). Perf: 191-4,896 ns/node -- slowest in benchmarks. C++ crash kills BEAM. No Elixir bindings exist.

**Taffy Rust NIF (Rustler) -- GOOD FALLBACK**: ~3K stars, used in Bevy/Dioxus. Rustler catches panics. 39-1,098 ns/node (2-5x faster than Yoga). Still needs NIF boundary + Rust toolchain.

**Pure Elixir "Flexbox Lite" -- RECOMMENDED**: Reference TS implementation achieved flexbox in <600 lines (vs Yoga 8,280). Terminal simplifies dramatically: monospace grid, integer coords, no reflow/sub-pixel/float/grid. 3-pass algo: measure -> flex-resolve -> position. PanGui (C#) proved purpose-built engines can be 69x faster than Yoga.

**Ratatui-style Constraints -- TOO LIMITED**: No flex-grow/shrink, no cross-axis alignment. Would limit ElixirOpentui parity.

#### 3. Performance: Layout is NOT the Bottleneck

- 500 nodes at ~100 ns/node = ~50us per layout pass
- 30 FPS budget = 33,333us -- layout is ~0.15% of budget
- Even 10x slower = only 1.5%. Rendering (1-5ms) and I/O (0.5-2ms) dominate.
- **Layout should stay in Elixir, NOT in a NIF.** Debuggable, testable, no FFI overhead.

#### 4. Caching Strategy

Triggers: window resize, content change, style change. Dirty-flag propagation, hash-keyed cache, skip unchanged subtrees. >90% cache hit rate for typical interaction.

#### 5. Prior Art Comparison

| Framework | Layout | Flexbox? |
|-----------|--------|----------|
| ElixirOpentui | Yoga C++ FFI | Full |
| Ratatui (18K stars) | Constraint splits | No |
| Bubbletea/Lipgloss | JoinH/V + Place | No |
| Ratatouille | ex_termbox grid | No |
| Ink (React TUI) | Yoga | Full |

#### 6. Recommended Architecture

**Phase 1: Pure Elixir (~800-1,200 lines)**
```elixir
defmodule ElixirTUI.Layout do
  defstruct [:flex_direction, :flex_grow, :flex_shrink, :justify_content,
             :align_items, :width, :height, :padding, :margin, :gap, :position]

  @spec compute(tree, w :: integer, h :: integer) ::
    %{node_id => %{x: integer, y: integer, w: integer, h: integer}}
  def compute(tree, available_w, available_h)
end
```
Three passes: Measure (bottom-up) -> Flex resolve (top-down) -> Position (top-down).

**Phase 2 (if needed): Taffy NIF via Rustler** for flex-wrap, CSS grid, strict W3C compliance.

#### 7. Why NOT Yoga

FFI too complex for trees, slowest benchmark results, C++ crash risk, no Elixir bindings. Taffy is strictly superior if we ever need a NIF engine.

#### 8. Cross-Hypothesis Interactions

- **H1**: Layout is a pure function `[%{id, style, children}]` -> `%{id => rect}`. Fits single-GenServer Runtime.
- **H2**: Layout produces positions; renderer consumes them. Separate stages. Layout stays in Elixir, rendering hot path in Zig NIF. (Note: H2 estimated layout at 1-5ms; my analysis shows ~50us for 500 nodes, even more reason to keep it Elixir-side.)
- **H5**: Layout props as DSL keywords: `box direction: :row, flex_grow: 1, gap: 2`.
