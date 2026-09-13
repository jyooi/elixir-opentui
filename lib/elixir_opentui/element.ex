defmodule ElixirOpentui.Element do
  @moduledoc """
  Core element struct representing a node in the UI tree.

  Every UI component — whether built-in (box, text, input) or user-defined —
  produces an Element tree. The layout engine consumes this tree to compute
  positions, and the renderer paints it to the terminal.
  """

  alias ElixirOpentui.Style

  @type element_type ::
          :box
          | :text
          | :label
          | :panel
          | :button
          | :input
          | :select
          | :checkbox
          | :scroll_box
          | :textarea
          | :tab_select
          | :line_number
          | :code
          | :markdown
          | :diff
          | :frame_buffer
          | :ascii_font
          | :component

  @type t :: %__MODULE__{
          type: element_type(),
          attrs: map(),
          style: Style.t(),
          children: [t()],
          id: term(),
          component: module() | nil
        }

  defstruct type: :box,
            attrs: %{},
            style: %Style{},
            children: [],
            id: nil,
            component: nil

  @layout_attrs [
    :flex_direction,
    :flex_grow,
    :flex_shrink,
    :flex_basis,
    :flex_wrap,
    :justify_content,
    :align_items,
    :align_self,
    :width,
    :height,
    :min_width,
    :min_height,
    :max_width,
    :max_height,
    :padding,
    :margin,
    :gap,
    :position,
    :top,
    :left,
    :right,
    :bottom,
    :border,
    :border_style,
    :border_title,
    :border_title_align,
    :fg,
    :bg,
    :opacity,
    :overflow,
    :z_index,
    :focus_fg,
    :focus_bg,
    :focus_border_color,
    :cursor_color,
    :cursor_style,
    :bold,
    :italic,
    :underline,
    :strikethrough,
    :dim,
    :inverse,
    :blink,
    :hidden
  ]

  @doc "Create an element from type, keyword attrs, and children list."
  @spec new(element_type(), keyword(), [t()] | t()) :: t()
  def new(type, attrs \\ [], children \\ []) do
    children = List.wrap(children) |> List.flatten() |> Enum.reject(&is_nil/1)
    attrs = normalize_aliases(attrs)
    {style_attrs, rest_attrs} = Keyword.split(attrs, @layout_attrs)
    {meta_attrs, content_attrs} = Keyword.split(rest_attrs, [:id, :component])

    %__MODULE__{
      type: type,
      attrs: Map.new(content_attrs),
      style: Style.from_attrs(style_attrs),
      children: children,
      id: Keyword.get(meta_attrs, :id),
      component: Keyword.get(meta_attrs, :component)
    }
  end

  @aliases %{
    direction: :flex_direction,
    grow: :flex_grow,
    shrink: :flex_shrink,
    basis: :flex_basis,
    wrap: :flex_wrap
  }

  defp normalize_aliases(attrs) do
    Enum.map(attrs, fn {k, v} ->
      {Map.get(@aliases, k, k), v}
    end)
  end
end
