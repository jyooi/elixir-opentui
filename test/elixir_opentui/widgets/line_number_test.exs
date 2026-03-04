defmodule ElixirOpentui.Widgets.LineNumberTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.LineNumber

  describe "init/1" do
    test "initializes with default values" do
      state = LineNumber.init(%{line_count: 10, id: :ln})
      assert state.line_count == 10
      assert state.scroll_offset == 0
      assert state.min_width == 3
      assert state.padding_right == 1
      assert state.line_number_offset == 0
      assert state.line_colors == %{}
      assert state.line_signs == %{}
      assert state.hide_line_numbers == MapSet.new()
      assert state.line_numbers == %{}
      assert state.show_line_numbers == true
    end

    test "initializes with custom settings" do
      state =
        LineNumber.init(%{
          line_count: 50,
          id: :ln,
          min_width: 5,
          padding_right: 2,
          line_number_offset: 10
        })

      assert state.min_width == 5
      assert state.padding_right == 2
      assert state.line_number_offset == 10
    end
  end

  describe "calculate_gutter_width/1" do
    test "calculates width for small line counts" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      # 5 lines -> 1 digit, min_width 3, padding_right 1 -> max(3, 1+1+1)=3
      width = LineNumber.calculate_gutter_width(state)
      assert width == 3
    end

    test "calculates width for larger line counts" do
      state = LineNumber.init(%{line_count: 1000, id: :ln})
      # 1000 lines -> 4 digits, min_width 3, padding_right 1 -> max(3, 4+1+1)=6
      width = LineNumber.calculate_gutter_width(state)
      assert width == 6
    end

    test "respects min_width" do
      state = LineNumber.init(%{line_count: 5, id: :ln, min_width: 5})
      # 5 lines -> 1 digit, but min_width 5 -> max(5, 1+1+1)=5
      width = LineNumber.calculate_gutter_width(state)
      assert width == 5
    end

    test "accounts for line_number_offset" do
      state = LineNumber.init(%{line_count: 5, id: :ln, line_number_offset: 995})
      # max line = 5 + 995 = 1000 -> 4 digits -> max(3, 4+1+1)=6
      width = LineNumber.calculate_gutter_width(state)
      assert width == 6
    end

    test "accounts for custom line_numbers" do
      state = LineNumber.init(%{line_count: 5, id: :ln, line_numbers: %{0 => 9999}})
      # custom max is 9999 -> 4 digits -> max(3, 4+1+1)=6
      width = LineNumber.calculate_gutter_width(state)
      assert width == 6
    end

    test "accounts for before signs" do
      signs = %{0 => %{before: ">>", before_color: nil}}
      state = LineNumber.init(%{line_count: 5, id: :ln, line_signs: signs})
      # base 3 + max_before 2 + max_after 0 = 5
      width = LineNumber.calculate_gutter_width(state)
      assert width == 5
    end

    test "accounts for after signs" do
      signs = %{0 => %{after: "!", after_color: nil}}
      state = LineNumber.init(%{line_count: 5, id: :ln, line_signs: signs})
      # base 3 + max_before 0 + max_after 1 = 4
      width = LineNumber.calculate_gutter_width(state)
      assert width == 4
    end
  end

  describe "update messages" do
    test "set_line_count" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      state = LineNumber.update({:set_line_count, 20}, nil, state)
      assert state.line_count == 20
    end

    test "set_scroll_offset" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      state = LineNumber.update({:set_scroll_offset, 3}, nil, state)
      assert state.scroll_offset == 3
    end

    test "set_line_colors" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      colors = %{1 => "#2d4a2e", 3 => "#4a2d2d"}
      state = LineNumber.update({:set_line_colors, colors}, nil, state)
      assert state.line_colors == colors
    end

    test "set_line_color (single)" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      state = LineNumber.update({:set_line_color, 2, "#ff0000"}, nil, state)
      assert state.line_colors == %{2 => "#ff0000"}
    end

    test "clear_line_color" do
      state = LineNumber.init(%{line_count: 5, id: :ln, line_colors: %{2 => "#ff0000"}})
      state = LineNumber.update({:clear_line_color, 2}, nil, state)
      assert state.line_colors == %{}
    end

    test "set_line_signs" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      signs = %{0 => %{before: ">>", after: "!"}}
      state = LineNumber.update({:set_line_signs, signs}, nil, state)
      assert state.line_signs == signs
    end

    test "set_line_sign (single)" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      state = LineNumber.update({:set_line_sign, 0, %{before: ">>"}}, nil, state)
      assert state.line_signs == %{0 => %{before: ">>"}}
    end

    test "clear_line_sign" do
      state = LineNumber.init(%{line_count: 5, id: :ln, line_signs: %{0 => %{before: ">>"}}})
      state = LineNumber.update({:clear_line_sign, 0}, nil, state)
      assert state.line_signs == %{}
    end

    test "set_hide_line_numbers" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      state = LineNumber.update({:set_hide_line_numbers, MapSet.new([1, 3])}, nil, state)
      assert MapSet.member?(state.hide_line_numbers, 1)
      assert MapSet.member?(state.hide_line_numbers, 3)
    end

    test "set_line_numbers (custom mapping)" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      state = LineNumber.update({:set_line_numbers, %{0 => 100, 2 => 200}}, nil, state)
      assert state.line_numbers == %{0 => 100, 2 => 200}
    end

    test "set_show_line_numbers" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      state = LineNumber.update({:set_show_line_numbers, false}, nil, state)
      assert state.show_line_numbers == false
    end

    test "set_line_number_offset" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      state = LineNumber.update({:set_line_number_offset, 10}, nil, state)
      assert state.line_number_offset == 10
    end

    test "set_line_sources" do
      state = LineNumber.init(%{line_count: 5, id: :ln})
      sources = [0, 0, 1, 2, 2, 2, 3, 4]
      state = LineNumber.update({:set_line_sources, sources}, nil, state)
      assert state.line_sources == sources
    end
  end

  describe "render" do
    test "produces a :line_number element" do
      state = LineNumber.init(%{line_count: 10, id: :myln})
      tree = LineNumber.render(state)
      assert tree.type == :line_number
      assert tree.id == :myln
    end

    test "render includes gutter_width" do
      state = LineNumber.init(%{line_count: 10, id: :myln})
      tree = LineNumber.render(state)
      assert tree.attrs.gutter_width > 0
    end

    test "render includes all configuration" do
      state =
        LineNumber.init(%{
          line_count: 10,
          id: :myln,
          line_colors: %{1 => "#ff0000"},
          line_signs: %{0 => %{before: ">>"}},
          line_number_offset: 5
        })

      tree = LineNumber.render(state)
      assert tree.attrs.line_colors == %{1 => "#ff0000"}
      assert tree.attrs.line_signs == %{0 => %{before: ">>"}}
      assert tree.attrs.line_number_offset == 5
    end
  end
end
