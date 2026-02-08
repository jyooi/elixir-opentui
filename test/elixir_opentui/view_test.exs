defmodule ElixirOpentui.ViewTest do
  use ExUnit.Case, async: true

  import ElixirOpentui.View
  alias ElixirOpentui.Element

  describe "basic DSL macros" do
    test "box creates box element" do
      el = box()
      assert %Element{type: :box} = el
    end

    test "text creates text element" do
      el = text(content: "Hello")
      assert el.type == :text
      assert el.attrs.content == "Hello"
    end

    test "label creates label element" do
      el = label(content: "Status: OK")
      assert el.type == :label
      assert el.attrs.content == "Status: OK"
    end

    test "panel creates panel element" do
      el = panel(title: "Info", border: true)
      assert el.type == :panel
      assert el.attrs.title == "Info"
      assert el.style.border == true
    end

    test "button creates button element" do
      el = button(content: "Click me", id: :btn)
      assert el.type == :button
      assert el.id == :btn
    end

    test "input creates input element" do
      el = input(id: :username, value: "", placeholder: "Enter name")
      assert el.type == :input
      assert el.id == :username
      assert el.attrs.placeholder == "Enter name"
    end

    test "select creates select element" do
      el = select(id: :role, options: ["admin", "user"])
      assert el.type == :select
      assert el.attrs.options == ["admin", "user"]
    end
  end

  describe "nesting with do blocks" do
    test "single child" do
      el =
        box do
          text(content: "Hello")
        end

      assert el.type == :box
      assert length(el.children) == 1
      assert hd(el.children).type == :text
    end

    test "multiple children" do
      el =
        box do
          text(content: "A")
          text(content: "B")
          text(content: "C")
        end

      assert length(el.children) == 3
    end

    test "nested boxes" do
      el =
        box do
          box direction: :row do
            text(content: "Left")
            text(content: "Right")
          end
        end

      assert length(el.children) == 1
      inner = hd(el.children)
      assert inner.type == :box
      assert inner.style.flex_direction == :row
      assert length(inner.children) == 2
    end

    test "deeply nested structure" do
      el =
        view do
          panel title: "App", border: true do
            box direction: :row, gap: 2 do
              label(content: "Name:")
              input(id: :name, value: "", placeholder: "Enter name")
            end

            box direction: :row, gap: 2 do
              button(content: "Submit", id: :submit)
              button(content: "Cancel", id: :cancel)
            end
          end
        end

      assert el.type == :box
      panel = hd(el.children)
      assert panel.type == :panel
      assert length(panel.children) == 2
    end
  end

  describe "style props in DSL" do
    test "flex properties" do
      el =
        box flex_grow: 1, flex_shrink: 0, flex_direction: :row do
          text(content: "Flexible")
        end

      assert el.style.flex_grow == 1
      assert el.style.flex_shrink == 0
      assert el.style.flex_direction == :row
    end

    test "dimensions" do
      el =
        box width: 40, height: 10 do
          text(content: "Sized")
        end

      assert el.style.width == 40
      assert el.style.height == 10
    end

    test "padding and gap" do
      el =
        box padding: 2, gap: 1 do
          text(content: "Padded")
        end

      assert el.style.padding == {2, 2, 2, 2}
      assert el.style.gap == 1
    end
  end
end
