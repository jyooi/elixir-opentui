nif_loaded? =
  try do
    is_reference(ElixirOpentui.EditBufferNIF.create())
  rescue
    _ -> false
  end

source_build? = System.get_env("ZIGLER_PRECOMPILE_FORCE_RECOMPILE") == "true"

exclude =
  [:known_finding] ++
    if(nif_loaded?, do: [], else: [:nif]) ++ if(source_build?, do: [], else: [:nif_source])

ExUnit.configure(exclude: exclude)

ExUnit.start()
