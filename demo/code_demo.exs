# Code Interactive Demo
# Run: mix run demo/code_demo.exs
#
# Syntax-highlighted code display with line numbers.
# Left/Right to cycle examples, L to toggle line numbers.
# Up/Down/PgUp/PgDown/Home/End to scroll.
# Press Ctrl+C to exit.

defmodule CodeDemo do
  alias ElixirOpentui.Widgets.Code
  alias ElixirOpentui.Color

  @viewport 18

  # Multiple code examples to cycle through (like OpenTUI's code-demo)
  @examples [
    %{
      name: "Elixir — GenServer",
      filetype: "elixir",
      code: ~S'''
      defmodule MyApp.Cache do
        @moduledoc """
        An in-memory cache with TTL support.
        Uses GenServer for concurrent access.
        """

        use GenServer

        @default_ttl :timer.minutes(5)

        # --- Client API ---

        def start_link(opts \\ []) do
          name = Keyword.get(opts, :name, __MODULE__)
          GenServer.start_link(__MODULE__, opts, name: name)
        end

        def get(server \\ __MODULE__, key) do
          GenServer.call(server, {:get, key})
        end

        def put(server \\ __MODULE__, key, value, ttl \\ @default_ttl) do
          GenServer.cast(server, {:put, key, value, ttl})
        end

        def delete(server \\ __MODULE__, key) do
          GenServer.cast(server, {:delete, key})
        end

        # --- Server Callbacks ---

        @impl true
        def init(_opts) do
          schedule_cleanup()
          {:ok, %{entries: %{}}}
        end

        @impl true
        def handle_call({:get, key}, _from, state) do
          result =
            case Map.get(state.entries, key) do
              nil -> nil
              {value, expires_at} ->
                if System.monotonic_time(:millisecond) < expires_at,
                  do: value,
                  else: nil
            end
          {:reply, result, state}
        end

        @impl true
        def handle_cast({:put, key, value, ttl}, state) do
          expires_at = System.monotonic_time(:millisecond) + ttl
          entries = Map.put(state.entries, key, {value, expires_at})
          {:noreply, %{state | entries: entries}}
        end

        def handle_cast({:delete, key}, state) do
          {:noreply, %{state | entries: Map.delete(state.entries, key)}}
        end

        @impl true
        def handle_info(:cleanup, state) do
          now = System.monotonic_time(:millisecond)
          entries = Map.reject(state.entries, fn {_k, {_v, exp}} -> now >= exp end)
          schedule_cleanup()
          {:noreply, %{state | entries: entries}}
        end

        defp schedule_cleanup do
          Process.send_after(self(), :cleanup, :timer.seconds(30))
        end
      end
      '''
    },
    %{
      name: "Elixir — Pipeline",
      filetype: "elixir",
      code: ~S'''
      defmodule MyApp.DataPipeline do
        @moduledoc "ETL pipeline with streaming and error handling."

        require Logger

        @batch_size 1000

        def run(source_path, opts \\ []) do
          batch_size = Keyword.get(opts, :batch_size, @batch_size)
          output = Keyword.get(opts, :output, :stdout)

          source_path
          |> File.stream!([], :line)
          |> Stream.map(&String.trim/1)
          |> Stream.reject(&(&1 == ""))
          |> Stream.map(&parse_record/1)
          |> Stream.filter(&match?({:ok, _}, &1))
          |> Stream.map(fn {:ok, record} -> record end)
          |> Stream.map(&transform/1)
          |> Stream.chunk_every(batch_size)
          |> Stream.each(fn batch ->
            case load_batch(batch, output) do
              :ok -> Logger.info("Loaded batch of #{length(batch)} records")
              {:error, reason} -> Logger.error("Batch failed: #{inspect(reason)}")
            end
          end)
          |> Stream.run()
        end

        defp parse_record(line) do
          case Jason.decode(line) do
            {:ok, data} -> {:ok, data}
            {:error, _} -> {:error, :invalid_json}
          end
        end

        defp transform(record) do
          record
          |> Map.update("timestamp", nil, &parse_timestamp/1)
          |> Map.update("amount", 0, &normalize_amount/1)
          |> Map.put("processed_at", DateTime.utc_now() |> DateTime.to_iso8601())
        end

        defp parse_timestamp(nil), do: nil
        defp parse_timestamp(ts) when is_binary(ts) do
          case DateTime.from_iso8601(ts) do
            {:ok, dt, _} -> dt
            _ -> nil
          end
        end

        defp normalize_amount(amt) when is_number(amt), do: Float.round(amt / 1.0, 2)
        defp normalize_amount(amt) when is_binary(amt) do
          case Float.parse(amt) do
            {val, _} -> Float.round(val, 2)
            :error -> 0.0
          end
        end
        defp normalize_amount(_), do: 0.0

        defp load_batch(batch, :stdout) do
          Enum.each(batch, &IO.inspect/1)
          :ok
        end

        defp load_batch(batch, {:file, path}) do
          lines = Enum.map(batch, &(Jason.encode!(&1) <> "\n"))
          File.write(path, lines, [:append])
        end
      end
      '''
    },
    %{
      name: "Elixir — LiveView",
      filetype: "elixir",
      code: ~S'''
      defmodule MyAppWeb.DashboardLive do
        use MyAppWeb, :live_view

        alias MyApp.Metrics

        @refresh_interval :timer.seconds(5)

        @impl true
        def mount(_params, _session, socket) do
          if connected?(socket) do
            :timer.send_interval(@refresh_interval, :refresh)
          end

          {:ok,
           socket
           |> assign(:page_title, "Dashboard")
           |> assign(:metrics, Metrics.current())
           |> assign(:chart_data, Metrics.history(hours: 24))
           |> assign(:filter, :all)}
        end

        @impl true
        def handle_event("filter", %{"type" => type}, socket) do
          filter = String.to_existing_atom(type)
          chart_data = Metrics.history(hours: 24, filter: filter)

          {:noreply,
           socket
           |> assign(:filter, filter)
           |> assign(:chart_data, chart_data)}
        end

        def handle_event("export", _params, socket) do
          csv = Metrics.export_csv(socket.assigns.chart_data)

          {:noreply,
           socket
           |> push_event("download", %{
             data: csv,
             filename: "metrics_#{Date.utc_today()}.csv",
             content_type: "text/csv"
           })}
        end

        @impl true
        def handle_info(:refresh, socket) do
          {:noreply,
           socket
           |> assign(:metrics, Metrics.current())
           |> assign(:chart_data, Metrics.history(
             hours: 24,
             filter: socket.assigns.filter
           ))}
        end

        @impl true
        def render(assigns) do
          ~H"""
          <div class="dashboard">
            <.header>
              <%= @page_title %>
              <:actions>
                <.button phx-click="export">Export CSV</.button>
              </:actions>
            </.header>

            <div class="grid grid-cols-3 gap-4">
              <.stat_card
                title="Requests/sec"
                value={@metrics.rps}
                trend={@metrics.rps_trend}
              />
              <.stat_card
                title="Avg Latency"
                value={"#{@metrics.avg_latency}ms"}
                trend={@metrics.latency_trend}
              />
              <.stat_card
                title="Error Rate"
                value={"#{@metrics.error_rate}%"}
                trend={@metrics.error_trend}
              />
            </div>
          </div>
          """
        end
      end
      '''
    },
    %{
      name: "TypeScript — API Client",
      filetype: "typescript",
      code: ~S'''
      interface ApiConfig {
        baseUrl: string;
        timeout: number;
        retries?: number;
        headers?: Record<string, string>;
      }

      interface ApiResponse<T> {
        data: T;
        status: number;
        headers: Headers;
      }

      class ApiClient {
        private config: ApiConfig;
        private controller: AbortController;

        constructor(config: ApiConfig) {
          this.config = {
            retries: 3,
            timeout: 5000,
            ...config,
          };
          this.controller = new AbortController();
        }

        async get<T>(path: string): Promise<ApiResponse<T>> {
          return this.request<T>("GET", path);
        }

        async post<T>(path: string, body: unknown): Promise<ApiResponse<T>> {
          return this.request<T>("POST", path, body);
        }

        private async request<T>(
          method: string,
          path: string,
          body?: unknown,
        ): Promise<ApiResponse<T>> {
          const url = `${this.config.baseUrl}${path}`;
          let lastError: Error | null = null;

          for (let attempt = 0; attempt < (this.config.retries ?? 1); attempt++) {
            try {
              const response = await fetch(url, {
                method,
                headers: {
                  "Content-Type": "application/json",
                  ...this.config.headers,
                },
                body: body ? JSON.stringify(body) : undefined,
                signal: AbortSignal.timeout(this.config.timeout),
              });

              if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
              }

              const data: T = await response.json();
              return { data, status: response.status, headers: response.headers };
            } catch (error) {
              lastError = error as Error;
              if (attempt < (this.config.retries ?? 1) - 1) {
                await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
              }
            }
          }

          throw lastError;
        }

        cancel(): void {
          this.controller.abort();
          this.controller = new AbortController();
        }
      }

      // Usage
      const api = new ApiClient({
        baseUrl: "https://api.example.com",
        timeout: 10000,
        headers: { Authorization: "Bearer token123" },
      });

      const users = await api.get<User[]>("/users");
      console.log(`Found ${users.data.length} users`);
      '''
    },
    %{
      name: "TypeScript — React Hook",
      filetype: "typescript",
      code: ~S'''
      import { useState, useEffect, useCallback, useRef } from "react";

      interface UseFetchOptions<T> {
        initialData?: T;
        enabled?: boolean;
        refetchInterval?: number;
        onSuccess?: (data: T) => void;
        onError?: (error: Error) => void;
      }

      interface UseFetchResult<T> {
        data: T | undefined;
        error: Error | null;
        isLoading: boolean;
        isRefetching: boolean;
        refetch: () => Promise<void>;
      }

      function useFetch<T>(
        url: string,
        options: UseFetchOptions<T> = {},
      ): UseFetchResult<T> {
        const {
          initialData,
          enabled = true,
          refetchInterval,
          onSuccess,
          onError,
        } = options;

        const [data, setData] = useState<T | undefined>(initialData);
        const [error, setError] = useState<Error | null>(null);
        const [isLoading, setIsLoading] = useState(false);
        const [isRefetching, setIsRefetching] = useState(false);
        const mountedRef = useRef(true);

        const fetchData = useCallback(
          async (isRefetch = false) => {
            if (isRefetch) {
              setIsRefetching(true);
            } else {
              setIsLoading(true);
            }
            setError(null);

            try {
              const response = await fetch(url);
              if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
              }

              const json: T = await response.json();

              if (mountedRef.current) {
                setData(json);
                onSuccess?.(json);
              }
            } catch (err) {
              if (mountedRef.current) {
                const fetchError = err instanceof Error ? err : new Error(String(err));
                setError(fetchError);
                onError?.(fetchError);
              }
            } finally {
              if (mountedRef.current) {
                setIsLoading(false);
                setIsRefetching(false);
              }
            }
          },
          [url, onSuccess, onError],
        );

        useEffect(() => {
          mountedRef.current = true;
          if (enabled) {
            fetchData();
          }
          return () => {
            mountedRef.current = false;
          };
        }, [enabled, fetchData]);

        useEffect(() => {
          if (!refetchInterval || !enabled) return;

          const interval = setInterval(() => {
            fetchData(true);
          }, refetchInterval);

          return () => clearInterval(interval);
        }, [refetchInterval, enabled, fetchData]);

        const refetch = useCallback(() => fetchData(true), [fetchData]);

        return { data, error, isLoading, isRefetching, refetch };
      }

      export default useFetch;
      '''
    },
    %{
      name: "Plain Text — Config",
      filetype: nil,
      code: ~S'''
      # Application Configuration
      #
      # Environment: production
      # Last updated: 2025-01-15

      [database]
      host = "db.example.com"
      port = 5432
      name = "myapp_prod"
      pool_size = 20
      ssl = true

      [cache]
      adapter = "redis"
      host = "cache.example.com"
      port = 6379
      ttl_seconds = 300
      max_memory = "256mb"

      [http]
      port = 4000
      bind = "0.0.0.0"
      max_connections = 10000
      keepalive_timeout = 60

      [logging]
      level = "info"
      format = "json"
      output = "stdout"
      '''
    }
  ]

  def init(cols, rows) do
    first = hd(@examples)

    %{
      cols: cols,
      rows: rows,
      example_index: 0,
      show_line_numbers: true,
      code: Code.init(%{
        id: :code_view,
        content: String.trim(first.code),
        filetype: first.filetype,
        scroll_offset: 0,
        visible_lines: @viewport,
        show_line_numbers: true
      })
    }
  end

  def handle_event(%{type: :key, key: "c", ctrl: true, meta: false}, _state), do: :quit

  # Left/Right to cycle examples
  def handle_event(%{type: :key, key: :left, ctrl: false, meta: false}, state) do
    new_idx = rem(state.example_index - 1 + length(@examples), length(@examples))
    switch_example(state, new_idx)
  end

  def handle_event(%{type: :key, key: :right, ctrl: false, meta: false}, state) do
    new_idx = rem(state.example_index + 1, length(@examples))
    switch_example(state, new_idx)
  end

  # L to toggle line numbers
  def handle_event(%{type: :key, key: "l", ctrl: false, meta: false}, state) do
    show = !state.show_line_numbers
    new_code = Code.update({:set_show_line_numbers, show}, nil, state.code)
    {:cont, %{state | show_line_numbers: show, code: new_code}}
  end

  def handle_event(%{type: :key} = event, state) do
    new_code = Code.update(:key, event, state.code)
    {:cont, %{state | code: new_code}}
  end

  def handle_event(_event, state), do: {:cont, state}

  defp switch_example(state, new_idx) do
    example = Enum.at(@examples, new_idx)

    new_code = Code.init(%{
      id: :code_view,
      content: String.trim(example.code),
      filetype: example.filetype,
      scroll_offset: 0,
      visible_lines: @viewport,
      show_line_numbers: state.show_line_numbers
    })

    {:cont, %{state | example_index: new_idx, code: new_code}}
  end

  def render(state) do
    import ElixirOpentui.View

    bg = Color.rgb(13, 17, 23)
    fg = Color.rgb(230, 237, 243)
    panel_w = min(80, state.cols - 4)

    code_state = state.code
    example = Enum.at(@examples, state.example_index)
    total = length(String.split(code_state.content, "\n"))
    max_scroll = max(0, total - @viewport)
    pct = if max_scroll > 0, do: trunc(code_state.scroll_offset / max_scroll * 100), else: 0
    line_nums = if state.show_line_numbers, do: "ON", else: "OFF"
    status_str = "#{example.name} (#{state.example_index + 1}/#{length(@examples)}) | Lines: #{line_nums} | #{pct}%"

    panel id: :main, title: "Code Demo — Syntax Highlighting + Line Numbers",
          width: panel_w, height: @viewport + 7,
          border: true, fg: fg, bg: bg do

      text(content: "←/→ Switch examples | L Toggle line numbers | ↑/↓/PgUp/PgDn Scroll", fg: Color.rgb(136, 136, 136), bg: bg)
      text(content: "Ctrl+C to quit", fg: Color.rgb(136, 136, 136), bg: bg)
      text(content: "")

      code(
        id: :code_view,
        content: code_state.content,
        filetype: code_state.filetype,
        tokens: code_state.tokens,
        scroll_offset: code_state.scroll_offset,
        visible_lines: @viewport,
        show_line_numbers: state.show_line_numbers,
        width: panel_w - 4
      )

      text(content: "")
      text(content: String.duplicate("─", panel_w - 4), fg: Color.rgb(60, 60, 80), bg: bg)
      text(content: " #{status_str}", fg: Color.rgb(165, 214, 255), bg: bg)
    end
  end

  def focused_id(_state), do: :code_view
end

ElixirOpentui.Demo.DemoRunner.run(CodeDemo)
