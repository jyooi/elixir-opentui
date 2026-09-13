defmodule ElixirOpentui.CapabilitiesTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Capabilities

  describe "detect_env/0" do
    test "default struct has expected defaults" do
      caps = Capabilities.detect_env()
      assert caps.kitty_keyboard == false
      assert caps.synchronized_output == :unknown
    end
  end

  describe "apply_capability/2 kitty keyboard" do
    test "kitty_keyboard event sets kitty_keyboard to true" do
      caps = %Capabilities{}
      event = %{type: :capability, capability: :kitty_keyboard, value: 5}
      assert Capabilities.apply_capability(caps, event).kitty_keyboard == true
    end
  end

  describe "apply_capability/2 DECRQM mode 2026" do
    test "status 1 (set) marks synchronized_output as true" do
      caps = %Capabilities{}
      event = %{type: :capability, capability: :decrqm, mode: 2026, status: 1}
      assert Capabilities.apply_capability(caps, event).synchronized_output == true
    end

    test "status 2 (reset/supported) marks synchronized_output as true" do
      caps = %Capabilities{}
      event = %{type: :capability, capability: :decrqm, mode: 2026, status: 2}
      assert Capabilities.apply_capability(caps, event).synchronized_output == true
    end

    test "status 3 (permanently set) marks synchronized_output as true" do
      caps = %Capabilities{}
      event = %{type: :capability, capability: :decrqm, mode: 2026, status: 3}
      assert Capabilities.apply_capability(caps, event).synchronized_output == true
    end

    test "status 0 (not recognized) marks synchronized_output as false" do
      caps = %Capabilities{}
      event = %{type: :capability, capability: :decrqm, mode: 2026, status: 0}
      assert Capabilities.apply_capability(caps, event).synchronized_output == false
    end

    test "status 4 (permanently reset) marks synchronized_output as false" do
      caps = %Capabilities{}
      event = %{type: :capability, capability: :decrqm, mode: 2026, status: 4}
      assert Capabilities.apply_capability(caps, event).synchronized_output == false
    end

    test "late DECRQM can still upgrade an already-resolved struct" do
      caps = %Capabilities{synchronized_output: false}
      event = %{type: :capability, capability: :decrqm, mode: 2026, status: 1}
      assert Capabilities.apply_capability(caps, event).synchronized_output == true
    end
  end

  describe "apply_capability/2 unknown events" do
    test "unknown capability event leaves struct unchanged" do
      caps = %Capabilities{kitty_keyboard: false, synchronized_output: :unknown}
      event = %{type: :capability, capability: :unknown_thing, value: 42}
      assert Capabilities.apply_capability(caps, event) == caps
    end
  end

  describe "synchronized_output?/1" do
    test "unknown resolves to false" do
      assert Capabilities.synchronized_output?(%Capabilities{synchronized_output: :unknown}) ==
               false
    end

    test "true resolves to true" do
      assert Capabilities.synchronized_output?(%Capabilities{synchronized_output: true}) == true
    end

    test "false resolves to false" do
      assert Capabilities.synchronized_output?(%Capabilities{synchronized_output: false}) == false
    end
  end
end
