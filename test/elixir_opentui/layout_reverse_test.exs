defmodule ElixirOpentui.LayoutReverseTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Element
  alias ElixirOpentui.Layout

  defp layout(tree, w \\ 80, h \\ 24) do
    {_tagged, results} = Layout.compute(tree, w, h)
    results
  end

  defp rect_for(results, id) do
    Map.get(results, id)
  end

  describe "flex_direction: :row_reverse" do
    test "children positioned right-to-left" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row_reverse], [
          Element.new(:box, id: :a, width: 20, height: 10),
          Element.new(:box, id: :b, width: 30, height: 10)
        ])

      results = layout(tree)

      assert rect_for(results, :a).x == 60
      assert rect_for(results, :b).x == 30
    end

    test "cross axis (y) is unaffected" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row_reverse], [
          Element.new(:box, id: :child, width: 20, height: 10)
        ])

      results = layout(tree)
      assert rect_for(results, :child).y == 0
    end

    test "children stretch to full height by default" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 10, flex_direction: :row_reverse], [
          Element.new(:box, id: :child, width: 20)
        ])

      results = layout(tree)
      assert rect_for(results, :child).h == 10
    end

    test "flex_grow distributes space" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row_reverse], [
          Element.new(:box, id: :fixed, width: 20, height: 24),
          Element.new(:box, id: :grow, flex_grow: 1)
        ])

      results = layout(tree)
      assert rect_for(results, :grow).w == 60
      assert rect_for(results, :fixed).x == 60
      assert rect_for(results, :grow).x == 0
    end

    test "gap works with reversed positions" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row_reverse, gap: 10],
          [
            Element.new(:box, id: :a, width: 20, height: 10),
            Element.new(:box, id: :b, width: 20, height: 10)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :a).x == 60
      assert rect_for(results, :b).x == 30
    end

    test "justify_content: flex_start places children at the right" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :row_reverse,
            justify_content: :flex_start
          ],
          [
            Element.new(:box, id: :child, width: 20, height: 24)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).x == 60
    end

    test "justify_content: flex_end places children at the left" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :row_reverse,
            justify_content: :flex_end
          ],
          [
            Element.new(:box, id: :child, width: 20, height: 24)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).x == 0
    end

    test "justify_content: center keeps children centered" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :row_reverse,
            justify_content: :center
          ],
          [
            Element.new(:box, id: :child, width: 20, height: 24)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).x == 30
    end

    test "justify_content: space_between with reversed order" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :row_reverse,
            justify_content: :space_between
          ],
          [
            Element.new(:box, id: :a, width: 10, height: 24),
            Element.new(:box, id: :b, width: 10, height: 24),
            Element.new(:box, id: :c, width: 10, height: 24)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :a).x == 70
      assert rect_for(results, :c).x == 0
    end

    test "three children positioned right-to-left" do
      tree =
        Element.new(:box, [id: :root, width: 60, height: 24, flex_direction: :row_reverse], [
          Element.new(:box, id: :a, width: 10, height: 10),
          Element.new(:box, id: :b, width: 20, height: 10),
          Element.new(:box, id: :c, width: 10, height: 10)
        ])

      results = layout(tree)
      assert rect_for(results, :a).x == 50
      assert rect_for(results, :b).x == 30
      assert rect_for(results, :c).x == 20

      assert rect_for(results, :a).w == 10
      assert rect_for(results, :b).w == 20
      assert rect_for(results, :c).w == 10
    end

    test "asymmetric horizontal margins are mirrored correctly" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row_reverse], [
          Element.new(:box, id: :child, width: 20, height: 10, margin: {0, 8, 0, 2})
        ])

      results = layout(tree)

      assert rect_for(results, :child).x == 52
    end

    test "multiple children with different asymmetric margins in row_reverse" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row_reverse], [
          Element.new(:box, id: :a, width: 10, height: 10, margin: {0, 5, 0, 1}),
          Element.new(:box, id: :b, width: 10, height: 10, margin: {0, 3, 0, 7})
        ])

      results = layout(tree)

      assert rect_for(results, :a).x == 65
      assert rect_for(results, :b).x == 51
    end
  end

  describe "flex_direction: :column_reverse" do
    test "children positioned bottom-to-top" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24], [
          Element.new(
            :box,
            [id: :col_rev, width: 80, height: 24, flex_direction: :column_reverse],
            [
              Element.new(:text, id: :a, content: "Line 1"),
              Element.new(:text, id: :b, content: "Line 2"),
              Element.new(:text, id: :c, content: "Line 3")
            ]
          )
        ])

      results = layout(tree)
      assert rect_for(results, :a).y == 23
      assert rect_for(results, :b).y == 22
      assert rect_for(results, :c).y == 21
    end

    test "cross axis (x) is unaffected" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :column_reverse], [
          Element.new(:box, id: :child, height: 5)
        ])

      results = layout(tree)
      assert rect_for(results, :child).x == 0
    end

    test "children stretch to full width by default" do
      tree =
        Element.new(:box, [id: :root, width: 40, height: 24, flex_direction: :column_reverse], [
          Element.new(:box, id: :child, height: 5)
        ])

      results = layout(tree)
      assert rect_for(results, :child).w == 40
    end

    test "flex_grow distributes space" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :column_reverse], [
          Element.new(:box, id: :fixed, width: 80, height: 4),
          Element.new(:box, id: :grow, flex_grow: 1)
        ])

      results = layout(tree)
      assert rect_for(results, :grow).h == 20
      assert rect_for(results, :fixed).y == 20
      assert rect_for(results, :grow).y == 0
    end

    test "justify_content: flex_start places children at the bottom" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :column_reverse,
            justify_content: :flex_start
          ],
          [
            Element.new(:box, id: :child, width: 80, height: 4)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).y == 20
    end

    test "justify_content: flex_end places children at the top" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :column_reverse,
            justify_content: :flex_end
          ],
          [
            Element.new(:box, id: :child, width: 80, height: 4)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).y == 0
    end

    test "justify_content: center keeps children centered" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :column_reverse,
            justify_content: :center
          ],
          [
            Element.new(:box, id: :child, width: 80, height: 4)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).y == 10
    end

    test "asymmetric vertical margins are mirrored correctly" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :column_reverse], [
          Element.new(:box, id: :child, width: 20, height: 4, margin: {3, 0, 7, 0})
        ])

      results = layout(tree)

      assert rect_for(results, :child).y == 13
    end

    test "gap works with reversed positions" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :column_reverse, gap: 2],
          [
            Element.new(:box, id: :a, width: 80, height: 4),
            Element.new(:box, id: :b, width: 80, height: 4)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :a).y == 20
      assert rect_for(results, :b).y == 14
    end
  end

  describe "edge cases" do
    test "single child with row_reverse" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row_reverse], [
          Element.new(:box, id: :child, width: 80, height: 24)
        ])

      results = layout(tree)
      assert rect_for(results, :child).x == 0
    end

    test "empty container with row_reverse" do
      tree = Element.new(:box, id: :root, width: 80, height: 24, flex_direction: :row_reverse)
      results = layout(tree)
      assert rect_for(results, :root).w == 80
    end

    test "empty container with column_reverse" do
      tree = Element.new(:box, id: :root, width: 80, height: 24, flex_direction: :column_reverse)
      results = layout(tree)
      assert rect_for(results, :root).h == 24
    end

    test "nested containers with different directions" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row_reverse], [
          Element.new(
            :box,
            [id: :left, width: 40, height: 24, flex_direction: :column],
            [
              Element.new(:text, id: :top_text, content: "Hello"),
              Element.new(:text, id: :bottom_text, content: "World")
            ]
          ),
          Element.new(:box, id: :right, width: 40, height: 24)
        ])

      results = layout(tree)
      assert rect_for(results, :left).x == 40
      assert rect_for(results, :right).x == 0

      assert rect_for(results, :top_text).y == 0
      assert rect_for(results, :bottom_text).y == 1
      assert rect_for(results, :top_text).x == 40
    end
  end
end
