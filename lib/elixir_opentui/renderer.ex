defmodule ElixirOpentui.Renderer do
  @moduledoc """
  Full terminal renderer with double buffering and diff-based updates.

  Manages two buffers (front/back), computes layout, paints elements,
  diffs the result, and outputs minimal ANSI sequences.

  Supports two backends:
  - `:elixir` (default) — pure Elixir Buffer with diff-based ANSI
  - `:native` — NIF-backed NativeBuffer with native diff/ANSI

  Can operate in two modes:
  - Live mode: writes to Terminal driver (real terminal)
  - Capture mode: returns ANSI output as iodata (for testing)
  """

  alias ElixirOpentui.{Buffer, NativeBuffer, Layout, Painter, ANSI}

  @type t :: %__MODULE__{
          cols: non_neg_integer(),
          rows: non_neg_integer(),
          front: Buffer.t() | NativeBuffer.t(),
          back: Buffer.t() | nil,
          native_buf: NativeBuffer.t() | nil,
          backend: :elixir | :native,
          frame_count: non_neg_integer()
        }

  defstruct [:cols, :rows, :front, :back, :native_buf, backend: :elixir, frame_count: 0]

  @doc "Create a new renderer with given dimensions."
  def new(cols, rows, opts \\ []) do
    backend = Keyword.get(opts, :backend, :elixir)

    case backend do
      :native ->
        nbuf = NativeBuffer.new(cols, rows)

        %__MODULE__{
          cols: cols,
          rows: rows,
          native_buf: nbuf,
          front: nbuf,
          backend: :native,
          frame_count: 0
        }

      _ ->
        %__MODULE__{
          cols: cols,
          rows: rows,
          front: Buffer.new(cols, rows),
          back: Buffer.new(cols, rows),
          backend: :elixir,
          frame_count: 0
        }
    end
  end

  @doc "Render an element tree and return {renderer, ansi_iodata}."
  def render(%__MODULE__{backend: :native} = renderer, tree) do
    %{cols: cols, rows: rows, native_buf: nbuf} = renderer
    {tagged, layout_results} = Layout.compute(tree, cols, rows)

    nbuf = NativeBuffer.clear(nbuf)
    nbuf = Painter.paint(tagged, layout_results, nbuf)
    {nbuf, ansi} = NativeBuffer.render_frame_capture(nbuf)

    new_renderer = %{
      renderer
      | native_buf: nbuf,
        front: nbuf,
        frame_count: renderer.frame_count + 1
    }

    {new_renderer, ansi}
  end

  def render(%__MODULE__{cols: cols, rows: rows, front: front} = renderer, tree) do
    {tagged, layout_results} = Layout.compute(tree, cols, rows)

    back = Buffer.new(cols, rows)
    painted = Painter.paint(tagged, layout_results, back)

    changes = Buffer.diff(front, painted)
    ansi_output = ANSI.render_diff(changes)

    new_renderer = %{
      renderer
      | front: painted,
        back: front,
        frame_count: renderer.frame_count + 1
    }

    {new_renderer, ANSI.frame(ansi_output)}
  end

  @doc "Force a full redraw (no diff, re-render everything)."
  def render_full(%__MODULE__{backend: :native} = renderer, tree) do
    %{cols: cols, rows: rows} = renderer
    {tagged, layout_results} = Layout.compute(tree, cols, rows)

    nbuf = NativeBuffer.new(cols, rows)
    nbuf = NativeBuffer.clear(nbuf)
    nbuf = Painter.paint(tagged, layout_results, nbuf)
    {nbuf, ansi} = NativeBuffer.render_frame_capture(nbuf)

    new_renderer = %{
      renderer
      | native_buf: nbuf,
        front: nbuf,
        frame_count: renderer.frame_count + 1
    }

    {new_renderer, ansi}
  end

  def render_full(%__MODULE__{cols: cols, rows: rows} = renderer, tree) do
    {tagged, layout_results} = Layout.compute(tree, cols, rows)

    back = Buffer.new(cols, rows)
    painted = Painter.paint(tagged, layout_results, back)

    ansi_output = ANSI.render_full(painted)

    new_renderer = %{
      renderer
      | front: painted,
        back: Buffer.new(cols, rows),
        frame_count: renderer.frame_count + 1
    }

    {new_renderer, ANSI.frame([ANSI.clear_screen(), ansi_output])}
  end

  @doc "Resize the renderer. Next render will be a full redraw."
  def resize(%__MODULE__{backend: backend}, cols, rows) do
    new(cols, rows, backend: backend)
  end

  @doc "Get the front buffer (last rendered frame)."
  def get_buffer(%__MODULE__{front: front}), do: front

  @doc "Get the layout results from the last render. Requires re-computation."
  def compute_layout(%__MODULE__{cols: cols, rows: rows}, tree) do
    Layout.compute(tree, cols, rows)
  end
end
