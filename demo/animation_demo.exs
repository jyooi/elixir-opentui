# Animation Demo
# Run: mix run demo/animation_demo.exs
#
# A box that fades in on start.
# Press 'f' to toggle fade in/out, 'q' or Ctrl+C to quit.

defmodule AnimationDemo do
  alias ElixirOpentui.Animation.Timeline
  alias ElixirOpentui.Color

  def init(cols, rows) do
    tl =
      Timeline.new(duration: 500)
      |> Timeline.add(:opacity, from: 0.0, to: 1.0, easing: :out_expo)
      |> Timeline.play()

    %{cols: cols, rows: rows, timeline: tl, _live: true}
  end

  def handle_event(%{type: :key, key: "c", ctrl: true, meta: false}, _state), do: :quit
  def handle_event(%{type: :key, key: "q", meta: false}, _state), do: :quit

  def handle_event(%{type: :key, key: "f", meta: false}, state) do
    current = Timeline.value(state.timeline, :opacity)
    target = if current > 0.5, do: 0.0, else: 1.0

    tl =
      Timeline.new(duration: 400)
      |> Timeline.add(:opacity, from: current, to: target, easing: :in_out_sine)
      |> Timeline.play()

    {:cont, %{state | timeline: tl, _live: true}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def handle_tick(dt, state) do
    tl = Timeline.advance(state.timeline, dt)
    live = not Timeline.finished?(tl)
    {:cont, %{state | timeline: tl, _live: live}}
  end

  def render(state) do
    import ElixirOpentui.View

    opacity = Timeline.value(state.timeline, :opacity)
    # Map opacity to a visible brightness for the box content
    brightness = trunc(opacity * 255)
    fg = Color.rgb(brightness, brightness, brightness)
    bg = Color.rgb(trunc(opacity * 30), trunc(opacity * 20), trunc(opacity * 50))
    dim_fg = Color.rgb(100, 100, 100)

    panel_w = min(50, state.cols - 4)
    bar = String.duplicate("#", trunc(opacity * 30))

    panel id: :main, title: "Animation Demo", width: panel_w, height: 12,
          border: true, fg: fg, bg: bg do
      text(content: "Press 'f' to toggle fade, 'q' to quit", fg: dim_fg, bg: bg)
      text(content: "")
      text(content: "  Opacity: #{Float.round(opacity / 1, 2)}", fg: fg, bg: bg)
      text(content: "  Live: #{state._live}", fg: dim_fg, bg: bg)
      text(content: "")
      text(content: "  [#{String.pad_trailing(bar, 30)}]", fg: fg, bg: bg)
    end
  end

  def focused_id(_state), do: :main
end

ElixirOpentui.Demo.DemoRunner.run(AnimationDemo)
