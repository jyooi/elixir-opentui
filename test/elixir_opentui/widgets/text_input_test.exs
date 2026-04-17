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

    test "initializes with _pending list" do
      state = TextInput.init(%{id: :inp})
      assert state._pending == []
    end
  end

  describe "update_props/3" do
    test "preserves local edits when unrelated props change" do
      prev_props = %{id: :inp, value: "hello", placeholder: "old"}
      new_props = %{id: :inp, value: "hello", placeholder: "new"}

      state = TextInput.init(prev_props)
      state = TextInput.update(:key, key("!"), state)
      state = TextInput.update_props(prev_props, new_props, state)

      assert state.value == "hello!"
      assert state.cursor_pos == 6
      assert state.placeholder == "new"
    end

    test "syncs value when the incoming value prop changes" do
      prev_props = %{id: :inp, value: "hello"}
      new_props = %{id: :inp, value: "ok"}

      state = TextInput.init(prev_props)
      state = TextInput.update(:key, key("!"), state)
      state = TextInput.update_props(prev_props, new_props, state)

      assert state.value == "ok"
      assert state.cursor_pos == 2
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

  describe "Emacs keybindings" do
    test "Ctrl+B moves cursor left" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = TextInput.update(:key, key("b", ctrl: true), state)
      assert state.cursor_pos == 2
    end

    test "Ctrl+F moves cursor right" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = %{state | cursor_pos: 0}
      state = TextInput.update(:key, key("f", ctrl: true), state)
      assert state.cursor_pos == 1
    end

    test "Ctrl+D deletes forward" do
      state = TextInput.init(%{value: "abc", id: :inp})
      state = %{state | cursor_pos: 0}
      state = TextInput.update(:key, key("d", ctrl: true), state)
      assert state.value == "bc"
      assert state.cursor_pos == 0
    end
  end

  describe "emit_change via _pending" do
    test "emit_change fires when on_change is set" do
      state = TextInput.init(%{value: "", on_change: :text_changed, id: :inp})
      state = TextInput.update(:key, key("a"), state)
      assert state.value == "a"
      assert {:text_changed, "a"} in state._pending
    end

    test "emit_change does not fire when on_change is nil" do
      state = TextInput.init(%{value: "", id: :inp})
      state = TextInput.update(:key, key("a"), state)
      assert state.value == "a"
      assert state._pending == []
    end
  end

  describe "on_submit" do
    test "Enter key triggers on_submit pending message" do
      state = TextInput.init(%{value: "hello", on_submit: :submitted, id: :inp})
      state = TextInput.update(:key, key(:enter), state)
      assert {:submitted, "hello"} in state._pending
    end

    test "Enter key no-op when on_submit is nil" do
      state = TextInput.init(%{value: "hello", id: :inp})
      state = TextInput.update(:key, key(:enter), state)
      assert state._pending == []
    end
  end

  describe "max_length" do
    test "max_length rejects insertion when at limit" do
      state = TextInput.init(%{value: "abc", max_length: 3, id: :inp})
      state = TextInput.update(:key, key("d"), state)
      assert state.value == "abc"
    end

    test "max_length allows insertion when under limit" do
      state = TextInput.init(%{value: "ab", max_length: 3, id: :inp})
      state = TextInput.update(:key, key("c"), state)
      assert state.value == "abc"
    end

    test "max_length truncates pasted text" do
      state = TextInput.init(%{value: "", max_length: 5, id: :inp})
      state = TextInput.update(:paste, %{type: :paste, data: "abcdefghij"}, state)
      assert String.length(state.value) <= 5
    end

    test "max_length defaults to infinity" do
      state = TextInput.init(%{id: :inp})
      assert state.max_length == :infinity
    end
  end

  describe "focus and cursor styling" do
    test "focus colors passed through element attrs" do
      state =
        TextInput.init(%{
          id: :inp,
          focused_bg: {50, 50, 50, 255},
          cursor_bg: {200, 200, 200, 255}
        })

      tree = TextInput.render(state)
      assert tree.attrs.focused_bg == {50, 50, 50, 255}
      assert tree.attrs.cursor_bg == {200, 200, 200, 255}
    end

    test "cursor_style passed through element style" do
      state = TextInput.init(%{id: :inp, cursor_style: :bar})
      tree = TextInput.render(state)
      assert tree.style.cursor_style == :bar
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

    test "scroll offset uses display columns for wide graphemes" do
      state = TextInput.init(%{value: "", width: 3, id: :inp})
      state = TextInput.update(:key, key("A"), state)
      state = TextInput.update(:paste, %{type: :paste, data: "界"}, state)
      state = TextInput.update(:key, key("B"), state)

      assert state.value == "A界B"
      assert state.cursor_pos == 3
      assert state.scroll_offset == 2
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
