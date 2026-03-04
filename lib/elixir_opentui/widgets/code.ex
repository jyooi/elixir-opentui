defmodule ElixirOpentui.Widgets.Code do
  @moduledoc """
  Code display widget with syntax highlighting via Makeup.

  Renders source code with syntax highlighting for supported languages.
  Uses the Makeup library for tokenization and applies terminal-compatible
  colors to different token types.

  ## Props
  - `:content` — source code string
  - `:filetype` — language identifier for highlighting (e.g., "elixir", "html")
  - `:id` — element id
  - `:show_line_numbers` — show line number gutter (default: true)
  - `:line_number_offset` — offset for line numbering (default: 0)
  - `:wrap_mode` — text wrapping mode :none | :char | :word (default: :none)
  - `:scroll_offset` — vertical scroll position (default: 0)
  - `:visible_lines` — number of visible lines (default: nil, show all)
  - `:streaming` — whether content is being streamed (default: false)
  """

  use ElixirOpentui.Component

  alias ElixirOpentui.Widgets.ScrollHelper

  @impl true
  def init(props) do
    content = Map.get(props, :content, "")
    filetype = Map.get(props, :filetype)

    tokens = highlight(content, filetype)

    %{
      content: content,
      filetype: filetype,
      tokens: tokens,
      id: Map.get(props, :id),
      show_line_numbers: Map.get(props, :show_line_numbers, true),
      line_number_offset: Map.get(props, :line_number_offset, 0),
      wrap_mode: Map.get(props, :wrap_mode, :none),
      scroll_offset: Map.get(props, :scroll_offset, 0),
      visible_lines: Map.get(props, :visible_lines),
      streaming: Map.get(props, :streaming, false),
      line_count: length(String.split(content, "\n"))
    }
  end

  @impl true
  def update({:set_content, content}, _event, state) do
    tokens = highlight(content, state.filetype)
    %{state | content: content, tokens: tokens, line_count: length(String.split(content, "\n"))}
  end

  def update({:set_content, content, filetype}, _event, state) do
    tokens = highlight(content, filetype)

    %{
      state
      | content: content,
        filetype: filetype,
        tokens: tokens,
        line_count: length(String.split(content, "\n"))
    }
  end

  def update({:set_filetype, filetype}, _event, state) do
    tokens = highlight(state.content, filetype)
    %{state | filetype: filetype, tokens: tokens}
  end

  def update({:set_scroll_offset, offset}, _event, state) do
    %{state | scroll_offset: offset}
  end

  def update({:set_show_line_numbers, show}, _event, state) do
    %{state | show_line_numbers: show}
  end

  def update({:set_streaming, streaming}, _event, state) do
    %{state | streaming: streaming}
  end

  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update(_, _, state), do: state

  @impl true
  def render(state) do
    import ElixirOpentui.View, only: [code: 1]

    lines = String.split(state.content, "\n")

    code(
      id: state.id,
      content: state.content,
      filetype: state.filetype,
      tokens: state.tokens,
      lines: lines,
      line_count: state.line_count,
      show_line_numbers: state.show_line_numbers,
      line_number_offset: state.line_number_offset,
      wrap_mode: state.wrap_mode,
      scroll_offset: state.scroll_offset,
      visible_lines: state.visible_lines,
      streaming: state.streaming
    )
  end

  # --- Key handling for scrolling ---

  defp handle_key(event, state) do
    case ScrollHelper.handle_scroll_key(event,
           offset: state.scroll_offset,
           total: state.line_count,
           visible: state.visible_lines
         ) do
      {:handled, new_offset} -> %{state | scroll_offset: new_offset}
      :unhandled -> state
    end
  end

  # --- Syntax highlighting ---

  @doc """
  Tokenize source code using Makeup for the given filetype.

  Returns a list of `{token_type, metadata, text}` tuples, or the raw
  content string if no lexer is available for the filetype.
  """
  @spec highlight(String.t() | nil, String.t() | nil) :: list() | nil
  def highlight(content, filetype) when is_binary(content) do
    case get_lexer(filetype) do
      nil -> nil
      lexer -> safe_lex(lexer, content)
    end
  end

  def highlight(_, _), do: nil

  defp safe_lex(lexer, content) do
    try do
      lexer.lex(content)
    rescue
      _ -> nil
    end
  end

  defp get_lexer("elixir"), do: get_lexer_module(Makeup.Lexers.ElixirLexer)
  defp get_lexer("ex"), do: get_lexer_module(Makeup.Lexers.ElixirLexer)
  defp get_lexer("exs"), do: get_lexer_module(Makeup.Lexers.ElixirLexer)
  defp get_lexer("typescript"), do: get_lexer_module(MakeupTS.Lexer)
  defp get_lexer("javascript"), do: get_lexer_module(MakeupTS.Lexer)
  defp get_lexer("ts"), do: get_lexer_module(MakeupTS.Lexer)
  defp get_lexer("js"), do: get_lexer_module(MakeupTS.Lexer)
  defp get_lexer("tsx"), do: get_lexer_module(MakeupTS.Lexer)
  defp get_lexer("jsx"), do: get_lexer_module(MakeupTS.Lexer)
  defp get_lexer(_), do: nil

  defp get_lexer_module(module) do
    if Code.ensure_loaded?(module), do: module, else: nil
  end
end
