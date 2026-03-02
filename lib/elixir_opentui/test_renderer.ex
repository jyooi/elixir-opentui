defmodule ElixirOpentui.TestRenderer do
  @moduledoc """
  Headless test renderer — renders element trees into a Buffer without
  touching stdout. Used by ExUnit tests to verify rendering output.

  Maps to ElixirOpentui's createTestRenderer().
  """

  use GenServer

  alias ElixirOpentui.Buffer
  alias ElixirOpentui.NativeBuffer
  alias ElixirOpentui.Element
  alias ElixirOpentui.Layout
  alias ElixirOpentui.Painter

  @type t :: GenServer.server()

  defstruct [
    :cols,
    :rows,
    :buffer,
    :prev_buffer,
    :layout_results,
    :element_tree,
    backend: :elixir
  ]

  # --- Public API ---

  @doc "Start a test renderer with given dimensions."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    cols = Keyword.get(opts, :cols, 80)
    rows = Keyword.get(opts, :rows, 24)
    backend = Keyword.get(opts, :backend, :elixir)
    GenServer.start_link(__MODULE__, {cols, rows, backend})
  end

  @doc "Render an element tree and return the buffer."
  @spec render(t(), Element.t()) :: Buffer.t()
  def render(renderer, %Element{} = element) do
    GenServer.call(renderer, {:render, element})
  end

  @doc "Get the current buffer."
  @spec get_buffer(t()) :: Buffer.t()
  def get_buffer(renderer) do
    GenServer.call(renderer, :get_buffer)
  end

  @doc "Get the current frame as list of strings (one per row)."
  @spec get_frame(t()) :: [String.t()]
  def get_frame(renderer) do
    GenServer.call(renderer, :get_frame)
  end

  @doc "Get the cell at (x, y)."
  @spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: Buffer.cell() | nil
  def get_cell(renderer, x, y) do
    GenServer.call(renderer, {:get_cell, x, y})
  end

  @doc "Get the hit_id at (x, y)."
  @spec get_hit_id(t(), non_neg_integer(), non_neg_integer()) :: term()
  def get_hit_id(renderer, x, y) do
    GenServer.call(renderer, {:get_hit_id, x, y})
  end

  @doc "Resize the renderer."
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: :ok
  def resize(renderer, cols, rows) do
    GenServer.call(renderer, {:resize, cols, rows})
  end

  @doc "Clear the buffer."
  @spec clear(t()) :: :ok
  def clear(renderer) do
    GenServer.call(renderer, :clear)
  end

  @doc "Get the layout results map."
  @spec get_layout(t()) :: Layout.layout_result()
  def get_layout(renderer) do
    GenServer.call(renderer, :get_layout)
  end

  # --- GenServer callbacks ---

  @impl true
  def init({cols, rows, backend}) do
    buffer = make_buffer(backend, cols, rows)

    {:ok,
     %__MODULE__{
       cols: cols,
       rows: rows,
       buffer: buffer,
       prev_buffer: nil,
       layout_results: %{},
       element_tree: nil,
       backend: backend
     }}
  end

  @impl true
  def handle_call({:render, element}, _from, state) do
    {tagged_tree, layout_results} = Layout.compute(element, state.cols, state.rows)

    buffer = make_buffer(state.backend, state.cols, state.rows)
    buffer = Painter.paint(tagged_tree, layout_results, buffer)

    {:reply, buffer,
     %{
       state
       | buffer: buffer,
         prev_buffer: state.buffer,
         layout_results: layout_results,
         element_tree: tagged_tree
     }}
  end

  def handle_call(:get_buffer, _from, state) do
    {:reply, state.buffer, state}
  end

  def handle_call(:get_frame, _from, state) do
    {:reply, buf_mod(state.backend).to_strings(state.buffer), state}
  end

  def handle_call({:get_cell, x, y}, _from, state) do
    {:reply, buf_mod(state.backend).get_cell(state.buffer, x, y), state}
  end

  def handle_call({:get_hit_id, x, y}, _from, state) do
    {:reply, buf_mod(state.backend).get_hit_id(state.buffer, x, y), state}
  end

  def handle_call({:resize, cols, rows}, _from, state) do
    buffer = make_buffer(state.backend, cols, rows)
    {:reply, :ok, %{state | cols: cols, rows: rows, buffer: buffer, prev_buffer: nil}}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{state | buffer: buf_mod(state.backend).clear(state.buffer)}}
  end

  def handle_call(:get_layout, _from, state) do
    {:reply, state.layout_results, state}
  end

  defp buf_mod(:native), do: NativeBuffer
  defp buf_mod(_), do: Buffer

  defp make_buffer(:native, cols, rows), do: NativeBuffer.new(cols, rows)
  defp make_buffer(_, cols, rows), do: Buffer.new(cols, rows)
end
