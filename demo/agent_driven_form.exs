# Agent-Driven Form Demo
# Run: mix run demo/agent_driven_form.exs
#
# Simulates an AI agent filling out a Sign-In form via the semantic
# accessibility API (Runtime.snapshot / Runtime.dispatch). No ANSI,
# no keystroke plumbing — the agent reads widget state and mutates it.

defmodule AgentDrivenForm.App do
  use ElixirOpentui.Component

  alias ElixirOpentui.Widgets.{TextInput, Checkbox}

  def init(_props), do: %{submitted: false, submitted_with: nil}

  def update({:email_changed, _value}, _event, state), do: state
  def update({:password_changed, _value}, _event, state), do: state
  def update({:remember_changed, _value}, _event, state), do: state

  def update(:submit_clicked, _event, state) do
    %{state | submitted: true, submitted_with: :agent}
  end

  def update(_, _, state), do: state

  def render(_state) do
    import ElixirOpentui.View

    panel id: :form, border_title: "Sign In", width: 48, height: 14 do
      text(content: "Email")

      component(TextInput,
        id: :email,
        value: "",
        placeholder: "you@example.com",
        width: 30,
        on_change: :email_changed
      )

      text(content: "Password")

      component(TextInput,
        id: :password,
        value: "",
        placeholder: "hunter2",
        width: 30,
        on_change: :password_changed
      )

      component(Checkbox,
        id: :remember,
        label: "Remember me",
        checked: false,
        on_change: :remember_changed
      )

      button(id: :submit, label: "Submit", on_click: :submit_clicked, width: 10, height: 1)
    end
  end
end

defmodule AgentDrivenForm.Agent do
  @moduledoc """
  A tiny scripted "agent". Walks the snapshot tree, prints what it sees,
  dispatches actions, and reports on state changes.
  """

  alias ElixirOpentui.Runtime

  # --- Snapshot helpers ---

  def find_node(%{root: root}, id), do: find_node(root, id)
  def find_node(nil, _id), do: nil

  def find_node(%{id: node_id} = node, id) when node_id == id, do: node

  def find_node(%{children: children}, id) do
    Enum.find_value(children, &find_node(&1, id))
  end

  def find_node(_, _), do: nil

  # Flatten every meaningful widget so we can print a one-line inventory.
  # Note: Accessibility emits the root, AND (if the root is "meaningful",
  # e.g. a titled panel) the walker re-emits it as its own child. We
  # de-dup by (id, role) so the inventory reads cleanly.
  def flatten(%{root: root}) do
    root
    |> flatten_node()
    |> Enum.uniq_by(fn n -> {n.id, n.role, Map.get(n, :state)} end)
  end

  defp flatten_node(nil), do: []

  defp flatten_node(%{children: children} = node) do
    [Map.delete(node, :children) | Enum.flat_map(children, &flatten_node/1)]
  end

  # --- Pretty print ---

  def print_inventory(snap) do
    IO.puts("== widgets visible to agent ==")

    for node <- flatten(snap) do
      id = inspect(node.id)
      role = node.role
      state_str = format_state(node.state)
      focus = if node.focused, do: " [FOCUSED]", else: ""
      IO.puts("  #{String.pad_trailing(id, 12)} role=#{String.pad_trailing(to_string(role), 10)} #{state_str}#{focus}")
    end

    IO.puts("  focused_id=#{inspect(snap.focused_id)}")
    IO.puts("")
  end

  defp format_state(state) when map_size(state) == 0, do: ""

  defp format_state(state) do
    state
    |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v, limit: 30)}" end)
    |> Enum.join(" ")
  end

  # --- The agent loop ---

  def act(rt, label, action) do
    before_snap = Runtime.snapshot(rt)
    :ok = Runtime.dispatch(rt, action)
    after_snap = Runtime.snapshot(rt)

    IO.puts("-> #{label}")
    IO.puts("   action: #{inspect(action)}")
    report_diff(before_snap, after_snap)
    IO.puts("")
  end

  defp report_diff(before_snap, after_snap) do
    before_map = flatten(before_snap) |> Map.new(&{&1.id, &1})
    after_map = flatten(after_snap) |> Map.new(&{&1.id, &1})

    changes =
      for {id, a} <- after_map,
          b = Map.get(before_map, id),
          b != nil,
          b.state != a.state or b.focused != a.focused do
        {id, b, a}
      end

    if changes == [] do
      IO.puts("   (no observable state change)")
    else
      for {id, b, a} <- changes do
        if b.state != a.state do
          IO.puts("   #{inspect(id)} state: #{inspect(b.state)} -> #{inspect(a.state)}")
        end

        if b.focused != a.focused do
          IO.puts("   #{inspect(id)} focused: #{b.focused} -> #{a.focused}")
        end
      end
    end

    if before_snap.focused_id != after_snap.focused_id do
      IO.puts(
        "   focused_id: #{inspect(before_snap.focused_id)} -> #{inspect(after_snap.focused_id)}"
      )
    end
  end
end

# --- Run it ---

alias ElixirOpentui.Runtime
alias AgentDrivenForm.{App, Agent}

IO.puts("\n[1] Starting headless Runtime and mounting app...")
{:ok, rt} = Runtime.start_link(cols: 60, rows: 18)
:ok = Runtime.mount(rt, App)

IO.puts("\n[2] Initial snapshot:")
Agent.print_inventory(Runtime.snapshot(rt))

IO.puts("[3] Agent plan:")
IO.puts("    fill email, fill password, toggle remember-me, click submit\n")

Agent.act(rt, "focus email input", {:focus, :email})
Agent.act(rt, "type email", {:set_value, :email, "agent@example.com"})

Agent.act(rt, "focus password input", {:focus, :password})
Agent.act(rt, "type password", {:set_value, :password, "correct horse battery staple"})

Agent.act(rt, "focus remember-me", {:focus, :remember})
Agent.act(rt, "toggle remember-me", {:toggle, :remember})

Agent.act(rt, "click submit", {:click, :submit})

IO.puts("[4] Final snapshot:")
final = Runtime.snapshot(rt)
Agent.print_inventory(final)

# --- Verdict ---

email = Agent.find_node(final, :email)
password = Agent.find_node(final, :password)
remember = Agent.find_node(final, :remember)

email_ok = email && email.state.value == "agent@example.com"
password_ok = password && password.state.value == "correct horse battery staple"
remember_ok = remember && remember.state.checked == true

# on_click fires :submit_clicked, which the app captures in its own state.
# Observable via :sys.get_state (test-style introspection; a real app would
# reflect it in the snapshot by rendering a confirmation panel).
app_state = :sys.get_state(rt).app_state
submit_fired = app_state.submitted == true

IO.puts("[5] Verdict:")
IO.puts("    email value correct?    #{email_ok}  (#{inspect(email && email.state.value)})")
IO.puts("    password value correct? #{password_ok}  (#{inspect(password && password.state.value)})")
IO.puts("    remember-me checked?    #{remember_ok}  (#{inspect(remember && remember.state.checked)})")
IO.puts("    submit on_click fired?  #{submit_fired}  (app_state=#{inspect(app_state)})")

all_ok = email_ok and password_ok and remember_ok and submit_fired

IO.puts("")

if all_ok do
  IO.puts("PASS -- the form is in the expected state. The agent API worked.")
else
  IO.puts("FAIL -- something did not match the expected state.")
  System.halt(1)
end
