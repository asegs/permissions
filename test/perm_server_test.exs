defmodule PermServerTest do
  use ExUnit.Case
  doctest PermServer

  test "greets the world" do
    assert PermServer.hello() == :world
  end
end
