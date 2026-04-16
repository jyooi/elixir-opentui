defmodule ElixirOpentui.AccessibilityTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Runtime
  alias ElixirOpentui.Widgets.{TextInput, Checkbox}

  defmodule AgentApp do
    use ElixirOpentui.Component

    def init(_props), do: %{}
    def update(_, _, state), do: state

    def render(_state) do
      import ElixirOpentui.View

      panel id: :root, border_title: "Login", width: 40, height: 10 do
        text(content: "Email")
        component(TextInput, id: :email, value: "", placeholder: "you@example.com", width: 20)
        component(Checkbox, id: :remember, label: "Remember me", checked: false)
        button(id: :submit, content: "Submit", width: 10, height: 1)
      end
    end
  end

  defp mount_app do
    {:ok, rt} = Runtime.start_link([])
    :ok = Runtime.mount(rt, AgentApp)
    rt
  end

  defp find_node(snapshot, id) do
    walk = fn node, walk ->
      if node.id == id, do: node, else: Enum.find_value(node.children, &walk.(&1, walk))
    end

    walk.(snapshot.root, walk)
  end

  test "snapshot prunes structural boxes but keeps titled panel, text labels, and widgets" do
    rt = mount_app()
    snap = Runtime.snapshot(rt)

    # Panel "Login" is the only meaningful top-level node — it becomes root.
    assert snap.root.role == :container
    assert snap.root.state == %{title: "Login"}

    roles = Enum.map(snap.root.children, & &1.role)
    assert :text in roles
    assert :textbox in roles
    assert :checkbox in roles
    assert :button in roles
  end

  test "set_value mutates TextInput and is visible in next snapshot" do
    rt = mount_app()
    :ok = Runtime.dispatch(rt, {:set_value, :email, "hi@example.com"})

    snap = Runtime.snapshot(rt)

    assert find_node(snap, :email).state == %{
             value: "hi@example.com",
             placeholder: "you@example.com"
           }
  end

  test "toggle flips Checkbox checked state" do
    rt = mount_app()
    assert find_node(Runtime.snapshot(rt), :remember).state.checked == false

    :ok = Runtime.dispatch(rt, {:toggle, :remember})
    assert find_node(Runtime.snapshot(rt), :remember).state.checked == true
  end

  test "focus action updates focused_id visible in snapshot" do
    rt = mount_app()
    :ok = Runtime.dispatch(rt, {:focus, :email})

    snap = Runtime.snapshot(rt)
    assert snap.focused_id == :email
    assert find_node(snap, :email).focused == true
  end

  test "key passthrough reaches the focused widget" do
    rt = mount_app()
    :ok = Runtime.dispatch(rt, {:focus, :email})

    for k <- ["a", "b"] do
      :ok =
        Runtime.dispatch(
          rt,
          {:key, %{type: :key, key: k, meta: false, ctrl: false, alt: false, shift: false}}
        )
    end

    snap = Runtime.snapshot(rt)
    assert find_node(snap, :email).state.value == "ab"
  end

  test "label resolution: checkbox picks up label from widget state, text from content attr" do
    rt = mount_app()
    snap = Runtime.snapshot(rt)

    assert find_node(snap, :remember).state.label == "Remember me"

    text_node = Enum.find(snap.root.children, &(&1.role == :text))
    assert text_node.state.content == "Email"
  end

  test "find_widget is a one-call convenience on Runtime" do
    rt = mount_app()
    :ok = Runtime.dispatch(rt, {:set_value, :email, "foo"})

    node = Runtime.find_widget(rt, :email)
    assert node.state.value == "foo"
    assert Runtime.find_widget(rt, :nonexistent) == nil
  end

  defmodule ClickApp do
    use ElixirOpentui.Component

    def init(_), do: %{clicks: 0}
    def update(:bump, _event, state), do: %{state | clicks: state.clicks + 1}
    def update(_, _, state), do: state

    def render(_) do
      import ElixirOpentui.View

      box id: :root, width: 20, height: 5 do
        button(id: :go, label: "Go", on_click: :bump, width: 10, height: 1)
      end
    end
  end

  test ":click fires a :button's on_click attr as an app message" do
    {:ok, rt} = Runtime.start_link([])
    :ok = Runtime.mount(rt, ClickApp)

    :ok = Runtime.dispatch(rt, {:click, :go})
    :ok = Runtime.dispatch(rt, {:click, :go})

    assert :sys.get_state(rt).app_state == %{clicks: 2}
  end

  defmodule FormApp do
    use ElixirOpentui.Component

    alias ElixirOpentui.Widgets.{TextInput, Checkbox, Select}

    def init(_), do: %{email: "", role: nil, remember: false}
    def update({:email_changed, v}, _e, s), do: %{s | email: v}
    def update({:role_changed, v}, _e, s), do: %{s | role: v}
    def update({:remember_changed, v}, _e, s), do: %{s | remember: v}
    def update(_, _, s), do: s

    def render(_) do
      import ElixirOpentui.View

      box id: :root, width: 40, height: 10 do
        component(TextInput, id: :email, value: "", on_change: :email_changed)

        component(Select,
          id: :role,
          options: ["A", "B", "C"],
          selected: 0,
          on_change: :role_changed
        )

        component(Checkbox,
          id: :remember,
          label: "R",
          checked: false,
          on_change: :remember_changed
        )
      end
    end
  end

  test "semantic actions fire on_change so app-level state tracks widget changes" do
    {:ok, rt} = Runtime.start_link([])
    :ok = Runtime.mount(rt, FormApp)

    :ok = Runtime.dispatch(rt, {:set_value, :email, "hi@x"})
    :ok = Runtime.dispatch(rt, {:select_index, :role, 2})
    :ok = Runtime.dispatch(rt, {:toggle, :remember})

    assert :sys.get_state(rt).app_state == %{email: "hi@x", role: 2, remember: true}
  end

  test "real Enter key on a focused :button also fires on_click" do
    {:ok, rt} = Runtime.start_link([])
    :ok = Runtime.mount(rt, ClickApp)

    :ok = Runtime.dispatch(rt, {:focus, :go})

    :ok =
      Runtime.dispatch(
        rt,
        {:key, %{type: :key, key: :enter, ctrl: false, alt: false, shift: false, meta: false}}
      )

    assert :sys.get_state(rt).app_state == %{clicks: 1}
  end
end
