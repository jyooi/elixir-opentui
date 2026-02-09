# Elm/TEA vs LiveView Model Comparison

## Current Architecture: The Elm Architecture (TEA)

ElixirOpentui currently uses a pure MVU (Model-View-Update) pattern, also known as The Elm Architecture:

```
Model (state) → View (render) → Update (handle message) → Model ...
```

### Current Component Callbacks

```elixir
@callback init(props :: map()) :: state
@callback update(msg, event, state) :: state
@callback render(state) :: Element.t()
```

### Characteristics of Current Model

| Aspect | Current Elm/TEA |
|--------|----------------|
| State management | Plain maps/structs |
| Event handling | Pattern match on `msg` atom in `update/3` |
| Side effects | None — pure functions only |
| Async work | Not supported |
| Subscriptions | Not supported |
| Inter-process comms | Not supported |
| Return values | Raw state (no tuples) |

## Proposed: LiveView Model

### Proposed Component Callbacks

```elixir
@callback mount(socket :: Socket.t()) :: {:ok, Socket.t()}
@callback update(assigns :: map(), socket :: Socket.t()) :: {:ok, Socket.t()}
@callback handle_event(event, params, socket) :: {:noreply, Socket.t()}
@callback handle_info(msg, socket) :: {:noreply, Socket.t()}    # NEW
@callback render(assigns :: map()) :: Element.t()
```

### What LiveView Adds on Top of TEA

| Aspect | LiveView Model |
|--------|---------------|
| State management | `Socket.assigns` (structured map with helpers) |
| Event handling | `handle_event/3` (named events with params) |
| Side effects | `handle_info/2` for async results |
| Async work | `Task.async` + `handle_info/2` |
| Subscriptions | `Phoenix.PubSub.subscribe` in `mount` |
| Inter-process comms | Standard GenServer messages via `handle_info` |
| Return values | Tagged tuples (`{:ok, socket}`, `{:noreply, socket}`) |

## Side-by-Side: Counter Example

### Elm/TEA (Current)

```elixir
defmodule Counter do
  use ElixirOpentui.Component

  def init(_props), do: %{count: 0}

  def update(:increment, _event, state) do
    %{state | count: state.count + 1}
  end

  def update(:decrement, _event, state) do
    %{state | count: state.count - 1}
  end

  def render(state) do
    import ElixirOpentui.View
    box direction: :row do
      button content: "-", on_click: :decrement
      text content: "#{state.count}"
      button content: "+", on_click: :increment
    end
  end
end
```

### LiveView Model (Proposed)

```elixir
defmodule Counter do
  use ElixirOpentui.Component

  def mount(socket) do
    {:ok, assign(socket, count: 0)}
  end

  def handle_event("increment", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end

  def handle_event("decrement", _params, socket) do
    {:noreply, assign(socket, count: socket.assigns.count - 1)}
  end

  def render(assigns) do
    import ElixirOpentui.View
    box direction: :row do
      button content: "-", on_click: "decrement"
      text content: "#{assigns.count}"
      button content: "+", on_click: "increment"
    end
  end
end
```

## Side-by-Side: Async Data Loading

### Elm/TEA (Current) — NOT POSSIBLE

```elixir
# There is no mechanism for async work.
# update/3 must return state synchronously.
# No handle_info callback exists.
```

### LiveView Model (Proposed)

```elixir
defmodule UserList do
  use ElixirOpentui.Component

  def mount(socket) do
    # Kick off async data fetch
    Task.async(fn -> MyApp.Repo.all(User) end)
    {:ok, assign(socket, users: [], loading: true)}
  end

  def handle_info({ref, users}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, users: users, loading: false)}
  end

  def render(assigns) do
    import ElixirOpentui.View
    box direction: :column do
      if assigns.loading do
        text content: "Loading..."
      else
        for user <- assigns.users do
          text content: user.name
        end
      end
    end
  end
end
```

## Side-by-Side: PubSub Subscriptions

### Elm/TEA (Current) — NOT POSSIBLE

```elixir
# No subscription mechanism.
# Components cannot receive messages from other processes.
```

### LiveView Model (Proposed)

```elixir
defmodule ChatRoom do
  use ElixirOpentui.Component

  def mount(socket) do
    Phoenix.PubSub.subscribe(MyApp.PubSub, "chat:lobby")
    {:ok, assign(socket, messages: [])}
  end

  def handle_info({:new_message, msg}, socket) do
    messages = socket.assigns.messages ++ [msg]
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_event("send", %{"text" => text}, socket) do
    Phoenix.PubSub.broadcast(MyApp.PubSub, "chat:lobby", {:new_message, text})
    {:noreply, socket}
  end

  def render(assigns) do
    import ElixirOpentui.View
    box direction: :column do
      scroll_box height: 20 do
        for msg <- assigns.messages do
          text content: msg
        end
      end
      input id: :chat_input, placeholder: "Type a message..."
    end
  end
end
```

## The Gap Analysis

The core insight: **LiveView is a superset of TEA**. It includes the full MVU loop (mount/render/handle_event) PLUS:

| Capability | TEA | LiveView | Gap |
|-----------|-----|----------|-----|
| Pure state transitions | Yes | Yes | None |
| Named events with params | Atoms only | Strings + maps | Minor |
| Structured state access | Raw maps | `socket.assigns` | Minor |
| Async work | No | `handle_info/2` | **Major** |
| Process messaging | No | `handle_info/2` | **Major** |
| PubSub subscriptions | No | `subscribe` + `handle_info` | **Major** |
| Timers / intervals | No | `Process.send_after` + `handle_info` | **Major** |
| Return value extension | No | Tagged tuples | Moderate |

The three **major** gaps all stem from the same missing piece: `handle_info/2`. Adding this single callback to the Component behaviour bridges most of the gap between TEA and LiveView.
