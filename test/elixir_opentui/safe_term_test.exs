defmodule ElixirOpentui.SafeTermTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.SafeTerm

  # Atoms referenced as literals below are created by the compiler when this
  # file is compiled, so existing_atoms_only: true will accept them at runtime.

  describe "accepts literals" do
    test "atoms, including special" do
      assert SafeTerm.parse(":login_clicked") == {:ok, :login_clicked}
      assert SafeTerm.parse("true") == {:ok, true}
      assert SafeTerm.parse("false") == {:ok, false}
      assert SafeTerm.parse("nil") == {:ok, nil}
    end

    test "binaries" do
      assert SafeTerm.parse("\"hello\"") == {:ok, "hello"}
      assert SafeTerm.parse("\"\"") == {:ok, ""}
    end

    test "integers" do
      assert SafeTerm.parse("0") == {:ok, 0}
      assert SafeTerm.parse("42") == {:ok, 42}
    end

    test "2-tuples" do
      assert SafeTerm.parse("{:role_changed, 2}") == {:ok, {:role_changed, 2}}
      assert SafeTerm.parse("{:email_changed, \"a@b\"}") == {:ok, {:email_changed, "a@b"}}
    end

    test "n-tuples" do
      assert SafeTerm.parse("{1, 2, 3}") == {:ok, {1, 2, 3}}
      assert SafeTerm.parse("{:a, :two, 3, \"four\"}") == {:ok, {:a, :two, 3, "four"}}
    end

    test "lists" do
      assert SafeTerm.parse("[]") == {:ok, []}
      assert SafeTerm.parse("[1, 2, 3]") == {:ok, [1, 2, 3]}
      assert SafeTerm.parse("[:a, 1, \"s\"]") == {:ok, [:a, 1, "s"]}
    end

    test "nested structures" do
      assert SafeTerm.parse("{:nested, {:a, 1}}") == {:ok, {:nested, {:a, 1}}}
      assert SafeTerm.parse("{:tag, [1, :two, \"three\"]}") ==
               {:ok, {:tag, [1, :two, "three"]}}
    end
  end

  describe "rejects code execution vectors" do
    test "function calls" do
      assert {:error, _} = SafeTerm.parse("send(self(), :boom)")
      assert {:error, _} = SafeTerm.parse(":os.cmd(~c\"rm -rf /\")")
      assert {:error, _} = SafeTerm.parse("spawn(fn -> :ok end)")
    end

    test "call shape rejected by AST walker even when all atoms exist" do
      # Reference these atoms at compile time so existing_atoms_only accepts
      # them, forcing rejection to happen in safe_term/1 instead of the parser.
      _ = {:erlang, :length}
      assert {:error, msg} = SafeTerm.parse(":erlang.length([])")
      assert msg =~ "disallowed"
    end

    test "operators" do
      assert {:error, msg} = SafeTerm.parse("1 + 2")
      assert msg =~ "`+`"

      assert {:error, _} = SafeTerm.parse("-5")
    end

    test "variables" do
      assert {:error, msg} = SafeTerm.parse("foo")
      assert msg =~ "`foo`"
    end

    test "anonymous functions" do
      assert {:error, _} = SafeTerm.parse("fn -> 1 end")
    end

    test "maps" do
      assert {:error, msg} = SafeTerm.parse("%{a: 1}")
      assert msg =~ "`%{}`"
    end

    test "sigils" do
      assert {:error, _} = SafeTerm.parse("~c\"hi\"")
    end
  end

  describe "rejects disallowed primitives" do
    test "floats" do
      assert SafeTerm.parse("3.14") == {:error, "disallowed term: 3.14"}
    end
  end

  describe "atom-table exhaustion guard" do
    test "novel atoms blocked at parse time" do
      # A fresh string every run so the atom genuinely doesn't exist.
      unique = ":never_before_seen_atom_#{System.unique_integer([:positive])}"
      assert {:error, msg} = SafeTerm.parse(unique)
      assert msg =~ "parse error"
    end

    test "novel atoms inside tuples also blocked" do
      unique = "{:#{:erlang.unique_integer([:positive])}_novel_atom, 1}"
      assert {:error, _} = SafeTerm.parse(unique)
    end
  end

  describe "malformed input" do
    test "unterminated tuple" do
      assert {:error, msg} = SafeTerm.parse("{{{")
      assert msg =~ "parse error"
    end

    test "empty string" do
      # Elixir parses "" as an empty __block__, which the AST walker rejects.
      assert {:error, msg} = SafeTerm.parse("")
      assert msg =~ "__block__"
    end
  end
end
