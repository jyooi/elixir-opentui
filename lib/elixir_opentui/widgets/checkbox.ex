defmodule ElixirOpentui.Widgets.Checkbox do
  @moduledoc """
  Checkbox/toggle widget.

  Renders as `[x] Label` or `[ ] Label`. Toggled with Space or Enter.

  ## Props
  - `:checked` — boolean state
  - `:label` — text label
  - `:on_change` — message tag sent as `{tag, new_checked_value}`
  - `:id` — element id (required for focus)
  """

  use ElixirOpentui.Component

  import ElixirOpentui.Component

  @impl true
  def init(props) do
    %{
      checked: Map.get(props, :checked, false),
      label: Map.get(props, :label, ""),
      on_change: Map.get(props, :on_change),
      id: Map.get(props, :id),
      _pending: []
    }
  end

  @impl true
  def update(:toggle, _event, state) do
    toggle(state)
  end

  def update(:key, %{type: :key} = event, state) do
    handle_key(event, state)
  end

  def update({:set_checked, value}, _event, state) do
    %{state | checked: value}
    |> emit_change()
  end

  def update(_, _, state), do: state

  @impl true
  def update_props(prev_props, new_props, state) do
    state = %{
      state
      | id: Map.get(new_props, :id),
        label: Map.get(new_props, :label, ""),
        on_change: Map.get(new_props, :on_change)
    }

    if prop_changed?(prev_props, new_props, :checked) do
      %{state | checked: Map.get(new_props, :checked, false)}
    else
      state
    end
  end

  @impl true
  def render(state) do
    import ElixirOpentui.View

    checkbox(
      id: state.id,
      checked: state.checked,
      label: state.label
    )
  end

  defp handle_key(%{key: " "}, state), do: toggle(state)
  defp handle_key(%{key: :enter}, state), do: toggle(state)
  defp handle_key(_, state), do: state

  defp toggle(state) do
    state = %{state | checked: not state.checked}
    emit_change(state)
  end

  defp emit_change(state), do: emit(state, state.on_change, [state.checked])
end
