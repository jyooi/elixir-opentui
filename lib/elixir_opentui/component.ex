defmodule ElixirOpentui.Component do
  @moduledoc """
  Behaviour for ElixirOpentui components.

  Components are pure functions with state — NOT GenServers.
  They run inside the Runtime's single GenServer process.

  ## Callbacks

  - `init/1` — Initialize component state from props
  - `update/3` — Handle events, return new state
  - `render/1` — Return an Element tree from current state

  ## Example

      defmodule Counter do
        use ElixirOpentui.Component

        def init(_props), do: %{count: 0}

        def update(:increment, _event, state), do: %{state | count: state.count + 1}
        def update(:decrement, _event, state), do: %{state | count: state.count - 1}
        def update(_, _, state), do: state

        def render(state) do
          import ElixirOpentui.View

          box direction: :row, gap: 2 do
            button(id: :dec, content: "-")
            text(content: "\#{state.count}")
            button(id: :inc, content: "+")
          end
        end
      end
  """

  @doc "Initialize component state from props."
  @callback init(props :: map()) :: term()

  @doc "Handle a message/event. Returns new state."
  @callback update(msg :: term(), event :: term(), state :: term()) :: term()

  @doc "Render the component to an Element tree."
  @callback render(state :: term()) :: ElixirOpentui.Element.t()

  @optional_callbacks []

  defmacro __using__(_opts) do
    quote do
      @behaviour ElixirOpentui.Component
    end
  end
end
