defmodule ElixirOpentui.Widgets.Diff do
  @moduledoc """
  Diff display widget with unified and split views.

  Parses unified diff format and renders with line numbers, add/remove
  indicators, and per-line coloring. Supports both unified (single column)
  and split (side-by-side) view modes.

  ## Props
  - `:diff` — unified diff string
  - `:view` — display mode :unified | :split (default: :unified)
  - `:id` — element id
  - `:show_line_numbers` — show line number gutters (default: true)
  - `:scroll_offset` — vertical scroll position (default: 0)
  - `:visible_lines` — number of visible lines (default: nil, show all)
  - `:filetype` — language for syntax highlighting (optional)
  """

  use ElixirOpentui.Component

  alias ElixirOpentui.Widgets.ScrollHelper

  @impl true
  def init(props) do
    diff_text = Map.get(props, :diff, "")
    parsed = parse_diff(diff_text)
    view = Map.get(props, :view, :unified)

    %{
      diff: diff_text,
      parsed: parsed,
      view: view,
      id: Map.get(props, :id),
      show_line_numbers: Map.get(props, :show_line_numbers, true),
      scroll_offset: Map.get(props, :scroll_offset, 0),
      visible_lines: Map.get(props, :visible_lines),
      filetype: Map.get(props, :filetype),
      unified_line_count: length(build_unified_lines(parsed)),
      split_line_count: length(build_split_lines(parsed)),
      _pending: []
    }
  end

  @impl true
  def update({:set_diff, diff_text}, _event, state) do
    parsed = parse_diff(diff_text)

    %{
      state
      | diff: diff_text,
        parsed: parsed,
        scroll_offset: 0,
        unified_line_count: length(build_unified_lines(parsed)),
        split_line_count: length(build_split_lines(parsed))
    }
  end

  def update({:set_view, view}, _event, state) when view in [:unified, :split] do
    %{state | view: view, scroll_offset: 0}
  end

  def update({:set_show_line_numbers, show}, _event, state) do
    %{state | show_line_numbers: show}
  end

  def update({:set_scroll_offset, offset}, _event, state) do
    %{state | scroll_offset: offset}
  end

  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update(_, _, state), do: state

  @impl true
  def render(state) do
    alias ElixirOpentui.Element

    lines =
      case state.view do
        :unified -> build_unified_lines(state.parsed)
        :split -> build_split_lines(state.parsed)
      end

    Element.new(:diff,
      id: state.id,
      diff: state.diff,
      view: state.view,
      lines: lines,
      line_count: current_line_count(state),
      show_line_numbers: state.show_line_numbers,
      scroll_offset: state.scroll_offset,
      visible_lines: state.visible_lines,
      filetype: state.filetype
    )
  end

  # --- Key handling ---

  defp handle_key(event, state) do
    case ScrollHelper.handle_scroll_key(event,
           offset: state.scroll_offset,
           total: current_line_count(state),
           visible: state.visible_lines
         ) do
      {:handled, new_offset} -> %{state | scroll_offset: new_offset}
      :unhandled -> state
    end
  end

  defp current_line_count(%{view: :unified} = state), do: state.unified_line_count
  defp current_line_count(%{view: :split} = state), do: state.split_line_count

  # --- Diff parsing ---

  @doc """
  Parse a unified diff string into a structured representation.

  Returns a list of hunks, where each hunk contains:
  - `:header` — the @@ line
  - `:old_start` — starting line in old file
  - `:new_start` — starting line in new file
  - `:lines` — list of `%{type, content, old_line, new_line}` maps
  """
  def parse_diff(""), do: []

  def parse_diff(diff_text) when is_binary(diff_text) do
    diff_text
    |> String.split("\n")
    |> parse_lines([], nil)
    |> Enum.reverse()
  end

  defp parse_lines([], hunks, current), do: maybe_close_hunk(hunks, current)

  defp parse_lines([line | rest], hunks, current) do
    cond do
      String.starts_with?(line, "@@") ->
        {old_start, new_start} = parse_hunk_header(line)

        new_hunk = %{
          header: line,
          old_start: old_start,
          new_start: new_start,
          old_line: old_start,
          new_line: new_start,
          lines: []
        }

        hunks = maybe_close_hunk(hunks, current)
        parse_lines(rest, hunks, new_hunk)

      current != nil and String.starts_with?(line, "+") ->
        diff_line = %{
          type: :add,
          content: String.slice(line, 1..-1//1),
          old_line: nil,
          new_line: current.new_line
        }

        current = %{current | lines: [diff_line | current.lines], new_line: current.new_line + 1}
        parse_lines(rest, hunks, current)

      current != nil and String.starts_with?(line, "-") ->
        diff_line = %{
          type: :remove,
          content: String.slice(line, 1..-1//1),
          old_line: current.old_line,
          new_line: nil
        }

        current = %{current | lines: [diff_line | current.lines], old_line: current.old_line + 1}
        parse_lines(rest, hunks, current)

      current != nil and String.starts_with?(line, " ") ->
        diff_line = %{
          type: :context,
          content: String.slice(line, 1..-1//1),
          old_line: current.old_line,
          new_line: current.new_line
        }

        current = %{
          current
          | lines: [diff_line | current.lines],
            old_line: current.old_line + 1,
            new_line: current.new_line + 1
        }

        parse_lines(rest, hunks, current)

      # Skip file headers (---/+++ lines), no-newline markers, empty lines
      true ->
        parse_lines(rest, hunks, current)
    end
  end

  defp maybe_close_hunk(hunks, nil), do: hunks

  defp maybe_close_hunk(hunks, current) do
    closed = %{
      header: current.header,
      old_start: current.old_start,
      new_start: current.new_start,
      lines: Enum.reverse(current.lines)
    }

    [closed | hunks]
  end

  defp parse_hunk_header(header) do
    case Regex.run(~r/@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/, header) do
      [_, old, new] -> {String.to_integer(old), String.to_integer(new)}
      _ -> {1, 1}
    end
  end

  @doc "Build display lines from parsed diff state for the current view mode."
  def build_lines(state) do
    case state.view do
      :unified -> build_unified_lines(state.parsed)
      :split -> build_split_lines(state.parsed)
    end
  end

  # --- Line building ---

  defp build_unified_lines(hunks) do
    Enum.flat_map(hunks, fn hunk ->
      hunk.lines
    end)
  end

  defp build_split_lines(hunks) do
    Enum.flat_map(hunks, fn hunk ->
      build_split_hunk(hunk.lines, [])
    end)
  end

  defp build_split_hunk([], acc), do: Enum.reverse(acc)

  defp build_split_hunk(lines, acc) do
    {removes, rest} = Enum.split_while(lines, &(&1.type == :remove))
    {adds, rest} = Enum.split_while(rest, &(&1.type == :add))

    paired = pair_lines(removes, adds)

    acc =
      Enum.reduce(paired, acc, fn {left, right}, acc ->
        [%{left: left, right: right} | acc]
      end)

    case rest do
      [] ->
        Enum.reverse(acc)

      [%{type: :context} = ctx | rest2] ->
        split_line = %{left: ctx, right: ctx}
        build_split_hunk(rest2, [split_line | acc])

      [other | rest2] ->
        # Handle unexpected line types
        split_line = %{
          left: other,
          right: %{type: :empty, content: "", old_line: nil, new_line: nil}
        }

        build_split_hunk(rest2, [split_line | acc])
    end
  end

  defp pair_lines(removes, adds) do
    max_len = max(length(removes), length(adds))
    empty = %{type: :empty, content: "", old_line: nil, new_line: nil}

    removes = removes ++ List.duplicate(empty, max_len - length(removes))
    adds = adds ++ List.duplicate(empty, max_len - length(adds))

    Enum.zip(removes, adds)
  end
end
