defmodule ElixirOpentui.EditorViewTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.EditBuffer
  alias ElixirOpentui.EditorView

  defp setup_view(text \\ "Hello World", width \\ 80, height \\ 24) do
    buf = EditBuffer.from_text(text)
    view = EditorView.new(buf, width, height)
    {buf, view}
  end

  describe "new/3" do
    test "creates a view" do
      {_buf, view} = setup_view()
      assert %EditorView{edit_buffer: %EditBuffer{}} = view
    end
  end

  describe "viewport" do
    test "get_viewport returns dimensions" do
      {_buf, view} = setup_view()
      vp = EditorView.get_viewport(view)
      assert is_tuple(vp) or is_nil(vp)
    end

    test "set_viewport_size" do
      {_buf, view} = setup_view()
      view = EditorView.set_viewport_size(view, 40, 10)
      assert %EditorView{} = view
    end
  end

  describe "visual cursor" do
    test "get_visual_cursor returns 5-tuple" do
      {_buf, view} = setup_view()
      {vr, vc, lr, lc, offset} = EditorView.get_visual_cursor(view)
      assert is_integer(vr)
      assert is_integer(vc)
      assert is_integer(lr)
      assert is_integer(lc)
      assert is_integer(offset)
    end

    test "move_up_visual and move_down_visual" do
      {_buf, view} = setup_view("Line1\nLine2\nLine3")
      # Move cursor to line 2
      view = EditorView.set_cursor_by_offset(view, 6)
      {_, _, lr, _, _} = EditorView.get_visual_cursor(view)
      assert lr == 1

      view = EditorView.move_up_visual(view)
      {_, _, lr, _, _} = EditorView.get_visual_cursor(view)
      assert lr == 0

      view = EditorView.move_down_visual(view)
      {_, _, lr, _, _} = EditorView.get_visual_cursor(view)
      assert lr == 1
    end
  end

  describe "wrap mode" do
    test "set_wrap_mode accepts all modes" do
      {_buf, view} = setup_view()
      view = EditorView.set_wrap_mode(view, :none)
      assert %EditorView{} = view
      view = EditorView.set_wrap_mode(view, :char)
      assert %EditorView{} = view
      view = EditorView.set_wrap_mode(view, :word)
      assert %EditorView{} = view
    end

    test "virtual line count changes with wrapping" do
      # Long line that would wrap at width 10
      {_buf, view} = setup_view("Hello World this is a long line", 10, 5)
      view = EditorView.set_wrap_mode(view, :none)
      count_no_wrap = EditorView.get_total_virtual_line_count(view)

      view = EditorView.set_wrap_mode(view, :char)
      count_char_wrap = EditorView.get_total_virtual_line_count(view)

      # With char wrapping, a long line should produce more virtual lines
      assert count_char_wrap >= count_no_wrap
    end
  end

  describe "selection" do
    test "set and get selection" do
      {_buf, view} = setup_view("Hello World")
      view = EditorView.set_selection(view, 6, 11)
      sel = EditorView.get_selection(view)
      assert sel == {6, 11}
    end

    test "get_selected_text" do
      {_buf, view} = setup_view("Hello World")
      view = EditorView.set_selection(view, 6, 11)
      assert EditorView.get_selected_text(view) == "World"
    end

    test "reset_selection clears selection" do
      {_buf, view} = setup_view("Hello World")
      view = EditorView.set_selection(view, 0, 5)
      view = EditorView.reset_selection(view)
      assert EditorView.get_selection(view) == nil
    end

    test "no selection returns nil" do
      {_buf, view} = setup_view("Hello")
      assert EditorView.get_selection(view) == nil
    end

    test "delete_selected_text" do
      {buf, view} = setup_view("Hello World")
      view = EditorView.set_selection(view, 5, 11)
      _view = EditorView.delete_selected_text(view)
      assert EditBuffer.get_text(buf) == "Hello"
    end
  end

  describe "word boundaries" do
    test "get_next_word_boundary returns visual cursor" do
      {_buf, view} = setup_view("Hello World")
      view = EditorView.set_cursor_by_offset(view, 0)
      {_vr, _vc, _lr, _lc, offset} = EditorView.get_next_word_boundary(view)
      # Should move to next word boundary (past "Hello")
      assert offset > 0
    end

    test "get_prev_word_boundary returns visual cursor" do
      {_buf, view} = setup_view("Hello World")
      view = EditorView.set_cursor_by_offset(view, 11)
      {_vr, _vc, _lr, _lc, offset} = EditorView.get_prev_word_boundary(view)
      assert offset < 11
    end
  end

  describe "line boundaries" do
    test "get_eol returns end of logical line" do
      {_buf, view} = setup_view("Hello\nWorld")
      view = EditorView.set_cursor_by_offset(view, 0)
      {_vr, _vc, lr, _lc, _offset} = EditorView.get_eol(view)
      assert lr == 0
    end

    test "get_visual_sol and get_visual_eol" do
      {_buf, view} = setup_view("Hello World")
      view = EditorView.set_cursor_by_offset(view, 3)
      {_vr, _vc, _lr, _lc, sol_offset} = EditorView.get_visual_sol(view)
      {_vr, _vc, _lr, _lc, eol_offset} = EditorView.get_visual_eol(view)
      assert sol_offset <= 3
      assert eol_offset >= 3
    end
  end

  describe "scroll margin" do
    test "set_scroll_margin" do
      {_buf, view} = setup_view()
      view = EditorView.set_scroll_margin(view, 0.25)
      assert %EditorView{} = view
    end
  end
end
