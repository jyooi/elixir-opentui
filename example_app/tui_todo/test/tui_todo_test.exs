defmodule TuiTodoTest do
  use ExUnit.Case
  doctest TuiTodo

  test "greets the world" do
    assert TuiTodo.hello() == :world
  end
end
