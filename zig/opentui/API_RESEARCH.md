# OpenTUI Textarea API Research

Research of the TypeScript API surface from `@opentui/core` for porting to Elixir NIF bindings.

---

## 1. EditBuffer Public API

**Source:** `packages/core/src/edit-buffer.ts`

EditBuffer extends `EventEmitter` and wraps a native Zig rope-based text buffer with undo/redo history.

### Constructor / Factory

| Method | Signature | Description |
|--------|-----------|-------------|
| `EditBuffer.create` | `(widthMethod: WidthMethod) => EditBuffer` | Factory. `WidthMethod` is `"wcwidth" \| "unicode"`. Calls `lib.createEditBuffer(widthMethod)` |
| `constructor` | `(lib: RenderLib, ptr: Pointer)` | Internal. Registers instance in a static registry by `id` for native event routing |

### Text Operations

| Method | Signature | Description |
|--------|-----------|-------------|
| `setText` | `(text: string) => void` | Set text and **reset** buffer state (clears history, resets add_buffer). For initial text loading. |
| `setTextOwned` | `(text: string) => void` | Like `setText` but native takes ownership of the memory |
| `replaceText` | `(text: string) => void` | Replace text **preserving** undo history (creates an undo point) |
| `replaceTextOwned` | `(text: string) => void` | Like `replaceText` but native takes ownership |
| `getText` | `() => string` | Returns full buffer text (up to 1MB) |
| `getLineCount` | `() => number` | Number of logical lines |
| `insertChar` | `(char: string) => void` | Insert a single character at cursor |
| `insertText` | `(text: string) => void` | Insert multi-char text at cursor |
| `deleteChar` | `() => void` | Delete character forward (at cursor) |
| `deleteCharBackward` | `() => void` | Delete character backward (backspace) |
| `deleteRange` | `(startLine, startCol, endLine, endCol) => void` | Delete a range by row/col coordinates |
| `newLine` | `() => void` | Insert a newline at cursor |
| `deleteLine` | `() => void` | Delete the current line |
| `clear` | `() => void` | Clear all text |

### Cursor Operations

| Method | Signature | Description |
|--------|-----------|-------------|
| `moveCursorLeft` | `() => void` | Move cursor one grapheme left |
| `moveCursorRight` | `() => void` | Move cursor one grapheme right |
| `moveCursorUp` | `() => void` | Move cursor up one logical line |
| `moveCursorDown` | `() => void` | Move cursor down one logical line |
| `gotoLine` | `(line: number) => void` | Jump to a specific line (0-indexed) |
| `setCursor` | `(line, col) => void` | Set cursor by logical row and column |
| `setCursorToLineCol` | `(line, col) => void` | Set cursor by line/col (clamps to line end) |
| `setCursorByOffset` | `(offset: number) => void` | Set cursor by character offset from buffer start |
| `getCursorPosition` | `() => LogicalCursor` | Returns `{row, col, offset}` |

### Word/Line Boundaries

| Method | Signature | Description |
|--------|-----------|-------------|
| `getNextWordBoundary` | `() => LogicalCursor` | Next word boundary from cursor (`{row, col, offset}`) |
| `getPrevWordBoundary` | `() => LogicalCursor` | Previous word boundary from cursor |
| `getEOL` | `() => LogicalCursor` | End of current line |

### Offset/Position Conversion

| Method | Signature | Description |
|--------|-----------|-------------|
| `offsetToPosition` | `(offset) => {row, col} \| null` | Convert byte offset to row/col |
| `positionToOffset` | `(row, col) => number` | Convert row/col to byte offset |
| `getLineStartOffset` | `(row) => number` | Get byte offset of line start |
| `getTextRange` | `(startOffset, endOffset) => string` | Extract text by offsets |
| `getTextRangeByCoords` | `(startRow, startCol, endRow, endCol) => string` | Extract text by coordinates |

### Undo/Redo

| Method | Signature | Description |
|--------|-----------|-------------|
| `undo` | `() => string \| null` | Undo last operation. Returns metadata string (max 256 bytes) or null |
| `redo` | `() => string \| null` | Redo last undone operation. Returns metadata string or null |
| `canUndo` | `() => boolean` | Whether undo stack has entries |
| `canRedo` | `() => boolean` | Whether redo stack has entries |
| `clearHistory` | `() => void` | Clear undo/redo stacks |

**History Model:** Per-character granularity. Each `insertChar`, `deleteChar`, `deleteCharBackward`, `newLine`, `insertText`, `deleteRange`, `deleteLine` creates an undo point. `undo()` reverts one operation, `redo()` re-applies. `setText` clears history; `replaceText` preserves it.

### Styling / Highlights

