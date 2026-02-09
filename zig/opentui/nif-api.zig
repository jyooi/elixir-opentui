// NIF API entry point - re-exports types needed by the NIF bindings
pub const edit_buffer = @import("edit-buffer.zig");
pub const editor_view = @import("editor-view.zig");
pub const text_buffer = @import("text-buffer.zig");
pub const grapheme = @import("grapheme.zig");
pub const utf8 = @import("utf8.zig");

pub const EditBuffer = edit_buffer.EditBuffer;
pub const EditorView = editor_view.EditorView;
pub const VisualCursor = editor_view.VisualCursor;
pub const GraphemePool = grapheme.GraphemePool;
pub const WidthMethod = utf8.WidthMethod;
pub const WrapMode = text_buffer.WrapMode;
pub const Cursor = edit_buffer.Cursor;
