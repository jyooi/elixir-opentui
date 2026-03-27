defmodule ElixirOpentui.TextBufferTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.TextBuffer
  alias ElixirOpentui.Color

  describe "new/0 and from_text/1" do
    test "empty buffer" do
      buf = TextBuffer.new()
      assert TextBuffer.to_plain(buf) == ""
      assert TextBuffer.grapheme_count(buf) == 0
    end

    test "from plain text" do
      buf = TextBuffer.from_text("Hello World")
      assert TextBuffer.to_plain(buf) == "Hello World"
      assert TextBuffer.grapheme_count(buf) == 11
    end

    test "from text with Unicode" do
      buf = TextBuffer.from_text("Hello 世界")
      assert TextBuffer.to_plain(buf) == "Hello 世界"
      assert TextBuffer.grapheme_count(buf) == 8
    end

    test "emoji graphemes" do
      buf = TextBuffer.from_text("Hi 👋🏽")
      plain = TextBuffer.to_plain(buf)
      assert String.contains?(plain, "Hi")
    end
  end

  describe "from_spans/1" do
    test "multiple styled spans" do
      buf =
        TextBuffer.from_spans([
          {"Hello ", fg: Color.red()},
          {"World", fg: Color.blue(), bold: true}
        ])

      assert TextBuffer.to_plain(buf) == "Hello World"
      assert TextBuffer.grapheme_count(buf) == 11
    end

    test "plain strings in span list" do
      buf = TextBuffer.from_spans(["Hello ", "World"])
      assert TextBuffer.to_plain(buf) == "Hello World"
    end
  end

  describe "display_width/1" do
    test "ASCII text width equals length" do
      buf = TextBuffer.from_text("Hello")
      assert TextBuffer.display_width(buf) == 5
    end

    test "CJK characters are double-width" do
      buf = TextBuffer.from_text("世界")
      assert TextBuffer.display_width(buf) == 4
    end

    test "mixed ASCII and CJK" do
      buf = TextBuffer.from_text("Hi世界")
      assert TextBuffer.display_width(buf) == 6
    end

    test "combining marks do not add display width" do
      assert TextBuffer.display_width("e\u0301") == 1
      assert TextBuffer.display_width("\u0301") == 0
    end

    test "multi-codepoint emoji keeps emoji width" do
      assert TextBuffer.display_width("👋🏽") == 2
    end

    test "emoji variation selector sequences use wide display width" do
      assert TextBuffer.display_width("✈️") == 2
      assert TextBuffer.display_width("☑️") == 2
    end
  end

  describe "column helpers" do
    test "slice_columns clips by display columns" do
      assert TextBuffer.slice_columns("A界B", 0, 2) == "A "
      assert TextBuffer.slice_columns("A界B", 1, 3) == "界B"
      assert TextBuffer.slice_columns("A界B", 2, 2) == " B"
    end

    test "pad column helpers use display width" do
      assert TextBuffer.pad_trailing_columns("界", 4) == "界  "
      assert TextBuffer.pad_leading_columns("界", 4) == "  界"
    end

    test "grapheme_index_to_column maps grapheme positions to display columns" do
      assert TextBuffer.grapheme_index_to_column("A界B", 0) == 0
      assert TextBuffer.grapheme_index_to_column("A界B", 1) == 1
      assert TextBuffer.grapheme_index_to_column("A界B", 2) == 3
      assert TextBuffer.grapheme_index_to_column("A界B", 3) == 4
    end
  end

  describe "style_at/2" do
    test "returns style at grapheme index" do
      buf =
        TextBuffer.from_spans([
          {"Hello", fg: Color.red()},
          {"World", fg: Color.blue()}
        ])

      style0 = TextBuffer.style_at(buf, 0)
      assert style0.fg == Color.red()

      style5 = TextBuffer.style_at(buf, 5)
      assert style5.fg == Color.blue()
    end

    test "returns nil for out of bounds" do
      buf = TextBuffer.from_text("Hi")
      assert TextBuffer.style_at(buf, 10) == nil
    end
  end

  describe "append/3" do
    test "appends text with style" do
      buf = TextBuffer.from_text("Hello")
      buf = TextBuffer.append(buf, " World", fg: Color.green())
      assert TextBuffer.to_plain(buf) == "Hello World"
    end
  end

  describe "dim and inverse span support" do
    test "TextBuffer span supports dim" do
      buf = TextBuffer.from_spans([{"dimmed", dim: true}])
      style = TextBuffer.style_at(buf, 0)
      assert style.dim == true
      assert style.inverse == false
    end

    test "TextBuffer span supports inverse" do
      buf = TextBuffer.from_spans([{"inverted", inverse: true}])
      style = TextBuffer.style_at(buf, 0)
      assert style.inverse == true
      assert style.dim == false
    end
  end

  describe "styled/2" do
    test "creates span with all attributes" do
      buf = TextBuffer.styled("hello", bold: true, fg: {255, 0, 0, 255}, dim: true, inverse: true)
      assert TextBuffer.to_plain(buf) == "hello"
      style = TextBuffer.style_at(buf, 0)
      assert style.bold == true
      assert style.dim == true
      assert style.inverse == true
      assert style.fg == {255, 0, 0, 255}
    end
  end

  describe "concat/1" do
    test "merges multiple TextBuffers" do
      a = TextBuffer.from_text("Hello ")
      b = TextBuffer.styled("World", bold: true)
      combined = TextBuffer.concat([a, b])
      assert TextBuffer.to_plain(combined) == "Hello World"
      assert TextBuffer.grapheme_count(combined) == 11
    end
  end

  describe "graphemes/1" do
    test "returns grapheme cluster list" do
      buf = TextBuffer.from_text("ABC")
      assert TextBuffer.graphemes(buf) == ["A", "B", "C"]
    end
  end
end
