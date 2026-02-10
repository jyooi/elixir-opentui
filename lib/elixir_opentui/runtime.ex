defmodule ElixirOpentui.Runtime do
  @moduledoc """
  The MVU runtime GenServer. Owns all application and component state.

  Runs the main loop:
  1. Receive events (from Terminal or test harness)
  2. Route through EventManager
  3. Update component states
  4. Re-render the element tree
  5. Diff and output to terminal

  Can run in two modes:
  - `:live` — connected to a real Terminal driver
  - `:headless` — for testing (no terminal, captures frames)
  """

  use GenServer

  alias ElixirOpentui.{Renderer, EventManager, Element, Buffer, NativeBuffer, Layout, Painter, Focus}

  @type component_state :: %{
          module: module(),
          state: term(),
          props: map()
        }

  @type model :: %{
          app_module: module() | nil,
          app_state: term(),
          component_states: %{optional(term()) => component_state()},
          renderer: Renderer.t(),
          event_manager: EventManager.state(),
          tree: Element.t() | nil,
          mode: :live | :headless,
          terminal: GenServer.server() | nil,
          frame_count: non_neg_integer(),
          on_event: (term() -> :ok) | nil
        }

  defstruct [
    :app_module,
    :app_state,
    :renderer,
    :event_manager,
    :tree,
    :terminal,
    :on_event,
    component_states: %{},
    mode: :headless,
    backend: :elixir,
    frame_count: 0
  ]

  # --- Public API ---

  @doc "Start the runtime."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @doc "Set the root app module and initialize it."
  @spec mount(GenServer.server(), module(), map()) :: :ok
  def mount(server, app_module, props \\ %{}) do
    GenServer.call(server, {:mount, app_module, props})
  end

  @doc "Send an event to the runtime for processing."
  @spec send_event(GenServer.server(), term()) :: :ok
  def send_event(server, event) do
    GenServer.cast(server, {:event, event})
  end

  @doc "Send a message to a specific component."
  @spec send_msg(GenServer.server(), term(), term()) :: :ok
  def send_msg(server, component_id, msg) do
    GenServer.cast(server, {:component_msg, component_id, msg})
  end

  @doc "Force a re-render."
  @spec render(GenServer.server()) :: :ok
  def render(server) do
    GenServer.call(server, :render)
  end

  @doc "Get the current rendered frame as list of strings (headless mode)."
  @spec get_frame(GenServer.server()) :: [String.t()]
  def get_frame(server) do
    GenServer.call(server, :get_frame)
  end

  @doc "Get the current focus state."
  @spec get_focus(GenServer.server()) :: Focus.t()
  def get_focus(server) do
    GenServer.call(server, :get_focus)
  end

  @doc "Get a component's current state."
  @spec get_component_state(GenServer.server(), term()) :: term() | nil
  def get_component_state(server, id) do
    GenServer.call(server, {:get_component_state, id})
  end

  @doc "Get the current element tree."
  @spec get_tree(GenServer.server()) :: Element.t() | nil
  def get_tree(server) do
    GenServer.call(server, :get_tree)
  end

  @doc "Resize the runtime."
  @spec resize(GenServer.server(), non_neg_integer(), non_neg_integer()) :: :ok
  def resize(server, cols, rows) do
    GenServer.call(server, {:resize, cols, rows})
  end

  # --- GenServer callbacks ---

  @impl true
  def init(opts) do
    cols = Keyword.get(opts, :cols, 80)
    rows = Keyword.get(opts, :rows, 24)
    mode = Keyword.get(opts, :mode, :headless)
    terminal = Keyword.get(opts, :terminal)
    on_event = Keyword.get(opts, :on_event)
    backend = Keyword.get(opts, :backend, :elixir)

    state = %__MODULE__{
      renderer: Renderer.new(cols, rows, backend: backend),
      mode: mode,
      terminal: terminal,
      on_event: on_event,
      backend: backend
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:mount, app_module, props}, _from, state) do
    app_state = app_module.init(props)
    tree = app_module.render(app_state)

    {tree, comp_states} = resolve_components(tree, state.component_states)

    {tagged, layout_results} = Layout.compute(tree, state.renderer.cols, state.renderer.rows)
    buffer = new_buffer(state)
    buffer = Painter.paint(tagged, layout_results, buffer)
    buffer = finalize_buffer(state, buffer)

    em = EventManager.new(tree, buffer)

    renderer = update_renderer_front(state.renderer, buffer)

    new_state = %{
      state
      | app_module: app_module,
        app_state: app_state,
        tree: tree,
        component_states: comp_states,
        event_manager: em,
        renderer: renderer
    }

    {:reply, :ok, new_state}
  end

  def handle_call(:render, _from, state) do
    new_state = do_render(state)
    {:reply, :ok, new_state}
  end

  def handle_call(:get_frame, _from, state) do
    frame = buffer_mod(state).to_strings(state.renderer.front)
    {:reply, frame, state}
  end

  def handle_call(:get_focus, _from, state) do
    focus = if state.event_manager, do: state.event_manager.focus, else: %Focus{}
    {:reply, focus, state}
  end

  def handle_call({:get_component_state, id}, _from, state) do
    result =
      case Map.get(state.component_states, id) do
        nil -> nil
        comp -> comp.state
      end

    {:reply, result, state}
  end

  def handle_call(:get_tree, _from, state) do
    {:reply, state.tree, state}
  end

  def handle_call({:resize, cols, rows}, _from, state) do
    new_renderer = Renderer.resize(state.renderer, cols, rows)
    new_state = %{state | renderer: new_renderer}
    new_state = do_render(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:event, event}, state) do
    new_state = process_event(state, event)
    {:noreply, new_state}
  end

  def handle_cast({:component_msg, component_id, msg}, state) do
    new_state = update_component(state, component_id, msg, nil)
    new_state = do_render(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:terminal_event, event}, state) do
    new_state = process_event(state, event)
    {:noreply, new_state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private helpers ---

  defp process_event(state, event) do
    if state.on_event, do: state.on_event.(event)

    if state.event_manager do
      {new_em, actions} = EventManager.process(state.event_manager, event)
      state = %{state | event_manager: new_em}

      state =
        Enum.reduce(actions, state, fn
          {:update, msg}, acc -> update_app(acc, msg)
          {:resize, cols, rows}, acc -> handle_resize(acc, cols, rows)
          {:focus_changed, _id}, acc -> acc
          {:mouse, _event}, acc -> acc
          _, acc -> acc
        end)

      do_render(state)
    else
      state
    end
  end

  defp update_app(%{app_module: nil} = state, _msg), do: state

  defp update_app(state, msg) do
    new_app_state = state.app_module.update(msg, nil, state.app_state)
    %{state | app_state: new_app_state}
  end

  defp update_component(state, component_id, msg, event) do
    case Map.get(state.component_states, component_id) do
      nil ->
        state

      comp ->
        new_comp_state = comp.module.update(msg, event, comp.state)

        pending = Map.get(new_comp_state, :_pending, [])
        clean_state = Map.put(new_comp_state, :_pending, [])
        new_comp = %{comp | state: clean_state}
        state = %{state | component_states: Map.put(state.component_states, component_id, new_comp)}

        Enum.reduce(Enum.reverse(pending), state, fn msg, s ->
          update_app(s, msg)
        end)
    end
  end

  defp handle_resize(state, cols, rows) do
    new_renderer = Renderer.resize(state.renderer, cols, rows)
    %{state | renderer: new_renderer}
  end

  defp do_render(%{app_module: nil} = state), do: state

  defp do_render(state) do
    tree = state.app_module.render(state.app_state)
    {tree, comp_states} = resolve_components(tree, state.component_states)

    {tagged, layout_results} = Layout.compute(tree, state.renderer.cols, state.renderer.rows)
    buffer = new_buffer(state)
    buffer = Painter.paint(tagged, layout_results, buffer)
    buffer = finalize_buffer(state, buffer)

    em =
      if state.event_manager do
        EventManager.update(state.event_manager, tree, buffer)
      else
        EventManager.new(tree, buffer)
      end

    renderer = update_renderer_front(state.renderer, buffer)

    %{
      state
      | tree: tree,
        component_states: comp_states,
        event_manager: em,
        renderer: renderer
    }
  end

  defp buffer_mod(%{backend: :native}), do: NativeBuffer
  defp buffer_mod(_state), do: Buffer

  defp new_buffer(%{backend: :native, renderer: %{cols: cols, rows: rows}}) do
    nbuf = NativeBuffer.new(cols, rows)
    NativeBuffer.clear(nbuf)
  end

  defp new_buffer(%{renderer: %{cols: cols, rows: rows}}) do
    Buffer.new(cols, rows)
  end

  defp finalize_buffer(%{backend: :native}, %NativeBuffer{} = nbuf) do
    {nbuf, _ansi} = NativeBuffer.render_frame_capture(nbuf)
    nbuf
  end

  defp finalize_buffer(_state, buffer), do: buffer

  defp update_renderer_front(%{backend: :native} = renderer, nbuf) do
    %{renderer | native_buf: nbuf, front: nbuf, frame_count: renderer.frame_count + 1}
  end

  defp update_renderer_front(renderer, buffer) do
    %{renderer | front: buffer, frame_count: renderer.frame_count + 1}
  end

  # Walk the tree and initialize any component elements
  defp resolve_components(%Element{component: nil} = el, comp_states) do
    {children, comp_states} =
      Enum.map_reduce(el.children, comp_states, &resolve_components/2)

    {%{el | children: children}, comp_states}
  end

  defp resolve_components(%Element{component: module, id: id, attrs: attrs} = _el, comp_states) do
    props = Map.new(attrs)

    comp =
      case Map.get(comp_states, id) do
        nil ->
          %{module: module, state: module.init(props), props: props}

        existing ->
          existing
      end

    tree = module.render(comp.state)
    tree = %{tree | id: tree.id || id}

    {children, comp_states} =
      Enum.map_reduce(tree.children, comp_states, &resolve_components/2)

    tree = %{tree | children: children}
    comp_states = Map.put(comp_states, id, comp)

    {tree, comp_states}
  end
end
