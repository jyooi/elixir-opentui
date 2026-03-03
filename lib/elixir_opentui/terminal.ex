defmodule ElixirOpentui.Terminal do
  @moduledoc """
  Terminal driver — manages raw mode, reads input, writes output, handles resize.

  Uses Erlang's :io module for terminal control. Provides a GenServer that
  owns the terminal state and dispatches input events.

  Supports Kitty keyboard protocol auto-detection with modifyOtherKeys fallback.
  """

  use GenServer

  alias ElixirOpentui.{ANSI, Capabilities, Input}

  @type t :: %{
          cols: non_neg_integer(),
          rows: non_neg_integer(),
          raw_mode: boolean(),
          suspended: boolean(),
          listeners: [pid()],
          kitty_keyboard: boolean(),
          kitty_flags: non_neg_integer(),
          modify_other_keys: boolean(),
          detecting: boolean(),
          capabilities: Capabilities.t()
        }

  defstruct cols: 80,
            rows: 24,
            raw_mode: false,
            suspended: false,
            listeners: [],
            kitty_keyboard: false,
            kitty_flags: 0,
            modify_other_keys: false,
            detecting: false,
            capabilities: %ElixirOpentui.Capabilities{}

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

  @doc "Suspend the terminal — leaves raw/alt screen mode, saves state."
  @spec suspend(GenServer.server()) :: :ok
  def suspend(server) do
    GenServer.call(server, :suspend)
  end

  @doc "Resume the terminal — re-enters raw/alt screen mode."
  @spec resume(GenServer.server()) :: :ok
  def resume(server) do
    GenServer.call(server, :resume)
  end

  @doc "Get current terminal capabilities."
  @spec capabilities(GenServer.server()) :: Capabilities.t()
  def capabilities(server) do
    GenServer.call(server, :capabilities)
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
    # Trap exits so terminate/2 is called during shutdown, giving us
    # a chance to write cleanup escape sequences before the process dies.
    Process.flag(:trap_exit, true)

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

  def handle_call(:capabilities, _from, state) do
    {:reply, state.capabilities, state}
  end

  def handle_call(:enter, _from, state) do
    setup_raw_mode()
    :os.set_signal(:sigtstp, :ignore)
    caps = Capabilities.detect_env()

    output = [
      ANSI.enter_alt_screen(),
      ANSI.hide_cursor(),
      ANSI.enable_mouse(),
      ANSI.enable_paste(),
      ANSI.query_kitty_keyboard(),
      ANSI.query_decrqm(2026)
    ]

    write_stdout(output)
    Process.send_after(self(), :keyboard_detect_timeout, 100)
    {:reply, :ok, %{state | raw_mode: true, detecting: true, capabilities: caps}}
  end

  def handle_call(:leave, _from, state) do
    output = [
      keyboard_disable_sequences(state),
      ANSI.disable_paste(),
      ANSI.disable_mouse(),
      ANSI.show_cursor(),
      ANSI.leave_alt_screen(),
      ANSI.disable_mouse(),
      ANSI.reset()
    ]

    write_stdout(output)
    restore_mode()
    :os.set_signal(:sigtstp, :default)

    {:reply, :ok,
     %{state | raw_mode: false, kitty_keyboard: false, modify_other_keys: false, detecting: false}}
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

  def handle_call(:suspend, _from, %{raw_mode: true} = state) do
    output = [
      keyboard_disable_sequences(state),
      ANSI.disable_paste(),
      ANSI.disable_mouse(),
      ANSI.show_cursor(),
      ANSI.leave_alt_screen(),
      ANSI.disable_mouse(),
      ANSI.reset()
    ]

    write_stdout(output)
    restore_mode()
    {:reply, :ok, %{state | suspended: true, raw_mode: false, detecting: false}}
  end

  def handle_call(:suspend, _from, state) do
    {:reply, :ok, %{state | suspended: true}}
  end

  def handle_call(:resume, _from, %{suspended: true} = state) do
    setup_raw_mode()

    output = [
      ANSI.enter_alt_screen(),
      ANSI.hide_cursor(),
      ANSI.enable_mouse(),
      ANSI.enable_paste(),
      keyboard_enable_sequences(state)
    ]

    write_stdout(output)
    {:reply, :ok, %{state | suspended: false, raw_mode: true}}
  end

  def handle_call(:resume, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, chars}}, state) do
    send(from, {:io_reply, reply_as, :ok})
    events = Input.parse(IO.iodata_to_binary([chars]))

    {cap_events, input_events} = Enum.split_with(events, &(&1.type == :capability))

    state = Enum.reduce(cap_events, state, &handle_capability_event/2)

    input_events
    |> Enum.filter(&press_event?/1)
    |> Enum.each(fn event ->
      Enum.each(state.listeners, fn pid ->
        send(pid, {:terminal_event, event})
      end)
    end)

    {:noreply, state}
  end

  def handle_info(:keyboard_detect_timeout, %{detecting: true} = state) do
    write_stdout(ANSI.enable_modify_other_keys())
    {:noreply, %{state | detecting: false, modify_other_keys: true}}
  end

  def handle_info(:keyboard_detect_timeout, state), do: {:noreply, state}

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
      output = [
        keyboard_disable_sequences(state),
        ANSI.disable_paste(),
        ANSI.disable_mouse(),
        ANSI.show_cursor(),
        ANSI.leave_alt_screen(),
        ANSI.disable_mouse(),
        ANSI.reset()
      ]

      write_stdout(output)

      # Fallback: write critical cleanup directly to /dev/tty, bypassing
      # the Erlang IO system which may already be shut down.
      try do
        {:ok, tty} = :file.open(~c"/dev/tty", [:write, :raw, :binary])

        :file.write(
          tty,
          IO.iodata_to_binary([
            keyboard_disable_sequences(state),
            ANSI.disable_mouse(),
            ANSI.show_cursor(),
            ANSI.reset()
          ])
        )

        :file.close(tty)
      catch
        _, _ -> :ok
      end

      # In tmux with `set -g mouse on`, tmux may re-enable mouse forwarding
      # after the process exits. Spawn a detached cleanup process.
      spawn_deferred_mouse_cleanup(state)

      restore_mode()
      :os.set_signal(:sigtstp, :default)
    end

    :ok
  end

  # --- Private helpers ---

  defp handle_capability_event(%{capability: :kitty_keyboard, value: _flags} = event, state) do
    # Clean up modifyOtherKeys if it was enabled during the detection timeout
    if state.modify_other_keys, do: write_stdout(ANSI.disable_modify_other_keys())
    flags = ANSI.default_kitty_flags()
    write_stdout(ANSI.push_kitty_keyboard(flags))
    caps = Capabilities.apply_capability(state.capabilities, event)

    %{
      state
      | kitty_keyboard: true,
        kitty_flags: flags,
        detecting: false,
        modify_other_keys: false,
        capabilities: caps
    }
  end

  defp handle_capability_event(%{capability: :decrqm} = event, state) do
    caps = Capabilities.apply_capability(state.capabilities, event)
    %{state | capabilities: caps}
  end

  defp handle_capability_event(_event, state), do: state

  # Filter out repeat/release events — only pass :press (and legacy events without event_type)
  defp press_event?(%{event_type: :repeat}), do: false
  defp press_event?(%{event_type: :release}), do: false
  defp press_event?(_), do: true

  # Single function body (not multi-clause) to handle overlapping states defensively
  defp keyboard_disable_sequences(state) do
    kitty =
      if state.kitty_keyboard,
        do: [ANSI.set_kitty_keyboard(0), ANSI.pop_kitty_keyboard()],
        else: []

    mok = if state.modify_other_keys, do: ANSI.disable_modify_other_keys(), else: []
    [kitty, mok]
  end

  defp keyboard_enable_sequences(state) do
    kitty = if state.kitty_keyboard, do: ANSI.push_kitty_keyboard(state.kitty_flags), else: []
    mok = if state.modify_other_keys, do: ANSI.enable_modify_other_keys(), else: []
    [kitty, mok]
  end

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

  # Spawn a background shell process that writes mouse disable sequences
  # AFTER the BEAM exits. This handles the tmux `set -g mouse on` case where
  # tmux re-enables mouse forwarding when the pane's child process exits.
  #
  # Port.open children go through erl_child_setup which calls setsid(),
  # detaching from the controlling terminal. We resolve the actual tty device
  # path (e.g. /dev/pts/3) before spawning.
  defp spawn_deferred_mouse_cleanup(state) do
    disable_seq =
      IO.iodata_to_binary([
        ANSI.disable_mouse(),
        keyboard_disable_sequences(state),
        ANSI.show_cursor(),
        ANSI.reset()
      ])

    tty_path = resolve_tty_path()

    # Write escape sequences to a temp file to avoid shell quoting issues.
    tmp = "/tmp/.elixir_opentui_cleanup_#{:os.getpid()}"
    File.write!(tmp, disable_seq)

    cmd = "sleep 0.3 && cat #{tmp} > #{tty_path} 2>/dev/null; rm -f #{tmp}"
    port = Port.open({:spawn, "sh -c '#{cmd} &'"}, [:binary, :nouse_stdio])
    :erlang.unlink(port)
  catch
    _, _ -> :ok
  end

  defp resolve_tty_path do
    from_fds =
      Enum.find_value([2, 0, 1], fn fd_num ->
        case File.read_link("/proc/self/fd/#{fd_num}") do
          {:ok, "/dev/pts/" <> _ = path} -> path
          {:ok, "/dev/tty" <> rest = path} when rest != "" -> path
          _ -> nil
        end
      end)

    from_fds || resolve_tty_via_open()
  end

  defp resolve_tty_via_open do
    case :file.open(~c"/dev/tty", [:read, :raw]) do
      {:ok, fd} ->
        path = find_tty_device_in_proc()
        :file.close(fd)
        path || "/dev/tty"

      _ ->
        "/dev/tty"
    end
  end

  defp find_tty_device_in_proc do
    case File.ls("/proc/self/fd") do
      {:ok, entries} ->
        entries
        |> Enum.sort_by(&String.to_integer/1)
        |> Enum.reverse()
        |> Enum.find_value(fn entry ->
          case File.read_link("/proc/self/fd/#{entry}") do
            {:ok, "/dev/pts/" <> _ = path} -> path
            {:ok, "/dev/tty" <> rest = path} when rest != "" -> path
            _ -> nil
          end
        end)

      _ ->
        nil
    end
  end
end