| Method | Signature | Description |
|--------|-----------|-------------|
| `setDefaultFg` | `(fg: RGBA \| null) => void` | Set default foreground color |
| `setDefaultBg` | `(bg: RGBA \| null) => void` | Set default background color |
| `setDefaultAttributes` | `(attributes: number \| null) => void` | Set default text attributes bitmask |
| `resetDefaults` | `() => void` | Reset fg/bg/attributes to defaults |
| `setSyntaxStyle` | `(style: SyntaxStyle \| null) => void` | Set syntax highlighting style table |
| `getSyntaxStyle` | `() => SyntaxStyle \| null` | Get current syntax style |
| `addHighlight` | `(lineIdx, highlight: Highlight) => void` | Add highlight to specific line |
| `addHighlightByCharRange` | `(highlight: Highlight) => void` | Add highlight by character range |
| `removeHighlightsByRef` | `(hlRef: number) => void` | Remove highlights by reference ID |
| `clearLineHighlights` | `(lineIdx) => void` | Clear highlights on a line |
| `clearAllHighlights` | `() => void` | Clear all highlights |
| `getLineHighlights` | `(lineIdx) => Highlight[]` | Get highlights for a line |

### Lifecycle

| Method | Signature | Description |
|--------|-----------|-------------|
| `destroy` | `() => void` | Free native resources, remove from registry |
| `ptr` | `getter => Pointer` | Get native pointer (throws if destroyed) |
| `id` | `readonly number` | Unique buffer ID for event routing |

### Events (via EventEmitter)

Native events prefixed with `eb_` are stripped and forwarded:
- `"cursor-changed"` - Emitted when cursor position changes
- `"content-changed"` - Emitted when buffer content changes

---

## 2. EditorView Public API

**Source:** `packages/core/src/editor-view.ts`

EditorView wraps a native Zig view over an EditBuffer, providing visual line wrapping, viewport management, selection, and visual cursor positioning.

### Constructor / Factory

| Method | Signature | Description |
|--------|-----------|-------------|
| `EditorView.create` | `(editBuffer: EditBuffer, viewportWidth, viewportHeight) => EditorView` | Factory. Creates native view via `lib.createEditorView(editBuffer.ptr, w, h)` |

### Viewport Management

| Method | Signature | Description |
|--------|-----------|-------------|
| `setViewportSize` | `(width, height) => void` | Resize viewport |
| `setViewport` | `(x, y, width, height, moveCursor?: bool) => void` | Set full viewport rect. `moveCursor` defaults true |
| `getViewport` | `() => Viewport` | Returns `{offsetX, offsetY, height, width}` |
| `setScrollMargin` | `(margin: number) => void` | Set scroll margin (fraction, e.g. 0.2) |

### Wrap Mode

| Method | Signature | Description |
|--------|-----------|-------------|
| `setWrapMode` | `(mode: "none" \| "char" \| "word") => void` | Set text wrapping mode |

### Line Count

| Method | Signature | Description |
|--------|-----------|-------------|
| `getVirtualLineCount` | `() => number` | Lines visible in current viewport |
| `getTotalVirtualLineCount` | `() => number` | Total virtual lines (with wrapping) |

### Selection (Offset-based)

| Method | Signature | Description |
|--------|-----------|-------------|
| `setSelection` | `(start, end, bgColor?, fgColor?) => void` | Set selection by offsets |
| `updateSelection` | `(end, bgColor?, fgColor?) => void` | Update selection end point |
| `resetSelection` | `() => void` | Clear selection |
| `getSelection` | `() => {start, end} \| null` | Get current selection offsets |
| `hasSelection` | `() => boolean` | Whether selection is active |

### Selection (Local/Visual coordinates)

| Method | Signature | Description |
|--------|-----------|-------------|
| `setLocalSelection` | `(anchorX, anchorY, focusX, focusY, bg?, fg?, updateCursor?, followCursor?) => boolean` | Set selection by visual coordinates |
| `updateLocalSelection` | `(anchorX, anchorY, focusX, focusY, bg?, fg?, updateCursor?, followCursor?) => boolean` | Update selection by visual coordinates |
| `resetLocalSelection` | `() => void` | Clear local selection |
| `getSelectedText` | `() => string` | Get text of current selection (up to 1MB) |
| `deleteSelectedText` | `() => void` | Delete selected text |

### Cursor

| Method | Signature | Description |
|--------|-----------|-------------|
| `getCursor` | `() => {row, col}` | Get logical cursor position |
| `getVisualCursor` | `() => VisualCursor` | Returns `{visualRow, visualCol, logicalRow, logicalCol, offset}` |
| `setCursorByOffset` | `(offset) => void` | Set cursor by character offset |

### Visual Navigation

| Method | Signature | Description |
|--------|-----------|-------------|
| `moveUpVisual` | `() => void` | Move up one visual line (respects wrapping) |
| `moveDownVisual` | `() => void` | Move down one visual line |

