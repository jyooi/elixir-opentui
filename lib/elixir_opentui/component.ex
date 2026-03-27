defmodule ElixirOpentui.Component do
  @moduledoc """
  Behaviour for ElixirOpentui components.

  Components are pure functions with state — NOT GenServers.
  They run inside the Runtime's single GenServer process.

  ## Callbacks

  - `init/1` — Initialize component state from props
  - `update_props/3` — Reconcile mounted state when parent props change
  - `update/3` — Handle events, return new state
  - `render/1` — Return an Element tree from current state

  ## Live Mode (Tick Loop)

  Set `_live: true` in your component state to opt into the runtime tick
  loop (~30 FPS). When live mode is active, tick events are delivered as:

      def update(:tick, %{dt: dt}, state) do
        # dt is the elapsed milliseconds since the last tick
        %{state | elapsed: state.elapsed + dt}
      end

  The runtime automatically starts ticking when any component (or the
  app module) has `_live: true` in its state, and stops when none do.

  For programmatic control (e.g. starting/stopping animations from
  external events), use `Runtime.request_live/1` and `Runtime.drop_live/2`.

  > **Note:** The key must be exactly `:_live`. Common typos like `:live`
  > or `:is_live` will trigger a warning in the logs.

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

  @doc "Reconcile mounted state when parent props change."
  @callback update_props(prev_props :: map(), new_props :: map(), state :: term()) :: term()

  @doc "Handle a message/event. Returns new state."
  @callback update(msg :: term(), event :: term(), state :: term()) :: term()

  @doc "Render the component to an Element tree."
  @callback render(state :: term()) :: ElixirOpentui.Element.t()

  @optional_callbacks [update_props: 3]

  defmacro __using__(_opts) do
    quote do
      @behaviour ElixirOpentui.Component
    end
  end
end
