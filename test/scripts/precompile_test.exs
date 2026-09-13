argv = System.argv()
System.argv([])
ExUnit.CaptureIO.capture_io(fn -> Code.require_file("scripts/precompile.exs") end)
System.argv(argv)

defmodule ElixirOpentui.Scripts.PrecompileTest do
  use ExUnit.Case, async: true

  test "derives the real NIF module name from each NIF source file" do
    assert Precompile.nif_module("lib/elixir_opentui/edit_buffer_nif.ex") ==
             ElixirOpentui.EditBufferNIF
  end
end
