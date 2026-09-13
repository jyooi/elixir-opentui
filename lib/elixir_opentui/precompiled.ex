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

  # The precompile workflow writes these shasums for each release.
  defp edit_buffer_nif_shasums do
    [
      "aarch64-freebsd-none": "16323fbc467059300216a4a3ecc1c4c6d3f053438535a717fc3b9e53c6bc7bc0",
      "aarch64-linux-gnu": "a38b4148aad42b15ae18ffea661a1dd1b6c03fc5e8795a4b1686f168d9e9268f",
      "aarch64-linux-musl": "c2e7b4844e4a2065e4421ddc1720396e68387aa69504eb9932ca1297f4088306",
      "aarch64-macos-none": "200f055a32c049da33f1c8d403c0bbf2ff113c6bf558528e5f29fcdd4670131d",
      "x86_64-freebsd-none": "5576620dc0f8cb7d114a1ede551b3e345ac8062e9d0a1b92ea02051ec07ebce9",
      "x86_64-linux-gnu": "914a58265cd8d2564f0685454ed51cc9ba58be56a4bdc466fcdfa8302fe63f7a",
      "x86_64-linux-musl": "38aa576d79a5052251647f56616b5c6d1c9b756740d675255540ebaefa3c56d0",
      "x86_64-macos-none": "2ef6e8784b797dcec1f792b269c45385ee725ea98b31ae8621f51305f16127b1"
    ]
  end
end
