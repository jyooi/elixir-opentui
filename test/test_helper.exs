unless ElixirOpentui.EditBufferNIF.available?() do
  ExUnit.configure(exclude: [:nif])
end

ExUnit.start()
