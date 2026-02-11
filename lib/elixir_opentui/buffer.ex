defmodule ElixirOpentui.Buffer do
  @moduledoc """
  Cell-based terminal buffer. Each cell stores a character, fg/bg colors, and attributes.

  Maps to ElixirOpentui's OptimizedBuffer. This is the "framebuffer" — layout and painting
  write cells into this buffer, and the renderer diffs it against the previous frame
  to produce minimal ANSI output.
  """

  @behaviour ElixirOpentui.BufferBehaviour

  alias ElixirOpentui.Color

  @type cell :: %{
          char: String.t(),
          fg: Color.t(),
          bg: Color.t(),
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          strikethrough: boolean(),
          dim: boolean(),
          inverse: boolean(),
          blink: boolean(),
          hidden: boolean(),
          hit_id: term()
        }

  @type t :: %__MODULE__{
          cols: non_neg_integer(),
          rows: non_neg_integer(),
          cells: :array.array(cell()),
          default_fg: Color.t(),
          default_bg: Color.t(),
          scissor_stack: [{integer(), integer(), integer(), integer()}]
        }

  defstruct cols: 0, rows: 0, cells: nil, default_fg: nil, default_bg: nil, scissor_stack: []

  @default_fg {255, 255, 255, 255}
  @default_bg {0, 0, 0, 255}

  @doc "Create a new buffer with the given dimensions."
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def new(cols, rows, opts \\ []) do
    fg = Keyword.get(opts, :fg, @default_fg)
    bg = Keyword.get(opts, :bg, @default_bg)
    empty = blank_cell(fg, bg)
    cells = :array.new(cols * rows, default: empty)

    %__MODULE__{cols: cols, rows: rows, cells: cells, default_fg: fg, default_bg: bg}
  end

  @doc "Get the cell at (x, y). Returns nil if out of bounds."
  @spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: cell() | nil
  def get_cell(%__MODULE__{cols: cols, rows: rows, cells: cells}, x, y)
      when x >= 0 and x < cols and y >= 0 and y < rows do
    :array.get(y * cols + x, cells)
  end

  def get_cell(_, _, _), do: nil

  @doc "Set a cell at (x, y). No-op if out of bounds or outside scissor rect."
  @spec put_cell(t(), non_neg_integer(), non_neg_integer(), cell()) :: t()
  def put_cell(%__MODULE__{} = buf, x, y, cell) do
    if in_scissor?(buf, x, y) do
      %{buf | cells: :array.set(y * buf.cols + x, cell, buf.cells)}
    else
      buf
    end
  end

  def put_cell(buf, _, _, _), do: buf

  @doc "Push a scissor rect. Drawing is clipped to the intersection of all active scissor rects."
  def push_scissor(%__MODULE__{scissor_stack: stack} = buf, x, y, w, h) do
    parent =
      case stack do
        [] -> {0, 0, buf.cols, buf.rows}
        [top | _] -> top
      end

    clipped = intersect_rect({x, y, w, h}, parent)
    %{buf | scissor_stack: [clipped | stack]}
  end

  @doc "Pop the top scissor rect, restoring the previous clip region."
  def pop_scissor(%__MODULE__{scissor_stack: [_ | rest]} = buf) do
    %{buf | scissor_stack: rest}
  end

  def pop_scissor(buf), do: buf

  @doc "Write a character at (x, y) with fg/bg colors and optional text attributes."
  @spec draw_char(t(), non_neg_integer(), non_neg_integer(), String.t(), Color.t(), Color.t(), keyword()) ::
          t()
  def draw_char(buf, x, y, char, fg, bg, attrs \\ []) do
    cell = %{blank_cell(fg, bg) | char: char}
    cell = apply_attrs(cell, attrs)
    put_cell(buf, x, y, cell)
  end

  @doc "Write a character with alpha blending over existing cell."
  @spec draw_char_blend(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          Color.t(),
          Color.t(),
          keyword()
        ) :: t()
  def draw_char_blend(buf, x, y, char, fg, bg, attrs \\ []) do
    case get_cell(buf, x, y) do
      nil ->
        buf

      existing ->
        blended_fg = Color.blend(fg, existing.fg)
        blended_bg = Color.blend(bg, existing.bg)
        draw_char(buf, x, y, char, blended_fg, blended_bg, attrs)
    end
  end

  @doc "Write a string horizontally starting at (x, y) with optional text attributes."
  @spec draw_text(t(), non_neg_integer(), non_neg_integer(), String.t(), Color.t(), Color.t(), keyword()) ::
          t()
  def draw_text(buf, x, y, text, fg, bg, attrs \\ []) do
    text
    |> String.graphemes()
    |> Enum.reduce({buf, x}, fn grapheme, {b, cx} ->
      {draw_char(b, cx, y, grapheme, fg, bg, attrs), cx + 1}
    end)
    |> elem(0)
  end

  @doc "Fill a rectangular region with a character, colors, and optional text attributes."
  @spec fill_rect(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          Color.t(),
          Color.t(),
          keyword()
        ) :: t()
  def fill_rect(buf, x, y, w, h, char, fg, bg, attrs \\ []) do
    for cy <- y..(y + h - 1)//1,
        cx <- x..(x + w - 1)//1,
        reduce: buf do
      acc -> draw_char(acc, cx, cy, char, fg, bg, attrs)
    end
  end

  @doc "Set hit_id for a rectangular region (for mouse event targeting)."
  @spec set_hit_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          term()
        ) :: t()
  def set_hit_region(buf, x, y, w, h, hit_id) do
    for cy <- y..(y + h - 1)//1,
        cx <- x..(x + w - 1)//1,
        reduce: buf do
      acc ->
        case get_cell(acc, cx, cy) do
          nil -> acc
          cell -> put_cell(acc, cx, cy, %{cell | hit_id: hit_id})
        end
    end
  end

  @doc "Get the hit_id at coordinates (x, y)."
  @spec get_hit_id(t(), non_neg_integer(), non_neg_integer()) :: term()
  def get_hit_id(buf, x, y) do
    case get_cell(buf, x, y) do
      nil -> nil
      cell -> cell.hit_id
    end
  end

  @doc "Clear the buffer to blank cells."
  @spec clear(t()) :: t()
  def clear(%__MODULE__{cols: cols, rows: rows, default_fg: fg, default_bg: bg} = buf) do
    empty = blank_cell(fg, bg)
    %{buf | cells: :array.new(cols * rows, default: empty)}
  end

  @doc "Resize the buffer. Contents are lost."
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  def resize(%__MODULE__{default_fg: fg, default_bg: bg}, cols, rows) do
    new(cols, rows, fg: fg, bg: bg)
  end

  @doc "Extract a rectangular region as a list of rows (list of cells)."
  @spec capture_rect(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [[cell()]]
  def capture_rect(buf, x, y, w, h) do
    for cy <- y..(y + h - 1)//1 do
      for cx <- x..(x + w - 1)//1 do
        get_cell(buf, cx, cy) || blank_cell(buf.default_fg, buf.default_bg)
      end
    end
  end

  @doc "Convert the full buffer to a list of row strings (for testing/display)."
  @spec to_strings(t()) :: [String.t()]
  def to_strings(%__MODULE__{cols: cols, rows: rows} = buf) do
    for y <- 0..(rows - 1)//1 do
      for x <- 0..(cols - 1)//1, into: "" do
        case get_cell(buf, x, y) do
          nil -> " "
          %{char: char} -> char
        end
      end
    end
  end

  @doc "Diff two buffers, returning list of {x, y, new_cell} changes."
  @spec diff(t(), t()) :: [{non_neg_integer(), non_neg_integer(), cell()}]
  def diff(%__MODULE__{cols: cols, rows: rows, cells: old}, %__MODULE__{
        cols: cols,
        rows: rows,
        cells: new_cells
      }) do
    for i <- 0..(cols * rows - 1),
        old_cell = :array.get(i, old),
        new_cell = :array.get(i, new_cells),
        old_cell != new_cell do
      x = rem(i, cols)
      y = div(i, cols)
      {x, y, new_cell}
    end
  end

  def diff(_, _), do: []

  defp in_scissor?(%__MODULE__{scissor_stack: [], cols: cols, rows: rows}, x, y) do
    x >= 0 and x < cols and y >= 0 and y < rows
  end

  defp in_scissor?(%__MODULE__{scissor_stack: [{sx, sy, sw, sh} | _]}, x, y) do
    x >= sx and x < sx + sw and y >= sy and y < sy + sh
  end

  defp intersect_rect({x1, y1, w1, h1}, {x2, y2, w2, h2}) do
    left = max(x1, x2)
    top = max(y1, y2)
    right = min(x1 + w1, x2 + w2)
    bottom = min(y1 + h1, y2 + h2)
    {left, top, max(0, right - left), max(0, bottom - top)}
  end

  defp blank_cell(fg, bg) do
    %{
      char: " ",
      fg: fg,
      bg: bg,
      bold: false,
      italic: false,
      underline: false,
      strikethrough: false,
      dim: false,
      inverse: false,
      blink: false,
      hidden: false,
      hit_id: nil
    }
  end

  defp apply_attrs(cell, []), do: cell

  defp apply_attrs(cell, attrs) do
    Enum.reduce(attrs, cell, fn
      {:bold, v}, c -> %{c | bold: v}
      {:italic, v}, c -> %{c | italic: v}
      {:underline, v}, c -> %{c | underline: v}
      {:strikethrough, v}, c -> %{c | strikethrough: v}
      {:dim, v}, c -> %{c | dim: v}
      {:inverse, v}, c -> %{c | inverse: v}
      {:blink, v}, c -> %{c | blink: v}
      {:hidden, v}, c -> %{c | hidden: v}
      _, c -> c
    end)
  end
end
