defmodule GitTrailers.AcceptanceTest do
  use ExUnit.Case, async: true

  test "parses a Linux-style review and Signed-off-by chain" do
    message = File.read!("test/fixtures/real_world/linux-signed-off.txt")
    assert {:ok, result} = GitTrailers.parse(message)

    assert result.subject == "net: account transmitted packets exactly once"

    assert result.body ==
             "\nAvoid charging the packet counter on both the retry and completion paths.\n"

    assert Enum.map(result.trailers, & &1.key) == [
             "Fixes",
             "Reported-by",
             "Reviewed-by",
             "Signed-off-by",
             "Signed-off-by"
           ]
  end

  test "parses modern co-author and generator attribution trailers" do
    message = File.read!("test/fixtures/real_world/ai-attribution.txt")
    assert {:ok, result} = GitTrailers.parse(message)

    assert Enum.map(result.trailers, &{&1.key, &1.value}) == [
             {"Co-authored-by", "Claude <noreply@anthropic.com>"},
             {"Generated-with", "Claude Code"},
             {"Reviewed-by", "Ada Example <ada@example.com>"}
           ]
  end
end
