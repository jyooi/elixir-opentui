defmodule ElixirOpentui.TestHelpers do
  @moduledoc """
  Shared test utilities for ElixirOpentui tests.

  Maps to ElixirOpentui's testing/test-renderer.ts, providing:
  - TestRenderer creation and frame capture
  - Frame assertion helpers
  - Mock input/mouse helpers (Phase 3)
  """

  import ExUnit.Assertions

  alias ElixirOpentui.TestRenderer
  alias ElixirOpentui.Element
  @doc "Create a test renderer with default 80x24 or custom dimensions."
  def create_test_renderer(opts \\ []) do
    {:ok, renderer} = TestRenderer.start_link(opts)
    renderer
  end

  @doc "Render an element and return the frame as list of strings."
  def render_frame(renderer, %Element{} = element) do
    TestRenderer.render(renderer, element)
    TestRenderer.get_frame(renderer)
  end

  @doc "Assert that the rendered frame contains the given text somewhere."
  def assert_frame_contains(renderer, text) do
    frame = TestRenderer.get_frame(renderer)
    joined = Enum.join(frame)

    assert String.contains?(joined, text),
           "Expected frame to contain #{inspect(text)}, got:\n#{format_frame(frame)}"
  end

  @doc "Assert the character at (x, y) matches."
  def assert_char_at(renderer, x, y, expected_char) do
    cell = TestRenderer.get_cell(renderer, x, y)
    assert cell != nil, "No cell at (#{x}, #{y})"

    assert cell.char == expected_char,
           "Expected char #{inspect(expected_char)} at (#{x}, #{y}), got #{inspect(cell.char)}"
  end

  @doc "Assert the fg color at (x, y) matches."
  def assert_fg_at(renderer, x, y, expected_fg) do
    cell = TestRenderer.get_cell(renderer, x, y)
    assert cell != nil, "No cell at (#{x}, #{y})"

    assert cell.fg == expected_fg,
           "Expected fg #{inspect(expected_fg)} at (#{x}, #{y}), got #{inspect(cell.fg)}"
  end

  @doc "Assert the bg color at (x, y) matches."
  def assert_bg_at(renderer, x, y, expected_bg) do
    cell = TestRenderer.get_cell(renderer, x, y)
    assert cell != nil, "No cell at (#{x}, #{y})"

    assert cell.bg == expected_bg,
           "Expected bg #{inspect(expected_bg)} at (#{x}, #{y}), got #{inspect(cell.bg)}"
  end

  @doc "Assert that the layout rect for a given id matches expected values."
  def assert_layout(renderer, id, expected) do
    layout = TestRenderer.get_layout(renderer)
    rect = Map.get(layout, id)
    assert rect != nil, "No layout found for id #{inspect(id)}"

    if x = Keyword.get(expected, :x), do: assert(rect.x == x, "Expected x=#{x}, got #{rect.x}")
    if y = Keyword.get(expected, :y), do: assert(rect.y == y, "Expected y=#{y}, got #{rect.y}")
    if w = Keyword.get(expected, :w), do: assert(rect.w == w, "Expected w=#{w}, got #{rect.w}")
    if h = Keyword.get(expected, :h), do: assert(rect.h == h, "Expected h=#{h}, got #{rect.h}")
  end

  @doc "Get a nice string representation of the frame for debugging."
  def format_frame(frame) do
    frame
    |> Enum.with_index()
    |> Enum.map(fn {row, i} -> "  #{String.pad_leading(Integer.to_string(i), 2)}│#{row}│" end)
    |> Enum.join("\n")
  end
end
