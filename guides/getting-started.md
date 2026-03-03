# Getting Started

Build your first terminal UI app in 5 minutes.

## Prerequisites

- Elixir ~> 1.19
- OTP 28 or later (check with `elixir --version`)

## Setup

Create a new Mix project and add ElixirOpentui:

```bash
mix new my_tui_app
cd my_tui_app
```

Add the dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:elixir_opentui, "~> 0.1.0"}
  ]
end
```

Then install and set up the Zig toolchain:

```bash
mix deps.get
mix zig.get
mix compile
```

The `mix zig.get` step downloads a Zig compiler — this is needed to compile the NIF
that handles fast buffer operations. It only runs once.

## Your first app: a counter

Create a file called `counter.exs` in your project root:

```elixir
defmodule Counter do
  alias ElixirOpentui.Color

  def init(_cols, _rows) do
    %{count: 0}
  end

  def handle_event(%{type: :key, key: "c", ctrl: true}, _state), do: :quit

  def handle_event(%{type: :key, key: :up}, state) do
    {:cont, %{state | count: state.count + 1}}
  end

  def handle_event(%{type: :key, key: :down}, state) do
    {:cont, %{state | count: max(0, state.count - 1)}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(20, 20, 35)
    fg = Color.rgb(200, 200, 200)

    panel id: :main, title: "Counter", width: 30, height: 7,
          border: true, fg: fg, bg: bg do
      text(content: "Count: #{state.count}", fg: Color.rgb(100, 220, 100), bg: bg)
      text(content: "")
      text(content: "Up/Down to change", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "Ctrl+C to quit", fg: Color.rgb(100, 100, 100), bg: bg)
    end
  end

  def focused_id(_state), do: nil
end

ElixirOpentui.Demo.DemoRunner.run(Counter)
```

Run it:

```bash
mix run counter.exs
```

You should see a bordered panel with a counter. Press Up/Down to change the value,
Ctrl+C to exit.

## How the pattern works

Every ElixirOpentui app implements four functions:

### `init(cols, rows)`

Called once at startup with the terminal dimensions. Returns your initial state — just
a plain map.

```elixir
def init(cols, rows) do
  %{count: 0, cols: cols, rows: rows}
end
```

### `handle_event(event, state)`

Called whenever the user presses a key, clicks the mouse, or pastes text. You
pattern-match on the event and return either:

- `{:cont, new_state}` — keep running with updated state
- `:quit` — exit the app

```elixir
def handle_event(%{type: :key, key: :up}, state) do
  {:cont, %{state | count: state.count + 1}}
end
```

Key events look like `%{type: :key, key: "a", ctrl: false, shift: false, meta: false}`.
Special keys use atoms: `:up`, `:down`, `:left`, `:right`, `:tab`, `:enter`, `:escape`,
`:backspace`, `:home`, `:end`, `:page_up`, `:page_down`.

### `render(state)`

Called after every event. Returns a UI tree built with the View DSL. The framework
diffs the output against the previous frame and only redraws what changed.

```elixir
def render(state) do
  import ElixirOpentui.View

  panel id: :main, title: "My App", width: 40, height: 10, border: true do
    text(content: "Hello from ElixirOpentui!")
  end
end
```

### `focused_id(state)`

Returns the id of the currently focused widget, or `nil` if nothing is focused.
This tells the framework which widget should receive keyboard input and show
focus styling.

```elixir
def focused_id(state), do: :my_input
```

## Adding a widget

Let's add a text input to the counter. Widgets manage their own state — you
initialize them in `init`, route events to them in `handle_event`, and render
their state in `render`.

```elixir
defmodule CounterWithInput do
  alias ElixirOpentui.Widgets.TextInput
  alias ElixirOpentui.Color

  def init(cols, _rows) do
    %{
      count: 0,
      input: TextInput.init(%{id: :name, placeholder: "Your name...", width: min(25, cols - 10)})
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true}, _state), do: :quit

  def handle_event(%{type: :key, key: :up}, state) do
    {:cont, %{state | count: state.count + 1}}
  end

  def handle_event(%{type: :key, key: :down}, state) do
    {:cont, %{state | count: max(0, state.count - 1)}}
  end

  # Route other key events to the text input widget
  def handle_event(%{type: :key} = event, state) do
    {:cont, %{state | input: TextInput.update(:key, event, state.input)}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(20, 20, 35)
    fg = Color.rgb(200, 200, 200)

    panel id: :main, title: "Counter + Input", width: 35, height: 10,
          border: true, fg: fg, bg: bg do
      text(content: "Count: #{state.count}", fg: Color.rgb(100, 220, 100), bg: bg)
      text(content: "")

      label(content: "Name:", fg: Color.rgb(100, 220, 100), bg: bg)
      input(
        id: :name,
        value: state.input.value,
        placeholder: state.input.placeholder,
        cursor_pos: state.input.cursor_pos,
        scroll_offset: state.input.scroll_offset,
        width: state.input.width,
        height: 1,
        bg: Color.rgb(40, 40, 60),
        fg: fg
      )
      text(content: "")
      text(content: "Up/Down: count | Type: input", fg: Color.rgb(100, 100, 100), bg: bg)
    end
  end

  def focused_id(_state), do: :name
end

ElixirOpentui.Demo.DemoRunner.run(CounterWithInput)
```

The pattern for any widget is the same:
1. `WidgetModule.init(%{...})` in your `init/2`
2. `WidgetModule.update(:key, event, widget_state)` in your `handle_event/2`
3. Render the widget's state as element attributes in your `render/1`

## Next steps

- Browse the `demo/` directory for more examples — there are 17 of them covering
  every widget and feature
- Check out `demo/widget_gallery.exs` to see all the basic widgets together
- Look at `demo/text_area_demo.exs` for multi-line editing with undo/redo
- Look at `demo/animation_demo.exs` for timeline-based animations
