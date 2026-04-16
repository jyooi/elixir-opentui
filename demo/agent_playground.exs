# Agent Playground — a long-running Runtime exposed over TCP so an
# external agent can drive it interactively.
#
# Run: mix run --no-halt demo/agent_playground.exs
# Port: 4040
#
# Protocol (one command per line, response one line):
#   snapshot            -> inspect()'d snapshot map
#   find <id>           -> inspect()'d single widget node (or "nil")
#   appstate            -> inspect()'d app_state
#   dispatch <action>   -> "ok" (action is an Elixir term, e.g. {:toggle, :remember})
#   quit                -> closes this connection
#
# Nothing here is production-grade — it's deliberately small so an agent
# can use it without Plug/Phoenix/etc.

defmodule AgentPlayground.LoginApp do
  use ElixirOpentui.Component

  alias ElixirOpentui.Widgets.{TextInput, Checkbox, Select}

  def init(_props) do
    %{
      submitted: false,
      submitted_payload: nil,
      email: "",
      password: "",
      role_index: 2,
      remember: false
    }
  end

  def update({:email_changed, v}, _e, s), do: %{s | email: v}
  def update({:password_changed, v}, _e, s), do: %{s | password: v}
  def update({:role_changed, idx}, _e, s), do: %{s | role_index: idx}
  def update({:remember_changed, v}, _e, s), do: %{s | remember: v}

  def update(:login_clicked, _e, s) do
    %{
      s
      | submitted: true,
        submitted_payload: %{
          email: s.email,
          password_length: String.length(s.password),
          role_index: s.role_index,
          remember: s.remember
        }
    }
  end

  def update(_, _, state), do: state

  def render(_state) do
    import ElixirOpentui.View

    panel id: :login, border_title: "Sign In", width: 50, height: 18 do
      text(content: "Email")

      component(TextInput,
        id: :email,
        value: "",
        placeholder: "you@example.com",
        width: 32,
        on_change: :email_changed
      )

      text(content: "Password")

      component(TextInput,
        id: :password,
        value: "",
        placeholder: "(min 8 chars)",
        width: 32,
        on_change: :password_changed
      )

      text(content: "Role")

      component(Select,
        id: :role,
        options: ["Admin", "User", "Guest"],
        selected: 2,
        visible_count: 3,
        on_change: :role_changed
      )

      component(Checkbox,
        id: :remember,
        label: "Remember me",
        checked: false,
        on_change: :remember_changed
      )

      button(id: :login, label: "Login", on_click: :login_clicked, width: 10, height: 1)
    end
  end
end

defmodule AgentPlayground.Bridge do
  @port 4040

  def start(rt) do
    {:ok, listen} =
      :gen_tcp.listen(@port, [:binary, packet: :line, active: false, reuseaddr: true])

    IO.puts("[bridge] listening on localhost:#{@port}")
    accept_loop(listen, rt)
  end

  defp accept_loop(listen, rt) do
    {:ok, sock} = :gen_tcp.accept(listen)
    {:ok, pid} = Task.start(fn -> handle(sock, rt) end)
    :gen_tcp.controlling_process(sock, pid)
    accept_loop(listen, rt)
  end

  defp handle(sock, rt) do
    case :gen_tcp.recv(sock, 0, 120_000) do
      {:ok, line} ->
        response = process(String.trim(line), rt)
        :gen_tcp.send(sock, response <> "\n")
        handle(sock, rt)

      {:error, _} ->
        :ok
    end
  end

  defp process("snapshot", rt) do
    rt |> ElixirOpentui.Runtime.snapshot() |> inspect(pretty: true, limit: :infinity)
  end

  defp process("find " <> rest, rt) do
    id = parse_id(String.trim(rest))
    rt |> ElixirOpentui.Runtime.find_widget(id) |> inspect(pretty: true, limit: :infinity)
  end

  defp process("appstate", rt) do
    :sys.get_state(rt).app_state |> inspect(pretty: true, limit: :infinity)
  end

  defp process("dispatch " <> action_str, rt) do
    {action, _} = Code.eval_string(action_str)
    :ok = ElixirOpentui.Runtime.dispatch(rt, action)
    "ok"
  rescue
    e -> "ERROR: #{Exception.message(e)}"
  end

  defp process("quit", _rt), do: "bye"

  defp process(other, _rt), do: "ERROR: unknown command: #{inspect(other)}"

  # Network input — never `String.to_atom`, or an agent can exhaust the atom
  # table one `find <uuid>` at a time. All widget IDs in LoginApp are atoms
  # that already exist once the module is compiled, so `to_existing_atom`
  # covers the real cases; anything else falls through as a string and
  # `Accessibility.find_node` (which matches via `==`) cleanly returns nil.
  defp parse_id(":" <> name), do: parse_id(name)

  defp parse_id(name) do
    String.to_existing_atom(name)
  rescue
    ArgumentError -> name
  end
end

{:ok, rt} = ElixirOpentui.Runtime.start_link([])
:ok = ElixirOpentui.Runtime.mount(rt, AgentPlayground.LoginApp)

IO.puts("[app] LoginApp mounted, Runtime pid=#{inspect(rt)}")
AgentPlayground.Bridge.start(rt)
