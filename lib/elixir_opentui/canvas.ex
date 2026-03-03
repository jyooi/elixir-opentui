defmodule ElixirOpentui.Canvas do
  @moduledoc """
  User-facing drawing surface for the `:frame_buffer` widget type.

  Cells are stored in a Map keyed by `{x, y}` for O(1) overwrites.
  The painter iterates unique cells only — no duplicate draws.
  """

  alias ElixirOpentui.Color

  @type cell :: {String.t(), Color.t(), Color.t()}
  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          cells: %{{integer(), integer()} => cell()}
        }

  defstruct width: 0, height: 0, cells: %{}

  @doc "Create an empty canvas of the given dimensions."
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height) do
    %__MODULE__{width: width, height: height, cells: %{}}
  end

  @doc "Set a single cell at `{x, y}`. Overwrites any existing cell at that position."
  @spec set_cell(t(), integer(), integer(), String.t(), Color.t(), Color.t()) :: t()
  def set_cell(%__MODULE__{} = canvas, x, y, char, fg, bg) do
    %{canvas | cells: Map.put(canvas.cells, {x, y}, {char, fg, bg})}
  end

  @doc "Draw a text string starting at `{x, y}`, advancing x per grapheme."
  @spec draw_text(t(), integer(), integer(), String.t(), Color.t(), Color.t()) :: t()
  def draw_text(%__MODULE__{} = canvas, x, y, text, fg, bg) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(canvas, fn {char, i}, acc ->
      set_cell(acc, x + i, y, char, fg, bg)
    end)
  end

  @doc "Fill a rectangle with the given character and colors."
  @spec fill_rect(t(), integer(), integer(), non_neg_integer(), non_neg_integer(), String.t(), Color.t(), Color.t()) ::
          t()
  def fill_rect(%__MODULE__{} = canvas, _x, _y, w, _h, _char, _fg, _bg) when w <= 0, do: canvas
  def fill_rect(%__MODULE__{} = canvas, _x, _y, _w, h, _char, _fg, _bg) when h <= 0, do: canvas

  def fill_rect(%__MODULE__{} = canvas, x, y, w, h, char, fg, bg) do
    Enum.reduce(0..(h - 1)//1, canvas, fn dy, acc ->
      Enum.reduce(0..(w - 1)//1, acc, fn dx, acc2 ->
        set_cell(acc2, x + dx, y + dy, char, fg, bg)
      end)
    end)
  end

  @doc "Clear all cells, resetting to an empty canvas."
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = canvas) do
    %{canvas | cells: %{}}
  end
end