### Word/Line Boundaries (Visual)

| Method | Signature | Description |
|--------|-----------|-------------|
| `getNextWordBoundary` | `() => VisualCursor` | Next word boundary |
| `getPrevWordBoundary` | `() => VisualCursor` | Previous word boundary |
| `getEOL` | `() => VisualCursor` | End of logical line |
| `getVisualSOL` | `() => VisualCursor` | Start of visual line |
| `getVisualEOL` | `() => VisualCursor` | End of visual line |

### Line Info

| Method | Signature | Description |
|--------|-----------|-------------|
| `getLineInfo` | `() => LineInfo` | Visual line info (with wrapping) |
| `getLogicalLineInfo` | `() => LineInfo` | Logical line info |
| `getText` | `() => string` | Full buffer text via the view |

### Placeholder

| Method | Signature | Description |
|--------|-----------|-------------|
| `setPlaceholderStyledText` | `(chunks: StyledChunk[]) => void` | Set placeholder styled text chunks. Each chunk: `{text, fg?, bg?, attributes?}` |

### Tab Display

| Method | Signature | Description |
|--------|-----------|-------------|
| `setTabIndicator` | `(indicator: string \| number) => void` | Set tab indicator character |
| `setTabIndicatorColor` | `(color: RGBA) => void` | Set tab indicator color |

### Measurement

| Method | Signature | Description |
|--------|-----------|-------------|
| `measureForDimensions` | `(width, height) => {lineCount, maxWidth} \| null` | Measure text layout for given dimensions |

### Extmarks

| Property | Type | Description |
|----------|------|-------------|
| `extmarks` | `ExtmarksController` | Lazy-initialized extmarks controller |

### Lifecycle

| Method | Signature | Description |
|--------|-----------|-------------|
| `destroy` | `() => void` | Free native view resources |

---

## 3. Textarea Keybinding Map

**Source:** `packages/core/src/renderables/Textarea.ts` lines 57-125

The `TextareaAction` type enumerates all possible actions. Default bindings:

### Cursor Movement

| Key Combo | Action |
|-----------|--------|
| `Left` | `move-left` |
| `Right` | `move-right` |
| `Up` | `move-up` |
| `Down` | `move-down` |
| `Ctrl+F` | `move-right` |
| `Ctrl+B` | `move-left` |

### Selection (Shift + Movement)

| Key Combo | Action |
|-----------|--------|
| `Shift+Left` | `select-left` |
| `Shift+Right` | `select-right` |
| `Shift+Up` | `select-up` |
| `Shift+Down` | `select-down` |

### Line Home/End (Logical)

| Key Combo | Action |
|-----------|--------|
| `Ctrl+A` | `line-home` |
| `Ctrl+E` | `line-end` |
| `Ctrl+Shift+A` | `select-line-home` |
| `Ctrl+Shift+E` | `select-line-end` |

### Visual Line Home/End

| Key Combo | Action |
|-----------|--------|
| `Meta+A` | `visual-line-home` |
| `Meta+E` | `visual-line-end` |
| `Meta+Shift+A` | `select-visual-line-home` |
| `Meta+Shift+E` | `select-visual-line-end` |
| `Super+Left` | `visual-line-home` |
| `Super+Right` | `visual-line-end` |
| `Super+Shift+Left` | `select-visual-line-home` |
| `Super+Shift+Right` | `select-visual-line-end` |

### Buffer Home/End

| Key Combo | Action |
|-----------|--------|
| `Home` | `buffer-home` |
| `End` | `buffer-end` |
| `Shift+Home` | `select-buffer-home` |
| `Shift+End` | `select-buffer-end` |
| `Super+Up` | `buffer-home` |
| `Super+Down` | `buffer-end` |
| `Super+Shift+Up` | `select-buffer-home` |
| `Super+Shift+Down` | `select-buffer-end` |

### Word Movement

| Key Combo | Action |
|-----------|--------|
| `Meta+F` | `word-forward` |
| `Meta+B` | `word-backward` |
| `Meta+Right` / `Ctrl+Right` | `word-forward` |
| `Meta+Left` / `Ctrl+Left` | `word-backward` |
| `Meta+Shift+F` | `select-word-forward` |
| `Meta+Shift+B` | `select-word-backward` |
| `Meta+Shift+Right` | `select-word-forward` |
| `Meta+Shift+Left` | `select-word-backward` |

### Deletion

