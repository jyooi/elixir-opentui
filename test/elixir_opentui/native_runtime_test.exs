defmodule ElixirOpentui.NativeRuntimeTest do
  use ExUnit.Case, async: true

  @moduletag :nif

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

  describe "native backend runtime" do
    test "mount and get_frame" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10, backend: :native)
      Runtime.mount(rt, SimpleApp)
      frame = Runtime.get_frame(rt)
      assert length(frame) == 10
      assert String.contains?(hd(frame), "Hello")
    end

    test "frame dimensions match" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10, backend: :native)
      Runtime.mount(rt, SimpleApp)
      frame = Runtime.get_frame(rt)
      assert length(frame) == 10
      assert String.length(hd(frame)) == 40
    end

    test "focus management works" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10, backend: :native)
      Runtime.mount(rt, SimpleApp)

      focus = Runtime.get_focus(rt)
      assert :btn in focus.focusable_ids
      assert :inp in focus.focusable_ids
    end

    test "tab event advances focus" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10, backend: :native)
      Runtime.mount(rt, SimpleApp)

      tab = %{type: :key, key: :tab, ctrl: false, alt: false, shift: false}
      Runtime.send_event(rt, tab)
      Process.sleep(10)

      focus = Runtime.get_focus(rt)
      assert focus.focused_id == :btn
    end

    test "resize works" do
      {:ok, rt} = Runtime.start_link(cols: 40, rows: 10, backend: :native)
      Runtime.mount(rt, SimpleApp)
      Runtime.resize(rt, 60, 20)
      frame = Runtime.get_frame(rt)
      assert length(frame) == 20
      assert String.length(hd(frame)) == 60
    end
  end
end
