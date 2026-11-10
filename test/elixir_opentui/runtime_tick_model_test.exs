defmodule ElixirOpentui.RuntimeTickModelTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Runtime

  defmodule App do
    @moduledoc false
    use ElixirOpentui.Component

    def init(_props), do: %{_live: false}
    def update(:toggle_live, _event, state), do: %{state | _live: not state._live}
    def update(_, _, state), do: state

    def render(_state) do
      import ElixirOpentui.View
      text(content: "")
    end
  end

  @ops [:start, :stop, :request_live, :drop_live, :suspend, :resume, :toggle_live]
  @depth 4

  defp sequences(0), do: [[]]
  defp sequences(n), do: for(op <- @ops, rest <- sequences(n - 1), do: [op | rest])

  defp mount do
    {:ok, rt} = Runtime.start_link(cols: 1, rows: 1)
    :ok = Runtime.mount(rt, App)
    rt
  end

  defp apply_op(rt, :start, refs) do
    Runtime.start(rt)
    refs
  end

  defp apply_op(rt, :stop, refs) do
    Runtime.stop(rt)
    refs
  end

  defp apply_op(rt, :request_live, refs), do: [Runtime.request_live(rt) | refs]
  defp apply_op(_rt, :drop_live, []), do: []

  defp apply_op(rt, :drop_live, [ref | refs]) do
    Runtime.drop_live(rt, ref)
    refs
  end

  defp apply_op(rt, :suspend, refs) do
    Runtime.suspend(rt)
    refs
  end

  defp apply_op(rt, :resume, refs) do
    Runtime.resume(rt)
    refs
  end

  defp apply_op(rt, :toggle_live, refs) do
    Runtime.send_app_msg(rt, :toggle_live)
    refs
  end

  defp should_tick?(s) do
    s.app_state._live or MapSet.size(s.live_refs) > 0 or s.explicit_start
  end

  defp first_violation(rule) do
    Enum.find_value(sequences(@depth), fn ops ->
      rt = mount()

      broken_at =
        ops
        |> Enum.reduce_while({[], []}, fn op, {refs, done} ->
          refs = apply_op(rt, op, refs)
          done = done ++ [op]
          if rule.(:sys.get_state(rt)), do: {:cont, {refs, done}}, else: {:halt, {:broken, done}}
        end)

      GenServer.stop(rt)

      case broken_at do
        {:broken, done} -> done
        _ -> nil
      end
    end)
  end

  test "the runtime is suspended exactly while suspend calls are outstanding" do
    rule = fn s -> s.suspend_count > 0 == (s.control_state == :suspended) end
    assert first_violation(rule) == nil
  end

  test "the runtime ticks when ticks are wanted and it is not suspended" do
    rule = fn s ->
      not (s.suspend_count == 0 and should_tick?(s)) or
        (s.control_state == :running and s.tick_timer_ref != nil)
    end

    assert first_violation(rule) == nil
  end

  test "a stop and a start that wait behind an expired tick timer leave one tick chain" do
    frame_ms = 100
    ticks = :counters.new(1, [])

    count = fn
      %{type: :tick} -> :counters.add(ticks, 1, 1)
      _ -> :ok
    end

    {:ok, rt} = Runtime.start_link(cols: 1, rows: 1, on_event: count)
    :ok = Runtime.mount(rt, App)
    :sys.replace_state(rt, &%{&1 | target_frame_time: frame_ms})

    :ok = Runtime.start(rt)
    :ok = :sys.suspend(rt)
    spawn(fn -> Runtime.stop(rt) end)
    Process.sleep(10)
    spawn(fn -> Runtime.start(rt) end)
    Process.sleep(frame_ms + 50)
    :ok = :sys.resume(rt)

    Process.sleep(50)
    :counters.put(ticks, 1, 0)
    Process.sleep(10 * frame_ms)
    observed = :counters.get(ticks, 1)
    GenServer.stop(rt)

    assert observed in 5..12, "expected about 10 ticks in 10 frames, got #{observed}"
  end
end
