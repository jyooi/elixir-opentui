defmodule ElixirOpentui.TextBufferTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.TextBuffer
  alias ElixirOpentui.Color

  describe "display_width/1" do
    test "ASCII text width equals length" do
      assert TextBuffer.display_width("Hello") == 5
    end

    test "CJK characters are double-width" do
      assert TextBuffer.display_width("世界") == 4
    end

    test "mixed ASCII and CJK" do
      assert TextBuffer.display_width("Hi世界") == 6
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
end
