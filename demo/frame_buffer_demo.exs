# Frame Buffer Demo — Starfield with ASCIIFont
# Run: mix run demo/frame_buffer_demo.exs
#
# A 60 FPS demo showcasing Canvas + ASCIIFont widgets.
# Stars twinkle via direct math, title cycles hue via Timeline.
# Press Space=pause, Tab=cycle fonts, R=reset, Q=quit.

defmodule FrameBufferDemo do
  alias ElixirOpentui.Animation.Timeline
  alias ElixirOpentui.{Canvas, Color, ASCIIFont}

  @fonts [:tiny, :block]
  @star_count 40
  @wave_chars ["~", "≈", "~", "^", "~", "≈", "~", "^"]

  def init(cols, rows) do
    stars = generate_stars(cols, rows)

    tl =
      Timeline.new(duration: 3000, loop: true)
      |> Timeline.add(:hue, from: 0.0, to: 360.0, easing: :linear)
      |> Timeline.play()

    %{
      cols: cols,
      rows: rows,
      stars: stars,
      timeline: tl,
      elapsed: 0.0,
      paused: false,
      font_idx: 0,
      fps: 0,
      fps_frame_count: 0,
      fps_last_time: 0.0,
      _live: true,
      _tick_interval: 16
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true, meta: false}, _state), do: :quit
  def handle_event(%{type: :key, key: "q", meta: false}, _state), do: :quit

  def handle_event(%{type: :key, key: " ", meta: false}, state) do
    {:cont, %{state | paused: not state.paused}}
  end

  def handle_event(%{type: :key, key: "r", meta: false}, state) do
    stars = generate_stars(state.cols, state.rows)

    tl =
      Timeline.new(duration: 3000, loop: true)
      |> Timeline.add(:hue, from: 0.0, to: 360.0, easing: :linear)
      |> Timeline.play()

    {:cont, %{state | stars: stars, timeline: tl, elapsed: 0.0, fps: 0, fps_frame_count: 0, fps_last_time: 0.0}}
  end

  def handle_event(%{type: :key, key: :tab, meta: false}, state) do
    new_idx = rem(state.font_idx + 1, length(@fonts))
    {:cont, %{state | font_idx: new_idx}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def handle_tick(_dt, %{paused: true} = state) do
    {:cont, state}
  end

  def handle_tick(dt, state) do
    elapsed = state.elapsed + dt
    tl = Timeline.advance(state.timeline, dt)
    frame_count = state.fps_frame_count + 1

    {fps, frame_count, fps_last_time} =
      if elapsed - state.fps_last_time >= 1000.0 do
        {frame_count, 0, elapsed}
      else
        {state.fps, frame_count, state.fps_last_time}
      end

    {:cont,
     %{
       state
       | elapsed: elapsed,
         timeline: tl,
         fps: fps,
         fps_frame_count: frame_count,
         fps_last_time: fps_last_time
     }}
  end

  def render(state) do
    import ElixirOpentui.View

    font = Enum.at(@fonts, state.font_idx)
    font_h = ASCIIFont.font_height(font)

    # Compute available space
    panel_h = min(state.rows - 2, 30)
    # 2 for top/bottom border, 1 for footer text, 1 for spacing
    canvas_h = max(3, panel_h - font_h - 4)
    canvas_w = max(10, state.cols - 6)
    panel_w = min(state.cols - 2, canvas_w + 4)

    # Build the canvas with stars + wave
    canvas = build_canvas(state, canvas_w, canvas_h)

    # Title colors from hue
    hue = Timeline.value(state.timeline, :hue)
    title_fg = Color.hsl(hue, 0.8, 0.65)
    secondary_fg = Color.hsl(hue + 30.0, 0.5, 0.4)

    font_name = Atom.to_string(font) |> String.upcase()
    status = if state.paused, do: "PAUSED", else: "RUNNING"

    footer =
      "SPC=pause TAB=font(#{font_name}) R=reset Q=quit  " <>
        "#{status}  FPS:#{state.fps}"

    panel_bg = Color.rgb(10, 10, 20)
    dim_fg = Color.rgb(80, 80, 100)

    panel id: :main, title: " Starfield Demo ", width: panel_w, height: panel_h,
          border: true, border_style: :rounded, bg: panel_bg, fg: Color.rgb(60, 80, 120) do
      box height: font_h + 1, padding: {0, 1, 0, 1} do
        ascii_font(
          text: "---!!!---!!!---",
          font: font,
          fg: title_fg,
          secondary_fg: secondary_fg,
          bg: panel_bg
        )
      end

      box height: canvas_h, padding: {0, 1, 0, 1} do
        frame_buffer(buffer: canvas, width: canvas_w, height: canvas_h)
      end

      text(content: footer, fg: dim_fg, bg: panel_bg)
    end
  end

  def focused_id(_state), do: nil

  # --- Private ---

  defp generate_stars(cols, rows) do
    max_w = max(10, cols - 6)
    max_h = max(3, rows - 15)

    for _ <- 1..@star_count do
      %{
        x: :rand.uniform(max_w) - 1,
        y: :rand.uniform(max_h) - 1,
        phase: :rand.uniform() * :math.pi() * 2,
        freq: 0.001 + :rand.uniform() * 0.003,
        base_brightness: 100 + :rand.uniform(155)
      }
    end
  end

  defp build_canvas(state, w, h) do
    canvas = Canvas.new(w, h)
    bg = Color.rgb(10, 10, 20)

    # Draw stars
    canvas =
      Enum.reduce(state.stars, canvas, fn star, c ->
        if star.x < w and star.y < h do
          brightness =
            (:math.sin(state.elapsed * star.freq + star.phase) * 0.5 + 0.5)
            |> Kernel.*(star.base_brightness)
            |> trunc()
            |> max(20)
            |> min(255)

          char =
            cond do
              brightness > 200 -> "★"
              brightness > 140 -> "*"
              brightness > 80 -> "·"
              true -> "."
            end

          fg = Color.rgb(brightness, brightness, min(255, brightness + 30))
          Canvas.set_cell(c, star.x, star.y, char, fg, bg)
        else
          c
        end
      end)

    # Draw sine wave near the bottom
    wave_y = max(0, h - 2)

    canvas =
      if wave_y > 0 do
        Enum.reduce(0..(w - 1)//1, canvas, fn x, c ->
          offset = :math.sin(x * 0.15 + state.elapsed * 0.002) * 1.0
          y_pos = wave_y + trunc(offset)

          if y_pos >= 0 and y_pos < h do
            char_idx = rem(x, length(@wave_chars))
            char = Enum.at(@wave_chars, char_idx)

            # Wave color shifts with position
            wave_hue = rem(trunc(x * 3 + state.elapsed * 0.1), 360)
            fg = Color.hsl(wave_hue / 1.0, 0.6, 0.45)
            Canvas.set_cell(c, x, y_pos, char, fg, bg)
          else
            c
          end
        end)
      else
        canvas
      end

    canvas
  end

end

ElixirOpentui.Demo.DemoRunner.run(FrameBufferDemo)
