defmodule ElixirOpentui.ColorTest do
  use ExUnit.Case, async: true

  alias ElixirOpentui.Color

  describe "constructors" do
    test "rgb creates opaque color" do
      assert Color.rgb(255, 0, 128) == {255, 0, 128, 255}
    end

    test "rgba creates color with alpha" do
      assert Color.rgba(255, 0, 128, 128) == {255, 0, 128, 128}
    end

    test "named colors" do
      assert Color.black() == {0, 0, 0, 255}
      assert Color.white() == {255, 255, 255, 255}
      assert Color.red() == {255, 0, 0, 255}
      assert Color.green() == {0, 255, 0, 255}
      assert Color.blue() == {0, 0, 255, 255}
      assert Color.transparent() == {0, 0, 0, 0}
    end
  end

  describe "blend/2" do
    test "opaque over anything yields opaque" do
      assert Color.blend({255, 0, 0, 255}, {0, 255, 0, 255}) == {255, 0, 0, 255}
    end

    test "transparent over anything yields background" do
      bg = {0, 255, 0, 255}
      assert Color.blend({0, 0, 0, 0}, bg) == bg
    end

    test "50% alpha blends colors" do
      result = Color.blend({255, 0, 0, 128}, {0, 0, 255, 255})
      {r, _g, b, a} = result
      assert r > 100 and r < 200
      assert b > 50 and b < 200
      assert a == 255
    end

    test "transparent over transparent" do
      assert Color.blend({0, 0, 0, 0}, {0, 0, 0, 0}) == {0, 0, 0, 0}
    end
  end

  describe "with_opacity/2" do
    test "full opacity unchanged" do
      assert Color.with_opacity({255, 0, 0, 255}, 1.0) == {255, 0, 0, 255}
    end

    test "zero opacity" do
      assert Color.with_opacity({255, 0, 0, 255}, 0.0) == {255, 0, 0, 0}
    end

    test "half opacity" do
      {_r, _g, _b, a} = Color.with_opacity({255, 0, 0, 255}, 0.5)
      assert a == 128
    end
  end

  describe "from_hex/1" do
    test "6-digit hex" do
      assert Color.from_hex("#FF0000") == {:ok, {255, 0, 0, 255}}
      assert Color.from_hex("#00FF00") == {:ok, {0, 255, 0, 255}}
      assert Color.from_hex("#0000FF") == {:ok, {0, 0, 255, 255}}
    end

    test "8-digit hex with alpha" do
      assert Color.from_hex("#FF000080") == {:ok, {255, 0, 0, 128}}
    end

    test "invalid hex" do
      assert Color.from_hex("not-a-hex") == {:error, :invalid_hex}
      assert Color.from_hex("#GG0000") == {:error, :invalid_hex}
      assert Color.from_hex("#FF") == {:error, :invalid_hex}
    end
  end

  describe "ANSI" do
    test "to_ansi_fg produces escape sequence" do
      result = IO.iodata_to_binary(Color.to_ansi_fg({255, 128, 0, 255}))
      assert result == "\e[38;2;255;128;0m"
    end

    test "to_ansi_bg produces escape sequence" do
      result = IO.iodata_to_binary(Color.to_ansi_bg({0, 128, 255, 255}))
      assert result == "\e[48;2;0;128;255m"
    end
  end
end
