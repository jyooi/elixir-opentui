defmodule ElixirOpentui.BufferBehaviour do
  @moduledoc """
  Behaviour defining the buffer interface for both pure-Elixir (Buffer)
  and NIF-backed (NativeBuffer) implementations.
  """

  alias ElixirOpentui.Color

  @callback new(cols :: non_neg_integer(), rows :: non_neg_integer(), opts :: keyword()) :: term()
  @callback draw_char(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              char :: String.t(),
              fg :: Color.t(),
              bg :: Color.t()
            ) :: term()
  @callback draw_char(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              char :: String.t(),
              fg :: Color.t(),
              bg :: Color.t(),
              attrs :: keyword()
            ) :: term()
  @callback draw_char_blend(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              char :: String.t(),
              fg :: Color.t(),
              bg :: Color.t()
            ) :: term()
  @callback draw_char_blend(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              char :: String.t(),
              fg :: Color.t(),
              bg :: Color.t(),
              attrs :: keyword()
            ) :: term()
  @callback draw_text(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              text :: String.t(),
              fg :: Color.t(),
              bg :: Color.t()
            ) :: term()
  @callback draw_text(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              text :: String.t(),
              fg :: Color.t(),
              bg :: Color.t(),
              attrs :: keyword()
            ) :: term()
  @callback fill_rect(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              w :: integer(),
              h :: integer(),
              char :: String.t(),
              fg :: Color.t(),
              bg :: Color.t()
            ) :: term()
  @callback fill_rect(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              w :: integer(),
              h :: integer(),
              char :: String.t(),
              fg :: Color.t(),
              bg :: Color.t(),
              attrs :: keyword()
            ) :: term()
  @callback set_hit_region(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              w :: integer(),
              h :: integer(),
              hit_id :: term()
            ) :: term()
  @callback get_cell(buf :: term(), x :: integer(), y :: integer()) :: map() | nil
  @callback get_hit_id(buf :: term(), x :: integer(), y :: integer()) :: term()
  @callback push_scissor(
              buf :: term(),
              x :: integer(),
              y :: integer(),
              w :: integer(),
              h :: integer()
            ) :: term()
  @callback pop_scissor(buf :: term()) :: term()
  @callback clear(buf :: term()) :: term()
  @callback to_strings(buf :: term()) :: [String.t()]
end
