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

  # --- Backward compatibility ---

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

  # --- Basic row wrapping ---

  describe "flex_wrap: :wrap with row direction" do
    test "two children fit, third wraps to second line" do
      tree =
        Element.new(:box, [id: :root, width: 50, height: 24, flex_direction: :row, flex_wrap: :wrap], [
          Element.new(:box, id: :a, width: 20, height: 5),
          Element.new(:box, id: :b, width: 20, height: 8),
          Element.new(:box, id: :c, width: 20, height: 6)
        ])

      results = layout(tree, 50, 24)

      # Line 1: :a (w=20) + :b (w=20) = 40, fits in 50
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).x == 20
      assert rect_for(results, :b).y == 0

      # Line 2: :c wraps (20+20+20 = 60 > 50)
      assert rect_for(results, :c).x == 0
      # Line 1 cross = max(5, 8) = 8, so line 2 starts at y=8
      assert rect_for(results, :c).y == 8
    end

    test "all children fit on one line" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row, flex_wrap: :wrap], [
          Element.new(:box, id: :a, width: 20, height: 10),
          Element.new(:box, id: :b, width: 20, height: 10),
          Element.new(:box, id: :c, width: 20, height: 10)
        ])

      results = layout(tree)
      # All fit: same as no-wrap
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :b).x == 20
      assert rect_for(results, :c).x == 40
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 0
      assert rect_for(results, :c).y == 0
    end

    test "each child on its own line when container is narrow" do
      tree =
        Element.new(:box, [id: :root, width: 15, height: 30, flex_direction: :row, flex_wrap: :wrap], [
          Element.new(:box, id: :a, width: 20, height: 4),
          Element.new(:box, id: :b, width: 20, height: 6),
          Element.new(:box, id: :c, width: 20, height: 3)
        ])

      results = layout(tree, 15, 30)

      # Each child is wider than container, so each gets its own line
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).x == 0
      assert rect_for(results, :b).y == 4
      assert rect_for(results, :c).x == 0
      assert rect_for(results, :c).y == 10
    end
  end

  # --- Column wrapping ---

  describe "flex_wrap: :wrap with column direction" do
    test "children wrap to next column" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 20, flex_direction: :column, flex_wrap: :wrap], [
          Element.new(:box, id: :a, width: 15, height: 8),
          Element.new(:box, id: :b, width: 20, height: 8),
          Element.new(:box, id: :c, width: 10, height: 8)
        ])

      results = layout(tree, 80, 20)

      # Line 1: :a (h=8) + :b (h=8) = 16, fits in 20
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).x == 0
      assert rect_for(results, :b).y == 8

      # Line 2: :c wraps (8+8+8 = 24 > 20)
      # Line 1 cross = max(15, 20) = 20, so line 2 starts at x=20
      assert rect_for(results, :c).x == 20
      assert rect_for(results, :c).y == 0
    end
  end

  # --- Line cross sizes ---

  describe "line cross sizes" do
    test "line height is max of children heights in that line" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 50, height: 30, flex_direction: :row, flex_wrap: :wrap, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 20, height: 3),
            Element.new(:box, id: :b, width: 20, height: 7),
            Element.new(:box, id: :c, width: 20, height: 4)
          ]
        )

      results = layout(tree, 50, 30)

      # Line 1: :a(h=3) + :b(h=7), line cross = 7
      # Line 2: :c starts at y=7
      assert rect_for(results, :c).y == 7
    end

    test "stretch applies within line cross size, not full container" do
      # Use text elements (intrinsic h=1) alongside boxes with explicit heights.
      # Text has :auto height, so stretch can expand it.
      # Boxes with explicit height set the line cross but aren't expanded.
      tree =
        Element.new(
          :box,
          [id: :root, width: 50, height: 30, flex_direction: :row, flex_wrap: :wrap, align_items: :stretch],
          [
            Element.new(:text, id: :a, width: 20, content: "hi"),
            Element.new(:box, id: :b, width: 20, height: 7),
            Element.new(:text, id: :c, width: 20, content: "lo")
          ]
        )

      results = layout(tree, 50, 30)

      # Line 1: text_a(intrinsic_cross=1) + box_b(intrinsic_cross=7), line cross = 7
      # text_a should stretch to line cross = 7, not full container h = 30
      assert rect_for(results, :a).h == 7
      assert rect_for(results, :b).h == 7

      # Line 2: text_c alone, intrinsic_cross = 1, line cross = 1
      # text_c stretches to its own line cross = 1
      assert rect_for(results, :c).h == 1
      assert rect_for(results, :c).y == 7
    end
  end

  # --- Flex grow/shrink per line ---

  describe "flex grow/shrink per line" do
    test "flex_grow distributes within each line independently" do
      # Use auto-width boxes (intrinsic_main=0 in row mode) with flex_grow
      # alongside a fixed-width box that forces wrapping
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

      # Line splitting: a(30)+b(0)=30 ≤ 55, then +c(30)=60 > 55 → wraps
      # Line 1: [a(30), b(0, grow=1)], remaining = 25, b grows to 25
      # Line 2: [c(30), d(0, grow=1)], remaining = 25, d grows to 25
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

      # Line 1: :a(20) fits in 30
      # Line 2: :b(20) fits in 30
      # Both should be on separate lines since 20+20=40 > 30
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 5
    end
  end

  # --- Gap with wrapping ---

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

      # Both fit on one line: 20 + 5 + 20 = 45 ≤ 60
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

      # Without gap: 20+20+20 = 60 > 45 → wraps after 2nd
      # With gap=10: 20 + 10 + 20 = 50 > 45 → wraps after 1st!
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 5
    end

    test "no cross-axis gap between lines" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 30, height: 24, flex_direction: :row, flex_wrap: :wrap, gap: 5, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 20, height: 4),
            Element.new(:box, id: :b, width: 20, height: 6)
          ]
        )

      results = layout(tree, 30, 24)

      # Line 1: :a(20) fits in 30
      # Line 2: :b wraps (20+5+20=45 > 30), starts at y = line1_cross = 4
      # No cross-axis gap between lines
      assert rect_for(results, :b).y == 4
    end
  end

  # --- Justify content with wrapping ---

  describe "justify_content with wrapping" do
    test "center within each line" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 50, height: 24, flex_direction: :row, flex_wrap: :wrap, justify_content: :center],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 5),
            Element.new(:box, id: :c, width: 20, height: 5)
          ]
        )

      results = layout(tree, 50, 24)

      # Line 1: :a(20) + :b(20) = 40, free = 10, centered → offset = 5
      assert rect_for(results, :a).x == 5
      assert rect_for(results, :b).x == 25

      # Line 2: :c(20), free = 30, centered → offset = 15
      assert rect_for(results, :c).x == 15
      assert rect_for(results, :c).y == 5
    end

    test "space_between within each line" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 60, height: 24, flex_direction: :row, flex_wrap: :wrap, justify_content: :space_between],
          [
            Element.new(:box, id: :a, width: 10, height: 5),
            Element.new(:box, id: :b, width: 10, height: 5),
            Element.new(:box, id: :c, width: 10, height: 5)
          ]
        )

      results = layout(tree, 60, 24)

      # All 3 fit: 10+10+10 = 30 ≤ 60, free = 30, between = 15
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :b).x == 25
      assert rect_for(results, :c).x == 50
    end
  end

  # --- Align items with wrapping ---

  describe "align_items with wrapping" do
    test "center within each line" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 50, height: 30, flex_direction: :row, flex_wrap: :wrap, align_items: :center],
          [
            Element.new(:box, id: :a, width: 20, height: 2),
            Element.new(:box, id: :b, width: 20, height: 8),
            Element.new(:box, id: :c, width: 20, height: 4)
          ]
        )

      results = layout(tree, 50, 30)

      # Line 1: :a(h=2) + :b(h=8), line cross = 8
      # :a centered: (8 - 2) / 2 = 3
      assert rect_for(results, :a).y == 3
      assert rect_for(results, :b).y == 0
    end

    test "flex_end within each line" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 50, height: 30, flex_direction: :row, flex_wrap: :wrap, align_items: :flex_end],
          [
            Element.new(:box, id: :a, width: 20, height: 2),
            Element.new(:box, id: :b, width: 20, height: 8),
            Element.new(:box, id: :c, width: 20, height: 3)
          ]
        )

      results = layout(tree, 50, 30)

      # Line 1 cross = 8
      # :a flex_end: y = 8 - 2 = 6
      assert rect_for(results, :a).y == 6
      assert rect_for(results, :b).y == 0

      # Line 2 cross = 3, starts at y=8
      # :c flex_end within its line: y = 8 + (3 - 3) = 8
      assert rect_for(results, :c).y == 8
    end
  end

  # --- Wrap reverse ---

  describe "flex_wrap: :wrap_reverse" do
    test "row wrap_reverse: lines stack in reverse order" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 50, height: 30, flex_direction: :row, flex_wrap: :wrap_reverse, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 5),
            Element.new(:box, id: :c, width: 20, height: 3)
          ]
        )

      results = layout(tree, 50, 30)

      # Two lines: [a, b] and [c]
      # wrap_reverse: line 2 [c] is placed first (y=0), line 1 [a,b] is placed second
      # Line [c] cross = 3, so line [a,b] starts at y = 3
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
          [id: :root, width: 80, height: 20, flex_direction: :column, flex_wrap: :wrap_reverse, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 10, height: 8),
            Element.new(:box, id: :b, width: 15, height: 8),
            Element.new(:box, id: :c, width: 12, height: 8)
          ]
        )

      results = layout(tree, 80, 20)

      # Two lines: [a(h=8), b(h=8)] and [c(h=8)]
      # a+b = 16 ≤ 20, c wraps
      # wrap_reverse: line [c] placed first (x=0), line [a,b] placed second
      # Line [c] cross = 12, so line [a,b] starts at x = 12
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
          [id: :root, width: 50, height: 30, flex_direction: :row_reverse, flex_wrap: :wrap, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 20, height: 5),
            Element.new(:box, id: :b, width: 20, height: 5),
            Element.new(:box, id: :c, width: 20, height: 5)
          ]
        )

      results = layout(tree, 50, 30)

      # Line 1: [a, b] (20+20=40 ≤ 50), reversed → b at left, a at right
      # Line 2: [c], reversed → c at right
      assert rect_for(results, :a).x == 30
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).x == 10
      assert rect_for(results, :b).y == 0

      # Line 2 starts at y=5 (line 1 cross = 5)
      assert rect_for(results, :c).x == 30
      assert rect_for(results, :c).y == 5
    end
  end

  # --- Auto-sizing ---

  describe "auto-sizing with wrap" do
    test "auto height with row wrap: sum of line cross sizes" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 50, flex_direction: :row, flex_wrap: :wrap, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 30, height: 5),
            Element.new(:box, id: :b, width: 30, height: 8),
            Element.new(:box, id: :c, width: 30, height: 4)
          ]
        )

      results = layout(tree, 50, 24)

      # Line 1: :a(30) fits, :b(30) wraps → line 1 = [a], cross = 5
      # Line 2: :b(30) fits, :c(30) wraps → line 2 = [b], cross = 8
      # Line 3: :c alone → cross = 4
      # Wait, 30 + 30 = 60 > 50, so each pair overflows
      # Actually: a=30 ≤ 50, b: 30+30=60 > 50 → wraps
      # So line 1 = [a], line 2 = [b], line 3 = [c]
      # auto height = 5 + 8 + 4 = 17
      root = rect_for(results, :root)
      assert root.h == 17
    end

    test "auto width with column wrap: sum of line cross sizes" do
      tree =
        Element.new(
          :box,
          [id: :root, height: 15, flex_direction: :column, flex_wrap: :wrap, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 10, height: 8),
            Element.new(:box, id: :b, width: 15, height: 8),
            Element.new(:box, id: :c, width: 12, height: 8)
          ]
        )

      results = layout(tree, 80, 15)

      # Line 1: :a(h=8) fits, :b(h=8): 8+8=16 > 15 → wraps
      # Line 1 = [a] cross=10, Line 2 = [b] cross=15, Line 3 = [c] cross=12
      # auto width = 10 + 15 + 12 = 37
      root = rect_for(results, :root)
      assert root.w == 37
    end
  end

  # --- Edge cases ---

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
          [id: :root, width: 30, height: 24, flex_direction: :row, flex_wrap: :wrap, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 10, height: 5),
            Element.new(:box, id: :b, width: 50, height: 5),
            Element.new(:box, id: :c, width: 10, height: 5)
          ]
        )

      results = layout(tree, 30, 24)

      # :a fits on line 1 (10 ≤ 30)
      # :b overflows: 10 + 50 = 60 > 30, wraps to line 2 (alone, overflows but still placed)
      # :c: 50 + 10 = 60 > 30, wraps to line 3
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
          [id: :root, width: 50, height: 24, flex_direction: :row, flex_wrap: :wrap, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 20, height: 5, margin: 3),
            Element.new(:box, id: :b, width: 20, height: 5)
          ]
        )

      results = layout(tree, 50, 24)

      # :a intrinsic_main = 20 + 3 + 3 = 26
      # :b intrinsic_main = 20
      # Total: 26 + 20 = 46 ≤ 50, fits on one line
      # :a has margin_top=3, so y offset = 3 (flex_start returns margin_before)
      assert rect_for(results, :a).y == 3
      assert rect_for(results, :b).y == 0

      # With narrower container it would wrap
      tree2 =
        Element.new(
          :box,
          [id: :root, width: 40, height: 24, flex_direction: :row, flex_wrap: :wrap, align_items: :flex_start],
          [
            Element.new(:box, id: :a2, width: 20, height: 5, margin: 3),
            Element.new(:box, id: :b2, width: 20, height: 5)
          ]
        )

      results2 = layout(tree2, 40, 24)

      # :a2 intrinsic_main = 26, :b2 = 20, total = 46 > 40 → wraps
      # :a2 has margin_top=3
      assert rect_for(results2, :a2).y == 3
      # line 1 cross includes margin: max cross = 5 + 3 + 3 = 11
      assert rect_for(results2, :b2).y == 11
    end

    test "border + padding + wrap" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 40, height: 24, flex_direction: :row, flex_wrap: :wrap,
           border: true, padding: 1, align_items: :flex_start],
          [
            Element.new(:box, id: :a, width: 15, height: 4),
            Element.new(:box, id: :b, width: 15, height: 4),
            Element.new(:box, id: :c, width: 15, height: 4)
          ]
        )

      results = layout(tree, 40, 24)

      # Inner space: 40 - 2*(1+1) = 36 (border=1, padding=1 each side)
      # :a(15) + :b(15) = 30 ≤ 36, fits
      # :c(15): 30+15=45 > 36, wraps
      # Base offset: border(1) + padding(1) = 2
      assert rect_for(results, :a).x == 2
      assert rect_for(results, :a).y == 2
      assert rect_for(results, :b).x == 17
      assert rect_for(results, :b).y == 2
      assert rect_for(results, :c).x == 2
      assert rect_for(results, :c).y == 6
    end
  end
end
