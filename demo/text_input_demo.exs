# TextInput Interactive Demo
# Run: mix run demo/text_input_demo.exs
#
# Two text inputs with tab navigation.
# Type text, use arrow keys, Home/End, Ctrl+A/E/K/U, Backspace/Delete.
# Press Ctrl+C to exit.

defmodule TextInputDemo do
  alias ElixirOpentui.Widgets.TextInput
  alias ElixirOpentui.Color

  @field_ids [:name, :email]

  def init(cols, rows) do
    %{
      cols: cols,
      rows: rows,
      focus_idx: 0,
      fields: %{
        name: TextInput.init(%{id: :name, placeholder: "Enter your name...", width: min(40, cols - 10)}),
        email: TextInput.init(%{id: :email, placeholder: "user@example.com", width: min(40, cols - 10)})
      }
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true, meta: false}, _state), do: :quit

  def handle_event(%{type: :key, key: :tab, shift: true, meta: false}, state) do
    new_idx = rem(state.focus_idx - 1 + length(@field_ids), length(@field_ids))
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key, key: :tab, meta: false}, state) do
    new_idx = rem(state.focus_idx + 1, length(@field_ids))
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key} = event, state) do
    field_id = Enum.at(@field_ids, state.focus_idx)
    field_state = state.fields[field_id]
    new_field = TextInput.update(:key, event, field_state)
    {:cont, put_in(state, [:fields, field_id], new_field)}
  end

  def handle_event(%{type: :paste} = event, state) do
    field_id = Enum.at(@field_ids, state.focus_idx)
    field_state = state.fields[field_id]
    new_field = TextInput.update(:paste, event, field_state)
    {:cont, put_in(state, [:fields, field_id], new_field)}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    name_state = state.fields.name
    email_state = state.fields.email
    focused_field = Enum.at(@field_ids, state.focus_idx)

    panel_w = min(56, state.cols - 4)

    panel id: :main, title: "TextInput Demo", width: panel_w, height: 18,
          border: true, fg: Color.rgb(200, 200, 200), bg: Color.rgb(20, 20, 35) do

      text(content: "Tab to switch fields, Ctrl+C to quit", fg: Color.rgb(100, 100, 100), bg: Color.rgb(20, 20, 35))
      text(content: "")

      label(content: if(focused_field == :name, do: "> Name:", else: "  Name:"),
            fg: Color.rgb(100, 220, 100), bg: Color.rgb(20, 20, 35))
      input(
        id: :name,
        value: name_state.value,
        placeholder: name_state.placeholder,
        cursor_pos: name_state.cursor_pos,
        scroll_offset: name_state.scroll_offset,
        width: name_state.width,
        height: 1,
        bg: Color.rgb(40, 40, 60),
        fg: Color.rgb(200, 200, 200)
      )
      text(content: "")

      label(content: if(focused_field == :email, do: "> Email:", else: "  Email:"),
            fg: Color.rgb(100, 220, 100), bg: Color.rgb(20, 20, 35))
      input(
        id: :email,
        value: email_state.value,
        placeholder: email_state.placeholder,
        cursor_pos: email_state.cursor_pos,
        scroll_offset: email_state.scroll_offset,
        width: email_state.width,
        height: 1,
        bg: Color.rgb(40, 40, 60),
        fg: Color.rgb(200, 200, 200)
      )
      text(content: "")

      text(content: String.duplicate("─", panel_w - 4), fg: Color.rgb(60, 60, 80), bg: Color.rgb(20, 20, 35))

      text(content: " Name:  #{display_value(name_state.value)}",
           fg: Color.rgb(180, 180, 200), bg: Color.rgb(20, 20, 35))
      text(content: " Email: #{display_value(email_state.value)}",
           fg: Color.rgb(180, 180, 200), bg: Color.rgb(20, 20, 35))
      text(content: " Cursor: pos=#{current_field(state).cursor_pos} scroll=#{current_field(state).scroll_offset}",
           fg: Color.rgb(100, 100, 120), bg: Color.rgb(20, 20, 35))
    end
  end

  def focused_id(state), do: Enum.at(@field_ids, state.focus_idx)

  defp current_field(state) do
    field_id = Enum.at(@field_ids, state.focus_idx)
    state.fields[field_id]
  end

  defp display_value(""), do: "(empty)"
  defp display_value(v), do: v
end

ElixirOpentui.Demo.DemoRunner.run(TextInputDemo)
