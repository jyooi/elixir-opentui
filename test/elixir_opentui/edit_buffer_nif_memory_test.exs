defmodule ElixirOpentui.EditBufferNIFMemoryTest do
  use ExUnit.Case, async: false

  @moduletag :nif

  alias ElixirOpentui.EditBufferNIF

  describe "gc safety" do
    test "creating many resources doesn't leak memory" do
      initial = :erlang.memory(:total)

      for _ <- 1..100 do
        buf = EditBufferNIF.create()
        EditBufferNIF.set_text(buf, String.duplicate("x", 1000))
        _view = EditBufferNIF.create_editor_view(buf, 40, 10)
      end

      :erlang.garbage_collect()
      Process.sleep(50)
      :erlang.garbage_collect()

      final = :erlang.memory(:total)
      # Memory growth should be bounded (allow 10MB margin for VM overhead)
      assert final - initial < 10_000_000
    end
  end
end
