defmodule ElixirOpentui.ElementTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Element
  alias ElixirOpentui.Style

  describe "new/3" do
    test "creates element with type and defaults" do
      el = Element.new(:box)
      assert el.type == :box
      assert el.children == []
      assert el.attrs == %{}
      assert %Style{} = el.style
    end

    test "separates style attrs from content attrs" do
      el = Element.new(:text, content: "Hello", fg: {255, 0, 0, 255}, flex_grow: 1)
      assert el.attrs == %{content: "Hello"}
      assert el.style.fg == {255, 0, 0, 255}
      assert el.style.flex_grow == 1
    end

    test "extracts id and key" do
      el = Element.new(:box, id: :my_box, key: "k1")
      assert el.id == :my_box
      assert el.key == "k1"
    end

    test "flattens and rejects nil children" do
      child1 = Element.new(:text, content: "A")
      child2 = Element.new(:text, content: "B")
      el = Element.new(:box, [], [child1, nil, [child2, nil]])
      assert length(el.children) == 2
    end
  end

  describe "count/1" do
    test "single node" do
      assert Element.count(Element.new(:box)) == 1
    end

    test "nested tree" do
      tree =
        Element.new(:box, [], [
          Element.new(:text, content: "A"),
          Element.new(:box, [], [
            Element.new(:text, content: "B"),
            Element.new(:text, content: "C")
          ])
        ])

      assert Element.count(tree) == 5
    end
  end

  describe "find_by_id/2" do
    test "finds root by id" do
      el = Element.new(:box, id: :root)
      assert Element.find_by_id(el, :root) == el
    end

    test "finds nested child" do
      child = Element.new(:text, id: :target, content: "Found")

      tree =
        Element.new(:box, [], [
          Element.new(:box, [], [child])
        ])

      found = Element.find_by_id(tree, :target)
      assert found.id == :target
      assert found.attrs.content == "Found"
    end

    test "returns nil when not found" do
      tree = Element.new(:box, id: :root)
      assert Element.find_by_id(tree, :nonexistent) == nil
    end
  end

  describe "map/2" do
    test "transforms all nodes" do
      tree =
        Element.new(:box, [], [
          Element.new(:text, content: "A"),
          Element.new(:text, content: "B")
        ])

      mapped =
        Element.map(tree, fn el ->
          if el.type == :text do
            %{el | attrs: Map.update(el.attrs, :content, "", &(&1 <> "!"))}
          else
            el
          end
        end)

      [c1, c2] = mapped.children
      assert c1.attrs.content == "A!"
      assert c2.attrs.content == "B!"
    end
  end

  describe "reduce/3" do
    test "collects all content" do
      tree =
        Element.new(:box, [], [
          Element.new(:text, content: "A"),
          Element.new(:text, content: "B")
        ])

      texts =
        Element.reduce(tree, [], fn el, acc ->
          case Map.get(el.attrs, :content) do
            nil -> acc
            text -> acc ++ [text]
          end
        end)

      assert texts == ["A", "B"]
    end
  end
end
