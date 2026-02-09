# Checkbox Interactive Demo
# Run: mix run demo/checkbox_demo.exs
#
# Four checkboxes with Tab navigation.
# Space or Enter to toggle, Ctrl+C to exit.

defmodule CheckboxDemo do
  alias ElixirOpentui.Widgets.Checkbox
  alias ElixirOpentui.Color

  @items [
    {:notifications, "Notifications"},
    {:dark_mode, "Dark mode"},
    {:auto_save, "Auto-save"},
    {:line_numbers, "Line numbers"}
  ]

  def init(cols, rows) do
    fields =
      @items
      |> Enum.map(fn {id, label} ->
        {id, Checkbox.init(%{id: id, label: label, checked: false})}
      end)
      |> Map.new()

    %{cols: cols, rows: rows, focus_idx: 0, fields: fields}
  end

  def handle_event(%{type: :key, key: "c", ctrl: true}, _state), do: :quit

  def handle_event(%{type: :key, key: :tab, shift: true}, state) do
    new_idx = rem(state.focus_idx - 1 + length(@items), length(@items))
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key, key: :tab}, state) do
    new_idx = rem(state.focus_idx + 1, length(@items))
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key, key: :down}, state) do
    new_idx = min(state.focus_idx + 1, length(@items) - 1)
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key, key: :up}, state) do
    new_idx = max(state.focus_idx - 1, 0)
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key} = event, state) do
    {id, _label} = Enum.at(@items, state.focus_idx)
    field_state = state.fields[id]
    new_field = Checkbox.update(:key, event, field_state)
    {:cont, put_in(state, [:fields, id], new_field)}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(20, 20, 35)
    fg = Color.rgb(200, 200, 200)
    panel_w = min(48, state.cols - 4)
    {focused_id, _} = Enum.at(@items, state.focus_idx)

    checked_items =
      @items
      |> Enum.filter(fn {id, _} -> state.fields[id].checked end)
      |> Enum.map(fn {_, label} -> label end)

    summary = if checked_items == [], do: "(none)", else: Enum.join(checked_items, ", ")

    panel id: :main, title: "Checkbox Demo", width: panel_w, height: 16,
          border: true, fg: fg, bg: bg do

      text(content: "Tab/Arrows to navigate, Space to toggle", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "Ctrl+C to quit", fg: Color.rgb(100, 100, 100), bg: bg)
      text(content: "")

      for {id, _label} <- @items do
        cb_state = state.fields[id]
        prefix = if id == focused_id, do: "> ", else: "  "

        checkbox(
          id: id,
          checked: cb_state.checked,
          label: prefix <> cb_state.label,
          fg: fg,
          bg: bg
        )
      end

      text(content: "")
      text(content: String.duplicate("─", panel_w - 4), fg: Color.rgb(60, 60, 80), bg: bg)
      text(content: " Enabled: #{summary}", fg: Color.rgb(180, 180, 200), bg: bg)
      text(content: " Count: #{length(checked_items)}/#{length(@items)}", fg: Color.rgb(100, 100, 120), bg: bg)
    end
  end

  def focused_id(state) do
    {id, _} = Enum.at(@items, state.focus_idx)
    id
  end
end

ElixirOpentui.DemoRunner.run(CheckboxDemo)
