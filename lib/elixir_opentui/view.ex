defmodule ElixirOpentui.View do
  @moduledoc """
  DSL macros for building ElixirOpentui element trees.

  ## Usage

      import ElixirOpentui.View

      box direction: :row, gap: 2 do
        text content: "Hello"
        box flex_grow: 1, bg: Color.blue() do
          label content: "World"
        end
      end

  Each macro expands to `ElixirOpentui.Element.new/3` calls, producing a tree of
  `%ElixirOpentui.Element{}` structs.
  """

  alias ElixirOpentui.Element

  @element_types [
    :box,
    :text,
    :label,
    :panel,
    :button,
    :input,
    :select,
    :checkbox,
    :scroll_box,
    :textarea,
    :code,
    :markdown,
    :diff
  ]

  for type <- @element_types do
    @doc "Create a `#{type}` element."
    defmacro unquote(type)(attrs_or_block \\ []) do
      type = unquote(type)
      {attrs, children} = extract_attrs_and_children(attrs_or_block)
      build_element(type, attrs, children)
    end

    defmacro unquote(type)(attrs, do_block) do
      type = unquote(type)
      children = extract_children(do_block)
      build_element(type, attrs, children)
    end
  end

  @doc "Create a `view` root element (alias for box)."
  defmacro view(attrs_or_block \\ []) do
    {attrs, children} = extract_attrs_and_children(attrs_or_block)
    build_element(:box, attrs, children)
  end

  defmacro view(attrs, do_block) do
    children = extract_children(do_block)
    build_element(:box, attrs, children)
  end

  @doc """
  Render a user-defined component.

      component MyCounter, id: :counter, initial: 0
  """
  defmacro component(module, attrs \\ []) do
    quote do
      Element.new(:component, [{:component, unquote(module)} | unquote(attrs)])
    end
  end

  defp extract_attrs_and_children(attrs_or_block) do
    case Keyword.pop(attrs_or_block, :do) do
      {nil, attrs} -> {attrs, []}
      {block, attrs} -> {attrs, extract_children(do: block)}
    end
  end

  defp extract_children(do: {:__block__, _, children}), do: children
  defp extract_children(do: child) when not is_nil(child), do: [child]
  defp extract_children(do: nil), do: []
  defp extract_children(_), do: []

  defp build_element(type, attrs, children) do
    quote do
      Element.new(unquote(type), unquote(attrs), unquote(children))
    end
  end
end
