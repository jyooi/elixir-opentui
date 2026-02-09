# LiveView Integration Findings

## 5-Agent Scientific Debate: How Should Phoenix LiveView Integrate with ElixirOpentui?

**Date**: 2026-02-09
**Participants**: 5 specialized agents (H1–H5), each advocating a distinct hypothesis
**Inspired by**: OpenTUI (https://opentui.com) — the TypeScript TUI framework this project is based on

---

## Executive Summary

After extensive debate, the agents reached a **layered consensus** — the hypotheses are not mutually exclusive but form complementary layers of a complete LiveView integration strategy:

1. **H2 (Component API Alignment)** — ADOPT. Align component callbacks with LiveView conventions (`mount/handle_event/render` + assigns pattern). Zero dependency on Phoenix.
2. **H3 (Dual-Render Architecture)** — ADOPT as primary integration. Build a `LiveView Adapter` that converts Element trees to HTML with CSS flexbox, following OpenTUI's reconciler pattern.
3. **H4 (State Orchestrator via PubSub)** — ADOPT as enhancement layer. LiveView manages shared state and real-time sync via PubSub. Enables multi-user sessions and web admin panels.
4. **H1 (Terminal Transport)** — SECONDARY. Useful as a quick-win for terminal-in-browser, but limited compared to H3's native web rendering.
5. **H5 (TUI-Styled Web Components)** — SUBSUMED by H3. The HTML/CSS output approach is correct but framing it as "terminal-styled" is unnecessarily limiting. H3's adapter pattern is more general.

---

## Hypothesis Details

### H1: LiveView as Terminal Transport (xterm.js in Browser)

**Premise**: Stream ANSI frames via LiveView WebSocket to xterm.js terminal emulator in browser.

**Strengths**:
- Zero changes to existing rendering pipeline
- Full fidelity — every terminal app works in browser immediately
- Proven approach (ttyd, Wetty, Livebook terminal)
- Bidirectional: keyboard/mouse events flow back through LiveView channel

**Weaknesses (identified in debate)**:
- Double indirection: Elixir → ANSI → xterm.js → browser DOM
- Limited to terminal capabilities — no accessibility, no responsive design
- "Why not just SSH?" — web terminal adds latency without adding capability
- xterm.js is a large JS dependency (~400KB)
- No semantic HTML — screen readers can't parse ANSI output

**Implementation sketch**:
```elixir
# New module: ElixirOpentui.LiveTerminal (Phoenix Channel)
defmodule ElixirOpentuiLive.TerminalChannel do
  use Phoenix.Channel

  def join("terminal:" <> _id, _params, socket) do
    {:ok, pid} = ElixirOpentui.Runtime.start_link(mode: :channel, channel: self())
    {:ok, assign(socket, :runtime, pid)}
  end

  def handle_in("key", %{"key" => key, "mods" => mods}, socket) do
    event = ElixirOpentui.Input.parse_key(key, mods)
    ElixirOpentui.Runtime.send_event(socket.assigns.runtime, event)
    {:noreply, socket}
  end

  # Runtime sends ANSI frames back through channel
  def handle_info({:frame, ansi_data}, socket) do
    push(socket, "frame", %{data: Base.encode64(ansi_data)})
    {:noreply, socket}
  end
end
```

**Verdict**: SECONDARY approach. Useful as a quick integration path, but not "first-class LiveView support."

---

### H2: LiveView Component Unification (API Alignment)

**Premise**: Align ElixirOpentui.Component's API with LiveView conventions — NOT by requiring Phoenix, but by adopting the same patterns.

**Strengths**:
- **Zero learning curve** for Phoenix developers (mount/handle_event/render is universal)
- **Clean separation** of concerns: `update/2` for parent-driven prop changes, `handle_event/3` for user interactions (current `update/3` conflates both)
- **Future-proof** return tuples (`{:ok, socket}`, `{:noreply, socket}`) enable extension
- **Ecosystem alignment** with Phoenix, Scenic, and GenServer conventions
- **Complementary** to all other hypotheses — they all need a component model

**Key Change**: Split the current `update/3` callback:

```elixir
# CURRENT (ElixirOpentui.Component)
@callback init(props :: map()) :: term()
@callback update(msg :: term(), event :: term(), state :: term()) :: term()
@callback render(state :: term()) :: Element.t()

# PROPOSED (LiveView-aligned)
@callback mount(socket :: Socket.t()) :: {:ok, Socket.t()}
@callback update(assigns :: map(), socket :: Socket.t()) :: {:ok, Socket.t()}
@callback handle_event(event :: String.t(), params :: map(), socket :: Socket.t()) :: {:noreply, Socket.t()}
@callback render(assigns :: map()) :: Element.t()
```

**New Socket struct** (~15 lines):
```elixir
defmodule ElixirOpentui.Socket do
  defstruct assigns: %{}, id: nil, component: nil

  def assign(socket, key, value) do
    %{socket | assigns: Map.put(socket.assigns, key, value)}
  end

  def assign(socket, keyword_or_map) do
    Enum.reduce(keyword_or_map, socket, fn {k, v}, acc -> assign(acc, k, v) end)
  end
end
```

**Example migration** (Counter component):
```elixir
# BEFORE
defmodule Counter do
  use ElixirOpentui.Component
  def init(_props), do: %{count: 0}
  def update(:increment, _event, state), do: %{state | count: state.count + 1}
  def update(_, _, state), do: state
  def render(state), do: text(content: "#{state.count}")
end

# AFTER
defmodule Counter do
  use ElixirOpentui.Component
  def mount(socket), do: {:ok, assign(socket, count: 0)}
  def handle_event("increment", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end
  def render(assigns), do: text(content: "#{assigns.count}")
end
```

**Weaknesses (debated)**:
- Migration cost: all widgets + tests need updating (but mechanical)
- Over-engineering concern: the current API is simpler and works
- Counter-argument: simplicity now = debt later when LiveView adapter is built

**Verdict**: STRONG ADOPT. This is foundational — all other hypotheses benefit from it.

---

### H3: Dual-Render Architecture (Same Tree → Terminal OR Web)

**Premise**: The Element tree is already output-agnostic. Build a render adapter layer that converts trees to HTML/CSS for LiveView, just as Painter converts them to terminal buffers.

**Strengths**:
- **Follows OpenTUI's exact pattern**: framework-agnostic core + adapter packages
- Element types map naturally to HTML: `:box` → `<div>`, `:text` → `<span>`, `:button` → `<button>`, `:input` → `<input>`
- Style struct maps 1:1 to CSS: `flex_direction` → `flex-direction`, `gap` → `gap`, `padding` → `padding`
- Can render simultaneously to both terminal and web (live debug view!)
- No changes needed to core ElixirOpentui

**Implementation architecture**:
```
ElixirOpentui (core, no Phoenix dependency)
├── Element tree production (View DSL, Component)
├── Layout engine (pure Elixir Flexbox Lite)
├── Terminal adapter (Painter → Buffer → ANSI) [existing]
└── BufferBehaviour (polymorphic dispatch) [existing]

ElixirOpentuiLive (separate package, depends on Phoenix)
├── LiveView adapter (Element tree → HEEx/HTML)
├── Style → CSS converter
├── Event adapter (LiveView events → ElixirOpentui events)
└── LiveComponent wrappers for interactive widgets
```

**Element → HTML mapping**:
```elixir
defmodule ElixirOpentuiLive.HTMLAdapter do
  def render_element(%Element{type: :box} = el, assigns) do
    ~H"""
    <div style={style_to_css(el.style)} id={el.id}>
      <%= for child <- el.children do %>
        <%= render_element(child, assigns) %>
      <% end %>
    </div>
    """
  end

  def render_element(%Element{type: :text} = el, _assigns) do
    ~H"""
    <span style={style_to_css(el.style)}><%= el.attrs[:content] %></span>
    """
  end

  def render_element(%Element{type: :input} = el, assigns) do
    ~H"""
    <input
      type="text"
      value={el.attrs[:value]}
      placeholder={el.attrs[:placeholder]}
      phx-keyup="input_key"
      phx-value-id={el.id}
      style={style_to_css(el.style)}
    />
    """
  end

  defp style_to_css(%Style{} = s) do
    [
      s.flex_direction && "flex-direction:#{s.flex_direction}",
      s.flex_grow && "flex-grow:#{s.flex_grow}",
      s.gap && "gap:#{s.gap}ch",
      s.padding && padding_to_css(s.padding),
      s.fg && "color:#{color_to_css(s.fg)}",
      s.bg && "background-color:#{color_to_css(s.bg)}",
      s.border && "border:1px solid currentColor",
      s.width && width_to_css(s.width),
      s.height && height_to_css(s.height),
      "display:flex",
      "font-family:monospace"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(";")
  end
end
```

**Weaknesses (debated)**:
- Terminal cells are fixed-width grids; HTML text is variable → fidelity gap
- "Write once, run anywhere" historically under-delivers
- Maintaining two adapters increases surface area
- Counter-argument: the adapters are thin (~200-300 lines each), and the core does the heavy lifting

**Verdict**: ADOPT as the primary LiveView integration strategy. This is the OpenTUI-proven pattern.

---

### H4: LiveView as State Orchestrator (PubSub + Shared State)

**Premise**: Use LiveView only for state management and real-time coordination via PubSub. Terminal rendering remains the sole output path. Enables multi-user shared sessions.

**Strengths**:
- Enables genuinely new capabilities impossible with terminal alone:
  - Multi-user synchronized terminal sessions
  - Web admin panel that controls a terminal app
  - Live debugging dashboard showing component state
  - Presence tracking for collaborative editing
- Zero changes to existing ElixirOpentui code
- ~200 lines implementation
- Natural fit for Elixir's process model

**Implementation**:
```elixir
defmodule ElixirOpentuiLive.StateSync do
  @moduledoc "Bridges ElixirOpentui Runtime state to LiveView via PubSub"

  use GenServer

  def start_link(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    topic = Keyword.get(opts, :topic, "opentui:state")
    GenServer.start_link(__MODULE__, %{runtime: runtime, topic: topic})
  end

  def init(state) do
    # Subscribe to runtime state changes
    Phoenix.PubSub.subscribe(MyApp.PubSub, state.topic)
    {:ok, state}
  end

  # Broadcast state changes from Runtime to all LiveViews
  def handle_info({:runtime_state_changed, new_state}, state) do
    Phoenix.PubSub.broadcast(MyApp.PubSub, state.topic, {:state_update, new_state})
    {:noreply, state}
  end

  # Forward LiveView events to Runtime
  def handle_info({:liveview_event, event}, state) do
    ElixirOpentui.Runtime.send_event(state.runtime, event)
    {:noreply, state}
  end
end
```

**Web dashboard LiveView**:
```elixir
defmodule MyAppWeb.TUIDashboardLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "opentui:state")
    {:ok, assign(socket, tree: nil, component_states: %{})}
  end

  def handle_info({:state_update, state}, socket) do
    {:noreply, assign(socket, tree: state.tree, component_states: state.component_states)}
  end

  def handle_event("send_event", %{"event" => event}, socket) do
    Phoenix.PubSub.broadcast(MyApp.PubSub, "opentui:state", {:liveview_event, event})
    {:noreply, socket}
  end
end
```

**Weaknesses (debated)**:
- "Why use LiveView if you're not using its rendering?" — but PubSub is the real value
- The Runtime GenServer already handles state perfectly well for single-user
- Counter-argument: single-user is just one use case; PubSub enables multi-user scenarios that are genuinely impossible without it

**Verdict**: ADOPT as enhancement layer. Complements H3 perfectly — H3 handles rendering, H4 handles coordination.

---

### H5: TUI-Styled Web Components (HTML+CSS Terminal Aesthetic)

**Premise**: Render Element trees as HTML/CSS that mimics terminal aesthetics — monospace fonts, dark themes, character-cell grid.

**Strengths**:
- Full HTML accessibility (screen readers, ARIA)
- CSS flexbox is far more powerful than terminal flexbox
- Theming support (terminal dark, light, retro CRT, modern UI)
- No xterm.js dependency
- Native web form elements for inputs

**Weaknesses (debated)**:
- Subsumed by H3 — this IS the HTML adapter from H3, just with a specific styling choice
- "Why not just use LiveView directly?" — if you're making HTML, what does ElixirOpentui add?
- Counter-argument: ElixirOpentui adds the component model, layout engine, and declarative DSL. The HTML adapter just changes the output format.
- Terminal-styled CSS is a theming concern, not an architecture concern

**Concrete adapter code** (H5's strongest contribution — the Element-to-HEEx compiler):
```elixir
defmodule ElixirOpentui.LiveView.Adapter do
  use Phoenix.Component

  def tui_element(%{element: %{type: :box}} = assigns) do
    ~H"""
    <div class="tui-box" style={to_css(@element.style)}>
      <.tui_element :for={child <- @element.children} element={child} focus_id={@focus_id} />
    </div>
    """
  end

  def tui_element(%{element: %{type: :text}} = assigns) do
    ~H"""
    <span class="tui-text" style={to_css(@element.style)}>{@element.attrs[:content]}</span>
    """
  end

  def tui_element(%{element: %{type: :button}} = assigns) do
    ~H"""
    <button class="tui-button" style={to_css(@element.style)}
            phx-click="tui_event" phx-value-id={@element.id}>
      {@element.attrs[:content]}
    </button>
    """
  end

  def tui_element(%{element: %{type: :input}} = assigns) do
    ~H"""
    <input class="tui-input" type="text" value={@element.attrs[:value] || ""}
           placeholder={@element.attrs[:placeholder] || ""} style={to_css(@element.style)}
           phx-change="tui_input" phx-value-id={@element.id} />
    """
  end

  def tui_element(%{element: %{type: :select}} = assigns) do
    ~H"""
    <div class="tui-select" role="listbox" style={to_css(@element.style)}>
      <div :for={{opt, idx} <- Enum.with_index(@element.attrs[:options] || [])}
           class={["tui-select-option", idx == (@element.attrs[:selected] || 0) && "tui-selected"]}
           role="option" phx-click="tui_select" phx-value-id={@element.id} phx-value-index={idx}>
        {opt}
      </div>
    </div>
    """
  end

  def tui_element(%{element: %{type: :checkbox}} = assigns) do
    ~H"""
    <label class="tui-checkbox" style={to_css(@element.style)}>
      <input type="checkbox" checked={@element.attrs[:checked]}
             phx-click="tui_toggle" phx-value-id={@element.id} />
      <span>{if @element.attrs[:checked], do: "[x] ", else: "[ ] "}</span>
      <span>{@element.attrs[:label]}</span>
    </label>
    """
  end

  def tui_element(%{element: %{type: :panel}} = assigns) do
    ~H"""
    <fieldset class="tui-panel" style={to_css(@element.style)}>
      <legend :if={@element.attrs[:title]}>{@element.attrs[:title]}</legend>
      <.tui_element :for={child <- @element.children} element={child} focus_id={@focus_id} />
    </fieldset>
    """
  end

  def tui_element(assigns) do
    ~H"""
    <div class={"tui-#{@element.type}"} style={to_css(@element.style)}>
      <.tui_element :for={child <- @element.children} element={child} focus_id={@focus_id} />
    </div>
    """
  end
end
```

**Verdict**: SUBSUMED by H3. The terminal styling is just a CSS theme that can ship with the HTML adapter. However, H5's concrete HEEx function components above ARE the HTML adapter implementation — H3 and H5 converged on the same code.

---

## Consensus Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Code                         │
│  defmodule MyApp do                                         │
│    use ElixirOpentui.Component  # LiveView-aligned API (H2) │
│    def mount(socket), do: ...                               │
│    def handle_event(event, params, socket), do: ...         │
│    def render(assigns), do: box do ... end                  │
│  end                                                        │
└─────────────────┬───────────────────────────────────────────┘
                  │ Element tree
                  ▼
┌─────────────────────────────────────────────────────────────┐
│            ElixirOpentui Core (framework-agnostic)          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │ View DSL │ │ Element  │ │  Layout  │ │  Component   │   │
│  │ (macros) │ │ (struct) │ │ (flexbox)│ │ (behaviour)  │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │  Buffer  │ │ Painter  │ │ Runtime  │ │ EventManager │   │
│  │ (cells)  │ │ (render) │ │  (MVU)   │ │  (routing)   │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
└─────────┬───────────────────────────┬───────────────────────┘
          │                           │
          ▼                           ▼
┌──────────────────┐    ┌──────────────────────────────────┐
│ Terminal Adapter  │    │ ElixirOpentuiLive (optional pkg) │
│  (existing)       │    │                                  │
│ ┌──────────────┐  │    │  ┌──────────────────────────┐   │
│ │Painter→Buffer│  │    │  │ HTML Adapter (H3)        │   │
│ │→ANSI→stdout  │  │    │  │ Element → HEEx/HTML+CSS  │   │
│ └──────────────┘  │    │  └──────────────────────────┘   │
│ ┌──────────────┐  │    │  ┌──────────────────────────┐   │
│ │ NIF backend  │  │    │  │ State Sync (H4)          │   │
│ │ (Zig buffer) │  │    │  │ PubSub + Presence        │   │
│ └──────────────┘  │    │  └──────────────────────────┘   │
│ ┌──────────────┐  │    │  ┌──────────────────────────┐   │
│ │Terminal.ex   │  │    │  │ LiveTerminal (H1)        │   │
│ │(raw TTY I/O) │  │    │  │ xterm.js WebSocket       │   │
│ └──────────────┘  │    │  └──────────────────────────┘   │
└──────────────────┘    └──────────────────────────────────┘
```

---

## Implementation Plan

### Phase 7A: Component API Alignment (H2) — Core Package

**Changes to `elixir_opentui` (no new dependencies)**:

1. Add `ElixirOpentui.Socket` struct (~15 lines)
2. Update `ElixirOpentui.Component` behaviour callbacks
3. Update `ElixirOpentui.Runtime` to use new callback signatures
4. Migrate all widgets (TextInput, Select, Checkbox, ScrollBox) to new API
5. Update all tests

**Estimated scope**: ~500 lines changed, 0 new dependencies

### Phase 7B: HTML Adapter (H3) — New Package `elixir_opentui_live`

**New package with Phoenix dependency**:

1. `ElixirOpentuiLive.HTMLAdapter` — converts Element trees to HEEx
2. `ElixirOpentuiLive.StyleCSS` — converts Style structs to CSS strings
3. `ElixirOpentuiLive.EventAdapter` — maps LiveView events to ElixirOpentui events
4. `ElixirOpentuiLive.RuntimeLive` — LiveView that wraps Runtime GenServer
5. `ElixirOpentuiLive.ComponentHelpers` — LiveView function components for each element type
6. CSS theme file for terminal aesthetic (optional)

**Estimated scope**: ~600 lines, depends on `phoenix_live_view`

### Phase 7C: State Sync (H4) — Enhancement in `elixir_opentui_live`

1. `ElixirOpentuiLive.StateSync` — PubSub bridge for Runtime state
2. `ElixirOpentuiLive.Presence` — multi-user presence tracking
3. `ElixirOpentuiLive.AdminDashboard` — optional web dashboard LiveView

**Estimated scope**: ~300 lines

### Phase 7D: Terminal Transport (H1) — Enhancement in `elixir_opentui_live`

1. `ElixirOpentuiLive.TerminalChannel` — Phoenix Channel for xterm.js
2. JavaScript client hook for xterm.js integration
3. Terminal.ex adapter for channel-based I/O

**Estimated scope**: ~200 lines + JS

---

## Key Debate Points & Resolutions

### Debate 1: "Should Phoenix be a dependency of the core library?"
**Resolution**: NO. The core `elixir_opentui` package remains dependency-free (except Zigler). LiveView integration lives in a separate `elixir_opentui_live` package. This follows OpenTUI's pattern where `@opentui/core` has zero dependencies on React or SolidJS.

### Debate 2: "Should the component API change even without LiveView?"
**Resolution**: YES. H2's argument that `update/3` conflates parent prop changes with user events is valid regardless of LiveView. The current TextInput widget mixes keyboard event handling with state transitions in the same callback. Splitting into `update/2` + `handle_event/3` is cleaner.

### Debate 3: "Is dual-render (H3) 'write once run anywhere' doomed to fail?"
**Resolution**: NO, because the abstraction is thin. The Element tree is already a virtual DOM. The HTML adapter is ~300 lines of mapping (`:box` → `<div>`, etc). Unlike Java applets or React Native, we're not trying to abstract away platform differences — we're just providing two output formats for the same tree. Terminal apps may need platform-specific tweaks, but the core logic is shared.

### Debate 4: "Is H4 (PubSub orchestrator) over-engineered?"
**Resolution**: NO, because it enables genuinely new capabilities (multi-user sync, live debugging, web admin panels) that are impossible without it. The implementation is ~200 lines and entirely optional.

### Debate 5: "Why not just embed a terminal in the browser (H1) instead of native HTML (H3)?"
**Resolution**: Both have value. H1 is a quick win for 100% fidelity. H3 is better for accessibility, SEO, responsiveness, and native web UX. Ship both — let the developer choose.

---

## OpenTUI Precedent Analysis

OpenTUI (TypeScript) solved this exact problem with their React and SolidJS integrations:

| OpenTUI (TypeScript) | ElixirOpentui (Elixir) |
|---|---|
| `@opentui/core` (no framework deps) | `elixir_opentui` (no Phoenix deps) |
| `@opentui/react` (React reconciler) | `elixir_opentui_live` (LiveView adapter) |
| `componentCatalogue` (tag → constructor) | Element type → HTML mapping |
| `react-reconciler` host config | LiveView lifecycle → Runtime bridge |
| `Renderable` class hierarchy | `Element` struct + `Component` behaviour |
| Yoga layout engine | Flexbox Lite layout engine |
| Zig native buffer/diff | Zig NIF buffer/diff |
| `useRenderer()` hook | LiveView assigns + PubSub |

The parallel is striking. ElixirOpentui should follow the same separation of concerns.

---

## Cross-Agent Debate: Key Exchanges

### "At what level should LiveView adapt?" (H4 vs H2 vs H3)

H4 made the strongest framing argument: **each framework adapts at its natural abstraction level**.

```
React adapts at:     Tree operations (createElement, appendChild, removeChild)
SolidJS adapts at:   Reactive primitives (createSignal, createEffect)
LiveView adapts at:  State synchronization (assigns, PubSub, handle_info)
```

H4 argued this means LiveView's adapter should be a PubSub state bridge, not a tree reconciler or component replacement. H2 countered that the Elixir ecosystem has converged on ONE convention (`mount/handle_event/render`), making it valid to align the core API. H3 argued both are wrong — the adapter should work at the Element tree level, converting to HEEx.

**Resolution**: All three levels have value. H2 addresses the API surface, H3 addresses rendering output, H4 addresses state coordination. They are orthogonal concerns.

### "H1 is the foundation" vs "H1 is architecturally wrong" (H1 vs H3/H5)

H1 argued it's the **bottom adapter** in the pipeline — any future reconciler still needs H1 to deliver frames to the browser. H3 and H5 argued piping ANSI to xterm.js is "like embedding a phone emulator in a desktop app" — you waste the entire web platform (accessibility, CSS, native forms).

H1's rebuttal: `NativeBuffer.render_frame_capture/1` already produces ANSI binary — the data is ready. 150 lines gets you terminal-in-browser. H5's rebuttal: those 150 lines produce an inaccessible, unsearchable, non-responsive black box.

**Resolution**: Both valid. H1 ships fast with 100% fidelity. H3/H5 ships slower with native web UX. They serve different users — ship both.

### "Does OpenTUI validate or contradict dual-render?" (H3 vs H4)

H4 noted: "OpenTUI does NOT render to both terminal and HTML from the same tree. Each framework adapter has its own pipeline." H3 countered: "OpenTUI's architecture DOES support it — the Renderable tree is the universal interchange format. OpenTUI just hasn't built a web renderer yet."

**Resolution**: The OpenTUI architecture allows both patterns. The Element tree IS framework-agnostic. Whether you render it to terminal, HTML, or both is an output concern handled by adapters.

### "update/3 is actually broken" (H2 evidence from all widgets)

H2 provided concrete evidence from every widget:

```elixir
# ScrollBox — two different concerns in one callback
def update(:key, %{type: :key} = event, state)           # user event
def update(:mouse, %{type: :mouse, action: :scroll_up})  # user event
def update({:set_scroll, y}, _event, state)               # parent command
def update({:set_content_height, h}, _event, state)       # parent command
```

No other agent contested this finding. The `update/3` design flaw is real and independent of LiveView.

### The "reconciler" question (all agents)

Each agent interpreted "LiveView's reconciler equivalent" differently:
- **H1**: "LiveView doesn't need a reconciler — our Runtime IS the reconciler. H1 just transports the output."
- **H2**: "The reconciler is trivially thin if the core API already matches LiveView conventions."
- **H3**: "The reconciler is `WebAdapter.render(element_tree)` — a ~200 line Element-to-HEEx compiler."
- **H4**: "The reconciler is PubSub state sync — state-level adaptation, not tree-level."
- **H5**: "The reconciler is ~80 lines of pattern-matched function components (Element type → HEEx)."

**Resolution**: They're all partially right. The "reconciler" has multiple dimensions — API alignment (H2), tree translation (H3/H5), state sync (H4), and transport (H1).

---

## Minority Opinions

**H1 (Transport) as Primary**: H1 argued terminal-in-browser via xterm.js should be the PRIMARY approach — 100% fidelity, zero code changes, 150 lines, ships in a day. Valid for "get existing apps in a browser fast." Counter: fidelity isn't the only goal — accessibility, responsiveness, and native web UX matter for production web apps.

**H4 (State Orchestrator) as Sole Integration**: H4 argued it's the ONLY hypothesis enabling genuinely new capabilities (multi-user sync, presence, web admin panels) and should be primary. Counter: H4 alone provides no rendering path to the browser — it needs H1, H3, or H5 for display.

**H5 (TUI Aesthetic is THE value prop)**: H5 argued the terminal aesthetic IS what makes ElixirOpentui unique on the web. Counter: theming is a CSS concern, not architecture. The HTML adapter should support any theme — terminal is just the default.

**H2 Contested by H4/H5**: Both H4 and H5 called H2 "good refactoring, not an integration strategy." H2 agreed but maintained it's the foundational layer all integration strategies build on.

---

## Final Recommendation

**Adopt the layered consensus approach**:

1. **Phase 7A** (H2): Align component API with LiveView conventions — immediate, no new deps
2. **Phase 7B** (H3): Build HTML adapter in `elixir_opentui_live` — primary integration
3. **Phase 7C** (H4): Add PubSub state sync — enables multi-user scenarios
4. **Phase 7D** (H1): Add terminal transport — quick win for terminal-in-browser

This gives ElixirOpentui the same "framework-agnostic core + optional framework adapter" architecture that made OpenTUI successful with React and SolidJS.
