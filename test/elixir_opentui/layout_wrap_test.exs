defmodule ElixirOpentui.LayoutWrapTest do
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

  describe "backward compatibility" do
    test "no_wrap is the default" do
      assert %ElixirOpentui.Style{}.flex_wrap == :no_wrap
    end

    test "no_wrap row behaves identically to before" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row], [
          Element.new(:box, id: :a, width: 20, height: 10),
          Element.new(:box, id: :b, width: 30, height: 10),
          Element.new(:box, id: :c, width: 10, height: 10)
        ])

      results = layout(tree)
      assert rect_for(results, :a) == %Layout.Rect{x: 0, y: 0, w: 20, h: 10}
      assert rect_for(results, :b) == %Layout.Rect{x: 20, y: 0, w: 30, h: 10}
      assert rect_for(results, :c) == %Layout.Rect{x: 50, y: 0, w: 10, h: 10}
    end
  end

  describe "flex_wrap: :wrap with row direction" do
    test "two children fit, third wraps to second line" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 50, height: 24, flex_direction: :row, flex_wrap: :wrap],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 8),
            Element.new(:box, id: :c, width: 20, height: 6)
          ]
        )

      results = layout(tree, 50, 24)

      assert rect_for(results, :a).x == 0
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).x == 20
      assert rect_for(results, :b).y == 0

      assert rect_for(results, :c).x == 0
      assert rect_for(results, :c).y == 8
    end

    test "all children fit on one line" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, flex_wrap: :wrap],
          [
            Element.new(:box, id: :a, width: 20, height: 10),
            Element.new(:box, id: :b, width: 20, height: 10),
            Element.new(:box, id: :c, width: 20, height: 10)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :b).x == 20
      assert rect_for(results, :c).x == 40
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 0
      assert rect_for(results, :c).y == 0
    end

    test "each child on its own line when container is narrow" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 15, height: 30, flex_direction: :row, flex_wrap: :wrap],
          [
            Element.new(:box, id: :a, width: 20, height: 4),
            Element.new(:box, id: :b, width: 20, height: 6),
            Element.new(:box, id: :c, width: 20, height: 3)
          ]
        )

      results = layout(tree, 15, 30)

      assert rect_for(results, :a).x == 0
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).x == 0
      assert rect_for(results, :b).y == 4
      assert rect_for(results, :c).x == 0
      assert rect_for(results, :c).y == 10
    end
  end

  describe "flex_wrap: :wrap with column direction" do
    test "children wrap to next column" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 20, flex_direction: :column, flex_wrap: :wrap],
          [
            Element.new(:box, id: :a, width: 15, height: 8),
            Element.new(:box, id: :b, width: 20, height: 8),
            Element.new(:box, id: :c, width: 10, height: 8)
          ]
        )

      results = layout(tree, 80, 20)

      assert rect_for(results, :a).x == 0
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).x == 0
      assert rect_for(results, :b).y == 8

      assert rect_for(results, :c).x == 20
      assert rect_for(results, :c).y == 0
    end
  end

  describe "line cross sizes" do
    test "line height is max of children heights in that line" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 50,
            height: 30,
            flex_direction: :row,
            flex_wrap: :wrap,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 20, height: 3),
            Element.new(:box, id: :b, width: 20, height: 7),
            Element.new(:box, id: :c, width: 20, height: 4)
          ]
        )

      results = layout(tree, 50, 30)

      assert rect_for(results, :c).y == 7
    end

    test "stretch applies within line cross size, not full container" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 50,
            height: 30,
            flex_direction: :row,
            flex_wrap: :wrap,
            align_items: :stretch
          ],
          [
            Element.new(:text, id: :a, width: 20, content: "hi"),
            Element.new(:box, id: :b, width: 20, height: 7),
            Element.new(:text, id: :c, width: 20, content: "lo")
          ]
        )

      results = layout(tree, 50, 30)

      assert rect_for(results, :a).h == 7
      assert rect_for(results, :b).h == 7

      assert rect_for(results, :c).h == 1
      assert rect_for(results, :c).y == 7
    end
  end

  describe "flex grow/shrink per line" do
    test "flex_grow distributes within each line independently" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 55, height: 24, flex_direction: :row, flex_wrap: :wrap],
          [
            Element.new(:box, id: :a, width: 30, height: 5),
            Element.new(:box, id: :b, height: 5, flex_grow: 1),
            Element.new(:box, id: :c, width: 30, height: 5),
            Element.new(:box, id: :d, height: 5, flex_grow: 1)
          ]
        )

      results = layout(tree, 55, 24)

      assert rect_for(results, :a).w == 30
      assert rect_for(results, :b).w == 25

      assert rect_for(results, :c).y == 5
      assert rect_for(results, :c).w == 30
      assert rect_for(results, :d).w == 25
    end

    test "flex_shrink applies per line" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 30, height: 40, flex_direction: :row, flex_wrap: :wrap],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 5)
          ]
        )

      results = layout(tree, 30, 40)

      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 5
    end
  end

  describe "gap with wrapping" do
    test "gap applied between children on same line" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 60, height: 24, flex_direction: :row, flex_wrap: :wrap, gap: 5],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 5)
          ]
        )

      results = layout(tree, 60, 24)

      assert rect_for(results, :a).x == 0
      assert rect_for(results, :b).x == 25
    end

    test "gap affects line splitting" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 45, height: 24, flex_direction: :row, flex_wrap: :wrap, gap: 10],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 5),
            Element.new(:box, id: :c, width: 20, height: 5)
          ]
        )

      results = layout(tree, 45, 24)

      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 5
    end

    test "no cross-axis gap between lines" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 30,
            height: 24,
            flex_direction: :row,
            flex_wrap: :wrap,
            gap: 5,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 20, height: 4),
            Element.new(:box, id: :b, width: 20, height: 6)
          ]
        )

      results = layout(tree, 30, 24)

      assert rect_for(results, :b).y == 4
    end
  end

  describe "justify_content with wrapping" do
    test "center within each line" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 50,
            height: 24,
            flex_direction: :row,
            flex_wrap: :wrap,
            justify_content: :center
          ],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 5),
            Element.new(:box, id: :c, width: 20, height: 5)
          ]
        )

      results = layout(tree, 50, 24)

      assert rect_for(results, :a).x == 5
      assert rect_for(results, :b).x == 25

      assert rect_for(results, :c).x == 15
      assert rect_for(results, :c).y == 5
    end

    test "space_between within each line" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 60,
            height: 24,
            flex_direction: :row,
            flex_wrap: :wrap,
            justify_content: :space_between
          ],
          [
            Element.new(:box, id: :a, width: 10, height: 5),
            Element.new(:box, id: :b, width: 10, height: 5),
            Element.new(:box, id: :c, width: 10, height: 5)
          ]
        )

      results = layout(tree, 60, 24)

      assert rect_for(results, :a).x == 0
      assert rect_for(results, :b).x == 25
      assert rect_for(results, :c).x == 50
    end
  end

  describe "align_items with wrapping" do
    test "center within each line" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 50,
            height: 30,
            flex_direction: :row,
            flex_wrap: :wrap,
            align_items: :center
          ],
          [
            Element.new(:box, id: :a, width: 20, height: 2),
            Element.new(:box, id: :b, width: 20, height: 8),
            Element.new(:box, id: :c, width: 20, height: 4)
          ]
        )

      results = layout(tree, 50, 30)

      assert rect_for(results, :a).y == 3
      assert rect_for(results, :b).y == 0
    end

    test "flex_end within each line" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 50,
            height: 30,
            flex_direction: :row,
            flex_wrap: :wrap,
            align_items: :flex_end
          ],
          [
            Element.new(:box, id: :a, width: 20, height: 2),
            Element.new(:box, id: :b, width: 20, height: 8),
            Element.new(:box, id: :c, width: 20, height: 3)
          ]
        )

      results = layout(tree, 50, 30)

      assert rect_for(results, :a).y == 6
      assert rect_for(results, :b).y == 0

      assert rect_for(results, :c).y == 8
    end
  end

  describe "flex_wrap: :wrap_reverse" do
    test "row wrap_reverse: lines stack in reverse order" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 50,
            height: 30,
            flex_direction: :row,
            flex_wrap: :wrap_reverse,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 5),
            Element.new(:box, id: :c, width: 20, height: 3)
          ]
        )

      results = layout(tree, 50, 30)

      assert rect_for(results, :c).y == 0
      assert rect_for(results, :c).x == 0
      assert rect_for(results, :a).y == 3
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :b).y == 3
      assert rect_for(results, :b).x == 20
    end

    test "column wrap_reverse: columns stack in reverse order" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 20,
            flex_direction: :column,
            flex_wrap: :wrap_reverse,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 10, height: 8),
            Element.new(:box, id: :b, width: 15, height: 8),
            Element.new(:box, id: :c, width: 12, height: 8)
          ]
        )

      results = layout(tree, 80, 20)

      assert rect_for(results, :c).x == 0
      assert rect_for(results, :c).y == 0
      assert rect_for(results, :a).x == 12
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).x == 12
      assert rect_for(results, :b).y == 8
    end

    test "row_reverse + wrap: children reversed within line, lines normal" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 50,
            height: 30,
            flex_direction: :row_reverse,
            flex_wrap: :wrap,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 5),
            Element.new(:box, id: :c, width: 20, height: 5)
          ]
        )

      results = layout(tree, 50, 30)

      assert rect_for(results, :a).x == 30
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).x == 10
      assert rect_for(results, :b).y == 0

      assert rect_for(results, :c).x == 30
      assert rect_for(results, :c).y == 5
    end
  end

  describe "auto-sizing with wrap" do
    test "auto height with row wrap: sum of line cross sizes" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 50,
            flex_direction: :row,
            flex_wrap: :wrap,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 30, height: 5),
            Element.new(:box, id: :b, width: 30, height: 8),
            Element.new(:box, id: :c, width: 30, height: 4)
          ]
        )

      results = layout(tree, 50, 24)

      root = rect_for(results, :root)
      assert root.h == 17
    end

    test "auto width with column wrap: sum of line cross sizes" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            height: 15,
            flex_direction: :column,
            flex_wrap: :wrap,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 10, height: 8),
            Element.new(:box, id: :b, width: 15, height: 8),
            Element.new(:box, id: :c, width: 12, height: 8)
          ]
        )

      results = layout(tree, 80, 15)

      root = rect_for(results, :root)
      assert root.w == 37
    end
  end

  describe "edge cases" do
    test "single child with wrap" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, flex_wrap: :wrap],
          [
            Element.new(:box, id: :a, width: 20, height: 10)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :a).y == 0
    end

    test "empty container with wrap" do
      tree = Element.new(:box, id: :root, width: 80, height: 24, flex_wrap: :wrap)
      results = layout(tree)
      assert rect_for(results, :root).w == 80
      assert rect_for(results, :root).h == 24
    end

    test "child wider than container gets its own line" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 30,
            height: 24,
            flex_direction: :row,
            flex_wrap: :wrap,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 10, height: 5),
            Element.new(:box, id: :b, width: 50, height: 5),
            Element.new(:box, id: :c, width: 10, height: 5)
          ]
        )

      results = layout(tree, 30, 24)

      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 5
      assert rect_for(results, :c).y == 10
    end

    test "wrap attribute via Element.new shorthand" do
      el = Element.new(:box, wrap: :wrap)
      assert el.style.flex_wrap == :wrap
    end

    test "margin affects line splitting" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 50,
            height: 24,
            flex_direction: :row,
            flex_wrap: :wrap,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 20, height: 5, margin: 3),
            Element.new(:box, id: :b, width: 20, height: 5)
          ]
        )

      results = layout(tree, 50, 24)

      assert rect_for(results, :a).y == 3
      assert rect_for(results, :b).y == 0

      tree2 =
        Element.new(
          :box,
          [
            id: :root,
            width: 40,
            height: 24,
            flex_direction: :row,
            flex_wrap: :wrap,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a2, width: 20, height: 5, margin: 3),
            Element.new(:box, id: :b2, width: 20, height: 5)
          ]
        )

      results2 = layout(tree2, 40, 24)

      assert rect_for(results2, :a2).y == 3
      assert rect_for(results2, :b2).y == 11
    end

    test "border + padding + wrap" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 40,
            height: 24,
            flex_direction: :row,
            flex_wrap: :wrap,
            border: true,
            padding: 1,
            align_items: :flex_start
          ],
          [
            Element.new(:box, id: :a, width: 15, height: 4),
            Element.new(:box, id: :b, width: 15, height: 4),
            Element.new(:box, id: :c, width: 15, height: 4)
          ]
        )

      results = layout(tree, 40, 24)

      assert rect_for(results, :a).x == 2
      assert rect_for(results, :a).y == 2
      assert rect_for(results, :b).x == 17
      assert rect_for(results, :b).y == 2
      assert rect_for(results, :c).x == 2
      assert rect_for(results, :c).y == 6
    end
  end
end
