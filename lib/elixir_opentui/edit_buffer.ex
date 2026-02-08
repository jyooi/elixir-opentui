defmodule ElixirOpentui.EditBuffer do
  @moduledoc """
  Editable text buffer with cursor and selection support.

  Maps to ElixirOpentui's EditBuffer: supports setText/getText, cursor movement,
  insertion, deletion, and selection ranges.
  """

  @type t :: %__MODULE__{
          text: String.t(),
          cursor: non_neg_integer(),
          selection_start: non_neg_integer() | nil,
          selection_end: non_neg_integer() | nil
        }

  defstruct text: "",
            cursor: 0,
            selection_start: nil,
            selection_end: nil

  @doc "Create an empty EditBuffer."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Create an EditBuffer with initial text."
  @spec from_text(String.t()) :: t()
  def from_text(text) when is_binary(text) do
    %__MODULE__{text: text, cursor: String.length(text)}
  end

  @doc "Get the buffer text."
  @spec get_text(t()) :: String.t()
  def get_text(%__MODULE__{text: text}), do: text

  @doc "Set the buffer text, clamping cursor."
  @spec set_text(t(), String.t()) :: t()
  def set_text(%__MODULE__{} = buf, text) do
    len = String.length(text)
    %{buf | text: text, cursor: min(buf.cursor, len), selection_start: nil, selection_end: nil}
  end

  @doc "Get the cursor position (grapheme index)."
  @spec get_cursor(t()) :: non_neg_integer()
  def get_cursor(%__MODULE__{cursor: cursor}), do: cursor

  @doc "Set cursor position, clamped to valid range."
  @spec set_cursor(t(), integer()) :: t()
  def set_cursor(%__MODULE__{text: text} = buf, pos) do
    len = String.length(text)
    clamped = pos |> max(0) |> min(len)
    %{buf | cursor: clamped, selection_start: nil, selection_end: nil}
  end

  @doc "Move cursor left by n graphemes."
  @spec move_left(t(), non_neg_integer()) :: t()
  def move_left(%__MODULE__{cursor: cursor} = buf, n \\ 1) do
    set_cursor(buf, cursor - n)
  end

  @doc "Move cursor right by n graphemes."
  @spec move_right(t(), non_neg_integer()) :: t()
  def move_right(%__MODULE__{cursor: cursor} = buf, n \\ 1) do
    set_cursor(buf, cursor + n)
  end

  @doc "Move cursor to start of text."
  @spec move_home(t()) :: t()
  def move_home(%__MODULE__{} = buf), do: set_cursor(buf, 0)

  @doc "Move cursor to end of text."
  @spec move_end(t()) :: t()
  def move_end(%__MODULE__{text: text} = buf), do: set_cursor(buf, String.length(text))

  @doc "Insert text at cursor position."
  @spec insert(t(), String.t()) :: t()
  def insert(%__MODULE__{text: text, cursor: cursor} = buf, str) do
    {before, after_cursor} = split_at(text, cursor)
    new_text = before <> str <> after_cursor
    insert_len = String.length(str)
    %{buf | text: new_text, cursor: cursor + insert_len, selection_start: nil, selection_end: nil}
  end

  @doc "Delete n graphemes before cursor (backspace)."
  @spec delete_backward(t(), non_neg_integer()) :: t()
  def delete_backward(buf, n \\ 1)
  def delete_backward(%__MODULE__{cursor: 0} = buf, _n), do: buf

  def delete_backward(%__MODULE__{text: text, cursor: cursor} = buf, n) do
    delete_count = min(n, cursor)
    {before, after_cursor} = split_at(text, cursor)
    trimmed_before = String.slice(before, 0, String.length(before) - delete_count)
    %{buf | text: trimmed_before <> after_cursor, cursor: cursor - delete_count}
  end

  @doc "Delete n graphemes after cursor (delete key)."
  @spec delete_forward(t(), non_neg_integer()) :: t()
  def delete_forward(%__MODULE__{text: text, cursor: cursor} = buf, n \\ 1) do
    len = String.length(text)

    if cursor >= len do
      buf
    else
      {before, after_cursor} = split_at(text, cursor)
      remaining = String.slice(after_cursor, min(n, String.length(after_cursor)), len)
      %{buf | text: before <> (remaining || "")}
    end
  end

  @doc "Select a range of text."
  @spec select(t(), non_neg_integer(), non_neg_integer()) :: t()
  def select(%__MODULE__{text: text} = buf, start, finish) do
    len = String.length(text)
    s = start |> max(0) |> min(len)
    e = finish |> max(0) |> min(len)
    {s, e} = if s > e, do: {e, s}, else: {s, e}
    %{buf | selection_start: s, selection_end: e}
  end

  @doc "Get selected text, or nil if no selection."
  @spec get_selection(t()) :: String.t() | nil
  def get_selection(%__MODULE__{selection_start: nil}), do: nil
  def get_selection(%__MODULE__{selection_end: nil}), do: nil

  def get_selection(%__MODULE__{text: text, selection_start: s, selection_end: e}) do
    String.slice(text, s, e - s)
  end

  @doc "Delete the selected text and place cursor at selection start."
  @spec delete_selection(t()) :: t()
  def delete_selection(%__MODULE__{selection_start: nil} = buf), do: buf
  def delete_selection(%__MODULE__{selection_end: nil} = buf), do: buf

  def delete_selection(%__MODULE__{text: text, selection_start: s, selection_end: e}) do
    {before, _} = split_at(text, s)
    {_, after_sel} = split_at(text, e)
    %__MODULE__{text: before <> after_sel, cursor: s}
  end

  @doc "Get text length in graphemes."
  @spec length(t()) :: non_neg_integer()
  def length(%__MODULE__{text: text}), do: String.length(text)

  defp split_at(text, pos) do
    before = String.slice(text, 0, pos)
    after_part = String.slice(text, pos, String.length(text) - pos)
    {before, after_part || ""}
  end
end
