# Select Interactive Demo
# Run: mix run demo/select_demo.exs
#
# A select list with 10 options and viewport scrolling.
# Up/Down arrows, Home/End, PgUp/PgDown to navigate.
# Press Ctrl+C to exit.

defmodule SelectDemo do
  alias ElixirOpentui.Widgets.Select
  alias ElixirOpentui.Color

  @options [
    "Elixir",
    "Rust",
    "Zig",
    "TypeScript",
    "Python",
    "Go",
    "Haskell",
    "OCaml",
    "Clojure",
    "Erlang"
  ]

  @descriptions %{
    "Elixir" => "Functional, concurrent, runs on BEAM VM",
    "Rust" => "Systems programming with memory safety",
    "Zig" => "Low-level control with high-level features",
    "TypeScript" => "Typed superset of JavaScript",
    "Python" => "Versatile, readable, huge ecosystem",
    "Go" => "Simple, fast, built for concurrency",
    "Haskell" => "Pure functional with strong type system",
    "OCaml" => "ML family with practical focus",
    "Clojure" => "Lisp on the JVM with immutable data",
    "Erlang" => "Battle-tested distributed systems"
  }

  def init(cols, rows) do
    %{
      cols: cols,
      rows: rows,
      select: Select.init(%{
        id: :lang_select,
        options: @options,
        selected: 0,
        visible_count: 6
      })
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true, meta: false}, _state), do: :quit

  def handle_event(%{type: :key} = event, state) do
    new_select = Select.update(:key, event, state.select)
    {:cont, %{state | select: new_select}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(20, 20, 35)
    fg = Color.rgb(200, 200, 200)
    panel_w = min(50, state.cols - 4)

    sel = state.select
    selected_name = Enum.at(@options, sel.selected, "")
    description = Map.get(@descriptions, selected_name, "")
    total = length(@options)
    scroll_pos = "#{sel.scroll_offset + 1}-#{min(sel.scroll_offset + sel.visible_count, total)} of #{total}"

    panel id: :main, title: "Select Demo", width: panel_w, height: 18,
          border: true, fg: fg, bg: bg do

      text(content: "Up/Down, Home/End, PgUp/PgDown to navigate", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "Ctrl+C to quit", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "")

      label(content: "Choose a language:", fg: Color.rgb(100, 220, 100), bg: bg)
      select(
        id: :lang_select,
        options: @options,
        selected: sel.selected,
        scroll_offset: sel.scroll_offset,
        height: sel.visible_count,
        width: panel_w - 6,
        fg: fg,
        bg: bg
      )
      text(content: "")

      text(content: String.duplicate("─", panel_w - 4), fg: Color.rgb(60, 60, 80), bg: bg)

      text(content: " Selected: #{selected_name}", fg: Color.rgb(80, 160, 255), bg: bg)
      text(content: " #{description}", fg: Color.rgb(160, 160, 180), bg: bg)
      text(content: " Showing: #{scroll_pos}", fg: Color.rgb(100, 100, 120), bg: bg)
    end
  end

  def focused_id(_state), do: :lang_select
end

ElixirOpentui.Demo.DemoRunner.run(SelectDemo)
