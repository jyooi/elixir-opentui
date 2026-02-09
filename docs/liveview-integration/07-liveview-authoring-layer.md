# LiveView as Terminal UI Authoring Layer

## The User's Vision

Instead of asking "how does LiveView display terminal UIs in a browser," the actual question is:

**Can we use LiveView's declarative paradigm (mount/handle_event/assign/render) as the authoring model for terminal UIs?**

This inverts the typical framing. LiveView isn't a rendering target — it's the API developers use to build terminal applications.

## Two Approaches

### Approach A: Adopt the API, Not the Dependency

Align ElixirOpentui's component model with LiveView conventions without depending on Phoenix:

```elixir
defmodule MyTerminalApp do
  use ElixirOpentui.Component  # Looks like LiveView, but no Phoenix required

  def mount(socket) do
    {:ok, assign(socket, count: 0, name: "")}
  end

  def handle_event("increment", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end

  def handle_event("name_changed", %{"value" => name}, socket) do
    {:noreply, assign(socket, name: name)}
  end

  def render(assigns) do
    import ElixirOpentui.View

    box direction: :column, padding: 1 do
      text content: "Hello, #{assigns.name}!"
      input id: :name, value: assigns.name, on_change: "name_changed"

      box direction: :row, gap: 2 do
        button content: "+", on_click: "increment"
        text content: "Count: #{assigns.count}"
      end
    end
  end
end

# Run it in the terminal
ElixirOpentui.Runtime.start_link(root: MyTerminalApp)
```

**Pros**:
- Zero dependencies beyond ElixirOpentui
- Phoenix developers feel instantly at home
- Can later add actual LiveView rendering via `elixir_opentui_live` adapter
- Testable without Phoenix in the dependency tree

**Cons**:
- It's "LiveView-like" but not actual LiveView — subtle differences may confuse
- No access to LiveView's server-side rendering, WebSocket, or JS interop

### Approach B: Actual LiveView with Custom Terminal Transport

Use real Phoenix LiveView, but replace the browser rendering with terminal output:

```elixir
defmodule MyTerminalApp do
  use Phoenix.LiveView  # Real LiveView!

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def handle_event("increment", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end

  def render(assigns) do
    # Instead of HEEx, returns an Element tree
    import ElixirOpentui.View

    box direction: :column do
      text content: "Count: #{assigns.count}"
      button content: "+", on_click: "increment"
    end
  end
end

# Custom transport replaces browser WebSocket with terminal I/O
ElixirOpentui.LiveTransport.start_link(live_view: MyTerminalApp)
```

**Pros**:
- Real LiveView — no API mismatch, full feature set
- `handle_info/2`, PubSub, Presence, LiveComponents all work
- Same app can render to both terminal and browser

**Cons**:
- Phoenix + LiveView become hard dependencies (~large dep tree for a TUI app)
- Custom transport is complex (must implement LiveView's diffing protocol)
- LiveView's render function expects HEEx, not Element trees — requires patching the renderer

## Recommendation

**Start with Approach A** (Phase 7A from the consensus). It delivers 90% of the value — the familiar API — without the dependency cost. Approach B can be explored later as an advanced option for apps that genuinely need both web and terminal rendering.

The key insight: what developers want from "LiveView support" is primarily the **developer experience** (mount/assign/handle_event pattern), not necessarily the LiveView runtime. Approach A delivers that DX immediately.

## What Changes in ElixirOpentui

### New: `ElixirOpentui.Socket`

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

### Modified: `ElixirOpentui.Component`

```elixir
defmodule ElixirOpentui.Component do
  @callback mount(socket :: Socket.t()) :: {:ok, Socket.t()}
  @callback update(assigns :: map(), socket :: Socket.t()) :: {:ok, Socket.t()}
  @callback handle_event(event :: String.t(), params :: map(), socket :: Socket.t()) ::
              {:noreply, Socket.t()}
  @callback handle_info(msg :: term(), socket :: Socket.t()) :: {:noreply, Socket.t()}
  @callback render(assigns :: map()) :: Element.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour ElixirOpentui.Component
      import ElixirOpentui.View
      import ElixirOpentui.Socket, only: [assign: 2, assign: 3]

      # Default implementations
      def update(assigns, socket), do: {:ok, ElixirOpentui.Socket.assign(socket, assigns)}
      def handle_info(_msg, socket), do: {:noreply, socket}

      defoverridable update: 2, handle_info: 2
    end
  end
end
```

### Modified: `ElixirOpentui.Runtime`

The Runtime GenServer needs to:
1. Create `Socket` structs instead of raw state maps for components
2. Route events as `handle_event("name", params, socket)` instead of `update(msg, event, state)`
3. Support `handle_info` by forwarding process messages to the owning component
4. Use tagged tuple returns (`{:ok, socket}`, `{:noreply, socket}`) instead of raw state

## Migration Path

1. **Phase 7A**: Implement Socket + new Component callbacks in `elixir_opentui`
2. Migrate 4 widgets (TextInput, Select, Checkbox, ScrollBox) to new API
3. Update Runtime to dispatch via new callbacks
4. Update all tests
5. **Later**: Build `elixir_opentui_live` adapter for actual LiveView rendering (Phases 7B-7D)
