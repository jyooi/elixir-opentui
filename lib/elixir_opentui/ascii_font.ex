defmodule ElixirOpentui.ASCIIFont do
  @moduledoc """
  Renders text using large ASCII art fonts.

  Supports multiple font styles with 1 or 2 color channels.
  Font data is sourced from the MIT-licensed cfonts project.
  """

  @type font_name :: :tiny | :block | :pixel

  @font_modules %{
    tiny: ElixirOpentui.ASCIIFont.Tiny,
    block: ElixirOpentui.ASCIIFont.Block,
    pixel: ElixirOpentui.ASCIIFont.Pixel
  }

  @doc "Get the font data map for a given font name."
  @spec font_data(font_name()) :: map()
  def font_data(font) do
    case Map.get(@font_modules, font) do
      nil -> raise ArgumentError, "unknown font: #{inspect(font)}"
      mod -> mod.font_data()
    end
  end

  @doc "Get the height (number of lines) for a font."
  @spec font_height(font_name()) :: non_neg_integer()
  def font_height(font) do
    font_data(font).lines
  end

  @doc """
  Compute the rendered dimensions of text in a given font.

  Returns `{width, height}` where width is the sum of first-row
  grapheme widths plus letterspace gaps between characters.
  """
  @spec dimensions(String.t(), font_name()) :: {non_neg_integer(), non_neg_integer()}
  def dimensions(text, font) do
    data = font_data(font)
    height = data.lines

    if text == "" do
      {0, height}
    else
      chars = text |> String.upcase() |> String.graphemes()
      letterspace = data.letterspace_size

      width =
        chars
        |> Enum.with_index()
        |> Enum.reduce(0, fn {char, idx}, acc ->
          glyph = Map.get(data.chars, char)
          char_width = glyph_width(glyph, data)
          gap = if idx > 0, do: letterspace, else: 0
          acc + char_width + gap
        end)

      {width, height}
    end
  end

  @doc """
  Render text to plain lines (color tags stripped).

  Returns a list of strings, one per font line.
  """
  @spec render_to_lines(String.t(), font_name()) :: [String.t()]
  def render_to_lines(text, font) do
    data = font_data(font)

    if text == "" do
      List.duplicate("", data.lines)
    else
      chars = text |> String.upcase() |> String.graphemes()
      letterspace_str = String.duplicate(" ", data.letterspace_size)

      Enum.map(0..(data.lines - 1)//1, fn row ->
        chars
        |> Enum.with_index()
        |> Enum.map(fn {char, _idx} ->
          glyph = Map.get(data.chars, char)
          row_data = glyph_row(glyph, data, row)
          strip_color_tags(row_data)
        end)
        |> Enum.join(letterspace_str)
      end)
    end
  end

  @doc """
  Render text to color-segmented rows.

  Returns a list of rows, where each row is a list of `{text, color_index}` segments.
  Color index 0 = primary color, 1 = secondary color.
  """
  @spec render_to_segments(String.t(), font_name()) :: [[{String.t(), non_neg_integer()}]]
  def render_to_segments(text, font) do
    data = font_data(font)

    if text == "" do
      List.duplicate([], data.lines)
    else
      chars = text |> String.upcase() |> String.graphemes()
      letterspace_str = String.duplicate(" ", data.letterspace_size)

      Enum.map(0..(data.lines - 1)//1, fn row ->
        chars
        |> Enum.with_index()
        |> Enum.flat_map(fn {char, idx} ->
          glyph = Map.get(data.chars, char)
          row_data = glyph_row(glyph, data, row)
          segments = parse_color_tags(row_data)

          if idx > 0 and letterspace_str != "" do
            [{letterspace_str, 0} | segments]
          else
            segments
          end
        end)
      end)
    end
  end

  @doc """
  Parse color tags from a font glyph row string.

  `"<c1>██</c1><c2>╗</c2>"` → `[{"██", 0}, {"╗", 1}]`

  Untagged text gets color_index 0.
  """
  @spec parse_color_tags(String.t()) :: [{String.t(), non_neg_integer()}]
  def parse_color_tags(str) when is_binary(str) do
    # Match <cN>...</cN> tags or plain text between them
    ~r/<c(\d+)>(.*?)<\/c\d+>|([^<]+)/
    |> Regex.scan(str)
    |> Enum.map(fn
      [_full, color_num, text, ""] ->
        idx = max(0, String.to_integer(color_num) - 1)
        {text, idx}

      [_full, "", "", plain_text] ->
        {plain_text, 0}

      [_full, color_num, text] ->
        idx = max(0, String.to_integer(color_num) - 1)
        {text, idx}

      [plain_text] ->
        {plain_text, 0}
    end)
    |> Enum.reject(fn {text, _} -> text == "" end)
  end

  def parse_color_tags(_), do: []

  # --- Private helpers ---

  defp glyph_width(nil, data) do
    # Unknown char: use space width
    case Map.get(data.chars, " ") do
      nil -> 1
      space_glyph -> first_row_width(space_glyph, data)
    end
  end

  defp glyph_width(glyph, data) do
    first_row_width(glyph, data)
  end

  defp first_row_width(glyph, data) do
    row_str = List.first(glyph) || ""

    if data.colors > 1 do
      strip_color_tags(row_str) |> grapheme_length()
    else
      grapheme_length(row_str)
    end
  end

  defp glyph_row(nil, data, row) do
    # Unknown char fallback: space
    case Map.get(data.chars, " ") do
      nil -> " "
      space_glyph -> Enum.at(space_glyph, row, " ")
    end
  end

  defp glyph_row(glyph, _data, row) do
    Enum.at(glyph, row, "")
  end

  defp strip_color_tags(str) do
    str
    |> String.replace(~r/<c\d+>/, "")
    |> String.replace(~r/<\/c\d+>/, "")
  end

  defp grapheme_length(str) do
    String.graphemes(str) |> length()
  end
end
