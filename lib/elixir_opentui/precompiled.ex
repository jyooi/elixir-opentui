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
    "aarch64-freebsd-none": "da0c50913186a923d269826e4e2a61b63e37bfabfd16da370a2a7fb5cca35dd1",
    "aarch64-linux-gnu": "43ed2e9ca907bfe1f19f5dda73600011e437340153398d5d2294a45cf5b20bfb",
    "aarch64-linux-musl": "cb85947eabf13e74e17271eb247ac3a947232737e14444584149920f76923db5",
    "aarch64-macos-none": "6efd93f8df1766f4843935da49d6e8f68f4c7e00f1637521cb608918b0ed6e19",
    "x86_64-freebsd-none": "d6a1514919716850f15f1ec103c18efe22d7a175e9f75a006eb7057e543dd01d",
    "x86_64-linux-gnu": "f274d173bfec2e2f17d4191e608a94a9bd43681c6dd0835042bdcbfd636525d5",
    "x86_64-linux-musl": "d36747e651d562dbbc4f2b649d39e0e166bf395c98adf15ccdbfce331241d58f",
    "x86_64-macos-none": "13612e44a4d519f9f68ea4ff8c541710a9fce7597e6d7609c3c0552a6b7c71bf"
    ]
  end

  defp edit_buffer_nif_shasums do
    [
    "aarch64-freebsd-none": "466c11f272d04797ce5693c7ad3daa2a554a24c2e71482e4c192489e0d2daa19",
    "aarch64-linux-gnu": "5d32a0b3a9a0b217f7559956dcdaf81c3ec6016aabfe138fcae47b6a4f4acdc3",
    "aarch64-linux-musl": "d468ef8a302d9df66b49ceb1828b772eebfbd5a0ba3d8fe7df3faa461544d361",
    "aarch64-macos-none": "addeeb4755610de4bf441fdecc602c314fef87ddb314de7fa98c48c19d5acdf0",
    "x86_64-freebsd-none": "d96d8f3c86af65adcb60cc61b57972794bc0d2815e7f910a036a554c84b86b65",
    "x86_64-linux-gnu": "1493cc59ba428f2600993de8f42dac5f0434bde448f876894ae35be69420f089",
    "x86_64-linux-musl": "8236e789230a1a8b528ec00dfff1feea3e756be67ec9fc72160de24288e5621e",
    "x86_64-macos-none": "a2321aee4bfd5685e9334d97e662cbf9e430fa7ff8e2c4e026a8d28c956ed408"
    ]
  end
end
