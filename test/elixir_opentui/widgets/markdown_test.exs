defmodule ElixirOpentui.Widgets.MarkdownTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.Markdown

  defp key(k, opts \\ []) do
    %{
      type: :key,
      key: k,
      ctrl: Keyword.get(opts, :ctrl, false),
      alt: Keyword.get(opts, :alt, false),
      shift: Keyword.get(opts, :shift, false),
      meta: false
    }
  end

  @sample_markdown """
  # Heading 1

  This is a paragraph with **bold** and *italic* text.

  ## Heading 2

  - Item 1
  - Item 2
  - Item 3

  ```elixir
  defmodule Hello do
    def world, do: :ok
  end
  ```

  > This is a blockquote

  ---

  1. First
  2. Second
  """

  describe "init/1" do
    test "initializes with content and defaults" do
      state = Markdown.init(%{content: @sample_markdown, id: :md})
      assert state.content == @sample_markdown
      assert state.scroll_offset == 0
    end

    test "initializes empty" do
      state = Markdown.init(%{id: :md})
      assert state.content == ""
      assert state.blocks == []
    end
  end

  describe "parse_markdown/1" do
    test "parses headings" do
      blocks = Markdown.parse_markdown("# Title\n\n## Subtitle")
      headings = Enum.filter(blocks, &(&1.type == :heading))
      assert length(headings) >= 2

      h1 = Enum.find(headings, &(&1.level == 1))
      assert h1.content =~ "Title"

      h2 = Enum.find(headings, &(&1.level == 2))
      assert h2.content =~ "Subtitle"
    end

    test "parses paragraphs" do
      blocks = Markdown.parse_markdown("Hello world\n\nSecond paragraph")
      paragraphs = Enum.filter(blocks, &(&1.type == :paragraph))
      assert length(paragraphs) >= 1
    end

    test "handles empty content" do
      assert Markdown.parse_markdown("") == []
    end

    test "handles complex markdown" do
      blocks = Markdown.parse_markdown(@sample_markdown)
      assert length(blocks) > 0

      types = Enum.map(blocks, & &1.type) |> Enum.uniq()
      assert :heading in types
    end
  end

  @has_earmark Code.ensure_loaded?(Earmark)

  describe "earmark parsing" do
    @describetag skip: if(!@has_earmark, do: "Earmark not available")

    test "parses code blocks" do
      md = "```elixir\ndefmodule Foo do\nend\n```"
      blocks = Markdown.parse_markdown(md)
      code_blocks = Enum.filter(blocks, &(&1.type == :code_block))
      assert length(code_blocks) > 0
      block = hd(code_blocks)
      assert block.language == "elixir"
      assert block.content =~ "defmodule"
    end

    test "parses unordered lists" do
      md = "- Apple\n- Banana\n- Cherry"
      blocks = Markdown.parse_markdown(md)
      lists = Enum.filter(blocks, &(&1.type == :list))
      assert length(lists) > 0
      list = hd(lists)
      assert list.ordered == false
      assert length(list.items) == 3
    end

    test "parses ordered lists" do
      md = "1. First\n2. Second\n3. Third"
      blocks = Markdown.parse_markdown(md)
      lists = Enum.filter(blocks, &(&1.type == :list))
      assert length(lists) > 0
      list = hd(lists)
      assert list.ordered == true
      assert length(list.items) == 3
    end

    test "parses blockquotes" do
      md = "> This is a quote"
      blocks = Markdown.parse_markdown(md)
      quotes = Enum.filter(blocks, &(&1.type == :blockquote))
      assert length(quotes) > 0
      assert hd(quotes).content =~ "quote"
    end

    test "parses horizontal rules" do
      md = "---"
      blocks = Markdown.parse_markdown(md)
      rules = Enum.filter(blocks, &(&1.type == :horizontal_rule))
      assert length(rules) > 0
      assert hd(rules).type == :horizontal_rule
    end
  end

  describe "updates" do
    test "set_content reparses" do
      state = Markdown.init(%{content: "# Old", id: :md})
      state = Markdown.update({:set_content, "# New\n\nParagraph"}, nil, state)
      assert state.content == "# New\n\nParagraph"
      assert length(state.blocks) > 0
    end

    test "set_scroll_offset" do
      state = Markdown.init(%{content: @sample_markdown, id: :md})
      state = Markdown.update({:set_scroll_offset, 5}, nil, state)
      assert state.scroll_offset == 5
    end
  end

  describe "scrolling" do
    test "down increments scroll_offset" do
      state = Markdown.init(%{content: @sample_markdown, id: :md, visible_lines: 5})
      state = Markdown.update(:key, key(:down), state)
      assert state.scroll_offset == 1
    end

    test "up decrements scroll_offset" do
      state = Markdown.init(%{content: @sample_markdown, id: :md})
      state = %{state | scroll_offset: 3}
      state = Markdown.update(:key, key(:up), state)
      assert state.scroll_offset == 2
    end

    test "up stops at 0" do
      state = Markdown.init(%{content: @sample_markdown, id: :md})
      state = Markdown.update(:key, key(:up), state)
      assert state.scroll_offset == 0
    end

    test "home goes to top" do
      state = Markdown.init(%{content: @sample_markdown, id: :md})
      state = %{state | scroll_offset: 10}
      state = Markdown.update(:key, key(:home), state)
      assert state.scroll_offset == 0
    end
  end

  describe "render" do
    test "produces a :markdown element" do
      state = Markdown.init(%{content: @sample_markdown, id: :mymd})
      tree = Markdown.render(state)
      assert tree.type == :markdown
      assert tree.id == :mymd
    end

    test "includes blocks and block_count" do
      state = Markdown.init(%{content: @sample_markdown, id: :mymd})
      tree = Markdown.render(state)
      assert tree.attrs.block_count > 0
      assert is_list(tree.attrs.blocks)
    end
  end
end
