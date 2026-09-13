defmodule ElixirOpentui.Precompiled do
  @moduledoc """
  Download URLs and SHA256 hashes for prebuilt NIF binaries.

  Zero-dependency module — must not reference any NIF module to avoid
  circular compile dependencies. Zigler's `normalize_shasum/1` returns
  `nil` for platforms not listed here, causing `precompiled:` to resolve
  to `nil` and triggering source compilation as a fallback.
  """

  @version Mix.Project.config()[:version]
  @base_url "https://github.com/jyooi/elixir-opentui/releases/download/v#{@version}"

  @doc "Precompiled config for ElixirOpentui.EditBufferNIF"
  def edit_buffer_nif_precompiled do
    {:web, "#{@base_url}/Elixir.ElixirOpentui.EditBufferNIF.#TRIPLE.#EXT",
     edit_buffer_nif_shasums()}
  end

  # Empty until the precompile workflow refills it after the NIF source change.
  # An empty list means every platform compiles from source.
  defp edit_buffer_nif_shasums do
    []
  end
end
