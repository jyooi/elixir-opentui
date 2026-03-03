defmodule ElixirOpentui.Layout do
  @moduledoc """
  Pure Elixir "Flexbox Lite" layout engine.

  Computes layout for a tree of `%ElixirOpentui.Element{}` structs, producing
  a map of `%{element_ref => %Rect{x, y, w, h}}` results.

  Implements the TUI-relevant subset of CSS Flexbox:
  - flex_direction: :row | :column
  - flex_grow, flex_shrink, flex_basis
  - justify_content: :flex_start | :flex_end | :center | :space_between | :space_around
  - align_items, align_self: :flex_start | :flex_end | :center | :stretch
  - width, height (fixed, :auto, {:percent, p})
  - padding, margin, gap
  - position: :relative | :absolute (with top/left/right/bottom)

  NOT implemented (not used in TUI): flex-wrap, align-content, order, CSS grid.

  Three-pass algorithm:
  1. Measure (bottom-up): compute intrinsic sizes
  2. Flex resolve (top-down): distribute space via grow/shrink
  3. Position (top-down): compute absolute coordinates
  """

  alias ElixirOpentui.Element

  defmodule Rect do
    @moduledoc "Layout result rectangle."
    @type t :: %__MODULE__{x: integer(), y: integer(), w: non_neg_integer(), h: non_neg_integer()}
    defstruct x: 0, y: 0, w: 0, h: 0
  end

  @type layout_result :: %{reference() => Rect.t()}

  @doc """
  Compute layout for an element tree within the given available space.

  Returns a map keyed by element reference (using make_ref() assigned during layout)
  mapping to `%Rect{}` structs.
  """
  @spec compute(Element.t(), non_neg_integer(), non_neg_integer()) ::
          {Element.t(), layout_result()}
  def compute(%Element{} = root, available_w, available_h) do
    # Tag each node with a unique ref for result lookup
    {tagged_root, _} = tag_nodes(root, 0)

    results = %{}
    {results, _} = layout_node(tagged_root, available_w, available_h, 0, 0, results)
    {tagged_root, results}
  end

  # --- Pass 1+2+3 combined in recursive descent ---

  defp layout_node(%Element{} = node, avail_w, avail_h, parent_x, parent_y, results) do
    style = node.style

    # Resolve this node's dimensions
    {node_w, node_h} = resolve_dimensions(style, avail_w, avail_h)

    # Account for padding and border
    {pad_top, pad_right, pad_bottom, pad_left} = style.padding
    border_extra = if style.border, do: 1, else: 0
    inner_offset_x = pad_left + border_extra
    inner_offset_y = pad_top + border_extra
    inner_w = max(0, node_w - pad_left - pad_right - border_extra * 2)
    inner_h = max(0, node_h - pad_top - pad_bottom - border_extra * 2)

    # Separate absolute-positioned children from flow children
    {absolute_children, flow_children} =
      Enum.split_with(node.children, fn child -> child.style.position == :absolute end)

    # Measure flow children to get intrinsic sizes
    measured = measure_children(flow_children, style.flex_direction, inner_w, inner_h)

    # Flex resolve: distribute space
    resolved = flex_resolve(measured, style, inner_w, inner_h)

    # Position flow children
    {results, _} =
      position_flow_children(
        resolved,
        style,
        inner_w,
        inner_h,
        parent_x + inner_offset_x,
        parent_y + inner_offset_y,
        results
      )

    # Position absolute children
    results =
      position_absolute_children(
        absolute_children,
        parent_x + inner_offset_x,
        parent_y + inner_offset_y,
        inner_w,
        inner_h,
        results
      )

    # If height/width was :auto, recompute based on children
    {node_w, node_h} =
      auto_size_from_children(
        node,
        style,
        resolved,
        node_w,
        node_h,
        pad_left,
        pad_right,
        pad_top,
        pad_bottom,
        border_extra
      )

    rect = %Rect{x: parent_x, y: parent_y, w: node_w, h: node_h}
    ref = node.attrs[:_layout_ref]
    results = if ref, do: Map.put(results, ref, rect), else: results

    # Also store by id if present
    results = if node.id, do: Map.put(results, node.id, rect), else: results

    {results, rect}
  end

  # --- Dimension resolution ---

  defp resolve_dimensions(style, avail_w, avail_h) do
    w = resolve_dim(style.width, avail_w)
    h = resolve_dim(style.height, avail_h)

    w = apply_min_max(w, style.min_width, style.max_width, avail_w)
    h = apply_min_max(h, style.min_height, style.max_height, avail_h)

    {w, h}
  end

  defp resolve_dim(:auto, avail), do: avail
  defp resolve_dim({:percent, p}, avail), do: round(avail * p / 100.0)
  defp resolve_dim(fixed, _avail) when is_integer(fixed), do: fixed
  defp resolve_dim(_, avail), do: avail

  defp apply_min_max(val, min_d, max_d, avail) do
    min_v =
      case min_d do
        :auto -> 0
        {:percent, p} -> round(avail * p / 100.0)
        n when is_integer(n) -> n
        _ -> 0
      end

    max_v =
      case max_d do
        :auto -> :infinity
        {:percent, p} -> round(avail * p / 100.0)
        n when is_integer(n) -> n
        _ -> :infinity
      end

    val = max(val, min_v)
    if max_v == :infinity, do: val, else: min(val, max_v)
  end

  # --- Measurement ---

  defp measure_children(children, flex_dir, avail_w, avail_h) do
    Enum.map(children, fn child ->
      style = child.style
      {cw, ch} = child_intrinsic_size(child, style, flex_dir, avail_w, avail_h)
      {margin_top, margin_right, margin_bottom, margin_left} = style.margin

      main_size =
        case flex_dir do
          :row -> cw + margin_left + margin_right
          :column -> ch + margin_top + margin_bottom
        end

      cross_size =
        case flex_dir do
          :row -> ch + margin_top + margin_bottom
          :column -> cw + margin_left + margin_right
        end

      %{
        element: child,
        intrinsic_main: main_size,
        intrinsic_cross: cross_size,
        content_main: if(flex_dir == :row, do: cw, else: ch),
        content_cross: if(flex_dir == :row, do: ch, else: cw),
        resolved_main: main_size,
        resolved_cross: cross_size,
        flex_grow: style.flex_grow,
        flex_shrink: style.flex_shrink,
        flex_basis: style.flex_basis,
        margin: style.margin
      }
    end)
  end

  defp child_intrinsic_size(child, style, flex_dir, avail_w, avail_h) do
    # Elements with known intrinsic sizes (text, label, input, button) always
    # use their content size. Containers (box, panel, etc.) use 0 on the main
    # axis (so flex-grow has room) and available space on the cross axis
    # (controlled later by stretch/align).
    has_intrinsic =
      child.type in [
        :text,
        :label,
        :input,
        :button,
        :checkbox,
        :select,
        :textarea,
        :tab_select,
        :line_number,
        :code,
        :diff,
        :markdown,
        :frame_buffer,
        :ascii_font
      ]

    w =
      case style.width do
        :auto ->
          if has_intrinsic do
            content_width(child, avail_w)
          else
            case flex_dir do
              :row -> 0
              :column -> avail_w
            end
          end

        {:percent, p} ->
          round(avail_w * p / 100.0)

        n when is_integer(n) ->
          n

        _ ->
          content_width(child, avail_w)
      end

    h =
      case style.height do
        :auto ->
          if has_intrinsic do
            content_height(child, avail_h)
          else
            case flex_dir do
              :column -> 0
              :row -> avail_h
            end
          end

        {:percent, p} ->
          round(avail_h * p / 100.0)

        n when is_integer(n) ->
          n

        _ ->
          content_height(child, avail_h)
      end

    {w, h}
  end

  defp content_width(%Element{type: :text, attrs: attrs}, _avail) do
    case Map.get(attrs, :content) do
      nil -> 0
      text -> String.length(text)
    end
  end

  defp content_width(%Element{type: :label, attrs: attrs}, _avail) do
    case Map.get(attrs, :content) do
      nil -> 0
      text -> String.length(text)
    end
  end

  defp content_width(%Element{type: :input, attrs: attrs}, avail) do
    Map.get(attrs, :width, min(20, avail))
  end

  defp content_width(%Element{type: :button, attrs: attrs}, _avail) do
    case Map.get(attrs, :content) do
      nil -> 0
      text -> String.length(text)
    end
  end

  defp content_width(%Element{type: :checkbox, attrs: attrs}, _avail) do
    label = Map.get(attrs, :label, "")
    4 + String.length(label)
  end

  defp content_width(%Element{type: :textarea, attrs: attrs}, _avail) do
    Map.get(attrs, :width, 40)
  end

  defp content_width(%Element{type: :select, attrs: attrs}, avail) do
    options = Map.get(attrs, :options, [])
    show_scroll_indicator = Map.get(attrs, :show_scroll_indicator, false)

    base_w =
      if options == [] do
        min(15, avail)
      else
        options |> Enum.map(&select_option_width/1) |> Enum.max()
      end

    if show_scroll_indicator, do: base_w + 1, else: base_w
  end

  defp content_width(%Element{type: :tab_select, attrs: attrs}, avail) do
    Map.get(attrs, :width, min(60, avail))
  end

  defp content_width(%Element{type: :line_number, attrs: attrs}, _avail) do
    Map.get(attrs, :gutter_width, 4)
  end

  defp content_width(%Element{type: :code, attrs: attrs}, avail) do
    Map.get(attrs, :width, avail)
  end

  defp content_width(%Element{type: :diff, attrs: attrs}, avail) do
    Map.get(attrs, :width, avail)
  end

  defp content_width(%Element{type: :markdown, attrs: attrs}, avail) do
    Map.get(attrs, :width, avail)
  end

  defp content_width(%Element{type: :frame_buffer, attrs: attrs}, _avail) do
    case Map.get(attrs, :buffer) do
      %{width: w} -> w
      _ -> Map.get(attrs, :width, 0)
    end
  end

  defp content_width(%Element{type: :ascii_font, attrs: attrs}, _avail) do
    text = Map.get(attrs, :text, "")
    font = Map.get(attrs, :font, :tiny)

    {w, _h} = ElixirOpentui.ASCIIFont.dimensions(text, font)
    w
  end

  defp content_width(_el, _avail), do: 0

  defp select_option_width(%{name: name}), do: String.length(name)
  defp select_option_width(opt), do: String.length(to_string(opt))

  defp content_height(%Element{type: type}, _avail)
       when type in [:text, :label, :input, :button, :checkbox],
       do: 1

  defp content_height(%Element{type: :textarea, attrs: attrs}, _avail) do
    Map.get(attrs, :height, 10)
  end

  defp content_height(%Element{type: :select, attrs: attrs}, _avail) do
    options = Map.get(attrs, :options, [])
    show_description = Map.get(attrs, :show_description, false)
    item_spacing = Map.get(attrs, :item_spacing, 0)
    rows_per = 1 + if(show_description, do: 1, else: 0) + item_spacing
    max(1, length(options) * rows_per)
  end

  defp content_height(%Element{type: :tab_select, attrs: attrs}, _avail) do
    show_underline = Map.get(attrs, :show_underline, true)
    show_description = Map.get(attrs, :show_description, true)
    1 + if(show_underline, do: 1, else: 0) + if show_description, do: 1, else: 0
  end

  defp content_height(%Element{type: :line_number, attrs: attrs}, _avail) do
    Map.get(attrs, :visible_lines, Map.get(attrs, :line_count, 0))
  end

  defp content_height(%Element{type: :code, attrs: attrs}, _avail) do
    Map.get(attrs, :visible_lines) || Map.get(attrs, :line_count, 0)
  end

  defp content_height(%Element{type: :diff, attrs: attrs}, _avail) do
    Map.get(attrs, :visible_lines) || Map.get(attrs, :line_count, 0)
  end

  defp content_height(%Element{type: :markdown, attrs: attrs}, _avail) do
    Map.get(attrs, :visible_lines) || Map.get(attrs, :block_count, 0)
  end

  defp content_height(%Element{type: :frame_buffer, attrs: attrs}, _avail) do
    case Map.get(attrs, :buffer) do
      %{height: h} -> h
      _ -> Map.get(attrs, :height, 0)
    end
  end

  defp content_height(%Element{type: :ascii_font, attrs: attrs}, _avail) do
    font = Map.get(attrs, :font, :tiny)
    ElixirOpentui.ASCIIFont.font_height(font)
  end

  defp content_height(_el, _avail), do: 0

  # --- Flex resolution ---

  defp flex_resolve([], _style, _avail_w, _avail_h), do: []

  defp flex_resolve(measured, style, avail_w, avail_h) do
    avail_main = if style.flex_direction == :row, do: avail_w, else: avail_h
    gap = style.gap
    total_gaps = max(0, Kernel.length(measured) - 1) * gap

    # Sum intrinsic main sizes
    total_intrinsic = Enum.reduce(measured, 0, fn m, acc -> acc + m.intrinsic_main end)
    remaining = avail_main - total_intrinsic - total_gaps

    cond do
      remaining > 0 ->
        distribute_grow(measured, remaining, style.flex_direction)

      remaining < 0 ->
        distribute_shrink(measured, abs(remaining), style.flex_direction)

      true ->
        measured
    end
  end

  defp distribute_grow(measured, remaining, flex_dir) do
    total_grow = Enum.reduce(measured, 0.0, fn m, acc -> acc + m.flex_grow end)

    if total_grow == 0.0 do
      measured
    else
      Enum.map(measured, fn m ->
        if m.flex_grow > 0 do
          extra = round(remaining * m.flex_grow / total_grow)
          new_main = m.content_main + extra

          case flex_dir do
            :row ->
              {_mt, mr, _mb, ml} = m.margin
              %{m | resolved_main: new_main + ml + mr, content_main: new_main}

            :column ->
              {mt, _mr, mb, _ml} = m.margin
              %{m | resolved_main: new_main + mt + mb, content_main: new_main}
          end
        else
          m
        end
      end)
    end
  end

  defp distribute_shrink(measured, overflow, flex_dir) do
    total_shrink =
      Enum.reduce(measured, 0.0, fn m, acc ->
        acc + m.flex_shrink * m.content_main
      end)

    if total_shrink == 0.0 do
      measured
    else
      Enum.map(measured, fn m ->
        if m.flex_shrink > 0 do
          shrink_amount = round(overflow * (m.flex_shrink * m.content_main) / total_shrink)
          new_main = max(0, m.content_main - shrink_amount)

          case flex_dir do
            :row ->
              {_mt, mr, _mb, ml} = m.margin
              %{m | resolved_main: new_main + ml + mr, content_main: new_main}

            :column ->
              {mt, _mr, mb, _ml} = m.margin
              %{m | resolved_main: new_main + mt + mb, content_main: new_main}
          end
        else
          m
        end
      end)
    end
  end

  # --- Positioning ---

  defp position_flow_children(resolved, style, avail_w, avail_h, base_x, base_y, results) do
    gap = style.gap
    flex_dir = style.flex_direction
    avail_main = if flex_dir == :row, do: avail_w, else: avail_h
    avail_cross = if flex_dir == :row, do: avail_h, else: avail_w

    total_main =
      resolved
      |> Enum.reduce(0, fn m, acc -> acc + m.resolved_main end)
      |> Kernel.+(max(0, Kernel.length(resolved) - 1) * gap)

    free_main = max(0, avail_main - total_main)

    # Compute main-axis start offset and spacing based on justify_content
    {start_offset, between_extra} =
      justify(style.justify_content, free_main, Kernel.length(resolved))

    {results, _offset} =
      Enum.reduce(resolved, {results, start_offset}, fn m, {res, main_offset} ->
        {mt, mr, mb, ml} = m.margin

        # Cross-axis alignment
        cross_offset =
          align_cross(
            style.align_items,
            m.element.style.align_self,
            m.content_cross,
            avail_cross,
            mt,
            mb,
            ml,
            mr,
            flex_dir
          )

        # Calculate absolute position
        {child_x, child_y} =
          case flex_dir do
            :row ->
              {base_x + main_offset + ml, base_y + cross_offset}

            :column ->
              {base_x + cross_offset, base_y + main_offset + mt}
          end

        child_w = if flex_dir == :row, do: m.content_main, else: m.content_cross
        child_h = if flex_dir == :row, do: m.content_cross, else: m.content_main

        # Stretch cross-axis if applicable
        {child_w, child_h} =
          apply_stretch(
            style.align_items,
            m.element.style.align_self,
            flex_dir,
            child_w,
            child_h,
            avail_cross,
            mt,
            mb,
            ml,
            mr
          )

        # Recursively layout this child's subtree
        {res, _child_rect} = layout_node(m.element, child_w, child_h, child_x, child_y, res)

        next_offset = main_offset + m.resolved_main + gap + between_extra
        {res, next_offset}
      end)

    {results, nil}
  end

  defp justify(:flex_start, _free, _count), do: {0, 0}
  defp justify(:flex_end, free, _count), do: {free, 0}
  defp justify(:center, free, _count), do: {div(free, 2), 0}

  defp justify(:space_between, free, count) when count > 1 do
    {0, div(free, count - 1)}
  end

  defp justify(:space_between, _free, _count), do: {0, 0}

  defp justify(:space_around, free, count) when count > 0 do
    space = div(free, count)
    {div(space, 2), space}
  end

  defp justify(:space_around, _free, _count), do: {0, 0}
  defp justify(_, _free, _count), do: {0, 0}

  defp align_cross(align_items, align_self, content_cross, avail_cross, mt, mb, ml, mr, flex_dir) do
    effective_align = if align_self == :auto, do: align_items, else: align_self
    margin_before = if flex_dir == :row, do: mt, else: ml
    margin_after = if flex_dir == :row, do: mb, else: mr
    total_cross = content_cross + margin_before + margin_after

    case effective_align do
      :flex_start -> margin_before
      :flex_end -> avail_cross - content_cross - margin_after
      :center -> margin_before + div(max(0, avail_cross - total_cross), 2)
      :stretch -> margin_before
      _ -> margin_before
    end
  end

  defp apply_stretch(align_items, align_self, flex_dir, w, h, avail_cross, mt, mb, ml, mr) do
    effective_align = if align_self == :auto, do: align_items, else: align_self

    if effective_align == :stretch do
      case flex_dir do
        :row -> {w, max(0, avail_cross - mt - mb)}
        :column -> {max(0, avail_cross - ml - mr), h}
      end
    else
      {w, h}
    end
  end

  defp position_absolute_children(children, base_x, base_y, container_w, container_h, results) do
    Enum.reduce(children, results, fn child, res ->
      style = child.style
      {cw, ch} = resolve_dimensions(style, container_w, container_h)

      x =
        cond do
          style.left != nil -> base_x + style.left
          style.right != nil -> base_x + container_w - cw - style.right
          true -> base_x
        end

      y =
        cond do
          style.top != nil -> base_y + style.top
          style.bottom != nil -> base_y + container_h - ch - style.bottom
          true -> base_y
        end

      {res, _} = layout_node(child, cw, ch, x, y, res)
      res
    end)
  end

  defp auto_size_from_children(_node, style, resolved, w, h, pad_l, pad_r, pad_t, pad_b, border) do
    # Only shrink-to-content when there ARE children; otherwise keep the
    # available space passed by the parent (flex-grow scenario).
    if (style.width == :auto or style.height == :auto) and resolved != [] do
      {auto_w, auto_h} =
        case style.flex_direction do
          :row ->
            content_w = Enum.reduce(resolved, 0, fn m, acc -> acc + m.resolved_main end)
            gap_w = max(0, Kernel.length(resolved) - 1) * style.gap
            max_h = Enum.reduce(resolved, 0, fn m, acc -> max(acc, m.resolved_cross) end)
            {content_w + gap_w + pad_l + pad_r + border * 2, max_h + pad_t + pad_b + border * 2}

          :column ->
            content_h = Enum.reduce(resolved, 0, fn m, acc -> acc + m.resolved_main end)
            gap_h = max(0, Kernel.length(resolved) - 1) * style.gap
            max_w = Enum.reduce(resolved, 0, fn m, acc -> max(acc, m.resolved_cross) end)
            {max_w + pad_l + pad_r + border * 2, content_h + gap_h + pad_t + pad_b + border * 2}
        end

      w = if style.width == :auto, do: auto_w, else: w
      h = if style.height == :auto, do: auto_h, else: h
      {w, h}
    else
      {w, h}
    end
  end

  # --- Node tagging ---

  defp tag_nodes(%Element{} = el, counter) do
    ref = make_ref()
    el = %{el | attrs: Map.put(el.attrs, :_layout_ref, ref)}

    {tagged_children, counter} =
      Enum.reduce(el.children, {[], counter + 1}, fn child, {acc, c} ->
        {tagged, c2} = tag_nodes(child, c)
        {acc ++ [tagged], c2}
      end)

    {%{el | children: tagged_children}, counter}
  end
end
