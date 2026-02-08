defmodule ElixirOpentui.Terminal do
  @moduledoc """
  Terminal driver — manages raw mode, reads input, writes output, handles resize.

  Uses Erlang's :io module for terminal control. Provides a GenServer that
  owns the terminal state and dispatches input events.
  """

  use GenServer

  alias ElixirOpentui.{ANSI, Input}

  @type t :: %{
          cols: non_neg_integer(),
          rows: non_neg_integer(),
          raw_mode: boolean(),
          listeners: [pid()]
        }

  defstruct cols: 80, rows: 24, raw_mode: false, listeners: []

  # --- Public API ---

  @doc "Start the terminal driver."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @doc "Get current terminal dimensions."
  @spec size(GenServer.server()) :: {non_neg_integer(), non_neg_integer()}
  def size(server) do
    GenServer.call(server, :size)
  end

  @doc "Enter raw mode and alternate screen."
  @spec enter(GenServer.server()) :: :ok
  def enter(server) do
    GenServer.call(server, :enter)
  end

  @doc "Leave raw mode and restore terminal."
  @spec leave(GenServer.server()) :: :ok
  def leave(server) do
    GenServer.call(server, :leave)
  end

  @doc "Write iodata to the terminal."
  @spec write(GenServer.server(), iodata()) :: :ok
  def write(server, data) do
    GenServer.call(server, {:write, data})
  end

  @doc "Subscribe to input events. Events are sent as {:terminal_event, event}."
  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(server) do
    GenServer.call(server, {:subscribe, self()})
  end

  @doc "Unsubscribe from input events."
  @spec unsubscribe(GenServer.server()) :: :ok
  def unsubscribe(server) do
    GenServer.call(server, {:unsubscribe, self()})
  end

  @doc "Query terminal size using ANSI escape / ioctl."
  @spec detect_size() :: {non_neg_integer(), non_neg_integer()}
  def detect_size do
    case :io.columns() do
      {:ok, cols} ->
        rows =
          case :io.rows() do
            {:ok, r} -> r
            _ -> 24
          end

        {cols, rows}

      _ ->
        {80, 24}
    end
  end

  # --- GenServer callbacks ---

  @impl true
  def init(opts) do
    {cols, rows} = Keyword.get(opts, :size, detect_size())

    state = %__MODULE__{
      cols: cols,
      rows: rows,
      raw_mode: false,
      listeners: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:size, _from, state) do
    {:reply, {state.cols, state.rows}, state}
  end

  def handle_call(:enter, _from, state) do
    setup_raw_mode()
    output = [ANSI.enter_alt_screen(), ANSI.hide_cursor(), ANSI.enable_mouse(), ANSI.enable_paste()]
    write_stdout(output)
    {:reply, :ok, %{state | raw_mode: true}}
  end

  def handle_call(:leave, _from, state) do
    output = [ANSI.disable_paste(), ANSI.disable_mouse(), ANSI.show_cursor(), ANSI.leave_alt_screen(), ANSI.reset()]
    write_stdout(output)
    restore_mode()
    {:reply, :ok, %{state | raw_mode: false}}
  end

  def handle_call({:write, data}, _from, state) do
    write_stdout(data)
    {:reply, :ok, state}
  end

  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | listeners: [pid | state.listeners]}}
  end

  def handle_call({:unsubscribe, pid}, _from, state) do
    {:reply, :ok, %{state | listeners: List.delete(state.listeners, pid)}}
  end

  @impl true
  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, chars}}, state) do
    send(from, {:io_reply, reply_as, :ok})
    events = Input.parse(IO.iodata_to_binary([chars]))

    Enum.each(events, fn event ->
      Enum.each(state.listeners, fn pid ->
        send(pid, {:terminal_event, event})
      end)
    end)

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | listeners: List.delete(state.listeners, pid)}}
  end

  def handle_info({:resize, cols, rows}, state) do
    new_state = %{state | cols: cols, rows: rows}

    Enum.each(state.listeners, fn pid ->
      send(pid, {:terminal_event, %{type: :resize, cols: cols, rows: rows}})
    end)

    {:noreply, new_state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.raw_mode do
      output = [ANSI.disable_paste(), ANSI.disable_mouse(), ANSI.show_cursor(), ANSI.leave_alt_screen(), ANSI.reset()]
      write_stdout(output)
      restore_mode()
    end

    :ok
  end

  # --- Private helpers ---

  defp setup_raw_mode do
    :io.setopts(:standard_io, binary: true, encoding: :latin1)
  rescue
    _ -> :ok
  end

  defp restore_mode do
    :io.setopts(:standard_io, binary: false, encoding: :unicode)
  rescue
    _ -> :ok
  end

  defp write_stdout(data) do
    :io.put_chars(:standard_io, data)
  rescue
    _ -> :ok
  end
end
