# TabSelect Interactive Demo
# Run: mix run demo/tab_select_demo.exs
#
# Horizontal tab selection with scroll arrows.
# Left/Right arrows or [/] to navigate tabs.
# Press Ctrl+C to exit.

defmodule TabSelectDemo do
  alias ElixirOpentui.Widgets.TabSelect
  alias ElixirOpentui.Color

  @options [
    %{name: "Elixir", description: "Functional, concurrent, BEAM VM"},
    %{name: "Rust", description: "Systems programming, memory safe"},
    %{name: "Zig", description: "Low-level with high-level features"},
    %{name: "TypeScript", description: "Typed JavaScript superset"},
    %{name: "Python", description: "Versatile, readable, huge ecosystem"},
    %{name: "Go", description: "Simple, fast, built for concurrency"},
    %{name: "Haskell", description: "Pure functional, strong types"},
    %{name: "OCaml", description: "ML family, practical focus"}
  ]

  def init(cols, rows) do
    %{
      cols: cols,
      rows: rows,
      tabs: TabSelect.init(%{
        id: :lang_tabs,
        options: @options,
        selected: 0,
        tab_width: 14,
        width: min(56, cols - 4) - 4,
        wrap_selection: true,
        show_description: true,
        show_underline: true,
        show_scroll_arrows: true
      })
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true}, _state), do: :quit

  def handle_event(%{type: :key} = event, state) do
    new_tabs = TabSelect.update(:key, event, state.tabs)
    {:cont, %{state | tabs: new_tabs}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(20, 20, 35)
    fg = Color.rgb(200, 200, 200)
    panel_w = min(56, state.cols - 4)

    tabs = state.tabs
    total = length(tabs.options)
    selected_opt = Enum.at(tabs.options, tabs.selected)
    selected_name = if selected_opt, do: selected_opt.name, else: ""
    selected_desc = if selected_opt, do: selected_opt.description || "", else: ""
    scroll_info = "Tab #{tabs.selected + 1} of #{total} (scroll: #{tabs.scroll_offset})"

    panel id: :main, title: "TabSelect Demo", width: panel_w, height: 14,
          border: true, fg: fg, bg: bg do

      text(content: "Left/Right or [/] to navigate tabs", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "Ctrl+C to quit", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "")

      tab_select(
        id: :lang_tabs,
        options: @options,
        selected: tabs.selected,
        scroll_offset: tabs.scroll_offset,
        tab_width: tabs.tab_width,
        width: panel_w - 4,
        show_description: true,
        show_underline: true,
        show_scroll_arrows: true
      )

      text(content: "")
      text(content: String.duplicate("─", panel_w - 4), fg: Color.rgb(60, 60, 80), bg: bg)

      text(content: " Selected: #{selected_name}", fg: Color.rgb(80, 160, 255), bg: bg)
      text(content: " #{selected_desc}", fg: Color.rgb(160, 160, 180), bg: bg)
      text(content: " #{scroll_info}", fg: Color.rgb(100, 100, 120), bg: bg)
    end
  end

  def focused_id(_state), do: :lang_tabs
end

ElixirOpentui.Demo.DemoRunner.run(TabSelectDemo)
