defmodule ElixirOpentui.Widgets.Markdown do
  @moduledoc """
  Markdown rendering widget via Earmark.

  Parses markdown content and produces a structured element tree with
  styled blocks for headings, paragraphs, code blocks, lists, etc.

  ## Props
  - `:content` — markdown string
  - `:id` — element id
  - `:scroll_offset` — vertical scroll position (default: 0)
  - `:visible_lines` — number of visible lines (default: nil, show all)
  - `:code_filetype` — default filetype for fenced code blocks (optional)
  """

  use ElixirOpentui.Component

  alias ElixirOpentui.Widgets.ScrollHelper

  @impl true
  def init(props) do
    content = Map.get(props, :content, "")
    blocks = parse_markdown(content)

    %{
      content: content,
      blocks: blocks,
      rendered_line_count: count_rendered_lines(blocks),
      id: Map.get(props, :id),
      scroll_offset: Map.get(props, :scroll_offset, 0),
      visible_lines: Map.get(props, :visible_lines),
      code_filetype: Map.get(props, :code_filetype),
      _pending: []
    }
  end

  @impl true
  def update({:set_content, content}, _event, state) do
    blocks = parse_markdown(content)

    %{
      state
      | content: content,
        blocks: blocks,
        scroll_offset: 0,
        rendered_line_count: count_rendered_lines(blocks)
    }
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

    Element.new(:markdown,
      id: state.id,
      content: state.content,
      blocks: state.blocks,
      block_count: length(state.blocks),
      scroll_offset: state.scroll_offset,
      visible_lines: state.visible_lines,
      code_filetype: state.code_filetype
    )
  end

  # --- Key handling ---

  defp handle_key(event, state) do
    case ScrollHelper.handle_scroll_key(event,
           offset: state.scroll_offset,
           total: state.rendered_line_count,
           visible: state.visible_lines
         ) do
      {:handled, new_offset} -> %{state | scroll_offset: new_offset}
      :unhandled -> state
    end
  end

  # NOTE: must mirror painter.ex markdown_blocks_to_lines/10
  defp count_rendered_lines(blocks) do
    Enum.reduce(blocks, 0, fn block, acc ->
      acc +
        case block do
          %{type: :heading} -> 2
          %{type: :paragraph, content: c} -> length(String.split(c, "\n")) + 1
          %{type: :code_block, content: c} -> length(String.split(c, "\n")) + 1
          %{type: :list, items: items} -> length(items) + 1
          %{type: :blockquote, content: c} -> length(String.split(c, "\n")) + 1
          %{type: :horizontal_rule} -> 2
          %{type: :text} -> 1
          _ -> 0
        end
    end)
  end

  # --- Markdown parsing ---

  @doc """
  Parse markdown content into a list of block structures.

  Each block has a `:type` and type-specific fields. Falls back to
  a simple line-based parser if Earmark is not available.
  """
  def parse_markdown(content) when is_binary(content) do
    if earmark_available?() do
      parse_with_earmark(content)
    else
      parse_simple(content)
    end
  end

  def parse_markdown(_), do: []

  defp earmark_available? do
    Code.ensure_loaded?(Earmark)
  end

  defp parse_with_earmark(content) do
    case Earmark.as_ast(content) do
      {:ok, ast, _} -> ast_to_blocks(ast)
      {:error, _, _} -> parse_simple(content)
    end
  end

  defp ast_to_blocks(ast) do
    Enum.flat_map(ast, &ast_node_to_block/1)
  end

  defp ast_node_to_block({"h1", _, children, _}) do
    [%{type: :heading, level: 1, content: extract_text(children)}]
  end

  defp ast_node_to_block({"h2", _, children, _}) do
    [%{type: :heading, level: 2, content: extract_text(children)}]
  end

  defp ast_node_to_block({"h3", _, children, _}) do
    [%{type: :heading, level: 3, content: extract_text(children)}]
  end

  defp ast_node_to_block({"h4", _, children, _}) do
    [%{type: :heading, level: 4, content: extract_text(children)}]
  end

  defp ast_node_to_block({"h5", _, children, _}) do
    [%{type: :heading, level: 5, content: extract_text(children)}]
  end

  defp ast_node_to_block({"h6", _, children, _}) do
    [%{type: :heading, level: 6, content: extract_text(children)}]
  end

  defp ast_node_to_block({"p", _, children, _}) do
    [%{type: :paragraph, content: extract_text(children)}]
  end

  defp ast_node_to_block({"pre", _, [{"code", attrs, [code], _}], _}) do
    lang = find_attr(attrs, "class", "") |> String.replace("language-", "")
    [%{type: :code_block, content: code, language: lang}]
  end

  defp ast_node_to_block({"ul", _, items, _}) do
    list_items = Enum.map(items, fn {"li", _, children, _} -> extract_text(children) end)
    [%{type: :list, ordered: false, items: list_items}]
  end

  defp ast_node_to_block({"ol", _, items, _}) do
    list_items = Enum.map(items, fn {"li", _, children, _} -> extract_text(children) end)
    [%{type: :list, ordered: true, items: list_items}]
  end

  defp ast_node_to_block({"blockquote", _, children, _}) do
    [%{type: :blockquote, content: extract_text(children)}]
  end

  defp ast_node_to_block({"hr", _, _, _}) do
    [%{type: :horizontal_rule}]
  end

  defp ast_node_to_block(text) when is_binary(text) do
    if String.trim(text) == "" do
      []
    else
      [%{type: :text, content: text}]
    end
  end

  defp ast_node_to_block(_), do: []

  defp extract_text(children) when is_list(children) do
    Enum.map_join(children, &extract_text_node/1)
  end

  defp extract_text(text) when is_binary(text), do: text
  defp extract_text(_), do: ""

  defp extract_text_node(text) when is_binary(text), do: text
  defp extract_text_node({"code", _, [code], _}), do: code
  defp extract_text_node({"em", _, children, _}), do: extract_text(children)
  defp extract_text_node({"strong", _, children, _}), do: extract_text(children)
  defp extract_text_node({"a", _, children, _}), do: extract_text(children)
  defp extract_text_node({_tag, _, children, _}), do: extract_text(children)
  defp extract_text_node(_), do: ""

  defp find_attr(attrs, key, default) do
    case List.keyfind(attrs, key, 0) do
      {_, value} -> value
      nil -> default
    end
  end

  # --- Simple fallback parser (no Earmark) ---

  defp parse_simple(content) do
    content
    |> String.split("\n")
    |> Enum.chunk_while(
      [],
      fn line, acc ->
        cond do
          String.starts_with?(line, "#") ->
            {level, text} = parse_heading_line(line)
            block = %{type: :heading, level: level, content: text}

            case acc do
              [] ->
                {:cont, block, []}

              lines ->
                {:cont, %{type: :paragraph, content: Enum.join(Enum.reverse(lines), "\n")},
                 [block]}
            end

          String.trim(line) == "" ->
            case acc do
              [] ->
                {:cont, []}

              lines ->
                {:cont, %{type: :paragraph, content: Enum.join(Enum.reverse(lines), "\n")}, []}
            end

          true ->
            {:cont, [line | acc]}
        end
      end,
      fn
        [] -> {:cont, []}
        lines -> {:cont, %{type: :paragraph, content: Enum.join(Enum.reverse(lines), "\n")}, []}
      end
    )
    |> List.flatten()
  end

  defp parse_heading_line(line) do
    {hashes, rest} = String.split_at(line, count_leading_hashes(line, 0))
    {String.length(hashes), String.trim(rest)}
  end

  defp count_leading_hashes("#" <> rest, n), do: count_leading_hashes(rest, n + 1)
  defp count_leading_hashes(_, n), do: n
end
