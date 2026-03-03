defmodule ElixirOpentui.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jyooi/elixir-opentui"

  def project do
    [
      app: :elixir_opentui,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: "A terminal UI framework for Elixir with a high-performance Zig NIF backend.",
      name: "ElixirOpentui",
      source_url: @source_url,
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "OpenTUI (upstream Zig)" => "https://github.com/anomalyco/opentui"
      },
      files: ~w(lib zig .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "guides/getting-started.md"],
      source_ref: "v#{@version}",
      groups_for_modules: [
        Widgets: ~r/Widgets\./,
        Animation: ~r/Animation\./,
        Core: [
          ElixirOpentui.Element,
          ElixirOpentui.View,
          ElixirOpentui.Component,
          ElixirOpentui.Style
        ],
        Rendering: [
          ElixirOpentui.Renderer,
          ElixirOpentui.Buffer,
          ElixirOpentui.NativeBuffer,
          ElixirOpentui.Painter,
          ElixirOpentui.ANSI
        ],
        Layout: [ElixirOpentui.Layout],
        Terminal: [ElixirOpentui.Terminal, ElixirOpentui.Input, ElixirOpentui.Capabilities]
      ]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:zigler, "~> 0.15.2", runtime: false},
      {:makeup, "~> 1.2", optional: true},
      {:makeup_elixir, "~> 1.0", optional: true},
      {:makeup_ts, "~> 0.2", optional: true},
      {:earmark, "~> 1.4", optional: true}
    ]
  end
end
