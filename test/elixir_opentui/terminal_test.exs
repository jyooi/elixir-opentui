defmodule ElixirOpentui.TerminalTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Terminal

  describe "suspend/resume raw_mode state" do
    test "suspend sets raw_mode to false" do
      {:ok, term} = Terminal.start_link(size: {80, 24})
      Terminal.enter(term)

      state_before = :sys.get_state(term)
      assert state_before.raw_mode == true

      Terminal.suspend(term)

      state_after = :sys.get_state(term)
      assert state_after.raw_mode == false
      assert state_after.suspended == true
    end

    test "resume sets raw_mode to true" do
      {:ok, term} = Terminal.start_link(size: {80, 24})
      Terminal.enter(term)
      Terminal.suspend(term)

      state_suspended = :sys.get_state(term)
      assert state_suspended.raw_mode == false
      assert state_suspended.suspended == true

      Terminal.resume(term)

      state_resumed = :sys.get_state(term)
      assert state_resumed.raw_mode == true
      assert state_resumed.suspended == false
    end
  end
end