| Key Combo | Action |
|-----------|--------|
| `Backspace` | `backspace` |
| `Shift+Backspace` | `backspace` |
| `Delete` | `delete` |
| `Shift+Delete` | `delete` |
| `Ctrl+D` | `delete` |
| `Ctrl+W` | `delete-word-backward` |
| `Ctrl+Backspace` | `delete-word-backward` |
| `Meta+Backspace` | `delete-word-backward` |
| `Meta+D` / `Meta+Delete` / `Ctrl+Delete` | `delete-word-forward` |
| `Ctrl+Shift+D` | `delete-line` |
| `Ctrl+K` | `delete-to-line-end` |
| `Ctrl+U` | `delete-to-line-start` |

### Editing

| Key Combo | Action |
|-----------|--------|
| `Return` / `Linefeed` | `newline` |
| `Meta+Return` | `submit` |

### Undo/Redo

| Key Combo | Action |
|-----------|--------|
| `Ctrl+-` | `undo` |
| `Ctrl+.` | `redo` |
| `Super+Z` | `undo` |
| `Super+Shift+Z` | `redo` |

### Select All

| Key Combo | Action |
|-----------|--------|
| `Super+A` | `select-all` |

### Character Input

Any key without `ctrl`, `meta`, `super`, or `hyper` modifiers, where the sequence first char code is >= 32 and != 127, is inserted as text. `space` key is explicitly handled to insert `" "`.

---

## 4. Textarea State Model

**Source:** `Textarea.ts` and `EditBufferRenderable.ts`

### TextareaRenderable State

- `_placeholder`: `StyledText | string | null` - Placeholder text
- `_placeholderColor`: `RGBA`
- `_unfocusedBackgroundColor`: `RGBA`
- `_unfocusedTextColor`: `RGBA`
- `_focusedBackgroundColor`: `RGBA`
- `_focusedTextColor`: `RGBA`
- `_keyBindingsMap`: `Map<string, TextareaAction>` - Resolved keybindings
- `_keyAliasMap`: `KeyAliasMap` - Key name aliases
- `_keyBindings`: `KeyBinding[]` - Custom bindings
- `_actionHandlers`: `Map<TextareaAction, () => boolean>` - Action handler functions
- `_initialValueSet`: `boolean` - Whether initial value has been applied
- `_submitListener`: `(event: SubmitEvent) => void` - Submit callback

### EditBufferRenderable State (parent)

- `editBuffer`: `EditBuffer` (readonly) - The native buffer
- `editorView`: `EditorView` (readonly) - The native view
- `_textColor`: `RGBA`
- `_backgroundColor`: `RGBA`
- `_defaultAttributes`: `number` - Text attribute bitmask
- `_selectionBg`: `RGBA | undefined`
- `_selectionFg`: `RGBA | undefined`
- `_wrapMode`: `"none" | "char" | "word"` (default: `"word"`)
- `_scrollMargin`: `number` (default: `0.2` = 20% of viewport)
- `_showCursor`: `boolean` (default: `true`)
- `_cursorColor`: `RGBA`
- `_cursorStyle`: `CursorStyleOptions` (`{style: "block", blinking: true}`)
- `_scrollSpeed`: `number` (default: `16`)
- `_autoScrollVelocity`: `number` - Auto-scroll speed during drag
- `_autoScrollAccumulator`: `number` - Sub-line scroll accumulator
- `_keyboardSelectionActive`: `boolean`
- `lastLocalSelection`: `LocalSelectionBounds | null`
- `selectable`: `boolean` (default: `true`)
- `_focusable`: `boolean` (default: `true`)

### Computed Properties

- `plainText`: `string` - Full buffer text
- `logicalCursor`: `LogicalCursor` - `{row, col, offset}`
- `visualCursor`: `VisualCursor` - `{visualRow, visualCol, logicalRow, logicalCol, offset}`
- `cursorOffset`: `number` - Character offset (get/set)
- `lineCount`: `number` - Logical line count
- `virtualLineCount`: `number` - Visual line count (with wrapping)
- `scrollY`: `number` - Current vertical scroll offset

---

## 5. Selection Model

### Offset-based Selection (EditorView)

Selection is tracked as an offset range `{start: number, end: number}` into the buffer. The native Zig code handles this via:
- `setSelection(start, end, bgColor?, fgColor?)` - Set by buffer offsets
- `updateSelection(end, bgColor?, fgColor?)` - Update end point
- `getSelection()` returns `{start, end} | null`

### Local/Visual Selection

For mouse drag, selection uses visual coordinates relative to the widget:
- `setLocalSelection(anchorX, anchorY, focusX, focusY, ...)` - Set by visual coords
- `updateLocalSelection(...)` - Update by visual coords
- The native code translates visual coordinates to buffer offsets accounting for wrapping and viewport scroll

### Keyboard Selection

Uses `updateSelectionForMovement(shiftPressed, isBeforeMovement)`:
1. If shift not pressed: clear selection
2. If shift pressed and before movement: start selection at current cursor if none exists
3. If shift pressed and after movement: update selection end to new cursor position

