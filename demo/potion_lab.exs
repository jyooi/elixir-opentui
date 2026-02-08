# Potion Brewing Lab Demo
# Run: mix run demo/potion_lab.exs
#
# Showcases the high-level component API:
#   Component behaviour + View DSL + Renderer.render_full → ANSI color output
#
# 4 storyboard scenes rendered progressively with full 24-bit color.

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

# ── Storyboard Scenes ──────────────────────────────────────────────────────

alias ElixirOpentui.Renderer

scenes = [
  {"Scene 1: Empty Lab",
   %{}},
  {"Scene 2: Filling the Form",
   %{name: "Starfire Elixir", ingredient: 1, glowing: true, shimmering: true}},
  {"Scene 3: Brewed!",
   %{name: "Starfire Elixir", ingredient: 1, glowing: true, shimmering: true, brewed: true}},
  {"Scene 4: Different Brew",
   %{name: "Frostbite Tonic", ingredient: 3, bubbling: true, brewed: true}}
]

IO.write("\e[2J\e[H")

for {title, props} <- scenes do
  state = PotionLab.init(props)
  tree = PotionLab.render(state)

  renderer = Renderer.new(56, 24)
  {_renderer, ansi} = Renderer.render_full(renderer, tree)

  IO.puts("\e[1;38;2;200;200;200m── #{title} ──\e[0m\n")
  IO.write(ansi)
  IO.write("\e[0m\n\n")
end

IO.puts("\e[38;2;100;100;100m(demo/potion_lab.exs — ElixirOpentui high-level component showcase)\e[0m")
