defmodule ElixirOpentui.EditorView do
  @moduledoc """
  NIF-backed editor viewport with visual line wrapping, selection, and scrolling.

  Wraps the native Zig EditorView which provides viewport-aware text editing
  on top of an EditBuffer. Handles word/char wrapping, scroll margins,
  visual cursor positioning (viewport-relative), and text selection.
  """

  alias ElixirOpentui.EditBuffer
  alias ElixirOpentui.EditBufferNIF

  @type t :: %__MODULE__{
          ref: reference(),
          edit_buffer: EditBuffer.t()
        }

  defstruct [:ref, :edit_buffer]

  @type visual_cursor :: {
          visual_row :: non_neg_integer(),
          visual_col :: non_neg_integer(),
          logical_row :: non_neg_integer(),
          logical_col :: non_neg_integer(),
          offset :: non_neg_integer()
        }

  @type wrap_mode :: :none | :char | :word

  @doc """
  Create a new EditorView for the given EditBuffer with viewport dimensions.

  The viewport width and height are in display-width columns and lines respectively.
  """
  @spec new(EditBuffer.t(), non_neg_integer(), non_neg_integer()) :: t()
  def new(%EditBuffer{ref: eb_ref} = edit_buffer, width, height)
      when is_integer(width) and is_integer(height) do
    ref = EditBufferNIF.create_editor_view(eb_ref, width, height)
    %__MODULE__{ref: ref, edit_buffer: edit_buffer}
  end

  @doc "Resize the viewport."
  @spec set_viewport_size(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_viewport_size(%__MODULE__{ref: ref} = view, width, height)
      when is_integer(width) and is_integer(height) do
    EditBufferNIF.view_set_viewport_size(ref, width, height)
    view
  end

  @doc """
  Get the current viewport as `{offset_x, offset_y, width, height}` or `nil`.
  """
  @spec get_viewport(t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
  def get_viewport(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_viewport(ref)
  end

  @doc """
  Get the visual cursor position as a 5-tuple.

  Returns `{visual_row, visual_col, logical_row, logical_col, offset}`.

  Visual coordinates are viewport-relative (visual_row=0 is the top of the viewport).
  Logical coordinates are document-absolute.
  """
  @spec get_visual_cursor(t()) :: visual_cursor()
  def get_visual_cursor(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_visual_cursor(ref)
  end

  @doc "Move the cursor up one visual line (respects wrapping)."
  @spec move_up_visual(t()) :: t()
  def move_up_visual(%__MODULE__{ref: ref} = view) do
    EditBufferNIF.view_move_up_visual(ref)
    view
  end

  @doc "Move the cursor down one visual line (respects wrapping)."
  @spec move_down_visual(t()) :: t()
  def move_down_visual(%__MODULE__{ref: ref} = view) do
    EditBufferNIF.view_move_down_visual(ref)
    view
  end

  @doc """
  Set the wrap mode.

  - `:none` - no wrapping (lines extend beyond viewport)
  - `:char` - wrap at character boundaries
  - `:word` - wrap at word boundaries
  """
  @spec set_wrap_mode(t(), wrap_mode()) :: t()
  def set_wrap_mode(%__MODULE__{ref: ref} = view, mode) when mode in [:none, :char, :word] do
    EditBufferNIF.view_set_wrap_mode(ref, EditBufferNIF.wrap_mode_int(mode))
    view
  end

  @doc """
  Set the scroll margin as a fraction of viewport height (0.0 to 0.5).

  This controls how close the cursor can get to the viewport edges before
  scrolling kicks in.
  """
  @spec set_scroll_margin(t(), float()) :: t()
  def set_scroll_margin(%__MODULE__{ref: ref} = view, margin) when is_float(margin) do
    EditBufferNIF.view_set_scroll_margin(ref, margin)
    view
  end

  @doc "Get the total number of virtual (visual) lines, accounting for wrapping."
  @spec get_total_virtual_line_count(t()) :: non_neg_integer()
  def get_total_virtual_line_count(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_total_virtual_line_count(ref)
  end

  @doc "Set the selection range by display-width offsets."
  @spec set_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_selection(%__MODULE__{ref: ref} = view, start_offset, end_offset)
      when is_integer(start_offset) and is_integer(end_offset) do
    EditBufferNIF.view_set_selection(ref, start_offset, end_offset)
    view
  end

  @doc "Clear the current selection."
  @spec reset_selection(t()) :: t()
  def reset_selection(%__MODULE__{ref: ref} = view) do
    EditBufferNIF.view_reset_selection(ref)
    view
  end

  @doc "Get the selection range as `{start, end}` or `nil` if no selection."
  @spec get_selection(t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_selection(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_selection(ref)
  end

  @doc "Delete the currently selected text."
  @spec delete_selected_text(t()) :: t()
  def delete_selected_text(%__MODULE__{ref: ref} = view) do
    EditBufferNIF.view_delete_selected_text(ref)
    view
  end

  @doc "Get the currently selected text as a string."
  @spec get_selected_text(t()) :: String.t()
  def get_selected_text(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_selected_text(ref)
  end

  @doc "Set the cursor position by display-width offset."
  @spec set_cursor_by_offset(t(), non_neg_integer()) :: t()
  def set_cursor_by_offset(%__MODULE__{ref: ref} = view, offset) when is_integer(offset) do
    EditBufferNIF.view_set_cursor_by_offset(ref, offset)
    view
  end

  @doc "Get the next word boundary position as a visual cursor tuple."
  @spec get_next_word_boundary(t()) :: visual_cursor()
  def get_next_word_boundary(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_next_word_boundary(ref)
  end

  @doc "Get the previous word boundary position as a visual cursor tuple."
  @spec get_prev_word_boundary(t()) :: visual_cursor()
  def get_prev_word_boundary(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_prev_word_boundary(ref)
  end

  @doc "Get the end-of-line position as a visual cursor tuple."
  @spec get_eol(t()) :: visual_cursor()
  def get_eol(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_eol(ref)
  end

  @doc "Get the visual start-of-line position (accounts for wrapping)."
  @spec get_visual_sol(t()) :: visual_cursor()
  def get_visual_sol(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_visual_sol(ref)
  end

  @doc "Get the visual end-of-line position (accounts for wrapping)."
  @spec get_visual_eol(t()) :: visual_cursor()
  def get_visual_eol(%__MODULE__{ref: ref}) do
    EditBufferNIF.view_get_visual_eol(ref)
  end
end
