defmodule ElixirOpentui.EditBufferNIFMemoryTest do
  use ExUnit.Case, async: false

  @moduletag :nif

  alias ElixirOpentui.EditBufferNIF

  @calls 2000
  @max_growth_bytes 2_000_000

  defp memory_growth(fun) do
    :erlang.garbage_collect()
    initial = :erlang.memory(:total)
    Enum.each(1..@calls, fn _ -> fun.() end)
    :erlang.garbage_collect()
    :erlang.memory(:total) - initial
  end

  defp editor do
    buf = EditBufferNIF.create()
    view = EditBufferNIF.create_editor_view(buf, 200, 50)
    EditBufferNIF.set_text(buf, String.duplicate(String.duplicate("x", 150) <> "\n", 40))
    {buf, view}
  end

  describe "gc safety" do
    test "creating many resources does not leak memory" do
      initial = :erlang.memory(:total)

      for _ <- 1..100 do
        buf = EditBufferNIF.create()
        EditBufferNIF.set_text(buf, String.duplicate("x", 1000))
        _view = EditBufferNIF.create_editor_view(buf, 40, 10)
      end

      :erlang.garbage_collect()
      Process.sleep(50)
      :erlang.garbage_collect()

      final = :erlang.memory(:total)
      assert final - initial < 10_000_000
    end

    @tag :nif_source
    test "an editor view keeps its edit buffer alive" do
      make_view = fn ->
        buf = EditBufferNIF.create()
        EditBufferNIF.set_text(buf, String.duplicate("hello world\n", 50))
        EditBufferNIF.create_editor_view(buf, 80, 20)
      end

      views = for _ <- 1..200, do: make_view.()
      :erlang.garbage_collect()
      Process.sleep(50)
      :erlang.garbage_collect()
      _reuse_freed_memory = for _ <- 1..200, do: make_view.()

      for view <- views do
        assert [first | _] = EditBufferNIF.view_get_visible_lines(view)
        assert first == "hello world"
        EditBufferNIF.view_set_selection(view, 0, 5)
        assert EditBufferNIF.view_get_selected_text(view) == "hello"
      end
    end
  end

  describe "returned binaries" do
    @describetag :nif_source

    test "get_text/1 does not leak its result" do
      {buf, _view} = editor()
      assert memory_growth(fn -> EditBufferNIF.get_text(buf) end) < @max_growth_bytes
    end

    test "view_get_visible_lines/1 does not leak its lines" do
      {buf, view} = editor()
      growth = memory_growth(fn -> EditBufferNIF.view_get_visible_lines(view) end)
      assert growth < @max_growth_bytes
      assert is_reference(buf)
    end

    test "view_get_selected_text/1 does not leak its result" do
      {buf, view} = editor()
      EditBufferNIF.view_set_selection(view, 0, 2000)
      growth = memory_growth(fn -> EditBufferNIF.view_get_selected_text(view) end)
      assert growth < @max_growth_bytes
      assert is_reference(buf)
    end
  end
end
