unless ElixirOpentui.NIF.available?() do
  ExUnit.configure(exclude: [:nif])
end

ExUnit.start()
