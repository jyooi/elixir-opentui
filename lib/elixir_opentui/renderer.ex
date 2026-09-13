defmodule ElixirOpentui.Renderer do
  @moduledoc """
  Full terminal renderer with double buffering and diff-based updates.

  Keeps the last painted frame, computes layout, paints elements,
  diffs the result, and outputs minimal ANSI sequences.

  Can operate in two modes:
  - Live mode: writes to Terminal driver (real terminal)
  - Capture mode: returns ANSI output as iodata (for testing)
  """

  alias ElixirOpentui.{Buffer, Layout, Painter, ANSI}

  @type t :: %__MODULE__{
          cols: non_neg_integer(),
          rows: non_neg_integer(),
          front: Buffer.t(),
          frame_count: non_neg_integer()
        }

  defstruct [:cols, :rows, :front, frame_count: 0]

  @doc "Create a new renderer with given dimensions."
  def new(cols, rows) do
    %__MODULE__{cols: cols, rows: rows, front: Buffer.new(cols, rows), frame_count: 0}
  end

  @doc "Render an element tree and return {renderer, ansi_iodata}."
  def render(%__MODULE__{cols: cols, rows: rows, front: front} = renderer, tree, opts \\ []) do
    {tagged, layout_results} = Layout.compute(tree, cols, rows)

    back = Buffer.new(cols, rows)
    painted = Painter.paint(tagged, layout_results, back, opts)

    changes = Buffer.diff(front, painted)
    ansi_output = ANSI.render_diff(changes)

    new_renderer = %{renderer | front: painted, frame_count: renderer.frame_count + 1}

    {new_renderer, ANSI.frame(ansi_output)}
  end

  @doc "Force a full redraw (no diff, re-render everything)."
  def render_full(%__MODULE__{cols: cols, rows: rows} = renderer, tree, opts \\ []) do
    {tagged, layout_results} = Layout.compute(tree, cols, rows)

    back = Buffer.new(cols, rows)
    painted = Painter.paint(tagged, layout_results, back, opts)

    ansi_output = ANSI.render_full(painted)

    new_renderer = %{renderer | front: painted, frame_count: renderer.frame_count + 1}

    {new_renderer, ANSI.frame([ANSI.clear_screen(), ansi_output])}
  end

  @doc "Resize the renderer. Next render will be a full redraw."
  def resize(%__MODULE__{}, cols, rows), do: new(cols, rows)

  @doc "Get the front buffer (last rendered frame)."
  def get_buffer(%__MODULE__{front: front}), do: front

  @doc "Get the layout results from the last render. Requires re-computation."
  def compute_layout(%__MODULE__{cols: cols, rows: rows}, tree) do
    Layout.compute(tree, cols, rows)
  end
end
