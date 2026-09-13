defmodule ElixirOpentui.EventManagerTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{EventManager, Element, Buffer, Layout, Painter}

  defp build_scene do
    tree =
      Element.new(:box, [id: :root, width: 20, height: 5], [
        Element.new(:button, id: :btn, content: "Click", width: 10, height: 1),
        Element.new(:input, id: :inp, value: "", width: 10, height: 1)
      ])

    {tagged, layout_results} = Layout.compute(tree, 20, 5)
    buffer = Buffer.new(20, 5)
    buffer = Painter.paint(tagged, layout_results, buffer)
    {tree, buffer}
  end

  describe "new/2" do
    test "creates event manager with focus from tree" do
      {tree, buffer} = build_scene()
      em = EventManager.new(tree, buffer)
      assert em.focus.focusable_ids == [:btn, :inp]
      assert em.focus.focused_id == nil
    end
  end

  describe "tab navigation" do
    test "Tab focuses first element" do
      {tree, buffer} = build_scene()
      em = EventManager.new(tree, buffer)

      tab = %{type: :key, key: :tab, ctrl: false, alt: false, shift: false}
      {em2, actions} = EventManager.process(em, tab)
      assert em2.focus.focused_id == :btn
      assert [{:focus_changed, :btn}] = actions
    end

    test "Tab cycles through elements" do
      {tree, buffer} = build_scene()
      em = EventManager.new(tree, buffer)

      tab = %{type: :key, key: :tab, ctrl: false, alt: false, shift: false}
      {em2, _} = EventManager.process(em, tab)
      {em3, _} = EventManager.process(em2, tab)
      assert em3.focus.focused_id == :inp
    end

    test "Shift+Tab goes backward" do
      {tree, buffer} = build_scene()
      em = EventManager.new(tree, buffer)

      shift_tab = %{type: :key, key: :tab, ctrl: false, alt: false, shift: true}
      {em2, _} = EventManager.process(em, shift_tab)
      assert em2.focus.focused_id == :inp
    end
  end

  describe "mouse focus" do
    test "left click on button focuses it" do
      {tree, buffer} = build_scene()
      em = EventManager.new(tree, buffer)

      click = %{
        type: :mouse,
        action: :press,
        button: :left,
        x: 0,
        y: 0,
        ctrl: false,
        alt: false,
        shift: false
      }

      {em2, _} = EventManager.process(em, click)
      assert em2.focus.focused_id == :btn
    end

    test "click on non-focusable area does not change focus" do
      {tree, buffer} = build_scene()
      em = EventManager.new(tree, buffer)

      # Click on empty area (beyond elements)
      click = %{
        type: :mouse,
        action: :press,
        button: :left,
        x: 15,
        y: 4,
        ctrl: false,
        alt: false,
        shift: false
      }

      {em2, _} = EventManager.process(em, click)
      assert em2.focus.focused_id == nil
    end

    test "right click does not auto-focus" do
      {tree, buffer} = build_scene()
      em = EventManager.new(tree, buffer)

      right_click = %{
        type: :mouse,
        action: :press,
        button: :right,
        x: 0,
        y: 0,
        ctrl: false,
        alt: false,
        shift: false
      }

      {em2, _} = EventManager.process(em, right_click)
      assert em2.focus.focused_id == nil
    end
  end

  describe "update/3" do
    test "updates tree and buffer, preserves focus" do
      {tree, buffer} = build_scene()
      em = EventManager.new(tree, buffer)
      em = %{em | focus: ElixirOpentui.Focus.focus(em.focus, :btn)}

      em2 = EventManager.update(em, tree, buffer)
      assert em2.focus.focused_id == :btn
    end
  end

  describe "resize events" do
    test "resize produces resize action" do
      {tree, buffer} = build_scene()
      em = EventManager.new(tree, buffer)

      resize = %{type: :resize, cols: 100, rows: 40}
      {_em2, actions} = EventManager.process(em, resize)
      assert [{:resize, 100, 40}] = actions
    end
  end
end
