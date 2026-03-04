# Claude Animation Demo (NIF Pipeline)
# Run: mix run demo/claude_animation.exs
#
# Drives NativeBuffer directly to showcase the full NIF render pipeline:
#   NativeBuffer → batch binary protocol → Zig diff → ANSI → stdout

alias ElixirOpentui.{Color, NativeBuffer}

# --- Font: 7×7 pixel letters ---

font = %{
  ?C => [
    ~c"..####.",
    ~c"##.....",
    ~c"##.....",
    ~c"##.....",
    ~c"##.....",
    ~c"##.....",
    ~c"..####."
  ],
  ?L => [
    ~c"##.....",
    ~c"##.....",
    ~c"##.....",
    ~c"##.....",
    ~c"##.....",
    ~c"##.....",
    ~c"#######"
  ],
  ?A => [
    ~c"..###..",
    ~c".##.##.",
    ~c"##...##",
    ~c"#######",
    ~c"##...##",
    ~c"##...##",
    ~c"##...##"
  ],
  ?U => [
    ~c"##...##",
    ~c"##...##",
    ~c"##...##",
    ~c"##...##",
    ~c"##...##",
    ~c".##.##.",
    ~c"..###.."
  ],
  ?D => [
    ~c"#####..",
    ~c"##..##.",
    ~c"##...##",
    ~c"##...##",
    ~c"##...##",
    ~c"##..##.",
    ~c"#####.."
  ],
  ?E => [
    ~c"#######",
    ~c"##.....",
    ~c"##.....",
    ~c"####...",
    ~c"##.....",
    ~c"##.....",
    ~c"#######"
  ]
}

black = {0, 0, 0, 255}

# --- Terminal setup ---

# Save terminal state and enter raw mode
old_stty = String.trim(IO.chardata_to_string(:os.cmd(~c"stty -g < /dev/tty")))
:os.cmd(~c"stty raw -echo < /dev/tty")

# Alt screen, hide cursor, clear
IO.write("\e[?1049h\e[?25l\e[2J")

# Get terminal size
{cols_str, 0} = System.cmd("tput", ["cols"])
{rows_str, 0} = System.cmd("tput", ["lines"])
cols = String.trim(cols_str) |> String.to_integer()
rows = String.trim(rows_str) |> String.to_integer()

# --- Boot sequence ---

boot_lines = [
  {"> Initializing ElixirOpentui NIF renderer...", 300},
  {"> Zig FrameBuffer: #{cols}×#{rows} OK", 200},
  {"> Batch binary protocol: READY", 200},
  {"> ANSI diff engine: ARMED", 200}
]

boot_row = div(rows, 2) - 3

Enum.reduce(boot_lines, boot_row, fn {text, delay}, row ->
  IO.write("\e[#{row};3H\e[38;2;0;200;0m#{text}\e[0m")
  Process.sleep(delay)
  row + 1
end)

# Loading bar
bar_row = boot_row + length(boot_lines) + 1
bar_width = 40
IO.write("\e[#{bar_row};3H\e[38;2;0;200;0m[")
IO.write(String.duplicate(" ", bar_width))
IO.write("] 0%\e[0m")

for i <- 1..bar_width do
  IO.write("\e[#{bar_row};#{3 + i}H\e[38;2;0;255;0m█\e[0m")
  pct = trunc(i / bar_width * 100)
  IO.write("\e[#{bar_row};#{3 + bar_width + 2}H\e[38;2;0;200;0m#{pct}%  \e[0m")
  Process.sleep(trunc(800 / bar_width))
end

Process.sleep(300)

# --- Input reader process ---

parent = self()

input_pid =
  spawn_link(fn ->
    case :file.open(~c"/dev/tty", [:read, :raw, :binary]) do
      {:ok, tty} ->
        read_loop = fn read_loop ->
          case :file.read(tty, 1) do
            {:ok, <<byte>>} ->
              send(parent, {:input, byte})
              read_loop.(read_loop)

            _ ->
              :ok
          end
        end

        read_loop.(read_loop)

      {:error, reason} ->
        IO.write("\e[0m\e[?25h\e[?1049l")
        :os.cmd(String.to_charlist("stty #{old_stty} < /dev/tty"))
        IO.puts("\nFailed to open /dev/tty: #{reason}")
        IO.puts("This demo must be run in an interactive terminal.")
        System.halt(1)
    end
  end)

