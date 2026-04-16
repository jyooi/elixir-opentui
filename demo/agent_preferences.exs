defmodule AgentPreferences.PrefsApp do
  use ElixirOpentui.Component

  alias ElixirOpentui.Widgets.{Checkbox, Select}

  def init(_props) do
    %{
      save_clicked: false,
      last_action: nil
    }
  end

  def update(:save_clicked, _event, state) do
    %{state | save_clicked: true, last_action: :save_clicked}
  end

  def update(_msg, _event, state), do: state

  def render(_state) do
    import ElixirOpentui.View

    panel id: :prefs, border_title: "Preferences", width: 60, height: 18 do
      component(Select,
        id: :theme,
        options: ["Light", "Dark", "System"],
        selected: 2
      )

      component(Checkbox, id: :email_notify, label: "Email notifications", checked: false)
      component(Checkbox, id: :sms_notify, label: "SMS notifications", checked: false)
      component(Checkbox, id: :push_notify, label: "Push notifications", checked: false)

      button(id: :save, content: "Save", on_click: :save_clicked, width: 10, height: 1)
    end
  end
end

defmodule AgentPreferences.Driver do
  alias ElixirOpentui.Runtime

  def run do
    {:ok, rt} = Runtime.start_link(cols: 80, rows: 24, mode: :headless)
    Runtime.mount(rt, AgentPreferences.PrefsApp)

    IO.puts("=== Agent Preferences Demo ===\n")

    # 1. Initial snapshot + inventory
    snap = Runtime.snapshot(rt)
    ids = collect_ids(snap.root)
    IO.puts("Initial inventory: root=#{inspect(snap.root.type)} id=#{inspect(snap.root.id)} ids=#{inspect(ids)}")

    # 2. Verify initial state via find_widget
    theme0 = Runtime.find_widget(rt, :theme)
    IO.puts("Initial theme state: #{inspect(theme0.state)}")

    # 3. Change theme to "Dark" (index 1)
    :ok = Runtime.dispatch(rt, {:select_index, :theme, 1})
    theme1 = Runtime.find_widget(rt, :theme)
    IO.puts("After select_index(:theme, 1): selected=#{theme1.state.selected} option=#{Enum.at(theme1.state.options, theme1.state.selected)}")

    # 4. Enable only :push_notify
    :ok = Runtime.dispatch(rt, {:set_checked, :push_notify, true})

    # 5. Click save
    :ok = Runtime.dispatch(rt, {:click, :save})

    # 6. Final state check
    theme_final   = Runtime.find_widget(rt, :theme)
    email_final   = Runtime.find_widget(rt, :email_notify)
    sms_final     = Runtime.find_widget(rt, :sms_notify)
    push_final    = Runtime.find_widget(rt, :push_notify)
    app_state     = :sys.get_state(rt).app_state

    IO.puts("\n=== Final State ===")
    IO.puts("theme:        selected=#{theme_final.state.selected} (#{Enum.at(theme_final.state.options, theme_final.state.selected)})")
    IO.puts("email_notify: checked=#{email_final.state.checked}")
    IO.puts("sms_notify:   checked=#{sms_final.state.checked}")
    IO.puts("push_notify:  checked=#{push_final.state.checked}")
    IO.puts("app_state:    #{inspect(app_state)}")

    # 7. Verdict
    checks = [
      {"theme index = 1",                theme_final.state.selected == 1},
      {"push_notify checked",            push_final.state.checked == true},
      {"email_notify unchecked",         email_final.state.checked == false},
      {"sms_notify unchecked",           sms_final.state.checked == false},
      {"save_clicked fired in app",      app_state.save_clicked == true}
    ]

    IO.puts("\n=== Verdict ===")
    Enum.each(checks, fn {label, ok?} ->
      IO.puts("  [#{if ok?, do: "PASS", else: "FAIL"}] #{label}")
    end)

    if Enum.all?(checks, fn {_l, ok?} -> ok? end) do
      IO.puts("\n*** OVERALL: PASS ***")
      :ok
    else
      IO.puts("\n*** OVERALL: FAIL ***")
      System.halt(1)
    end
  end

  defp collect_ids(nil), do: []
  defp collect_ids(%{id: id, children: children}) do
    base = if is_nil(id), do: [], else: [id]
    base ++ Enum.flat_map(children, &collect_ids/1)
  end
end

AgentPreferences.Driver.run()
