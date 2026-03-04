defmodule ElixirOpentui.Color do
  @moduledoc """
  RGBA color representation for terminal UI rendering.

  Colors are stored as 4-tuples {r, g, b, a} where each component is 0-255.
  Alpha channel is used for opacity/blending calculations.
  """

  @type component :: 0..255
  @type t :: {component(), component(), component(), component()}

  @transparent {0, 0, 0, 0}
  @black {0, 0, 0, 255}
  @white {255, 255, 255, 255}
  @red {255, 0, 0, 255}
  @green {0, 255, 0, 255}
  @blue {0, 0, 255, 255}
  @yellow {255, 255, 0, 255}
  @cyan {0, 255, 255, 255}
  @magenta {255, 0, 255, 255}

  def transparent, do: @transparent
  def black, do: @black
  def white, do: @white
  def red, do: @red
  def green, do: @green
  def blue, do: @blue
  def yellow, do: @yellow
  def cyan, do: @cyan
  def magenta, do: @magenta

  @doc "Create an RGB color with full opacity."
  @spec rgb(component(), component(), component()) :: t()
  def rgb(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    {r, g, b, 255}
  end

  @doc "Create an RGBA color."
  @spec rgba(component(), component(), component(), component()) :: t()
  def rgba(r, g, b, a) when r in 0..255 and g in 0..255 and b in 0..255 and a in 0..255 do
    {r, g, b, a}
  end

  @doc """
  Alpha-blend `fg` over `bg`. Standard Porter-Duff "source over" compositing.
  """
  @spec blend(fg :: t(), bg :: t()) :: t()
  def blend({_fr, _fg, _fb, 0}, bg), do: bg
  def blend({fr, fg, fb, 255}, _bg), do: {fr, fg, fb, 255}

  def blend({fr, fg, fb, fa}, {br, bg, bb, ba}) do
    alpha_f = fa / 255.0
    alpha_b = ba / 255.0
    out_a = alpha_f + alpha_b * (1.0 - alpha_f)

    if out_a == 0.0 do
      @transparent
    else
      out_r = round((fr * alpha_f + br * alpha_b * (1.0 - alpha_f)) / out_a)
      out_g = round((fg * alpha_f + bg * alpha_b * (1.0 - alpha_f)) / out_a)
      out_b = round((fb * alpha_f + bb * alpha_b * (1.0 - alpha_f)) / out_a)
      out_alpha = round(out_a * 255.0)
      {clamp(out_r), clamp(out_g), clamp(out_b), clamp(out_alpha)}
    end
  end

  @doc "Apply opacity (0.0-1.0) to a color by scaling its alpha."
  @spec with_opacity(t(), float()) :: t()
  def with_opacity({r, g, b, a}, opacity) when opacity >= 0.0 and opacity <= 1.0 do
    {r, g, b, round(a * opacity) |> clamp()}
  end

  @doc "Parse a hex color string like '#FF0000' or '#FF0000FF'."
  @spec from_hex(String.t()) :: {:ok, t()} | {:error, :invalid_hex}
  def from_hex("#" <> hex) do
    case byte_size(hex) do
      6 ->
        with {r, ""} <- Integer.parse(String.slice(hex, 0, 2), 16),
             {g, ""} <- Integer.parse(String.slice(hex, 2, 2), 16),
             {b, ""} <- Integer.parse(String.slice(hex, 4, 2), 16) do
          {:ok, {r, g, b, 255}}
        else
          _ -> {:error, :invalid_hex}
        end

      8 ->
        with {r, ""} <- Integer.parse(String.slice(hex, 0, 2), 16),
             {g, ""} <- Integer.parse(String.slice(hex, 2, 2), 16),
             {b, ""} <- Integer.parse(String.slice(hex, 4, 2), 16),
             {a, ""} <- Integer.parse(String.slice(hex, 6, 2), 16) do
          {:ok, {r, g, b, a}}
        else
          _ -> {:error, :invalid_hex}
        end

      _ ->
        {:error, :invalid_hex}
    end
  end

  def from_hex(_), do: {:error, :invalid_hex}

  @doc "Convert to ANSI 24-bit foreground escape sequence."
  @spec to_ansi_fg(t()) :: iodata()
  def to_ansi_fg({r, g, b, _a}) do
    ["\e[38;2;", Integer.to_string(r), ";", Integer.to_string(g), ";", Integer.to_string(b), "m"]
  end

  @doc "Convert to ANSI 24-bit background escape sequence."
  @spec to_ansi_bg(t()) :: iodata()
  def to_ansi_bg({r, g, b, _a}) do
    ["\e[48;2;", Integer.to_string(r), ";", Integer.to_string(g), ";", Integer.to_string(b), "m"]
  end

  defp clamp(v) when v < 0, do: 0
  defp clamp(v) when v > 255, do: 255
  defp clamp(v), do: v
end
