defmodule ElixirOpentui.Widgets.TextInput do
  @moduledoc """
  Interactive text input widget.

  Manages cursor position, text editing, scroll offset for long text,
  and emits on_change messages to the parent.

  ## Props
  - `:value` — current text value (controlled from parent)
  - `:placeholder` — placeholder text when empty
  - `:on_change` — message tag sent as `{tag, new_value}` on edit
  - `:width` — display width
  - `:id` — element id (required for focus)

  ## Internal State
  - `:cursor_pos` — cursor position within value
  - `:scroll_offset` — horizontal scroll for text wider than widget
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
      width: Map.get(props, :width, 20),
      id: Map.get(props, :id)
    }
  end

  @impl true
  def update(:sync_value, %{value: value}, state) do
    %{state | value: value, cursor_pos: min(state.cursor_pos, String.length(value))}
  end

  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update(:paste, %{type: :paste, data: data}, state) do
    {before, after_cursor} = split_at_cursor(state)
    new_value = before <> data <> after_cursor
    new_cursor = state.cursor_pos + String.length(data)
    state = %{state | value: new_value, cursor_pos: new_cursor}
    state = adjust_scroll(state)
    emit_change(state)
  end

  def update(_, _, state), do: state

  @impl true
  def render(state) do
    import ElixirOpentui.View

    input(
      id: state.id,
      value: state.value,
      placeholder: state.placeholder,
      cursor_pos: state.cursor_pos,
      scroll_offset: state.scroll_offset,
      width: state.width
    )
  end

  # --- Key handling ---

  defp handle_key(%{key: key, ctrl: false, alt: false} = _event, state)
       when is_binary(key) and byte_size(key) == 1 do
    insert_char(state, key)
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
    {before, after_cursor} = split_at_cursor(state)

    if String.length(after_cursor) > 0 do
      new_after = String.slice(after_cursor, 1, String.length(after_cursor) - 1)
      state = %{state | value: before <> new_after}
      emit_change(state)
    else
      state
    end
  end

  defp handle_key(%{key: :left}, state) do
    new_pos = max(0, state.cursor_pos - 1)
    state = %{state | cursor_pos: new_pos}
    adjust_scroll(state)
  end

  defp handle_key(%{key: :right}, state) do
    new_pos = min(String.length(state.value), state.cursor_pos + 1)
    state = %{state | cursor_pos: new_pos}
    adjust_scroll(state)
  end

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

  # --- Helpers ---

  defp insert_char(state, char) do
    {before, after_cursor} = split_at_cursor(state)
    new_value = before <> char <> after_cursor
    new_cursor = state.cursor_pos + 1
    state = %{state | value: new_value, cursor_pos: new_cursor}
    state = adjust_scroll(state)
    emit_change(state)
  end

  defp split_at_cursor(state) do
    before = String.slice(state.value, 0, state.cursor_pos)
    after_cursor = String.slice(state.value, state.cursor_pos, String.length(state.value) - state.cursor_pos)
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
      state
    else
      state
    end
  end
end
