defmodule ElixirOpentui.Widgets.TextInputTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.TextInput

  defp key(k, opts \\ []) do
    %{
      type: :key,
      key: k,
      ctrl: Keyword.get(opts, :ctrl, false),
      alt: Keyword.get(opts, :alt, false),
      shift: Keyword.get(opts, :shift, false)
    }
  end

  describe "init/1" do
    test "initializes with value and cursor at end" do
      state = TextInput.init(%{value: "hello", id: :inp})
      assert state.value == "hello"
      assert state.cursor_pos == 5
      assert state.scroll_offset == 0
    end

    test "initializes empty" do
      state = TextInput.init(%{id: :inp})
      assert state.value == ""
      assert state.cursor_pos == 0
    end
  end

  describe "character insertion" do
    test "inserts at cursor position" do
      state = TextInput.init(%{value: "", id: :inp})
      state = TextInput.update(:key, key("a"), state)
      assert state.value == "a"
      assert state.cursor_pos == 1
    end

    test "inserts in the middle" do
      state = TextInput.init(%{value: "ac", id: :inp})
      state = %{state | cursor_pos: 1}
      state = TextInput.update(:key, key("b"), state)
      assert state.value == "abc"
      assert state.cursor_pos == 2
    end

    test "multiple characters" do
      state = TextInput.init(%{value: "", id: :inp})
      state = TextInput.update(:key, key("h"), state)
      state = TextInput.update(:key, key("i"), state)
      assert state.value == "hi"
      assert state.cursor_pos == 2
    end
  end

  describe "backspace" do
    test "deletes character before cursor" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = TextInput.update(:key, key(:backspace), state)
      assert state.value == "ab"
      assert state.cursor_pos == 2
    end

    test "no-op at beginning" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = %{state | cursor_pos: 0}
      state = TextInput.update(:key, key(:backspace), state)
      assert state.value == "abc"
      assert state.cursor_pos == 0
    end

    test "deletes in the middle" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = %{state | cursor_pos: 2}
      state = TextInput.update(:key, key(:backspace), state)
      assert state.value == "ac"
      assert state.cursor_pos == 1
    end
  end

  describe "delete" do
    test "deletes character at cursor" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = %{state | cursor_pos: 0}
      state = TextInput.update(:key, key(:delete), state)
      assert state.value == "bc"
      assert state.cursor_pos == 0
    end

    test "no-op at end" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = TextInput.update(:key, key(:delete), state)
      assert state.value == "abc"
    end
  end

  describe "cursor movement" do
    test "left moves cursor back" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = TextInput.update(:key, key(:left), state)
      assert state.cursor_pos == 2
    end

    test "right at end stays" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = TextInput.update(:key, key(:right), state)
      assert state.cursor_pos == 3
    end

    test "home goes to beginning" do
      state = TextInput.init(%{value: "hello", id: :inp})
      state = TextInput.update(:key, key(:home), state)
      assert state.cursor_pos == 0
    end

    test "end goes to end" do
      state = TextInput.init(%{value: "hello", id: :inp})
      state = %{state | cursor_pos: 0}
      state = TextInput.update(:key, key(:end), state)
      assert state.cursor_pos == 5
    end

    test "Ctrl+A goes to beginning" do
      state = TextInput.init(%{value: "hello", id: :inp})
      state = TextInput.update(:key, key("a", ctrl: true), state)
      assert state.cursor_pos == 0
    end

    test "Ctrl+E goes to end" do
      state = TextInput.init(%{value: "hello", id: :inp})
      state = %{state | cursor_pos: 0}
      state = TextInput.update(:key, key("e", ctrl: true), state)
      assert state.cursor_pos == 5
    end
  end

  describe "Ctrl+K / Ctrl+U" do
    test "Ctrl+K kills to end of line" do
      state = TextInput.init(%{value: "hello world", id: :inp})
      state = %{state | cursor_pos: 5}
      state = TextInput.update(:key, key("k", ctrl: true), state)
      assert state.value == "hello"
    end

    test "Ctrl+U kills to beginning of line" do
      state = TextInput.init(%{value: "hello world", id: :inp})
      state = %{state | cursor_pos: 5}
      state = TextInput.update(:key, key("u", ctrl: true), state)
      assert state.value == " world"
      assert state.cursor_pos == 0
    end
  end

  describe "scroll offset" do
    test "scrolls right when cursor moves past visible area" do
      state = TextInput.init(%{value: "", width: 5, id: :inp})

      state =
        Enum.reduce(String.graphemes("abcdefghij"), state, fn char, s ->
          TextInput.update(:key, key(char), s)
        end)

      assert state.value == "abcdefghij"
      assert state.cursor_pos == 10
      assert state.scroll_offset > 0
    end

    test "scrolls left when cursor moves before visible area" do
      state = TextInput.init(%{value: "abcdefghij", width: 5, id: :inp})
      state = %{state | scroll_offset: 5, cursor_pos: 5}
      state = TextInput.update(:key, key(:left), state)
      state = TextInput.update(:key, key(:left), state)

      assert state.cursor_pos == 3
    end
  end

  describe "paste" do
    test "inserts pasted text" do
      state = TextInput.init(%{value: "hello ", id: :inp})
      state = TextInput.update(:paste, %{type: :paste, data: "world"}, state)
      assert state.value == "hello world"
      assert state.cursor_pos == 11
    end
  end

  describe "render/1" do
    test "produces an input element" do
      state = TextInput.init(%{value: "test", id: :myinput})
      tree = TextInput.render(state)
      assert tree.type == :input
      assert tree.id == :myinput
      assert tree.attrs.value == "test"
    end
  end
end
