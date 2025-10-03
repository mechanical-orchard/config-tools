defmodule ConfigToolsTest do
  use ExUnit.Case
  doctest ConfigTools

  test "greets the world" do
    assert ConfigTools.hello() == :world
  end
end
