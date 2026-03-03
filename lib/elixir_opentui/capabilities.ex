defmodule ElixirOpentui.Capabilities do
  @moduledoc """
  Terminal capability detection via environment variables and escape sequence queries.

  Provides a Capabilities struct that records what the terminal supports.
  Detection happens in two phases:
  1. Environment variables (instant, zero I/O) — called once at startup
  2. Query responses (async, within 100ms window) — applied as responses arrive

  Query-based capabilities start as `:unknown` and are upgraded to `true`/`false`
  as responses arrive. Accessor functions resolve `:unknown` → `false` at read time,
  so there is no separate finalization step. Late responses can still upgrade a
  capability at any time.

  This struct is observational — it records capabilities but does not gate output.
  Conditional output gating (e.g., skipping ANSI for TERM=dumb) is a separate concern.
  """

  @type color_support :: :no_color | :basic | :color256 | :truecolor

  @type t :: %__MODULE__{
          color_support: color_support(),
          terminal_program: String.t() | nil,
          tmux: boolean(),
          term: String.t() | nil,
          kitty_keyboard: boolean(),
          synchronized_output: boolean() | :unknown
        }

  defstruct color_support: :truecolor,
            terminal_program: nil,
            tmux: false,
            term: nil,
            kitty_keyboard: false,
            synchronized_output: :unknown

  # --- Environment detection ---

  @doc """
  Detect capabilities from environment variables. Zero I/O cost.

  Accepts an optional `env_fn` for testability — defaults to `System.get_env/1`.
  This allows tests to remain `async: true` without mutating global env state.
  """
  @spec detect_env((String.t() -> String.t() | nil)) :: t()
  def detect_env(env_fn \\ &System.get_env/1) do
    %__MODULE__{
      color_support: detect_color_support(env_fn),
      terminal_program: detect_terminal_program(env_fn),
      tmux: env_fn.("TMUX") != nil,
      term: env_fn.("TERM")
    }
  end

  # --- Capability event reducer ---

  @doc """
  Apply a parsed capability response event to the capabilities struct.

  Capability events have `%{type: :capability, capability: atom(), ...}` with
  additional keys varying by capability type:
  - `:kitty_keyboard` — `value: flags` (integer)
  - `:decrqm` — `mode: integer, status: integer`

  Can be called at any time, including after the detection window closes.
  Late responses simply update the struct.
  """
  @spec apply_capability(t(), map()) :: t()
  def apply_capability(caps, %{capability: :kitty_keyboard}) do
    %{caps | kitty_keyboard: true}
  end

  def apply_capability(caps, %{capability: :decrqm, mode: 2026, status: status}) do
    # DECRQM status values (per ECMA-48 / DEC STD 070):
    #   0 = not recognized (terminal doesn't know this mode)
    #   1 = set (mode is currently enabled)
    #   2 = reset (mode is supported but currently disabled)
    #   3 = permanently set (cannot be toggled off)
    #   4 = permanently reset (cannot be toggled on)
    # Supported = status in [1, 2, 3]; unsupported = 0, 4
    %{caps | synchronized_output: status in [1, 2, 3]}
  end

  def apply_capability(caps, _event), do: caps

  # --- Accessor functions (resolve :unknown at read time) ---

  @doc "Does the terminal support synchronized output (mode 2026)? Resolves :unknown → false."
  @spec synchronized_output?(t()) :: boolean()
  def synchronized_output?(%__MODULE__{synchronized_output: :unknown}), do: false
  def synchronized_output?(%__MODULE__{synchronized_output: val}), do: val

  # --- Private detection helpers ---

  defp detect_color_support(env_fn) do
    cond do
      env_fn.("NO_COLOR") != nil -> :no_color
      env_fn.("TERM") == "dumb" -> :no_color
      env_fn.("COLORTERM") in ["truecolor", "24bit"] -> :truecolor
      term_supports_256?(env_fn) -> :color256
      true -> :truecolor
    end
  end

  defp detect_terminal_program(env_fn) do
    cond do
      (id = env_fn.("KITTY_WINDOW_ID")) && id != "" -> "kitty"
      (id = env_fn.("WT_SESSION")) && id != "" -> "windows-terminal"
      (prog = env_fn.("TERM_PROGRAM")) && prog != "" -> String.downcase(prog)
      true -> nil
    end
  end

  defp term_supports_256?(env_fn) do
    case env_fn.("TERM") do
      nil -> false
      term -> String.contains?(term, "256color")
    end
  end
end
