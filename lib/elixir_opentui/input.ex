defmodule ElixirOpentui.Input do
  @moduledoc """
  Parses raw terminal input bytes into structured key and mouse events.

  Handles:
  - Regular characters (UTF-8)
  - Control keys (Ctrl+A through Ctrl+Z)
  - Escape sequences (arrows, function keys, home/end, etc.)
  - SGR mouse events (\\e[<...M/m)
  - Bracketed paste (\\e[200~ ... \\e[201~)
  - Kitty keyboard protocol CSI u sequences (\\e[codepoint;modifier:event_type u)
  - xterm modifyOtherKeys (\\e[27;modifier;keycode~)
  - Capability query responses (\\e[?{flags}u)
  """

  # --- Kitty special key codepoints (Unicode PUA + standard) ---

  @kitty_special_keys %{
    27 => :escape,
    9 => :tab,
    13 => :enter,
    127 => :backspace,
    # PUA functional keys (57344-57357 handled by @kitty_functional_keys)
    # PUA special keys
    57358 => :caps_lock,
    57359 => :scroll_lock,
    57360 => :num_lock,
    57361 => :print_screen,
    57362 => :pause,
    57363 => :menu,
    # F13-F35
    57376 => :f13,
    57377 => :f14,
    57378 => :f15,
    57379 => :f16,
    57380 => :f17,
    57381 => :f18,
    57382 => :f19,
    57383 => :f20,
    57384 => :f21,
    57385 => :f22,
    57386 => :f23,
    57387 => :f24,
    57388 => :f25,
    57389 => :f26,
    57390 => :f27,
    57391 => :f28,
    57392 => :f29,
    57393 => :f30,
    57394 => :f31,
    57395 => :f32,
    57396 => :f33,
    57397 => :f34,
    57398 => :f35,
    # Keypad keys
    57399 => :kp_0,
    57400 => :kp_1,
    57401 => :kp_2,
    57402 => :kp_3,
    57403 => :kp_4,
    57404 => :kp_5,
    57405 => :kp_6,
    57406 => :kp_7,
    57407 => :kp_8,
    57408 => :kp_9,
    57409 => :kp_decimal,
    57410 => :kp_divide,
    57411 => :kp_multiply,
    57412 => :kp_subtract,
    57413 => :kp_add,
    57414 => :kp_enter,
    57415 => :kp_equal,
    57416 => :kp_separator,
    57417 => :kp_left,
    57418 => :kp_right,
    57419 => :kp_up,
    57420 => :kp_down,
    57421 => :kp_page_up,
    57422 => :kp_page_down,
    57423 => :kp_home,
    57424 => :kp_end,
    57425 => :kp_insert,
    57426 => :kp_delete,
    57427 => :kp_begin,
    # Media keys
    57428 => :media_play,
    57429 => :media_pause,
    57430 => :media_play_pause,
    57431 => :media_reverse,
    57432 => :media_stop,
    57433 => :media_fast_forward,
    57434 => :media_rewind,
    57435 => :media_track_next,
    57436 => :media_track_previous,
    57437 => :media_record,
    57438 => :lower_volume,
    57439 => :raise_volume,
    57440 => :mute_volume,
    # Modifier keys (reported as key events with flags >= 5)
    57441 => :left_shift,
    57442 => :left_control,
    57443 => :left_alt,
    57444 => :left_super,
    57445 => :left_hyper,
    57446 => :left_meta,
    57447 => :right_shift,
    57448 => :right_control,
    57449 => :right_alt,
    57450 => :right_super,
    57451 => :right_hyper,
    57452 => :right_meta,
    57453 => :iso_level3_shift,
    57454 => :iso_level5_shift
  }

  @kitty_functional_keys %{
    57344 => :escape,
    57345 => :enter,
    57346 => :tab,
    57347 => :backspace,
    57348 => :insert,
    57349 => :delete,
    57350 => :left,
    57351 => :right,
    57352 => :up,
    57353 => :down,
    57354 => :page_up,
    57355 => :page_down,
    57356 => :home,
    57357 => :end,
    # F1-F12
    57364 => :f1,
    57365 => :f2,
    57366 => :f3,
    57367 => :f4,
    57368 => :f5,
    57369 => :f6,
    57370 => :f7,
    57371 => :f8,
    57372 => :f9,
    57373 => :f10,
    57374 => :f11,
    57375 => :f12
  }

  @type key_event :: %{
          type: :key,
          key: atom() | String.t(),
          ctrl: boolean(),
          alt: boolean(),
          shift: boolean(),
          meta: boolean()
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
  @type capability_event :: %{type: :capability, capability: atom(), value: term()}

  @type event :: key_event() | mouse_event() | paste_event() | capability_event()

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
    event = %{
      type: :key,
      key: <<char>>,
      ctrl: false,
      alt: true,
      shift: char in ?A..?Z,
      meta: false
    }

    parse_loop(rest, [event | acc])
  end

  # Bare escape
  defp parse_loop(<<"\e">>, acc) do
    [%{type: :key, key: :escape, ctrl: false, alt: false, shift: false, meta: false} | acc]
    |> Enum.reverse()
  end

  defp parse_loop(<<"\e", rest::binary>>, acc) do
    parse_loop(rest, [
      %{type: :key, key: :escape, ctrl: false, alt: false, shift: false, meta: false} | acc
    ])
  end

  # Control characters
  defp parse_loop(<<0, rest::binary>>, acc) do
    parse_loop(rest, [ctrl_key("@") | acc])
  end

  defp parse_loop(<<char, rest::binary>>, acc) when char >= 1 and char <= 26 do
    letter = <<char + ?a - 1>>

    event =
      case char do
        9 -> %{type: :key, key: :tab, ctrl: false, alt: false, shift: false, meta: false}
        10 -> %{type: :key, key: :enter, ctrl: false, alt: false, shift: false, meta: false}
        13 -> %{type: :key, key: :enter, ctrl: false, alt: false, shift: false, meta: false}
        _ -> ctrl_key(letter)
      end

    parse_loop(rest, [event | acc])
  end

  # Backspace / Delete
  defp parse_loop(<<127, rest::binary>>, acc) do
    parse_loop(rest, [
      %{type: :key, key: :backspace, ctrl: false, alt: false, shift: false, meta: false} | acc
    ])
  end

  # Regular UTF-8 character
  defp parse_loop(<<char::utf8, rest::binary>>, acc) do
    key = <<char::utf8>>
    shift = char in ?A..?Z

    parse_loop(rest, [
      %{type: :key, key: key, ctrl: false, alt: false, shift: shift, meta: false} | acc
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

  # --- Kitty keyboard protocol: CSI u sequences ---

  # Kitty keyboard query response: \e[?{flags}u
  defp csi_to_event(["?" <> flags_str | _], "u") do
    flags = to_integer(flags_str, 0)
    %{type: :capability, capability: :kitty_keyboard, value: flags}
  end

  # Kitty key events: \e[codepoint;modifier:event_type u
  defp csi_to_event(params, "u") do
    parse_kitty_key(params)
  end

  # Modified keys: \e[1;modN where mod encodes ctrl/alt/shift
  # Enhanced with event_type support: \e[1;mod:event_type N
  defp csi_to_event([_n, mod_str], final) when final in ["A", "B", "C", "D", "H", "F"] do
    {mod_value, event_type} = split_modifier_event_type(mod_str)
    base = csi_to_event([], final)
    event = apply_modifier(base, mod_value)
    if event_type, do: Map.put(event, :event_type, event_type_atom(event_type)), else: event
  end

  defp csi_to_event(_params, "A"), do: key(:up)
  defp csi_to_event(_params, "B"), do: key(:down)
  defp csi_to_event(_params, "C"), do: key(:right)
  defp csi_to_event(_params, "D"), do: key(:left)
  defp csi_to_event(_params, "H"), do: key(:home)
  defp csi_to_event(_params, "F"), do: key(:end)

  defp csi_to_event(_params, "Z"),
    do: %{type: :key, key: :tab, ctrl: false, alt: false, shift: true, meta: false}

  # --- Tilde-terminated sequences ---
  # Clause ordering (most-specific first, Elixir matches top-down):
  # 1. modifyOtherKeys 3-param: \e[27;mod;keycode~
  # 2. Modified tilde 2-param: \e[code;mod[:event_type]~
  # 3. Legacy 1-param catch-all: \e[N~

  # modifyOtherKeys format: \e[27;{modifier};{keycode}~
  defp csi_to_event(["27", mod_str, keycode_str], "~") do
    keycode = to_integer(keycode_str, 0)
    mod_value = to_integer(mod_str, 1)
    key_name = modify_other_keys_to_key(keycode)
    event = %{type: :key, key: key_name, ctrl: false, alt: false, shift: false, meta: false}
    apply_modifier(event, mod_value)
  end

  # Modified tilde: \e[code;mod[:event_type]~ — FIXES existing bug where modifiers were ignored
  defp csi_to_event([code_str, mod_str], "~") do
    {mod_value, event_type} = split_modifier_event_type(mod_str)
    base = tilde_code_to_event(code_str)
    event = apply_modifier(base, mod_value)
    if event_type, do: Map.put(event, :event_type, event_type_atom(event_type)), else: event
  end

  # Legacy tilde: \e[N~
  defp csi_to_event(params, "~") do
    code_str = List.first(params) || "0"
    tilde_code_to_event(code_str)
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

  defp collect_params_and_final(<<char, rest::binary>>, params)
       when char >= 0x40 and char <= 0x7E do
    param_strs =
      params
      |> Enum.reverse()
      |> IO.iodata_to_binary()
      |> String.split(";", trim: false)

    {param_strs, <<char>>, rest}
  end

  defp collect_params_and_final(<<char, rest::binary>>, params)
       when char >= 0x20 and char <= 0x3F do
    collect_params_and_final(rest, [<<char>> | params])
  end

  defp collect_params_and_final(_, _params), do: nil

  # --- Key event constructors ---

  defp key(name) do
    %{type: :key, key: name, ctrl: false, alt: false, shift: false, meta: false}
  end

  defp ctrl_key(letter) do
    %{type: :key, key: letter, ctrl: true, alt: false, shift: false, meta: false}
  end

  # --- Kitty key event parsing ---

  defp parse_kitty_key(params) do
    # params[0] = codepoint[:shifted_codepoint[:base_layout_codepoint]]
    # params[1] = modifier[:event_type]   (optional)
    codepoint_str = List.first(params) || "0"
    mod_str = Enum.at(params, 1)

    # Extract the primary codepoint (before any colon sub-params)
    codepoint = codepoint_str |> String.split(":") |> List.first() |> to_integer(0)

    key_name = kitty_codepoint_to_key(codepoint)

    event = %{type: :key, key: key_name, ctrl: false, alt: false, shift: false, meta: false}

    if mod_str do
      {mod_value, event_type} = split_modifier_event_type(mod_str)
      event = apply_kitty_modifier(event, mod_value)

      if event_type,
        do: Map.put(event, :event_type, event_type_atom(event_type)),
        else: event
    else
      event
    end
  end

  defp kitty_codepoint_to_key(cp) when is_map_key(@kitty_functional_keys, cp) do
    Map.fetch!(@kitty_functional_keys, cp)
  end

  defp kitty_codepoint_to_key(cp) when is_map_key(@kitty_special_keys, cp) do
    Map.fetch!(@kitty_special_keys, cp)
  end

  defp kitty_codepoint_to_key(cp) when cp >= 32 and cp <= 0x10FFFF do
    <<cp::utf8>>
  rescue
    # Invalid codepoint
    _ -> :unknown
  end

  defp kitty_codepoint_to_key(_), do: :unknown

  # Kitty modifier bits → event map fields:
  #   bit 0 (1)   shift     → shift:
  #   bit 1 (2)   alt       → alt:
  #   bit 2 (4)   ctrl      → ctrl:
  #   bit 3 (8)   super     → meta:  (matches OpenTUI convention)
  #   bit 4 (16)  hyper     → (dropped, no widget uses it)
  #   bit 5 (32)  meta      → (dropped, no widget uses it)
  #   bit 6 (64)  caps_lock → (dropped, not sent with flags=5)
  #   bit 7 (128) num_lock  → (dropped, not sent with flags=5)
  defp apply_kitty_modifier(event, mod) do
    # Kitty uses 1-based modifiers, same as xterm
    apply_modifier(event, mod)
  end

  # Modifier decoding: ANSI modifier value (1 = none, 2 = shift, 3 = alt, etc.)
  # This encoding is shared by xterm and Kitty protocols.
  defp apply_modifier(event, mod) do
    mod = mod - 1

    %{
      event
      | shift: band(mod, 1) != 0,
        alt: band(mod, 2) != 0,
        ctrl: band(mod, 4) != 0,
        meta: band(mod, 8) != 0
    }
  end

  # Split modifier string that may contain event_type sub-param.
  # Returns {modifier, event_type} where event_type is nil when not present.
  # "5:3" → {5, 3}, "5:1" → {5, 1}, "5" → {5, nil}
  defp split_modifier_event_type(mod_str) do
    case String.split(mod_str, ":") do
      [mod_part, event_type_part | _] ->
        {to_integer(mod_part, 1), to_integer(event_type_part, 1)}

      [mod_part] ->
        {to_integer(mod_part, 1), nil}
    end
  end

  # Event type: 1 = press (default), 2 = repeat, 3 = release
  defp event_type_atom(1), do: :press
  defp event_type_atom(2), do: :repeat
  defp event_type_atom(3), do: :release
  defp event_type_atom(_), do: :press

  # --- Tilde code mapping (shared between 1-param and 2-param tilde clauses) ---

  defp tilde_code_to_event(code_str) do
    code = to_integer(code_str, 0)

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

  # --- modifyOtherKeys key mapping ---

  defp modify_other_keys_to_key(13), do: :enter
  defp modify_other_keys_to_key(27), do: :escape
  defp modify_other_keys_to_key(9), do: :tab
  defp modify_other_keys_to_key(127), do: :backspace
  defp modify_other_keys_to_key(32), do: " "

  defp modify_other_keys_to_key(keycode) when keycode >= 33 and keycode <= 126 do
    <<keycode>>
  end

  defp modify_other_keys_to_key(_), do: :unknown

  defp to_integer(str, default) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end
end
