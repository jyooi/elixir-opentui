defmodule ElixirOpentui.Demo.PotionLabTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Runtime

  defmodule PotionLab do
    use ElixirOpentui.Component

    alias ElixirOpentui.Color

    @panel_fg Color.rgb(180, 180, 180)
    @panel_bg Color.rgb(20, 20, 35)
    @title_fg Color.rgb(0, 220, 255)
    @label_fg Color.rgb(100, 220, 100)
    @input_bg Color.rgb(40, 40, 60)
    @button_fg Color.rgb(180, 100, 255)
    @button_bg Color.rgb(50, 25, 80)
    @gold_fg Color.rgb(255, 215, 80)
    @divider_fg Color.rgb(100, 100, 100)

    @ingredients ["Dragon Scale", "Moonflower", "Phoenix Feather", "Crystal Dew"]

    def init(props) do
      %{
        name: Map.get(props, :name, ""),
        ingredient: Map.get(props, :ingredient, 0),
        glowing: Map.get(props, :glowing, false),
        bubbling: Map.get(props, :bubbling, false),
        shimmering: Map.get(props, :shimmering, false),
        brewed: Map.get(props, :brewed, false)
      }
    end

    def update(_, _, state), do: state

    def render(state) do
      import ElixirOpentui.View

      ingredient_name = Enum.at(@ingredients, state.ingredient, "Dragon Scale")
      traits = build_traits(state)

      panel id: :lab, title: "Potion Brewing Lab", width: 56, height: 24,
            border: true, fg: @panel_fg, bg: @panel_bg do
        text(content: "~~ Alchemist's Workshop ~~", fg: @title_fg, bg: @panel_bg)
        text(content: "")

        label(content: "Potion Name:", fg: @label_fg, bg: @panel_bg)
        input(
          id: :name_input,
          value: state.name,
          placeholder: "Enter potion name...",
          width: 42,
          height: 1,
          bg: @input_bg,
          fg: @panel_fg
        )
        text(content: "")

        label(content: "Base Ingredient:", fg: @label_fg, bg: @panel_bg)
        select(
          id: :ingredient,
          options: @ingredients,
          selected: state.ingredient,
          height: 4,
          width: 42,
          fg: @panel_fg,
          bg: @panel_bg
        )
        text(content: "")

        label(content: "Magical Properties:", fg: @label_fg, bg: @panel_bg)
        box direction: :row, gap: 2 do
          checkbox(id: :glow, label: "Glowing", checked: state.glowing, fg: @panel_fg, bg: @panel_bg)
          checkbox(id: :bubble, label: "Bubbling", checked: state.bubbling, fg: @panel_fg, bg: @panel_bg)
          checkbox(id: :shimmer, label: "Shimmering", checked: state.shimmering, fg: @panel_fg, bg: @panel_bg)
        end
        text(content: "")

        button(
          id: :brew_btn,
          content: "<< Brew! >>",
          width: 14,
          height: 1,
          fg: @button_fg,
          bg: @button_bg
        )
        text(content: "")

        text(content: String.duplicate("═", 52), fg: @divider_fg, bg: @panel_bg)

        if state.brewed do
          box height: 3 do
            label(content: "Result:", fg: @label_fg, bg: @panel_bg)
            text(
              content: "  >> \"#{state.name}\" <<",
              fg: @gold_fg,
              bg: @panel_bg
            )
            text(
              content: "  A Legendary #{traits} potion made with #{ingredient_name}.",
              fg: @panel_fg,
              bg: @panel_bg
            )
          end
        else
          text(content: "  Awaiting brew command...", fg: @divider_fg, bg: @panel_bg)
        end
      end
    end

    defp build_traits(state) do
      [
        if(state.glowing, do: "glowing"),
        if(state.bubbling, do: "bubbling"),
        if(state.shimmering, do: "shimmering")
      ]
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> "plain"
        traits -> Enum.join(traits, ", ")
      end
    end
  end

  defp mount_lab(props \\ %{}) do
    {:ok, rt} = Runtime.start_link(cols: 56, rows: 24)
    Runtime.mount(rt, PotionLab, props)
    rt
  end

  defp frame_text(rt) do
    Runtime.get_frame(rt) |> Enum.join("\n")
  end

  describe "initial render (empty lab)" do
    test "contains panel title" do
      rt = mount_lab()
      text = frame_text(rt)
      assert String.contains?(text, "Potion Brewing Lab")
    end

    test "contains workshop title" do
      rt = mount_lab()
      text = frame_text(rt)
      assert String.contains?(text, "Alchemist's Workshop")
    end

    test "contains form labels" do
      rt = mount_lab()
      text = frame_text(rt)
      assert String.contains?(text, "Potion Name:")
      assert String.contains?(text, "Base Ingredient:")
      assert String.contains?(text, "Magical Properties:")
    end

    test "contains default ingredient options" do
      rt = mount_lab()
      text = frame_text(rt)
      assert String.contains?(text, "Dragon Scale")
      assert String.contains?(text, "Moonflower")
    end

    test "shows awaiting message when not brewed" do
      rt = mount_lab()
      text = frame_text(rt)
      assert String.contains?(text, "Awaiting brew command")
    end

    test "frame dimensions match" do
      rt = mount_lab()
      frame = Runtime.get_frame(rt)
      assert length(frame) == 24
      assert String.length(hd(frame)) == 56
    end
  end

  describe "filled form" do
    test "shows potion name in input" do
      rt = mount_lab(%{name: "Starfire Elixir", ingredient: 1, glowing: true, shimmering: true})
      text = frame_text(rt)
      assert String.contains?(text, "Starfire Elixir")
    end

    test "shows checked checkboxes" do
      rt = mount_lab(%{glowing: true, shimmering: true})
      text = frame_text(rt)
      assert String.contains?(text, "[x] Glowing")
      assert String.contains?(text, "[x] Shimmering")
      assert String.contains?(text, "[ ] Bubbling")
    end

    test "shows brew button" do
      rt = mount_lab()
      text = frame_text(rt)
      assert String.contains?(text, "<< Brew! >>")
    end
  end

  describe "brewed state" do
    test "shows result text" do
      rt = mount_lab(%{
        name: "Starfire Elixir",
        ingredient: 1,
        glowing: true,
        shimmering: true,
        brewed: true
      })
      text = frame_text(rt)
      assert String.contains?(text, "Result:")
      assert String.contains?(text, "Starfire Elixir")
      assert String.contains?(text, "Legendary")
    end

    test "does not show awaiting message" do
      rt = mount_lab(%{name: "Test", brewed: true})
      text = frame_text(rt)
      refute String.contains?(text, "Awaiting brew")
    end

    test "shows trait description" do
      rt = mount_lab(%{name: "X", glowing: true, bubbling: true, brewed: true})
      text = frame_text(rt)
      assert String.contains?(text, "glowing")
      assert String.contains?(text, "bubbling")
    end
  end

  describe "different brew" do
    test "renders second recipe correctly" do
      rt = mount_lab(%{name: "Frostbite Tonic", ingredient: 3, bubbling: true, brewed: true})
      text = frame_text(rt)
      assert String.contains?(text, "Frostbite Tonic")
      assert String.contains?(text, "Crystal Dew")
      assert String.contains?(text, "bubbling")
    end
  end

  describe "focusable elements" do
    test "detects interactive widgets" do
      rt = mount_lab()
      focus = Runtime.get_focus(rt)
      assert :name_input in focus.focusable_ids
      assert :brew_btn in focus.focusable_ids
      assert :glow in focus.focusable_ids
      assert :bubble in focus.focusable_ids
      assert :shimmer in focus.focusable_ids
    end
  end
end
