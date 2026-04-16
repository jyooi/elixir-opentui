defmodule ElixirOpentui.SafeTerm do
  @moduledoc """
  Parses a string into an Elixir term WITHOUT evaluating it.

  Designed for agent bridges and other untrusted callers that need to send
  structured actions (e.g. `{:role_changed, 2}`) to a `Runtime`. `Code.eval_string`
  executes arbitrary code; `Code.string_to_quoted` returns an AST that we
  walk to confirm every node is a pure literal.

  ## Grammar

  Accepted:

    * atoms (incl. `true`, `false`, `nil`)
    * binaries (double-quoted strings)
    * integers
    * tuples of any arity
    * lists

  Rejected:

    * floats
    * maps
    * variables and function calls
    * operators
    * anonymous functions, sigils, module aliases

  ## Atom safety

  Uses `existing_atoms_only: true` so novel atoms in the source string are
  rejected by the parser. This prevents atom-table exhaustion and naturally
  restricts callers to atoms defined in already-loaded modules.
  """

  @type result :: {:ok, term()} | {:error, String.t()}

  @doc """
  Parses `str` into a safe Elixir term.

  Returns `{:ok, term}` on success or `{:error, reason}` if the string is
  malformed, uses an undefined atom, or contains any disallowed construct.
  """
  @spec parse(String.t()) :: result
  def parse(str) when is_binary(str) do
    case Code.string_to_quoted(str, existing_atoms_only: true) do
      {:ok, ast} -> safe_term(ast)
      {:error, {_, msg, _}} -> {:error, "parse error: #{inspect(msg)}"}
    end
  end

  defp safe_term(x) when is_atom(x) or is_binary(x) or is_integer(x), do: {:ok, x}

  defp safe_term({a, b}) do
    with {:ok, av} <- safe_term(a),
         {:ok, bv} <- safe_term(b),
         do: {:ok, {av, bv}}
  end

  defp safe_term({:{}, _meta, args}) when is_list(args) do
    with {:ok, vals} <- safe_list(args), do: {:ok, List.to_tuple(vals)}
  end

  defp safe_term(list) when is_list(list), do: safe_list(list)

  defp safe_term({name, _meta, args}) when is_atom(name) and (is_list(args) or is_nil(args)) do
    {:error, "disallowed construct `#{name}` — only atoms, binaries, integers, tuples, lists accepted"}
  end

  defp safe_term(other), do: {:error, "disallowed term: #{inspect(other)}"}

  defp safe_list(list) do
    Enum.reduce_while(list, {:ok, []}, fn elem, {:ok, acc} ->
      case safe_term(elem) do
        {:ok, v} -> {:cont, {:ok, [v | acc]}}
        err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      err -> err
    end
  end
end
