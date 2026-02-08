defmodule ElixirOpentui.TestRendererTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.{TestRenderer, Element, Color}

  setup do
    {:ok, renderer} = TestRenderer.start_link(cols: 40, rows: 10)
    %{renderer: renderer}
  end

  describe "start_link/1" do
    test "creates renderer with custom dimensions" do
      {:ok, r} = TestRenderer.start_link(cols: 20, rows: 5)
      buf = TestRenderer.get_buffer(r)
      assert buf.cols == 20
      assert buf.rows == 5
    end

    test "defaults to 80x24" do
      {:ok, r} = TestRenderer.start_link()
      buf = TestRenderer.get_buffer(r)
      assert buf.cols == 80
      assert buf.rows == 24
    end
  end

  describe "render/2" do
    test "renders element and returns buffer", %{renderer: r} do
      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:text, content: "Hello World")
        ])

      buf = TestRenderer.render(r, tree)
      assert buf.cols == 40
      assert buf.rows == 10
    end

    test "frame contains rendered text", %{renderer: r} do
      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:text, content: "Hello")
        ])

      TestRenderer.render(r, tree)
      frame = TestRenderer.get_frame(r)
      assert String.contains?(hd(frame), "Hello")
    end
  end

  describe "get_cell/3" do
    test "returns cell after rendering", %{renderer: r} do
      tree = Element.new(:box, width: 40, height: 10, bg: Color.blue())
      TestRenderer.render(r, tree)
      cell = TestRenderer.get_cell(r, 5, 5)
      assert cell != nil
      assert cell.bg == Color.blue()
    end
  end

  describe "get_hit_id/3" do
    test "returns hit_id for interactive element", %{renderer: r} do
      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:button, id: :my_btn, content: "Click", width: 10, height: 1)
        ])

      TestRenderer.render(r, tree)
      assert TestRenderer.get_hit_id(r, 0, 0) == :my_btn
    end
  end

  describe "resize/3" do
    test "changes buffer dimensions", %{renderer: r} do
      TestRenderer.resize(r, 60, 20)
      buf = TestRenderer.get_buffer(r)
      assert buf.cols == 60
      assert buf.rows == 20
    end
  end

  describe "clear/1" do
    test "clears the buffer", %{renderer: r} do
      tree =
        Element.new(:box, [width: 40, height: 10], [
          Element.new(:text, content: "Hello")
        ])

      TestRenderer.render(r, tree)
      TestRenderer.clear(r)
      frame = TestRenderer.get_frame(r)
      assert Enum.all?(frame, &(String.trim(&1) == ""))
    end
  end

  describe "get_layout/1" do
    test "returns layout results with element ids", %{renderer: r} do
      tree =
        Element.new(:box, [id: :root, width: 40, height: 10], [
          Element.new(:text, id: :title, content: "Title")
        ])

      TestRenderer.render(r, tree)
      layout = TestRenderer.get_layout(r)
      assert Map.has_key?(layout, :root)
      assert Map.has_key?(layout, :title)
    end
  end
end