The selection interacts with the `RenderContext`'s global selection system:
- `_ctx.startSelection(this, cursorX, cursorY)` - Begin
- `_ctx.updateSelection(this, cursorX, cursorY, {finishDragging: true})` - Update
- `_ctx.clearSelection()` - Clear

### Selection + Editing Behavior

- Typing with selection active: deletes selection first, then inserts
- Backspace/Delete with selection: deletes selection
- Arrow without shift with selection: moves cursor to selection edge and clears
  - Left: moves to selection start
  - Right: moves to selection end
- Word delete with selection: deletes selection (not word)

---

## 6. Mouse Interaction

**Source:** `EditBufferRenderable.ts`

### Scroll Events

`onMouseEvent` handles `event.type === "scroll"`:
- `direction: "up"`: decreases viewport `offsetY`
- `direction: "down"`: increases viewport `offsetY` (capped at `totalVirtualLines - viewport.height`)
- `direction: "left"/"right"`: adjusts `offsetX` (only when `wrapMode === "none"`)
- Scroll delta comes from `event.scroll.delta`

### Mouse Selection

`shouldStartSelection(x, y)`: Returns true if coordinates are within widget bounds and `selectable` is true.

`onSelectionChanged(selection)`: Called by the renderer's global selection system:
1. Converts global coordinates to local widget coordinates
2. For initial click (`selection.isStart`): calls `setLocalSelection` with `updateCursor=true`
3. For drag continuation: calls `updateLocalSelection` with `updateCursor=true`
4. For release or clear: calls `resetLocalSelection`
5. During drag near edges: sets `_autoScrollVelocity` for auto-scrolling

### Auto-scroll During Drag

In `onUpdate(deltaTime)`:
- If `_autoScrollVelocity !== 0` and selection active:
  - Accumulates scroll based on velocity and deltaTime
  - When accumulated >= 1 line, scrolls viewport
  - Requests selection update to track cursor

---

## 7. Event Callbacks

### TextareaRenderable

| Callback | Type | Trigger |
|----------|------|---------|
| `onSubmit` | `(event: SubmitEvent) => void` | `Meta+Return` pressed |

### EditBufferRenderable

| Callback | Type | Trigger |
|----------|------|---------|
| `onCursorChange` | `(event: CursorChangeEvent) => void` | Cursor position changes. Event: `{line: number, visualColumn: number}` |
| `onContentChange` | `(event: ContentChangeEvent) => void` | Buffer content changes. Event: `{}` (no payload; use `getText()`) |

### Native Events (EditBuffer EventEmitter)

| Event | Description |
|-------|-------------|
| `"cursor-changed"` | Native cursor change (triggers `onCursorChange` callback) |
| `"content-changed"` | Native content change (triggers `onContentChange`, yoga markDirty, render request) |

---

## 8. Zig <-> TS Boundary

**Source:** `packages/core/src/zig.ts`, `packages/core/src/zig-structs.ts`

### Architecture

TS loads a platform-specific shared library (`@opentui/core-{platform}-{arch}`) via `bun:ffi`'s `dlopen`. All Zig calls go through raw FFI function pointers with C-compatible types.

### Data Structs (Zig <-> TS)

Defined in `zig-structs.ts` using `bun-ffi-structs`:

```
LogicalCursor  = { row: u32, col: u32, offset: u32 }
VisualCursor   = { visualRow: u32, visualCol: u32, logicalRow: u32, logicalCol: u32, offset: u32 }
LineInfo       = { starts: [u32], startsLen: u32, widths: [u32], widthsLen: u32,
                   sources: [u32], sourcesLen: u32, wraps: [u32], wrapsLen: u32, maxWidth: u32 }
Highlight      = { start: u32, end: u32, styleId: u32, priority: u8, hlRef: u16 }
MeasureResult  = { lineCount: u32, maxWidth: u32 }
StyledChunk    = { text: char*, text_len: u64, fg: pointer?, bg: pointer?, attributes: u32? }
```

### Key FFI Functions for EditBuffer

