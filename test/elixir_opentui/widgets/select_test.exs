defmodule ElixirOpentui.Widgets.SelectTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.Select

  defp key(k, opts \\ []) do
    %{
      type: :key,
      key: k,
      ctrl: Keyword.get(opts, :ctrl, false),
      alt: Keyword.get(opts, :alt, false),
      shift: Keyword.get(opts, :shift, false)
    }
  end

  @options ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]

  describe "init/1" do
    test "initializes with options and default selection" do
      state = Select.init(%{options: @options, id: :sel})
      assert length(state.options) == 5
      assert state.selected == 0
      assert state.scroll_offset == 0
      assert state._pending == []
    end

    test "initializes with custom selection" do
      state = Select.init(%{options: @options, selected: 2, id: :sel})
      assert state.selected == 2
    end
  end

  describe "option normalization" do
    test "string options auto-convert to SelectOption map" do
      state = Select.init(%{options: ["Alpha", "Bravo"], id: :sel})
      assert hd(state.options) == %{name: "Alpha", description: nil, value: nil}
    end

    test "SelectOption map with name/description/value" do
      opts = [
        %{name: "Alpha", description: "First letter", value: :alpha},
        %{name: "Bravo", description: "Second letter", value: :bravo}
      ]

      state = Select.init(%{options: opts, id: :sel})
      first = hd(state.options)
      assert first.name == "Alpha"
      assert first.description == "First letter"
      assert first.value == :alpha
    end

    test "render includes normalized option format" do
      state = Select.init(%{options: @options, id: :mysel})
      tree = Select.render(state)
      assert tree.type == :select
      assert tree.id == :mysel
      first_opt = hd(tree.attrs.options)
      assert first_opt.name == "Alpha"
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

    test "down stops at last option (wrap_selection false)" do
      state = Select.init(%{options: @options, selected: 4, id: :sel})
      state = Select.update(:key, key(:down), state)
      assert state.selected == 4
    end

    test "up stops at first option (wrap_selection false)" do
      state = Select.init(%{options: @options, selected: 0, id: :sel})
      state = Select.update(:key, key(:up), state)
      assert state.selected == 0
    end
  end

  describe "vim navigation" do
    test "j moves selection down" do
      state = Select.init(%{options: @options, id: :sel})
      state = Select.update(:key, key("j"), state)
      assert state.selected == 1
    end

    test "k moves selection up" do
      state = Select.init(%{options: @options, selected: 2, id: :sel})
      state = Select.update(:key, key("k"), state)
      assert state.selected == 1
    end
  end

  describe "fast scroll" do
    test "Shift+Down fast scrolls by step" do
      state = Select.init(%{options: @options, fast_scroll_step: 3, id: :sel})
      state = Select.update(:key, key(:down, shift: true), state)
      assert state.selected == 3
    end

    test "Shift+Up fast scrolls by step" do
      state = Select.init(%{options: @options, selected: 4, fast_scroll_step: 3, id: :sel})
      state = Select.update(:key, key(:up, shift: true), state)
      assert state.selected == 1
    end

    test "fast scroll clamps to bounds" do
      state = Select.init(%{options: @options, selected: 3, fast_scroll_step: 5, id: :sel})
      state = Select.update(:key, key(:down, shift: true), state)
      assert state.selected == 4
    end
  end

  describe "wrap_selection" do
    test "wrap_selection true wraps at bottom" do
      state = Select.init(%{options: @options, selected: 4, wrap_selection: true, id: :sel})
      state = Select.update(:key, key(:down), state)
      assert state.selected == 0
    end

    test "wrap_selection true wraps at top" do
      state = Select.init(%{options: @options, selected: 0, wrap_selection: true, id: :sel})
      state = Select.update(:key, key(:up), state)
      assert state.selected == 4
    end
  end

  describe "Enter key selection" do
    test "Enter key emits on_select pending message" do
      state = Select.init(%{options: @options, on_select: :item_selected, id: :sel})
      state = Select.update(:key, key(:enter), state)
      assert length(state._pending) == 1
      [{tag, idx, opt}] = state._pending
      assert tag == :item_selected
      assert idx == 0
      assert opt.name == "Alpha"
    end

    test "Enter no-op without on_select" do
      state = Select.init(%{options: @options, id: :sel})
      state = Select.update(:key, key(:enter), state)
      assert state._pending == []
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
      assert length(state.options) == 2
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

  describe "show_description" do
    test "show_description affects rows_per_item" do
      state = Select.init(%{options: @options, visible_count: 10, show_description: true, id: :sel})
      # With show_description=true, rows_per_item=2, so visible_items = 10/2 = 5
      # page_down should move by 5 items
      state = Select.update(:key, key(:page_down), state)
      assert state.selected == 4
    end
  end

  describe "item_spacing" do
    test "item_spacing affects rows_per_item" do
      state =
        Select.init(%{options: @options, visible_count: 10, item_spacing: 1, id: :sel})

      # rows_per_item = 1 + 0 + 1 = 2, visible_items = 10/2 = 5
      state = Select.update(:key, key(:page_down), state)
      assert state.selected == 4
    end
  end

  describe "scroll indicator" do
    test "scroll indicator reduces option text width by 1" do
      state = Select.init(%{options: @options, show_scroll_indicator: true, id: :sel})
      tree = Select.render(state)
      assert tree.attrs.show_scroll_indicator == true
    end
  end
end
