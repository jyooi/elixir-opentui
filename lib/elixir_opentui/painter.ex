defmodule ElixirOpentui.Painter do
  @moduledoc """
  Paints an element tree into a Buffer using layout results.

  Walks the element tree in z-order (painter's algorithm), writing
  characters and colors into the cell buffer. Each element type has
  its own painting logic.
  """

  alias ElixirOpentui.Border
  alias ElixirOpentui.Buffer
  alias ElixirOpentui.Color
  alias ElixirOpentui.Element
  alias ElixirOpentui.Layout.Rect
  alias ElixirOpentui.TextBuffer

  # --- Focus & UI ---
  @focus_border_fg {80, 160, 255, 255}
  @focus_input_cursor_bg {200, 200, 200, 255}
  @select_highlight_bg {60, 120, 200, 255}
  @placeholder_fg {128, 128, 128, 255}
  @dim_fg {100, 100, 100, 255}
  @description_fg {150, 150, 150, 255}

  # --- Gutter ---
  @gutter_fg {100, 100, 120, 255}

  # --- Diff ---
  @diff_add_fg {80, 220, 80, 255}
  @diff_add_bg {26, 77, 26, 255}
  @diff_rem_fg {220, 80, 80, 255}
  @diff_rem_bg {77, 26, 26, 255}

  # --- Markdown ---
  @md_heading_fg {88, 166, 255, 255}
  @md_code_fg {165, 214, 255, 255}
  @md_code_bg {22, 27, 34, 255}
  @md_quote_fg {139, 148, 158, 255}
  @md_list_fg {255, 123, 114, 255}
  @md_rule_fg {60, 60, 80, 255}

  # --- Tab Select ---
  @tab_selected_fg {255, 255, 255, 255}
  @tab_selected_bg {60, 120, 200, 255}
  @tab_dim_fg {100, 100, 100, 255}

  # --- Select Widget ---
  @select_fg_highlight {255, 255, 255, 255}

  # --- Syntax Token Colors ---
  @token_default {230, 237, 243, 255}
  @token_colors [
                  {[:keyword, :keyword_declaration, :keyword_namespace, :keyword_reserved],
                   {255, 123, 114, 255}},
                  {[:name_function, :name_function_magic], {210, 168, 255, 255}},
                  {[:name_class, :name_builtin, :name_builtin_pseudo], {255, 166, 87, 255}},
                  {[
                     :string,
                     :string_affix,
                     :string_char,
                     :string_doc,
                     :string_double,
                     :string_escape,
                     :string_heredoc,
                     :string_interpol,
                     :string_regex,
                     :string_single,
                     :string_symbol,
                     :string_sigil
                   ], {165, 214, 255, 255}},
                  {[:comment, :comment_doc, :comment_multiline, :comment_single],
                   {139, 148, 158, 255}},
                  {[
                     :number,
                     :number_bin,
                     :number_float,
                     :number_hex,
                     :number_integer,
                     :number_oct
                   ], {121, 192, 255, 255}},
                  {[:name_attribute, :name_decorator], {255, 166, 87, 255}},
                  {[:operator, :operator_word], {255, 123, 114, 255}},
                  {[:punctuation], {240, 246, 252, 255}},
                  {[:name_constant, :name_variable_global, :name_entity], {121, 192, 255, 255}}
                ]
                |> Enum.flat_map(fn {types, color} -> Enum.map(types, &{&1, color}) end)
                |> Map.new()

  @doc "Paint the element tree into the buffer using computed layout."
  def paint(%Element{} = root, layout_results, buffer, opts \\ []) do
    focus_id = Keyword.get(opts, :focus_id)
    paint_node(root, layout_results, buffer, 1.0, focus_id)
  end

  defp el_fg(el, buf, opacity), do: Color.with_opacity(el.style.fg || buf.default_fg, opacity)
  defp el_bg(el, buf, opacity), do: Color.with_opacity(el.style.bg || buf.default_bg, opacity)

  defp paint_node(%Element{} = el, layout, buf, parent_opacity, focus_id) do
    ref = el.attrs[:_layout_ref]
    rect = Map.get(layout, ref) || Map.get(layout, el.id)

    case rect do
      nil ->
        buf

      %Rect{x: x, y: y, w: w, h: h} ->
        opacity = parent_opacity * el.style.opacity
        focused = focus_id != nil and el.id == focus_id

        buf = paint_background(buf, el, x, y, w, h, opacity)
        buf = paint_border(buf, el, x, y, w, h, opacity, focused)
        buf = paint_content(buf, el, x, y, w, h, opacity, focused)
        buf = paint_hit_region(buf, el, x, y, w, h)

        buf =
          if el.type == :scroll_box do
            Buffer.push_scissor(buf, x, y, w, h)
          else
            buf
          end

        sorted_children = Enum.sort_by(el.children, & &1.style.z_index, &<=/2)

        buf =
          Enum.reduce(sorted_children, buf, fn child, b ->
            paint_node(child, layout, b, opacity, focus_id)
          end)

        if el.type == :scroll_box do
          Buffer.pop_scissor(buf)
        else
          buf
        end
    end
  end

  defp paint_background(buf, el, x, y, w, h, opacity) do
    case el.style.bg do
      nil ->
        buf

      bg ->
        bg = Color.with_opacity(bg, opacity)
        fg = el_fg(el, buf, opacity)
        Buffer.fill_rect(buf, x, y, w, h, " ", fg, bg)
    end
  end

  defp paint_border(buf, el, x, y, w, h, opacity, focused) do
    if el.style.border and w >= 2 and h >= 2 do
      chars = Border.chars(el.style.border_style)

      fg =
        if focused do
          (el.style.focus_border_color || @focus_border_fg) |> Color.with_opacity(opacity)
        else
          el_fg(el, buf, opacity)
        end

      bg = el_bg(el, buf, opacity)

      buf =
        Enum.reduce(1..(w - 2)//1, buf, fn cx, b ->
          b = Buffer.draw_char(b, x + cx, y, chars.h, fg, bg)
          Buffer.draw_char(b, x + cx, y + h - 1, chars.h, fg, bg)
        end)

      buf =
        Enum.reduce(1..(h - 2)//1, buf, fn cy, b ->
          b = Buffer.draw_char(b, x, y + cy, chars.v, fg, bg)
          Buffer.draw_char(b, x + w - 1, y + cy, chars.v, fg, bg)
        end)

      buf = Buffer.draw_char(buf, x, y, chars.tl, fg, bg)
      buf = Buffer.draw_char(buf, x + w - 1, y, chars.tr, fg, bg)
      buf = Buffer.draw_char(buf, x, y + h - 1, chars.bl, fg, bg)
      buf = Buffer.draw_char(buf, x + w - 1, y + h - 1, chars.br, fg, bg)

      paint_border_title(buf, el, x, y, w, fg, bg)
    else
      buf
    end
  end

  defp paint_border_title(buf, el, x, y, w, fg, bg) do
    title = el.style.border_title

    if title && w >= 4 do
      max_display_w = w - 4

      {truncated, _} =
        title
        |> String.graphemes()
        |> Enum.reduce_while({"", 0}, fn g, {acc, width} ->
          gw = TextBuffer.char_width(g)

          if width + gw <= max_display_w,
            do: {:cont, {acc <> g, width + gw}},
            else: {:halt, {acc, width}}
        end)

      title_str = " #{truncated} "

      title_display_w =
        String.graphemes(title_str)
        |> Enum.map(&TextBuffer.char_width/1)
        |> Enum.sum()

      start_x =
        case el.style.border_title_align do
          :center -> x + max(1, div(w - title_display_w, 2))
          :right -> x + max(1, w - title_display_w - 1)
          _left -> x + 1
        end

      start_x = max(x + 1, min(start_x, x + w - 1 - title_display_w))

      Buffer.draw_text(buf, start_x, y, title_str, fg, bg)
    else
      buf
    end
  end

  defp paint_content(buf, %Element{type: :text} = el, x, y, w, _h, opacity, _focused) do
    content = Map.get(el.attrs, :content, "")
    fg = el_fg(el, buf, opacity)
    bg = el.style.bg || Map.get(el.attrs, :_parent_bg, buf.default_bg)
    bg = Color.with_opacity(bg, opacity)
    attrs = style_attrs(el.style)

    truncated = TextBuffer.slice_columns(content, 0, w)
    Buffer.draw_text(buf, x, y, truncated, fg, bg, attrs)
  end

  defp paint_content(buf, %Element{type: :label} = el, x, y, w, _h, opacity, _focused) do
    content = Map.get(el.attrs, :content, "")
    fg = el_fg(el, buf, opacity)
    bg = el.style.bg || Map.get(el.attrs, :_parent_bg, buf.default_bg)
    bg = Color.with_opacity(bg, opacity)
    attrs = style_attrs(el.style)

    truncated = TextBuffer.slice_columns(content, 0, w)
    Buffer.draw_text(buf, x, y, truncated, fg, bg, attrs)
  end

  defp paint_content(buf, %Element{type: :panel} = el, x, y, w, _h, opacity, _focused) do
    # style.border_title is rendered in paint_border — skip legacy path
    if el.style.border_title do
      buf
    else
      title = Map.get(el.attrs, :title, "")

      if title != "" and w >= 4 do
        fg = el_fg(el, buf, opacity)
        bg = el_bg(el, buf, opacity)
        truncated = TextBuffer.slice_columns(title, 0, w - 4)
        title_str = " #{truncated} "
        Buffer.draw_text(buf, x + 1, y, title_str, fg, bg)
      else
        buf
      end
    end
  end

  defp paint_content(buf, %Element{type: :input} = el, x, y, w, _h, opacity, focused) do
    value = Map.get(el.attrs, :value, "")
    placeholder = Map.get(el.attrs, :placeholder, "")
    cursor_pos = Map.get(el.attrs, :cursor_pos, TextBuffer.grapheme_count(value))
    scroll_offset = Map.get(el.attrs, :scroll_offset, 0)
    attrs = style_attrs(el.style)

    display = if value == "", do: placeholder, else: value

    default_fg = el_fg(el, buf, opacity)
    default_bg = el_bg(el, buf, opacity)
    ph_fg = Map.get(el.attrs, :placeholder_fg, @placeholder_fg) |> Color.with_opacity(opacity)

    fg = if value == "", do: ph_fg, else: default_fg
    bg = default_bg

    visible = TextBuffer.slice_columns(display, scroll_offset, w)
    buf = Buffer.draw_text(buf, x, y, visible, fg, bg, attrs)

    if focused do
      c_fg =
        Map.get(el.attrs, :cursor_fg, el.style.bg || buf.default_bg)
        |> Color.with_opacity(opacity)

      c_bg =
        (el.style.cursor_color || Map.get(el.attrs, :cursor_bg, @focus_input_cursor_bg))
        |> Color.with_opacity(opacity)

      if value != "" do
        cursor_x = TextBuffer.grapheme_index_to_column(value, cursor_pos) - scroll_offset

        if cursor_x >= 0 and cursor_x < w do
          cursor_char =
            if cursor_x < TextBuffer.display_width(visible) do
              TextBuffer.grapheme_at_column(visible, cursor_x)
            else
              " "
            end

          paint_cursor_char(
            buf,
            el,
            x + cursor_x,
            y,
            cursor_char,
            c_fg,
            c_bg,
            default_fg,
            default_bg,
            opacity
          )
        else
          buf
        end
      else
        paint_cursor_char(buf, el, x, y, " ", c_fg, c_bg, default_fg, default_bg, opacity)
      end
    else
      buf
    end
  end

  defp paint_content(buf, %Element{type: :button} = el, x, y, w, _h, opacity, focused) do
    content = Map.get(el.attrs, :content, "")
    attrs = style_attrs(el.style)

    {fg, bg} =
      if focused do
        {(el.style.focus_fg || el.style.bg || buf.default_bg) |> Color.with_opacity(opacity),
         (el.style.focus_bg || el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)}
      else
        {el_fg(el, buf, opacity), el_bg(el, buf, opacity)}
      end

    truncated = TextBuffer.slice_columns(content, 0, w)
    Buffer.draw_text(buf, x, y, truncated, fg, bg, attrs)
  end

  defp paint_content(buf, %Element{type: :select} = el, x, y, w, h, opacity, focused) do
    options = Map.get(el.attrs, :options, [])
    selected = Map.get(el.attrs, :selected, 0)
    scroll_offset = Map.get(el.attrs, :scroll_offset, 0)
    show_description = Map.get(el.attrs, :show_description, false)
    show_scroll_indicator = Map.get(el.attrs, :show_scroll_indicator, false)
    item_spacing = Map.get(el.attrs, :item_spacing, 0)
    attrs = style_attrs(el.style)

    fg = el_fg(el, buf, opacity)
    bg = el_bg(el, buf, opacity)
    sel_fg = Color.with_opacity(@select_fg_highlight, opacity)
    sel_bg = (el.style.focus_bg || @select_highlight_bg) |> Color.with_opacity(opacity)
    desc_fg = Color.with_opacity(@description_fg, opacity)

    text_w = if show_scroll_indicator, do: max(1, w - 1), else: w
    rows_per = 1 + if(show_description, do: 1, else: 0) + item_spacing
    visible_items = if rows_per > 0, do: max(1, div(h, rows_per)), else: h
    visible_options = Enum.slice(options, scroll_offset, visible_items)

    buf =
      Enum.reduce(Enum.with_index(visible_options, scroll_offset), buf, fn {opt, idx}, b ->
        row_base = y + (idx - scroll_offset) * rows_per

        if row_base < y + h do
          opt_name = option_name(opt)
          opt_str = TextBuffer.slice_columns(opt_name, 0, text_w)

          b =
            if focused and idx == selected do
              b = Buffer.fill_rect(b, x, row_base, text_w, 1, " ", sel_fg, sel_bg, attrs)
              Buffer.draw_text(b, x, row_base, opt_str, sel_fg, sel_bg, attrs)
            else
              Buffer.draw_text(b, x, row_base, opt_str, fg, bg, attrs)
            end

          if show_description and row_base + 1 < y + h do
            desc = option_description(opt)

            if desc do
              desc_str = TextBuffer.slice_columns(desc, 0, text_w)
              Buffer.draw_text(b, x, row_base + 1, desc_str, desc_fg, bg, attrs)
            else
              b
            end
          else
            b
          end
        else
          b
        end
      end)

    if show_scroll_indicator and length(options) > visible_items do
      paint_scroll_indicator(
        buf,
        x + w - 1,
        y,
        h,
        scroll_offset,
        length(options),
        visible_items,
        fg,
        bg,
        opacity
      )
    else
      buf
    end
  end

  defp paint_content(buf, %Element{type: :checkbox} = el, x, y, w, _h, opacity, focused) do
    checked = Map.get(el.attrs, :checked, false)
    label_text = Map.get(el.attrs, :label, "")
    attrs = style_attrs(el.style)

    indicator = if checked, do: "[x] ", else: "[ ] "
    content = indicator <> label_text

    fg =
      if focused do
        (el.style.focus_fg || @focus_border_fg) |> Color.with_opacity(opacity)
      else
        el_fg(el, buf, opacity)
      end

    bg = el_bg(el, buf, opacity)

    truncated = TextBuffer.slice_columns(content, 0, w)
    Buffer.draw_text(buf, x, y, truncated, fg, bg, attrs)
  end

  defp paint_content(buf, %Element{type: :scroll_box} = el, x, y, w, _h, opacity, _focused) do
    scroll_y = Map.get(el.attrs, :scroll_y, 0)

    if scroll_y > 0 do
      fg = Color.with_opacity(@description_fg, opacity)
      bg = el_bg(el, buf, opacity)
      Buffer.draw_char(buf, x + w - 1, y, "▲", fg, bg)
    else
      buf
    end
  end

  defp paint_content(buf, %Element{type: :textarea} = el, x, y, w, h, opacity, focused) do
    lines = Map.get(el.attrs, :lines, [])
    placeholder = Map.get(el.attrs, :placeholder, "")
    cursor_row = Map.get(el.attrs, :cursor_row, 0)
    cursor_col = Map.get(el.attrs, :cursor_col, 0)
    selection = Map.get(el.attrs, :selection)
    attrs = style_attrs(el.style)

    fg = el_fg(el, buf, opacity)
    bg = el_bg(el, buf, opacity)
    placeholder_fg = Color.with_opacity(@placeholder_fg, opacity)

    buf =
      if lines == [] do
        placeholder_line = TextBuffer.slice_columns(placeholder, 0, w)
        Buffer.draw_text(buf, x, y, placeholder_line, placeholder_fg, bg, attrs)
      else
        Enum.reduce(Enum.with_index(lines), buf, fn {line, row_idx}, b ->
          if row_idx < h do
            visible = TextBuffer.slice_columns(line, 0, w)

            if selection do
              draw_textarea_line_with_selection(
                b,
                x,
                y + row_idx,
                visible,
                row_idx,
                w,
                selection,
                fg,
                bg,
                opacity,
                attrs
              )
            else
              Buffer.draw_text(b, x, y + row_idx, visible, fg, bg, attrs)
            end
          else
            b
          end
        end)
      end

    if focused do
      if cursor_row >= 0 and cursor_row < h and cursor_col >= 0 and cursor_col < w do
        cursor_line = Enum.at(lines, cursor_row, "")

        cursor_char =
          if cursor_col < TextBuffer.display_width(cursor_line) do
            TextBuffer.grapheme_at_column(cursor_line, cursor_col)
          else
            " "
          end

        cursor_fg = el_bg(el, buf, opacity)

        cursor_bg =
          (el.style.cursor_color || @focus_input_cursor_bg) |> Color.with_opacity(opacity)

        paint_cursor_char(
          buf,
          el,
          x + cursor_col,
          y + cursor_row,
          cursor_char,
          cursor_fg,
          cursor_bg,
          fg,
          bg,
          opacity
        )
      else
        buf
      end
    else
      buf
    end
  end

  # --- Tab Select ---

  defp paint_content(buf, %Element{type: :tab_select} = el, x, y, w, _h, opacity, focused) do
    options = Map.get(el.attrs, :options, [])
    selected = Map.get(el.attrs, :selected, 0)
    scroll_offset = Map.get(el.attrs, :scroll_offset, 0)
    tab_width = Map.get(el.attrs, :tab_width, 20)
    show_underline = Map.get(el.attrs, :show_underline, true)
    show_description = Map.get(el.attrs, :show_description, true)
    show_scroll_arrows = Map.get(el.attrs, :show_scroll_arrows, true)

    fg = el_fg(el, buf, opacity)
    bg = el_bg(el, buf, opacity)
    sel_fg = Color.with_opacity(@tab_selected_fg, opacity)
    sel_bg = Color.with_opacity(@tab_selected_bg, opacity)
    dim_fg = Color.with_opacity(@tab_dim_fg, opacity)

    max_visible = max(1, div(w, tab_width))
    visible_opts = Enum.slice(options, scroll_offset, max_visible)

    has_left = show_scroll_arrows and scroll_offset > 0
    has_right = show_scroll_arrows and scroll_offset + max_visible < length(options)
    arrow_w = if has_left, do: 1, else: 0
    right_arrow_w = if has_right, do: 1, else: 0

    buf = if has_left, do: Buffer.draw_char(buf, x, y, "<", dim_fg, bg), else: buf
    buf = if has_right, do: Buffer.draw_char(buf, x + w - 1, y, ">", dim_fg, bg), else: buf

    tab_area_x = x + arrow_w
    tab_area_w = w - arrow_w - right_arrow_w

    buf =
      Enum.reduce(Enum.with_index(visible_opts, scroll_offset), buf, fn {opt, idx}, b ->
        tab_x = tab_area_x + (idx - scroll_offset) * tab_width

        if tab_x + tab_width > tab_area_x + tab_area_w do
          b
        else
          tab_name = tab_select_name(opt)
          truncated = TextBuffer.slice_columns(tab_name, 0, tab_width - 1)
          padded = TextBuffer.pad_trailing_columns(truncated, tab_width)

          if focused and idx == selected do
            b = Buffer.fill_rect(b, tab_x, y, tab_width, 1, " ", sel_fg, sel_bg)
            Buffer.draw_text(b, tab_x, y, padded, sel_fg, sel_bg)
          else
            Buffer.draw_text(b, tab_x, y, padded, fg, bg)
          end
        end
      end)

    buf =
      if show_underline do
        underline_y = y + 1
        buf = Buffer.draw_text(buf, x, underline_y, String.duplicate("─", w), dim_fg, bg)

        if focused do
          sel_tab_x = tab_area_x + (selected - scroll_offset) * tab_width

          if sel_tab_x >= tab_area_x and sel_tab_x + tab_width <= tab_area_x + tab_area_w do
            Buffer.draw_text(
              buf,
              sel_tab_x,
              underline_y,
              String.duplicate("━", tab_width),
              sel_fg,
              bg
            )
          else
            buf
          end
        else
          buf
        end
      else
        buf
      end

    if show_description do
      desc_y = y + if show_underline, do: 2, else: 1
      desc = tab_select_desc(Enum.at(options, selected))

      if desc do
        Buffer.draw_text(buf, x, desc_y, TextBuffer.slice_columns(desc, 0, w), dim_fg, bg)
      else
        buf
      end
    else
      buf
    end
  end

  # --- Line Number ---

  defp paint_content(buf, %Element{type: :line_number} = el, x, y, w, h, opacity, _focused) do
    line_count = Map.get(el.attrs, :line_count, 0)
    scroll_offset = Map.get(el.attrs, :scroll_offset, 0)
    visible_lines = Map.get(el.attrs, :visible_lines, line_count)
    line_number_offset = Map.get(el.attrs, :line_number_offset, 0)
    line_colors = Map.get(el.attrs, :line_colors, %{})
    line_signs = Map.get(el.attrs, :line_signs, %{})
    show = Map.get(el.attrs, :show_line_numbers, true)
    gutter_width = w

    fg = el.style.fg || Color.with_opacity(@dim_fg, opacity)
    bg = el_bg(el, buf, opacity)

    if not show do
      buf
    else
      rows = min(visible_lines, min(h, max(0, line_count - scroll_offset)))

      Enum.reduce(0..max(0, rows - 1)//1, buf, fn row, b ->
        line_idx = scroll_offset + row

        if line_idx >= line_count do
          b
        else
          line_num = line_idx + 1 + line_number_offset
          line_fg = Map.get(line_colors, line_idx, fg) |> Color.with_opacity(opacity)

          sign_before = get_in(line_signs, [line_idx, :before]) || ""
          sign_after = get_in(line_signs, [line_idx, :after]) || ""
          num_str = to_string(line_num)

          num_w =
            gutter_width - TextBuffer.display_width(sign_before) -
              TextBuffer.display_width(sign_after) - 1

          padded_num = String.pad_leading(num_str, max(1, num_w))

          full_str =
            TextBuffer.slice_columns(
              sign_before <> padded_num <> sign_after <> " ",
              0,
              gutter_width
            )

          b = Buffer.draw_text(b, x, y + row, full_str, line_fg, bg)

          sign_before_color = get_in(line_signs, [line_idx, :before_color])

          if sign_before != "" and sign_before_color do
            Buffer.draw_text(
              b,
              x,
              y + row,
              sign_before,
              Color.with_opacity(sign_before_color, opacity),
              bg
            )
          else
            b
          end
        end
      end)
    end
  end

  # --- Code ---

  defp paint_content(buf, %Element{type: :code} = el, x, y, w, h, opacity, _focused) do
    content = Map.get(el.attrs, :content, "")
    tokens = Map.get(el.attrs, :tokens)
    scroll_offset = Map.get(el.attrs, :scroll_offset, 0)
    visible_lines = Map.get(el.attrs, :visible_lines) || h
    show_line_numbers = Map.get(el.attrs, :show_line_numbers, true)

    fg = el_fg(el, buf, opacity)
    bg = el_bg(el, buf, opacity)
    gutter_fg = Color.with_opacity(@gutter_fg, opacity)

    lines = String.split(content, "\n")
    total = length(lines)
    digits = if total > 0, do: max(2, length(Integer.digits(total))), else: 2
    gutter_w = if show_line_numbers, do: digits + 2, else: 0
    code_x = x + gutter_w
    code_w = max(0, w - gutter_w)
    rows = min(visible_lines, min(h, max(0, total - scroll_offset)))

    {token_lines, color_for} =
      if tokens do
        {split_tokens_into_lines(tokens), &token_color(&1, opacity)}
      else
        {Enum.map(lines, &[{:plain, &1}]), fn _ -> fg end}
      end

    paint_code_lines(
      buf,
      token_lines,
      x,
      y,
      code_x,
      code_w,
      gutter_fg,
      bg,
      digits,
      show_line_numbers,
      scroll_offset,
      rows,
      color_for
    )
  end

  # --- Diff ---

  defp paint_content(buf, %Element{type: :diff} = el, x, y, w, h, opacity, _focused) do
    diff_lines = Map.get(el.attrs, :lines, [])
    view = Map.get(el.attrs, :view, :unified)
    scroll_offset = Map.get(el.attrs, :scroll_offset, 0)
    visible_lines = Map.get(el.attrs, :visible_lines) || h
    show_line_numbers = Map.get(el.attrs, :show_line_numbers, true)

    fg = el_fg(el, buf, opacity)
    bg = el_bg(el, buf, opacity)
    add_fg = Color.with_opacity(@diff_add_fg, opacity)
    add_bg = Color.with_opacity(@diff_add_bg, opacity)
    rem_fg = Color.with_opacity(@diff_rem_fg, opacity)
    rem_bg = Color.with_opacity(@diff_rem_bg, opacity)
    gutter_fg = Color.with_opacity(@gutter_fg, opacity)

    total = length(diff_lines)
    rows = min(visible_lines, min(h, max(0, total - scroll_offset)))

    colors = %{
      fg: fg,
      bg: bg,
      add_fg: add_fg,
      add_bg: add_bg,
      rem_fg: rem_fg,
      rem_bg: rem_bg,
      gutter_fg: gutter_fg
    }

    case view do
      :unified ->
        paint_diff_unified(
          buf,
          diff_lines,
          x,
          y,
          w,
          colors,
          show_line_numbers,
          scroll_offset,
          rows
        )

      :split ->
        paint_diff_split(
          buf,
          diff_lines,
          x,
          y,
          w,
          colors,
          show_line_numbers,
          scroll_offset,
          rows
        )
    end
  end

  # --- Markdown ---

  defp paint_content(buf, %Element{type: :markdown} = el, x, y, w, h, opacity, _focused) do
    blocks = Map.get(el.attrs, :blocks, [])
    scroll_offset = Map.get(el.attrs, :scroll_offset, 0)

    fg = el_fg(el, buf, opacity)
    bg = el_bg(el, buf, opacity)
    heading_fg = Color.with_opacity(@md_heading_fg, opacity)
    code_fg = Color.with_opacity(@md_code_fg, opacity)
    code_bg = Color.with_opacity(@md_code_bg, opacity)
    quote_fg = Color.with_opacity(@md_quote_fg, opacity)
    list_fg = Color.with_opacity(@md_list_fg, opacity)
    rule_fg = Color.with_opacity(@md_rule_fg, opacity)

    rendered_lines =
      markdown_blocks_to_lines(
        blocks,
        w,
        fg,
        heading_fg,
        code_fg,
        code_bg,
        quote_fg,
        list_fg,
        rule_fg,
        bg
      )

    visible =
      Enum.slice(
        rendered_lines,
        scroll_offset,
        min(h, max(0, length(rendered_lines) - scroll_offset))
      )

    Enum.reduce(Enum.with_index(visible), buf, fn {{text, line_fg, line_bg, line_attrs}, row},
                                                  b ->
      visible_text = TextBuffer.slice_columns(text, 0, w)

      b =
        if line_bg != bg,
          do: Buffer.fill_rect(b, x, y + row, w, 1, " ", line_fg, line_bg),
          else: b

      Buffer.draw_text(b, x, y + row, visible_text, line_fg, line_bg, line_attrs)
    end)
  end

  # --- Frame Buffer (Canvas) ---

  defp paint_content(buf, %Element{type: :frame_buffer} = el, x, y, w, h, opacity, _focused) do
    case Map.get(el.attrs, :buffer) do
      %ElixirOpentui.Canvas{cells: cells} ->
        Enum.reduce(cells, buf, fn {{cx, cy}, {char, cell_fg, cell_bg}}, b ->
          if cx >= 0 and cx < w and cy >= 0 and cy < h do
            fg = Color.with_opacity(cell_fg, opacity)
            bg = Color.with_opacity(cell_bg, opacity)
            Buffer.draw_char(b, x + cx, y + cy, char, fg, bg)
          else
            b
          end
        end)

      _ ->
        buf
    end
  end

  # --- ASCII Font ---

  defp paint_content(buf, %Element{type: :ascii_font} = el, x, y, w, h, opacity, _focused) do
    text = Map.get(el.attrs, :text, "")
    font = Map.get(el.attrs, :font, :tiny)

    if text == "" do
      buf
    else
      primary_fg = el_fg(el, buf, opacity)
      bg = el_bg(el, buf, opacity)

      secondary_fg =
        case Map.get(el.attrs, :secondary_fg) do
          nil ->
            # Dim the primary color to ~50% brightness as default secondary
            {r, g, b, a} = primary_fg
            Color.with_opacity({div(r, 2), div(g, 2), div(b, 2), a}, 1.0)

          color ->
            Color.with_opacity(color, opacity)
        end

      buf = Buffer.fill_rect(buf, x, y, w, h, " ", primary_fg, bg)

      rows = ElixirOpentui.ASCIIFont.render_to_segments(text, font)

      rows
      |> Enum.with_index()
      |> Enum.reduce(buf, fn {segments, row_idx}, b ->
        if row_idx >= h do
          b
        else
          {b, _col} =
            Enum.reduce(segments, {b, 0}, fn {seg_text, color_idx}, {bb, col} ->
              seg_fg = if color_idx == 0, do: primary_fg, else: secondary_fg

              seg_text
              |> String.graphemes()
              |> Enum.reduce({bb, col}, fn char, {bbb, c} ->
                if c < w and char != " " do
                  {Buffer.draw_char(bbb, x + c, y + row_idx, char, seg_fg, bg), c + 1}
                else
                  {bbb, c + 1}
                end
              end)
            end)

          b
        end
      end)
    end
  end

  defp paint_content(buf, _el, _x, _y, _w, _h, _opacity, _focused), do: buf

  # --- Select helpers ---

  defp option_name(%{name: name}), do: name
  defp option_name(opt), do: to_string(opt)

  defp option_description(%{description: desc}) when is_binary(desc), do: desc
  defp option_description(_), do: nil

  defp paint_scroll_indicator(buf, x, y, h, scroll_offset, total, visible, _fg, bg, opacity) do
    indicator_fg = Color.with_opacity(@dim_fg, opacity)

    thumb_size = max(1, div(h * visible, total))

    thumb_pos =
      if total > visible,
        do: div(scroll_offset * (h - thumb_size), total - visible),
        else: 0

    Enum.reduce(0..(h - 1)//1, buf, fn row, b ->
      char =
        cond do
          row == 0 and scroll_offset > 0 -> "▲"
          row == h - 1 and scroll_offset + visible < total -> "▼"
          row >= thumb_pos and row < thumb_pos + thumb_size -> "█"
          true -> "│"
        end

      Buffer.draw_char(b, x, y + row, char, indicator_fg, bg)
    end)
  end

  # --- Textarea helpers ---

  defp paint_cursor_char(
         buf,
         el,
         cx,
         cy,
         char,
         block_fg,
         block_bg,
         normal_fg,
         normal_bg,
         _opacity
       ) do
    case el.style.cursor_style do
      :underline ->
        Buffer.draw_char(buf, cx, cy, char, normal_fg, normal_bg, underline: true)

      :bar ->
        # Bar cursor: render character normally; terminal cursor positioning deferred
        Buffer.draw_char(buf, cx, cy, char, normal_fg, normal_bg)

      _block ->
        Buffer.draw_char(buf, cx, cy, char, block_fg, block_bg)
    end
  end

  defp draw_textarea_line_with_selection(
         buf,
         x,
         y,
         line,
         row_idx,
         w,
         sel,
         fg,
         bg,
         opacity,
         attrs
       ) do
    %{start_row: sr, start_col: sc, end_row: er, end_col: ec} = sel

    # Determine which columns in this row are selected
    {sel_start, sel_end} =
      cond do
        row_idx < sr or row_idx > er -> {w, w}
        row_idx == sr and row_idx == er -> {sc, ec}
        row_idx == sr -> {sc, w}
        row_idx == er -> {0, ec}
        true -> {0, w}
      end

    line
    |> String.graphemes()
    |> Enum.reduce({buf, 0}, fn ch, {b, col} ->
      width = TextBuffer.char_width(ch)
      selected? = col < sel_end and col + width > sel_start

      b =
        if width <= 0 do
          b
        else
          if selected? do
            sel_fg = Color.with_opacity(bg, opacity)
            sel_bg = Color.with_opacity(fg, opacity)
            Buffer.draw_char(b, x + col, y, ch, sel_fg, sel_bg, attrs)
          else
            Buffer.draw_char(b, x + col, y, ch, fg, bg, attrs)
          end
        end

      {b, col + width}
    end)
    |> elem(0)
  end

  defp style_attrs(style) do
    attrs = []
    attrs = if style.bold, do: [{:bold, true} | attrs], else: attrs
    attrs = if style.italic, do: [{:italic, true} | attrs], else: attrs
    attrs = if style.underline, do: [{:underline, true} | attrs], else: attrs
    attrs = if style.strikethrough, do: [{:strikethrough, true} | attrs], else: attrs
    attrs = if style.dim, do: [{:dim, true} | attrs], else: attrs
    attrs = if style.inverse, do: [{:inverse, true} | attrs], else: attrs
    attrs = if style.blink, do: [{:blink, true} | attrs], else: attrs
    attrs = if style.hidden, do: [{:hidden, true} | attrs], else: attrs
    attrs
  end

  defp paint_hit_region(buf, el, x, y, w, h) do
    if el.id do
      Buffer.set_hit_region(buf, x, y, w, h, el.id)
    else
      buf
    end
  end

  # --- Tab Select helpers ---

  defp tab_select_name(%{name: name}), do: name
  defp tab_select_name(s) when is_binary(s), do: s
  defp tab_select_name(_), do: ""

  defp tab_select_desc(%{description: desc}) when is_binary(desc), do: desc
  defp tab_select_desc(_), do: nil

  # --- Code helpers ---

  defp split_tokens_into_lines(tokens) do
    tokens
    |> Enum.reduce([[]], fn {type, _meta, text}, lines ->
      text_str = IO.iodata_to_binary(List.wrap(text))
      parts = String.split(text_str, "\n", parts: :infinity)

      case parts do
        [single] ->
          [current | rest] = lines
          [[{type, single} | current] | rest]

        [first | more] ->
          [current | rest] = lines
          current = [{type, first} | current]
          # Each subsequent part starts a new line
          new_lines = Enum.map(more, fn part -> [{type, part}] end)
          Enum.reverse(new_lines) ++ [current | rest]
      end
    end)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
  end

  defp token_color(type, opacity) do
    Color.with_opacity(Map.get(@token_colors, type, @token_default), opacity)
  end

  # --- Code painting helpers ---

  defp paint_code_lines(
         buf,
         token_lines,
         x,
         y,
         code_x,
         code_w,
         gutter_fg,
         bg,
         digits,
         show_line_numbers,
         scroll_offset,
         rows,
         color_for
       ) do
    Enum.reduce(0..max(0, rows - 1)//1, buf, fn row, b ->
      line_idx = scroll_offset + row

      b =
        if show_line_numbers do
          num_str = String.pad_leading(to_string(line_idx + 1), digits)
          Buffer.draw_text(b, x, y + row, num_str <> "  ", gutter_fg, bg)
        else
          b
        end

      line_tokens = Enum.at(token_lines, line_idx, [])

      {b, _col} =
        Enum.reduce(line_tokens, {b, 0}, fn {type, text}, {bb, col} ->
          visible = TextBuffer.slice_columns(text, 0, max(0, code_w - col))

          bb =
            if col < code_w and visible != "" do
              Buffer.draw_text(bb, code_x + col, y + row, visible, color_for.(type), bg)
            else
              bb
            end

          {bb, col + TextBuffer.display_width(text)}
        end)

      b
    end)
  end

  # --- Diff painting helpers ---

  defp paint_diff_unified(
         buf,
         diff_lines,
         x,
         y,
         w,
         colors,
         show_line_numbers,
         scroll_offset,
         rows
       ) do
    %{gutter_fg: gutter_fg} = colors

    gutter_w = if show_line_numbers, do: 10, else: 0
    content_x = x + gutter_w + 2
    content_w = max(0, w - gutter_w - 2)

    Enum.reduce(0..max(0, rows - 1)//1, buf, fn row, b ->
      line_idx = scroll_offset + row
      line = Enum.at(diff_lines, line_idx)

      if line == nil do
        b
      else
        type = Map.get(line, :type, :context)
        {line_fg, line_bg, sign} = diff_line_style(type, colors)
        content = Map.get(line, :content, "")

        # Fill background for add/remove lines
        b =
          if type in [:add, :remove] do
            Buffer.fill_rect(b, x, y + row, w, 1, " ", line_fg, line_bg)
          else
            b
          end

        # Draw line numbers
        b =
          if show_line_numbers do
            old_num = Map.get(line, :old_line)
            new_num = Map.get(line, :new_line)

            old_str =
              if old_num, do: String.pad_leading(to_string(old_num), 4), else: "    "

            new_str =
              if new_num, do: String.pad_leading(to_string(new_num), 4), else: "    "

            Buffer.draw_text(b, x, y + row, old_str <> " " <> new_str, gutter_fg, line_bg)
          else
            b
          end

        # Draw sign and content
        b = Buffer.draw_text(b, x + gutter_w, y + row, sign <> " ", line_fg, line_bg)
        visible = TextBuffer.slice_columns(content, 0, content_w)
        Buffer.draw_text(b, content_x, y + row, visible, line_fg, line_bg)
      end
    end)
  end

  defp paint_diff_split(
         buf,
         diff_lines,
         x,
         y,
         w,
         colors,
         show_line_numbers,
         scroll_offset,
         rows
       ) do
    half_w = div(w, 2)
    right_x = x + half_w
    gutter_w = if show_line_numbers, do: 6, else: nil
    content_w = max(0, half_w - (gutter_w || 0) - 3)
    empty = %{type: :empty, content: "", old_line: nil, new_line: nil}

    Enum.reduce(0..max(0, rows - 1)//1, buf, fn row, b ->
      line_idx = scroll_offset + row
      line = Enum.at(diff_lines, line_idx)

      if line == nil do
        b
      else
        # Split lines have %{left: side, right: side} structure
        left = Map.get(line, :left, empty)
        right = Map.get(line, :right, empty)

        b
        |> paint_diff_side(
          left,
          left.old_line,
          x,
          y + row,
          half_w - 1,
          content_w,
          gutter_w,
          colors
        )
        |> Buffer.draw_char(right_x - 1, y + row, "│", colors.gutter_fg, colors.bg)
        |> paint_diff_side(
          right,
          right.new_line,
          right_x,
          y + row,
          half_w,
          content_w,
          gutter_w,
          colors
        )
      end
    end)
  end

  # One half of a split diff row. `gutter_w` is nil when line numbers are hidden.
  defp paint_diff_side(b, side, num, sx, sy, fill_w, content_w, gutter_w, colors) do
    {side_fg, side_bg, sign} = diff_line_style(side.type, colors)
    content_offset = (gutter_w || 0) + 2

    b =
      if side.type in [:remove, :add] do
        Buffer.fill_rect(b, sx, sy, fill_w, 1, " ", side_fg, side_bg)
      else
        b
      end

    b =
      if gutter_w do
        num_str =
          if num, do: String.pad_leading(to_string(num), 4) <> " ", else: "     "

        Buffer.draw_text(b, sx, sy, num_str, colors.gutter_fg, side_bg)
      else
        b
      end

    b = Buffer.draw_text(b, sx + (gutter_w || 0), sy, sign <> " ", side_fg, side_bg)

    Buffer.draw_text(
      b,
      sx + content_offset,
      sy,
      TextBuffer.slice_columns(side.content, 0, content_w),
      side_fg,
      side_bg
    )
  end

  # --- Diff helpers ---

  defp diff_line_style(:add, %{add_fg: fg, add_bg: bg}), do: {fg, bg, "+"}
  defp diff_line_style(:remove, %{rem_fg: fg, rem_bg: bg}), do: {fg, bg, "-"}
  defp diff_line_style(_type, %{fg: fg, bg: bg}), do: {fg, bg, " "}

  # --- Markdown helpers ---

  # NOTE: markdown.ex count_rendered_lines/1 mirrors this logic
  defp markdown_blocks_to_lines(
         blocks,
         w,
         fg,
         heading_fg,
         code_fg,
         code_bg,
         quote_fg,
         list_fg,
         rule_fg,
         bg
       ) do
    blocks
    |> Enum.flat_map(fn block ->
      case block do
        %{type: :heading, level: level, content: content} ->
          prefix = String.duplicate("#", level) <> " "
          attrs = [bold: true]
          [{prefix <> content, heading_fg, bg, attrs}, {"", fg, bg, []}]

        %{type: :paragraph, content: content} ->
          lines = String.split(content, "\n")
          Enum.map(lines, fn line -> {line, fg, bg, []} end) ++ [{"", fg, bg, []}]

        %{type: :code_block, content: content} ->
          code_lines = String.split(content, "\n")

          Enum.map(code_lines, fn line -> {"  " <> line, code_fg, code_bg, []} end) ++
            [{"", fg, bg, []}]

        %{type: :list, ordered: ordered, items: items} ->
          items
          |> Enum.with_index(1)
          |> Enum.map(fn {item, idx} ->
            bullet = if ordered, do: "#{idx}. ", else: "  - "
            {bullet <> item, list_fg, bg, []}
          end)
          |> Kernel.++([{"", fg, bg, []}])

        %{type: :blockquote, content: content} ->
          lines = String.split(content, "\n")

          Enum.map(lines, fn line -> {"  > " <> line, quote_fg, bg, [italic: true]} end) ++
            [{"", fg, bg, []}]

        %{type: :horizontal_rule} ->
          [{String.duplicate("─", w), rule_fg, bg, []}, {"", fg, bg, []}]

        %{type: :text, content: content} ->
          [{content, fg, bg, []}]

        _ ->
          []
      end
    end)
  end
end
