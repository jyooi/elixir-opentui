defmodule ElixirOpentui.ComponentTest do
  use ExUnit.Case, async: true


  defmodule Counter do
    use ElixirOpentui.Component

    def init(props), do: %{count: Map.get(props, :initial, 0)}

    def update(:increment, _event, state), do: %{state | count: state.count + 1}
    def update(:decrement, _event, state), do: %{state | count: state.count - 1}
    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View

      box direction: :row, gap: 1 do
        button(id: :dec, content: "-", width: 3)
        text(content: "#{state.count}")
        button(id: :inc, content: "+", width: 3)
      end
    end
  end

  defmodule StaticLabel do
    use ElixirOpentui.Component

    def init(props), do: %{text: Map.get(props, :text, "Hello")}
    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View
      text(content: state.text)
    end
  end

  describe "Component behaviour" do
    test "init returns initial state" do
      state = Counter.init(%{initial: 5})
      assert state.count == 5
    end

    test "init with defaults" do
      state = Counter.init(%{})
      assert state.count == 0
    end

    test "update handles messages" do
      state = Counter.init(%{})
      state = Counter.update(:increment, nil, state)
      assert state.count == 1
      state = Counter.update(:decrement, nil, state)
      assert state.count == 0
    end

    test "render returns element tree" do
      state = Counter.init(%{initial: 42})
      tree = Counter.render(state)
      assert tree.type == :box
      assert length(tree.children) == 3
    end

    test "render reflects current state" do
      state = Counter.init(%{initial: 7})
      tree = Counter.render(state)
      text_el = Enum.find(tree.children, &(&1.type == :text))
      assert text_el.attrs.content == "7"
    end
  end
end
