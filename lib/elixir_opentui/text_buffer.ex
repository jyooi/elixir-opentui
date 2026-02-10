defmodule ElixirOpentui.TextBuffer do
  @moduledoc """
  Styled text buffer — stores text with per-character or per-span styling.

  Maps to ElixirOpentui's TextBuffer: handles Unicode grapheme clusters,
  styled spans, and plain text extraction.
  """

  alias ElixirOpentui.Color

  @type span :: %{
          text: String.t(),
          fg: Color.t() | nil,
          bg: Color.t() | nil,
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          strikethrough: boolean(),
          dim: boolean(),
          inverse: boolean()
        }

  @type t :: %__MODULE__{
          spans: [span()],
          cache_plain: String.t() | nil,
          cache_graphemes: [String.t()] | nil
        }

  defstruct spans: [], cache_plain: nil, cache_graphemes: nil

  @default_span_style %{
    fg: nil,
    bg: nil,
    bold: false,
    italic: false,
    underline: false,
    strikethrough: false,
    dim: false,
    inverse: false
  }

  @doc "Create an empty TextBuffer."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Create a TextBuffer from plain text."
  @spec from_text(String.t()) :: t()
  def from_text(text) when is_binary(text) do
    %__MODULE__{spans: [Map.put(@default_span_style, :text, text)]}
  end

  @doc "Create a TextBuffer from styled spans."
  @spec from_spans([{String.t(), keyword()}]) :: t()
  def from_spans(spans) when is_list(spans) do
    styled =
      Enum.map(spans, fn
        {text, style} when is_binary(text) ->
          @default_span_style
          |> Map.put(:text, text)
          |> Map.merge(Map.new(style))

        text when is_binary(text) ->
          Map.put(@default_span_style, :text, text)
      end)

    %__MODULE__{spans: styled}
  end

  @doc "Create a TextBuffer from a single styled text string."
  @spec styled(String.t(), keyword()) :: t()
  def styled(text, style \\ []) when is_binary(text) do
    span =
      @default_span_style
      |> Map.put(:text, text)
      |> Map.merge(Map.new(style))

    %__MODULE__{spans: [span]}
  end

  @doc "Concatenate a list of TextBuffers into one."
  @spec concat([t()]) :: t()
  def concat(buffers) when is_list(buffers) do
    spans = Enum.flat_map(buffers, fn %__MODULE__{spans: s} -> s end)
    %__MODULE__{spans: spans}
  end

  @doc "Get the plain text content (all spans concatenated)."
  @spec to_plain(t()) :: String.t()
  def to_plain(%__MODULE__{cache_plain: cached}) when is_binary(cached), do: cached

  def to_plain(%__MODULE__{spans: spans} = buf) do
    plain = spans |> Enum.map(& &1.text) |> IO.iodata_to_binary()
    # Cache for repeated access
    put_in(buf.cache_plain, plain)
    plain
  end

  @doc "Get grapheme clusters list."
  @spec graphemes(t()) :: [String.t()]
  def graphemes(%__MODULE__{cache_graphemes: cached}) when is_list(cached), do: cached

  def graphemes(%__MODULE__{} = buf) do
    buf |> to_plain() |> String.graphemes()
  end

  @doc "Get grapheme count (visual character count)."
  @spec grapheme_count(t()) :: non_neg_integer()
  def grapheme_count(%__MODULE__{} = buf) do
    buf |> to_plain() |> String.length()
  end

  @doc "Get display width accounting for wide characters (CJK, emoji)."
  @spec display_width(t()) :: non_neg_integer()
  def display_width(%__MODULE__{} = buf) do
    buf
    |> graphemes()
    |> Enum.reduce(0, fn grapheme, acc -> acc + char_width(grapheme) end)
  end

  @doc "Get the style at a given grapheme index."
  @spec style_at(t(), non_neg_integer()) :: span() | nil
  def style_at(%__MODULE__{spans: spans}, index) do
    find_span_at(spans, index, 0)
  end

  defp find_span_at([], _index, _offset), do: nil

  defp find_span_at([span | rest], index, offset) do
    len = String.length(span.text)

    if index < offset + len do
      Map.delete(span, :text)
    else
      find_span_at(rest, index, offset + len)
    end
  end

  @doc "Append text to the buffer."
  @spec append(t(), String.t(), keyword()) :: t()
  def append(%__MODULE__{spans: spans}, text, style \\ []) do
    new_span =
      @default_span_style
      |> Map.put(:text, text)
      |> Map.merge(Map.new(style))

    %__MODULE__{spans: spans ++ [new_span]}
  end

  @doc "Slice the buffer to a grapheme range."
  @spec slice(t(), non_neg_integer(), non_neg_integer()) :: t()
  def slice(%__MODULE__{} = buf, start, length) do
    plain = to_plain(buf)
    sliced = String.slice(plain, start, length)
    # Simplified: loses per-span styling on slice, applies first matching style
    from_text(sliced)
  end

  @doc """
  Calculate the display width of a single grapheme.
  Wide chars (CJK, some emoji) take 2 columns; others take 1.
  """
  @spec char_width(String.t()) :: 1 | 2
  def char_width(grapheme) do
    case String.to_charlist(grapheme) do
      [cp | _] when cp >= 0x1100 ->
        cond do
          # CJK ranges
          cp in 0x1100..0x115F -> 2
          cp in 0x2E80..0x303E -> 2
          cp in 0x3041..0x33BF -> 2
          cp in 0x3400..0x4DBF -> 2
          cp in 0x4E00..0x9FFF -> 2
          cp in 0xA000..0xA4CF -> 2
          cp in 0xAC00..0xD7AF -> 2
          cp in 0xF900..0xFAFF -> 2
          cp in 0xFE30..0xFE6F -> 2
          cp in 0xFF01..0xFF60 -> 2
          cp in 0xFFE0..0xFFE6 -> 2
          cp >= 0x1F000 -> 2
          true -> 1
        end

      _ ->
        1
    end
  end
end
