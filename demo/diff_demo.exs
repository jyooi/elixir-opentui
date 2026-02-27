# Diff Interactive Demo
# Run: mix run demo/diff_demo.exs
#
# Diff display with unified and split views.
# V to toggle view, C to cycle examples, L to toggle line numbers.
# Up/Down/PgUp/PgDown/Home/End to scroll.
# Press Ctrl+C to exit.

defmodule DiffDemo do
  alias ElixirOpentui.Widgets.Diff
  alias ElixirOpentui.Color

  @viewport 18

  # Multiple diff examples to cycle through (like OpenTUI's diff-demo)
  @examples [
    %{
      name: "Elixir — Add Mailer",
      diff: """
      --- a/lib/my_app/accounts.ex
      +++ b/lib/my_app/accounts.ex
      @@ -1,15 +1,20 @@
       defmodule MyApp.Accounts do
      -  alias MyApp.Repo
      +  alias MyApp.{Repo, Mailer}
         alias MyApp.Accounts.User
      +  alias MyApp.Accounts.Session

      -  def create_user(attrs) do
      +  @max_attempts 5
      +
      +  def create_user(attrs \\\\ %{}) do
           %User{}
      -    |> User.changeset(attrs)
      +    |> User.registration_changeset(attrs)
           |> Repo.insert()
      +    |> notify_admin()
         end

      -  def get_user(id), do: Repo.get(User, id)
      +  def get_user!(id), do: Repo.get!(User, id)
      +  def get_user(id), do: Repo.get(User, id) |> ok_or_not_found()

         def list_users do
           Repo.all(User)
      @@ -20,8 +25,14 @@
         def update_user(%User{} = user, attrs) do
           user
      -    |> User.changeset(attrs)
      +    |> User.update_changeset(attrs)
           |> Repo.update()
         end
      +
      +  defp notify_admin({:ok, user} = result) do
      +    Mailer.send_new_user_notification(user)
      +    result
      +  end
      +
      +  defp notify_admin(error), do: error
       end
      """
    },
    %{
      name: "Config — Add Features",
      diff: """
      --- a/config/config.exs
      +++ b/config/config.exs
      @@ -1,9 +1,15 @@
       import Config

      -config :my_app, MyApp.Repo,
      -  database: "my_app_dev",
      -  hostname: "localhost",
      -  pool_size: 10
      +config :my_app, MyApp.Repo,
      +  database: "my_app_dev",
      +  hostname: "localhost",
      +  pool_size: 10,
      +  ssl: true,
      +  timeout: 30_000

      -config :my_app, :env, :dev
      +config :my_app, :env, :dev
      +
      +config :my_app, :features,
      +  analytics: true,
      +  logging: :verbose
       end
      """
    },
    %{
      name: "Router — New Endpoints",
      diff: """
      --- a/lib/my_app_web/router.ex
      +++ b/lib/my_app_web/router.ex
      @@ -10,11 +10,21 @@
         scope "/api", MyAppWeb do
           pipe_through :api

           resources "/users", UserController, only: [:index, :show, :create]
      -    resources "/posts", PostController, only: [:index, :show]
      +    resources "/posts", PostController, only: [:index, :show, :create, :update, :delete]
      +
      +    scope "/admin" do
      +      pipe_through :admin_auth
      +      resources "/settings", SettingsController
      +      get "/metrics", MetricsController, :index
      +    end
         end

         scope "/", MyAppWeb do
           pipe_through :browser

           get "/", PageController, :home
      +    live "/dashboard", DashboardLive
      +    live "/dashboard/:section", DashboardLive, :section
         end
      """
    },
    %{
      name: "Test — Add Cases",
      diff: """
      --- a/test/my_app/accounts_test.exs
      +++ b/test/my_app/accounts_test.exs
      @@ -5,8 +5,28 @@
         describe "create_user/1" do
           test "creates user with valid attrs" do
             attrs = %{name: "Alice", email: "alice@example.com"}
      -      assert {:ok, user} = Accounts.create_user(attrs)
      -      assert user.name == "Alice"
      +      assert {:ok, %User{} = user} = Accounts.create_user(attrs)
      +      assert user.name == attrs.name
      +      assert user.email == attrs.email
      +    end
      +
      +    test "returns error with invalid email" do
      +      attrs = %{name: "Bob", email: "not-an-email"}
      +      assert {:error, changeset} = Accounts.create_user(attrs)
      +      assert "is not a valid email" in errors_on(changeset).email
      +    end
      +
      +    test "returns error with duplicate email" do
      +      attrs = %{name: "Alice", email: "alice@example.com"}
      +      assert {:ok, _user} = Accounts.create_user(attrs)
      +      assert {:error, changeset} = Accounts.create_user(attrs)
      +      assert "has already been taken" in errors_on(changeset).email
      +    end
      +
      +    test "hashes the password" do
      +      attrs = %{name: "Carol", email: "carol@example.com", password: "secret123"}
      +      assert {:ok, user} = Accounts.create_user(attrs)
      +      assert user.password_hash != "secret123"
      +      assert Bcrypt.verify_pass("secret123", user.password_hash)
           end
         end
      """
    },
    %{
      name: "Mix — Deps Update",
      diff: """
      --- a/mix.exs
      +++ b/mix.exs
      @@ -20,10 +20,14 @@
         defp deps do
           [
      -      {:phoenix, "~> 1.7.0"},
      -      {:phoenix_live_view, "~> 0.20.0"},
      +      {:phoenix, "~> 1.8.0"},
      +      {:phoenix_live_view, "~> 1.0.0"},
             {:ecto_sql, "~> 3.11"},
             {:postgrex, ">= 0.0.0"},
      -      {:jason, "~> 1.2"}
      +      {:jason, "~> 1.4"},
      +      {:bandit, "~> 1.5"},
      +      {:oban, "~> 2.18"},
      +      {:req, "~> 0.5"},
      +      {:floki, "~> 0.36"}
           ]
         end
      """
    }
  ]

  def init(cols, rows) do
    first = hd(@examples)

    %{
      cols: cols,
      rows: rows,
      example_index: 0,
      show_line_numbers: true,
      diff: Diff.init(%{
        id: :diff_view,
        diff: String.trim(first.diff),
        view: :unified,
        scroll_offset: 0,
        visible_lines: @viewport,
        show_line_numbers: true
      })
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true}, _state), do: :quit

  # V to toggle view (like OpenTUI)
  def handle_event(%{type: :key, key: "v", ctrl: false, meta: false}, state) do
    new_view = if state.diff.view == :unified, do: :split, else: :unified
    new_diff = Diff.update({:set_view, new_view}, nil, state.diff)
    {:cont, %{state | diff: new_diff}}
  end

  # C to cycle content examples (like OpenTUI)
  def handle_event(%{type: :key, key: "c", ctrl: false, meta: false}, state) do
    new_idx = rem(state.example_index + 1, length(@examples))
    example = Enum.at(@examples, new_idx)

    new_diff = Diff.init(%{
      id: :diff_view,
      diff: String.trim(example.diff),
      view: state.diff.view,
      scroll_offset: 0,
      visible_lines: @viewport,
      show_line_numbers: state.show_line_numbers
    })

    {:cont, %{state | example_index: new_idx, diff: new_diff}}
  end

  # L to toggle line numbers (like OpenTUI)
  def handle_event(%{type: :key, key: "l", ctrl: false, meta: false}, state) do
    show = !state.show_line_numbers
    new_diff = Diff.update({:set_show_line_numbers, show}, nil, state.diff)
    {:cont, %{state | show_line_numbers: show, diff: new_diff}}
  end

  def handle_event(%{type: :key} = event, state) do
    new_diff = Diff.update(:key, event, state.diff)
    {:cont, %{state | diff: new_diff}}
  end

  def handle_event(_event, state), do: {:cont, state}

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(13, 17, 23)
    fg = Color.rgb(230, 237, 243)
    panel_w = min(80, state.cols - 4)

    diff_state = state.diff
    diff_lines = Diff.build_lines(diff_state)
    example = Enum.at(@examples, state.example_index)
    view_label = if diff_state.view == :unified, do: "Unified", else: "Split"
    line_nums = if state.show_line_numbers, do: "ON", else: "OFF"
    status_str = "#{example.name} (#{state.example_index + 1}/#{length(@examples)}) | View: #{view_label} | Lines: #{line_nums}"

    panel id: :main, title: "Diff Demo — #{view_label}",
          width: panel_w, height: @viewport + 7,
          border: true, fg: fg, bg: bg do

      text(content: "V Toggle view | C Cycle examples | L Toggle line numbers | ↑/↓ Scroll", fg: Color.rgb(136, 136, 136), bg: bg)
      text(content: "Ctrl+C to quit", fg: Color.rgb(136, 136, 136), bg: bg)
      text(content: "")

      diff(
        id: :diff_view,
        diff: diff_state.diff,
        view: diff_state.view,
        lines: diff_lines,
        line_count: length(diff_lines),
        scroll_offset: diff_state.scroll_offset,
        visible_lines: @viewport,
        show_line_numbers: state.show_line_numbers,
        width: panel_w - 4
      )

      text(content: "")
      text(content: String.duplicate("─", panel_w - 4), fg: Color.rgb(60, 60, 80), bg: bg)
      text(content: " #{status_str}", fg: Color.rgb(165, 214, 255), bg: bg)
    end
  end

  def focused_id(_state), do: :diff_view
end

ElixirOpentui.Demo.DemoRunner.run(DiffDemo)
