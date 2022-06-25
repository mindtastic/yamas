defmodule YamasTest do
  use ExUnit.Case
  doctest Yamas

  test "greets the world" do
    assert Yamas.hello() == :world
  end
end
