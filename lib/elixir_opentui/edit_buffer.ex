defmodule ElixirOpentui.EditBuffer do
  @moduledoc """
  NIF-backed editable text buffer with cursor, undo/redo, and selection support.

  Wraps the native Zig EditBuffer which provides a rope-based text structure
  with per-character undo/redo history. The cursor uses display-width
  coordinates (row, col) rather than byte or grapheme offsets.
  """

  alias ElixirOpentui.EditBufferNIF

  @type t :: %__MODULE__{
          ref: reference()
        }

  defstruct [:ref]

  @doc "Create a new empty EditBuffer."
  @spec new() :: t()
  def new do
    ref = EditBufferNIF.create()
    %__MODULE__{ref: ref}
  end

  @doc "Create an EditBuffer with initial text."
  @spec from_text(String.t()) :: t()
  def from_text(text) when is_binary(text) do
    buf = new()
    EditBufferNIF.set_text(buf.ref, text)
    buf
  end

  @doc "Get the full buffer text."
  @spec get_text(t()) :: String.t()
  def get_text(%__MODULE__{ref: ref}) do
    EditBufferNIF.get_text(ref)
  end

  @doc "Set the buffer text, resetting cursor and clearing undo history."
  @spec set_text(t(), String.t()) :: t()
  def set_text(%__MODULE__{ref: ref} = buf, text) when is_binary(text) do
    EditBufferNIF.set_text(ref, text)
    buf
  end

  @doc "Replace buffer text, preserving undo history."
  @spec replace_text(t(), String.t()) :: t()
  def replace_text(%__MODULE__{ref: ref} = buf, text) when is_binary(text) do
    EditBufferNIF.replace_text(ref, text)
    buf
  end

  @doc """
  Get the cursor position as `{row, col, offset}`.

  - `row` - 0-indexed logical line number
  - `col` - display-width column on that line
  - `offset` - global display-width offset from buffer start
  """
  @spec get_cursor(t()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def get_cursor(%__MODULE__{ref: ref}) do
    EditBufferNIF.get_cursor(ref)
  end

  @doc "Set the cursor position by row and column (0-indexed). Clamps to valid range."
  @spec set_cursor(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_cursor(%__MODULE__{ref: ref} = buf, row, col)
      when is_integer(row) and is_integer(col) do
    EditBufferNIF.set_cursor(ref, row, col)
    buf
  end

  @doc "Set the cursor position by display-width offset from buffer start."
  @spec set_cursor_by_offset(t(), non_neg_integer()) :: t()
  def set_cursor_by_offset(%__MODULE__{ref: ref} = buf, offset) when is_integer(offset) do
    EditBufferNIF.set_cursor_by_offset(ref, offset)
    buf
  end

  @doc "Insert text at the current cursor position."
  @spec insert(t(), String.t()) :: t()
  def insert(%__MODULE__{ref: ref} = buf, text) when is_binary(text) do
    EditBufferNIF.insert_char(ref, text)
    buf
  end

  @doc "Delete one grapheme before the cursor (backspace)."
  @spec delete_backward(t()) :: t()
  def delete_backward(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.delete_char_backward(ref)
    buf
  end

  @doc "Delete one grapheme after the cursor (delete key)."
  @spec delete_forward(t()) :: t()
  def delete_forward(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.delete_char_forward(ref)
    buf
  end

  @doc "Move cursor one grapheme left."
  @spec move_left(t()) :: t()
  def move_left(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.move_cursor_left(ref)
    buf
  end

  @doc "Move cursor one grapheme right."
  @spec move_right(t()) :: t()
  def move_right(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.move_cursor_right(ref)
    buf
  end

  @doc "Move cursor up one logical line."
  @spec move_up(t()) :: t()
  def move_up(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.move_cursor_up(ref)
    buf
  end

  @doc "Move cursor down one logical line."
  @spec move_down(t()) :: t()
  def move_down(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.move_cursor_down(ref)
    buf
  end

  @doc "Insert a newline at the cursor."
  @spec new_line(t()) :: t()
  def new_line(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.new_line(ref)
    buf
  end

  @doc "Delete the current line."
  @spec delete_line(t()) :: t()
  def delete_line(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.delete_line(ref)
    buf
  end

  @doc "Jump cursor to the given line number (0-indexed)."
  @spec goto_line(t(), non_neg_integer()) :: t()
  def goto_line(%__MODULE__{ref: ref} = buf, line) when is_integer(line) do
    EditBufferNIF.goto_line(ref, line)
    buf
  end

  @doc "Undo the last operation. Returns `{buf, metadata}` where metadata is a binary or nil."
  @spec undo(t()) :: {t(), binary() | nil}
  def undo(%__MODULE__{ref: ref} = buf) do
    meta = EditBufferNIF.undo(ref)
    {buf, meta}
  end

  @doc "Redo the last undone operation. Returns `{buf, metadata}` where metadata is a binary or nil."
  @spec redo(t()) :: {t(), binary() | nil}
  def redo(%__MODULE__{ref: ref} = buf) do
    meta = EditBufferNIF.redo(ref)
    {buf, meta}
  end

  @doc "Get the number of logical lines."
  @spec line_count(t()) :: non_neg_integer()
  def line_count(%__MODULE__{ref: ref}) do
    EditBufferNIF.get_line_count(ref)
  end

  @doc """
  Delete a range of text between two cursor positions.

  Coordinates are `{row, col}` pairs (0-indexed, display-width columns).
  """
  @spec delete_range(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def delete_range(%__MODULE__{ref: ref} = buf, r1, c1, r2, c2)
      when is_integer(r1) and is_integer(c1) and is_integer(r2) and is_integer(c2) do
    EditBufferNIF.delete_range(ref, r1, c1, r2, c2)
    buf
  end

  @doc "Clear all text from the buffer."
  @spec clear(t()) :: t()
  def clear(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.eb_clear(ref)
    buf
  end

  @doc "Check whether there are any operations to undo."
  @spec can_undo?(t()) :: boolean()
  def can_undo?(%__MODULE__{ref: ref}) do
    EditBufferNIF.can_undo(ref)
  end

  @doc "Check whether there are any operations to redo."
  @spec can_redo?(t()) :: boolean()
  def can_redo?(%__MODULE__{ref: ref}) do
    EditBufferNIF.can_redo(ref)
  end

  @doc "Clear the undo/redo history."
  @spec clear_history(t()) :: t()
  def clear_history(%__MODULE__{ref: ref} = buf) do
    EditBufferNIF.clear_history(ref)
    buf
  end

  @doc """
  Get the end-of-line cursor position as `{row, col, offset}`.
  """
  @spec get_eol(t()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def get_eol(%__MODULE__{ref: ref}) do
    EditBufferNIF.get_eol_eb(ref)
  end

  @doc """
  Get the next word boundary cursor position as `{row, col, offset}`.
  """
  @spec get_next_word_boundary(t()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def get_next_word_boundary(%__MODULE__{ref: ref}) do
    EditBufferNIF.get_next_word_boundary_eb(ref)
  end

  @doc """
  Get the previous word boundary cursor position as `{row, col, offset}`.
  """
  @spec get_prev_word_boundary(t()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def get_prev_word_boundary(%__MODULE__{ref: ref}) do
    EditBufferNIF.get_prev_word_boundary_eb(ref)
  end

  @doc """
  Get text in the given display-width offset range.
  """
  @spec get_text_range(t(), non_neg_integer(), non_neg_integer()) :: String.t()
  def get_text_range(%__MODULE__{ref: ref}, start_offset, end_offset)
      when is_integer(start_offset) and is_integer(end_offset) do
    EditBufferNIF.get_text_range(ref, start_offset, end_offset)
  end

  @doc """
  Get text in the given coordinate range `(r1, c1)` to `(r2, c2)`.

  Coordinates are 0-indexed, display-width columns.
  """
  @spec get_text_range_by_coords(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: String.t()
  def get_text_range_by_coords(%__MODULE__{ref: ref}, r1, c1, r2, c2)
      when is_integer(r1) and is_integer(c1) and is_integer(r2) and is_integer(c2) do
    EditBufferNIF.get_text_range_by_coords(ref, r1, c1, r2, c2)
  end
end
