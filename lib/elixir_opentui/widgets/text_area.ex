defmodule ElixirOpentui.Widgets.TextArea do
  @moduledoc """
  Multi-line text editor widget.

  Wraps the EditBuffer and EditorView NIF resources to provide a full-featured
  textarea with cursor movement, selection, undo/redo, word navigation, and
  line wrapping.

  ## Props
  - `:id` — element id (required for focus)
  - `:value` — initial text value
  - `:placeholder` — placeholder text when empty
  - `:on_change` — message tag sent as `{tag, new_value}` on edit
  - `:on_submit` — message tag sent as `{tag, value}` on Alt+Enter
  - `:width` — display width (default 40)
  - `:height` — display height (default 10)
  - `:wrap` — wrap mode: `:word`, `:char`, or `:none` (default `:word`)
  """

  use ElixirOpentui.Component

  alias ElixirOpentui.EditBufferNIF

  # Wrap mode constants consolidated in EditBufferNIF.wrap_mode_int/1

  # ── Component callbacks ──────────────────────────────────────────────

  @impl true
  def init(props) do
    width = Map.get(props, :width, 40)
    height = Map.get(props, :height, 10)
    wrap = Map.get(props, :wrap, :word)
    value = Map.get(props, :value, "")

    edit_buffer = EditBufferNIF.create()
    editor_view = EditBufferNIF.create_editor_view(edit_buffer, width, height)

    if value != "", do: EditBufferNIF.set_text(edit_buffer, value)

    EditBufferNIF.view_set_wrap_mode(editor_view, EditBufferNIF.wrap_mode_int(wrap))
    EditBufferNIF.view_set_scroll_margin(editor_view, 0.2)

    %{
      id: Map.get(props, :id),
      width: width,
      height: height,
      placeholder: Map.get(props, :placeholder, ""),
      on_change: Map.get(props, :on_change),
      on_submit: Map.get(props, :on_submit),
      edit_buffer: edit_buffer,
      editor_view: editor_view,
      selection: nil,
      scroll_y: 0,
      scroll_x: 0,
      wrap: wrap
    }
  end

  @impl true
  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update(:paste, %{type: :paste, data: data}, state) do
    state = maybe_delete_selection(state)
    EditBufferNIF.insert_char(state.edit_buffer, data)
    sync_scroll(state)
    |> emit_change()
  end

  def update(:mouse, %{type: :mouse} = event, state) do
    handle_mouse(event, state)
  end

  def update(:resize, %{width: w, height: h}, state) do
    EditBufferNIF.view_set_viewport_size(state.editor_view, w, h)
    %{state | width: w, height: h}
    |> sync_scroll()
  end

  def update(:sync_value, %{value: value}, state) do
    EditBufferNIF.set_text(state.edit_buffer, value)
    %{state | selection: nil}
    |> sync_scroll()
  end

  def update(_, _, state), do: state

  @impl true
  def render(state) do
    import ElixirOpentui.View

    lines = EditBufferNIF.view_get_visible_lines(state.editor_view)
    {cursor_row, cursor_col} = get_visual_cursor_pos(state)
    sel_coords = selection_visual_coords(state)

    textarea(
      id: state.id,
      lines: lines,
      cursor_row: cursor_row,
      cursor_col: cursor_col,
      scroll_y: 0,
      placeholder: state.placeholder,
      selection: sel_coords,
      width: state.width,
      height: state.height
    )
  end

  # ── Key handling ─────────────────────────────────────────────────────

  defp handle_key(event, state) do
    action = resolve_action(event)
    execute_action(action, event, state)
  end

  defp resolve_action(%{key: key, ctrl: ctrl, alt: alt, shift: shift} = event) do
    super_ = Map.get(event, :meta, false)

    case {key, ctrl, alt, shift, super_} do
      # Movement
      {:left, false, false, false, false} -> :move_left
      {:right, false, false, false, false} -> :move_right
      {:up, false, false, false, false} -> :move_up
      {:down, false, false, false, false} -> :move_down
      {"f", true, false, false, false} -> :move_right
      {"b", true, false, false, false} -> :move_left

      # Selection (shift+movement)
      {:left, false, false, true, false} -> :select_left
      {:right, false, false, true, false} -> :select_right
      {:up, false, false, true, false} -> :select_up
      {:down, false, false, true, false} -> :select_down

      # Line home/end (logical)
      {"a", true, false, false, false} -> :line_home
      {"e", true, false, false, false} -> :line_end
      {"a", true, false, true, false} -> :select_line_home
      {"e", true, false, true, false} -> :select_line_end

      # Visual line home/end
      {"a", false, true, false, false} -> :visual_line_home
      {"e", false, true, false, false} -> :visual_line_end
      {"a", false, true, true, false} -> :select_visual_line_home
      {"e", false, true, true, false} -> :select_visual_line_end
      {:left, false, false, false, true} -> :visual_line_home
      {:right, false, false, false, true} -> :visual_line_end
      {:left, false, false, true, true} -> :select_visual_line_home
      {:right, false, false, true, true} -> :select_visual_line_end

      # Buffer home/end
      {:home, false, false, false, false} -> :buffer_home
      {:end, false, false, false, false} -> :buffer_end
      {:home, false, false, true, false} -> :select_buffer_home
      {:end, false, false, true, false} -> :select_buffer_end
      {:up, false, false, false, true} -> :buffer_home
      {:down, false, false, false, true} -> :buffer_end
      {:up, false, false, true, true} -> :select_buffer_home
      {:down, false, false, true, true} -> :select_buffer_end

      # Word movement
      {"f", false, true, false, false} -> :word_forward
      {"b", false, true, false, false} -> :word_backward
      {:right, false, true, false, false} -> :word_forward
      {:left, false, true, false, false} -> :word_backward
      {:right, true, false, false, false} -> :word_forward
      {:left, true, false, false, false} -> :word_backward
      {"f", false, true, true, false} -> :select_word_forward
      {"b", false, true, true, false} -> :select_word_backward
      {:right, false, true, true, false} -> :select_word_forward
      {:left, false, true, true, false} -> :select_word_backward

      # Deletion
      {:backspace, false, false, false, false} -> :backspace
      {:backspace, false, false, true, false} -> :backspace
      {:delete, false, false, false, false} -> :delete
      {:delete, false, false, true, false} -> :delete
      {"d", true, false, false, false} -> :delete
      {"w", true, false, false, false} -> :delete_word_backward
      {:backspace, true, false, false, false} -> :delete_word_backward
      {:backspace, false, true, false, false} -> :delete_word_backward
      {"d", false, true, false, false} -> :delete_word_forward
      {:delete, false, true, false, false} -> :delete_word_forward
      {:delete, true, false, false, false} -> :delete_word_forward
      {"d", true, false, true, false} -> :delete_line
      {"k", true, false, false, false} -> :delete_to_line_end
      {"u", true, false, false, false} -> :delete_to_line_start

      # Editing
      {:enter, false, false, false, false} -> :newline
      {:enter, false, true, false, false} -> :submit

      # Undo/Redo
      {"z", true, false, false, false} -> :undo
      {"y", true, false, false, false} -> :redo
      {"-", true, false, false, false} -> :undo
      {".", true, false, false, false} -> :redo
      {"z", false, false, false, true} -> :undo
      {"z", false, false, true, true} -> :redo

      # Select all
      {"a", false, false, false, true} -> :select_all

      # Character input - printable single chars without ctrl/alt/meta/super
      {ch, false, false, _, false} when is_binary(ch) -> :insert_char

      _ -> :noop
    end
  end

  # ── Action execution ─────────────────────────────────────────────────

  defp execute_action(:noop, _event, state), do: state

  # Movement actions
  defp execute_action(:move_left, _event, state) do
    state = collapse_selection_to(:start, state)
    EditBufferNIF.move_cursor_left(state.edit_buffer)
    sync_scroll(state)
  end

  defp execute_action(:move_right, _event, state) do
    state = collapse_selection_to(:end, state)
    EditBufferNIF.move_cursor_right(state.edit_buffer)
    sync_scroll(state)
  end

  defp execute_action(:move_up, _event, state) do
    state = collapse_selection(state)
    EditBufferNIF.view_move_up_visual(state.editor_view)
    sync_scroll(state)
  end

  defp execute_action(:move_down, _event, state) do
    state = collapse_selection(state)
    EditBufferNIF.view_move_down_visual(state.editor_view)
    sync_scroll(state)
  end

  # Selection movement
  defp execute_action(:select_left, _event, state) do
    state = start_or_continue_selection(state)
    EditBufferNIF.move_cursor_left(state.edit_buffer)
    update_selection_focus(state)
    |> sync_scroll()
  end

  defp execute_action(:select_right, _event, state) do
    state = start_or_continue_selection(state)
    EditBufferNIF.move_cursor_right(state.edit_buffer)
    update_selection_focus(state)
    |> sync_scroll()
  end

  defp execute_action(:select_up, _event, state) do
    state = start_or_continue_selection(state)
    EditBufferNIF.view_move_up_visual(state.editor_view)
    update_selection_focus(state)
    |> sync_scroll()
  end

  defp execute_action(:select_down, _event, state) do
    state = start_or_continue_selection(state)
    EditBufferNIF.view_move_down_visual(state.editor_view)
    update_selection_focus(state)
    |> sync_scroll()
  end

  # Line home/end
  defp execute_action(:line_home, _event, state) do
    state = collapse_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_eol(state.editor_view)
    {row, _col, _off} = EditBufferNIF.get_cursor(state.edit_buffer)
    EditBufferNIF.set_cursor(state.edit_buffer, row, 0)
    _ = offset
    sync_scroll(state)
  end

  defp execute_action(:line_end, _event, state) do
    state = collapse_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_eol(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    sync_scroll(state)
  end

  defp execute_action(:select_line_home, _event, state) do
    state = start_or_continue_selection(state)
    {row, _col, _off} = EditBufferNIF.get_cursor(state.edit_buffer)
    EditBufferNIF.set_cursor(state.edit_buffer, row, 0)
    update_selection_focus(state)
    |> sync_scroll()
  end

  defp execute_action(:select_line_end, _event, state) do
    state = start_or_continue_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_eol(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    update_selection_focus(state)
    |> sync_scroll()
  end

  # Visual line home/end
  defp execute_action(:visual_line_home, _event, state) do
    state = collapse_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_sol(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    sync_scroll(state)
  end

  defp execute_action(:visual_line_end, _event, state) do
    state = collapse_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_eol(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    sync_scroll(state)
  end

  defp execute_action(:select_visual_line_home, _event, state) do
    state = start_or_continue_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_sol(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    update_selection_focus(state)
    |> sync_scroll()
  end

  defp execute_action(:select_visual_line_end, _event, state) do
    state = start_or_continue_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_visual_eol(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    update_selection_focus(state)
    |> sync_scroll()
  end

  # Buffer home/end
  defp execute_action(:buffer_home, _event, state) do
    state = collapse_selection(state)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 0)
    sync_scroll(state)
  end

  defp execute_action(:buffer_end, _event, state) do
    state = collapse_selection(state)
    display_width = EditBufferNIF.get_text_display_width(state.edit_buffer)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, display_width)
    sync_scroll(state)
  end

  defp execute_action(:select_buffer_home, _event, state) do
    state = start_or_continue_selection(state)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, 0)
    update_selection_focus(state)
    |> sync_scroll()
  end

  defp execute_action(:select_buffer_end, _event, state) do
    state = start_or_continue_selection(state)
    display_width = EditBufferNIF.get_text_display_width(state.edit_buffer)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, display_width)
    update_selection_focus(state)
    |> sync_scroll()
  end

  # Word movement
  defp execute_action(:word_forward, _event, state) do
    state = collapse_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_next_word_boundary(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    sync_scroll(state)
  end

  defp execute_action(:word_backward, _event, state) do
    state = collapse_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_prev_word_boundary(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    sync_scroll(state)
  end

  defp execute_action(:select_word_forward, _event, state) do
    state = start_or_continue_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_next_word_boundary(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    update_selection_focus(state)
    |> sync_scroll()
  end

  defp execute_action(:select_word_backward, _event, state) do
    state = start_or_continue_selection(state)
    {_vr, _vc, _lr, _lc, offset} = EditBufferNIF.view_get_prev_word_boundary(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    update_selection_focus(state)
    |> sync_scroll()
  end

  # Deletion
  defp execute_action(:backspace, _event, state) do
    if has_selection?(state) do
      delete_selection(state)
    else
      EditBufferNIF.delete_char_backward(state.edit_buffer)
      sync_scroll(state)
    end
    |> emit_change()
  end

  defp execute_action(:delete, _event, state) do
    if has_selection?(state) do
      delete_selection(state)
    else
      EditBufferNIF.delete_char_forward(state.edit_buffer)
      sync_scroll(state)
    end
    |> emit_change()
  end

  defp execute_action(:delete_word_backward, _event, state) do
    if has_selection?(state) do
      delete_selection(state)
    else
      {_vr, _vc, _lr, _lc, target} = EditBufferNIF.view_get_prev_word_boundary(state.editor_view)
      {_row, _col, current} = EditBufferNIF.get_cursor(state.edit_buffer)
      delete_range_by_offsets(state, target, current)
    end
    |> emit_change()
  end

  defp execute_action(:delete_word_forward, _event, state) do
    if has_selection?(state) do
      delete_selection(state)
    else
      {_vr, _vc, _lr, _lc, target} = EditBufferNIF.view_get_next_word_boundary(state.editor_view)
      {_row, _col, current} = EditBufferNIF.get_cursor(state.edit_buffer)
      delete_range_by_offsets(state, current, target)
    end
    |> emit_change()
  end

  defp execute_action(:delete_line, _event, state) do
    state = clear_selection(state)
    EditBufferNIF.delete_line(state.edit_buffer)
    sync_scroll(state)
    |> emit_change()
  end

  defp execute_action(:delete_to_line_end, _event, state) do
    if has_selection?(state) do
      delete_selection(state)
    else
      {_vr, _vc, _lr, _lc, eol_offset} = EditBufferNIF.view_get_eol(state.editor_view)
      {_row, _col, current} = EditBufferNIF.get_cursor(state.edit_buffer)
      delete_range_by_offsets(state, current, eol_offset)
    end
    |> emit_change()
  end

  defp execute_action(:delete_to_line_start, _event, state) do
    if has_selection?(state) do
      delete_selection(state)
    else
      {row, _col, current} = EditBufferNIF.get_cursor(state.edit_buffer)
      EditBufferNIF.set_cursor(state.edit_buffer, row, 0)
      {_row2, _col2, line_start} = EditBufferNIF.get_cursor(state.edit_buffer)
      # Restore cursor, then delete the range
      EditBufferNIF.set_cursor_by_offset(state.edit_buffer, current)
      delete_range_by_offsets(state, line_start, current)
    end
    |> emit_change()
  end

  # Editing
  defp execute_action(:newline, _event, state) do
    state = maybe_delete_selection(state)
    EditBufferNIF.new_line(state.edit_buffer)
    sync_scroll(state)
    |> emit_change()
  end

  defp execute_action(:submit, _event, state) do
    emit_submit(state)
  end

  # Undo/Redo
  defp execute_action(:undo, _event, state) do
    EditBufferNIF.undo(state.edit_buffer)
    %{state | selection: nil}
    |> apply_nif_selection_reset()
    |> sync_scroll()
    |> emit_change()
  end

  defp execute_action(:redo, _event, state) do
    EditBufferNIF.redo(state.edit_buffer)
    %{state | selection: nil}
    |> apply_nif_selection_reset()
    |> sync_scroll()
    |> emit_change()
  end

  # Select all
  defp execute_action(:select_all, _event, state) do
    display_width = EditBufferNIF.get_text_display_width(state.edit_buffer)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, display_width)
    state = %{state | selection: %{anchor: 0, focus: display_width}}
    EditBufferNIF.view_set_selection(state.editor_view, 0, display_width)
    sync_scroll(state)
  end

  # Character input
  defp execute_action(:insert_char, %{key: ch}, state) do
    state = maybe_delete_selection(state)
    EditBufferNIF.insert_char(state.edit_buffer, ch)
    sync_scroll(state)
    |> emit_change()
  end

  # ── Mouse handling ───────────────────────────────────────────────────

  defp handle_mouse(%{action: :scroll, direction: dir}, state) do
    {_ox, oy, _w, _h} = EditBufferNIF.view_get_viewport(state.editor_view)
    total = EditBufferNIF.view_get_total_virtual_line_count(state.editor_view)

    new_oy =
      case dir do
        :up -> max(0, oy - 3)
        :down -> min(max(0, total - state.height), oy + 3)
        _ -> oy
      end

    EditBufferNIF.view_set_viewport(state.editor_view, 0, new_oy, state.width, state.height)
    %{state | scroll_y: new_oy}
  end

  defp handle_mouse(_event, state), do: state

  # ── Selection helpers ────────────────────────────────────────────────

  defp has_selection?(%{selection: nil}), do: false
  defp has_selection?(%{selection: %{anchor: a, focus: f}}) when a == f, do: false
  defp has_selection?(_), do: true

  defp start_or_continue_selection(%{selection: nil} = state) do
    {_row, _col, offset} = EditBufferNIF.get_cursor(state.edit_buffer)
    %{state | selection: %{anchor: offset, focus: offset}}
  end

  defp start_or_continue_selection(state), do: state

  defp update_selection_focus(state) do
    {_row, _col, offset} = EditBufferNIF.get_cursor(state.edit_buffer)
    sel = %{state.selection | focus: offset}
    state = %{state | selection: sel}

    {sel_start, sel_end} = selection_range(sel)
    EditBufferNIF.view_set_selection(state.editor_view, sel_start, sel_end)
    state
  end

  defp collapse_selection(%{selection: nil} = state), do: state

  defp collapse_selection(state) do
    EditBufferNIF.view_reset_selection(state.editor_view)
    %{state | selection: nil}
  end

  defp collapse_selection_to(_side, %{selection: nil} = state), do: state

  defp collapse_selection_to(side, %{selection: %{anchor: a, focus: f}} = state) do
    {sel_start, sel_end} = if a <= f, do: {a, f}, else: {f, a}

    offset =
      case side do
        :start -> sel_start
        :end -> sel_end
      end

    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, offset)
    EditBufferNIF.view_reset_selection(state.editor_view)
    %{state | selection: nil}
  end

  defp clear_selection(state) do
    EditBufferNIF.view_reset_selection(state.editor_view)
    %{state | selection: nil}
  end

  defp maybe_delete_selection(state) do
    if has_selection?(state) do
      delete_selection(state)
    else
      state
    end
  end

  defp delete_selection(state) do
    {sel_start, _sel_end} = selection_range(state.selection)
    EditBufferNIF.view_delete_selected_text(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, sel_start)
    EditBufferNIF.view_reset_selection(state.editor_view)
    %{state | selection: nil}
    |> sync_scroll()
  end

  defp selection_range(%{anchor: a, focus: f}) when a <= f, do: {a, f}
  defp selection_range(%{anchor: a, focus: f}), do: {f, a}

  defp apply_nif_selection_reset(state) do
    EditBufferNIF.view_reset_selection(state.editor_view)
    state
  end

  defp delete_range_by_offsets(state, from_offset, to_offset) when from_offset < to_offset do
    state = clear_selection(state)
    # Select the range, then delete it
    EditBufferNIF.view_set_selection(state.editor_view, from_offset, to_offset)
    EditBufferNIF.view_delete_selected_text(state.editor_view)
    EditBufferNIF.set_cursor_by_offset(state.edit_buffer, from_offset)
    EditBufferNIF.view_reset_selection(state.editor_view)
    sync_scroll(state)
  end

  defp delete_range_by_offsets(state, _from, _to), do: state

  # ── Viewport helpers ─────────────────────────────────────────────────

  defp sync_scroll(state) do
    case EditBufferNIF.view_get_viewport(state.editor_view) do
      {ox, oy, _w, _h} -> %{state | scroll_x: ox, scroll_y: oy}
      nil -> state
    end
  end

  defp get_visual_cursor_pos(state) do
    {vr, vc, _lr, _lc, _offset} = EditBufferNIF.view_get_visual_cursor(state.editor_view)
    {vr, vc}
  end

  defp selection_visual_coords(%{selection: nil}), do: nil

  defp selection_visual_coords(%{selection: %{anchor: a, focus: f}}) when a == f, do: nil

  defp selection_visual_coords(%{selection: %{anchor: a, focus: f}} = state) do
    {sel_start, sel_end} = if a <= f, do: {a, f}, else: {f, a}
    {sr, sc, er, ec} = EditBufferNIF.view_selection_visual_coords(state.editor_view, sel_start, sel_end)
    %{start_row: sr, start_col: sc, end_row: er, end_col: ec}
  end

  # ── Change/Submit emission ───────────────────────────────────────────

  defp emit_change(%{on_change: nil} = state), do: state

  defp emit_change(%{on_change: tag} = state) do
    text = EditBufferNIF.get_text(state.edit_buffer)
    send(self(), {tag, text})
    state
  end

  defp emit_submit(%{on_submit: nil} = state), do: state

  defp emit_submit(%{on_submit: tag} = state) do
    text = EditBufferNIF.get_text(state.edit_buffer)
    send(self(), {tag, text})
    state
  end
end