# --- Initialize NIF buffer ---

IO.write("\e[2J")
buf = NativeBuffer.new(cols, rows)

# --- Animation state ---

text = ~c"CLAUDE"
letter_w = 7
letter_gap = 2
text_total_w = length(text) * letter_w + (length(text) - 1) * letter_gap
text_x = div(cols - text_total_w, 2)
text_y = div(rows, 2) - 5

# Stars: {x, y, phase_offset, speed}
stars =
  for _ <- 1..60 do
    {Enum.random(0..(cols - 1)), Enum.random(0..(rows - 1)),
     :rand.uniform() * 6.28, 0.5 + :rand.uniform() * 2.0}
  end

# Particles: {x, y, vx, vy, hue, life, max_life}
initial_particles = []

tagline = "Terminal UI Framework"
tagline_x = div(cols - String.length(tagline), 2)
tagline_y = text_y + 9

sub_tagline = "Powered by Zig NIF"
sub_tagline_x = div(cols - String.length(sub_tagline), 2)
sub_tagline_y = tagline_y + 2

quit_text = "Press q to quit"
quit_x = div(cols - String.length(quit_text), 2)
quit_y = rows - 2

line_y = text_y + 8
line_x = text_x - 2
line_w = text_total_w + 4

# --- Animation loop ---

start_time = System.monotonic_time(:millisecond)

