defmodule ElixirOpentui.Widgets.SelectTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.Select

  defp key(k) do
    %{type: :key, key: k, ctrl: false, alt: false, shift: false}
  end

  @options ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]

  describe "init/1" do
    test "initializes with options and default selection" do
      state = Select.init(%{options: @options, id: :sel})
      assert state.options == @options
      assert state.selected == 0
      assert state.scroll_offset == 0
    end

    test "initializes with custom selection" do
      state = Select.init(%{options: @options, selected: 2, id: :sel})
      assert state.selected == 2
    end
  end

  describe "arrow navigation" do
    test "down moves to next option" do
      state = Select.init(%{options: @options, id: :sel})
      state = Select.update(:key, key(:down), state)
      assert state.selected == 1
    end

    test "up moves to previous option" do
      state = Select.init(%{options: @options, selected: 2, id: :sel})
      state = Select.update(:key, key(:up), state)
      assert state.selected == 1
    end

    test "down stops at last option" do
      state = Select.init(%{options: @options, selected: 4, id: :sel})
      state = Select.update(:key, key(:down), state)
      assert state.selected == 4
    end

    test "up stops at first option" do
      state = Select.init(%{options: @options, selected: 0, id: :sel})
      state = Select.update(:key, key(:up), state)
      assert state.selected == 0
    end
  end

  describe "home/end" do
    test "home goes to first" do
      state = Select.init(%{options: @options, selected: 3, id: :sel})
      state = Select.update(:key, key(:home), state)
      assert state.selected == 0
    end

    test "end goes to last" do
      state = Select.init(%{options: @options, id: :sel})
      state = Select.update(:key, key(:end), state)
      assert state.selected == 4
    end
  end

  describe "page up/down" do
    test "page down jumps by visible count" do
      state = Select.init(%{options: @options, visible_count: 3, id: :sel})
      state = Select.update(:key, key(:page_down), state)
      assert state.selected == 3
    end

    test "page up jumps back" do
      state = Select.init(%{options: @options, selected: 4, visible_count: 3, id: :sel})
      state = Select.update(:key, key(:page_up), state)
      assert state.selected == 1
    end
  end

  describe "set_options" do
    test "updates options and clamps selection" do
      state = Select.init(%{options: @options, selected: 4, id: :sel})
      state = Select.update({:set_options, ["A", "B"]}, nil, state)
      assert state.options == ["A", "B"]
      assert state.selected == 1
    end
  end

  describe "set_selected" do
    test "sets selection directly" do
      state = Select.init(%{options: @options, id: :sel})
      state = Select.update({:set_selected, 3}, nil, state)
      assert state.selected == 3
    end

    test "clamps out of bounds" do
      state = Select.init(%{options: @options, id: :sel})
      state = Select.update({:set_selected, 100}, nil, state)
      assert state.selected == 4
    end
  end

  describe "render/1" do
    test "produces a select element" do
      state = Select.init(%{options: @options, id: :mysel})
      tree = Select.render(state)
      assert tree.type == :select
      assert tree.id == :mysel
      assert tree.attrs.options == @options
      assert tree.attrs.selected == 0
    end
  end
end
