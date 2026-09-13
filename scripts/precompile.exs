# Custom precompile script for elixir-opentui
#
# Targets only 64-bit platforms (32-bit ARM/x86 fail due to Zigler's
# make.zig c_ulong/u64 mismatch). Run via: mix run scripts/precompile.exs <file>
#
# Usage:
#   mix run scripts/precompile.exs lib/elixir_opentui/edit_buffer_nif.ex

defmodule Precompile do
  @moduledoc false

  @doc "Read the module name from the NIF source file (`Macro.camelize` gives `Nif`, not `NIF`)."
  def nif_module(file) do
    [_, name] = Regex.run(~r/^defmodule\s+([\w.]+)/m, File.read!(file))
    Module.concat([name])
  end

  def run(file) do
    triples = [
      {:aarch64, :freebsd, :none},
      {:aarch64, :linux, :gnu},
      {:aarch64, :linux, :musl},
      {:aarch64, :macos, :none},
      {:x86_64, :freebsd, :none},
      {:x86_64, :linux, :gnu},
      {:x86_64, :linux, :musl},
      {:x86_64, :macos, :none}
      # 32-bit targets (arm, x86) excluded: Zigler make.zig c_ulong/u64 bug
      # Windows excluded: needs MSVC_ROOT/WINSDK_ROOT env vars
    ]

    this = self()
    callback = fn f -> send(this, {:result, f}) end

    results =
      Enum.reduce(triples, [], fn {arch, os, platform}, acc ->
        IO.puts("==> Compiling #{arch}-#{os}-#{platform}...")

        Application.put_env(:zigler, :precompiling, {arch, os, platform, callback})

        try do
          [{_module, _}] = Code.compile_file(file)

          receive do
            {:result, compiled_file} ->
              hash =
                compiled_file
                |> File.read!()
                |> then(&:crypto.hash(:sha256, &1))
                |> Base.encode16(case: :lower)

              IO.puts("    OK: #{Path.basename(compiled_file)} (#{hash})")
              [{:"#{arch}-#{os}-#{platform}", hash} | acc]
          after
            60_000 -> raise "timeout waiting for compile callback"
          end
        rescue
          e ->
            IO.puts("    FAILED: #{Exception.message(e)}")
            acc
        after
          file
          |> nif_module()
          |> Zig.Builder.staging_directory()
          |> File.rm_rf()

          Process.sleep(100)
        end
      end)

    shas =
      results
      |> Enum.reverse()
      |> inspect(pretty: true)
      |> String.split("\n")
      |> Enum.join("\n  ")

    IO.puts("""

    Precompilation complete. Shasums:

      #{shas}

    Copy into the appropriate function in lib/elixir_opentui/precompiled.ex
    """)

    basename = file |> Path.basename(".ex") |> String.downcase()
    shasum_file = "/tmp/shasums_#{basename}.exs"
    File.write!(shasum_file, inspect(Enum.reverse(results), limit: :infinity))
    IO.puts("Wrote machine-readable shasums to #{shasum_file}")
  end
end

case System.argv() do
  [file] -> Precompile.run(file)
  _ -> IO.puts("Usage: mix run scripts/precompile.exs <nif_file.ex>")
end
