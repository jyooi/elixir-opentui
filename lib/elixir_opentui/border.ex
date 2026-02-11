defmodule ElixirOpentui.Border do
  @moduledoc """
  Border character definitions for different border styles.

  Provides the box-drawing characters for :single, :double, :rounded, and :heavy
  border styles. Used by the Painter to render element borders.
  """

  @type border_style :: :single | :double | :rounded | :heavy
  @type border_chars :: %{
          tl: String.t(),
          tr: String.t(),
          bl: String.t(),
          br: String.t(),
          h: String.t(),
          v: String.t()
        }

  @spec chars(border_style()) :: border_chars()
  def chars(:single), do: %{tl: "┌", tr: "┐", bl: "└", br: "┘", h: "─", v: "│"}
  def chars(:double), do: %{tl: "╔", tr: "╗", bl: "╚", br: "╝", h: "═", v: "║"}
  def chars(:rounded), do: %{tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│"}
  def chars(:heavy), do: %{tl: "┏", tr: "┓", bl: "┗", br: "┛", h: "━", v: "┃"}

  @spec styles() :: [border_style()]
  def styles, do: [:single, :double, :rounded, :heavy]

  @spec valid?(term()) :: boolean()
  def valid?(style), do: style in [:single, :double, :rounded, :heavy]
end