animate = fn animate, buf, frame, particles ->
  t = frame / 30.0
  elapsed_ms = System.monotonic_time(:millisecond) - start_time

  # Safety timeout: 120s
  if elapsed_ms > 120_000 do
    :timeout
  else
    # Check input
    quit? =
      receive do
        {:input, byte} when byte in [?q, ?Q, 27, 3] -> true
        {:input, _} -> false
      after
        0 -> false
      end

    if quit? do
      :quit
    else
      # Clear back buffer
      buf = NativeBuffer.clear(buf)

      # 1. Stars
      buf =
        Enum.reduce(stars, buf, fn {sx, sy, phase, speed}, buf ->
          brightness = (1.0 + :math.sin(t * speed + phase)) / 2.0
          fade_in = min(1.0, elapsed_ms / 1500.0)
          b = trunc(brightness * fade_in * 255)
          # Blue-tinted stars
          r = trunc(b * 0.8)
          g = trunc(b * 0.9)
          fg = {r, g, b, 255}

          char = if brightness > 0.7, do: "✦", else: "·"
          NativeBuffer.draw_char(buf, sx, sy, char, fg, black)
        end)

      # 2. Big CLAUDE text with rainbow + letter cascade
      buf =
        text
        |> Enum.with_index()
        |> Enum.reduce(buf, fn {letter, li}, buf ->
          letter_rows = Map.get(font, letter, [])
          lx = text_x + li * (letter_w + letter_gap)

          # Letter cascade: stagger reveal by 150ms per letter
          letter_age_ms = elapsed_ms - li * 150
          letter_opacity = max(0.0, min(1.0, letter_age_ms / 400))

          if letter_opacity <= 0.0 do
            buf
          else
            letter_rows
            |> Enum.with_index()
            |> Enum.reduce(buf, fn {row, ry}, buf ->
              row
              |> Enum.with_index()
              |> Enum.reduce(buf, fn {ch, rx}, buf ->
                if ch == ?# do
                  abs_x = lx + rx
                  hue = rem(trunc(abs_x * 8 + t * 60), 360)
                  {r, g, b, _} = Color.hsl(hue, 1.0, 0.55)

                  # Apply letter opacity
                  r = trunc(r * letter_opacity)
                  g = trunc(g * letter_opacity)
                  b = trunc(b * letter_opacity)

                  # Shimmer: white highlight every ~5s
                  shimmer_phase = :math.sin(t * 1.2 - abs_x * 0.3)
                  {r, g, b} =
                    if shimmer_phase > 0.92 do
                      blend = (shimmer_phase - 0.92) / 0.08
                      {trunc(r + (255 - r) * blend),
                       trunc(g + (255 - g) * blend),
                       trunc(b + (255 - b) * blend)}
                    else
                      {r, g, b}
                    end

                  fg = {min(255, r), min(255, g), min(255, b), 255}
                  NativeBuffer.draw_char(buf, abs_x, text_y + ry, "█", fg, black)
                else
                  buf
                end
              end)
            end)
          end
        end)

      # 3. Particles: spawn from text area, float up
      particles =
        if rem(frame, 3) == 0 and length(particles) < 30 do
          px = text_x + Enum.random(0..(text_total_w - 1))
          py = text_y + Enum.random(0..6)
          hue = rem(trunc(px * 8 + t * 60), 360)
          max_life = 20 + Enum.random(0..20)
          [{px * 1.0, py * 1.0, (:rand.uniform() - 0.5) * 0.8, -0.3 - :rand.uniform() * 0.5,
            hue, max_life, max_life} | particles]
        else
          particles
        end

      particles =
        particles
        |> Enum.map(fn {px, py, vx, vy, hue, life, max_life} ->
          {px + vx, py + vy, vx, vy, hue, life - 1, max_life}
        end)
        |> Enum.filter(fn {_, _, _, _, _, life, _} -> life > 0 end)

      buf =
        Enum.reduce(particles, buf, fn {px, py, _, _, hue, life, max_life}, buf ->
          ix = trunc(px)
          iy = trunc(py)

          if ix >= 0 and ix < cols and iy >= 0 and iy < rows do
            opacity = life / max_life
            {r, g, b, _} = Color.hsl(hue, 1.0, 0.6)
            r = trunc(r * opacity)
            g = trunc(g * opacity)
            b = trunc(b * opacity)
            fg = {max(0, r), max(0, g), max(0, b), 255}
            char = if opacity > 0.5, do: "●", else: "∙"
            NativeBuffer.draw_char(buf, ix, iy, char, fg, black)
          else
            buf
          end
        end)

      # 4. Decorative rainbow line
      buf =
        if elapsed_ms > 1000 do
          line_opacity = min(1.0, (elapsed_ms - 1000) / 500.0)

          Enum.reduce(0..(line_w - 1), buf, fn i, buf ->
            hue = rem(trunc(i * 10 + t * 80), 360)
            {r, g, b, _} = Color.hsl(hue, 1.0, 0.5)
            r = trunc(r * line_opacity)
            g = trunc(g * line_opacity)
            b = trunc(b * line_opacity)
            fg = {r, g, b, 255}
            NativeBuffer.draw_char(buf, line_x + i, line_y, "─", fg, black)
          end)
        else
          buf
        end

      # 5. Tagline
      buf =
        if elapsed_ms > 1200 do
          tag_opacity = min(1.0, (elapsed_ms - 1200) / 600.0)
          b = trunc(200 * tag_opacity)
          fg = {b, b, b, 255}
          NativeBuffer.draw_text(buf, tagline_x, tagline_y, tagline, fg, black)
        else
          buf
        end

      # 6. Sub-tagline
      buf =
        if elapsed_ms > 1600 do
          sub_opacity = min(1.0, (elapsed_ms - 1600) / 600.0)
          b = trunc(100 * sub_opacity)
          fg = {b, b, b, 255}
          NativeBuffer.draw_text(buf, sub_tagline_x, sub_tagline_y, sub_tagline, fg, black)
        else
          buf
        end

      # 7. Quit hint — pulsing
      pulse = (1.0 + :math.sin(t * 2.0)) / 2.0
      b = trunc(40 + pulse * 40)
      buf = NativeBuffer.draw_text(buf, quit_x, quit_y, quit_text, {b, b, b, 255}, black)

      # Render frame via NIF (flush → diff → ANSI → stdout → swap)
      buf = NativeBuffer.render_frame(buf)

      # ~30fps
      Process.sleep(33)

      animate.(animate, buf, frame + 1, particles)
    end
  end
end

result = animate.(animate, buf, 0, initial_particles)

# --- Cleanup ---

Process.unlink(input_pid)
Process.exit(input_pid, :kill)

# Restore terminal
IO.write("\e[0m\e[?25h\e[?1049l")
:os.cmd(String.to_charlist("stty #{old_stty} < /dev/tty"))

case result do
  :quit    -> IO.puts("Goodbye!")
  :timeout -> IO.puts("Animation timed out (120s safety limit).")
end
