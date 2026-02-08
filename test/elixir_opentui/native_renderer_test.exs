defmodule ElixirOpentui.NativeRendererTest do
  use ExUnit.Case, async: true

  @moduletag :nif

  alias ElixirOpentui.{Renderer, Element, NativeBuffer}

  defp strip_ansi(binary) do
    Regex.replace(~r/\e\[[0-9;]*[A-Za-z]/, binary, "")
  end

  describe "new/3 with :native backend" do
    test "creates renderer with NativeBuffer" do
      r = Renderer.new(40, 10, backend: :native)
      assert r.cols == 40
      assert r.rows == 10
      assert r.backend == :native
      assert %NativeBuffer{} = r.native_buf
      assert r.frame_count == 0
    end
  end

  describe "render/2 with :native backend" do
    test "returns updated renderer and ANSI output" do
      r = Renderer.new(20, 5, backend: :native)

      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:text, content: "Hello")
        ])

      {r2, output} = Renderer.render(r, tree)
      assert r2.frame_count == 1
      assert r2.backend == :native
      binary = if is_binary(output), do: output, else: IO.iodata_to_binary(output)
      assert String.contains?(strip_ansi(binary), "Hello")
    end

    test "changing content produces different output" do
      r = Renderer.new(20, 5, backend: :native)
      tree1 = Element.new(:box, [width: 20, height: 5], [Element.new(:text, content: "AAA")])
      tree2 = Element.new(:box, [width: 20, height: 5], [Element.new(:text, content: "BBB")])

      {r2, _} = Renderer.render(r, tree1)
      {_r3, output} = Renderer.render(r2, tree2)
      binary = if is_binary(output), do: output, else: IO.iodata_to_binary(output)
      assert String.contains?(strip_ansi(binary), "B")
    end

    test "frame count increments" do
      r = Renderer.new(10, 3, backend: :native)
      tree = Element.new(:box, width: 10, height: 3)
      {r2, _} = Renderer.render(r, tree)
      {r3, _} = Renderer.render(r2, tree)
      assert r3.frame_count == 2
    end
  end

  describe "render_full/2 with :native backend" do
    test "produces output" do
      r = Renderer.new(20, 5, backend: :native)

      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:text, content: "Full")
        ])

      {r2, output} = Renderer.render_full(r, tree)
      binary = if is_binary(output), do: output, else: IO.iodata_to_binary(output)
      assert String.contains?(strip_ansi(binary), "Full")
      assert r2.frame_count == 1
    end
  end

  describe "resize/3 with :native backend" do
    test "preserves backend" do
      r = Renderer.new(80, 24, backend: :native)
      r2 = Renderer.resize(r, 120, 40)
      assert r2.cols == 120
      assert r2.rows == 40
      assert r2.backend == :native
      assert r2.frame_count == 0
    end
  end

  describe "get_buffer/1 with :native backend" do
    test "returns NativeBuffer after rendering" do
      r = Renderer.new(20, 5, backend: :native)

      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:text, content: "Test")
        ])

      {r2, _} = Renderer.render(r, tree)
      buf = Renderer.get_buffer(r2)
      assert %NativeBuffer{} = buf
    end
  end
end
