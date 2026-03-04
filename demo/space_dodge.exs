# Space Dodge — Vertical-scrolling asteroid dodger
# Run: mix run demo/space_dodge.exs
#
# A 60 FPS arcade game showcasing Canvas pixel drawing, ASCIIFont HUD,
# Timeline animations, color cycling, parallax starfield, and particle effects.
# Arrow keys / WASD / HJKL to move, Space to restart, Q to quit.

defmodule SpaceDodge do
  alias ElixirOpentui.Animation.Timeline
  alias ElixirOpentui.{Canvas, Color, ASCIIFont}

  # --- Ship shape (5 wide × 3 tall) ---
  @ship [
    {2, 0, "▲"},
    {1, 1, "◄"}, {2, 1, "█"}, {3, 1, "►"},
    {0, 2, "╚"}, {1, 2, "▓"}, {2, 2, "▓"}, {3, 2, "▓"}, {4, 2, "╝"}
  ]
  @ship_width 5
  @ship_height 3

  # --- Asteroid shapes ---
  @asteroid_small ["@", "◆", "●", "#"]

  @asteroid_medium [
    [{0, 0, "▓"}, {1, 0, "▒"}, {0, 1, "▒"}, {1, 1, "▓"}],
    [{0, 0, "◆"}, {1, 0, "#"}, {0, 1, "#"}, {1, 1, "◆"}],
    [{0, 0, "░"}, {1, 0, "▓"}, {0, 1, "▓"}, {1, 1, "░"}]
  ]

  @asteroid_large [
    [
      {0, 0, "░"}, {1, 0, "▓"}, {2, 0, "░"},
      {0, 1, "▓"}, {1, 1, "█"}, {2, 1, "▓"},
      {0, 2, "░"}, {1, 2, "▓"}, {2, 2, "░"}
    ],
    [
      {1, 0, "▒"},
      {0, 1, "▒"}, {1, 1, "▓"}, {2, 1, "▒"},
      {1, 2, "▒"}
    ],
    [
      {0, 0, "#"}, {1, 0, "▓"}, {2, 0, "#"},
      {0, 1, "▓"}, {1, 1, "◆"}, {2, 1, "▓"},
      {0, 2, "#"}, {1, 2, "▓"}, {2, 2, "#"}
    ]
  ]

  @star_count 80
  @space_bg Color.rgb(5, 5, 15)

  # --- init ---

  def init(cols, rows) do
    canvas_w = max(20, cols - 6)
    canvas_h = max(10, rows - 8)

    %{
      cols: cols,
      rows: rows,
      canvas_w: canvas_w,
      canvas_h: canvas_h,
      phase: :playing,
      player_x: canvas_w / 2.0 - 2.5,
      player_y: canvas_h - 4.0,
      asteroids: [],
      particles: [],
      stars: generate_stars(canvas_w, canvas_h),
      score: 0,
      high_score: 0,
      elapsed: 0.0,
      speed_mult: 1.0,
      spawn_timer: 0.0,
      spawn_interval: 800.0,
      timeline: build_main_timeline(),
      shake_timeline: nil,
      shake_x: 0,
      shake_y: 0,
      fps: 0,
      fps_frame_count: 0,
      fps_last_time: 0.0,
      frame_ms: 16.0,
      _live: true,
      _tick_interval: 16
    }
  end

  defp build_main_timeline do
    Timeline.new(duration: 2000, loop: true, alternate: true)
    |> Timeline.add(:engine_hue, from: 15.0, to: 60.0, easing: :linear)
    |> Timeline.add(:engine_pulse, from: 0.6, to: 1.0, easing: :in_out_sine)
    |> Timeline.add(:score_hue, from: 120.0, to: 180.0, easing: :linear)
    |> Timeline.play()
  end

  # --- handle_event ---

  def handle_event(%{type: :key, key: "c", ctrl: true, meta: false}, _state), do: :quit
  def handle_event(%{type: :key, key: "q", meta: false}, _state), do: :quit

  def handle_event(%{type: :key, key: " ", meta: false}, %{phase: :game_over} = state) do
    {:cont, restart_game(state)}
  end

  def handle_event(%{type: :key, key: key, meta: false}, %{phase: :playing} = state)
      when key in [:left, "a", "h"] do
    new_x = max(0.0, state.player_x - 1.5)
    {:cont, %{state | player_x: new_x}}
  end

  def handle_event(%{type: :key, key: key, meta: false}, %{phase: :playing} = state)
      when key in [:right, "d", "l"] do
    new_x = min(state.canvas_w - @ship_width + 0.0, state.player_x + 1.5)
    {:cont, %{state | player_x: new_x}}
  end

  def handle_event(%{type: :key, key: key, meta: false}, %{phase: :playing} = state)
      when key in [:up, "w", "k"] do
    min_y = max(0.0, state.canvas_h - 10.0)
    new_y = max(min_y, state.player_y - 1.0)
    {:cont, %{state | player_y: new_y}}
  end

  def handle_event(%{type: :key, key: key, meta: false}, %{phase: :playing} = state)
      when key in [:down, "s", "j"] do
    new_y = min(state.canvas_h - @ship_height + 0.0, state.player_y + 1.0)
    {:cont, %{state | player_y: new_y}}
  end

  def handle_event(_event, state), do: {:cont, state}

  # --- handle_tick ---

  def handle_tick(dt, %{phase: :game_over} = state) do
    # Only advance shake + particles during game over
    {shake_tl, sx, sy} = advance_shake(state.shake_timeline, dt)
    particles = move_particles(state.particles, dt)

    {:cont,
     %{state | shake_timeline: shake_tl, shake_x: sx, shake_y: sy, particles: particles}}
  end

  def handle_tick(dt, state) do
    elapsed = state.elapsed + dt
    tl = Timeline.advance(state.timeline, dt)

    # FPS counter + smoothed frame time (EMA: 90% old + 10% new)
    frame_ms = state.frame_ms * 0.9 + dt * 0.1
    frame_count = state.fps_frame_count + 1

    {fps, frame_count, fps_last_time} =
      if elapsed - state.fps_last_time >= 1000.0 do
        {frame_count, 0, elapsed}
      else
        {state.fps, frame_count, state.fps_last_time}
      end

    # Difficulty ramp
    speed_mult = 1.0 + elapsed / 30_000.0
    spawn_interval = max(200.0, 800.0 - elapsed / 100.0)

    # Spawn asteroids
    spawn_timer = state.spawn_timer - dt

    {asteroids, spawn_timer} =
      if spawn_timer <= 0.0 do
        ast = spawn_asteroid(state.canvas_w)
        {[ast | state.asteroids], spawn_interval}
      else
        {state.asteroids, spawn_timer}
      end

    # Move asteroids
    asteroids = move_asteroids(asteroids, dt, speed_mult, state.canvas_h)

    # Move particles + spawn exhaust
    particles = move_particles(state.particles, dt)
    engine_hue = Timeline.value(tl, :engine_hue)
    px = trunc(state.player_x) + 2
    py = trunc(state.player_y) + @ship_height
    particles = spawn_exhaust(particles, px, py, engine_hue)

    # Score
    score = state.score + max(1, trunc(dt / 16.0))

    # Collision
    if check_collision(state.player_x, state.player_y, asteroids) do
      explosion = spawn_explosion([], px, trunc(state.player_y) + 1)

      shake_tl =
        Timeline.new(duration: 600)
        |> Timeline.add(:shake, from: 6.0, to: 0.0, easing: :out_expo)
        |> Timeline.play()

      {:cont,
       %{
         state
         | phase: :game_over,
           elapsed: elapsed,
           timeline: tl,
           asteroids: asteroids,
           particles: explosion,
           score: score,
           high_score: max(state.high_score, score),
           speed_mult: speed_mult,
           spawn_interval: spawn_interval,
           spawn_timer: spawn_timer,
           shake_timeline: shake_tl,
           shake_x: 0,
           shake_y: 0,
           fps: fps,
           fps_frame_count: frame_count,
           fps_last_time: fps_last_time,
           frame_ms: frame_ms
       }}
    else
      {:cont,
       %{
         state
         | elapsed: elapsed,
           timeline: tl,
           asteroids: asteroids,
           particles: particles,
           score: score,
           speed_mult: speed_mult,
           spawn_interval: spawn_interval,
           spawn_timer: spawn_timer,
           fps: fps,
           fps_frame_count: frame_count,
           fps_last_time: fps_last_time,
           frame_ms: frame_ms
       }}
    end
  end

  # --- render ---

  def render(state) do
    import ElixirOpentui.View

    canvas = build_canvas(state)

    score_hue = Timeline.value(state.timeline, :score_hue)
    score_fg = Color.hsl(score_hue, 0.8, 0.65)

    speed_label = Float.round(state.speed_mult, 1)
    dim_fg = Color.rgb(80, 80, 100)
    panel_fg = Color.rgb(60, 80, 120)

    # FPS color: green when >=50, yellow 30-49, red <30
    fps_fg =
      cond do
        state.fps >= 50 -> Color.rgb(80, 255, 80)
        state.fps >= 30 -> Color.rgb(255, 220, 60)
        true -> Color.rgb(255, 70, 70)
      end

    frame_ms_label = Float.round(state.frame_ms, 1)

    score_text = "#{state.score}"
    info_text = "SPD:#{speed_label}  HI:#{state.high_score}"
    fps_text = "#{state.fps} FPS  #{frame_ms_label}ms"

    panel_w = min(state.cols - 2, state.canvas_w + 4)
    font = :tiny
    font_h = ASCIIFont.font_height(font)

    # Total height: border(1) + ascii_font + spacer(1) + canvas + footer(1) + border(1)
    panel_h = min(state.rows - 1, font_h + 1 + state.canvas_h + 1 + 2)

    footer =
      if state.phase == :game_over do
        "GAME OVER! Score:#{state.score}  High:#{state.high_score}  [SPC]=Retry [Q]=Quit"
      else
        "←↑↓→ / WASD / HJKL=move  [Q]=quit"
      end

    panel id: :main, title: " SPACE DODGE ", width: panel_w, height: panel_h,
          border: true, border_style: :rounded, bg: @space_bg, fg: panel_fg do
      box height: font_h + 1, direction: :row, padding: {0, 1, 0, 1} do
        ascii_font(
          text: score_text,
          font: font,
          fg: score_fg,
          bg: @space_bg
        )

        box(flex_grow: 1)
        text(content: fps_text <> "  ", fg: fps_fg, bg: @space_bg)
        text(content: info_text, fg: dim_fg, bg: @space_bg)
      end

      box height: state.canvas_h, padding: {0, 1, 0, 1} do
        frame_buffer(buffer: canvas, width: state.canvas_w, height: state.canvas_h)
      end

      text(content: footer, fg: dim_fg, bg: @space_bg)
    end
  end

  def focused_id(_state), do: nil

  # --- Canvas rendering ---

  defp build_canvas(state) do
    w = state.canvas_w
    h = state.canvas_h
    sx = state.shake_x
    sy = state.shake_y

    Canvas.new(w, h)
    |> draw_stars(state.stars, state.elapsed, w, h, sx, sy)
    |> draw_asteroids(state.asteroids, sx, sy)
    |> draw_particles(state.particles, w, h, sx, sy)
    |> draw_ship(state, sx, sy)
  end

  defp draw_stars(canvas, stars, elapsed, w, h, sx, sy) do
    Enum.reduce(stars, canvas, fn star, c ->
      # Parallax scroll speed by depth
      scroll_speed =
        case star.depth do
          1 -> 0.5
          2 -> 1.5
          _ -> 3.0
        end

      y = rem_float(star.y + elapsed * scroll_speed / 1000.0, h + 0.0)
      x = star.x + sx
      y_draw = trunc(y) + sy

      if x >= 0 and x < w and y_draw >= 0 and y_draw < h do
        brightness =
          (:math.sin(elapsed * star.freq + star.phase) * 0.5 + 0.5)
          |> Kernel.*(star.base_brightness)
          |> trunc()
          |> max(20)
          |> min(255)

        # Dimmer for far stars
        brightness =
          case star.depth do
            1 -> div(brightness, 3)
            2 -> div(brightness * 2, 3)
            _ -> brightness
          end

        char =
          case star.depth do
            1 -> "."
            2 -> "*"
            _ -> "+"
          end

        fg = Color.rgb(brightness, brightness, min(255, brightness + 30))
        Canvas.set_cell(c, trunc(x), y_draw, char, fg, @space_bg)
      else
        c
      end
    end)
  end

  defp draw_asteroids(canvas, asteroids, sx, sy) do
    Enum.reduce(asteroids, canvas, fn ast, c ->
      fg = Color.hsl(ast.hue, 0.5, 0.45)
      ax = trunc(ast.x) + sx
      ay = trunc(ast.y) + sy

      case ast.size do
        :small ->
          if ax >= 0 and ax < c.width and ay >= 0 and ay < c.height do
            char = Enum.at(@asteroid_small, ast.shape_idx)
            Canvas.set_cell(c, ax, ay, char, fg, @space_bg)
          else
            c
          end

        :medium ->
          shape = Enum.at(@asteroid_medium, ast.shape_idx)
          draw_shape(c, shape, ax, ay, fg)

        :large ->
          shape = Enum.at(@asteroid_large, ast.shape_idx)
          draw_shape(c, shape, ax, ay, fg)
      end
    end)
  end

  defp draw_shape(canvas, shape, base_x, base_y, fg) do
    Enum.reduce(shape, canvas, fn {dx, dy, char}, c ->
      px = base_x + dx
      py = base_y + dy

      if px >= 0 and px < c.width and py >= 0 and py < c.height do
        Canvas.set_cell(c, px, py, char, fg, @space_bg)
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
        brightness = trunc(p.base_brightness * life_ratio) |> max(0) |> min(255)
        {pr, pg, pb, _} = Color.hsl(p.hue, 0.8, max(0.2, 0.6 * life_ratio))
        fg = Color.rgb(max(pr, brightness), pg, pb)
        Canvas.set_cell(c, px, py, p.char, fg, @space_bg)
      else
        c
      end
    end)
  end

  defp draw_ship(canvas, %{phase: :game_over}, _sx, _sy), do: canvas

  defp draw_ship(canvas, state, sx, sy) do
    engine_hue = Timeline.value(state.timeline, :engine_hue)
    engine_pulse = Timeline.value(state.timeline, :engine_pulse)

    base_x = trunc(state.player_x) + sx
    base_y = trunc(state.player_y) + sy

    Enum.reduce(@ship, canvas, fn {dx, dy, char}, c ->
      px = base_x + dx
      py = base_y + dy

      if px >= 0 and px < c.width and py >= 0 and py < c.height do
        fg =
          cond do
            # Engine row (bottom) — animated color
            dy == 2 ->
              b = trunc(200 * engine_pulse) |> min(255)
              {er, eg, eb, _} = Color.hsl(engine_hue, 0.9, 0.55)
              Color.rgb(max(er, b), eg, eb)

            # Cockpit (top) — bright cyan
            dy == 0 ->
              Color.rgb(100, 220, 255)

            # Body — white/silver
            true ->
              Color.rgb(200, 210, 220)
          end

        Canvas.set_cell(c, px, py, char, fg, @space_bg)
      else
        c
      end
    end)
  end

  # --- Entity helpers ---

  defp generate_stars(w, h) do
    for _ <- 1..@star_count do
      %{
        x: :rand.uniform(w) - 1,
        y: :rand.uniform() * h,
        depth: weighted_random([{1, 40}, {2, 35}, {3, 25}]),
        phase: :rand.uniform() * :math.pi() * 2,
        freq: 0.001 + :rand.uniform() * 0.003,
        base_brightness: 100 + :rand.uniform(155)
      }
    end
  end

  defp spawn_asteroid(canvas_w) do
    size = weighted_random([{:small, 60}, {:medium, 30}, {:large, 10}])

    shape_count =
      case size do
        :small -> length(@asteroid_small)
        :medium -> length(@asteroid_medium)
        :large -> length(@asteroid_large)
      end

    ast_w =
      case size do
        :small -> 1
        :medium -> 2
        :large -> 3
      end

    %{
      x: :rand.uniform(max(1, canvas_w - ast_w)) - 1 + 0.0,
      y: -3.0,
      size: size,
      hue: :rand.uniform(360) + 0.0,
      shape_idx: :rand.uniform(shape_count) - 1
    }
  end

  defp spawn_exhaust(particles, px, py, engine_hue) do
    new =
      for _ <- 1..2 do
        %{
          x: px + (:rand.uniform() - 0.5) * 2.0,
          y: py + 0.0,
          vx: (:rand.uniform() - 0.5) * 1.5,
          vy: 3.0 + :rand.uniform() * 2.0,
          life: 300.0 + :rand.uniform() * 200.0,
          max_life: 500.0,
          hue: engine_hue + (:rand.uniform() - 0.5) * 30.0,
          base_brightness: 180 + :rand.uniform(75),
          char: Enum.random(["·", ".", "∙", "░"])
        }
      end

    new ++ particles
  end

  defp spawn_explosion(particles, cx, cy) do
    new =
      for _ <- 1..25 do
        angle = :rand.uniform() * :math.pi() * 2
        speed = 2.0 + :rand.uniform() * 6.0

        %{
          x: cx + 0.0,
          y: cy + 0.0,
          vx: :math.cos(angle) * speed,
          vy: :math.sin(angle) * speed,
          life: 400.0 + :rand.uniform() * 400.0,
          max_life: 800.0,
          hue: Enum.random([0.0, 15.0, 30.0, 45.0, 60.0]),
          base_brightness: 200 + :rand.uniform(55),
          char: Enum.random(["*", "●", "◆", "#", "▓", "░"])
        }
      end

    new ++ particles
  end

  defp move_asteroids(asteroids, dt, speed_mult, canvas_h) do
    asteroids
    |> Enum.map(fn ast ->
      base_speed = asteroid_base_speed(ast.size)
      %{ast | y: ast.y + base_speed * speed_mult * dt / 1000.0}
    end)
    |> Enum.filter(fn ast -> ast.y < canvas_h + 4.0 end)
  end

  defp move_particles(particles, dt) do
    particles
    |> Enum.map(fn p ->
      %{p | x: p.x + p.vx * dt / 1000.0, y: p.y + p.vy * dt / 1000.0, life: p.life - dt}
    end)
    |> Enum.filter(fn p -> p.life > 0.0 end)
  end

  defp check_collision(player_x, player_y, asteroids) do
    # Ship hitbox: center 3×3 area (offset 1,0 from player position)
    ship_left = player_x + 1.0
    ship_right = player_x + 4.0
    ship_top = player_y
    ship_bottom = player_y + @ship_height + 0.0

    Enum.any?(asteroids, fn ast ->
      ast_size =
        case ast.size do
          :small -> 1.0
          :medium -> 2.0
          :large -> 3.0
        end

      ast_left = ast.x
      ast_right = ast.x + ast_size
      ast_top = ast.y
      ast_bottom = ast.y + ast_size

      ship_left < ast_right and ship_right > ast_left and
        ship_top < ast_bottom and ship_bottom > ast_top
    end)
  end

  defp asteroid_base_speed(:small), do: 12.0
  defp asteroid_base_speed(:medium), do: 9.0
  defp asteroid_base_speed(:large), do: 7.0

  defp advance_shake(nil, _dt), do: {nil, 0, 0}

  defp advance_shake(shake_tl, dt) do
    tl = Timeline.advance(shake_tl, dt)
    magnitude = Timeline.value(tl, :shake)

    sx = trunc((:rand.uniform() - 0.5) * 2 * magnitude)
    sy = trunc((:rand.uniform() - 0.5) * 2 * magnitude)
    {tl, sx, sy}
  end

  defp restart_game(state) do
    %{
      state
      | phase: :playing,
        player_x: state.canvas_w / 2.0 - 2.5,
        player_y: state.canvas_h - 4.0,
        asteroids: [],
        particles: [],
        stars: generate_stars(state.canvas_w, state.canvas_h),
        score: 0,
        elapsed: 0.0,
        speed_mult: 1.0,
        spawn_timer: 0.0,
        spawn_interval: 800.0,
        timeline: build_main_timeline(),
        shake_timeline: nil,
        shake_x: 0,
        shake_y: 0
    }
  end

  defp weighted_random(options) do
    total = Enum.reduce(options, 0, fn {_, w}, acc -> acc + w end)
    roll = :rand.uniform(total)

    Enum.reduce_while(options, 0, fn {value, weight}, acc ->
      acc = acc + weight
      if roll <= acc, do: {:halt, value}, else: {:cont, acc}
    end)
  end

  # --- Helpers ---

  defp rem_float(a, b) do
    a - Float.floor(a / b) * b
  end
end

ElixirOpentui.Demo.DemoRunner.run(SpaceDodge)
