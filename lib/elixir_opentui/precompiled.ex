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
      "aarch64-freebsd-none": "1fea53c5c9855f338d1e58b31b40f0784aca8390c009fe6c0549f8a8ae150491",
      "aarch64-linux-gnu": "a88ce74c21f2a2d880856ec6ae367b111b35d2e6efd861b9afaaa294317c40ee",
      "aarch64-linux-musl": "76e0c8681bfa6d9894cb82a765f4352c2b650d4ee19c61a957a2b932facfcdff",
      "aarch64-macos-none": "19269f62a612c6e6fe716fe997f189bcf49bae1c2842760ff817c286e0b69958",
      "x86_64-freebsd-none": "43a3b78153ab0bb99c33c875f624406216b6f076bfef5f2ea02e500c4be81e15",
      "x86_64-linux-gnu": "2d4d5d8d030005803dccc0d3dfd9fb3003ed4139c1b6eb124dc98a11db072970",
      "x86_64-linux-musl": "a61910db7a9a8e7c2f8eb71bc10ce1cf10201a62c1740fc8a8a82c454690abf8",
      "x86_64-macos-none": "03639503a396dd386f4a21bb981af5b06d5dc944cbd91304bb76a4eaa86826aa"
    ]
  end

  defp edit_buffer_nif_shasums do
    [
      "aarch64-freebsd-none": "11065a7e2c2bdf65ab708decbcec5d13a55cb41f429e049cb8ce68e1b66b78e1",
      "aarch64-linux-gnu": "b730f715fdf9b7f437632af099a2abe638ed28dbdcd816e550a9f9347fd6de5d",
      "aarch64-linux-musl": "1772faa1565604fc0cfe91ae56a213e00104d00b1708fc3982d257d34e800b79",
      "aarch64-macos-none": "bf1e04bb8e0aa5c10e5341bec9ae31a3689f38a7b316d3a4665bbe86bf62d4d5",
      "x86_64-freebsd-none": "7ad4c6a9e8c5798b8100d3fecb22c6964a9d381763c02c3d1e0bf4e9162c6a77",
      "x86_64-linux-gnu": "ba91b0c5493a8be144173a1491ea66d5bfca78e1b9cbbcb173b0c22f8f609ad8",
      "x86_64-linux-musl": "af2f583619a3d1f307affab6e952222bb306965442b6fdb2f41b481c5654f764",
      "x86_64-macos-none": "f42d1042ea39322d5641890d891d77608f77deb257779c5c95128a71537253f5"
    ]
  end
end
