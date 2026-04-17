defmodule ElixirOpentui.LayoutTest do
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

  describe "basic dimensions" do
    test "root fills available space" do
      tree = Element.new(:box, id: :root, width: 80, height: 24)
      results = layout(tree)
      rect = rect_for(results, :root)
      assert rect.w == 80
      assert rect.h == 24
      assert rect.x == 0
      assert rect.y == 0
    end

    test "fixed width and height" do
      tree = Element.new(:box, id: :root, width: 40, height: 10)
      results = layout(tree, 80, 24)
      rect = rect_for(results, :root)
      assert rect.w == 40
      assert rect.h == 10
    end

    test "percentage dimensions" do
      tree = Element.new(:box, id: :root, width: {:percent, 50}, height: {:percent, 25})
      results = layout(tree, 80, 24)
      rect = rect_for(results, :root)
      assert rect.w == 40
      assert rect.h == 6
    end

    test "auto dimensions fill parent" do
      tree =
        Element.new(:box, [id: :root], [
          Element.new(:box, id: :child)
        ])

      results = layout(tree)
      child_rect = rect_for(results, :child)
      assert child_rect.w == 80
    end
  end

  describe "flex_direction: :column (default)" do
    test "children stack vertically" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24], [
          Element.new(:text, id: :a, content: "Line 1"),
          Element.new(:text, id: :b, content: "Line 2"),
          Element.new(:text, id: :c, content: "Line 3")
        ])

      results = layout(tree)

      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 1
      assert rect_for(results, :c).y == 2
    end

    test "children stretch to full width by default (align_items: :stretch)" do
      tree =
        Element.new(:box, [id: :root, width: 40, height: 10], [
          Element.new(:box, id: :child, height: 3)
        ])

      results = layout(tree)
      child_rect = rect_for(results, :child)
      assert child_rect.w == 40
    end
  end

  describe "flex_direction: :row" do
    test "children stack horizontally" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row], [
          Element.new(:box, id: :a, width: 20, height: 10),
          Element.new(:box, id: :b, width: 30, height: 10)
        ])

      results = layout(tree)

      assert rect_for(results, :a).x == 0
      assert rect_for(results, :b).x == 20
    end

    test "children stretch to full height by default" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 10, flex_direction: :row], [
          Element.new(:box, id: :child, width: 20)
        ])

      results = layout(tree)
      child_rect = rect_for(results, :child)
      assert child_rect.h == 10
    end
  end

  describe "flex_grow" do
    test "single child with flex_grow fills remaining space" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row], [
          Element.new(:box, id: :fixed, width: 20, height: 24),
          Element.new(:box, id: :grow, flex_grow: 1)
        ])

      results = layout(tree)
      grow_rect = rect_for(results, :grow)
      assert grow_rect.w == 60
    end

    test "multiple flex_grow splits remaining space" do
      tree =
        Element.new(:box, [id: :root, width: 100, height: 24, flex_direction: :row], [
          Element.new(:box, id: :a, flex_grow: 1),
          Element.new(:box, id: :b, flex_grow: 2)
        ])

      results = layout(tree)
      # flex_grow 1:2 ratio with 100 available
      assert rect_for(results, :a).w == 33
      assert rect_for(results, :b).w == 67
    end

    test "flex_grow in column direction" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24], [
          Element.new(:box, id: :fixed, height: 4),
          Element.new(:box, id: :grow, flex_grow: 1)
        ])

      results = layout(tree)
      grow_rect = rect_for(results, :grow)
      assert grow_rect.h == 20
    end
  end

  describe "gap" do
    test "gap between row children" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row, gap: 2], [
          Element.new(:box, id: :a, width: 10, height: 24),
          Element.new(:box, id: :b, width: 10, height: 24)
        ])

      results = layout(tree)
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :b).x == 12
    end

    test "gap between column children" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, gap: 1], [
          Element.new(:text, id: :a, content: "A"),
          Element.new(:text, id: :b, content: "B"),
          Element.new(:text, id: :c, content: "C")
        ])

      results = layout(tree)
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 2
      assert rect_for(results, :c).y == 4
    end
  end

  describe "padding" do
    test "padding offsets children" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, padding: 2], [
          Element.new(:text, id: :child, content: "Padded")
        ])

      results = layout(tree)
      child_rect = rect_for(results, :child)
      assert child_rect.x == 2
      assert child_rect.y == 2
    end

    test "asymmetric padding" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, padding: {1, 3, 1, 5}], [
          Element.new(:text, id: :child, content: "Offset")
        ])

      results = layout(tree)
      child_rect = rect_for(results, :child)
      assert child_rect.x == 5
      assert child_rect.y == 1
    end

    test "padding reduces available space for children" do
      tree =
        Element.new(:box, [id: :root, width: 40, height: 10, padding: 2, flex_direction: :row], [
          Element.new(:box, id: :child, flex_grow: 1)
        ])

      results = layout(tree)
      child_rect = rect_for(results, :child)
      assert child_rect.w == 36
    end
  end

  describe "justify_content" do
    test "flex_start (default)" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, justify_content: :flex_start],
          [
            Element.new(:box, id: :child, width: 20, height: 24)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).x == 0
    end

    test "flex_end" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, justify_content: :flex_end],
          [
            Element.new(:box, id: :child, width: 20, height: 24)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).x == 60
    end

    test "center" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, justify_content: :center],
          [
            Element.new(:box, id: :child, width: 20, height: 24)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).x == 30
    end

    test "space_between" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :row,
            justify_content: :space_between
          ],
          [
            Element.new(:box, id: :a, width: 10, height: 24),
            Element.new(:box, id: :b, width: 10, height: 24),
            Element.new(:box, id: :c, width: 10, height: 24)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :a).x == 0
      assert rect_for(results, :c).x == 70
    end

    test "space_around" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :row,
            justify_content: :space_around
          ],
          [
            Element.new(:box, id: :a, width: 10, height: 24),
            Element.new(:box, id: :b, width: 10, height: 24)
          ]
        )

      results = layout(tree)
      a_rect = rect_for(results, :a)
      b_rect = rect_for(results, :b)
      # space_around: equal space around each child
      # 80 - 20 = 60 free, 2 items => 30 each => half space on edges
      assert a_rect.x == 15
      assert b_rect.x == 55
    end

    test "space_evenly with multiple children" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :row,
            justify_content: :space_evenly
          ],
          [
            Element.new(:box, id: :a, width: 10, height: 24),
            Element.new(:box, id: :b, width: 10, height: 24),
            Element.new(:box, id: :c, width: 10, height: 24)
          ]
        )

      results = layout(tree)
      # 80 - 30 = 50 free, 4 gaps (count+1) => 12 each
      assert rect_for(results, :a).x == 12
      assert rect_for(results, :b).x == 34
      assert rect_for(results, :c).x == 56
    end

    test "space_evenly with single child" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            flex_direction: :row,
            justify_content: :space_evenly
          ],
          [
            Element.new(:box, id: :child, width: 20, height: 24)
          ]
        )

      results = layout(tree)
      # 80 - 20 = 60 free, 2 gaps => 30 each
      assert rect_for(results, :child).x == 30
    end

    test "space_evenly in column direction" do
      tree =
        Element.new(
          :box,
          [
            id: :root,
            width: 80,
            height: 24,
            justify_content: :space_evenly
          ],
          [
            Element.new(:box, id: :a, width: 80, height: 2),
            Element.new(:box, id: :b, width: 80, height: 2),
            Element.new(:box, id: :c, width: 80, height: 2)
          ]
        )

      results = layout(tree)
      # 24 - 6 = 18 free, 4 gaps => 4 each
      assert rect_for(results, :a).y == 4
      assert rect_for(results, :b).y == 10
      assert rect_for(results, :c).y == 16
    end
  end

  describe "align_items" do
    test "stretch (default) in row" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :stretch],
          [
            Element.new(:box, id: :child, width: 20)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).h == 24
    end

    test "flex_start" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:box, id: :child, width: 20, height: 5)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).y == 0
      assert rect_for(results, :child).h == 5
    end

    test "flex_end" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_end],
          [
            Element.new(:box, id: :child, width: 20, height: 5)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).y == 19
    end

    test "center" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :center],
          [
            Element.new(:box, id: :child, width: 20, height: 4)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :child).y == 10
    end
  end

  describe "align_self" do
    test "overrides parent align_items" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:box, id: :normal, width: 10, height: 5),
            Element.new(:box, id: :self_end, width: 10, height: 5, align_self: :flex_end)
          ]
        )

      results = layout(tree)
      assert rect_for(results, :normal).y == 0
      assert rect_for(results, :self_end).y == 19
    end
  end

  describe "border" do
    test "border takes 1 cell on each side" do
      tree =
        Element.new(:box, [id: :root, width: 40, height: 10, border: true], [
          Element.new(:text, id: :child, content: "Inside")
        ])

      results = layout(tree)
      child_rect = rect_for(results, :child)
      assert child_rect.x == 1
      assert child_rect.y == 1
    end

    test "border + padding" do
      tree =
        Element.new(:box, [id: :root, width: 40, height: 10, border: true, padding: 1], [
          Element.new(:text, id: :child, content: "Inside")
        ])

      results = layout(tree)
      child_rect = rect_for(results, :child)
      assert child_rect.x == 2
      assert child_rect.y == 2
    end
  end

  describe "position: :absolute" do
    test "absolute position with top/left" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24], [
          Element.new(:box, id: :flow, height: 5),
          Element.new(:box,
            id: :overlay,
            position: :absolute,
            top: 10,
            left: 20,
            width: 30,
            height: 8
          )
        ])

      results = layout(tree)
      overlay_rect = rect_for(results, :overlay)
      assert overlay_rect.x == 20
      assert overlay_rect.y == 10
      assert overlay_rect.w == 30
      assert overlay_rect.h == 8
    end

    test "absolute with right/bottom" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24], [
          Element.new(:box,
            id: :overlay,
            position: :absolute,
            right: 0,
            bottom: 0,
            width: 20,
            height: 5
          )
        ])

      results = layout(tree)
      overlay_rect = rect_for(results, :overlay)
      assert overlay_rect.x == 60
      assert overlay_rect.y == 19
    end

    test "absolute children don't affect flow" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24], [
          Element.new(:text, id: :a, content: "Line 1"),
          Element.new(:box,
            id: :abs,
            position: :absolute,
            top: 0,
            left: 0,
            width: 80,
            height: 24
          ),
          Element.new(:text, id: :b, content: "Line 2")
        ])

      results = layout(tree)
      assert rect_for(results, :a).y == 0
      assert rect_for(results, :b).y == 1
    end
  end

  describe "text element sizing" do
    test "text width from content" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:text, id: :txt, content: "Hello")
          ]
        )

      results = layout(tree)
      txt_rect = rect_for(results, :txt)
      assert txt_rect.w == 5
      assert txt_rect.h == 1
    end

    test "text width uses display columns for wide characters" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:text, id: :txt, content: "A界B")
          ]
        )

      results = layout(tree)
      txt_rect = rect_for(results, :txt)
      assert txt_rect.w == 4
      assert txt_rect.h == 1
    end

    test "checkbox width uses display columns for labels" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:checkbox, id: :cb, label: "界界")
          ]
        )

      results = layout(tree)
      cb_rect = rect_for(results, :cb)
      assert cb_rect.w == 8
    end

    test "select width uses display columns for option labels" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:select, id: :sel, options: ["界界", "ABC"])
          ]
        )

      results = layout(tree)
      sel_rect = rect_for(results, :sel)
      assert sel_rect.w == 4
    end
  end

  describe "min/max dimensions" do
    test "min_width prevents shrinking below" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24], [
          Element.new(:box, id: :child, width: 5, min_width: 20, height: 5)
        ])

      results = layout(tree)
      assert rect_for(results, :child).w == 20
    end

    test "max_width prevents growing above" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24], [
          Element.new(:box, id: :child, width: 100, max_width: 50, height: 5)
        ])

      results = layout(tree)
      assert rect_for(results, :child).w == 50
    end
  end

  describe "frame_buffer intrinsic size" do
    test "uses buffer dimensions" do
      canvas = ElixirOpentui.Canvas.new(20, 10)

      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:frame_buffer, id: :fb, buffer: canvas)
          ]
        )

      results = layout(tree)
      fb_rect = rect_for(results, :fb)
      assert fb_rect.w == 20
      assert fb_rect.h == 10
    end

    test "falls back to attrs width/height without buffer" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:frame_buffer, id: :fb, width: 15, height: 8)
          ]
        )

      results = layout(tree)
      fb_rect = rect_for(results, :fb)
      assert fb_rect.w == 15
      assert fb_rect.h == 8
    end
  end

  describe "ascii_font intrinsic size" do
    test "computed from text and font" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:ascii_font, id: :af, text: "AB", font: :tiny)
          ]
        )

      results = layout(tree)
      af_rect = rect_for(results, :af)
      # A=3 + letterspace=1 + B=3 = 7
      assert af_rect.w == 7
      assert af_rect.h == 2
    end

    test "block font height is 6" do
      tree =
        Element.new(
          :box,
          [id: :root, width: 80, height: 24, flex_direction: :row, align_items: :flex_start],
          [
            Element.new(:ascii_font, id: :af, text: "A", font: :block)
          ]
        )

      results = layout(tree)
      af_rect = rect_for(results, :af)
      assert af_rect.h == 6
    end

    test "participates in flex layout" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row], [
          Element.new(:ascii_font, id: :title, text: "HI", font: :tiny),
          Element.new(:box, id: :content, flex_grow: 1)
        ])

      results = layout(tree)
      title_rect = rect_for(results, :title)
      content_rect = rect_for(results, :content)
      # Title takes intrinsic width, content gets the rest
      assert content_rect.x == title_rect.w
      assert content_rect.w == 80 - title_rect.w
    end
  end

  describe "complex layouts" do
    test "sidebar + main content" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24, flex_direction: :row], [
          Element.new(:box, id: :sidebar, width: 20),
          Element.new(:box, id: :main, flex_grow: 1)
        ])

      results = layout(tree)
      assert rect_for(results, :sidebar).w == 20
      assert rect_for(results, :main).w == 60
      assert rect_for(results, :main).x == 20
    end

    test "header + body + footer" do
      tree =
        Element.new(:box, [id: :root, width: 80, height: 24], [
          Element.new(:box, id: :header, height: 3),
          Element.new(:box, id: :body, flex_grow: 1),
          Element.new(:box, id: :footer, height: 1)
        ])

      results = layout(tree)
      assert rect_for(results, :header).y == 0
      assert rect_for(results, :header).h == 3
      assert rect_for(results, :body).y == 3
      assert rect_for(results, :body).h == 20
      assert rect_for(results, :footer).y == 23
      assert rect_for(results, :footer).h == 1
    end
  end
end
