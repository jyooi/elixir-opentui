defmodule ElixirOpentui.Widgets.CheckboxTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.Checkbox

  defp key(k) do
    %{type: :key, key: k, ctrl: false, alt: false, shift: false}
  end

  describe "init/1" do
    test "defaults to unchecked" do
      state = Checkbox.init(%{label: "Accept", id: :cb})
      assert state.checked == false
      assert state.label == "Accept"
    end

    test "can start checked" do
      state = Checkbox.init(%{checked: true, label: "Agree", id: :cb})
      assert state.checked == true
    end
  end

  describe "toggle" do
    test "space toggles" do
      state = Checkbox.init(%{label: "Test", id: :cb})
      state = Checkbox.update(:key, key(" "), state)
      assert state.checked == true
      state = Checkbox.update(:key, key(" "), state)
      assert state.checked == false
    end

    test "enter toggles" do
      state = Checkbox.init(%{label: "Test", id: :cb})
      state = Checkbox.update(:key, key(:enter), state)
      assert state.checked == true
    end

    test "toggle message" do
      state = Checkbox.init(%{label: "Test", id: :cb})
      state = Checkbox.update(:toggle, nil, state)
      assert state.checked == true
    end
  end

  describe "set_checked" do
    test "sets checked value directly" do
      state = Checkbox.init(%{label: "Test", id: :cb})
      state = Checkbox.update({:set_checked, true}, nil, state)
      assert state.checked == true
      state = Checkbox.update({:set_checked, false}, nil, state)
      assert state.checked == false
    end
  end

  describe "on_change emission" do
    test "space toggle emits on_change with new value" do
      state = Checkbox.init(%{label: "Test", on_change: :toggled, id: :cb})
      state = Checkbox.update(:key, key(" "), state)
      assert state.checked == true
      assert [{:toggled, true}] = state._pending
    end

    test "enter toggle emits on_change" do
      state = Checkbox.init(%{label: "Test", on_change: :toggled, id: :cb})
      state = Checkbox.update(:key, key(:enter), state)
      assert [{:toggled, true}] = state._pending
    end

    test "toggle message emits on_change" do
      state = Checkbox.init(%{label: "Test", on_change: :toggled, id: :cb})
      state = Checkbox.update(:toggle, nil, state)
      assert [{:toggled, true}] = state._pending
    end

    test "no on_change means no pending" do
      state = Checkbox.init(%{label: "Test", id: :cb})
      state = Checkbox.update(:key, key(" "), state)
      assert state._pending == []
    end
  end

  describe "render/1" do
    test "produces a checkbox element" do
      state = Checkbox.init(%{label: "Accept terms", id: :cb})
      tree = Checkbox.render(state)
      assert tree.type == :checkbox
      assert tree.id == :cb
      assert tree.attrs.label == "Accept terms"
      assert tree.attrs.checked == false
    end
  end
end
