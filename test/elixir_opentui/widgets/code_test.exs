defmodule ElixirOpentui.Widgets.CodeTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.Code

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

  @sample_code """
  defmodule Hello do
    def greet(name) do
      IO.puts("Hello, \#{name}!")
    end
  end
  """

  describe "init/1" do
    test "initializes with content and defaults" do
      state = Code.init(%{content: @sample_code, id: :code})
      assert state.content == @sample_code
      assert state.show_line_numbers == true
      assert state.line_number_offset == 0
      assert state.wrap_mode == :none
      assert state.scroll_offset == 0
      assert state.streaming == false
    end

    test "initializes with filetype" do
      state = Code.init(%{content: @sample_code, filetype: "elixir", id: :code})
      assert state.filetype == "elixir"
    end

    test "initializes empty" do
      state = Code.init(%{id: :code})
      assert state.content == ""
      assert state.tokens == nil
    end
  end

  describe "content updates" do
    test "set_content updates content" do
      state = Code.init(%{content: "original", id: :code})
      state = Code.update({:set_content, "updated"}, nil, state)
      assert state.content == "updated"
    end

    test "set_content with filetype updates both" do
      state = Code.init(%{content: "old", id: :code})
      state = Code.update({:set_content, "new code", "elixir"}, nil, state)
      assert state.content == "new code"
      assert state.filetype == "elixir"
    end

    test "set_filetype updates filetype and re-highlights" do
      state = Code.init(%{content: @sample_code, id: :code})
      state = Code.update({:set_filetype, "elixir"}, nil, state)
      assert state.filetype == "elixir"
    end
  end

  describe "highlighting" do
    test "returns nil tokens for unknown filetype" do
      assert Code.highlight("some code", "unknown_lang") == nil
    end

    test "returns nil tokens for nil filetype" do
      assert Code.highlight("some code", nil) == nil
    end
  end

  @has_makeup_elixir Elixir.Code.ensure_loaded?(Makeup.Lexers.ElixirLexer)

  describe "syntax highlighting" do
    @describetag skip: if(!@has_makeup_elixir, do: "Makeup.Lexers.ElixirLexer not available")

    test "highlights elixir code" do
      tokens = Code.highlight("defmodule Foo do\nend", "elixir")
      assert is_list(tokens)
      assert length(tokens) > 0
    end

    test "highlights with 'ex' alias" do
      tokens = Code.highlight("def hello, do: :ok", "ex")
      assert is_list(tokens)
    end

    test "handles empty content" do
      tokens = Code.highlight("", "elixir")
      assert is_list(tokens)
    end
  end

  describe "scrolling" do
    test "down increments scroll_offset" do
      state = Code.init(%{content: "a\nb\nc\nd\ne", id: :code, visible_lines: 3})
      state = Code.update(:key, key(:down), state)
      assert state.scroll_offset == 1
    end

    test "up decrements scroll_offset" do
      state = Code.init(%{content: "a\nb\nc\nd\ne", id: :code, visible_lines: 3})
      state = %{state | scroll_offset: 2}
      state = Code.update(:key, key(:up), state)
      assert state.scroll_offset == 1
    end

    test "up stops at 0" do
      state = Code.init(%{content: "a\nb\nc", id: :code, visible_lines: 3})
      state = Code.update(:key, key(:up), state)
      assert state.scroll_offset == 0
    end

    test "home goes to top" do
      state = Code.init(%{content: "a\nb\nc\nd\ne", id: :code, visible_lines: 3})
      state = %{state | scroll_offset: 3}
      state = Code.update(:key, key(:home), state)
      assert state.scroll_offset == 0
    end

    test "end goes to bottom" do
      state = Code.init(%{content: "a\nb\nc\nd\ne", id: :code, visible_lines: 3})
      state = Code.update(:key, key(:end), state)
      assert state.scroll_offset == 2
    end

    test "page_down jumps by visible_lines" do
      state = Code.init(%{content: "a\nb\nc\nd\ne\nf\ng\nh\ni\nj", id: :code, visible_lines: 3})
      state = Code.update(:key, key(:page_down), state)
      assert state.scroll_offset == 3
    end

    test "page_up jumps back by visible_lines" do
      state = Code.init(%{content: "a\nb\nc\nd\ne\nf\ng\nh\ni\nj", id: :code, visible_lines: 3})
      state = %{state | scroll_offset: 5}
      state = Code.update(:key, key(:page_up), state)
      assert state.scroll_offset == 2
    end
  end

  describe "configuration" do
    test "set_scroll_offset" do
      state = Code.init(%{content: "a\nb\nc", id: :code})
      state = Code.update({:set_scroll_offset, 1}, nil, state)
      assert state.scroll_offset == 1
    end

    test "set_show_line_numbers" do
      state = Code.init(%{content: "a", id: :code})
      state = Code.update({:set_show_line_numbers, false}, nil, state)
      assert state.show_line_numbers == false
    end

    test "set_streaming" do
      state = Code.init(%{content: "a", id: :code})
      state = Code.update({:set_streaming, true}, nil, state)
      assert state.streaming == true
    end
  end

  describe "update_props/3" do
    test "clamps scroll offset when content shrinks" do
      prev_props = %{content: "a\nb\nc\nd\ne", visible_lines: 3, id: :code}
      new_props = %{content: "x\ny", visible_lines: 3, id: :code}

      state = Code.init(prev_props)
      state = %{state | scroll_offset: 2}
      state = Code.update_props(prev_props, new_props, state)

      assert state.content == "x\ny"
      assert state.scroll_offset == 0
    end

    test "preserves local toggles when parent does not control those props" do
      prev_props = %{content: "a\nb\nc", id: :code}
      new_props = %{content: "a\nb\nc", id: :code}

      state = Code.init(prev_props)
      state = Code.update({:set_show_line_numbers, false}, nil, state)
      state = Code.update({:set_streaming, true}, nil, state)
      state = Code.update_props(prev_props, new_props, state)

      assert state.show_line_numbers == false
      assert state.streaming == true
    end
  end

  describe "render" do
    test "produces a :code element" do
      state = Code.init(%{content: @sample_code, filetype: "elixir", id: :mycode})
      tree = Code.render(state)
      assert tree.type == :code
      assert tree.id == :mycode
    end

    test "render includes line count" do
      state = Code.init(%{content: "a\nb\nc", id: :mycode})
      tree = Code.render(state)
      assert tree.attrs.line_count == 3
    end

    test "render includes lines" do
      state = Code.init(%{content: "hello\nworld", id: :mycode})
      tree = Code.render(state)
      assert tree.attrs.lines == ["hello", "world"]
    end
  end
end
