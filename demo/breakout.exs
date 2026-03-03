# Breakout — Classic brick-breaker game
# Run: mix run demo/breakout.exs
#
# A 60 FPS arcade game showcasing Canvas pixel drawing, ASCIIFont HUD,
# Timeline animations, particle effects, screen shake, and smooth physics.
# Arrow keys / A,D / H,L to move paddle, Space to launch/restart, Q to quit.

defmodule Breakout do
  alias ElixirOpentui.Animation.Timeline
  alias ElixirOpentui.{Canvas, Color, ASCIIFont}

  # --- Constants ---
  @paddle_chars "▟█████▙"
  @paddle_width 7
  @paddle_speed 50.0
  @paddle_input_timeout 100.0

  @ball_char "●"
  @ball_base_speed 24.0
  @ball_speed_per_level 2.0
  @ball_max_speed 35.0
  @aspect_ratio 2.0

  @brick_width 4
  @brick_height 1
  @brick_top_margin 3
  @brick_left_margin 2

  @max_launch_angle 75.0
  @anti_stuck_min_vy 2.0

  @bg Color.rgb(8, 8, 20)

  @row_colors [
    {0.0, 0.8, 0.50},    # red
    {20.0, 0.85, 0.55},   # orange
    {45.0, 0.9, 0.55},    # yellow
    {120.0, 0.7, 0.45},   # green
    {180.0, 0.7, 0.50},   # cyan
    {230.0, 0.7, 0.50},   # blue
    {275.0, 0.6, 0.50},   # purple
    {320.0, 0.7, 0.55}    # pink
  ]

  @fill_chars %{3 => "█", 2 => "▓", 1 => "░"}

  @trail_life 80.0

  # ── init ──────────────────────────────────────────────────────────

  def init(cols, rows) do
    canvas_w = max(30, cols - 6)
    canvas_h = max(15, rows - 8)

    state = %{
      cols: cols,
      rows: rows,
      canvas_w: canvas_w,
      canvas_h: canvas_h,
      phase: :title,
      level: 1,
      lives: 3,
      score: 0,
      high_score: 0,
      combo: 0,
      combo_timer: 0.0,
      # Paddle
      paddle_x: canvas_w / 2.0 - @paddle_width / 2.0,
      paddle_y: canvas_h - 2,
      paddle_dir: :none,
      paddle_input_time: 0.0,
      # Ball
      ball_x: 0.0,
      ball_y: 0.0,
      ball_vx: 0.0,
      ball_vy: 0.0,
      ball_speed: @ball_base_speed,
      # Bricks
      bricks: [],
      # Particles + trail
      particles: [],
      trail: [],
      # Timelines
      timeline: build_main_timeline(),
      shake_timeline: nil,
      shake_x: 0,
      shake_y: 0,
      # FPS tracking
      elapsed: 0.0,
      fps: 0,
      fps_frame_count: 0,
      fps_last_time: 0.0,
      frame_ms: 16.0,
      # Live mode
      _live: true,
      _tick_interval: 16
    }

    state
    |> setup_level()
    |> place_ball_on_paddle()
  end

  defp build_main_timeline do
    Timeline.new(duration: 3000, loop: true, alternate: true)
    |> Timeline.add(:brick_hue_shift, from: -15.0, to: 15.0, easing: :linear)
    |> Timeline.add(:paddle_glow, from: 0.6, to: 1.0, easing: :in_out_sine)
    |> Timeline.add(:score_hue, from: 50.0, to: 70.0, easing: :linear)
    |> Timeline.play()
  end

  # ── handle_event ──────────────────────────────────────────────────

  def handle_event(%{type: :key, key: "c", ctrl: true, meta: false}, _state), do: :quit
  def handle_event(%{type: :key, key: "q", meta: false}, _state), do: :quit

  # Title screen — Space to start
  def handle_event(%{type: :key, key: " ", meta: false}, %{phase: :title} = state) do
    {:cont, %{state | phase: :serving}}
  end

  # Serving — Space to launch ball
  def handle_event(%{type: :key, key: " ", meta: false}, %{phase: :serving} = state) do
    # Launch at a slight random angle
    angle_deg = -90.0 + (:rand.uniform() - 0.5) * 30.0
    angle = angle_deg * :math.pi() / 180.0
    speed = state.ball_speed
    vx = :math.cos(angle) * speed * @aspect_ratio
    vy = :math.sin(angle) * speed

    {:cont, %{state | phase: :playing, ball_vx: vx, ball_vy: vy}}
  end

  # Game over — Space to restart
  def handle_event(%{type: :key, key: " ", meta: false}, %{phase: :game_over} = state) do
    {:cont, restart_game(state)}
  end

  # Level complete — Space to continue
  def handle_event(%{type: :key, key: " ", meta: false}, %{phase: :level_complete} = state) do
    new_state =
      %{state | level: state.level + 1, phase: :serving}
      |> setup_level()
      |> place_ball_on_paddle()

    {:cont, new_state}
  end

  # Pause toggle
  def handle_event(%{type: :key, key: "p", meta: false}, %{phase: :playing} = state) do
    {:cont, %{state | phase: :paused}}
  end

  def handle_event(%{type: :key, key: "p", meta: false}, %{phase: :paused} = state) do
    {:cont, %{state | phase: :playing}}
  end

  # Paddle movement — set direction + timestamp; actual movement happens in handle_tick
  def handle_event(%{type: :key, key: key, meta: false}, state)
      when key in [:left, "a", "h"] and state.phase in [:playing, :serving] do
    {:cont, %{state | paddle_dir: :left, paddle_input_time: state.elapsed}}
  end

  def handle_event(%{type: :key, key: key, meta: false}, state)
      when key in [:right, "d", "l"] and state.phase in [:playing, :serving] do
    {:cont, %{state | paddle_dir: :right, paddle_input_time: state.elapsed}}
  end

  def handle_event(_event, state), do: {:cont, state}

  # ── handle_tick ───────────────────────────────────────────────────

  def handle_tick(dt, %{phase: phase} = state) when phase in [:title, :paused] do
    tl = Timeline.advance(state.timeline, dt)
    {:cont, %{state | timeline: tl}}
  end

  def handle_tick(dt, %{phase: :game_over} = state) do
    {shake_tl, sx, sy} = advance_shake(state.shake_timeline, dt)
    particles = move_particles(state.particles, dt)
    trail = move_trail(state.trail, dt)
    tl = Timeline.advance(state.timeline, dt)

    {:cont,
     %{state | shake_timeline: shake_tl, shake_x: sx, shake_y: sy,
       particles: particles, trail: trail, timeline: tl}}
  end

  def handle_tick(dt, %{phase: :level_complete} = state) do
    tl = Timeline.advance(state.timeline, dt)
    particles = move_particles(state.particles, dt)
    {:cont, %{state | timeline: tl, particles: particles}}
  end

  def handle_tick(dt, %{phase: :serving} = state) do
    tl = Timeline.advance(state.timeline, dt)
    state = update_fps(state, dt)
    paddle_x = apply_paddle_movement(state, dt)

    state =
      %{state | timeline: tl, paddle_x: paddle_x}
      |> place_ball_on_paddle()

    {:cont, state}
  end

  def handle_tick(dt, %{phase: :playing} = state) do
    elapsed = state.elapsed + dt
    tl = Timeline.advance(state.timeline, dt)
    state = update_fps(state, dt)

    # Move paddle (velocity-based)
    paddle_x = apply_paddle_movement(state, dt)
    state = %{state | paddle_x: paddle_x}

    # Move ball
    new_bx = state.ball_x + state.ball_vx * dt / 1000.0
    new_by = state.ball_y + state.ball_vy * dt / 1000.0
    ball_vx = state.ball_vx
    ball_vy = state.ball_vy

    # Wall bounces (left/right)
    {new_bx, ball_vx} =
      cond do
        new_bx <= 0.0 -> {0.0, abs(ball_vx)}
        new_bx >= state.canvas_w - 1.0 -> {state.canvas_w - 1.0, -abs(ball_vx)}
        true -> {new_bx, ball_vx}
      end

    # Ceiling bounce
    {new_by, ball_vy} =
      if new_by <= 0.0 do
        {0.0, abs(ball_vy)}
      else
        {new_by, ball_vy}
      end

    # Paddle collision
    {ball_vx, ball_vy, new_by, paddle_particles} =
      check_paddle_collision(
        new_bx, new_by, ball_vx, ball_vy,
        state.paddle_x, state.paddle_y, state.ball_speed
      )

    # Brick collision
    {bricks, ball_vx, ball_vy, new_bx, new_by, score_add, brick_particles, combo_hits} =
      check_brick_collisions(
        state.bricks, new_bx, new_by, ball_vx, ball_vy,
        state.ball_x, state.ball_y, tl
      )

    # Anti-stuck: nudge vertical velocity if too flat
    ball_vy =
      if abs(ball_vy) < @anti_stuck_min_vy do
        if ball_vy >= 0, do: @anti_stuck_min_vy, else: -@anti_stuck_min_vy
      else
        ball_vy
      end

    # Update combo
    {combo, combo_timer} =
      if combo_hits > 0 do
        {state.combo + combo_hits, 2000.0}
      else
        timer = state.combo_timer - dt
        if timer <= 0.0, do: {0, 0.0}, else: {state.combo, timer}
      end

    combo_mult = max(1, combo)
    score = state.score + score_add * combo_mult

    # Ball trail
    trail =
      [%{x: new_bx, y: new_by, life: @trail_life, max_life: @trail_life} | state.trail]
      |> move_trail(0.0)

    # Particles
    particles =
      (state.particles ++ paddle_particles ++ brick_particles)
      |> move_particles(dt)

    # Shake
    {shake_tl, sx, sy} = advance_shake(state.shake_timeline, dt)

    # Check ball fell off bottom
    if new_by >= state.canvas_h do
      lives = state.lives - 1

      if lives <= 0 do
        # Game over
        explosion = spawn_explosion(trunc(new_bx), state.paddle_y, 0.0, 15)
        go_shake =
          Timeline.new(duration: 600)
          |> Timeline.add(:shake, from: 6.0, to: 0.0, easing: :out_expo)
          |> Timeline.play()

        {:cont,
         %{state |
           phase: :game_over,
           lives: 0,
           score: score,
           high_score: max(state.high_score, score),
           ball_x: new_bx, ball_y: new_by,
           ball_vx: 0.0, ball_vy: 0.0,
           bricks: bricks,
           particles: explosion,
           trail: trail,
           combo: 0, combo_timer: 0.0,
           timeline: tl, elapsed: elapsed,
           shake_timeline: go_shake, shake_x: 0, shake_y: 0}}
      else
        # Lost a life
        life_particles = spawn_explosion(trunc(new_bx), trunc(new_by), 0.0, 10)
        life_shake =
          Timeline.new(duration: 400)
          |> Timeline.add(:shake, from: 4.0, to: 0.0, easing: :out_expo)
          |> Timeline.play()

        new_state =
          %{state |
            phase: :serving,
            lives: lives,
            score: score,
            bricks: bricks,
            particles: life_particles,
            trail: [],
            combo: 0, combo_timer: 0.0,
            timeline: tl, elapsed: elapsed,
            shake_timeline: life_shake, shake_x: 0, shake_y: 0}
          |> place_ball_on_paddle()

        {:cont, new_state}
      end
    else
      # Check level complete
      if bricks == [] do
        clear_particles = spawn_level_clear_particles(state.canvas_w, state.canvas_h)
        clear_shake =
          Timeline.new(duration: 300)
          |> Timeline.add(:shake, from: 3.0, to: 0.0, easing: :out_expo)
          |> Timeline.play()

        {:cont,
         %{state |
           phase: :level_complete,
           score: score,
           bricks: [],
           ball_x: new_bx, ball_y: new_by,
           ball_vx: ball_vx, ball_vy: ball_vy,
           particles: particles ++ clear_particles,
           trail: trail,
           combo: combo, combo_timer: combo_timer,
           timeline: tl, elapsed: elapsed,
           shake_timeline: clear_shake, shake_x: 0, shake_y: 0}}
      else
        {:cont,
         %{state |
           ball_x: new_bx, ball_y: new_by,
           ball_vx: ball_vx, ball_vy: ball_vy,
           bricks: bricks,
           score: score,
           combo: combo, combo_timer: combo_timer,
           particles: particles,
           trail: trail,
           timeline: tl, elapsed: elapsed,
           shake_timeline: shake_tl, shake_x: sx, shake_y: sy}}
      end
    end
  end

  # ── render ────────────────────────────────────────────────────────

  def render(state) do
    import ElixirOpentui.View

    canvas = build_canvas(state)

    score_hue = Timeline.value(state.timeline, :score_hue)
    {sr, sg, sb} = hsl_to_rgb(score_hue, 0.8, 0.65)
    score_fg = Color.rgb(sr, sg, sb)

    dim_fg = Color.rgb(80, 80, 100)
    panel_fg = Color.rgb(60, 80, 120)

    fps_fg =
      cond do
        state.fps >= 50 -> Color.rgb(80, 255, 80)
        state.fps >= 30 -> Color.rgb(255, 220, 60)
        true -> Color.rgb(255, 70, 70)
      end

    frame_ms_label = Float.round(state.frame_ms, 1)

    score_text = "#{state.score}"
    lives_text = "LV:#{state.level}  " <> String.duplicate("♥", state.lives)
    fps_text = "#{state.fps} FPS  #{frame_ms_label}ms"

    combo_text =
      if state.combo > 1, do: "  x#{state.combo}", else: ""

    panel_w = min(state.cols - 2, state.canvas_w + 4)
    font = :tiny
    font_h = ASCIIFont.font_height(font)

    panel_h = min(state.rows - 1, font_h + 1 + state.canvas_h + 1 + 2)

    footer =
      case state.phase do
        :title -> "[SPC]=Start  [Q]=Quit"
        :serving -> "←→ / A,D / H,L=move  [SPC]=Launch"
        :playing -> "←→ / A,D / H,L=move  [P]=Pause  [Q]=Quit"
        :paused -> "[P]=Resume  [Q]=Quit"
        :level_complete -> "Level #{state.level} Complete!  [SPC]=Next Level"
        :game_over -> "GAME OVER! Score:#{state.score}  Hi:#{state.high_score}  [SPC]=Retry"
      end

    combo_fg = if state.combo > 3, do: Color.rgb(255, 200, 50), else: Color.rgb(200, 150, 100)

    panel id: :main, title: " BREAKOUT ", width: panel_w, height: panel_h,
          border: true, border_style: :rounded, bg: @bg, fg: panel_fg do
      box height: font_h + 1, direction: :row, padding: {0, 1, 0, 1} do
        ascii_font(
          text: score_text,
          font: font,
          fg: score_fg,
          bg: @bg
        )

        if combo_text != "" do
          text(content: combo_text, fg: combo_fg, bg: @bg)
        end

        box(flex_grow: 1)
        text(content: fps_text <> "  ", fg: fps_fg, bg: @bg)
        text(content: lives_text, fg: Color.rgb(255, 80, 80), bg: @bg)
      end

      box height: state.canvas_h, padding: {0, 1, 0, 1} do
        frame_buffer(buffer: canvas, width: state.canvas_w, height: state.canvas_h)
      end

      text(content: footer, fg: dim_fg, bg: @bg)
    end
  end

  def focused_id(_state), do: nil

  # ── Canvas rendering ──────────────────────────────────────────────

  defp build_canvas(state) do
    w = state.canvas_w
    h = state.canvas_h
    sx = state.shake_x
    sy = state.shake_y

    canvas = Canvas.new(w, h)

    canvas
    |> draw_bricks(state.bricks, state.timeline, sx, sy)
    |> draw_trail(state.trail, w, h, sx, sy)
    |> draw_particles(state.particles, w, h, sx, sy)
    |> draw_paddle(state, sx, sy)
    |> draw_ball(state, w, h, sx, sy)
    |> draw_overlay(state, w, h)
  end

  defp draw_bricks(canvas, bricks, timeline, sx, sy) do
    hue_shift = Timeline.value(timeline, :brick_hue_shift)

    Enum.reduce(bricks, canvas, fn brick, c ->
      bx = brick.x + sx
      by = brick.y + sy
      {base_h, s, l} = brick.color
      h = base_h + hue_shift
      {r, g, b} = hsl_to_rgb(h, s, l)
      fg = Color.rgb(r, g, b)

      fill = Map.get(@fill_chars, min(brick.hits, 3), "░")

      # Draw brick: ▐██▌
      chars = "▐" <> String.duplicate(fill, @brick_width - 2) <> "▌"

      chars
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.reduce(c, fn {char, i}, acc ->
        px = bx + i
        py = by

        if px >= 0 and px < acc.width and py >= 0 and py < acc.height do
          Canvas.set_cell(acc, px, py, char, fg, @bg)
        else
          acc
        end
      end)
    end)
  end

  defp draw_paddle(canvas, state, sx, sy) do
    paddle_glow = Timeline.value(state.timeline, :paddle_glow)
    px = trunc(state.paddle_x) + sx
    py = state.paddle_y + sy

    brightness = trunc(180 * paddle_glow) |> min(255)
    fg = Color.rgb(brightness, brightness, 255)

    @paddle_chars
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(canvas, fn {char, i}, c ->
      x = px + i
      if x >= 0 and x < c.width and py >= 0 and py < c.height do
        Canvas.set_cell(c, x, py, char, fg, @bg)
      else
        c
      end
    end)
  end

  defp draw_ball(canvas, %{phase: :title}, _w, _h, _sx, _sy), do: canvas
  defp draw_ball(canvas, %{phase: :game_over}, _w, _h, _sx, _sy), do: canvas

  defp draw_ball(canvas, state, w, h, sx, sy) do
    bx = trunc(state.ball_x) + sx
    by = trunc(state.ball_y) + sy

    if bx >= 0 and bx < w and by >= 0 and by < h do
      Canvas.set_cell(canvas, bx, by, @ball_char, Color.rgb(255, 255, 255), @bg)
    else
      canvas
    end
  end

  defp draw_trail(canvas, trail, w, h, sx, sy) do
    Enum.reduce(trail, canvas, fn t, c ->
      tx = trunc(t.x) + sx
      ty = trunc(t.y) + sy

      if tx >= 0 and tx < w and ty >= 0 and ty < h do
        life_ratio = t.life / t.max_life
        brightness = trunc(120 * life_ratio) |> max(0) |> min(255)
        fg = Color.rgb(brightness, brightness, min(255, brightness + 80))
        Canvas.set_cell(c, tx, ty, "·", fg, @bg)
      else
        c
      end
    end)
  end

  defp draw_particles(canvas, particles, w, h, sx, sy) do
    Enum.reduce(particles, canvas, fn p, c ->
      px = trunc(p.x) + sx
      py = trunc(p.y) + sy

      if px >= 0 and px < w and py >= 0 and py < h do
        life_ratio = p.life / p.max_life
        {pr, pg, pb} = hsl_to_rgb(p.hue, 0.8, max(0.2, 0.6 * life_ratio))
        brightness = trunc(200 * life_ratio) |> max(0) |> min(255)
        fg = Color.rgb(max(pr, brightness), pg, pb)
        Canvas.set_cell(c, px, py, p.char, fg, @bg)
      else
        c
      end
    end)
  end

  defp draw_overlay(canvas, %{phase: :title}, w, h) do
    # Draw "BREAKOUT" title centered
    title = "B R E A K O U T"
    subtitle = "Press SPACE to start"
    tx = max(0, div(w - String.length(title), 2))
    ty = div(h, 2) - 1
    stx = max(0, div(w - String.length(subtitle), 2))

    canvas
    |> Canvas.draw_text(tx, ty, title, Color.rgb(255, 200, 50), @bg)
    |> Canvas.draw_text(stx, ty + 2, subtitle, Color.rgb(150, 150, 180), @bg)
  end

  defp draw_overlay(canvas, %{phase: :paused}, w, h) do
    label = "PAUSED"
    tx = max(0, div(w - String.length(label), 2))
    ty = div(h, 2)
    Canvas.draw_text(canvas, tx, ty, label, Color.rgb(255, 255, 100), @bg)
  end

  defp draw_overlay(canvas, %{phase: :game_over} = state, w, h) do
    label1 = "GAME OVER"
    label2 = "Score: #{state.score}"
    t1x = max(0, div(w - String.length(label1), 2))
    t2x = max(0, div(w - String.length(label2), 2))
    ty = div(h, 2) - 1

    canvas
    |> Canvas.draw_text(t1x, ty, label1, Color.rgb(255, 60, 60), @bg)
    |> Canvas.draw_text(t2x, ty + 2, label2, Color.rgb(200, 200, 220), @bg)
  end

  defp draw_overlay(canvas, %{phase: :level_complete} = state, w, h) do
    label = "LEVEL #{state.level} COMPLETE!"
    tx = max(0, div(w - String.length(label), 2))
    ty = div(h, 2)
    Canvas.draw_text(canvas, tx, ty, label, Color.rgb(100, 255, 100), @bg)
  end

  defp draw_overlay(canvas, _state, _w, _h), do: canvas

  # ── Brick generation ──────────────────────────────────────────────

  defp setup_level(state) do
    bricks = generate_bricks(state.canvas_w, state.level)
    ball_speed = min(@ball_max_speed, @ball_base_speed + @ball_speed_per_level * (state.level - 1))
    %{state | bricks: bricks, ball_speed: ball_speed}
  end

  defp generate_bricks(canvas_w, level) do
    num_rows = min(8, 3 + level)
    usable_w = canvas_w - @brick_left_margin * 2
    bricks_per_row = div(usable_w, @brick_width)

    for row <- 0..(num_rows - 1), col <- 0..(bricks_per_row - 1) do
      x = @brick_left_margin + col * @brick_width
      y = @brick_top_margin + row

      color_idx = rem(row, length(@row_colors))
      color = Enum.at(@row_colors, color_idx)

      # Higher rows (top) get more hits at higher levels
      hits =
        cond do
          level >= 5 and row <= 1 -> 3
          level >= 3 and row <= 2 -> 2
          level >= 2 and row == 0 -> 2
          true -> 1
        end

      # Top rows worth more points
      points = (num_rows - row) * 10

      %{x: x, y: y, hits: hits, color: color, points: points, row: row}
    end
  end

  # ── Paddle movement (velocity-based) ─────────────────────────────

  defp apply_paddle_movement(state, dt) do
    if state.paddle_dir != :none and
       state.elapsed - state.paddle_input_time < @paddle_input_timeout do
      case state.paddle_dir do
        :left -> max(0.0, state.paddle_x - @paddle_speed * dt / 1000.0)
        :right -> min(state.canvas_w - @paddle_width + 0.0, state.paddle_x + @paddle_speed * dt / 1000.0)
        :none -> state.paddle_x
      end
    else
      state.paddle_x
    end
  end

  # ── Ball placement ────────────────────────────────────────────────

  defp place_ball_on_paddle(state) do
    bx = state.paddle_x + @paddle_width / 2.0
    by = state.paddle_y - 1.0

    %{state | ball_x: bx, ball_y: by, ball_vx: 0.0, ball_vy: 0.0}
  end

  # ── Paddle-ball collision ─────────────────────────────────────────

  defp check_paddle_collision(bx, by, vx, vy, paddle_x, paddle_y, ball_speed) do
    # Only check when ball is moving downward
    if vy > 0 and by >= paddle_y - 0.5 and by <= paddle_y + 0.5 and
       bx >= paddle_x and bx <= paddle_x + @paddle_width do
      # Hit offset from paddle center: -1.0 to 1.0
      center = paddle_x + @paddle_width / 2.0
      offset = (bx - center) / (@paddle_width / 2.0)
      offset = max(-1.0, min(1.0, offset))

      # Reflect angle: -75 to +75 degrees from vertical
      angle_deg = offset * @max_launch_angle
      angle = (angle_deg - 90.0) * :math.pi() / 180.0

      new_vx = :math.cos(angle) * ball_speed * @aspect_ratio
      new_vy = :math.sin(angle) * ball_speed
      new_by = paddle_y - 1.0

      # Paddle hit particles (fan upward)
      particles = spawn_paddle_particles(trunc(bx), paddle_y)

      {new_vx, new_vy, new_by, particles}
    else
      {vx, vy, by, []}
    end
  end

  # ── Brick collision ───────────────────────────────────────────────

  defp check_brick_collisions(bricks, bx, by, vx, vy, _prev_bx, _prev_by, _timeline) do
    # Check each brick for AABB collision with the ball
    {remaining, new_vx, new_vy, new_bx, new_by, total_score, all_particles, hits} =
      Enum.reduce(bricks, {[], vx, vy, bx, by, 0, [], 0},
        fn brick, {kept, cvx, cvy, cbx, cby, sc, parts, hit_count} ->
          if aabb_hit?(cbx, cby, brick) do
            # Determine reflection direction based on overlap
            {rvx, rvy, rbx, rby} = reflect_ball_off_brick(cbx, cby, cvx, cvy, brick)

            new_hits = brick.hits - 1

            if new_hits <= 0 do
              # Brick destroyed
              new_particles = spawn_brick_break_particles(brick)
              {kept, rvx, rvy, rbx, rby,
               sc + brick.points, parts ++ new_particles, hit_count + 1}
            else
              # Brick damaged
              spark_particles = spawn_brick_spark_particles(brick)
              {[%{brick | hits: new_hits} | kept], rvx, rvy, rbx, rby,
               sc + 5, parts ++ spark_particles, hit_count + 1}
            end
          else
            {[brick | kept], cvx, cvy, cbx, cby, sc, parts, hit_count}
          end
        end)

    {Enum.reverse(remaining), new_vx, new_vy, new_bx, new_by, total_score, all_particles, hits}
  end

  defp aabb_hit?(bx, by, brick) do
    bx >= brick.x - 0.5 and bx <= brick.x + @brick_width - 0.5 and
      by >= brick.y - 0.5 and by <= brick.y + @brick_height - 0.5
  end

  # Reflect ball off brick based on penetration depth from each side.
  # The axis with least penetration is the collision face.
  defp reflect_ball_off_brick(bx, by, vx, vy, brick) do
    # Distances from ball center to each brick edge
    left_pen = bx - (brick.x - 0.5)
    right_pen = (brick.x + @brick_width - 0.5) - bx
    top_pen = by - (brick.y - 0.5)
    bottom_pen = (brick.y + @brick_height - 0.5) - by

    min_x = min(left_pen, right_pen)
    min_y = min(top_pen, bottom_pen)

    if min_x < min_y do
      # Horizontal collision face
      new_vx = -vx
      new_bx = if left_pen < right_pen, do: brick.x - 0.6, else: brick.x + @brick_width - 0.4
      {new_vx, vy, new_bx, by}
    else
      # Vertical collision face
      new_vy = -vy
      new_by = if top_pen < bottom_pen, do: brick.y - 0.6, else: brick.y + @brick_height - 0.4
      {vx, new_vy, bx, new_by}
    end
  end

  # ── Particles ─────────────────────────────────────────────────────

  defp spawn_brick_break_particles(brick) do
    cx = brick.x + @brick_width / 2.0
    cy = brick.y + 0.0
    {base_h, _s, _l} = brick.color

    for _ <- 1..7 do
      angle = :rand.uniform() * :math.pi() * 2
      speed = 2.0 + :rand.uniform() * 5.0

      %{
        x: cx, y: cy,
        vx: :math.cos(angle) * speed * @aspect_ratio,
        vy: :math.sin(angle) * speed,
        life: 300.0 + :rand.uniform() * 300.0,
        max_life: 600.0,
        hue: base_h + (:rand.uniform() - 0.5) * 40.0,
        char: Enum.random(["*", "●", "◆", "▓", "░"])
      }
    end
  end

  defp spawn_brick_spark_particles(brick) do
    cx = brick.x + @brick_width / 2.0
    cy = brick.y + 0.0
    {base_h, _s, _l} = brick.color

    for _ <- 1..3 do
      angle = :rand.uniform() * :math.pi() * 2
      speed = 1.0 + :rand.uniform() * 3.0

      %{
        x: cx, y: cy,
        vx: :math.cos(angle) * speed * @aspect_ratio,
        vy: :math.sin(angle) * speed,
        life: 150.0 + :rand.uniform() * 150.0,
        max_life: 300.0,
        hue: base_h + 30.0,
        char: Enum.random(["·", "∙", "*"])
      }
    end
  end

  defp spawn_paddle_particles(cx, cy) do
    for _ <- 1..4 do
      spread = (:rand.uniform() - 0.5) * 4.0

      %{
        x: cx + spread,
        y: cy + 0.0,
        vx: spread * 1.5,
        vy: -(2.0 + :rand.uniform() * 3.0),
        life: 200.0 + :rand.uniform() * 200.0,
        max_life: 400.0,
        hue: 210.0 + (:rand.uniform() - 0.5) * 40.0,
        char: Enum.random(["·", "∙", "░"])
      }
    end
  end

  defp spawn_explosion(cx, cy, base_hue, count) do
    for _ <- 1..count do
      angle = :rand.uniform() * :math.pi() * 2
      speed = 2.0 + :rand.uniform() * 6.0

      %{
        x: cx + 0.0,
        y: cy + 0.0,
        vx: :math.cos(angle) * speed * @aspect_ratio,
        vy: :math.sin(angle) * speed,
        life: 400.0 + :rand.uniform() * 400.0,
        max_life: 800.0,
        hue: base_hue + (:rand.uniform() - 0.5) * 60.0,
        char: Enum.random(["*", "●", "◆", "#", "▓", "░"])
      }
    end
  end

  defp spawn_level_clear_particles(w, h) do
    for _ <- 1..20 do
      %{
        x: :rand.uniform(w) + 0.0,
        y: :rand.uniform(div(h, 2)) + 0.0,
        vx: (:rand.uniform() - 0.5) * 8.0,
        vy: 1.0 + :rand.uniform() * 4.0,
        life: 500.0 + :rand.uniform() * 500.0,
        max_life: 1000.0,
        hue: :rand.uniform(360) + 0.0,
        char: Enum.random(["*", "●", "◆", "★", "♦"])
      }
    end
  end

  defp move_particles(particles, dt) do
    particles
    |> Enum.map(fn p ->
      %{p | x: p.x + p.vx * dt / 1000.0, y: p.y + p.vy * dt / 1000.0, life: p.life - dt}
    end)
    |> Enum.filter(fn p -> p.life > 0.0 end)
  end

  defp move_trail(trail, dt) do
    trail
    |> Enum.map(fn t -> %{t | life: t.life - dt} end)
    |> Enum.filter(fn t -> t.life > 0.0 end)
  end

  # ── Shake ─────────────────────────────────────────────────────────

  defp advance_shake(nil, _dt), do: {nil, 0, 0}

  defp advance_shake(shake_tl, dt) do
    tl = Timeline.advance(shake_tl, dt)
    magnitude = Timeline.value(tl, :shake)

    sx = trunc((:rand.uniform() - 0.5) * 2 * magnitude)
    sy = trunc((:rand.uniform() - 0.5) * 2 * magnitude)
    {tl, sx, sy}
  end

  # ── FPS tracking ──────────────────────────────────────────────────

  defp update_fps(state, dt) do
    elapsed = state.elapsed + dt
    frame_ms = state.frame_ms * 0.9 + dt * 0.1
    frame_count = state.fps_frame_count + 1

    {fps, frame_count, fps_last_time} =
      if elapsed - state.fps_last_time >= 1000.0 do
        {frame_count, 0, elapsed}
      else
        {state.fps, frame_count, state.fps_last_time}
      end

    %{state |
      elapsed: elapsed,
      frame_ms: frame_ms,
      fps: fps,
      fps_frame_count: frame_count,
      fps_last_time: fps_last_time}
  end

  # ── Game flow ─────────────────────────────────────────────────────

  defp restart_game(state) do
    %{state |
      phase: :serving,
      level: 1,
      lives: 3,
      score: 0,
      combo: 0,
      combo_timer: 0.0,
      paddle_x: state.canvas_w / 2.0 - @paddle_width / 2.0,
      paddle_dir: :none,
      paddle_input_time: 0.0,
      particles: [],
      trail: [],
      timeline: build_main_timeline(),
      shake_timeline: nil,
      shake_x: 0,
      shake_y: 0,
      elapsed: 0.0,
      fps: 0,
      fps_frame_count: 0,
      fps_last_time: 0.0}
    |> setup_level()
    |> place_ball_on_paddle()
  end

  # ── Color helpers ─────────────────────────────────────────────────

  defp hsl_to_rgb(h, s, l) do
    h = h / 1.0
    h = h - Float.floor(h / 360.0) * 360.0
    c = (1.0 - abs(2.0 * l - 1.0)) * s
    x = c * (1.0 - abs(rem_float(h / 60.0, 2.0) - 1.0))
    m = l - c / 2.0

    {r1, g1, b1} =
      cond do
        h < 60 -> {c, x, 0.0}
        h < 120 -> {x, c, 0.0}
        h < 180 -> {0.0, c, x}
        h < 240 -> {0.0, x, c}
        h < 300 -> {x, 0.0, c}
        true -> {c, 0.0, x}
      end

    {
      trunc((r1 + m) * 255) |> max(0) |> min(255),
      trunc((g1 + m) * 255) |> max(0) |> min(255),
      trunc((b1 + m) * 255) |> max(0) |> min(255)
    }
  end

  defp rem_float(a, b) do
    a - Float.floor(a / b) * b
  end
end

ElixirOpentui.Demo.DemoRunner.run(Breakout)
