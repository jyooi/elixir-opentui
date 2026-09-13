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

  # --- Shared widget helpers ---

  @doc "True when `key` was added, removed, or changed between two prop maps."
  @spec prop_changed?(map(), map(), term()) :: boolean()
  def prop_changed?(prev_props, new_props, key) do
    prev_has? = Map.has_key?(prev_props, key)
    new_has? = Map.has_key?(new_props, key)

    prev_has? != new_has? or (prev_has? and Map.get(prev_props, key) != Map.get(new_props, key))
  end

  @doc "Copy prop `key` into state under `state_key` when it changed."
  @spec sync_prop(map(), map(), map(), term(), term(), term()) :: map()
  def sync_prop(state, prev_props, new_props, key, default, state_key \\ nil) do
    if prop_changed?(prev_props, new_props, key) do
      Map.put(state, state_key || key, Map.get(new_props, key, default))
    else
      state
    end
  end

  @doc "Queue `{tag, args...}` in `_pending` when `tag` is set."
  @spec emit(map(), term(), list()) :: map()
  def emit(state, nil, _args), do: state

  def emit(state, tag, args) do
    %{state | _pending: [List.to_tuple([tag | args]) | state._pending]}
  end

  @doc "Normalize a list of option strings or maps to `%{name, description, value}` maps."
  @spec normalize_options([String.t() | map()]) :: [map()]
  def normalize_options(options), do: Enum.map(options, &normalize_option/1)

  defp normalize_option(%{name: _} = opt) do
    Map.merge(%{name: "", description: nil, value: nil}, opt)
  end

  defp normalize_option(string) when is_binary(string) do
    %{name: string, description: nil, value: nil}
  end

  @doc """
  Reconcile `:options` and `:selected` props into state.

  Returns `{state, changed?}` where `changed?` is true when either prop changed.
  """
  @spec sync_options(map(), map(), map()) :: {map(), boolean()}
  def sync_options(state, prev_props, new_props) do
    {state, options_changed?} =
      if prop_changed?(prev_props, new_props, :options) do
        options = normalize_options(Map.get(new_props, :options, []))
        selected = min(state.selected, max(0, length(options) - 1))
        {%{state | options: options, selected: selected}, true}
      else
        {state, false}
      end

    if prop_changed?(prev_props, new_props, :selected) do
      selected = clamp(Map.get(new_props, :selected, 0), 0, max(0, length(state.options) - 1))
      {%{state | selected: selected}, true}
    else
      {state, options_changed?}
    end
  end

  @doc "Clamp `val` into `lo..hi`."
  @spec clamp(number(), number(), number()) :: number()
  def clamp(val, lo, hi), do: max(lo, min(hi, val))
end
