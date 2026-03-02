defmodule ElixirOpentui.Widgets.ScrollHelper do
  @moduledoc """
  Shared scroll key handling for scrollable display widgets.

  Centralizes the :up/:down/:page_up/:page_down/:home/:end key dispatch
  that is common to Code, Diff, and Markdown widgets. Accepts keyword
  opts to keep call sites self-documenting.

  ## Options

  - `:offset` (required) — current scroll offset
  - `:total` (required) — total number of lines
  - `:visible` (optional) — number of visible lines; used for page step
    and max offset clamping. When nil, page step defaults to 10 and
    max offset allows scrolling to the last line.
  """

  @spec handle_scroll_key(map(), keyword()) ::
          {:handled, non_neg_integer()} | :unhandled
  def handle_scroll_key(event, opts) do
    offset = Keyword.fetch!(opts, :offset)
    total = Keyword.fetch!(opts, :total)
    visible = Keyword.get(opts, :visible)

    max_offset = max(0, total - (visible || total))
    page_step = visible || 10

    case event.key do
      :up ->
        {:handled, max(0, offset - 1)}

      :down ->
        {:handled, min(max_offset, offset + 1)}

      :page_up ->
        {:handled, max(0, offset - page_step)}

      :page_down ->
        {:handled, min(max_offset, offset + page_step)}

      :home ->
        {:handled, 0}

      :end ->
        {:handled, max_offset}

      _ ->
        :unhandled
    end
  end
end
