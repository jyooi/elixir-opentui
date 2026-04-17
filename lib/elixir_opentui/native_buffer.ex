defmodule ElixirOpentui.NativeBuffer do
  @moduledoc """
  NIF-backed buffer wrapper. Accumulates draw operations as iodata in a
  batch binary protocol, then flushes them in one NIF call per frame.

  Implements the same BufferBehaviour as Buffer for polymorphic dispatch.
  """

  @behaviour ElixirOpentui.BufferBehaviour

  alias ElixirOpentui.{Color, TextBuffer}
  alias ElixirOpentui.NIF

  @char_bytes_size 64

  @type t :: %__MODULE__{
          ref: reference(),
          cols: non_neg_integer(),
          rows: non_neg_integer(),
          ops: iodata(),
          hit_map: %{atom() => non_neg_integer()},
          hit_reverse: %{non_neg_integer() => atom()},
          next_hit: non_neg_integer(),
          default_fg: Color.t(),
          default_bg: Color.t(),
          scissor_stack: [{integer(), integer(), non_neg_integer(), non_neg_integer()}]
        }

  defstruct [
    :ref,
    :cols,
    :rows,
    ops: [],
    hit_map: %{},
    hit_reverse: %{},
    next_hit: 1,
    default_fg: {255, 255, 255, 255},
    default_bg: {0, 0, 0, 255},
    scissor_stack: []
  ]

  @doc "Create a new NIF-backed buffer."
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def new(cols, rows, opts \\ []) do
    ref = NIF.init(cols, rows)
    fg = Keyword.get(opts, :fg, {255, 255, 255, 255})
    bg = Keyword.get(opts, :bg, {0, 0, 0, 255})

    %__MODULE__{
      ref: ref,
      cols: cols,
      rows: rows,
      default_fg: fg,
      default_bg: bg
    }
  end

  @doc "Push a scissor rect. Drawing is clipped to the intersection of all active scissor rects."
  def push_scissor(%__MODULE__{scissor_stack: stack} = buf, x, y, w, h) do
    parent =
      case stack do
        [] -> {0, 0, buf.cols, buf.rows}
        [top | _] -> top
      end

    clipped = intersect_rect({x, y, w, h}, parent)
    %{buf | scissor_stack: [clipped | stack]}
  end

  @doc "Pop the top scissor rect, restoring the previous clip region."
  def pop_scissor(%__MODULE__{scissor_stack: [_ | rest]} = buf) do
    %{buf | scissor_stack: rest}
  end

  def pop_scissor(buf), do: buf

  @doc "Draw a single character at (x, y) with optional text attributes."
  @spec draw_char(t(), integer(), integer(), String.t(), Color.t(), Color.t(), keyword()) :: t()
  def draw_char(%__MODULE__{} = buf, x, y, char, fg, bg, attrs \\ []) do
    draw_cells(buf, x, y, char, fg, bg, attrs)
  end

  @doc "Draw a character with alpha blending over existing cell."
  @spec draw_char_blend(t(), integer(), integer(), String.t(), Color.t(), Color.t(), keyword()) ::
          t()
  def draw_char_blend(%__MODULE__{} = buf, x, y, char, fg, bg, attrs \\ []) do
    draw_cells(buf, x, y, char, fg, bg, attrs)
  end

  @doc "Draw a string horizontally starting at (x, y) with optional text attributes."
  @spec draw_text(t(), integer(), integer(), String.t(), Color.t(), Color.t(), keyword()) :: t()
  def draw_text(buf, x, y, text, fg, bg, attrs \\ []) do
    text
    |> String.graphemes()
    |> Enum.reduce({buf, x}, fn grapheme, {b, cx} ->
      width = TextBuffer.char_width(grapheme)
      {draw_char(b, cx, y, grapheme, fg, bg, attrs), cx + width}
    end)
    |> elem(0)
  end

  @doc "Fill a rectangular region with optional text attributes."
  @spec fill_rect(
          t(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          Color.t(),
          Color.t(),
          keyword()
        ) ::
          t()
  def fill_rect(%__MODULE__{} = buf, x, y, w, h, char, fg, bg, attrs \\ []) do
    case TextBuffer.char_width(char) do
      1 ->
        {cx, cy, cw, ch} = clip_rect(buf, x, y, w, h)

        if cw > 0 and ch > 0 do
          %{buf | ops: [buf.ops | encode_fill(cx, cy, cw, ch, char, fg, bg, encode_attrs(attrs))]}
        else
          buf
        end

      width when width <= 0 ->
        buf

      _width ->
        for cy <- y..(y + h - 1)//1,
            cx <- x..(x + w - 1)//1,
            reduce: buf do
          acc -> draw_char(acc, cx, cy, char, fg, bg, attrs)
        end
    end
  end

  @doc "Set hit_id for a rectangular region."
  @spec set_hit_region(t(), integer(), integer(), integer(), integer(), term()) :: t()
  def set_hit_region(%__MODULE__{} = buf, x, y, w, h, hit_id) do
    {cx, cy, cw, ch} = clip_rect(buf, x, y, w, h)

    if cw > 0 and ch > 0 do
      {u16_id, buf} = map_hit_id(buf, hit_id)
      %{buf | ops: [buf.ops | encode_hit(cx, cy, cw, ch, u16_id)]}
    else
      buf
    end
  end

  @doc "Get cell data at (x, y) from the front buffer."
  @spec get_cell(t(), integer(), integer()) :: map() | nil
  def get_cell(%__MODULE__{ref: ref}, x, y) do
    case NIF.get_cell_data(ref, x, y) do
      nil ->
        nil

      {char_bin, fg_r, fg_g, fg_b, bg_r, bg_g, bg_b, attrs, _hit_id} ->
        %{
          char: char_bin,
          fg: {fg_r, fg_g, fg_b, 255},
          bg: {bg_r, bg_g, bg_b, 255},
          bold: Bitwise.band(attrs, 1) != 0,
          italic: Bitwise.band(attrs, 2) != 0,
          underline: Bitwise.band(attrs, 4) != 0,
          strikethrough: Bitwise.band(attrs, 8) != 0,
          dim: Bitwise.band(attrs, 16) != 0,
          inverse: Bitwise.band(attrs, 32) != 0,
          blink: Bitwise.band(attrs, 64) != 0,
          hidden: Bitwise.band(attrs, 128) != 0,
          hit_id: nil
        }
    end
  end

  @doc "Get the hit_id at coordinates (x, y) from the front buffer."
  @spec get_hit_id(t(), integer(), integer()) :: term()
  def get_hit_id(%__MODULE__{ref: ref, hit_reverse: hit_reverse}, x, y) do
    case NIF.get_hit_id(ref, x, y) do
      nil -> nil
      u16_id -> Map.get(hit_reverse, u16_id)
    end
  end

  @doc "Clear the back buffer."
  @spec clear(t()) :: t()
  def clear(%__MODULE__{ref: ref} = buf) do
    NIF.clear(ref)
    %{buf | ops: []}
  end

  @doc "Convert the front buffer to a list of row strings."
  @spec to_strings(t()) :: [String.t()]
  def to_strings(%__MODULE__{ref: ref}) do
    NIF.to_strings(ref)
  end

  @doc "Flush accumulated ops to the NIF back buffer."
  @spec flush(t()) :: t()
  def flush(%__MODULE__{ref: ref, ops: ops} = buf) do
    binary = IO.iodata_to_binary(ops)

    if byte_size(binary) > 0 do
      NIF.put_cells(ref, binary)
    end

    %{buf | ops: []}
  end

  @doc "Render frame and capture ANSI output. Flushes ops, diffs, returns binary."
  @spec render_frame_capture(t()) :: {t(), binary()}
  def render_frame_capture(%__MODULE__{} = buf) do
    buf = flush(buf)
    ansi = NIF.render_frame_capture(buf.ref)
    {buf, ansi}
  end

  @doc "Render frame to stdout. Flushes ops, diffs, writes."
  @spec render_frame(t()) :: t()
  def render_frame(%__MODULE__{} = buf) do
    buf = flush(buf)
    NIF.render_frame(buf.ref)
    buf
  end

  @doc "Diff is handled natively — not available as Elixir function."
  def diff(_old, _new) do
    raise "NativeBuffer does not support diff/2 — use render_frame/render_frame_capture instead"
  end

  # --- Binary Protocol Encoding ---

  defp encode_attrs([]), do: 0

  defp encode_attrs(attrs) do
    Enum.reduce(attrs, 0, fn
      {:bold, true}, acc -> Bitwise.bor(acc, 1)
      {:italic, true}, acc -> Bitwise.bor(acc, 2)
      {:underline, true}, acc -> Bitwise.bor(acc, 4)
      {:strikethrough, true}, acc -> Bitwise.bor(acc, 8)
      {:dim, true}, acc -> Bitwise.bor(acc, 16)
      {:inverse, true}, acc -> Bitwise.bor(acc, 32)
      {:blink, true}, acc -> Bitwise.bor(acc, 64)
      {:hidden, true}, acc -> Bitwise.bor(acc, 128)
      _, acc -> acc
    end)
  end

  defp draw_cells(%__MODULE__{} = buf, x, y, char, fg, bg, attrs) do
    case TextBuffer.char_width(char) do
      width when width <= 0 ->
        buf

      width ->
        if drawable_span?(buf, x, y, width) do
          encoded_attrs = encode_attrs(attrs)

          Enum.reduce(0..(width - 1)//1, buf, fn offset, acc ->
            cell_char = if offset == 0, do: char, else: ""
            append_cell(acc, x + offset, y, cell_char, fg, bg, encoded_attrs, 0)
          end)
        else
          buf
        end
    end
  end

  defp append_cell(%__MODULE__{} = buf, x, y, char, fg, bg, attrs, hit_id) do
    if in_scissor?(buf, x, y) do
      %{buf | ops: [buf.ops | encode_cell(x, y, char, fg, bg, attrs, hit_id)]}
    else
      buf
    end
  end

  defp encode_cell(x, y, char, {fr, fg, fb, _fa}, {br, bg, bb, _ba}, attrs, hit_id) do
    {char_len, char_bin} = encode_char(char)

    <<1, x::16-little, y::16-little, char_len, char_bin::binary-size(@char_bytes_size), fr, fg,
      fb, br, bg, bb, attrs, hit_id::16-little>>
  end

  defp encode_fill(x, y, w, h, char, {fr, fg, fb, _fa}, {br, bg, bb, _ba}, attrs) do
    {char_len, char_bin} = encode_char(char)

    <<2, x::16-little, y::16-little, w::16-little, h::16-little, char_len,
      char_bin::binary-size(@char_bytes_size), fr, fg, fb, br, bg, bb, attrs>>
  end

  defp encode_hit(x, y, w, h, hit_id) do
    <<3, x::16-little, y::16-little, w::16-little, h::16-little, hit_id::16-little>>
  end

  defp encode_char(char) do
    bytes = :binary.bin_to_list(char)
    len = min(length(bytes), @char_bytes_size)

    {len, :binary.list_to_bin(Enum.take(bytes, len) ++ List.duplicate(0, @char_bytes_size - len))}
  end

  defp in_scissor?(%__MODULE__{scissor_stack: [], cols: cols, rows: rows}, x, y) do
    x >= 0 and x < cols and y >= 0 and y < rows
  end

  defp in_scissor?(%__MODULE__{scissor_stack: [{sx, sy, sw, sh} | _]}, x, y) do
    x >= sx and x < sx + sw and y >= sy and y < sy + sh
  end

  defp drawable_span?(buf, x, y, width) do
    Enum.all?(0..(width - 1)//1, fn offset ->
      in_scissor?(buf, x + offset, y)
    end)
  end

  defp clip_rect(%__MODULE__{scissor_stack: [], cols: cols, rows: rows}, x, y, w, h) do
    intersect_rect({x, y, w, h}, {0, 0, cols, rows})
  end

  defp clip_rect(%__MODULE__{scissor_stack: [scissor | _]}, x, y, w, h) do
    intersect_rect({x, y, w, h}, scissor)
  end

  defp intersect_rect({x1, y1, w1, h1}, {x2, y2, w2, h2}) do
    left = max(x1, x2)
    top = max(y1, y2)
    right = min(x1 + w1, x2 + w2)
    bottom = min(y1 + h1, y2 + h2)
    {left, top, max(0, right - left), max(0, bottom - top)}
  end

  defp map_hit_id(%__MODULE__{hit_map: map, hit_reverse: rev, next_hit: next} = buf, hit_id)
       when is_atom(hit_id) do
    case Map.get(map, hit_id) do
      nil ->
        new_map = Map.put(map, hit_id, next)
        new_rev = Map.put(rev, next, hit_id)
        {next, %{buf | hit_map: new_map, hit_reverse: new_rev, next_hit: next + 1}}

      existing ->
        {existing, buf}
    end
  end

  defp map_hit_id(buf, _hit_id), do: {0, buf}
end
