defmodule ElixirOpentui.Capabilities do
  @moduledoc """
  Terminal capability detection via escape sequence queries.

  Provides a Capabilities struct that records what the terminal supports.
  Capabilities come from terminal query responses (async, within a 100ms window).

  Query-based capabilities start as `:unknown` and are upgraded to `true`/`false`
  as responses arrive. Accessor functions resolve `:unknown` → `false` at read time,
  so there is no separate finalization step. Late responses can still upgrade a
  capability at any time.

  This struct is observational — it records capabilities but does not gate output.
  Conditional output gating (e.g., skipping ANSI for TERM=dumb) is a separate concern.
  """

  @type t :: %__MODULE__{
          kitty_keyboard: boolean(),
          synchronized_output: boolean() | :unknown
        }

  defstruct kitty_keyboard: false,
            synchronized_output: :unknown

  @doc "Initial capabilities before any terminal query response arrives."
  @spec detect_env() :: t()
  def detect_env, do: %__MODULE__{}

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
end
