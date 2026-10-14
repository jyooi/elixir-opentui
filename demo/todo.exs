defmodule TodoApp do
  alias ElixirOpentui.Widgets.{TextInput, Checkbox, TabSelect, ScrollBox}
  alias ElixirOpentui.Color

  @filter_options [
    %{name: "All", description: "Show all todos"},
    %{name: "Active", description: "Show active only"},
    %{name: "Done", description: "Show completed only"}
  ]

  @filters [:all, :active, :done]

  def init(cols, rows) do
    panel_w = min(50, cols - 4)
    content_w = panel_w - 6

    %{
      cols: cols,
      rows: rows,
      todos: [],
      next_id: 1,
      focus_idx: 0,
      filter: :all,
      input:
        TextInput.init(%{
          id: :todo_input,
          placeholder: "What needs to be done?",
          width: content_w,
          on_submit: :add_todo
        }),
      tab:
        TabSelect.init(%{
          id: :filter_tabs,
          options: @filter_options,
          selected: 0,
          tab_width: 10,
          width: content_w,
          wrap_selection: true,
          show_description: false,
          show_underline: true,
          show_scroll_arrows: false
        }),
      scroll:
        ScrollBox.init(%{
          id: :todo_scroll,
          content_height: 0,
          height: max(rows - 16, 5)
        })
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true, meta: false}, _state), do: :quit

  def handle_event(%{type: :key, key: :tab, shift: true, meta: false}, state) do
    max_idx = max_focus_idx(state)
    new_idx = rem(state.focus_idx - 1 + max_idx + 1, max_idx + 1)
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key, key: :tab, meta: false}, state) do
    max_idx = max_focus_idx(state)
    new_idx = rem(state.focus_idx + 1, max_idx + 1)
    {:cont, %{state | focus_idx: new_idx}}
  end

  def handle_event(%{type: :key} = event, state) do
    {:cont, route_event(state.focus_idx, event, state)}
  end

  def handle_event(%{type: :paste} = event, state) do
    if state.focus_idx == 0 do
      {:cont, %{state | input: TextInput.update(:paste, event, state.input)}}
    else
      {:cont, state}
    end
  end

  def handle_event(%{type: :mouse, action: action} = event, state)
      when action in [:scroll_up, :scroll_down] do
    {:cont, %{state | scroll: ScrollBox.update(:mouse, event, state.scroll)}}
  end

  def handle_event(_event, state), do: {:cont, state}

  defp route_event(0, event, state) do
    new_input = TextInput.update(:key, event, state.input)

    case Enum.find(new_input._pending, fn {tag, _} -> tag == :add_todo end) do
      {:add_todo, value} when value != "" ->
        todo = %{id: state.next_id, text: String.trim(value), done: false}
        new_todos = state.todos ++ [todo]
        cleared_input = TextInput.update(:sync_value, %{value: ""}, %{new_input | _pending: []})

        %{
          state
          | todos: new_todos,
            next_id: state.next_id + 1,
            input: cleared_input,
            scroll: %{state.scroll | content_height: length(new_todos)}
        }

      _ ->
        %{state | input: %{new_input | _pending: []}}
    end
  end

  defp route_event(1, event, state) do
    new_tab = TabSelect.update(:key, event, state.tab)
    new_filter = Enum.at(@filters, new_tab.selected) || :all

    %{
      state
      | tab: %{new_tab | _pending: []},
        filter: new_filter,
        focus_idx: 1
    }
  end

  defp route_event(focus_idx, %{key: " "} = _event, state) when focus_idx >= 2 do
    toggle_todo(state, focus_idx)
  end

  defp route_event(focus_idx, %{key: key}, state) when focus_idx >= 2 and key in ["d", :delete] do
    delete_todo(state, focus_idx)
  end

  defp route_event(focus_idx, %{key: :up}, state) when focus_idx >= 2 do
    %{state | focus_idx: max(focus_idx - 1, 2)}
  end

  defp route_event(focus_idx, %{key: :down}, state) when focus_idx >= 2 do
    max_idx = max_focus_idx(state)
    %{state | focus_idx: min(focus_idx + 1, max_idx)}
  end

  defp route_event(_focus_idx, _event, state), do: state

  defp toggle_todo(state, focus_idx) do
    filtered = filtered_todos(state)

    case Enum.at(filtered, focus_idx - 2) do
      nil ->
        state

      todo ->
        new_todos =
          Enum.map(state.todos, fn t ->
            if t.id == todo.id, do: %{t | done: not t.done}, else: t
          end)

        %{state | todos: new_todos}
    end
  end

  defp delete_todo(state, focus_idx) do
    filtered = filtered_todos(state)

    case Enum.at(filtered, focus_idx - 2) do
      nil ->
        state

      todo ->
        new_todos = Enum.reject(state.todos, &(&1.id == todo.id))
        new_filtered_count = length(filtered) - 1
        new_focus = min(focus_idx, 2 + max(new_filtered_count - 1, 0))
        new_focus = if new_filtered_count == 0, do: 0, else: new_focus

        %{
          state
          | todos: new_todos,
            focus_idx: new_focus,
            scroll: %{state.scroll | content_height: length(new_todos)}
        }
    end
  end

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(20, 20, 35)
    fg = Color.rgb(200, 200, 200)
    dim = Color.rgb(100, 100, 100)
    accent = Color.rgb(100, 200, 255)
    green = Color.rgb(100, 220, 100)
    divider_fg = Color.rgb(60, 60, 80)
    panel_w = min(50, state.cols - 4)
    content_w = panel_w - 6

    filtered = filtered_todos(state)
    ti = state.input
    tabs = state.tab

    done_count = Enum.count(state.todos, & &1.done)
    total_count = length(state.todos)

    viewport_h = state.scroll.viewport_height
    scroll_y = state.scroll.scroll_y

    input_label = if(state.focus_idx == 0, do: "> Add todo:", else: "  Add todo:")
    filter_label = if(state.focus_idx == 1, do: "> Filter:", else: "  Filter:")
    status_fg = if done_count == total_count and total_count > 0, do: green, else: fg
    status_text = " #{done_count}/#{total_count} done"
    divider = String.duplicate("─", content_w)

    empty_msg =
      case state.filter do
        :all -> "No todos yet. Type one above!"
        :active -> "No active todos."
        :done -> "No completed todos."
      end

    todo_lines =
      for {todo, vis_idx} <- Enum.with_index(filtered) do
        todo_focus_idx = 2 + vis_idx
        is_focused = state.focus_idx == todo_focus_idx
        prefix = if is_focused, do: "> ", else: "  "
        check_char = if todo.done, do: "[x]", else: "[ ]"
        line_fg = if todo.done, do: dim, else: fg
        line = String.slice("#{prefix}#{check_char} #{todo.text}", 0, content_w)
        line_bg = if is_focused, do: Color.rgb(40, 40, 60), else: bg
        {line, line_fg, line_bg}
      end

    panel id: :main, title: "Todo List", width: panel_w, border: true, fg: fg, bg: bg do
      text(content: "Tab: next | Shift+Tab: prev | Ctrl+C: quit", fg: dim, bg: bg)
      text(content: "Enter: add | Space: toggle | d: delete", fg: dim, bg: bg)
      text(content: "")

      label(content: input_label, fg: accent, bg: bg)

      input(
        id: :todo_input,
        value: ti.value,
        placeholder: ti.placeholder,
        cursor_pos: ti.cursor_pos,
        scroll_offset: ti.scroll_offset,
        width: ti.width,
        height: 1,
        bg: Color.rgb(40, 40, 60),
        fg: fg
      )

      text(content: "")

      label(content: filter_label, fg: accent, bg: bg)

      tab_select(
        id: :filter_tabs,
        options: @filter_options,
        selected: tabs.selected,
        scroll_offset: tabs.scroll_offset,
        tab_width: tabs.tab_width,
        width: content_w,
        show_description: false,
        show_underline: true,
        show_scroll_arrows: false
      )

      text(content: "")

      text(content: divider, fg: divider_fg, bg: bg)

      if todo_lines == [] do
        text(content: "  #{empty_msg}", fg: dim, bg: bg)
      else
        scroll_box id: :todo_scroll, scroll_y: scroll_y, height: viewport_h do
          for {line, line_fg, line_bg} <- todo_lines do
            text(content: line, fg: line_fg, bg: line_bg)
          end
        end
      end

      text(content: divider, fg: divider_fg, bg: bg)

      text(content: status_text, fg: status_fg, bg: bg)
    end
  end

  def focused_id(state) do
    case state.focus_idx do
      0 -> :todo_input
      1 -> :filter_tabs
      _ -> :todo_scroll
    end
  end

  defp filtered_todos(state) do
    case state.filter do
      :all -> state.todos
      :active -> Enum.filter(state.todos, &(not &1.done))
      :done -> Enum.filter(state.todos, & &1.done)
    end
  end

  defp max_focus_idx(state) do
    filtered_count = length(filtered_todos(state))
    max(1, 1 + filtered_count)
  end
end

ElixirOpentui.DemoRunner.run(TodoApp)
