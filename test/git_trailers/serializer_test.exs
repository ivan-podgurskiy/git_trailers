defmodule GitTrailers.SerializerTest do
  use ExUnit.Case, async: true

  alias GitTrailers.Trailer

  describe "format/2" do
    test "canonicalizes a tuple with the default separator" do
      assert GitTrailers.format({" Fixes ", " #42 "}) == "Fixes: #42"
    end

    test "accepts a keyed map or parsed trailer struct" do
      assert GitTrailers.format(%{key: "Bug", value: "42"}, "#") == "Bug# 42"

      trailer = %Trailer{key: "Reviewed-by", value: "Alice", raw: "source", separator: "%"}
      assert GitTrailers.format(trailer) == "Reviewed-by: Alice"
    end

    test "rejects invalid inputs" do
      assert_raise ArgumentError, fn -> GitTrailers.format({"bad key", "x"}) end
      assert_raise ArgumentError, fn -> GitTrailers.format({"Key", "one\ntwo"}) end
      assert_raise ArgumentError, fn -> GitTrailers.format({"Key", "value"}, "") end
      assert_raise ArgumentError, fn -> GitTrailers.format({"Key", "value"}, "::") end
      assert_raise ArgumentError, fn -> GitTrailers.format({"Key", "value"}, " ") end
      assert_raise ArgumentError, fn -> GitTrailers.format(:invalid) end
    end
  end

  describe "serialize/1" do
    test "joins canonical trailer lines with LF and no terminal newline" do
      assert GitTrailers.serialize([{"A", "1"}, %{key: "B", value: "2"}]) == "A: 1\nB: 2"
      assert GitTrailers.serialize([]) == ""
    end

    test "validates the collection and every trailer" do
      assert_raise ArgumentError, fn -> GitTrailers.serialize(:invalid) end
      assert_raise ArgumentError, fn -> GitTrailers.serialize([{"A", "1"}, {"bad key", "2"}]) end
    end
  end
end
