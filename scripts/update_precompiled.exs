# Updates lib/elixir_opentui/precompiled.ex with shasums from /tmp.
#
# Run as: elixir scripts/update_precompiled.exs
# (plain Elixir, no Mix — avoids recompiling the file we're modifying)
#
# Expects /tmp/shasums_nif.exs and /tmp/shasums_edit_buffer_nif.exs
# to contain valid Elixir keyword list terms, written by precompile.exs.

target = "lib/elixir_opentui/precompiled.ex"
source = File.read!(target)

format_shasums = fn path ->
  {shasums, _} = path |> File.read!() |> Code.eval_string()

  shasums
  |> Enum.map(fn {k, v} -> ~s(    "#{k}": "#{v}") end)
  |> Enum.join(",\n")
end

nif_shasums = format_shasums.("/tmp/shasums_nif.exs")
edit_buffer_shasums = format_shasums.("/tmp/shasums_edit_buffer_nif.exs")

# Replace edit_buffer_nif_shasums FIRST (longer name prevents partial match)
edit_buffer_re = ~r/defp edit_buffer_nif_shasums do\n\s*\[.*?\]\n\s*end/s

updated =
  Regex.replace(edit_buffer_re, source, """
  defp edit_buffer_nif_shasums do
      [
  #{edit_buffer_shasums}
      ]
    end\
  """)

if updated == source do
  IO.puts(:stderr, "ERROR: edit_buffer_nif_shasums replacement did not match")
  System.halt(1)
end

# Then replace nif_shasums
nif_re = ~r/defp nif_shasums do\n\s*\[.*?\]\n\s*end/s

final =
  Regex.replace(nif_re, updated, """
  defp nif_shasums do
      [
  #{nif_shasums}
      ]
    end\
  """)

if final == updated do
  IO.puts(:stderr, "ERROR: nif_shasums replacement did not match")
  System.halt(1)
end

File.write!(target, final)
IO.puts("Updated #{target} with shasums for both NIFs")
