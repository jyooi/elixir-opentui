defmodule ElixirOpentui.Precompiled do
  @moduledoc """
  Download URLs and SHA256 hashes for prebuilt NIF binaries.

  Zero-dependency module — must not reference any NIF module to avoid
  circular compile dependencies. Zigler's `normalize_shasum/1` returns
  `nil` for platforms not listed here, causing `precompiled:` to resolve
  to `nil` and triggering source compilation as a fallback.
  """

  @base_url "https://github.com/jyooi/elixir-opentui/releases/download/v#VERSION"

  @doc "Precompiled config for ElixirOpentui.NIF"
  def nif_precompiled do
    {:web, "#{@base_url}/Elixir.ElixirOpentui.NIF.#TRIPLE.#EXT", nif_shasums()}
  end

  @doc "Precompiled config for ElixirOpentui.EditBufferNIF"
  def edit_buffer_nif_precompiled do
    {:web, "#{@base_url}/Elixir.ElixirOpentui.EditBufferNIF.#TRIPLE.#EXT",
     edit_buffer_nif_shasums()}
  end

  # Populated by CI after running `mix zig.precompile`.
  # Platforms not listed fall back to source compilation.
  defp nif_shasums do
    [
      # "x86_64-linux-gnu": "sha256hex...",
      # "aarch64-linux-gnu": "sha256hex...",
      # "x86_64-macos-none": "sha256hex...",
      # "aarch64-macos-none": "sha256hex...",
    ]
  end

  defp edit_buffer_nif_shasums do
    [
      # "x86_64-linux-gnu": "sha256hex...",
      # "aarch64-linux-gnu": "sha256hex...",
      # "x86_64-macos-none": "sha256hex...",
      # "aarch64-macos-none": "sha256hex...",
    ]
  end
end
