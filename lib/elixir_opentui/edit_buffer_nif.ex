defmodule ElixirOpentui.EditBufferNIF do
  @moduledoc """
  Zig NIF module wrapping the OpenTUI EditBuffer and EditorView.

  Provides a rope-based text buffer with undo/redo, cursor management,
  and viewport-aware editor view as NIF resources.
  """

  use Zig,
    otp_app: :elixir_opentui,
    resources: [:EditBufferResource, :EditorViewResource],
    dependencies: [opentui: "./zig/opentui"],
    extra_modules: [opentui_api: {:opentui, :opentui}]

  ~Z"""
  const std = @import("std");
  const beam = @import("beam");
  const root = @import("root");
  const api = @import("opentui_api");

  const EditBuffer = api.EditBuffer;
  const EditorView = api.EditorView;
  const VisualCursor = api.VisualCursor;
  const GraphemePool = api.GraphemePool;
  const WidthMethod = api.WidthMethod;
  const WrapMode = api.WrapMode;

  // ═══════════════════════════════════════════════════════════════════════
  // EditBuffer Resource
  // ═══════════════════════════════════════════════════════════════════════

  const EditBufferData = struct {
      edit_buffer: *EditBuffer,
      pool: *GraphemePool,
  };

  pub const EditBufferResource = beam.Resource(EditBufferData, root, .{});

  // ── create() → EditBufferResource ──────────────────────────────────────
  pub fn create() !EditBufferResource {
      const gpa = beam.allocator;

      const pool = try gpa.create(GraphemePool);
      pool.* = GraphemePool.init(gpa);

      const edit_buffer = try EditBuffer.init(gpa, pool, WidthMethod.wcwidth);

      return EditBufferResource.create(.{
          .edit_buffer = edit_buffer,
          .pool = pool,
      }, .{});
  }

  // ── set_text(resource, text) → :ok ─────────────────────────────────────
  pub fn set_text(resource: EditBufferResource, text: []const u8) !void {
      const data = resource.unpack();
      try data.edit_buffer.setText(text);
  }

  // ── get_text(resource) → binary ────────────────────────────────────────
  pub fn get_text(resource: EditBufferResource) ![]u8 {
      const gpa = beam.allocator;
      const data = resource.unpack();
      const buf = try gpa.alloc(u8, 1024 * 1024);
      defer gpa.free(buf);
      const len = data.edit_buffer.getText(buf);
      const result = try gpa.alloc(u8, len);
      @memcpy(result, buf[0..len]);
      return result;
  }

  // ── replace_text(resource, text) → :ok ─────────────────────────────────
  pub fn replace_text(resource: EditBufferResource, text: []const u8) !void {
      const data = resource.unpack();
      try data.edit_buffer.replaceText(text);
  }

  // ── get_cursor(resource) → {row, col, offset} ─────────────────────────
  pub fn get_cursor(resource: EditBufferResource) beam.term {
      const data = resource.unpack();
      const pos = data.edit_buffer.getCursorPosition();
      return beam.make(.{ pos.line, pos.visual_col, pos.offset }, .{});
  }

  // ── set_cursor(resource, row, col) → :ok ───────────────────────────────
  pub fn set_cursor(resource: EditBufferResource, row: u32, col: u32) !void {
      const data = resource.unpack();
      try data.edit_buffer.setCursor(row, col);
  }

  // ── set_cursor_by_offset(resource, offset) → :ok ───────────────────────
  pub fn set_cursor_by_offset(resource: EditBufferResource, offset: u32) !void {
      const data = resource.unpack();
      try data.edit_buffer.setCursorByOffset(offset);
  }

  // ── insert_char(resource, text) → :ok ──────────────────────────────────
  pub fn insert_char(resource: EditBufferResource, text: []const u8) !void {
      const data = resource.unpack();
      try data.edit_buffer.insertText(text);
  }

  // ── delete_char_backward(resource) → :ok ───────────────────────────────
  pub fn delete_char_backward(resource: EditBufferResource) !void {
      const data = resource.unpack();
      try data.edit_buffer.backspace();
  }

  // ── delete_char_forward(resource) → :ok ────────────────────────────────
  pub fn delete_char_forward(resource: EditBufferResource) !void {
      const data = resource.unpack();
      try data.edit_buffer.deleteForward();
  }

  // ── move_cursor_left(resource) → :ok ───────────────────────────────────
  pub fn move_cursor_left(resource: EditBufferResource) void {
      const data = resource.unpack();
      data.edit_buffer.moveLeft();
  }

  // ── move_cursor_right(resource) → :ok ──────────────────────────────────
  pub fn move_cursor_right(resource: EditBufferResource) void {
      const data = resource.unpack();
      data.edit_buffer.moveRight();
  }

  // ── move_cursor_up(resource) → :ok ─────────────────────────────────────
  pub fn move_cursor_up(resource: EditBufferResource) void {
      const data = resource.unpack();
      data.edit_buffer.moveUp();
  }

  // ── move_cursor_down(resource) → :ok ───────────────────────────────────
  pub fn move_cursor_down(resource: EditBufferResource) void {
      const data = resource.unpack();
      data.edit_buffer.moveDown();
  }

  // ── new_line(resource) → :ok ───────────────────────────────────────────
  pub fn new_line(resource: EditBufferResource) !void {
      const data = resource.unpack();
      try data.edit_buffer.insertText("\n");
  }

  // ── delete_line(resource) → :ok ────────────────────────────────────────
  pub fn delete_line(resource: EditBufferResource) !void {
      const data = resource.unpack();
      try data.edit_buffer.deleteLine();
  }

  // ── goto_line(resource, line) → :ok ────────────────────────────────────
  pub fn goto_line(resource: EditBufferResource, line: u32) !void {
      const data = resource.unpack();
      try data.edit_buffer.gotoLine(line);
  }

  // ── undo(resource) → binary | nil ──────────────────────────────────────
  pub fn undo(resource: EditBufferResource) !beam.term {
      const data = resource.unpack();
      const meta = data.edit_buffer.undo() catch return beam.make(.nil, .{});
      if (meta.len == 0) return beam.make(.nil, .{});
      return beam.make(meta, .{});
  }

  // ── redo(resource) → binary | nil ──────────────────────────────────────
  pub fn redo(resource: EditBufferResource) !beam.term {
      const data = resource.unpack();
      const meta = data.edit_buffer.redo() catch return beam.make(.nil, .{});
      if (meta.len == 0) return beam.make(.nil, .{});
      return beam.make(meta, .{});
  }

  // ── get_line_count(resource) → u32 ─────────────────────────────────────
  pub fn get_line_count(resource: EditBufferResource) u32 {
      const data = resource.unpack();
      return data.edit_buffer.tb.lineCount();
  }

  // ── delete_range(resource, r1, c1, r2, c2) → :ok ─────────────────────
  pub fn delete_range(resource: EditBufferResource, r1: u32, c1: u32, r2: u32, c2: u32) !void {
      const data = resource.unpack();
      const start = api.Cursor{ .row = r1, .col = c1 };
      const end_cur = api.Cursor{ .row = r2, .col = c2 };
      try data.edit_buffer.deleteRange(start, end_cur);
  }

  // ── clear(resource) → :ok ────────────────────────────────────────────
  pub fn eb_clear(resource: EditBufferResource) !void {
      const data = resource.unpack();
      try data.edit_buffer.clear();
  }

  // ── can_undo(resource) → bool ────────────────────────────────────────
  pub fn can_undo(resource: EditBufferResource) bool {
      const data = resource.unpack();
      return data.edit_buffer.canUndo();
  }

  // ── can_redo(resource) → bool ────────────────────────────────────────
  pub fn can_redo(resource: EditBufferResource) bool {
      const data = resource.unpack();
      return data.edit_buffer.canRedo();
  }

  // ── clear_history(resource) → :ok ────────────────────────────────────
  pub fn clear_history(resource: EditBufferResource) void {
      const data = resource.unpack();
      data.edit_buffer.clearHistory();
  }

  // ── get_eol_eb(resource) → {row, col, offset} ───────────────────────
  pub fn get_eol_eb(resource: EditBufferResource) beam.term {
      const data = resource.unpack();
      const cursor = data.edit_buffer.getEOL();
      return beam.make(.{ cursor.row, cursor.col, cursor.offset }, .{});
  }

  // ── get_next_word_boundary_eb(resource) → {row, col, offset} ────────
  pub fn get_next_word_boundary_eb(resource: EditBufferResource) beam.term {
      const data = resource.unpack();
      const cursor = data.edit_buffer.getNextWordBoundary();
      return beam.make(.{ cursor.row, cursor.col, cursor.offset }, .{});
  }

  // ── get_prev_word_boundary_eb(resource) → {row, col, offset} ────────
  pub fn get_prev_word_boundary_eb(resource: EditBufferResource) beam.term {
      const data = resource.unpack();
      const cursor = data.edit_buffer.getPrevWordBoundary();
      return beam.make(.{ cursor.row, cursor.col, cursor.offset }, .{});
  }

  // ── get_text_range(resource, start_offset, end_offset) → binary ─────
  pub fn get_text_range(resource: EditBufferResource, start_offset: u32, end_offset: u32) ![]u8 {
      const gpa = beam.allocator;
      const data = resource.unpack();
      const buf = try gpa.alloc(u8, 1024 * 1024);
      defer gpa.free(buf);
      const len = try data.edit_buffer.getTextRange(start_offset, end_offset, buf);
      const result = try gpa.alloc(u8, len);
      @memcpy(result, buf[0..len]);
      return result;
  }

  // ── get_text_range_by_coords(resource, r1, c1, r2, c2) → binary ────
  pub fn get_text_range_by_coords(resource: EditBufferResource, r1: u32, c1: u32, r2: u32, c2: u32) ![]u8 {
      const gpa = beam.allocator;
      const data = resource.unpack();
      const buf = try gpa.alloc(u8, 1024 * 1024);
      defer gpa.free(buf);
      const len = data.edit_buffer.getTextRangeByCoords(r1, c1, r2, c2, buf);
      const result = try gpa.alloc(u8, len);
      @memcpy(result, buf[0..len]);
      return result;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EditorView Resource
  // ═══════════════════════════════════════════════════════════════════════

  const EditorViewData = struct {
      editor_view: *EditorView,
  };

  pub const EditorViewResource = beam.Resource(EditorViewData, root, .{});

  // ── create_editor_view(edit_buf_resource, width, height) → EditorViewResource
  pub fn create_editor_view(edit_buf: EditBufferResource, width: u32, height: u32) !EditorViewResource {
      const gpa = beam.allocator;
      const eb_data = edit_buf.unpack();
      const editor_view = EditorView.init(gpa, eb_data.edit_buffer, width, height) catch return error.OutOfMemory;

      return EditorViewResource.create(.{
          .editor_view = editor_view,
      }, .{});
  }

  // ── view_set_viewport_size(view, width, height) → :ok ─────────────────
  pub fn view_set_viewport_size(view: EditorViewResource, width: u32, height: u32) void {
      const data = view.unpack();
      data.editor_view.setViewportSize(width, height);
  }

  // ── view_get_viewport(view) → {offset_x, offset_y, width, height} | nil
  pub fn view_get_viewport(view: EditorViewResource) beam.term {
      const data = view.unpack();
      if (data.editor_view.getViewport()) |vp| {
          return beam.make(.{ vp.x, vp.y, vp.width, vp.height }, .{});
      }
      return beam.make(.nil, .{});
  }

  // ── view_get_visual_cursor(view) → {visual_row, visual_col, logical_row, logical_col, offset}
  pub fn view_get_visual_cursor(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getVisualCursor();
      return beam.make(.{
          vc.visual_row,
          vc.visual_col,
          vc.logical_row,
          vc.logical_col,
          vc.offset,
      }, .{});
  }

  // ── view_move_up_visual(view) → :ok ────────────────────────────────────
  pub fn view_move_up_visual(view: EditorViewResource) void {
      const data = view.unpack();
      data.editor_view.moveUpVisual();
  }

  // ── view_move_down_visual(view) → :ok ──────────────────────────────────
  pub fn view_move_down_visual(view: EditorViewResource) void {
      const data = view.unpack();
      data.editor_view.moveDownVisual();
  }

  // ── view_set_wrap_mode(view, mode) → :ok ───────────────────────────────
  // mode: 0 = none, 1 = char, 2 = word
  pub fn view_set_wrap_mode(view: EditorViewResource, mode: u8) void {
      const data = view.unpack();
      const wrap_mode: WrapMode = switch (mode) {
          0 => .none,
          1 => .char,
          2 => .word,
          else => .none,
      };
      data.editor_view.setWrapMode(wrap_mode);
  }

  // ── view_set_scroll_margin(view, margin) → :ok ─────────────────────────
  pub fn view_set_scroll_margin(view: EditorViewResource, margin: f32) void {
      const data = view.unpack();
      data.editor_view.setScrollMargin(margin);
  }

  // ── view_get_total_virtual_line_count(view) → u32 ──────────────────────
  pub fn view_get_total_virtual_line_count(view: EditorViewResource) u32 {
      const data = view.unpack();
      return data.editor_view.getTotalVirtualLineCount();
  }

  // ── view_set_selection(view, start_offset, end_offset) → :ok ───────────
  pub fn view_set_selection(view: EditorViewResource, start: u32, end: u32) void {
      const data = view.unpack();
      data.editor_view.setSelection(start, end, null, null);
  }

  // ── view_reset_selection(view) → :ok ───────────────────────────────────
  pub fn view_reset_selection(view: EditorViewResource) void {
      const data = view.unpack();
      data.editor_view.resetSelection();
  }

  // ── view_get_selection(view) → {start, end} | nil ──────────────────────
  pub fn view_get_selection(view: EditorViewResource) beam.term {
      const data = view.unpack();
      if (data.editor_view.getSelection()) |sel| {
          return beam.make(.{ sel.start, sel.end }, .{});
      }
      return beam.make(.nil, .{});
  }

  // ── view_delete_selected_text(view) → :ok ──────────────────────────────
  pub fn view_delete_selected_text(view: EditorViewResource) !void {
      const data = view.unpack();
      try data.editor_view.deleteSelectedText();
  }

  // ── view_get_selected_text(view) → binary ──────────────────────────────
  pub fn view_get_selected_text(view: EditorViewResource) ![]u8 {
      const gpa = beam.allocator;
      const data = view.unpack();
      const buf = try gpa.alloc(u8, 1024 * 1024);
      defer gpa.free(buf);
      const len = data.editor_view.getSelectedTextIntoBuffer(buf);
      if (len == 0) {
          const empty = try gpa.alloc(u8, 0);
          return empty;
      }
      const result = try gpa.alloc(u8, len);
      @memcpy(result, buf[0..len]);
      return result;
  }

  // ── view_set_cursor_by_offset(view, offset) → :ok ─────────────────────
  pub fn view_set_cursor_by_offset(view: EditorViewResource, offset: u32) !void {
      const data = view.unpack();
      try data.editor_view.setCursorByOffset(offset);
  }

  // ── view_get_next_word_boundary(view) → {visual_row, visual_col, logical_row, logical_col, offset}
  pub fn view_get_next_word_boundary(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getNextWordBoundary();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }

  // ── view_get_prev_word_boundary(view) → {visual_row, visual_col, logical_row, logical_col, offset}
  pub fn view_get_prev_word_boundary(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getPrevWordBoundary();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }

  // ── view_get_eol(view) → {visual_row, visual_col, logical_row, logical_col, offset}
  pub fn view_get_eol(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getEOL();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }

  // ── view_get_visual_sol(view) → {visual_row, visual_col, logical_row, logical_col, offset}
  pub fn view_get_visual_sol(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getVisualSOL();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }

  // ── view_get_visual_eol(view) → {visual_row, visual_col, logical_row, logical_col, offset}
  pub fn view_get_visual_eol(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getVisualEOL();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }
  """

  @doc "Check if the EditBuffer NIF is available."
  @spec available?() :: boolean()
  def available? do
    try do
      ref = create()
      is_reference(ref)
    rescue
      _ -> false
    end
  end
end
