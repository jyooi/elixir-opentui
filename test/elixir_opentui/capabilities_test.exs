defmodule ElixirOpentui.CapabilitiesTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Capabilities

  # Helper: build an env_fn from a keyword-style map
  defp env(map) when is_map(map), do: fn key -> Map.get(map, key) end

  describe "detect_env/1 color support" do
    test "NO_COLOR disables color" do
      caps = Capabilities.detect_env(env(%{"NO_COLOR" => "1"}))
      assert caps.color_support == :no_color
    end

    test "NO_COLOR takes precedence over COLORTERM=truecolor" do
      caps = Capabilities.detect_env(env(%{"NO_COLOR" => "1", "COLORTERM" => "truecolor"}))
      assert caps.color_support == :no_color
    end

    test "TERM=dumb disables color" do
      caps = Capabilities.detect_env(env(%{"TERM" => "dumb"}))
      assert caps.color_support == :no_color
    end

    test "TERM=dumb takes precedence over COLORTERM=truecolor" do
      caps = Capabilities.detect_env(env(%{"TERM" => "dumb", "COLORTERM" => "truecolor"}))
      assert caps.color_support == :no_color
    end

    test "COLORTERM=truecolor detects truecolor" do
      caps = Capabilities.detect_env(env(%{"COLORTERM" => "truecolor"}))
      assert caps.color_support == :truecolor
    end

    test "COLORTERM=24bit detects truecolor" do
      caps = Capabilities.detect_env(env(%{"COLORTERM" => "24bit"}))
      assert caps.color_support == :truecolor
    end

    test "TERM=xterm-256color without COLORTERM detects 256 color" do
      caps = Capabilities.detect_env(env(%{"TERM" => "xterm-256color"}))
      assert caps.color_support == :color256
    end

    test "default with no vars returns optimistic truecolor" do
      caps = Capabilities.detect_env(env(%{}))
      assert caps.color_support == :truecolor
    end
  end

  describe "detect_env/1 terminal program" do
    test "KITTY_WINDOW_ID detects kitty" do
      caps = Capabilities.detect_env(env(%{"KITTY_WINDOW_ID" => "1"}))
      assert caps.terminal_program == "kitty"
    end

    test "WT_SESSION detects windows-terminal" do
      caps = Capabilities.detect_env(env(%{"WT_SESSION" => "abc-123"}))
      assert caps.terminal_program == "windows-terminal"
    end

    test "TERM_PROGRAM=ghostty detects ghostty (lowercased)" do
      caps = Capabilities.detect_env(env(%{"TERM_PROGRAM" => "Ghostty"}))
      assert caps.terminal_program == "ghostty"
    end

    test "no program vars returns nil" do
      caps = Capabilities.detect_env(env(%{}))
      assert caps.terminal_program == nil
    end
  end

  describe "detect_env/1 other fields" do
    test "TMUX set detects tmux" do
      caps = Capabilities.detect_env(env(%{"TMUX" => "/tmp/tmux-1000/default,12345,0"}))
      assert caps.tmux == true
    end

    test "no TMUX returns false" do
      caps = Capabilities.detect_env(env(%{}))
      assert caps.tmux == false
    end

    test "TERM is recorded" do
      caps = Capabilities.detect_env(env(%{"TERM" => "xterm-256color"}))
      assert caps.term == "xterm-256color"
    end

    test "default struct has expected defaults" do
      caps = Capabilities.detect_env(env(%{}))
      assert caps.kitty_keyboard == false
      assert caps.synchronized_output == :unknown
      assert caps.term == nil
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
