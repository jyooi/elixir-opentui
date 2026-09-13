defmodule ElixirOpentui.Renderer do
  @moduledoc """
  Terminal renderer with diff-based updates.

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

  @doc "Paint an element tree into a fresh buffer and return {renderer, buffer}."
  def paint(%__MODULE__{cols: cols, rows: rows} = renderer, tree, opts \\ []) do
    {tagged, layout_results} = Layout.compute(tree, cols, rows)
    painted = Painter.paint(tagged, layout_results, Buffer.new(cols, rows), opts)
    {%{renderer | front: painted, frame_count: renderer.frame_count + 1}, painted}
  end

  @doc "Render an element tree and return {renderer, ansi_iodata}."
  def render(%__MODULE__{front: front} = renderer, tree, opts \\ []) do
    {new_renderer, painted} = paint(renderer, tree, opts)
    {new_renderer, ANSI.frame(ANSI.render_diff(Buffer.diff(front, painted)))}
  end

  @doc "Force a full redraw (no diff, re-render everything)."
  def render_full(%__MODULE__{} = renderer, tree, opts \\ []) do
    {new_renderer, painted} = paint(renderer, tree, opts)
    {new_renderer, ANSI.frame([ANSI.clear_screen(), ANSI.render_full(painted)])}
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
