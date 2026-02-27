defmodule ElixirOpentui.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_opentui,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zigler, "~> 0.15.2", runtime: false},
      {:makeup, "~> 1.2"},
      {:makeup_elixir, "~> 1.0", optional: true},
      {:makeup_ts, "~> 0.2", optional: true},
      {:earmark, "~> 1.4", optional: true}
    ]
  end
end
