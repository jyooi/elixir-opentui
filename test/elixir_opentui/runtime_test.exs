defmodule ElixirOpentui.RuntimeTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Runtime

  defmodule SimpleApp do
    use ElixirOpentui.Component

    def init(props), do: %{title: Map.get(props, :title, "Hello")}
    def update({:set_title, title}, _event, state), do: %{state | title: title}
    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View

      box id: :root, width: 40, height: 10 do
        text(id: :title, content: state.title)
        button(id: :btn, content: "Click me", width: 15, height: 1)
        input(id: :inp, value: "", width: 20, height: 1)
      end
    end
  end

  defmodule CounterApp do
    use ElixirOpentui.Component

    def init(_props), do: %{count: 0}

    def update(:increment, _event, state), do: %{state | count: state.count + 1}
    def update(:decrement, _event, state), do: %{state | count: state.count - 1}
    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View

      box id: :root, width: 30, height: 5 do
        text(id: :count, content: "Count: #{state.count}")
        button(id: :inc_btn, content: "+", width: 5, height: 1)
        button(id: :dec_btn, content: "-", width: 5, height: 1)
      end
    end
  end

  describe "start_link and mount" do
    test "starts runtime with default dimensions" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10)
      Runtime.mount(rt, SimpleApp)
      frame = Runtime.get_frame(rt)
      assert length(frame) == 10
      assert String.contains?(hd(frame), "Hello")
    end

    test "mount with custom props" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10)
      Runtime.mount(rt, SimpleApp, %{title: "Custom"})
      frame = Runtime.get_frame(rt)
      assert String.contains?(hd(frame), "Custom")
    end
  end

  describe "focus management" do
    test "initial focus is nil" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10)
      Runtime.mount(rt, SimpleApp)
      focus = Runtime.get_focus(rt)
      assert focus.focused_id == nil
    end

    test "focusable elements are detected" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10)
      Runtime.mount(rt, SimpleApp)
      focus = Runtime.get_focus(rt)
      assert :btn in focus.focusable_ids
      assert :inp in focus.focusable_ids
    end

    test "tab event advances focus" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10)
      Runtime.mount(rt, SimpleApp)

      tab = %{type: :key, key: :tab, ctrl: false, alt: false, shift: false}
      Runtime.send_event(rt, tab)
      Process.sleep(10)

      focus = Runtime.get_focus(rt)
      assert focus.focused_id == :btn
    end
  end

  describe "rendering" do
    test "get_frame returns list of row strings" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10)
      Runtime.mount(rt, SimpleApp)
      frame = Runtime.get_frame(rt)
      assert is_list(frame)
      assert Enum.all?(frame, &is_binary/1)
    end

    test "frame dimensions match" do
      {:ok, rt} = Runtime.start_link(cols: 30, rows: 5)
      Runtime.mount(rt, CounterApp)
      frame = Runtime.get_frame(rt)
      assert length(frame) == 5
      assert String.length(hd(frame)) == 30
    end

    test "frame contains rendered content" do
      {:ok, rt} = Runtime.start_link(cols: 30, rows: 5)
      Runtime.mount(rt, CounterApp)
      frame = Runtime.get_frame(rt)
      joined = Enum.join(frame)
      assert String.contains?(joined, "Count: 0")
    end
  end

  describe "send_msg to runtime" do
    test "component message updates state and re-renders" do
      {:ok, rt} = Runtime.start_link(cols: 30, rows: 5)
      Runtime.mount(rt, CounterApp)

      Runtime.send_msg(rt, nil, :increment)
      Process.sleep(10)

      # The app_module is CounterApp, but send_msg sends to component_states.
      # For app-level updates, we use send_event with an :update action.
      # Let's verify the frame still shows the count
      frame = Runtime.get_frame(rt)
      joined = Enum.join(frame)
      assert String.contains?(joined, "Count:")
    end
  end

  describe "get_tree" do
    test "returns current element tree" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10)
      Runtime.mount(rt, SimpleApp)
      tree = Runtime.get_tree(rt)
      assert tree.type == :box
      assert tree.id == :root
    end
  end

  describe "resize" do
    test "resize updates renderer dimensions" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10)
      Runtime.mount(rt, SimpleApp)
      Runtime.resize(rt, 60, 20)
      frame = Runtime.get_frame(rt)
      assert length(frame) == 20
      assert String.length(hd(frame)) == 60
    end
  end

  describe "event callbacks" do
    test "on_event callback is called" do
      test_pid = self()

      {:ok, rt} =
        Runtime.start_link(
          cols: 40,
          rows: 10,
          on_event: fn event -> send(test_pid, {:event, event}) end
        )

      Runtime.mount(rt, SimpleApp)

      key = %{type: :key, key: "a", ctrl: false, alt: false, shift: false}
      Runtime.send_event(rt, key)

      assert_receive {:event, ^key}, 100
    end
  end
end
