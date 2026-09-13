defmodule ElixirOpentui.ASCIIFont do
  @moduledoc """
  Renders text using large ASCII art fonts.

  Supports multiple font styles with 1 or 2 color channels.
  Font data is sourced from the MIT-licensed cfonts project.
  """

  @type font_name :: :tiny | :block

  @font_modules %{
    tiny: ElixirOpentui.ASCIIFont.Tiny,
    block: ElixirOpentui.ASCIIFont.Block
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
    [first_row | _] = lines = render_to_lines(text, font)
    {String.length(first_row), length(lines)}
  end

  @doc """
  Render text to plain lines (color tags stripped).

  Returns a list of strings, one per font line.
  """
  @spec render_to_lines(String.t(), font_name()) :: [String.t()]
  def render_to_lines(text, font) do
    {data, rows} = glyph_rows(text, font, &strip_color_tags/1)
    letterspace_str = String.duplicate(" ", data.letterspace_size)
    Enum.map(rows, &Enum.join(&1, letterspace_str))
  end

  @doc """
  Render text to color-segmented rows.

  Returns a list of rows, where each row is a list of `{text, color_index}` segments.
  Color index 0 = primary color, 1 = secondary color.
  """
  @spec render_to_segments(String.t(), font_name()) :: [[{String.t(), non_neg_integer()}]]
  def render_to_segments(text, font) do
    {data, rows} = glyph_rows(text, font, &parse_color_tags/1)
    letterspace_str = String.duplicate(" ", data.letterspace_size)

    Enum.map(rows, fn row ->
      row
      |> Enum.with_index()
      |> Enum.flat_map(fn {segments, idx} ->
        if idx > 0 and letterspace_str != "" do
          [{letterspace_str, 0} | segments]
        else
          segments
        end
      end)
    end)
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
      [_full, "", "", plain_text] -> {plain_text, 0}
      [_full, color_num, text] -> {text, max(0, String.to_integer(color_num) - 1)}
    end)
    |> Enum.reject(fn {text, _} -> text == "" end)
  end

  def parse_color_tags(_), do: []

  # --- Private helpers ---

  # Apply `fun` to every glyph row of `text`, one list per font line.
  defp glyph_rows(text, font, fun) do
    data = font_data(font)
    chars = text |> String.upcase() |> String.graphemes()

    rows =
      Enum.map(0..(data.lines - 1)//1, fn row ->
        Enum.map(chars, fn char -> fun.(glyph_row(Map.get(data.chars, char), data, row)) end)
      end)

    {data, rows}
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
end