| FFI Symbol | Args | Returns | Description |
|-----------|------|---------|-------------|
| `createEditBuffer` | `u8` (widthMethod) | `ptr` | Create new edit buffer |
| `destroyEditBuffer` | `ptr` | `void` | Free edit buffer |
| `editBufferSetText` | `ptr, ptr, usize` | `void` | Set text (owned) |
| `editBufferSetTextFromMem` | `ptr, u8` (memId) | `void` | Set text from registered mem buffer |
| `editBufferReplaceText` | `ptr, ptr, usize` | `void` | Replace text preserving history |
| `editBufferReplaceTextFromMem` | `ptr, u8` | `void` | Replace from mem buffer |
| `editBufferGetText` | `ptr, ptr, usize` | `usize` | Get text into output buffer |
| `editBufferInsertChar` | `ptr, ptr, usize` | `void` | Insert char (UTF-8 bytes) |
| `editBufferInsertText` | `ptr, ptr, usize` | `void` | Insert text (UTF-8 bytes) |
| `editBufferDeleteChar` | `ptr` | `void` | Delete forward |
| `editBufferDeleteCharBackward` | `ptr` | `void` | Delete backward |
| `editBufferDeleteRange` | `ptr, u32, u32, u32, u32` | `void` | Delete range (startRow, startCol, endRow, endCol) |
| `editBufferNewLine` | `ptr` | `void` | Insert newline |
| `editBufferDeleteLine` | `ptr` | `void` | Delete current line |
| `editBufferMoveCursorLeft` | `ptr` | `void` | Move left |
| `editBufferMoveCursorRight` | `ptr` | `void` | Move right |
| `editBufferMoveCursorUp` | `ptr` | `void` | Move up |
| `editBufferMoveCursorDown` | `ptr` | `void` | Move down |
| `editBufferGotoLine` | `ptr, u32` | `void` | Jump to line |
| `editBufferSetCursor` | `ptr, u32, u32` | `void` | Set cursor row, col |
| `editBufferSetCursorToLineCol` | `ptr, u32, u32` | `void` | Set cursor (clamps) |
| `editBufferSetCursorByOffset` | `ptr, u32` | `void` | Set cursor by offset |
| `editBufferGetCursorPosition` | `ptr, ptr` (out) | `void` | Get cursor (writes LogicalCursor struct) |
| `editBufferGetNextWordBoundary` | `ptr, ptr` (out) | `void` | Get next word boundary |
| `editBufferGetPrevWordBoundary` | `ptr, ptr` (out) | `void` | Get prev word boundary |
| `editBufferGetEOL` | `ptr, ptr` (out) | `void` | Get end of line |
| `editBufferOffsetToPosition` | `ptr, u32, ptr` (out) | `bool` | Offset -> row/col |
| `editBufferPositionToOffset` | `ptr, u32, u32` | `u32` | Row/col -> offset |
| `editBufferGetLineStartOffset` | `ptr, u32` | `u32` | Line start offset |
| `editBufferGetTextRange` | `ptr, u32, u32, ptr, usize` | `usize` | Get text range by offsets |
| `editBufferGetTextRangeByCoords` | `ptr, u32, u32, u32, u32, ptr, usize` | `usize` | Get text range by coords |
| `editBufferUndo` | `ptr, ptr, usize` | `usize` | Undo (returns metadata bytes) |
| `editBufferRedo` | `ptr, ptr, usize` | `usize` | Redo (returns metadata bytes) |
| `editBufferCanUndo` | `ptr` | `bool` | Check undo availability |
| `editBufferCanRedo` | `ptr` | `bool` | Check redo availability |
| `editBufferClearHistory` | `ptr` | `void` | Clear undo/redo stacks |
| `editBufferClear` | `ptr` | `void` | Clear buffer |
| `editBufferGetId` | `ptr` | `u16` | Get buffer ID |
| `editBufferGetTextBuffer` | `ptr` | `ptr` | Get underlying TextBuffer ptr |

### Key FFI Functions for EditorView

