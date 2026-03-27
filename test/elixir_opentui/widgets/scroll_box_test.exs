defmodule ElixirOpentui.Widgets.ScrollBoxTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.ScrollBox

  defp key(k) do
    %{type: :key, key: k, ctrl: false, alt: false, shift: false}
  end

  describe "init/1" do
    test "starts at scroll position 0" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      assert state.scroll_y == 0
      assert state.content_height == 50
      assert state.viewport_height == 10
    end
  end

  describe "arrow scrolling" do
    test "down scrolls by 1" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = ScrollBox.update(:key, key(:down), state)
      assert state.scroll_y == 1
    end

    test "up scrolls by 1" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = %{state | scroll_y: 5}
      state = ScrollBox.update(:key, key(:up), state)
      assert state.scroll_y == 4
    end

    test "up stops at 0" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = ScrollBox.update(:key, key(:up), state)
      assert state.scroll_y == 0
    end

    test "down stops at max" do
      state = ScrollBox.init(%{content_height: 15, height: 10, id: :sb})
      state = %{state | scroll_y: 5}
      state = ScrollBox.update(:key, key(:down), state)
      assert state.scroll_y == 5
    end
  end

  describe "page scrolling" do
    test "page down scrolls by viewport height" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = ScrollBox.update(:key, key(:page_down), state)
      assert state.scroll_y == 10
    end

    test "page up scrolls back" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = %{state | scroll_y: 20}
      state = ScrollBox.update(:key, key(:page_up), state)
      assert state.scroll_y == 10
    end
  end

  describe "home/end" do
    test "home goes to top" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = %{state | scroll_y: 20}
      state = ScrollBox.update(:key, key(:home), state)
      assert state.scroll_y == 0
    end

    test "end goes to bottom" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = ScrollBox.update(:key, key(:end), state)
      assert state.scroll_y == 40
    end
  end

  describe "mouse scroll" do
    test "scroll up" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = %{state | scroll_y: 10}
      event = %{type: :mouse, action: :scroll_up, x: 0, y: 0}
      state = ScrollBox.update(:mouse, event, state)
      assert state.scroll_y == 7
    end

    test "scroll down" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      event = %{type: :mouse, action: :scroll_down, x: 0, y: 0}
      state = ScrollBox.update(:mouse, event, state)
      assert state.scroll_y == 3
    end
  end

  describe "set_content_height" do
    test "updates content height and clamps scroll" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = %{state | scroll_y: 40}
      state = ScrollBox.update({:set_content_height, 15}, nil, state)
      assert state.content_height == 15
      assert state.scroll_y == 5
    end
  end

  describe "update_props/3" do
    test "preserves locally updated content height when parent keeps omitting the prop" do
      prev_props = %{height: 10, id: :sb}
      new_props = %{height: 10, id: :sb}

      state = ScrollBox.init(prev_props)
      state = ScrollBox.update({:set_content_height, 25}, nil, state)
      state = ScrollBox.update_props(prev_props, new_props, state)

      assert state.content_height == 25
    end

    test "resets content height when parent removes a previously controlled prop" do
      prev_props = %{content_height: 50, height: 10, id: :sb}
      new_props = %{height: 10, id: :sb}

      state = ScrollBox.init(prev_props)
      state = ScrollBox.update_props(prev_props, new_props, state)

      assert state.content_height == 0
    end
  end

  describe "set_scroll" do
    test "sets scroll position" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = ScrollBox.update({:set_scroll, 25}, nil, state)
      assert state.scroll_y == 25
    end

    test "clamps to valid range" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      state = ScrollBox.update({:set_scroll, 100}, nil, state)
      assert state.scroll_y == 40
    end
  end

  describe "render/1" do
    test "produces a scroll_box element" do
      state = ScrollBox.init(%{content_height: 50, height: 10, id: :sb})
      tree = ScrollBox.render(state)
      assert tree.type == :scroll_box
      assert tree.id == :sb
      assert tree.attrs.scroll_y == 0
    end
  end
end
