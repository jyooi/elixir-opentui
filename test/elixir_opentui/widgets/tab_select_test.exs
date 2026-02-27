defmodule ElixirOpentui.Widgets.TabSelectTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.TabSelect

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

  @options [
    %{name: "Tab 1", description: "First tab"},
    %{name: "Tab 2", description: "Second tab"},
    %{name: "Tab 3", description: "Third tab"},
    %{name: "Tab 4", description: "Fourth tab"},
    %{name: "Tab 5", description: "Fifth tab"}
  ]

  describe "init/1" do
    test "initializes with options and default selection" do
      state = TabSelect.init(%{options: @options, id: :tabs})
      assert length(state.options) == 5
      assert state.selected == 0
      assert state.scroll_offset == 0
      assert state._pending == []
    end

    test "initializes with custom tab_width" do
      state = TabSelect.init(%{options: @options, id: :tabs, tab_width: 15})
      assert state.tab_width == 15
    end

    test "initializes with default settings" do
      state = TabSelect.init(%{options: @options, id: :tabs})
      assert state.show_description == true
      assert state.show_underline == true
      assert state.show_scroll_arrows == true
      assert state.wrap_selection == false
      assert state.tab_width == 20
    end
  end

  describe "option normalization" do
    test "map options with name and description" do
      state = TabSelect.init(%{options: @options, id: :tabs})
      first = hd(state.options)
      assert first.name == "Tab 1"
      assert first.description == "First tab"
    end

    test "string options auto-convert to map" do
      state = TabSelect.init(%{options: ["Home", "Files", "Settings"], id: :tabs})
      first = hd(state.options)
      assert first.name == "Home"
      assert first.description == nil
    end
  end

  describe "arrow navigation" do
    test "right moves to next tab" do
      state = TabSelect.init(%{options: @options, id: :tabs})
      state = TabSelect.update(:key, key(:right), state)
      assert state.selected == 1
    end

    test "left moves to previous tab" do
      state = TabSelect.init(%{options: @options, selected: 2, id: :tabs})
      state = TabSelect.update(:key, key(:left), state)
      assert state.selected == 1
    end

    test "right stops at last tab (wrap_selection false)" do
      state = TabSelect.init(%{options: @options, selected: 4, id: :tabs})
      state = TabSelect.update(:key, key(:right), state)
      assert state.selected == 4
    end

    test "left stops at first tab (wrap_selection false)" do
      state = TabSelect.init(%{options: @options, selected: 0, id: :tabs})
      state = TabSelect.update(:key, key(:left), state)
      assert state.selected == 0
    end
  end

  describe "bracket navigation" do
    test "] moves to next tab" do
      state = TabSelect.init(%{options: @options, id: :tabs})
      state = TabSelect.update(:key, key("]"), state)
      assert state.selected == 1
    end

    test "[ moves to previous tab" do
      state = TabSelect.init(%{options: @options, selected: 2, id: :tabs})
      state = TabSelect.update(:key, key("["), state)
      assert state.selected == 1
    end
  end

  describe "wrap_selection" do
    test "wrap_selection true wraps at end" do
      state = TabSelect.init(%{options: @options, selected: 4, wrap_selection: true, id: :tabs})
      state = TabSelect.update(:key, key(:right), state)
      assert state.selected == 0
    end

    test "wrap_selection true wraps at beginning" do
      state = TabSelect.init(%{options: @options, selected: 0, wrap_selection: true, id: :tabs})
      state = TabSelect.update(:key, key(:left), state)
      assert state.selected == 4
    end
  end

  describe "enter key selection" do
    test "enter emits on_select pending message" do
      state = TabSelect.init(%{options: @options, on_select: :tab_selected, id: :tabs})
      state = TabSelect.update(:key, key(:enter), state)
      assert length(state._pending) == 1
      [{tag, idx, opt}] = state._pending
      assert tag == :tab_selected
      assert idx == 0
      assert opt.name == "Tab 1"
    end

    test "enter no-op without on_select" do
      state = TabSelect.init(%{options: @options, id: :tabs})
      state = TabSelect.update(:key, key(:enter), state)
      assert state._pending == []
    end
  end

  describe "on_change emission" do
    test "navigation emits on_change" do
      state = TabSelect.init(%{options: @options, on_change: :changed, id: :tabs})
      state = TabSelect.update(:key, key(:right), state)
      assert [{:changed, 1}] = state._pending
    end

    test "no emission when selection doesn't change" do
      state = TabSelect.init(%{options: @options, selected: 0, on_change: :changed, id: :tabs})
      state = TabSelect.update(:key, key(:left), state)
      assert state._pending == []
    end

    test "bracket navigation emits on_change" do
      state = TabSelect.init(%{options: @options, on_change: :changed, id: :tabs})
      state = TabSelect.update(:key, key("]"), state)
      assert [{:changed, 1}] = state._pending
    end
  end

  describe "set_options" do
    test "updates options and clamps selection" do
      state = TabSelect.init(%{options: @options, selected: 4, id: :tabs})
      new_opts = [%{name: "A", description: "A"}, %{name: "B", description: "B"}]
      state = TabSelect.update({:set_options, new_opts}, nil, state)
      assert length(state.options) == 2
      assert state.selected == 1
    end
  end

  describe "set_selected" do
    test "sets selection directly" do
      state = TabSelect.init(%{options: @options, id: :tabs})
      state = TabSelect.update({:set_selected, 3}, nil, state)
      assert state.selected == 3
    end

    test "clamps out of bounds" do
      state = TabSelect.init(%{options: @options, id: :tabs})
      state = TabSelect.update({:set_selected, 100}, nil, state)
      assert state.selected == 4
    end
  end

  describe "scroll_offset" do
    test "scroll adjusts when selection moves past visible range" do
      # With width 40 and tab_width 20, only 2 tabs visible
      state = TabSelect.init(%{options: @options, id: :tabs, tab_width: 20, width: 40})
      # Move right 3 times to go past visible range
      state = TabSelect.update(:key, key(:right), state)
      state = TabSelect.update(:key, key(:right), state)
      state = TabSelect.update(:key, key(:right), state)
      assert state.selected == 3
      assert state.scroll_offset > 0
    end
  end

  describe "render" do
    test "produces a :tab_select element" do
      state = TabSelect.init(%{options: @options, id: :mytabs})
      tree = TabSelect.render(state)
      assert tree.type == :tab_select
      assert tree.id == :mytabs
    end

    test "render includes tab options and selection" do
      state = TabSelect.init(%{options: @options, id: :mytabs, selected: 2})
      tree = TabSelect.render(state)
      assert tree.attrs.selected == 2
      assert length(tree.attrs.options) == 5
    end
  end
end
