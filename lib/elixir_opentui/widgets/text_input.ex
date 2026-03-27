defmodule ElixirOpentui.Widgets.TextInput do
  @moduledoc """
  Interactive text input widget.

  Manages cursor position, text editing, scroll offset for long text,
  and emits on_change/on_submit messages to the parent via `_pending`.

  ## Props (mount-time only)
  - `:value` — initial text value
  - `:placeholder` — placeholder text when empty
  - `:on_change` — message tag sent as `{tag, new_value}` on edit
  - `:on_submit` — message tag sent as `{tag, value}` on Enter
  - `:max_length` — maximum character count (default: `:infinity`)
  - `:width` — display width
  - `:id` — element id (required for focus)
  - `:cursor_style` — `:block` | `:underline` | `:bar` (default: `:block`)
  - `:focused_bg` — background color when focused
  - `:focused_fg` — foreground color when focused
  - `:placeholder_fg` — foreground color for placeholder text
  - `:cursor_fg` — foreground color for cursor cell
  - `:cursor_bg` — background color for cursor cell
  """

  use ElixirOpentui.Component

  @impl true
  def init(props) do
    value = Map.get(props, :value, "")

    %{
      value: value,
      cursor_pos: String.length(value),
      scroll_offset: 0,
      placeholder: Map.get(props, :placeholder, ""),
      on_change: Map.get(props, :on_change),
      on_submit: Map.get(props, :on_submit),
      max_length: Map.get(props, :max_length, :infinity),
      width: Map.get(props, :width, 20),
      id: Map.get(props, :id),
      cursor_style: Map.get(props, :cursor_style, :block),
      focused_bg: Map.get(props, :focused_bg),
      focused_fg: Map.get(props, :focused_fg),
      placeholder_fg: Map.get(props, :placeholder_fg),
      cursor_fg: Map.get(props, :cursor_fg),
      cursor_bg: Map.get(props, :cursor_bg),
      _pending: []
    }
  end

  @impl true
  def update(:sync_value, %{value: value}, state) do
    %{state | value: value, cursor_pos: min(state.cursor_pos, String.length(value))}
    |> adjust_scroll()
  end

  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update(:paste, %{type: :paste, data: data}, state) do
    {before, after_cursor} = split_at_cursor(state)
    new_text = truncate_to_max(before <> data <> after_cursor, state.max_length)
    new_cursor = min(state.cursor_pos + String.length(data), String.length(new_text))
    state = %{state | value: new_text, cursor_pos: new_cursor}
    state = adjust_scroll(state)
    emit_change(state)
  end

  def update(_, _, state), do: state

  @impl true
  def update_props(prev_props, new_props, state) do
    state = %{
      state
      | id: Map.get(new_props, :id),
        placeholder: Map.get(new_props, :placeholder, ""),
        on_change: Map.get(new_props, :on_change),
        on_submit: Map.get(new_props, :on_submit),
        max_length: Map.get(new_props, :max_length, :infinity),
        width: Map.get(new_props, :width, 20),
        cursor_style: Map.get(new_props, :cursor_style, :block),
        focused_bg: Map.get(new_props, :focused_bg),
        focused_fg: Map.get(new_props, :focused_fg),
        placeholder_fg: Map.get(new_props, :placeholder_fg),
        cursor_fg: Map.get(new_props, :cursor_fg),
        cursor_bg: Map.get(new_props, :cursor_bg)
    }

    state =
      if prop_changed?(prev_props, new_props, :value) do
        update(:sync_value, %{value: Map.get(new_props, :value, "")}, state)
      else
        state
      end

    if prop_changed?(prev_props, new_props, :width) and
         not prop_changed?(prev_props, new_props, :value) do
      adjust_scroll(state)
    else
      state
    end
  end

  @impl true
  def render(state) do
    alias ElixirOpentui.Element

    attrs =
      [
        id: state.id,
        value: state.value,
        placeholder: state.placeholder,
        cursor_pos: state.cursor_pos,
        scroll_offset: state.scroll_offset,
        width: state.width,
        cursor_style: state.cursor_style
      ]
      |> maybe_put(:focused_bg, state.focused_bg)
      |> maybe_put(:focused_fg, state.focused_fg)
      |> maybe_put(:placeholder_fg, state.placeholder_fg)
      |> maybe_put(:cursor_fg, state.cursor_fg)
      |> maybe_put(:cursor_bg, state.cursor_bg)

    Element.new(:input, attrs)
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, key, value), do: Keyword.put(attrs, key, value)

  # --- Key handling ---

  defp handle_key(%{key: key, ctrl: false, alt: false} = _event, state)
       when is_binary(key) and byte_size(key) == 1 do
    insert_char(state, key)
  end

  defp handle_key(%{key: :enter}, state) do
    emit_submit(state)
  end

  defp handle_key(%{key: :backspace}, state) do
    if state.cursor_pos > 0 do
      {before, after_cursor} = split_at_cursor(state)
      new_before = String.slice(before, 0, String.length(before) - 1)
      new_value = new_before <> after_cursor
      state = %{state | value: new_value, cursor_pos: state.cursor_pos - 1}
      state = adjust_scroll(state)
      emit_change(state)
    else
      state
    end
  end

  defp handle_key(%{key: :delete}, state) do
    delete_forward(state)
  end

  defp handle_key(%{key: :left}, state), do: move_left(state)
  defp handle_key(%{key: :right}, state), do: move_right(state)

  defp handle_key(%{key: :home}, state) do
    %{state | cursor_pos: 0, scroll_offset: 0}
  end

  defp handle_key(%{key: :end}, state) do
    state = %{state | cursor_pos: String.length(state.value)}
    adjust_scroll(state)
  end

  defp handle_key(%{key: "a", ctrl: true}, state) do
    %{state | cursor_pos: 0, scroll_offset: 0}
  end

  defp handle_key(%{key: "e", ctrl: true}, state) do
    state = %{state | cursor_pos: String.length(state.value)}
    adjust_scroll(state)
  end

  # Emacs keybindings
  defp handle_key(%{key: "b", ctrl: true}, state), do: move_left(state)
  defp handle_key(%{key: "f", ctrl: true}, state), do: move_right(state)
  defp handle_key(%{key: "d", ctrl: true}, state), do: delete_forward(state)

  defp handle_key(%{key: "k", ctrl: true}, state) do
    {before, _after} = split_at_cursor(state)
    state = %{state | value: before}
    emit_change(state)
  end

  defp handle_key(%{key: "u", ctrl: true}, state) do
    {_before, after_cursor} = split_at_cursor(state)
    state = %{state | value: after_cursor, cursor_pos: 0, scroll_offset: 0}
    emit_change(state)
  end

  defp handle_key(_, state), do: state

  # --- Movement helpers ---

  defp move_left(state) do
    new_pos = max(0, state.cursor_pos - 1)
    state = %{state | cursor_pos: new_pos}
    adjust_scroll(state)
  end

  defp move_right(state) do
    new_pos = min(String.length(state.value), state.cursor_pos + 1)
    state = %{state | cursor_pos: new_pos}
    adjust_scroll(state)
  end

  defp delete_forward(state) do
    {before, after_cursor} = split_at_cursor(state)

    if String.length(after_cursor) > 0 do
      new_after = String.slice(after_cursor, 1, String.length(after_cursor) - 1)
      state = %{state | value: before <> new_after}
      emit_change(state)
    else
      state
    end
  end

  # --- Helpers ---

  defp insert_char(state, char) do
    if exceeds_max?(state) do
      state
    else
      {before, after_cursor} = split_at_cursor(state)
      new_value = before <> char <> after_cursor
      new_cursor = state.cursor_pos + 1
      state = %{state | value: new_value, cursor_pos: new_cursor}
      state = adjust_scroll(state)
      emit_change(state)
    end
  end

  defp exceeds_max?(%{max_length: :infinity}), do: false

  defp exceeds_max?(state) do
    String.length(state.value) >= state.max_length
  end

  defp truncate_to_max(text, :infinity), do: text

  defp truncate_to_max(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length)
    else
      text
    end
  end

  defp split_at_cursor(state) do
    before = String.slice(state.value, 0, state.cursor_pos)

    after_cursor =
      String.slice(state.value, state.cursor_pos, String.length(state.value) - state.cursor_pos)

    {before, after_cursor}
  end

  defp adjust_scroll(state) do
    w = state.width

    scroll =
      cond do
        state.cursor_pos < state.scroll_offset -> state.cursor_pos
        state.cursor_pos >= state.scroll_offset + w -> state.cursor_pos - w + 1
        true -> state.scroll_offset
      end

    %{state | scroll_offset: max(0, scroll)}
  end

  defp emit_change(state) do
    if state.on_change do
      %{state | _pending: [{state.on_change, state.value} | state._pending]}
    else
      state
    end
  end

  defp emit_submit(state) do
    if state.on_submit do
      %{state | _pending: [{state.on_submit, state.value} | state._pending]}
    else
      state
    end
  end

  defp prop_changed?(prev_props, new_props, key) do
    prev_has? = Map.has_key?(prev_props, key)
    new_has? = Map.has_key?(new_props, key)

    prev_has? != new_has? or (prev_has? and Map.get(prev_props, key) != Map.get(new_props, key))
  end
end
