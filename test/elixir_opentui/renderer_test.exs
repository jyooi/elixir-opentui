defmodule ElixirOpentui.RendererTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{Renderer, Element, Buffer, Color}

  describe "new/2" do
    test "creates renderer with correct dimensions" do
      r = Renderer.new(80, 24)
      assert r.cols == 80
      assert r.rows == 24
      assert r.frame_count == 0
    end

    test "front and back buffers match dimensions" do
      r = Renderer.new(40, 10)
      assert r.front.cols == 40
      assert r.front.rows == 10
      assert r.back.cols == 40
      assert r.back.rows == 10
    end
  end

  describe "render/2" do
    test "returns updated renderer and ANSI output" do
      r = Renderer.new(20, 5)

      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:text, content: "Hello")
        ])

      {r2, output} = Renderer.render(r, tree)
      assert r2.frame_count == 1
      binary = IO.iodata_to_binary(output)
      assert String.contains?(binary, "Hello")
    end

    test "subsequent renders produce smaller diffs" do
      r = Renderer.new(20, 5)

      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:text, content: "Hello")
        ])

      {r2, first_output} = Renderer.render(r, tree)

      {_r3, second_output} = Renderer.render(r2, tree)
      first_size = IO.iodata_to_binary(first_output) |> byte_size()
      second_size = IO.iodata_to_binary(second_output) |> byte_size()
      assert second_size < first_size
    end

    test "changing content produces diff output" do
      r = Renderer.new(20, 5)
      tree1 = Element.new(:box, [width: 20, height: 5], [Element.new(:text, content: "AAA")])
      tree2 = Element.new(:box, [width: 20, height: 5], [Element.new(:text, content: "BBB")])

      {r2, _} = Renderer.render(r, tree1)
      {_r3, output} = Renderer.render(r2, tree2)
      binary = IO.iodata_to_binary(output)
      assert String.contains?(binary, "B")
    end

    test "frame count increments" do
      r = Renderer.new(10, 3)
      tree = Element.new(:box, width: 10, height: 3)
      {r2, _} = Renderer.render(r, tree)
      {r3, _} = Renderer.render(r2, tree)
      assert r3.frame_count == 2
    end
  end

  describe "render_full/2" do
    test "produces full screen output" do
      r = Renderer.new(20, 5)

      tree =
        Element.new(:box, [width: 20, height: 5], [
          Element.new(:text, content: "Full")
        ])

      {r2, output} = Renderer.render_full(r, tree)
      binary = IO.iodata_to_binary(output)
      assert String.contains?(binary, "Full")
      assert String.contains?(binary, "\e[2J")
      assert r2.frame_count == 1
    end
  end

  describe "resize/3" do
    test "creates new renderer with new dimensions" do
      r = Renderer.new(80, 24)
      r2 = Renderer.resize(r, 120, 40)
      assert r2.cols == 120
      assert r2.rows == 40
      assert r2.frame_count == 0
    end
  end

  describe "get_buffer/1" do
    test "returns the front buffer after rendering" do
      r = Renderer.new(20, 5)

      tree =
        Element.new(:box, [width: 20, height: 5, bg: Color.blue()], [
          Element.new(:text, content: "Test")
        ])

      {r2, _} = Renderer.render(r, tree)
      buf = Renderer.get_buffer(r2)
      assert buf.cols == 20
      cell = Buffer.get_cell(buf, 0, 0)
      assert cell.char == "T"
    end
  end

  describe "compute_layout/2" do
    test "computes layout without rendering" do
      r = Renderer.new(40, 10)

      tree =
        Element.new(:box, [id: :root, width: 40, height: 10], [
          Element.new(:text, id: :title, content: "Title")
        ])

      {_tagged, layout} = Renderer.compute_layout(r, tree)
      assert Map.has_key?(layout, :root)
      assert Map.has_key?(layout, :title)
    end
  end
end
