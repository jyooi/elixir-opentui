defmodule ElixirOpentui.Style do
  @moduledoc """
  Style properties for layout computation, mirroring the Flexbox subset
  used by ElixirOpentui (no CSS grid, no float).
  """

  alias ElixirOpentui.Color

  @type dimension :: non_neg_integer() | :auto | {:percent, float()}
  @type flex_direction :: :row | :column | :row_reverse | :column_reverse
  @type justify_content ::
          :flex_start | :flex_end | :center | :space_between | :space_around | :space_evenly
  @type align_items :: :flex_start | :flex_end | :center | :stretch
  @type align_self :: :auto | :flex_start | :flex_end | :center | :stretch
  @type flex_wrap :: :no_wrap | :wrap | :wrap_reverse
  @type position_type :: :relative | :absolute

  @type border_style :: :single | :double | :rounded | :heavy
  @type cursor_style :: :block | :underline | :bar

  @type t :: %__MODULE__{
          flex_direction: flex_direction(),
          flex_grow: number(),
          flex_shrink: number(),
          flex_basis: dimension(),
          justify_content: justify_content(),
          align_items: align_items(),
          align_self: align_self(),
          flex_wrap: flex_wrap(),
          width: dimension(),
          height: dimension(),
          min_width: dimension(),
          min_height: dimension(),
          max_width: dimension(),
          max_height: dimension(),
          padding: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()},
          margin: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()},
          gap: non_neg_integer(),
          position: position_type(),
          top: non_neg_integer() | nil,
          left: non_neg_integer() | nil,
          right: non_neg_integer() | nil,
          bottom: non_neg_integer() | nil,
          border: boolean(),
          border_style: border_style(),
          border_title: String.t() | nil,
          border_title_align: :left | :center | :right,
          fg: Color.t() | nil,
          bg: Color.t() | nil,
          opacity: float(),
          overflow: :visible | :hidden,
          z_index: integer(),
          focus_fg: Color.t() | nil,
          focus_bg: Color.t() | nil,
          focus_border_color: Color.t() | nil,
          cursor_color: Color.t() | nil,
          cursor_style: cursor_style() | nil,
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          strikethrough: boolean(),
          dim: boolean(),
          inverse: boolean(),
          blink: boolean(),
          hidden: boolean()
        }

  defstruct flex_direction: :column,
            flex_grow: 0,
            flex_shrink: 1,
            flex_basis: :auto,
            justify_content: :flex_start,
            align_items: :stretch,
            align_self: :auto,
            flex_wrap: :no_wrap,
            width: :auto,
            height: :auto,
            min_width: :auto,
            min_height: :auto,
            max_width: :auto,
            max_height: :auto,
            padding: {0, 0, 0, 0},
            margin: {0, 0, 0, 0},
            gap: 0,
            position: :relative,
            top: nil,
            left: nil,
            right: nil,
            bottom: nil,
            border: false,
            border_style: :single,
            border_title: nil,
            border_title_align: :left,
            fg: nil,
            bg: nil,
            opacity: 1.0,
            overflow: :visible,
            z_index: 0,
            focus_fg: nil,
            focus_bg: nil,
            focus_border_color: nil,
            cursor_color: nil,
            cursor_style: nil,
            bold: false,
            italic: false,
            underline: false,
            strikethrough: false,
            dim: false,
            inverse: false,
            blink: false,
            hidden: false

  @doc "Build a Style from keyword attrs, normalizing shorthand padding/margin."
  @spec from_attrs(keyword()) :: t()
  def from_attrs(attrs) when is_list(attrs) do
    attrs
    |> normalize_padding()
    |> normalize_margin()
    |> then(&struct(__MODULE__, &1))
  end

  defp normalize_padding(attrs) do
    case Keyword.get(attrs, :padding) do
      nil -> attrs
      n when is_integer(n) -> Keyword.put(attrs, :padding, {n, n, n, n})
      {_t, _r, _b, _l} = quad -> Keyword.put(attrs, :padding, quad)
      _ -> attrs
    end
  end

  defp normalize_margin(attrs) do
    case Keyword.get(attrs, :margin) do
      nil -> attrs
      n when is_integer(n) -> Keyword.put(attrs, :margin, {n, n, n, n})
      {_t, _r, _b, _l} = quad -> Keyword.put(attrs, :margin, quad)
      _ -> attrs
    end
  end
end
