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
    extra_modules: [opentui_api: {:opentui, :opentui}],
    precompiled: ElixirOpentui.Precompiled.edit_buffer_nif_precompiled()

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

  const EditBufferData = struct {
      edit_buffer: *EditBuffer,
      pool: *GraphemePool,
  };

  const EditBufferCallbacks = struct {
      pub fn dtor(data: *EditBufferData) void {
          data.edit_buffer.deinit();
          data.pool.deinit();
          beam.allocator.destroy(data.pool);
      }
  };

  pub const EditBufferResource = beam.Resource(EditBufferData, root, .{ .Callbacks = EditBufferCallbacks });

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

  pub fn set_text(resource: EditBufferResource, text: []const u8) !void {
      const data = resource.unpack();
      try data.edit_buffer.setText(text);
  }

  pub fn get_text(resource: EditBufferResource) ![]u8 {
      const gpa = beam.allocator;
      const data = resource.unpack();
      const byte_size = @max(1, data.edit_buffer.tb.getByteSize());
      const buf = try gpa.alloc(u8, byte_size);
      defer gpa.free(buf);
      const len = data.edit_buffer.getText(buf);
      const result = try gpa.alloc(u8, len);
      @memcpy(result, buf[0..len]);
      return result;
  }

  pub fn get_cursor(resource: EditBufferResource) beam.term {
      const data = resource.unpack();
      const pos = data.edit_buffer.getCursorPosition();
      return beam.make(.{ pos.line, pos.visual_col, pos.offset }, .{});
  }

  pub fn set_cursor(resource: EditBufferResource, row: u32, col: u32) !void {
      const data = resource.unpack();
      try data.edit_buffer.setCursor(row, col);
  }

  pub fn set_cursor_by_offset(resource: EditBufferResource, offset: u32) !void {
      const data = resource.unpack();
      try data.edit_buffer.setCursorByOffset(offset);
  }

  pub fn insert_char(resource: EditBufferResource, text: []const u8) !void {
      const data = resource.unpack();
      try data.edit_buffer.insertText(text);
  }

  pub fn delete_char_backward(resource: EditBufferResource) !void {
      const data = resource.unpack();
      try data.edit_buffer.backspace();
  }

  pub fn delete_char_forward(resource: EditBufferResource) !void {
      const data = resource.unpack();
      try data.edit_buffer.deleteForward();
  }

  pub fn move_cursor_left(resource: EditBufferResource) void {
      const data = resource.unpack();
      data.edit_buffer.moveLeft();
  }

  pub fn move_cursor_right(resource: EditBufferResource) void {
      const data = resource.unpack();
      data.edit_buffer.moveRight();
  }

  pub fn new_line(resource: EditBufferResource) !void {
      const data = resource.unpack();
      try data.edit_buffer.insertText("\n");
  }

  pub fn delete_line(resource: EditBufferResource) !void {
      const data = resource.unpack();
      try data.edit_buffer.deleteLine();
  }

  pub fn undo(resource: EditBufferResource) !beam.term {
      const data = resource.unpack();
      const meta = data.edit_buffer.undo() catch return beam.make(.nil, .{});
      if (meta.len == 0) return beam.make(.nil, .{});
      return beam.make(meta, .{});
  }

  pub fn redo(resource: EditBufferResource) !beam.term {
      const data = resource.unpack();
      const meta = data.edit_buffer.redo() catch return beam.make(.nil, .{});
      if (meta.len == 0) return beam.make(.nil, .{});
      return beam.make(meta, .{});
  }

  pub fn get_line_count(resource: EditBufferResource) u32 {
      const data = resource.unpack();
      return data.edit_buffer.tb.lineCount();
  }

  const EditorViewData = struct {
      editor_view: *EditorView,
      edit_buffer_ref: EditBufferResource, // prevents GC of parent EditBuffer
  };

  const EditorViewCallbacks = struct {
      pub fn dtor(data: *EditorViewData) void {
          // Cannot call editor_view.deinit() or text_buffer_view.deinit() because
          // they access edit_buffer internals (events, rope) which may already be
          // freed — BEAM GC doesn't guarantee destructor ordering between resources.
          data.editor_view.global_allocator.destroy(data.editor_view);
      }
  };

  pub const EditorViewResource = beam.Resource(EditorViewData, root, .{ .Callbacks = EditorViewCallbacks });

  pub fn create_editor_view(edit_buf: EditBufferResource, width: u32, height: u32) !EditorViewResource {
      const gpa = beam.allocator;
      const eb_data = edit_buf.unpack();
      const editor_view = EditorView.init(gpa, eb_data.edit_buffer, width, height) catch return error.OutOfMemory;

      return EditorViewResource.create(.{
          .editor_view = editor_view,
          .edit_buffer_ref = edit_buf,
      }, .{});
  }

  pub fn view_set_viewport_size(view: EditorViewResource, width: u32, height: u32) void {
      const data = view.unpack();
      data.editor_view.setViewportSize(width, height);
  }

  pub fn view_get_viewport(view: EditorViewResource) beam.term {
      const data = view.unpack();
      if (data.editor_view.getViewport()) |vp| {
          return beam.make(.{ vp.x, vp.y, vp.width, vp.height }, .{});
      }
      return beam.make(.nil, .{});
  }

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

  pub fn view_move_up_visual(view: EditorViewResource) void {
      const data = view.unpack();
      data.editor_view.moveUpVisual();
  }

  pub fn view_move_down_visual(view: EditorViewResource) void {
      const data = view.unpack();
      data.editor_view.moveDownVisual();
  }

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

  pub fn view_set_scroll_margin(view: EditorViewResource, margin: f32) void {
      const data = view.unpack();
      data.editor_view.setScrollMargin(margin);
  }

  pub fn view_get_total_virtual_line_count(view: EditorViewResource) u32 {
      const data = view.unpack();
      return data.editor_view.getTotalVirtualLineCount();
  }

  pub fn view_set_selection(view: EditorViewResource, start: u32, end: u32) void {
      const data = view.unpack();
      data.editor_view.setSelection(start, end, null, null);
  }

  pub fn view_reset_selection(view: EditorViewResource) void {
      const data = view.unpack();
      data.editor_view.resetSelection();
  }

  pub fn view_delete_selected_text(view: EditorViewResource) !void {
      const data = view.unpack();
      try data.editor_view.deleteSelectedText();
  }

  pub fn view_get_selected_text(view: EditorViewResource) ![]u8 {
      const gpa = beam.allocator;
      const data = view.unpack();
      const byte_size = @max(1, data.editor_view.edit_buffer.tb.getByteSize());
      const buf = try gpa.alloc(u8, byte_size);
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

  pub fn view_get_next_word_boundary(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getNextWordBoundary();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }

  pub fn view_get_prev_word_boundary(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getPrevWordBoundary();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }

  pub fn view_get_eol(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getEOL();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }

  pub fn view_get_visual_sol(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getVisualSOL();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }

  pub fn view_get_visual_eol(view: EditorViewResource) beam.term {
      const data = view.unpack();
      const vc = data.editor_view.getVisualEOL();
      return beam.make(.{ vc.visual_row, vc.visual_col, vc.logical_row, vc.logical_col, vc.offset }, .{});
  }

  pub fn get_text_display_width(resource: EditBufferResource) u32 {
      const data = resource.unpack();
      return data.edit_buffer.tb.rope.totalWeight();
  }

  pub fn view_get_visible_lines(view: EditorViewResource) !beam.term {
      const gpa = beam.allocator;
      const data = view.unpack();
      const ev = data.editor_view;

      const vlines = ev.getVirtualLines();
      const count = vlines.len;
      if (count == 0) {
          return beam.make(.{}, .{});
      }

      const byte_size = @max(1, ev.edit_buffer.tb.getByteSize());
      const temp_buf = try gpa.alloc(u8, byte_size);
      defer gpa.free(temp_buf);

      var result_terms: [512]beam.term = undefined;
      const n = @min(count, 512);

      for (0..n) |i| {
          const vline = &vlines[i];
          const src_line = @as(u32, @intCast(vline.source_line));
          const start_col = vline.source_col_offset;
          const end_col = start_col + vline.width;

          const len = ev.edit_buffer.getTextRangeByCoords(src_line, start_col, src_line, end_col, temp_buf);
          const line_bin = try gpa.alloc(u8, len);
          @memcpy(line_bin, temp_buf[0..len]);
          result_terms[i] = beam.make(line_bin, .{});
      }

      return beam.make(result_terms[0..n], .{});
  }

  pub fn view_selection_visual_coords(view: EditorViewResource, sel_start: u32, sel_end: u32) beam.term {
      const data = view.unpack();
      const ev = data.editor_view;

      _ = ev.getViewport() orelse return beam.make(.{ @as(u32, 0), @as(u32, 0), @as(u32, 0), @as(u32, 0) }, .{});

      const saved_cursor = ev.edit_buffer.getPrimaryCursor();

      ev.edit_buffer.setCursorByOffset(sel_start) catch return beam.make(.{ @as(u32, 0), @as(u32, 0), @as(u32, 0), @as(u32, 0) }, .{});
      const start_vc = ev.getVisualCursor();

      ev.edit_buffer.setCursorByOffset(sel_end) catch return beam.make(.{ @as(u32, 0), @as(u32, 0), @as(u32, 0), @as(u32, 0) }, .{});
      const end_vc = ev.getVisualCursor();

      if (ev.edit_buffer.cursors.items.len > 0) {
          ev.edit_buffer.cursors.items[0] = saved_cursor;
      }

      return beam.make(.{ start_vc.visual_row, start_vc.visual_col, end_vc.visual_row, end_vc.visual_col }, .{});
  }

  pub fn view_set_viewport(view: EditorViewResource, x: u32, y: u32, width: u32, height: u32) void {
      const data = view.unpack();
      data.editor_view.setViewport(api.Viewport{ .x = x, .y = y, .width = width, .height = height }, false);
  }
  """

  @wrap_modes %{none: 0, char: 1, word: 2}

  @doc "Convert a wrap mode atom to its integer NIF representation."
  @spec wrap_mode_int(:none | :char | :word) :: 0 | 1 | 2
  def wrap_mode_int(mode), do: Map.fetch!(@wrap_modes, mode)
end
