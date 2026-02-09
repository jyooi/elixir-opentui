# Consensus Architecture

## System Diagram

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

## Implementation Phases

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

## Package Structure

```
elixir_opentui/              # Core (no Phoenix dependency)
├── lib/elixir_opentui/
│   ├── socket.ex            # NEW: Socket struct (Phase 7A)
│   ├── component.ex         # MODIFIED: LiveView-aligned callbacks
│   ├── runtime.ex           # MODIFIED: New callback dispatch
│   ├── element.ex           # UNCHANGED
│   ├── view.ex              # UNCHANGED
│   ├── layout.ex            # UNCHANGED
│   ├── painter.ex           # UNCHANGED
│   └── widgets/             # MODIFIED: Migrated to new API
└── mix.exs                  # No new deps

elixir_opentui_live/         # LiveView adapter (separate hex package)
├── lib/elixir_opentui_live/
│   ├── html_adapter.ex      # Element -> HEEx conversion
│   ├── style_css.ex         # Style -> CSS string
│   ├── event_adapter.ex     # LiveView events -> ElixirOpentui events
│   ├── runtime_live.ex      # LiveView wrapping Runtime
│   ├── state_sync.ex        # PubSub bridge
│   └── terminal_channel.ex  # xterm.js transport
├── assets/
│   ├── js/hooks/terminal.js # xterm.js LiveView hook
│   └── css/tui-theme.css    # Terminal aesthetic theme
└── mix.exs                  # Depends on phoenix_live_view + elixir_opentui
```
