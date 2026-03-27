defmodule ElixirOpentui.Widgets.DiffTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.Diff

  defp key(k, opts \\ []) do
    %{
      type: :key,
      key: k,
      ctrl: Keyword.get(opts, :ctrl, false),
      alt: Keyword.get(opts, :alt, false),
      shift: Keyword.get(opts, :shift, false),
      meta: false
    }
  end

  @sample_diff "--- a/file.txt\n+++ b/file.txt\n@@ -1,4 +1,4 @@\n line 1\n-line 2\n+line 2 modified\n line 3\n line 4\n"

  @multi_hunk_diff "--- a/file.txt\n+++ b/file.txt\n@@ -1,3 +1,3 @@\n line 1\n-old line 2\n+new line 2\n line 3\n@@ -10,3 +10,4 @@\n line 10\n-old line 11\n+new line 11a\n+new line 11b\n line 12\n"

  describe "init/1" do
    test "initializes with diff and defaults" do
      state = Diff.init(%{diff: @sample_diff, id: :diff})
      assert state.diff == @sample_diff
      assert state.view == :unified
      assert state.show_line_numbers == true
      assert state.scroll_offset == 0
    end

    test "initializes with split view" do
      state = Diff.init(%{diff: @sample_diff, view: :split, id: :diff})
      assert state.view == :split
    end

    test "initializes empty" do
      state = Diff.init(%{id: :diff})
      assert state.diff == ""
      assert state.parsed == []
    end
  end

  describe "parse_diff/1" do
    test "parses empty diff" do
      assert Diff.parse_diff("") == []
    end

    test "parses single hunk" do
      hunks = Diff.parse_diff(@sample_diff)
      assert length(hunks) == 1

      [hunk] = hunks
      assert hunk.old_start == 1
      assert hunk.new_start == 1
      assert length(hunk.lines) == 5
    end

    test "parses line types correctly" do
      [hunk] = Diff.parse_diff(@sample_diff)

      types = Enum.map(hunk.lines, & &1.type)
      assert types == [:context, :remove, :add, :context, :context]
    end

    test "strips leading +/- from content" do
      [hunk] = Diff.parse_diff(@sample_diff)

      contents = Enum.map(hunk.lines, & &1.content)
      assert "line 2" in contents
      assert "line 2 modified" in contents
      # Should not contain raw "+line 2 modified"
      refute "+line 2 modified" in contents
    end

    test "tracks line numbers for old and new" do
      [hunk] = Diff.parse_diff(@sample_diff)
      lines = hunk.lines

      # context: old=1, new=1
      assert Enum.at(lines, 0).old_line == 1
      assert Enum.at(lines, 0).new_line == 1

      # remove: old=2, new=nil
      assert Enum.at(lines, 1).old_line == 2
      assert Enum.at(lines, 1).new_line == nil

      # add: old=nil, new=2
      assert Enum.at(lines, 2).old_line == nil
      assert Enum.at(lines, 2).new_line == 2

      # context: old=3, new=3
      assert Enum.at(lines, 3).old_line == 3
      assert Enum.at(lines, 3).new_line == 3
    end

    test "parses multiple hunks" do
      hunks = Diff.parse_diff(@multi_hunk_diff)
      assert length(hunks) == 2

      [hunk1, hunk2] = hunks
      assert hunk1.old_start == 1
      assert hunk2.old_start == 10
    end

    test "handles hunk with more adds than removes" do
      hunks = Diff.parse_diff(@multi_hunk_diff)
      [_, hunk2] = hunks

      add_count = Enum.count(hunk2.lines, &(&1.type == :add))
      remove_count = Enum.count(hunk2.lines, &(&1.type == :remove))
      assert add_count == 2
      assert remove_count == 1
    end
  end

  describe "unified view" do
    test "builds unified lines from parsed diff" do
      state = Diff.init(%{diff: @sample_diff, id: :diff})
      tree = Diff.render(state)
      lines = tree.attrs.lines

      assert length(lines) > 0
      types = Enum.map(lines, & &1.type)
      assert :context in types
      assert :add in types
      assert :remove in types
    end
  end

  describe "split view" do
    test "builds split lines from parsed diff" do
      state = Diff.init(%{diff: @sample_diff, view: :split, id: :diff})
      tree = Diff.render(state)
      lines = tree.attrs.lines

      assert length(lines) > 0
      # Each split line should have :left and :right
      first = hd(lines)
      assert Map.has_key?(first, :left)
      assert Map.has_key?(first, :right)
    end

    test "pairs removes with adds in split view" do
      state = Diff.init(%{diff: @sample_diff, view: :split, id: :diff})
      tree = Diff.render(state)
      lines = tree.attrs.lines

      # Find the paired remove/add line
      paired =
        Enum.find(lines, fn line ->
          line.left.type == :remove and line.right.type == :add
        end)

      assert paired != nil
      assert paired.left.content == "line 2"
      assert paired.right.content == "line 2 modified"
    end

    test "pads with empty lines when unequal adds/removes" do
      state = Diff.init(%{diff: @multi_hunk_diff, view: :split, id: :diff})
      tree = Diff.render(state)
      lines = tree.attrs.lines

      empty_sides =
        Enum.filter(lines, fn line ->
          line.left.type == :empty or line.right.type == :empty
        end)

      # The second hunk has 1 remove and 2 adds, so there should be an empty left side
      assert length(empty_sides) > 0
    end
  end

  describe "updates" do
    test "set_diff resets scroll and reparses" do
      state = Diff.init(%{diff: @sample_diff, id: :diff})
      state = %{state | scroll_offset: 5}
      state = Diff.update({:set_diff, @multi_hunk_diff}, nil, state)
      assert state.scroll_offset == 0
      assert length(state.parsed) == 2
    end

    test "set_view changes mode" do
      state = Diff.init(%{diff: @sample_diff, id: :diff})
      state = Diff.update({:set_view, :split}, nil, state)
      assert state.view == :split
    end

    test "set_show_line_numbers" do
      state = Diff.init(%{diff: @sample_diff, id: :diff})
      state = Diff.update({:set_show_line_numbers, false}, nil, state)
      assert state.show_line_numbers == false
    end
  end

  describe "update_props/3" do
    test "preserves local line-number toggle when parent does not control it" do
      prev_props = %{diff: @sample_diff, id: :diff}
      new_props = %{diff: @sample_diff, id: :diff}

      state = Diff.init(prev_props)
      state = Diff.update({:set_show_line_numbers, false}, nil, state)
      state = Diff.update_props(prev_props, new_props, state)

      assert state.show_line_numbers == false
    end
  end

  describe "scrolling" do
    test "down increments scroll_offset" do
      state = Diff.init(%{diff: @sample_diff, id: :diff, visible_lines: 3})
      state = Diff.update(:key, key(:down), state)
      assert state.scroll_offset == 1
    end

    test "up decrements scroll_offset" do
      state = Diff.init(%{diff: @sample_diff, id: :diff, visible_lines: 3})
      state = %{state | scroll_offset: 2}
      state = Diff.update(:key, key(:up), state)
      assert state.scroll_offset == 1
    end

    test "home goes to top" do
      state = Diff.init(%{diff: @sample_diff, id: :diff, visible_lines: 3})
      state = %{state | scroll_offset: 3}
      state = Diff.update(:key, key(:home), state)
      assert state.scroll_offset == 0
    end
  end

  describe "render" do
    test "produces a :diff element" do
      state = Diff.init(%{diff: @sample_diff, id: :mydiff})
      tree = Diff.render(state)
      assert tree.type == :diff
      assert tree.id == :mydiff
    end

    test "includes view mode in element" do
      state = Diff.init(%{diff: @sample_diff, view: :split, id: :mydiff})
      tree = Diff.render(state)
      assert tree.attrs.view == :split
    end
  end
end
