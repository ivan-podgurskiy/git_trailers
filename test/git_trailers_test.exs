defmodule GitTrailersTest do
  use ExUnit.Case, async: true

  describe "parse/2" do
    test "returns all post-subject content as body when no block exists" do
      assert {:ok, result} = GitTrailers.parse("subject\n\nbody")
      assert result.subject == "subject"
      assert result.body == "\nbody"
      assert result.trailers == []
      assert result.block_start == -1
      refute result.has_divider
    end

    test "parses a Signed-off-by trailer into an idiomatic result struct" do
      message = "subject\n\nSigned-off-by: Alice <a@example.com>\n"

      assert {:ok, result} = GitTrailers.parse(message)
      assert result.__struct__ == GitTrailers.Result
      assert result.subject == "subject"
      assert result.body == ""
      assert result.block_start == 2
      refute result.has_divider

      assert [trailer] = result.trailers
      assert trailer.__struct__ == GitTrailers.Trailer
      assert trailer.key == "Signed-off-by"
      assert trailer.value == "Alice <a@example.com>"
      assert trailer.raw == "Signed-off-by: Alice <a@example.com>\n"
      assert trailer.separator == ":"
    end

    test "is total for empty and malformed message content" do
      assert {:ok, %{subject: "", body: "", trailers: [], block_start: -1}} =
               GitTrailers.parse("")

      assert {:ok, %{trailers: [], body: "\nnot a trailer"}} =
               GitTrailers.parse("subject\n\nnot a trailer")
    end
  end
end
