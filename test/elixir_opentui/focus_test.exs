defmodule ElixirOpentui.FocusTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Focus, Element}

  defp sample_tree do
    Element.new(:box, [id: :root, width: 40, height: 10], [
      Element.new(:input, id: :name_input, value: "", width: 20),
      Element.new(:text, id: :label, content: "Name:"),
      Element.new(:button, id: :submit_btn, content: "Submit", width: 10),
      Element.new(:select, id: :role_select, options: ["admin", "user"], width: 15),
      Element.new(:box, [id: :plain_box, width: 10, height: 3], [
        Element.new(:input, id: :nested_input, value: "", width: 10)
      ])
    ])
  end

  describe "from_tree/1" do
    test "collects focusable element ids" do
      focus = Focus.from_tree(sample_tree())
      assert :name_input in focus.focusable_ids
      assert :submit_btn in focus.focusable_ids
      assert :role_select in focus.focusable_ids
      assert :nested_input in focus.focusable_ids
    end

    test "non-focusable elements excluded" do
      focus = Focus.from_tree(sample_tree())
      refute :label in focus.focusable_ids
      refute :plain_box in focus.focusable_ids
      refute :root in focus.focusable_ids
    end

    test "initial focus is nil" do
      focus = Focus.from_tree(sample_tree())
      assert focus.focused_id == nil
    end

    test "preserves document order" do
      focus = Focus.from_tree(sample_tree())
      assert focus.focus_order == [:name_input, :submit_btn, :role_select, :nested_input]
    end
  end

  describe "focus/2" do
    test "sets focus to a valid id" do
      focus = Focus.from_tree(sample_tree()) |> Focus.focus(:name_input)
      assert focus.focused_id == :name_input
    end

    test "ignores focus on non-focusable id" do
      focus = Focus.from_tree(sample_tree()) |> Focus.focus(:label)
      assert focus.focused_id == nil
    end
  end

  describe "blur/1" do
    test "clears focus" do
      focus =
        Focus.from_tree(sample_tree())
        |> Focus.focus(:name_input)
        |> Focus.blur()

      assert focus.focused_id == nil
    end
  end

  describe "focus_next/1" do
    test "focuses first element when nothing focused" do
      focus = Focus.from_tree(sample_tree()) |> Focus.focus_next()
      assert focus.focused_id == :name_input
    end

    test "advances to next element" do
      focus =
        Focus.from_tree(sample_tree())
        |> Focus.focus(:name_input)
        |> Focus.focus_next()

      assert focus.focused_id == :submit_btn
    end

    test "wraps around at the end" do
      focus =
        Focus.from_tree(sample_tree())
        |> Focus.focus(:nested_input)
        |> Focus.focus_next()

      assert focus.focused_id == :name_input
    end

    test "full cycle returns to start" do
      focus = Focus.from_tree(sample_tree())

      # 4 focusable elements, first call moves from nil -> first, so 5 calls to cycle
      focus =
        focus
        |> Focus.focus_next()
        |> Focus.focus_next()
        |> Focus.focus_next()
        |> Focus.focus_next()
        |> Focus.focus_next()

      assert focus.focused_id == :name_input
    end
  end

  describe "focus_prev/1" do
    test "focuses last element when nothing focused" do
      focus = Focus.from_tree(sample_tree()) |> Focus.focus_prev()
      assert focus.focused_id == :nested_input
    end

    test "moves to previous element" do
      focus =
        Focus.from_tree(sample_tree())
        |> Focus.focus(:submit_btn)
        |> Focus.focus_prev()

      assert focus.focused_id == :name_input
    end

    test "wraps around at the beginning" do
      focus =
        Focus.from_tree(sample_tree())
        |> Focus.focus(:name_input)
        |> Focus.focus_prev()

      assert focus.focused_id == :nested_input
    end
  end

  describe "resolve_focus_target/2" do
    test "returns id of focusable element hit directly" do
      tree = sample_tree()
      assert Focus.resolve_focus_target(tree, :name_input) == :name_input
    end

    test "walks up to find focusable parent" do
      # nested_input is inside plain_box. If we click plain_box,
      # there's no focusable ancestor (plain_box is not focusable).
      tree = sample_tree()
      assert Focus.resolve_focus_target(tree, :plain_box) == nil
    end

    test "returns nil for non-focusable with no focusable ancestor" do
      tree = sample_tree()
      assert Focus.resolve_focus_target(tree, :label) == nil
    end

    test "returns nil for unknown id" do
      tree = sample_tree()
      assert Focus.resolve_focus_target(tree, :nonexistent) == nil
    end
  end

  describe "update_tree/2" do
    test "keeps focus if element still exists" do
      focus = Focus.from_tree(sample_tree()) |> Focus.focus(:name_input)
      updated = Focus.update_tree(focus, sample_tree())
      assert updated.focused_id == :name_input
    end

    test "clears focus if element removed" do
      focus = Focus.from_tree(sample_tree()) |> Focus.focus(:name_input)

      new_tree =
        Element.new(:box, [id: :root, width: 40, height: 10], [
          Element.new(:button, id: :submit_btn, content: "Submit", width: 10)
        ])

      updated = Focus.update_tree(focus, new_tree)
      assert updated.focused_id == nil
      assert updated.focusable_ids == [:submit_btn]
    end
  end

  describe "empty tree" do
    test "handles tree with no focusable elements" do
      tree =
        Element.new(:box, [id: :root, width: 40, height: 10], [
          Element.new(:text, id: :label, content: "Static")
        ])

      focus = Focus.from_tree(tree)
      assert focus.focusable_ids == []
      assert Focus.focus_next(focus).focused_id == nil
      assert Focus.focus_prev(focus).focused_id == nil
    end
  end
end
