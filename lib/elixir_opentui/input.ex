defmodule ElixirOpentui.Input do
  @moduledoc """
  Parses raw terminal input bytes into structured key and mouse events.

  Handles:
  - Regular characters (UTF-8)
  - Control keys (Ctrl+A through Ctrl+Z)
  - Escape sequences (arrows, function keys, home/end, etc.)
  - SGR mouse events (\e[<...M/m)
  - Bracketed paste (\e[200~ ... \e[201~)
  """

  @type key_event :: %{
          type: :key,
          key: atom() | String.t(),
          ctrl: boolean(),
          alt: boolean(),
          shift: boolean()
        }

  @type mouse_event :: %{
          type: :mouse,
          action: :press | :release | :move | :scroll_up | :scroll_down,
          button: :left | :right | :middle | :none,
          x: non_neg_integer(),
          y: non_neg_integer(),
          ctrl: boolean(),
          alt: boolean(),
          shift: boolean()
        }

  @type paste_event :: %{type: :paste, data: String.t()}

  @type event :: key_event() | mouse_event() | paste_event()

  @doc "Parse a chunk of raw terminal input into a list of events."
  @spec parse(binary()) :: [event()]
  def parse(data) when is_binary(data) do
    parse_loop(data, [])
  end

  defp parse_loop(<<>>, acc), do: Enum.reverse(acc)

  # Bracketed paste: \e[200~ ... \e[201~
  defp parse_loop(<<"\e[200~", rest::binary>>, acc) do
    case :binary.split(rest, "\e[201~") do
      [paste_data, remaining] ->
        parse_loop(remaining, [%{type: :paste, data: paste_data} | acc])

      [_incomplete] ->
        parse_loop(<<>>, [%{type: :paste, data: rest} | acc])
    end
  end

  # SGR mouse: \e[< Cb ; Cx ; Cy M/m
  defp parse_loop(<<"\e[<", rest::binary>>, acc) do
    case parse_sgr_mouse(rest) do
      {event, remaining} -> parse_loop(remaining, [event | acc])
      nil -> parse_loop(<<>>, acc)
    end
  end

  # CSI sequences: \e[ ...
  defp parse_loop(<<"\e[", rest::binary>>, acc) do
    case parse_csi(rest) do
      {event, remaining} -> parse_loop(remaining, [event | acc])
      nil -> parse_loop(<<>>, acc)
    end
  end

  # SS3 sequences: \eO ...
  defp parse_loop(<<"\eO", rest::binary>>, acc) do
    case parse_ss3(rest) do
      {event, remaining} -> parse_loop(remaining, [event | acc])
      nil -> parse_loop(<<>>, acc)
    end
  end

  # Alt+key: \e followed by a regular char
  defp parse_loop(<<"\e", char, rest::binary>>, acc) when char >= 0x20 do
    event = %{type: :key, key: <<char>>, ctrl: false, alt: true, shift: char in ?A..?Z}
    parse_loop(rest, [event | acc])
  end

  # Bare escape
  defp parse_loop(<<"\e">>, acc) do
    [%{type: :key, key: :escape, ctrl: false, alt: false, shift: false} | acc]
    |> Enum.reverse()
  end

  defp parse_loop(<<"\e", rest::binary>>, acc) do
    parse_loop(rest, [%{type: :key, key: :escape, ctrl: false, alt: false, shift: false} | acc])
  end

  # Control characters
  defp parse_loop(<<0, rest::binary>>, acc) do
    parse_loop(rest, [ctrl_key("@") | acc])
  end

  defp parse_loop(<<char, rest::binary>>, acc) when char >= 1 and char <= 26 do
    letter = <<char + ?a - 1>>

    event =
      case char do
        9 -> %{type: :key, key: :tab, ctrl: false, alt: false, shift: false}
        10 -> %{type: :key, key: :enter, ctrl: false, alt: false, shift: false}
        13 -> %{type: :key, key: :enter, ctrl: false, alt: false, shift: false}
        _ -> ctrl_key(letter)
      end

    parse_loop(rest, [event | acc])
  end

  # Backspace / Delete
  defp parse_loop(<<127, rest::binary>>, acc) do
    parse_loop(rest, [%{type: :key, key: :backspace, ctrl: false, alt: false, shift: false} | acc])
  end

  # Regular UTF-8 character
  defp parse_loop(<<char::utf8, rest::binary>>, acc) do
    key = <<char::utf8>>
    shift = char in ?A..?Z

    parse_loop(rest, [
      %{type: :key, key: key, ctrl: false, alt: false, shift: shift} | acc
    ])
  end

  # Skip unrecognized bytes
  defp parse_loop(<<_byte, rest::binary>>, acc) do
    parse_loop(rest, acc)
  end

  # --- CSI sequence parsing ---

  defp parse_csi(data) do
    case collect_params_and_final(data) do
      {params, final, rest} -> {csi_to_event(params, final), rest}
      nil -> nil
    end
  end

  # Modified keys MUST match before wildcards: \e[1;modN where mod encodes ctrl/alt/shift
  defp csi_to_event([_n, mod_str], final) when final in ["A", "B", "C", "D", "H", "F"] do
    base = csi_to_event([], final)
    apply_modifier(base, to_integer(mod_str, 1))
  end

  defp csi_to_event(_params, "A"), do: key(:up)
  defp csi_to_event(_params, "B"), do: key(:down)
  defp csi_to_event(_params, "C"), do: key(:right)
  defp csi_to_event(_params, "D"), do: key(:left)
  defp csi_to_event(_params, "H"), do: key(:home)
  defp csi_to_event(_params, "F"), do: key(:end)
  defp csi_to_event(_params, "Z"), do: %{type: :key, key: :tab, ctrl: false, alt: false, shift: true}

  # Tilde-terminated sequences: \e[N~
  defp csi_to_event(params, "~") do
    code = params |> List.first() |> to_integer(0)

    case code do
      1 -> key(:home)
      2 -> key(:insert)
      3 -> key(:delete)
      4 -> key(:end)
      5 -> key(:page_up)
      6 -> key(:page_down)
      15 -> key(:f5)
      17 -> key(:f6)
      18 -> key(:f7)
      19 -> key(:f8)
      20 -> key(:f9)
      21 -> key(:f10)
      23 -> key(:f11)
      24 -> key(:f12)
      _ -> key(:unknown)
    end
  end

  defp csi_to_event(_, _), do: key(:unknown)

  # --- SS3 sequence parsing (some terminals send these for F1-F4, arrows) ---

  defp parse_ss3(<<char, rest::binary>>) when char >= ?A and char <= ?Z do
    event =
      case char do
        ?P -> key(:f1)
        ?Q -> key(:f2)
        ?R -> key(:f3)
        ?S -> key(:f4)
        ?A -> key(:up)
        ?B -> key(:down)
        ?C -> key(:right)
        ?D -> key(:left)
        ?H -> key(:home)
        ?F -> key(:end)
        _ -> key(:unknown)
      end

    {event, rest}
  end

  defp parse_ss3(_), do: nil

  # --- SGR mouse parsing ---
  # Format: Cb;Cx;Cy[M|m]
  # M = press, m = release
  # Cb encodes button + modifiers

  defp parse_sgr_mouse(data) do
    case Regex.run(~r/^(\d+);(\d+);(\d+)([Mm])/, data) do
      [full, cb_str, cx_str, cy_str, action_char] ->
        cb = String.to_integer(cb_str)
        cx = String.to_integer(cx_str) - 1
        cy = String.to_integer(cy_str) - 1

        {action, button} = decode_mouse_button(cb, action_char)

        event = %{
          type: :mouse,
          action: action,
          button: button,
          x: cx,
          y: cy,
          ctrl: band(cb, 16) != 0,
          alt: band(cb, 8) != 0,
          shift: band(cb, 4) != 0
        }

        rest = binary_part(data, byte_size(full), byte_size(data) - byte_size(full))
        {event, rest}

      _ ->
        nil
    end
  end

  defp decode_mouse_button(cb, action_char) do
    base = band(cb, 3)
    motion = band(cb, 32) != 0

    cond do
      band(cb, 64) != 0 and base == 0 -> {:scroll_up, :none}
      band(cb, 64) != 0 and base == 1 -> {:scroll_down, :none}
      motion -> {:move, button_from_base(base)}
      action_char == "m" -> {:release, button_from_base(base)}
      true -> {:press, button_from_base(base)}
    end
  end

  defp button_from_base(0), do: :left
  defp button_from_base(1), do: :middle
  defp button_from_base(2), do: :right
  defp button_from_base(3), do: :none
  defp button_from_base(_), do: :none

  defp band(a, b), do: Bitwise.band(a, b)

  # Collect CSI parameter bytes and the final byte
  defp collect_params_and_final(data) do
    collect_params_and_final(data, [])
  end

  defp collect_params_and_final(<<>>, _params), do: nil

  defp collect_params_and_final(<<char, rest::binary>>, params) when char >= 0x40 and char <= 0x7E do
    param_strs =
      params
      |> Enum.reverse()
      |> IO.iodata_to_binary()
      |> String.split(";", trim: false)

    {param_strs, <<char>>, rest}
  end

  defp collect_params_and_final(<<char, rest::binary>>, params) when char >= 0x20 and char <= 0x3F do
    collect_params_and_final(rest, [<<char>> | params])
  end

  defp collect_params_and_final(_, _params), do: nil

  # --- Key event constructors ---

  defp key(name) do
    %{type: :key, key: name, ctrl: false, alt: false, shift: false}
  end

  defp ctrl_key(letter) do
    %{type: :key, key: letter, ctrl: true, alt: false, shift: false}
  end

  # Modifier decoding: ANSI modifier value (1 = none, 2 = shift, 3 = alt, etc.)
  defp apply_modifier(event, mod) do
    mod = mod - 1

    %{
      event
      | shift: band(mod, 1) != 0,
        alt: band(mod, 2) != 0,
        ctrl: band(mod, 4) != 0
    }
  end

  defp to_integer(str, default) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end
end
