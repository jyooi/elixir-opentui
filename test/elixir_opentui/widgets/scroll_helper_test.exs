defmodule ElixirOpentui.Widgets.ScrollHelperTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Widgets.ScrollHelper

  defp key(k) do
    %{type: :key, key: k, ctrl: false, alt: false, shift: false, meta: false}
  end

  describe "handle_scroll_key/2" do
    test "up decrements offset by 1" do
      assert {:handled, 4} =
               ScrollHelper.handle_scroll_key(key(:up), offset: 5, total: 20, visible: 10)
    end

    test "down increments offset by 1" do
      assert {:handled, 6} =
               ScrollHelper.handle_scroll_key(key(:down), offset: 5, total: 20, visible: 10)
    end

    test "page_up decrements offset by visible" do
      assert {:handled, 2} =
               ScrollHelper.handle_scroll_key(key(:page_up), offset: 7, total: 20, visible: 5)
    end

    test "page_down increments offset by visible" do
      assert {:handled, 10} =
               ScrollHelper.handle_scroll_key(key(:page_down), offset: 5, total: 20, visible: 5)
    end

    test "home sets offset to 0" do
      assert {:handled, 0} =
               ScrollHelper.handle_scroll_key(key(:home), offset: 8, total: 20, visible: 10)
    end

    test "end sets offset to max" do
      assert {:handled, 10} =
               ScrollHelper.handle_scroll_key(key(:end), offset: 0, total: 20, visible: 10)
    end

    # --- Clamping at 0 ---

    test "up clamps at 0" do
      assert {:handled, 0} =
               ScrollHelper.handle_scroll_key(key(:up), offset: 0, total: 10, visible: 5)
    end

    test "page_up clamps at 0" do
      assert {:handled, 0} =
               ScrollHelper.handle_scroll_key(key(:page_up), offset: 2, total: 10, visible: 5)
    end

    # --- Clamping at max ---

    test "down clamps at max offset" do
      # total=10, visible=5 => max_offset=5
      assert {:handled, 5} =
               ScrollHelper.handle_scroll_key(key(:down), offset: 5, total: 10, visible: 5)
    end

    test "page_down clamps at max offset" do
      assert {:handled, 5} =
               ScrollHelper.handle_scroll_key(key(:page_down), offset: 3, total: 10, visible: 5)
    end

    test "end at max offset is idempotent" do
      assert {:handled, 5} =
               ScrollHelper.handle_scroll_key(key(:end), offset: 5, total: 10, visible: 5)
    end

    # --- visible: nil fallback ---

    test "visible nil defaults page step to 10" do
      # page_up with step=10 from offset 5 => 0
      assert {:handled, 0} = ScrollHelper.handle_scroll_key(key(:page_up), offset: 5, total: 20)
    end

    test "visible nil uses total for max_offset (max_offset = 0)" do
      # When visible is nil, max_offset = max(0, total - total) = 0
      # So all forward scrolling clamps to 0
      assert {:handled, 0} = ScrollHelper.handle_scroll_key(key(:down), offset: 0, total: 5)
      assert {:handled, 0} = ScrollHelper.handle_scroll_key(key(:end), offset: 0, total: 5)
      assert {:handled, 0} = ScrollHelper.handle_scroll_key(key(:page_down), offset: 0, total: 20)
    end

    # --- Edge cases ---

    test "total 0 keeps all offsets at 0" do
      assert {:handled, 0} =
               ScrollHelper.handle_scroll_key(key(:down), offset: 0, total: 0, visible: 5)

      assert {:handled, 0} =
               ScrollHelper.handle_scroll_key(key(:page_down), offset: 0, total: 0, visible: 5)

      assert {:handled, 0} =
               ScrollHelper.handle_scroll_key(key(:end), offset: 0, total: 0, visible: 5)
    end

    test "total < visible means max_offset is 0" do
      assert {:handled, 0} =
               ScrollHelper.handle_scroll_key(key(:down), offset: 0, total: 3, visible: 10)

      assert {:handled, 0} =
               ScrollHelper.handle_scroll_key(key(:end), offset: 0, total: 3, visible: 10)
    end

    test "page step equals visible value" do
      # visible=7, offset=0 => page_down should go to 7
      assert {:handled, 7} =
               ScrollHelper.handle_scroll_key(key(:page_down), offset: 0, total: 20, visible: 7)

      # visible=7, offset=10 => page_up should go to 3
      assert {:handled, 3} =
               ScrollHelper.handle_scroll_key(key(:page_up), offset: 10, total: 20, visible: 7)
    end

    # --- Unhandled keys ---

    test "unhandled key returns :unhandled" do
      assert :unhandled =
               ScrollHelper.handle_scroll_key(key(:left), offset: 5, total: 20, visible: 10)

      assert :unhandled =
               ScrollHelper.handle_scroll_key(key(:right), offset: 5, total: 20, visible: 10)

      assert :unhandled =
               ScrollHelper.handle_scroll_key(key(:enter), offset: 5, total: 20, visible: 10)
    end
  end
end