| FFI Symbol | Args | Returns | Description |
|-----------|------|---------|-------------|
| `createEditorView` | `ptr, u32, u32` | `ptr` | Create (editBuffer ptr, width, height) |
| `destroyEditorView` | `ptr` | `void` | Free view |
| `editorViewSetViewportSize` | `ptr, u32, u32` | `void` | Resize viewport |
| `editorViewSetViewport` | `ptr, u32, u32, u32, u32, bool` | `void` | Set full viewport |
| `editorViewGetViewport` | `ptr, ptr, ptr, ptr, ptr` | `void` | Get viewport (4 out-params) |
| `editorViewSetScrollMargin` | `ptr, f32` | `void` | Set scroll margin |
| `editorViewSetWrapMode` | `ptr, u8` | `void` | Set wrap mode |
| `editorViewGetVirtualLineCount` | `ptr` | `u32` | Visible virtual lines |
| `editorViewGetTotalVirtualLineCount` | `ptr` | `u32` | Total virtual lines |
| `editorViewSetSelection` | `ptr, u32, u32, ptr, ptr` | `void` | Set selection |
| `editorViewResetSelection` | `ptr` | `void` | Clear selection |
| `editorViewGetSelection` | `ptr` | `u64` | Get selection (packed) |
| `editorViewSetLocalSelection` | `ptr, i32, i32, i32, i32, ptr, ptr, bool, bool` | `bool` | Set local selection |
| `editorViewUpdateSelection` | `ptr, u32, ptr, ptr` | `void` | Update selection end |
| `editorViewUpdateLocalSelection` | `ptr, i32, i32, i32, i32, ptr, ptr, bool, bool` | `bool` | Update local selection |
| `editorViewResetLocalSelection` | `ptr` | `void` | Clear local selection |
| `editorViewGetSelectedTextBytes` | `ptr, ptr, usize` | `usize` | Get selected text |
| `editorViewGetCursor` | `ptr, ptr, ptr` | `void` | Get cursor (2 out-params) |
| `editorViewGetText` | `ptr, ptr, usize` | `usize` | Get full text |
| `editorViewGetVisualCursor` | `ptr, ptr` (out) | `void` | Get VisualCursor struct |
| `editorViewMoveUpVisual` | `ptr` | `void` | Move up visual line |
| `editorViewMoveDownVisual` | `ptr` | `void` | Move down visual line |
| `editorViewDeleteSelectedText` | `ptr` | `void` | Delete selected text |
| `editorViewSetCursorByOffset` | `ptr, u32` | `void` | Set cursor by offset |
| `editorViewGetNextWordBoundary` | `ptr, ptr` (out) | `void` | Next word boundary |
| `editorViewGetPrevWordBoundary` | `ptr, ptr` (out) | `void` | Prev word boundary |
| `editorViewGetEOL` | `ptr, ptr` (out) | `void` | End of line |
| `editorViewGetVisualSOL` | `ptr, ptr` (out) | `void` | Visual start of line |
| `editorViewGetVisualEOL` | `ptr, ptr` (out) | `void` | Visual end of line |
| `editorViewSetPlaceholderStyledText` | `ptr, ptr, usize` | `void` | Set placeholder chunks |
| `editorViewSetTabIndicator` | `ptr, u32` | `void` | Set tab indicator codepoint |
| `editorViewSetTabIndicatorColor` | `ptr, ptr` | `void` | Set tab indicator color |
| `editorViewGetTextBufferView` | `ptr` | `ptr` | Get underlying TextBufferView ptr |
| `bufferDrawEditorView` | `ptr, ptr, i32, i32` | `void` | Draw editor view into buffer |

### Key FFI Functions for TextBuffer (used by EditBuffer)

| FFI Symbol | Args | Returns | Description |
|-----------|------|---------|-------------|
| `textBufferGetLineCount` | `ptr` | `u32` | Line count |
| `textBufferSetDefaultFg` | `ptr, ptr` | `void` | Default foreground color |
| `textBufferSetDefaultBg` | `ptr, ptr` | `void` | Default background color |
| `textBufferSetDefaultAttributes` | `ptr, ptr` | `void` | Default attributes |
| `textBufferResetDefaults` | `ptr` | `void` | Reset defaults |
| `textBufferRegisterMemBuffer` | `ptr, ptr, usize, bool` | `u16` | Register memory buffer |
| `textBufferReplaceMemBuffer` | `ptr, u8, ptr, usize, bool` | `bool` | Replace registered mem |
| `textBufferAddHighlight` | `ptr, u32, ptr` | `void` | Add highlight to line |
| `textBufferAddHighlightByCharRange` | `ptr, ptr` | `void` | Add highlight by char range |
| `textBufferRemoveHighlightsByRef` | `ptr, u16` | `void` | Remove by ref |
| `textBufferClearLineHighlights` | `ptr, u32` | `void` | Clear line highlights |
| `textBufferClearAllHighlights` | `ptr` | `void` | Clear all highlights |
| `textBufferSetSyntaxStyle` | `ptr, ptr` | `void` | Set syntax style |

### Measurement

| FFI Symbol | Args | Returns | Description |
|-----------|------|---------|-------------|
| `textBufferViewMeasureForDimensions` | `ptr, u32, u32, ptr` (out) | `bool` | Measure for dimensions |

### Marshalling Pattern

1. **Text in:** TS encodes string to UTF-8 `Uint8Array`, passes `(ptr, len)` to Zig
2. **Text out:** TS allocates a buffer, passes `(out_ptr, max_len)`, Zig writes and returns actual length, TS decodes with `TextDecoder`
3. **Structs out:** TS allocates struct buffer, passes `ptr` as out-param, Zig fills it. Unpacked via `bun-ffi-structs`
4. **Colors:** RGBA is 4x f32 packed in a buffer, passed as pointer
5. **Memory management:** "Owned" variants transfer ownership to Zig; "FromMem" variants use registered memory buffers (zero-copy optimization)
6. **Event routing:** A single native event callback dispatches events by buffer ID prefix (`eb_<id>`)

---

## 9. Extmarks API

**Source:** `packages/core/src/lib/extmarks.ts`

Extmarks are positioned annotations that track their position as the buffer is edited. Currently implemented in TS (will move to native later).

