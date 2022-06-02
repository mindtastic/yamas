defmodule YAMASTest do
  use ExUnit.Case
  doctest YAMAS

  test "greets the world" do
    assert YAMAS.hello() == :world
  end
end
