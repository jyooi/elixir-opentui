# Updates lib/elixir_opentui/precompiled.ex with shasums from /tmp.
#
# Run as: elixir scripts/update_precompiled.exs
# (plain Elixir, no Mix — avoids recompiling the file we're modifying)
#
# Expects /tmp/shasums_edit_buffer_nif.exs to contain a valid Elixir
# keyword list term, written by precompile.exs.

target = "lib/elixir_opentui/precompiled.ex"
source = File.read!(target)

format_shasums = fn path ->
  {shasums, _} = path |> File.read!() |> Code.eval_string()

  shasums
  |> Enum.map(fn {k, v} -> ~s(      "#{k}": "#{v}") end)
  |> Enum.join(",\n")
end

edit_buffer_shasums = format_shasums.("/tmp/shasums_edit_buffer_nif.exs")

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

File.write!(target, updated)
IO.puts("Updated #{target} with EditBufferNIF shasums")