### ExtmarksController Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `create` | `(options: ExtmarkOptions) => number` | Create extmark, returns ID |
| `delete` | `(id: number) => boolean` | Delete extmark by ID |
| `get` | `(id: number) => Extmark \| null` | Get extmark by ID |
| `getAll` | `() => Extmark[]` | All extmarks |
| `getVirtual` | `() => Extmark[]` | Only virtual extmarks |
| `getAtOffset` | `(offset) => Extmark[]` | Extmarks containing offset |
| `getAllForTypeId` | `(typeId) => Extmark[]` | Extmarks of a type |
| `clear` | `() => void` | Clear all extmarks |
| `registerType` | `(name: string) => number` | Register named type, returns ID |
| `getTypeId` | `(name) => number \| null` | Look up type ID |
| `getTypeName` | `(id) => string \| null` | Look up type name |
| `getMetadataFor` | `(extmarkId) => any` | Get extmark metadata |
| `destroy` | `() => void` | Cleanup, restore original methods |

### Extmark Interface

```ts
interface Extmark {
  id: number
  start: number    // Display-width offset including newlines
  end: number      // Display-width offset including newlines
  virtual: boolean // If true, cursor skips over it
  styleId?: number // Highlight style ID
  priority?: number
  data?: any
  typeId: number
}
```

Extmarks auto-adjust on insert/delete operations. Virtual extmarks cause cursor movement to skip their range. Extmarks have undo/redo support via `ExtmarksHistory`.

---

## 10. TextareaOptions (Full Configuration)

```ts
interface TextareaOptions extends EditBufferOptions {
  initialValue?: string
  backgroundColor?: ColorInput
  textColor?: ColorInput
  focusedBackgroundColor?: ColorInput
  focusedTextColor?: ColorInput
  placeholder?: StyledText | string | null
  placeholderColor?: ColorInput
  keyBindings?: KeyBinding[]
  keyAliasMap?: KeyAliasMap
  onSubmit?: (event: SubmitEvent) => void
}

interface EditBufferOptions extends RenderableOptions {
  textColor?: string | RGBA
  backgroundColor?: string | RGBA
  selectionBg?: string | RGBA
  selectionFg?: string | RGBA
  selectable?: boolean
  attributes?: number
  wrapMode?: "none" | "char" | "word"
  scrollMargin?: number
  scrollSpeed?: number
  showCursor?: boolean
  cursorColor?: string | RGBA
  cursorStyle?: CursorStyleOptions
  syntaxStyle?: SyntaxStyle
  tabIndicator?: string | number
  tabIndicatorColor?: string | RGBA
  onCursorChange?: (event: CursorChangeEvent) => void
  onContentChange?: (event: ContentChangeEvent) => void
}
```

---

## 11. Type Definitions

### LogicalCursor
```
{row: u32, col: u32, offset: u32}
```

### VisualCursor
```
{visualRow: u32, visualCol: u32, logicalRow: u32, logicalCol: u32, offset: u32}
```

### Viewport
```
{offsetX: number, offsetY: number, height: number, width: number}
```

### Highlight
```
{start: u32, end: u32, styleId: u32, priority?: u8, hlRef?: u16}
```

### LineInfo
```
{lineStarts: number[], lineWidths: number[], maxLineWidth: number, lineSources: number[], lineWraps: number[]}
```

### WidthMethod
```
"wcwidth" | "unicode"
```

### TextAttributes (bitmask)
```
NONE=0, BOLD=1, DIM=2, ITALIC=4, UNDERLINE=8, BLINK=16, INVERSE=32, HIDDEN=64, STRIKETHROUGH=128
```

---

## 12. Test Patterns

Tests use a `createTestRenderer` helper that provides:
- `renderer: TestRenderer` - The rendering context
- `renderOnce: () => Promise<void>` - Single render pass
- `mockInput: MockInput` - Keyboard simulation
  - `pressKey(key, {ctrl?, shift?, meta?, super?})`
  - `pressArrow(direction, modifiers?)`
  - `pressBackspace(modifiers?)`
  - `pressEnter()`
- `mockMouse: MockMouse` - Mouse simulation
  - `drag(startX, startY, endX, endY)`
  - `pressDown(x, y)`
  - `moveTo(x, y)`
  - `release(x, y)`
  - `scroll(x, y, direction)`
  - `emitMouseEvent(type, x, y)`

Test pattern:
1. Create renderer with `createTestRenderer({width, height})`
2. Create textarea with `createTextareaRenderable(renderer, renderOnce, options)`
3. Focus the textarea: `editor.focus()`
4. Simulate input via `mockInput` or `mockMouse`
5. Assert state via `editor.plainText`, `editor.logicalCursor`, `editor.hasSelection()`, `editor.getSelectedText()`
6. Cleanup: `currentRenderer.destroy()` in `afterEach`
