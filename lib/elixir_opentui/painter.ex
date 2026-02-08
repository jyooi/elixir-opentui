defmodule ElixirOpentui.Painter do
  @moduledoc """
  Paints an element tree into a Buffer using layout results.

  Walks the element tree in z-order (painter's algorithm), writing
  characters and colors into the cell buffer. Each element type has
  its own painting logic.

  Supports both Buffer (pure Elixir) and NativeBuffer (NIF-backed) via
  polymorphic dispatch through buffer_mod/1.
  """

  alias ElixirOpentui.Buffer
  alias ElixirOpentui.NativeBuffer
  alias ElixirOpentui.Color
  alias ElixirOpentui.Element
  alias ElixirOpentui.Layout.Rect

  @focus_border_fg {80, 160, 255, 255}
  @focus_input_cursor_bg {200, 200, 200, 255}
  @select_highlight_bg {60, 120, 200, 255}

  @doc "Paint the element tree into the buffer using computed layout."
  def paint(%Element{} = root, layout_results, buffer, opts \\ []) do
    focus_id = Keyword.get(opts, :focus_id)
    paint_node(root, layout_results, buffer, 1.0, focus_id)
  end

  defp buffer_mod(%Buffer{}), do: Buffer
  defp buffer_mod(%NativeBuffer{}), do: NativeBuffer

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

        Enum.reduce(el.children, buf, fn child, b ->
          paint_node(child, layout, b, opacity, focus_id)
        end)
    end
  end

  defp paint_background(buf, el, x, y, w, h, opacity) do
    case el.style.bg do
      nil ->
        buf

      bg ->
        bg = Color.with_opacity(bg, opacity)
        fg = (el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)
        buffer_mod(buf).fill_rect(buf, x, y, w, h, " ", fg, bg)
    end
  end

  defp paint_border(buf, el, x, y, w, h, opacity, focused) do
    if el.style.border and w >= 2 and h >= 2 do
      mod = buffer_mod(buf)

      fg =
        if focused do
          Color.with_opacity(@focus_border_fg, opacity)
        else
          (el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)
        end

      bg = (el.style.bg || buf.default_bg) |> Color.with_opacity(opacity)

      buf =
        Enum.reduce(1..(w - 2)//1, buf, fn cx, b ->
          b = mod.draw_char(b, x + cx, y, "─", fg, bg)
          mod.draw_char(b, x + cx, y + h - 1, "─", fg, bg)
        end)

      buf =
        Enum.reduce(1..(h - 2)//1, buf, fn cy, b ->
          b = mod.draw_char(b, x, y + cy, "│", fg, bg)
          mod.draw_char(b, x + w - 1, y + cy, "│", fg, bg)
        end)

      buf = mod.draw_char(buf, x, y, "┌", fg, bg)
      buf = mod.draw_char(buf, x + w - 1, y, "┐", fg, bg)
      buf = mod.draw_char(buf, x, y + h - 1, "└", fg, bg)
      mod.draw_char(buf, x + w - 1, y + h - 1, "┘", fg, bg)
    else
      buf
    end
  end

  defp paint_content(buf, %Element{type: :text} = el, x, y, w, _h, opacity, _focused) do
    content = Map.get(el.attrs, :content, "")
    fg = (el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)
    bg = el.style.bg || Map.get(el.attrs, :_parent_bg, buf.default_bg)
    bg = Color.with_opacity(bg, opacity)

    truncated = String.slice(content, 0, w)
    buffer_mod(buf).draw_text(buf, x, y, truncated, fg, bg)
  end

  defp paint_content(buf, %Element{type: :label} = el, x, y, w, _h, opacity, _focused) do
    content = Map.get(el.attrs, :content, "")
    fg = (el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)
    bg = el.style.bg || Map.get(el.attrs, :_parent_bg, buf.default_bg)
    bg = Color.with_opacity(bg, opacity)

    truncated = String.slice(content, 0, w)
    buffer_mod(buf).draw_text(buf, x, y, truncated, fg, bg)
  end

  defp paint_content(buf, %Element{type: :panel} = el, x, y, w, _h, opacity, _focused) do
    title = Map.get(el.attrs, :title, "")

    if title != "" and w >= 4 do
      fg = (el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)
      bg = (el.style.bg || buf.default_bg) |> Color.with_opacity(opacity)
      truncated = String.slice(title, 0, w - 4)
      title_str = " #{truncated} "
      buffer_mod(buf).draw_text(buf, x + 1, y, title_str, fg, bg)
    else
      buf
    end
  end

  defp paint_content(buf, %Element{type: :input} = el, x, y, w, _h, opacity, focused) do
    mod = buffer_mod(buf)
    value = Map.get(el.attrs, :value, "")
    placeholder = Map.get(el.attrs, :placeholder, "")
    cursor_pos = Map.get(el.attrs, :cursor_pos, String.length(value))
    scroll_offset = Map.get(el.attrs, :scroll_offset, 0)

    display = if value == "", do: placeholder, else: value

    fg =
      if value == "" do
        Color.with_opacity({128, 128, 128, 255}, opacity)
      else
        (el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)
      end

    bg = (el.style.bg || buf.default_bg) |> Color.with_opacity(opacity)

    visible = String.slice(display, scroll_offset, w)
    buf = mod.draw_text(buf, x, y, visible, fg, bg)

    if focused and value != "" do
      cursor_x = cursor_pos - scroll_offset

      if cursor_x >= 0 and cursor_x < w do
        cursor_char =
          if cursor_x < String.length(visible) do
            String.at(visible, cursor_x)
          else
            " "
          end

        cursor_fg = (el.style.bg || buf.default_bg) |> Color.with_opacity(opacity)
        cursor_bg = Color.with_opacity(@focus_input_cursor_bg, opacity)
        mod.draw_char(buf, x + cursor_x, y, cursor_char, cursor_fg, cursor_bg)
      else
        buf
      end
    else
      if focused and value == "" do
        cursor_fg = (el.style.bg || buf.default_bg) |> Color.with_opacity(opacity)
        cursor_bg = Color.with_opacity(@focus_input_cursor_bg, opacity)
        mod.draw_char(buf, x, y, " ", cursor_fg, cursor_bg)
      else
        buf
      end
    end
  end

  defp paint_content(buf, %Element{type: :button} = el, x, y, w, _h, opacity, focused) do
    content = Map.get(el.attrs, :content, "")

    {fg, bg} =
      if focused do
        {(el.style.bg || buf.default_bg) |> Color.with_opacity(opacity),
         (el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)}
      else
        {(el.style.fg || buf.default_fg) |> Color.with_opacity(opacity),
         (el.style.bg || buf.default_bg) |> Color.with_opacity(opacity)}
      end

    truncated = String.slice(content, 0, w)
    buffer_mod(buf).draw_text(buf, x, y, truncated, fg, bg)
  end

  defp paint_content(buf, %Element{type: :select} = el, x, y, w, h, opacity, focused) do
    mod = buffer_mod(buf)
    options = Map.get(el.attrs, :options, [])
    selected = Map.get(el.attrs, :selected, 0)
    scroll_offset = Map.get(el.attrs, :scroll_offset, 0)

    fg = (el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)
    bg = (el.style.bg || buf.default_bg) |> Color.with_opacity(opacity)
    sel_fg = Color.with_opacity({255, 255, 255, 255}, opacity)
    sel_bg = Color.with_opacity(@select_highlight_bg, opacity)

    visible_options = Enum.slice(options, scroll_offset, h)

    Enum.reduce(Enum.with_index(visible_options, scroll_offset), buf, fn {opt, idx}, b ->
      row = y + idx - scroll_offset

      if row < y + h do
        opt_str = String.slice(to_string(opt), 0, w)

        if focused and idx == selected do
          b = mod.fill_rect(b, x, row, w, 1, " ", sel_fg, sel_bg)
          mod.draw_text(b, x, row, opt_str, sel_fg, sel_bg)
        else
          mod.draw_text(b, x, row, opt_str, fg, bg)
        end
      else
        b
      end
    end)
  end

  defp paint_content(buf, %Element{type: :checkbox} = el, x, y, w, _h, opacity, focused) do
    checked = Map.get(el.attrs, :checked, false)
    label_text = Map.get(el.attrs, :label, "")

    indicator = if checked, do: "[x] ", else: "[ ] "
    content = indicator <> label_text

    fg =
      if focused do
        Color.with_opacity(@focus_border_fg, opacity)
      else
        (el.style.fg || buf.default_fg) |> Color.with_opacity(opacity)
      end

    bg = (el.style.bg || buf.default_bg) |> Color.with_opacity(opacity)

    truncated = String.slice(content, 0, w)
    buffer_mod(buf).draw_text(buf, x, y, truncated, fg, bg)
  end

  defp paint_content(buf, %Element{type: :scroll_box} = el, x, y, w, _h, opacity, _focused) do
    scroll_y = Map.get(el.attrs, :scroll_y, 0)

    if scroll_y > 0 do
      fg = Color.with_opacity({150, 150, 150, 255}, opacity)
      bg = (el.style.bg || buf.default_bg) |> Color.with_opacity(opacity)
      buffer_mod(buf).draw_char(buf, x + w - 1, y, "▲", fg, bg)
    else
      buf
    end
  end

  defp paint_content(buf, _el, _x, _y, _w, _h, _opacity, _focused), do: buf

  defp paint_hit_region(buf, el, x, y, w, h) do
    if el.id do
      buffer_mod(buf).set_hit_region(buf, x, y, w, h, el.id)
    else
      buf
    end
  end
end
