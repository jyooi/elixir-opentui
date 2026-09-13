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

    test "extracts id" do
      el = Element.new(:box, id: :my_box)
      assert el.id == :my_box
    end

    test "flattens and rejects nil children" do
      child1 = Element.new(:text, content: "A")
      child2 = Element.new(:text, content: "B")
      el = Element.new(:box, [], [child1, nil, [child2, nil]])
      assert length(el.children) == 2
    end
  end
end
