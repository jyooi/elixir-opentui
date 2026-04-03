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
  @spec grapheme_count(t() | String.t()) :: non_neg_integer()
  def grapheme_count(%__MODULE__{} = buf) do
    buf |> to_plain() |> String.length()
  end

  def grapheme_count(text) when is_binary(text), do: String.length(text)

  @doc "Get display width accounting for wide characters (CJK, emoji)."
  @spec display_width(t() | String.t()) :: non_neg_integer()
  def display_width(%__MODULE__{} = buf) do
    buf
    |> graphemes()
    |> Enum.reduce(0, fn grapheme, acc -> acc + char_width(grapheme) end)
  end

  def display_width(text) when is_binary(text) do
    text
    |> String.graphemes()
    |> Enum.reduce(0, fn grapheme, acc -> acc + char_width(grapheme) end)
  end

  @doc "Take the leading text that fits within the given display columns."
  @spec take_columns(String.t(), integer()) :: String.t()
  def take_columns(_text, max_columns) when max_columns <= 0, do: ""

  def take_columns(text, max_columns) when is_binary(text) do
    text
    |> String.graphemes()
    |> Enum.reduce_while({[], 0}, fn grapheme, {acc, width} ->
      grapheme_width = char_width(grapheme)

      if width + grapheme_width <= max_columns do
        {:cont, {[grapheme | acc], width + grapheme_width}}
      else
        {:halt, {acc, width}}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  @doc "Slice a string by display columns, replacing partially clipped graphemes with spaces."
  @spec slice_columns(String.t(), integer(), integer()) :: String.t()
  def slice_columns(_text, _start_column, width) when width <= 0, do: ""

  def slice_columns(text, start_column, width) when start_column <= 0 do
    do_slice_columns(text, 0, width)
  end

  def slice_columns(text, start_column, width) when is_binary(text) do
    do_slice_columns(text, start_column, width)
  end

  @doc "Pad a string on the right to the requested display width."
  @spec pad_trailing_columns(String.t(), non_neg_integer(), String.t()) :: String.t()
  def pad_trailing_columns(text, total_columns, pad_char \\ " ") when is_binary(text) do
    pad_columns(text, total_columns, pad_char, :trailing)
  end

  @doc "Pad a string on the left to the requested display width."
  @spec pad_leading_columns(String.t(), non_neg_integer(), String.t()) :: String.t()
  def pad_leading_columns(text, total_columns, pad_char \\ " ") when is_binary(text) do
    pad_columns(text, total_columns, pad_char, :leading)
  end

  @doc "Return the grapheme whose cell range covers the given display column."
  @spec grapheme_at_column(String.t(), integer()) :: String.t() | nil
  def grapheme_at_column(_text, column) when column < 0, do: nil

  def grapheme_at_column(text, column) when is_binary(text) do
    text
    |> String.graphemes()
    |> Enum.reduce_while(0, fn grapheme, current_column ->
      next_column = current_column + char_width(grapheme)

      cond do
        column < next_column -> {:halt, grapheme}
        true -> {:cont, next_column}
      end
    end)
    |> case do
      result when is_binary(result) -> result
      _ -> nil
    end
  end

  @doc "Get the display column corresponding to a grapheme index."
  @spec grapheme_index_to_column(String.t(), integer()) :: non_neg_integer()
  def grapheme_index_to_column(_text, index) when index <= 0, do: 0

  def grapheme_index_to_column(text, index) when is_binary(text) do
    text
    |> String.slice(0, index)
    |> display_width()
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
  Wide chars (CJK, some emoji) take 2 columns; combining marks take 0.
  """
  @spec char_width(String.t()) :: 0 | 1 | 2
  def char_width(grapheme) do
    codepoints = String.to_charlist(grapheme)

    if length(codepoints) > 1 and emoji_presentation?(codepoints) do
      2
    else
      do_char_width(codepoints)
    end
  end

  defp do_char_width(codepoints) do
    case codepoints do
      [cp] when cp in 0x0300..0x036F ->
        0

      [cp] when cp in 0x1AB0..0x1AFF ->
        0

      [cp] when cp in 0x1DC0..0x1DFF ->
        0

      [cp] when cp in 0x20D0..0x20FF ->
        0

      [cp] when cp in 0x200B..0x200D ->
        0

      [cp] when cp in 0xFE00..0xFE0F ->
        0

      [cp] when cp in 0xFE20..0xFE2F ->
        0

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
        grapheme_width_fallback(codepoints)
    end
  end

  defp grapheme_width_fallback(codepoints) do
    cond do
      codepoints == [] -> 0
      emoji_presentation?(codepoints) -> 2
      true -> 1
    end
  end

  defp emoji_presentation?(codepoints) do
    Enum.any?(codepoints, &(&1 == 0xFE0F)) or
      regional_indicator_pair?(codepoints) or
      Enum.any?(codepoints, &emoji_base_codepoint?/1)
  end

  defp regional_indicator_pair?(codepoints) do
    Enum.count(codepoints, &(&1 in 0x1F1E6..0x1F1FF)) >= 2
  end

  defp emoji_base_codepoint?(cp) do
    cp in 0x231A..0x231B or
      cp in 0x23E9..0x23EC or
      cp in 0x23F0..0x23F0 or
      cp in 0x23F3..0x23F3 or
      cp in 0x25FD..0x25FE or
      cp in 0x2614..0x2615 or
      cp in 0x2648..0x2653 or
      cp in 0x267F..0x267F or
      cp in 0x2693..0x2693 or
      cp in 0x26A1..0x26A1 or
      cp in 0x26AA..0x26AB or
      cp in 0x26BD..0x26BE or
      cp in 0x26C4..0x26C5 or
      cp in 0x26CE..0x26CE or
      cp in 0x26D4..0x26D4 or
      cp in 0x26EA..0x26EA or
      cp in 0x26F2..0x26F5 or
      cp in 0x26FA..0x26FA or
      cp in 0x2705..0x2705 or
      cp in 0x2708..0x270D or
      cp in 0x2728..0x2728 or
      cp in 0x274C..0x274C or
      cp in 0x274E..0x274E or
      cp in 0x2753..0x2755 or
      cp in 0x2757..0x2757 or
      cp in 0x2795..0x2797 or
      cp in 0x27B0..0x27B0 or
      cp in 0x27BF..0x27BF or
      cp in 0x2B1B..0x2B1C or
      cp in 0x2B50..0x2B50 or
      cp in 0x2B55..0x2B55 or
      cp in 0x1F000..0x1FAFF
  end

  defp do_slice_columns(text, start_column, width) do
    end_column = start_column + width

    text
    |> String.graphemes()
    |> Enum.reduce_while({[], 0}, fn grapheme, {acc, current_column} ->
      grapheme_width = char_width(grapheme)
      next_column = current_column + grapheme_width
      overlap = min(next_column, end_column) - max(current_column, start_column)

      cond do
        next_column <= start_column ->
          {:cont, {acc, next_column}}

        current_column >= end_column ->
          {:halt, {acc, current_column}}

        overlap <= 0 ->
          {:cont, {acc, next_column}}

        current_column >= start_column and next_column <= end_column ->
          {:cont, {[grapheme | acc], next_column}}

        true ->
          {:cont, {[String.duplicate(" ", overlap) | acc], next_column}}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp pad_columns(_text, total_columns, pad_char, direction) when total_columns <= 0 do
    _ = direction
    _ = pad_char
    ""
  end

  defp pad_columns(text, total_columns, pad_char, direction) do
    current_width = display_width(text)
    pad_width = max(1, char_width(pad_char))
    missing = max(0, total_columns - current_width)
    pad_count = div(missing + pad_width - 1, pad_width)
    padding = String.duplicate(pad_char, pad_count)
    padding = take_columns(padding, missing)

    case direction do
      :leading -> padding <> text
      :trailing -> text <> padding
    end
  end
end
