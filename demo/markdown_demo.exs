# Markdown Interactive Demo
# Run: mix run demo/markdown_demo.exs
#
# Rendered markdown with headings, lists, code blocks, tables, and more.
# Up/Down/PgUp/PgDown/Home to scroll.
# Press Ctrl+C to exit.

defmodule MarkdownDemo do
  alias ElixirOpentui.Widgets.Markdown
  alias ElixirOpentui.Color

  @viewport 20

  # Rich markdown showcasing various features (inspired by OpenTUI's markdown-demo)
  @sample_markdown """
  # ElixirOpentui Markdown Demo

  Welcome to the **MarkdownRenderable** showcase! This demonstrates rich markdown rendering in the terminal.

  ## Features

  - Automatic **heading** styling at multiple levels
  - Proper handling of `inline code`, **bold**, and *italic* text
  - Fenced code blocks with language detection
  - Ordered and unordered lists
  - Blockquotes and horizontal rules

  ## Code Examples

  Here's how to create a component:

  ```elixir
  defmodule Counter do
    use ElixirOpentui.Component

    def init(props) do
      %{count: Map.get(props, :initial, 0)}
    end

    def update(:increment, _event, state) do
      %{state | count: state.count + 1}
    end

    def render(state) do
      import ElixirOpentui.View
      text(content: "Count: \#{state.count}")
    end
  end
  ```

  And here's a GenServer example:

  ```elixir
  defmodule MyApp.Worker do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(opts) do
      schedule_work()
      {:ok, %{interval: Keyword.get(opts, :interval, 5000)}}
    end

    def handle_info(:work, state) do
      perform_work()
      schedule_work(state.interval)
      {:noreply, state}
    end

    defp schedule_work(interval \\\\ 5000) do
      Process.send_after(self(), :work, interval)
    end

    defp perform_work, do: :ok
  end
  ```

  ## Architecture

  The rendering pipeline works as follows:

  1. **Element tree** built from View DSL macros
  2. **Layout** engine computes positions and sizes
  3. **Painter** renders elements to a buffer
  4. **Buffer** holds a 2D grid of styled cells
  5. **ANSI diff** produces minimal escape sequences

  > The design prioritizes minimal terminal updates for smooth rendering.
  > Each frame only redraws cells that actually changed.

  ---

  ### Widget Catalog

  Built-in widgets include:

  - **TextInput** — single-line text editing with cursor
  - **TextArea** — multi-line editing with undo/redo and selection
  - **Select** — scrollable option list with keyboard navigation
  - **Checkbox** — toggleable boolean with custom labels
  - **ScrollBox** — scrollable container with mouse support
  - **TabSelect** — horizontal tab navigation with descriptions
  - **Code** — syntax-highlighted source code display
  - **Diff** — unified and split diff views with line numbers
  - **Markdown** — rendered markdown content (this widget!)
  - **LineNumber** — gutter with signs, colors, and markers

  ### Getting Started

  Add the dependency to your `mix.exs`:

  ```elixir
  {:elixir_opentui, "~> 0.1.0"}
  ```

  Then run:

  ```elixir
  mix deps.get
  mix zig.get
  mix compile
  ```

  ## FAQ

  > **Q:** Does it support mouse input?
  >
  > **A:** Yes! ScrollBox and Select both handle mouse scroll events.

  > **Q:** Can I use custom colors?
  >
  > **A:** Absolutely. Use `Color.rgb(r, g, b)` for 24-bit true color.

  ---

  *Built with Elixir + Zig NIFs for maximum performance.*
  """

  def init(cols, rows) do
    %{
      cols: cols,
      rows: rows,
      md: Markdown.init(%{
        id: :md_view,
        content: String.trim(@sample_markdown),
        scroll_offset: 0,
        visible_lines: @viewport
      })
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true}, _state), do: :quit

  def handle_event(%{type: :key} = event, state) do
    new_md = Markdown.update(:key, event, state.md)
    {:cont, %{state | md: new_md}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(13, 17, 23)
    fg = Color.rgb(230, 237, 243)
    panel_w = min(76, state.cols - 4)

    md_state = state.md
    status_str = "Scroll: #{md_state.scroll_offset} | Blocks: #{length(md_state.blocks)}"

    panel id: :main, title: "Markdown Demo",
          width: panel_w, height: @viewport + 7,
          border: true, fg: fg, bg: bg do

      text(content: "↑/↓/PgUp/PgDn/Home to scroll", fg: Color.rgb(136, 136, 136), bg: bg)
      text(content: "Ctrl+C to quit", fg: Color.rgb(136, 136, 136), bg: bg)
      text(content: "")

      markdown(
        id: :md_view,
        content: md_state.content,
        blocks: md_state.blocks,
        block_count: length(md_state.blocks),
        scroll_offset: md_state.scroll_offset,
        visible_lines: @viewport,
        width: panel_w - 4
      )

      text(content: "")
      text(content: String.duplicate("─", panel_w - 4), fg: Color.rgb(60, 60, 80), bg: bg)
      text(content: " #{status_str}", fg: Color.rgb(165, 214, 255), bg: bg)
    end
  end

  def focused_id(_state), do: :md_view
end

ElixirOpentui.Demo.DemoRunner.run(MarkdownDemo)
