defmodule ElixirOpentui.ASCIIFontTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.ASCIIFont

  # --- Color tag parsing ---

  describe "parse_color_tags/1" do
    test "parses two-color tagged string" do
      result = ASCIIFont.parse_color_tags("<c1>██</c1><c2>╗</c2>")
      assert result == [{"██", 0}, {"╗", 1}]
    end

    test "plain text (no tags) returns entire string at color_index 0" do
      result = ASCIIFont.parse_color_tags("Hello")
      assert result == [{"Hello", 0}]
    end

    test "mixed tagged and untagged" do
      result = ASCIIFont.parse_color_tags(" <c1>██</c1> ")
      assert result == [{" ", 0}, {"██", 0}, {" ", 0}]
    end

    test "empty string returns empty list" do
      assert ASCIIFont.parse_color_tags("") == []
    end

    test "adjacent tags with no gap" do
      result = ASCIIFont.parse_color_tags("<c1>AB</c1><c2>CD</c2>")
      assert result == [{"AB", 0}, {"CD", 1}]
    end

    test "multiple segments same color" do
      result = ASCIIFont.parse_color_tags("<c1>A</c1> <c1>B</c1>")
      assert result == [{"A", 0}, {" ", 0}, {"B", 0}]
    end

    test "whitespace inside tags preserved" do
      result = ASCIIFont.parse_color_tags("<c1>  </c1>")
      assert result == [{"  ", 0}]
    end

    test "nil input returns empty list" do
      assert ASCIIFont.parse_color_tags(nil) == []
    end
  end

  # --- dimensions ---

  describe "dimensions/2" do
    test "single char tiny" do
      {w, h} = ASCIIFont.dimensions("A", :tiny)
      # Tiny A is "▄▀█" = 3 graphemes wide, 2 lines tall
      assert w == 3
      assert h == 2
    end

    test "two chars tiny with letterspace" do
      {w, h} = ASCIIFont.dimensions("AB", :tiny)
      # A=3, letterspace=1, B=3 → 7
      assert w == 7
      assert h == 2
    end

    test "empty text returns zero width, font height" do
      {w, h} = ASCIIFont.dimensions("", :tiny)
      assert w == 0
      assert h == 2
    end

    test "single char block font" do
      {w, h} = ASCIIFont.dimensions("A", :block)
      # Block A first row: " █████╗ " = 9 visible graphemes
      assert h == 6
      assert w > 0
    end

    test "multi-char block font" do
      {w, h} = ASCIIFont.dimensions("HI", :block)
      assert h == 6
      assert w > 0
    end

    test "unknown char falls back to space width" do
      {w1, _} = ASCIIFont.dimensions("~", :tiny)
      {w2, _} = ASCIIFont.dimensions(" ", :tiny)
      assert w1 == w2
    end

    test "lowercase input same as uppercase" do
      assert ASCIIFont.dimensions("hello", :tiny) == ASCIIFont.dimensions("HELLO", :tiny)
    end

    test "longer text accumulates widths" do
      {w, _} = ASCIIFont.dimensions("HELLO", :tiny)
      # H=3, E=3, L=3, L=3, O=3 + 4*letterspace(1) = 19
      assert w == 19
    end
  end

  # --- render_to_segments ---

  describe "render_to_segments/2" do
    test "single char returns correct number of rows" do
      rows = ASCIIFont.render_to_segments("A", :tiny)
      assert length(rows) == 2
    end

    test "tiny font: all segments have color_index 0" do
      rows = ASCIIFont.render_to_segments("A", :tiny)

      for row <- rows do
        for {_text, idx} <- row do
          assert idx == 0
        end
      end
    end

    test "block font: segments have both color indices" do
      rows = ASCIIFont.render_to_segments("A", :block)
      assert length(rows) == 6

      all_indices =
        rows |> Enum.flat_map(fn row -> Enum.map(row, &elem(&1, 1)) end) |> Enum.uniq()

      assert 0 in all_indices
      assert 1 in all_indices
    end

    test "characters uppercased" do
      lower = ASCIIFont.render_to_segments("a", :tiny)
      upper = ASCIIFont.render_to_segments("A", :tiny)
      assert lower == upper
    end

    test "unknown char renders as space-width" do
      rows = ASCIIFont.render_to_segments("~", :tiny)
      assert length(rows) == 2
    end

    test "empty text returns list of empty rows at font height" do
      rows = ASCIIFont.render_to_segments("", :tiny)
      assert length(rows) == 2
      for row <- rows, do: assert(row == [])
    end

    test "multi-char includes letterspace" do
      rows = ASCIIFont.render_to_segments("AB", :tiny)
      assert length(rows) == 2

      # Each row should have segments for A + letterspace + B
      for row <- rows do
        text = row |> Enum.map(&elem(&1, 0)) |> Enum.join()
        assert String.length(text) > 0
      end
    end

    test "block font multi-char" do
      rows = ASCIIFont.render_to_segments("HI", :block)
      assert length(rows) == 6
    end
  end

  # --- render_to_lines ---

  describe "render_to_lines/2" do
    test "tiny A renders correctly" do
      lines = ASCIIFont.render_to_lines("A", :tiny)
      assert lines == ["▄▀█", "█▀█"]
    end

    test "multi-char correctly spaced" do
      lines = ASCIIFont.render_to_lines("AB", :tiny)
      assert length(lines) == 2
      # A row0="▄▀█" + " " + B row0="█▄▄" → "▄▀█ █▄▄"
      assert Enum.at(lines, 0) == "▄▀█ █▄▄"
    end

    test "empty text returns empty rows at font height" do
      lines = ASCIIFont.render_to_lines("", :tiny)
      assert length(lines) == 2
      for line <- lines, do: assert(line == "")
    end

    test "block font strips color tags" do
      lines = ASCIIFont.render_to_lines("I", :block)
      assert length(lines) == 6
      # No <c1>/<c2> tags should remain
      for line <- lines do
        refute String.contains?(line, "<c1>")
        refute String.contains?(line, "<c2>")
      end
    end

    test "block font I renders expected shape" do
      lines = ASCIIFont.render_to_lines("I", :block)
      # Block I: "██╗", "██║", "██║", "██║", "██║", "╚═╝"
      assert Enum.at(lines, 0) == "██╗"
      assert Enum.at(lines, 5) == "╚═╝"
    end
  end

  # --- font_height ---

  describe "font_height/1" do
    test "tiny is 2" do
      assert ASCIIFont.font_height(:tiny) == 2
    end

    test "block is 6" do
      assert ASCIIFont.font_height(:block) == 6
    end
  end

  # --- Per-font glyph spot checks ---

  describe "glyph verification" do
    test "tiny O glyph" do
      lines = ASCIIFont.render_to_lines("O", :tiny)
      assert lines == ["█▀█", "█▄█"]
    end

    test "block E first row" do
      lines = ASCIIFont.render_to_lines("E", :block)
      assert Enum.at(lines, 0) == "███████╗"
    end

    test "tiny space is single space per line" do
      lines = ASCIIFont.render_to_lines(" ", :tiny)
      assert lines == [" ", " "]
    end
  end
end
