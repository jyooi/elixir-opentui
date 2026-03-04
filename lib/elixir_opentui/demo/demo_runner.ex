defmodule ElixirOpentui.Demo.DemoRunner do
  @moduledoc """
  Reusable runner for interactive widget demos.

  Handles terminal setup/cleanup, input reading, and the render loop
  so demo modules can focus purely on widget logic.

  Uses OTP 28's `:shell.start_interactive({:noshell, :raw})` to switch
  the terminal to raw mode and read input via `IO.getn/2`.

  Supports Kitty keyboard protocol auto-detection with modifyOtherKeys fallback.
  Detects synchronized output (mode 2026) support and wraps frames in BSU/ESU
  when available to eliminate flicker.

  ## Demo Module Protocol

  A demo module must implement:

  - `init(cols, rows)` — returns initial state
  - `handle_event(event, state)` — returns `{:cont, new_state}` or `:quit`
  - `render(state)` — returns an Element tree
  - `focused_id(state)` — returns the focused widget id or nil
  """

  alias ElixirOpentui.{ANSI, Capabilities, Input, Renderer}

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

    # Trap exits so the after block always runs even if the linked input
    # reader crashes. Without this, a linked process dying with a non-normal
    # reason kills the main process and skips try/after cleanup.
    Process.flag(:trap_exit, true)

    {:ok, tty} = :file.open(~c"/dev/tty", [:write, :raw, :binary])

    # Arm the deferred mouse cleanup BEFORE entering the demo loop.
    # If the BEAM is killed abruptly (erlang:halt from break handler, SIGINT,
    # etc.), the after block never runs. By spawning the deferred cleanup
    # process now, it's already waiting to fire. On normal exit, the after
    # block deletes the temp file, cancelling the deferred cleanup (since
    # the after block already wrote the disable sequences directly).
    deferred_tmp = arm_deferred_mouse_cleanup(tty)

    try do
      setup_terminal(tty)

      input_pid = start_input_reader()
      {caps, buffered_events} = detect_capabilities(tty)
      ctx = %{tty: tty, caps: caps}

      state = demo_mod.init(cols, rows)
      renderer = Renderer.new(cols, rows)

      # Initial full render
      tree = demo_mod.render(state)
      focus_id = demo_mod.focused_id(state)
      {renderer, ansi} = Renderer.render_full(renderer, tree, focus_id: focus_id)
      write_frame(ctx, ansi)

      # Process any input events that arrived during the detection window
      case process_buffered_events(demo_mod, buffered_events, state, renderer, ctx) do
        {state, renderer} ->
          # Initialize _last_tick before entering the loop so the first
          # frame gets dt ≈ tick_interval, not dt = 0.
          state = Map.put_new(state, :_last_tick, System.monotonic_time(:millisecond))
          start_time = System.monotonic_time(:millisecond)
          result = loop(demo_mod, state, renderer, ctx, input_pid, start_time, timeout)
          stop_input_reader(input_pid)
          result

        :ok ->
          stop_input_reader(input_pid)
          :ok
      end
    after
      restore_terminal(tty)
      :file.close(tty)

      # Fallback: write critical cleanup through stderr (fd 2), a separate
      # I/O path from the /dev/tty fd above. Defends against the primary
      # write being lost due to prim_tty interaction during VM shutdown.
      try do
        :io.put_chars(
          :standard_error,
          IO.iodata_to_binary([
            ANSI.set_kitty_keyboard(0),
            ANSI.pop_kitty_keyboard(),
            ANSI.disable_modify_other_keys(),
            ANSI.disable_mouse()
          ])
        )
      catch
        _, _ -> :ok
      end

      # Switch prim_tty back to cooked mode. Note: this uses TCSANOW
      # (not TCSADRAIN) internally — there is no output drain guarantee.
      # For PTYs, the distinction is moot (pty_write is synchronous).
      :shell.start_interactive({:noshell, :cooked})

      # On normal exit, cancel the deferred cleanup by deleting its temp
      # file — restore_terminal already wrote the disable sequences.
      # The deferred process will harmlessly cat a missing file.
      cancel_deferred_mouse_cleanup(deferred_tmp)

      spawn_deferred_mouse_cleanup()

      :os.set_signal(:sigtstp, :default)
      Process.flag(:trap_exit, false)
    end
  end

  defp setup_terminal(tty) do
    tty_write(tty, [
      ANSI.enter_alt_screen(),
      ANSI.hide_cursor(),
      ANSI.enable_mouse(),
      ANSI.enable_paste(),
      ANSI.clear_screen()
    ])
  end

  defp restore_terminal(tty) do
    tty_write(tty, restore_terminal_sequences())
  end

  @doc false
  @spec restore_terminal_sequences() :: [iodata()]
  def restore_terminal_sequences do
    [
      # Disable Kitty keyboard: set flags to 0 first (belt-and-suspenders),
      # then pop the stack entry. The set ensures enhancements are off even
      # if the pop doesn't take effect (e.g. Ghostty state machine edge case
      # when keyboard events were recently processed).
      ANSI.set_kitty_keyboard(0),
      ANSI.pop_kitty_keyboard(),
      ANSI.disable_modify_other_keys(),
      ANSI.disable_paste(),
      ANSI.disable_mouse(),
      ANSI.reset(),
      ANSI.show_cursor(),
      ANSI.leave_alt_screen(),
      # Safety net: some terminals restore saved private modes on alt screen exit,
      # which can re-enable mouse tracking. Send disable again after leaving.
      ANSI.disable_mouse()
    ]
  end

  # Arm a deferred mouse cleanup process BEFORE the demo loop starts.
  # This ensures cleanup happens even if the BEAM is killed abruptly
  # (erlang:halt from break handler, SIGINT, etc.) and the after block
  # never runs.
  #
  # The subprocess sleeps, then checks if the temp file still exists.
  # On normal exit, the after block deletes the temp file (cancellation).
  # On abrupt exit, the file remains and the subprocess writes the
  # disable sequences to the tty.
  #
  # Port.open children go through erl_child_setup which calls setsid(),
  # losing access to /dev/tty. We resolve the real device path first.
  defp arm_deferred_mouse_cleanup(_tty) do
    disable_seq =
      IO.iodata_to_binary([
        ANSI.disable_mouse(),
        ANSI.set_kitty_keyboard(0),
        ANSI.pop_kitty_keyboard(),
        ANSI.disable_modify_other_keys(),
        ANSI.show_cursor(),
        ANSI.reset()
      ])

    tty_path = resolve_tty_path()
    tmp = "/tmp/.elixir_opentui_cleanup_#{:os.getpid()}"
    File.write!(tmp, disable_seq)

    # The subprocess checks if the temp file exists before writing.
    # If the after block ran (normal exit), it deletes the file → no-op.
    # If the BEAM was killed (abrupt exit), file exists → write cleanup.
    # Write multiple times to cover tmux's re-enable timing window.
    cmd =
      "sleep 1 && " <>
        "test -f #{tmp} && cat #{tmp} > #{tty_path} 2>/dev/null && " <>
        "sleep 0.5 && test -f #{tmp} && cat #{tmp} > #{tty_path} 2>/dev/null && " <>
        "sleep 0.5 && test -f #{tmp} && cat #{tmp} > #{tty_path} 2>/dev/null && " <>
        "rm -f #{tmp}"

    port = Port.open({:spawn, "sh -c '#{cmd} &'"}, [:binary, :nouse_stdio])
    # Unlink so the port's exit doesn't send {:EXIT, ...} to the demo loop.
    # The loop catches {:EXIT, _, _} to detect input reader death — an
    # unrelated port exit would accidentally quit the demo.
    :erlang.unlink(port)
    tmp
  catch
    _, _ -> nil
  end

  # Cancel the deferred cleanup by deleting the temp file.
  # The deferred subprocess checks `test -f` before each write.
  defp cancel_deferred_mouse_cleanup(nil), do: :ok

  defp cancel_deferred_mouse_cleanup(tmp) do
    File.rm(tmp)
  catch
    _, _ -> :ok
  end

  # Spawn a deferred mouse-disable for the after-block path.
  # Only writes disable_mouse() — the minimum needed for the tmux case
  # where tmux re-enables mouse tracking after the pane child exits.
  # All other terminal state (keyboard protocol, cursor, reset) was
  # already restored by restore_terminal/1 and the stderr fallback.
  # Keeping this minimal avoids injecting visible garbage into the
  # user's shell prompt. (The armed cleanup in arm_deferred_mouse_cleanup/1
  # retains full sequences because it fires when the after block didn't run.)
  defp spawn_deferred_mouse_cleanup do
    disable_seq = IO.iodata_to_binary(ANSI.disable_mouse())

    tty_path = resolve_tty_path()
    tmp = "/tmp/.elixir_opentui_cleanup2_#{:os.getpid()}"
    File.write!(tmp, disable_seq)

    cmd =
      "sleep 0.3 && cat #{tmp} > #{tty_path} 2>/dev/null && " <>
        "sleep 0.3 && cat #{tmp} > #{tty_path} 2>/dev/null && " <>
        "sleep 0.3 && cat #{tmp} > #{tty_path} 2>/dev/null && " <>
        "rm -f #{tmp}"

    port = Port.open({:spawn, "sh -c '#{cmd} &'"}, [:binary, :nouse_stdio])
    :erlang.unlink(port)
  catch
    _, _ -> :ok
  end

  # Resolve the actual tty device path (e.g. /dev/pts/3). /dev/tty is a
  # process-local alias that won't work in setsid() children — it fails
  # with ENXIO after setsid(). We need the real device like /dev/pts/3.
  defp resolve_tty_path do
    # Try standard fds first (stderr, stdin, stdout)
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

  # Fallback: open /dev/tty (which works while we have a controlling terminal)
  # and resolve the real device path via /proc/self/fd/N on the opened fd.
  defp resolve_tty_via_open do
    case :file.open(~c"/dev/tty", [:read, :raw]) do
      {:ok, fd} ->
        # :file.open returns {:file_descriptor, :prim_file, %{handle: _, r_ahead: _}}
        # We need to find the OS fd number. Use /proc/self/fd to scan for /dev/tty.
        path = find_tty_device_in_proc()
        :file.close(fd)
        path || "/dev/tty"

      _ ->
        "/dev/tty"
    end
  end

  # Scan /proc/self/fd/ for any fd pointing to a real tty device
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

  defp detect_capabilities(tty) do
    caps = Capabilities.detect_env()

    # Send both queries in one write (pipelined — single round-trip window)
    tty_write(tty, [ANSI.query_kitty_keyboard(), ANSI.query_decrqm(2026)])

    # We always wait the full detection window because we can't know how many
    # responses to expect. A terminal supporting kitty but not DECRQM sends one
    # response; one supporting both sends two. Use absolute deadline to prevent
    # creeping timeout — each recursive call computes remaining = max(0, deadline - now).
    deadline = System.monotonic_time(:millisecond) + 100
    {caps, buffered} = receive_capability_responses(caps, [], deadline)

    if caps.kitty_keyboard do
      tty_write(tty, ANSI.push_kitty_keyboard(ANSI.default_kitty_flags()))
    else
      tty_write(tty, ANSI.enable_modify_other_keys())
    end

    {caps, filter_press_events(buffered)}
  end

  defp receive_capability_responses(caps, buffered, deadline) do
    remaining = max(0, deadline - System.monotonic_time(:millisecond))

    receive do
      {:byte, first_byte} ->
        data = accumulate_bytes(first_byte)
        events = Input.parse(data)
        {cap_events, other_events} = Enum.split_with(events, &(&1.type == :capability))
        caps = Enum.reduce(cap_events, caps, &Capabilities.apply_capability(&2, &1))
        receive_capability_responses(caps, buffered ++ other_events, deadline)
    after
      remaining -> {caps, buffered}
    end
  end

  defp filter_press_events(events) do
    Enum.filter(events, fn
      %{event_type: :release} -> false
      %{event_type: :repeat} -> false
      _ -> true
    end)
  end

  defp process_buffered_events(_demo_mod, [], state, renderer, _ctx), do: {state, renderer}

  defp process_buffered_events(demo_mod, [event | rest], state, renderer, ctx) do
    case demo_mod.handle_event(event, state) do
      {:cont, new_state} ->
        tree = demo_mod.render(new_state)
        focus_id = demo_mod.focused_id(new_state)
        {new_renderer, ansi} = Renderer.render(renderer, tree, focus_id: focus_id)
        write_frame(ctx, ansi)
        process_buffered_events(demo_mod, rest, new_state, new_renderer, ctx)

      :quit ->
        :ok
    end
  end

  # Write a rendered frame, wrapping in synchronized update (BSU/ESU) when
  # the terminal supports mode 2026. This eliminates flicker by buffering
  # all output until the ESU sequence, then flushing it as a single
  # atomic screen update.
  #
  # TODO: Add sync output wrapping to Terminal.write/2 (the GenServer path)
  # once a use case for it exists. Currently only DemoRunner renders frames.
  defp write_frame(ctx, ansi) do
    %{tty: tty, caps: caps} = ctx

    if Capabilities.synchronized_output?(caps) do
      tty_write(tty, [ANSI.begin_sync_update(), ansi, ANSI.hide_cursor(), ANSI.end_sync_update()])
    else
      tty_write(tty, [ansi, ANSI.hide_cursor()])
    end
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

  defp loop(demo_mod, state, renderer, ctx, input_pid, start_time, timeout) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > timeout do
      :timeout
    else
      is_live = Map.get(state, :_live, false)
      tick_interval = Map.get(state, :_tick_interval, 33)

      wait_ms =
        if is_live do
          now = System.monotonic_time(:millisecond)
          time_spent = now - Map.get(state, :_last_tick, now)
          max(1, tick_interval - time_spent)
        else
          100
        end

      receive do
        {:byte, first_byte} ->
          data = accumulate_bytes(first_byte)
          events = Input.parse(data)

          # Filter capability events — late responses should update caps, not reach app code
          {cap_events, input_events} = Enum.split_with(events, &(&1.type == :capability))

          ctx =
            if cap_events != [] do
              caps = Enum.reduce(cap_events, ctx.caps, &Capabilities.apply_capability(&2, &1))
              %{ctx | caps: caps}
            else
              ctx
            end

          press_events =
            Enum.filter(input_events, fn
              %{event_type: :release} -> false
              %{event_type: :repeat} -> false
              _ -> true
            end)

          handle_events(
            demo_mod,
            press_events,
            state,
            renderer,
            ctx,
            input_pid,
            start_time,
            timeout
          )

        {:clipboard_copy, text} ->
          tty_write(ctx.tty, ANSI.copy_to_clipboard(text))
          loop(demo_mod, state, renderer, ctx, input_pid, start_time, timeout)

        {:EXIT, _pid, _reason} ->
          # Linked input reader (or other process) died — exit the loop
          # gracefully so the after block can run cleanup.
          :ok
      after
        wait_ms ->
          if is_live and function_exported?(demo_mod, :handle_tick, 2) do
            now = System.monotonic_time(:millisecond)
            dt = min(now - Map.get(state, :_last_tick, now), 500)

            case tick_and_render(demo_mod, dt, state, renderer, ctx) do
              {new_state, new_renderer, ctx} ->
                new_state = Map.put(new_state, :_last_tick, now)
                loop(demo_mod, new_state, new_renderer, ctx, input_pid, start_time, timeout)

              :ok ->
                :ok
            end
          else
            loop(demo_mod, state, renderer, ctx, input_pid, start_time, timeout)
          end
      end
    end
  end

  defp tick_and_render(demo_mod, dt, state, renderer, ctx) do
    case demo_mod.handle_tick(dt, state) do
      {:cont, new_state} ->
        tree = demo_mod.render(new_state)
        focus_id = demo_mod.focused_id(new_state)
        {new_renderer, ansi} = Renderer.render(renderer, tree, focus_id: focus_id)
        write_frame(ctx, ansi)
        {new_state, new_renderer, ctx}

      :quit ->
        :ok
    end
  end

  defp handle_events(demo_mod, [], state, renderer, ctx, input_pid, start_time, timeout) do
    is_live = Map.get(state, :_live, false)
    tick_interval = Map.get(state, :_tick_interval, 33)

    if is_live and function_exported?(demo_mod, :handle_tick, 2) do
      now = System.monotonic_time(:millisecond)
      time_since_tick = now - Map.get(state, :_last_tick, now)

      if time_since_tick >= tick_interval do
        dt = min(time_since_tick, 500)

        case tick_and_render(demo_mod, dt, state, renderer, ctx) do
          {new_state, new_renderer, ctx} ->
            new_state = Map.put(new_state, :_last_tick, now)
            loop(demo_mod, new_state, new_renderer, ctx, input_pid, start_time, timeout)

          :ok ->
            :ok
        end
      else
        loop(demo_mod, state, renderer, ctx, input_pid, start_time, timeout)
      end
    else
      loop(demo_mod, state, renderer, ctx, input_pid, start_time, timeout)
    end
  end

  defp handle_events(
         demo_mod,
         [event | rest],
         state,
         renderer,
         ctx,
         input_pid,
         start_time,
         timeout
       ) do
    case demo_mod.handle_event(event, state) do
      {:cont, new_state} ->
        # Live demos defer rendering to the next tick to avoid redundant
        # renders under sustained input (key hold). Non-live demos render
        # immediately since they have no tick loop.
        {new_renderer, ctx} =
          if Map.get(new_state, :_live, false) do
            {renderer, ctx}
          else
            tree = demo_mod.render(new_state)
            focus_id = demo_mod.focused_id(new_state)
            {new_renderer, ansi} = Renderer.render(renderer, tree, focus_id: focus_id)
            write_frame(ctx, ansi)
            {new_renderer, ctx}
          end

        handle_events(
          demo_mod,
          rest,
          new_state,
          new_renderer,
          ctx,
          input_pid,
          start_time,
          timeout
        )

      :quit ->
        :ok
    end
  end
end
