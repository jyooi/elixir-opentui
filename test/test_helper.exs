nif_loaded? =
  try do
    is_reference(ElixirOpentui.EditBufferNIF.create())
  rescue
    _ -> false
  end

unless nif_loaded?, do: ExUnit.configure(exclude: [:nif])

ExUnit.start()
