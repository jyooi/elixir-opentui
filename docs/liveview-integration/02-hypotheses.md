# Hypothesis Details

## H1: LiveView as Terminal Transport (xterm.js in Browser)

**Premise**: Stream ANSI frames via LiveView WebSocket to xterm.js terminal emulator in browser.

### Strengths
- Zero changes to existing rendering pipeline
- Full fidelity — every terminal app works in browser immediately
- Proven approach (ttyd, Wetty, Livebook terminal)
- Bidirectional: keyboard/mouse events flow back through LiveView channel

### Weaknesses
- Double indirection: Elixir -> ANSI -> xterm.js -> browser DOM
- Limited to terminal capabilities — no accessibility, no responsive design
- "Why not just SSH?" — web terminal adds latency without adding capability
- xterm.js is a large JS dependency (~400KB)
- No semantic HTML — screen readers can't parse ANSI output

### Implementation Sketch

```elixir
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

  def handle_info({:frame, ansi_data}, socket) do
    push(socket, "frame", %{data: Base.encode64(ansi_data)})
    {:noreply, socket}
  end
end
```

**Verdict**: SECONDARY. Useful as a quick integration path, but not "first-class LiveView support."

---

## H2: LiveView Component Unification (API Alignment)

**Premise**: Align ElixirOpentui.Component's API with LiveView conventions — NOT by requiring Phoenix, but by adopting the same patterns.

### Strengths
- Zero learning curve for Phoenix developers (`mount/handle_event/render` is universal)
- Clean separation: `update/2` for parent-driven prop changes, `handle_event/3` for user interactions (current `update/3` conflates both)
- Future-proof return tuples (`{:ok, socket}`, `{:noreply, socket}`) enable extension
- Ecosystem alignment with Phoenix, Scenic, and GenServer conventions

### Key Change: Split `update/3`

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

### New Socket Struct

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

### Migration Example (Counter)

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

### Evidence: `update/3` Is Broken

Every widget demonstrates the conflation problem:

```elixir
# ScrollBox — two different concerns in one callback
def update(:key, %{type: :key} = event, state)           # user event
def update(:mouse, %{type: :mouse, action: :scroll_up})  # user event
def update({:set_scroll, y}, _event, state)               # parent command
def update({:set_content_height, h}, _event, state)       # parent command
```

**Verdict**: STRONG ADOPT. Foundational — all other hypotheses benefit from it.

---

## H3: Dual-Render Architecture (Same Tree -> Terminal OR Web)

**Premise**: The Element tree is already output-agnostic. Build a render adapter that converts trees to HTML/CSS for LiveView, just as Painter converts them to terminal buffers.

### Strengths
- Follows OpenTUI's exact pattern: framework-agnostic core + adapter packages
- Element types map naturally to HTML: `:box` -> `<div>`, `:text` -> `<span>`, `:button` -> `<button>`
- Style struct maps 1:1 to CSS: `flex_direction` -> `flex-direction`, `gap` -> `gap`
- Can render simultaneously to both targets (live debug view)
- No changes needed to core ElixirOpentui

### Architecture

```
ElixirOpentui (core, no Phoenix dependency)
├── Element tree production (View DSL, Component)
├── Layout engine (pure Elixir Flexbox Lite)
├── Terminal adapter (Painter -> Buffer -> ANSI) [existing]
└── BufferBehaviour (polymorphic dispatch) [existing]

ElixirOpentuiLive (separate package, depends on Phoenix)
├── LiveView adapter (Element tree -> HEEx/HTML)
├── Style -> CSS converter
├── Event adapter (LiveView events -> ElixirOpentui events)
└── LiveComponent wrappers for interactive widgets
```

### Element -> HTML Mapping

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
      "display:flex",
      "font-family:monospace"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(";")
  end
end
```

**Verdict**: ADOPT as primary LiveView integration. This is the OpenTUI-proven pattern.

---

## H4: LiveView as State Orchestrator (PubSub + Shared State)

**Premise**: Use LiveView for state management and real-time coordination via PubSub. Enables multi-user shared sessions, web admin panels, live debugging.

### Strengths
- Enables genuinely new capabilities impossible with terminal alone:
  - Multi-user synchronized terminal sessions
  - Web admin panel controlling a terminal app
  - Live debugging dashboard showing component state
  - Presence tracking for collaborative editing
- Zero changes to existing ElixirOpentui code
- ~200 lines implementation
- Natural fit for Elixir's process model

### Implementation

```elixir
defmodule ElixirOpentuiLive.StateSync do
  use GenServer

  def start_link(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    topic = Keyword.get(opts, :topic, "opentui:state")
    GenServer.start_link(__MODULE__, %{runtime: runtime, topic: topic})
  end

  def init(state) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, state.topic)
    {:ok, state}
  end

  def handle_info({:runtime_state_changed, new_state}, state) do
    Phoenix.PubSub.broadcast(MyApp.PubSub, state.topic, {:state_update, new_state})
    {:noreply, state}
  end

  def handle_info({:liveview_event, event}, state) do
    ElixirOpentui.Runtime.send_event(state.runtime, event)
    {:noreply, state}
  end
end
```

**Verdict**: ADOPT as enhancement layer. Complements H3 — H3 handles rendering, H4 handles coordination.

---

## H5: TUI-Styled Web Components (HTML+CSS Terminal Aesthetic)

**Premise**: Render Element trees as HTML/CSS that mimics terminal aesthetics — monospace fonts, dark themes, character-cell grid.

### Strengths
- Full HTML accessibility (screen readers, ARIA)
- CSS flexbox is far more powerful than terminal flexbox
- Theming support (terminal dark, light, retro CRT, modern UI)
- No xterm.js dependency
- Native web form elements for inputs

### Concrete Adapter (H5's strongest contribution)

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

  def tui_element(%{element: %{type: :button}} = assigns) do
    ~H"""
    <button class="tui-button" style={to_css(@element.style)}
            phx-click="tui_event" phx-value-id={@element.id}>
      {@element.attrs[:content]}
    </button>
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
end
```

**Verdict**: SUBSUMED by H3. Terminal styling is a CSS theme, not an architecture. But H5's concrete function components ARE the H3 adapter implementation — they converged.
