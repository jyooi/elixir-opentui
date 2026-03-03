defmodule ElixirOpentui.ANSI do
  @moduledoc """
  ANSI escape sequence generation.

  Converts Buffer cells and diffs into terminal escape sequences.
  Pure module — no side effects. All functions return iodata.
  """

  alias ElixirOpentui.{Buffer, Color}

  # CSI (Control Sequence Introducer)
  @csi "\e["

  # --- Cursor control ---

  @doc "Move cursor to (x, y). 1-indexed for ANSI."
  @spec move_to(non_neg_integer(), non_neg_integer()) :: iodata()
  def move_to(x, y), do: [@csi, Integer.to_string(y + 1), ";", Integer.to_string(x + 1), "H"]

  @spec hide_cursor() :: iodata()
  def hide_cursor, do: "\e[?25l"

  @spec show_cursor() :: iodata()
  def show_cursor, do: "\e[?25h"

  @spec save_cursor() :: iodata()
  def save_cursor, do: "\e7"

  @spec restore_cursor() :: iodata()
  def restore_cursor, do: "\e8"

  # --- Screen control ---

  @spec clear_screen() :: iodata()
  def clear_screen, do: "\e[2J"

  @spec clear_line() :: iodata()
  def clear_line, do: "\e[2K"

  @spec enter_alt_screen() :: iodata()
  def enter_alt_screen, do: "\e[?1049h"

  @spec leave_alt_screen() :: iodata()
  def leave_alt_screen, do: "\e[?1049l"

  @spec reset() :: iodata()
  def reset, do: "\e[0m"

  # --- Mouse mode ---

  @spec enable_mouse() :: iodata()
  def enable_mouse, do: ["\e[?1000h", "\e[?1002h", "\e[?1003h", "\e[?1006h"]

  @spec disable_mouse() :: iodata()
  def disable_mouse, do: ["\e[?1006l", "\e[?1003l", "\e[?1002l", "\e[?1000l"]

  # --- Bracketed paste ---

  @spec enable_paste() :: iodata()
  def enable_paste, do: "\e[?2004h"

  @spec disable_paste() :: iodata()
  def disable_paste, do: "\e[?2004l"

  # --- Kitty keyboard protocol ---

  @doc "Query current Kitty keyboard flags. Terminal responds with `\\e[?{flags}u`."
  @spec query_kitty_keyboard() :: iodata()
  def query_kitty_keyboard, do: "\e[?u"

  @doc "Push Kitty keyboard flags onto the terminal's stack."
  @spec push_kitty_keyboard(non_neg_integer()) :: iodata()
  def push_kitty_keyboard(flags \\ default_kitty_flags()),
    do: ["\e[>", Integer.to_string(flags), "u"]

  @doc "Pop Kitty keyboard flags from the terminal's stack."
  @spec pop_kitty_keyboard() :: iodata()
  def pop_kitty_keyboard, do: "\e[<u"

  @doc """
  Set the Kitty keyboard flags for the current top-of-stack entry (no push/pop).

  `\\e[={flags}u` replaces the current entry's flags directly. Sending
  `set_kitty_keyboard(0)` before `pop_kitty_keyboard()` ensures keyboard
  enhancements are disabled even if the pop doesn't take effect.
  """
  @spec set_kitty_keyboard(non_neg_integer()) :: iodata()
  def set_kitty_keyboard(flags), do: ["\e[=", Integer.to_string(flags), "u"]

  @doc "Enable xterm modifyOtherKeys mode 2 (fallback for non-Kitty terminals)."
  @spec enable_modify_other_keys() :: iodata()
  def enable_modify_other_keys, do: "\e[>4;2m"

  @doc "Disable xterm modifyOtherKeys mode."
  @spec disable_modify_other_keys() :: iodata()
  def disable_modify_other_keys, do: "\e[>4;0m"

  @doc "Default Kitty keyboard flags: disambiguate (1) + alternate keys (4) = 5."
  @spec default_kitty_flags() :: non_neg_integer()
  def default_kitty_flags, do: 5

  # --- Synchronized output (mode 2026) ---

  @doc "Begin synchronized update — terminal buffers output until end_sync_update."
  @spec begin_sync_update() :: iodata()
  def begin_sync_update, do: "\e[?2026h"

  @doc "End synchronized update — terminal flushes buffered output."
  @spec end_sync_update() :: iodata()
  def end_sync_update, do: "\e[?2026l"

  @doc "Query DECRQM for a private mode. Response: \\e[?{mode};{status}$y"
  @spec query_decrqm(non_neg_integer()) :: iodata()
  def query_decrqm(mode), do: ["\e[?", Integer.to_string(mode), "$p"]

  # --- Clipboard (OSC 52) ---

  @doc """
  Generate OSC 52 sequence to copy text to the system clipboard.

  The terminal intercepts this sequence and copies the decoded text.
  Uses BEL (\\a) terminator — more compatible than ST (\\e\\\\) which
  breaks in screen and older tmux versions.
  """
  @spec copy_to_clipboard(String.t(), String.t()) :: iodata()
  def copy_to_clipboard(text, selection \\ "c")
  def copy_to_clipboard("", _selection), do: []

  def copy_to_clipboard(text, selection) do
    ["\e]52;", selection, ";", Base.encode64(text), "\a"]
  end

  # --- Cursor shape ---

  @doc "Set terminal cursor shape. Steady variants (no opts) or blink control."
  @spec cursor_shape(:block | :underline | :bar, keyword()) :: iodata()
  def cursor_shape(style, opts \\ [])

  def cursor_shape(:block, opts) do
    if Keyword.get(opts, :blink, false), do: "\e[1 q", else: "\e[2 q"
  end

  def cursor_shape(:underline, opts) do
    if Keyword.get(opts, :blink, false), do: "\e[3 q", else: "\e[4 q"
  end

  def cursor_shape(:bar, opts) do
    if Keyword.get(opts, :blink, false), do: "\e[5 q", else: "\e[6 q"
  end

  # --- Color / attribute SGR ---

  @doc "Generate SGR (Select Graphic Rendition) sequence for a cell's style."
  @spec sgr(
          Color.t(),
          Color.t(),
          boolean(),
          boolean(),
          boolean(),
          boolean(),
          boolean(),
          boolean(),
          boolean(),
          boolean()
        ) :: iodata()
  def sgr(
        fg,
        bg,
        bold,
        italic,
        underline,
        strikethrough,
        dim \\ false,
        inverse \\ false,
        blink \\ false,
        hidden \\ false
      ) do
    sgr_parts(fg, bg, bold, italic, underline, strikethrough, dim, inverse, blink, hidden)
  end

  @doc "Generate SGR sequence from a cell map."
  @spec sgr(map()) :: iodata()
  def sgr(%{
        fg: fg,
        bg: bg,
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        dim: dim,
        inverse: inverse,
        blink: blink,
        hidden: hidden
      }) do
    sgr_parts(fg, bg, bold, italic, underline, strikethrough, dim, inverse, blink, hidden)
  end

  defp sgr_parts(fg, bg, bold, italic, underline, strikethrough, dim, inverse, blink, hidden) do
    parts =
      []
      |> maybe_add(bold, "1")
      |> maybe_add(dim, "2")
      |> maybe_add(italic, "3")
      |> maybe_add(underline, "4")
      |> maybe_add(blink, "5")
      |> maybe_add(inverse, "7")
      |> maybe_add(hidden, "8")
      |> maybe_add(strikethrough, "9")
      |> add_fg(fg)
      |> add_bg(bg)

    [@csi, Enum.intersperse(Enum.reverse(parts), ";"), "m"]
  end

  defp maybe_add(parts, true, code), do: [code | parts]
  defp maybe_add(parts, false, _code), do: parts

  defp add_fg(parts, {r, g, b, _a}) do
    ["38;2;#{r};#{g};#{b}" | parts]
  end

  defp add_bg(parts, {r, g, b, _a}) do
    ["48;2;#{r};#{g};#{b}" | parts]
  end

  # --- Full frame rendering ---

  @doc "Render an entire buffer to ANSI iodata (for initial draw or full redraw)."
  @spec render_full(Buffer.t()) :: iodata()
  def render_full(%Buffer{cols: cols, rows: rows} = buf) do
    for y <- 0..(rows - 1)//1, reduce: [] do
      acc ->
        row_data = render_row(buf, y, cols)
        [acc, move_to(0, y), row_data]
    end
  end

  @doc "Render only the diff changes between two buffers."
  @spec render_diff([{non_neg_integer(), non_neg_integer(), Buffer.cell()}]) :: iodata()
  def render_diff(changes) do
    changes
    |> group_consecutive()
    |> Enum.map(fn {x, y, cells} ->
      [move_to(x, y) | render_cells(cells)]
    end)
  end

  @doc "Build a complete frame output: hide cursor, render, show cursor."
  @spec frame(iodata()) :: iodata()
  def frame(content) do
    [hide_cursor(), content, show_cursor()]
  end

  # --- Helpers ---

  defp render_row(buf, y, cols) do
    {iodata, _prev} =
      Enum.reduce(0..(cols - 1)//1, {[], nil}, fn x, {acc, prev_style} ->
        cell = Buffer.get_cell(buf, x, y)
        style = cell_style(cell)

        if style == prev_style do
          {[acc, cell.char], style}
        else
          {[acc, sgr(cell), cell.char], style}
        end
      end)

    [iodata, reset()]
  end

  defp render_cells(cells) do
    {iodata, _prev} =
      Enum.reduce(cells, {[], nil}, fn cell, {acc, prev_style} ->
        style = cell_style(cell)

        if style == prev_style do
          {[acc, cell.char], style}
        else
          {[acc, sgr(cell), cell.char], style}
        end
      end)

    [iodata, reset()]
  end

  defp cell_style(cell) do
    {cell.fg, cell.bg, cell.bold, cell.italic, cell.underline, cell.strikethrough, cell.dim,
     cell.inverse, cell.blink, cell.hidden}
  end

  # Group consecutive horizontal changes into runs for efficient cursor movement.
  # Input: [{x, y, cell}, ...] (from Buffer.diff)
  # Output: [{start_x, y, [cells]}, ...]
  defp group_consecutive(changes) do
    changes
    |> Enum.sort_by(fn {x, y, _} -> {y, x} end)
    |> Enum.chunk_while(
      nil,
      fn
        {x, y, cell}, nil ->
          {:cont, {x, y, x, [cell]}}

        {x, y, cell}, {start_x, curr_y, prev_x, cells} when y == curr_y and x == prev_x + 1 ->
          {:cont, {start_x, curr_y, x, cells ++ [cell]}}

        {x, y, cell}, {start_x, curr_y, _prev_x, cells} ->
          {:cont, {start_x, curr_y, cells}, {x, y, x, [cell]}}
      end,
      fn
        nil -> {:cont, nil}
        {start_x, y, _prev_x, cells} -> {:cont, {start_x, y, cells}, nil}
      end
    )
  end
end
