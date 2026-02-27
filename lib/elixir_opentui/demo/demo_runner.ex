defmodule ElixirOpentui.Demo.DemoRunner do
  @moduledoc """
  Reusable runner for interactive widget demos.

  Handles terminal setup/cleanup, input reading, and the render loop
  so demo modules can focus purely on widget logic.

  Uses OTP 28's `:shell.start_interactive({:noshell, :raw})` to switch
  the terminal to raw mode and read input via `IO.getn/2`.

  ## Demo Module Protocol

  A demo module must implement:

  - `init(cols, rows)` — returns initial state
  - `handle_event(event, state)` — returns `{:cont, new_state}` or `:quit`
  - `render(state)` — returns an Element tree
  - `focused_id(state)` — returns the focused widget id or nil
  """

  alias ElixirOpentui.{Input, Renderer}

  @doc "Run a demo module. Blocks until the demo exits or times out."
  def run(demo_mod, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 300_000)

    # Get terminal size before switching modes
    {cols, rows} = get_terminal_size()

    # Switch to raw mode using OTP 28's native API.
    # This enables lazy-read so IO.getn is the only terminal reader.
    :shell.start_interactive({:noshell, :raw})

    # Ignore SIGTSTP so Ctrl+Z bytes reach the app as input instead of
    # suspending the process.
    :os.set_signal(:sigtstp, :ignore)

    {:ok, tty} = :file.open(~c"/dev/tty", [:write, :raw, :binary])

    try do
      setup_terminal(tty)

      state = demo_mod.init(cols, rows)
      renderer = Renderer.new(cols, rows)

      input_pid = start_input_reader()
      start_time = System.monotonic_time(:millisecond)

      # Initial full render
      tree = demo_mod.render(state)
      focus_id = demo_mod.focused_id(state)
      {renderer, ansi} = Renderer.render_full(renderer, tree, focus_id: focus_id)
      tty_write(tty, [ansi, "\e[?25l"])

      result = loop(demo_mod, state, renderer, tty, input_pid, start_time, timeout)

      stop_input_reader(input_pid)
      result
    after
      restore_terminal(tty)
      :file.close(tty)
      :os.set_signal(:sigtstp, :default)
    end
  end

  defp setup_terminal(tty) do
    # Alt screen, hide cursor, enable SGR mouse, enable bracketed paste
    tty_write(tty, "\e[?1049h\e[?25l\e[?1006h\e[?2004h\e[2J")
  end

  defp restore_terminal(tty) do
    # Disable mouse, disable bracketed paste, show cursor, leave alt screen
    tty_write(tty, "\e[?1006l\e[?2004l\e[0m\e[?25h\e[?1049l")
  end

  defp tty_write(tty, data) do
    :file.write(tty, IO.iodata_to_binary(data))
  end

  defp get_terminal_size do
    {:ok, cols} = :io.columns()
    {:ok, rows} = :io.rows()
    {cols, rows}
  end

  defp start_input_reader do
    parent = self()

    spawn_link(fn ->
      :io.setopts(:standard_io, binary: true)
      byte_reader_loop(parent)
    end)
  end

  defp byte_reader_loop(parent) do
    case IO.getn("", 1) do
      data when is_binary(data) and byte_size(data) > 0 ->
        send(parent, {:byte, data})
        byte_reader_loop(parent)

      _ ->
        :ok
    end
  end

  defp stop_input_reader(pid) do
    Process.unlink(pid)
    Process.exit(pid, :kill)
  end

  # Accumulate bytes from the reader: once the first byte arrives,
  # wait 2ms for more (to capture multi-byte escape sequences as one chunk).
  defp accumulate_bytes(acc) do
    receive do
      {:byte, b} -> accumulate_bytes(acc <> b)
    after
      2 -> acc
    end
  end

  defp loop(demo_mod, state, renderer, tty, input_pid, start_time, timeout) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > timeout do
      :timeout
    else
      is_live = Map.get(state, :_live, false)
      wait_ms = if is_live, do: 33, else: 100

      receive do
        {:byte, first_byte} ->
          data = accumulate_bytes(first_byte)
          events = Input.parse(data)
          handle_events(demo_mod, events, state, renderer, tty, input_pid, start_time, timeout)
      after
        wait_ms ->
          if is_live and function_exported?(demo_mod, :handle_tick, 2) do
            dt = wait_ms
            {new_state, renderer, tty} = tick_and_render(demo_mod, dt, state, renderer, tty)
            loop(demo_mod, new_state, renderer, tty, input_pid, start_time, timeout)
          else
            loop(demo_mod, state, renderer, tty, input_pid, start_time, timeout)
          end
      end
    end
  end

  defp tick_and_render(demo_mod, dt, state, renderer, tty) do
    case demo_mod.handle_tick(dt, state) do
      {:cont, new_state} ->
        tree = demo_mod.render(new_state)
        focus_id = demo_mod.focused_id(new_state)
        {new_renderer, ansi} = Renderer.render(renderer, tree, focus_id: focus_id)
        tty_write(tty, [ansi, "\e[?25l"])
        {new_state, new_renderer, tty}

      :quit ->
        {state, renderer, tty}
    end
  end

  defp handle_events(demo_mod, [], state, renderer, tty, input_pid, start_time, timeout) do
    loop(demo_mod, state, renderer, tty, input_pid, start_time, timeout)
  end

  defp handle_events(demo_mod, [event | rest], state, renderer, tty, input_pid, start_time, timeout) do
    case demo_mod.handle_event(event, state) do
      {:cont, new_state} ->
        # Render after each event
        tree = demo_mod.render(new_state)
        focus_id = demo_mod.focused_id(new_state)
        {new_renderer, ansi} = Renderer.render(renderer, tree, focus_id: focus_id)
        tty_write(tty, [ansi, "\e[?25l"])
        handle_events(demo_mod, rest, new_state, new_renderer, tty, input_pid, start_time, timeout)

      :quit ->
        :ok
    end
  end
end
