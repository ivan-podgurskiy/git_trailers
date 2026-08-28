defmodule GitTrailers.AcceptanceTest do
  use ExUnit.Case, async: true

  test "parses a pinned Linux review and Signed-off-by chain" do
    message = File.read!("test/fixtures/real_world/linux-signed-off.txt")
    assert {:ok, result} = GitTrailers.parse(message)

    assert result.subject == "bpf, sockmap: Fix cork use-after-free in tcp_bpf_sendmsg()"

    assert Enum.map(result.trailers, & &1.key) == [
             "Fixes",
             "Signed-off-by",
             "Reviewed-by",
             "Reviewed-by",
             "Link",
             "Link",
             "Link",
             "Signed-off-by"
           ]
  end

  test "parses modern co-author and generator attribution trailers" do
    message = File.read!("test/fixtures/real_world/ai-attribution.txt")
    assert {:ok, result} = GitTrailers.parse(message)

    assert Enum.map(result.trailers, &{&1.key, &1.value}) == [
             {"Co-Authored-By", "Claude Opus 4.8 <noreply@anthropic.com>"},
             {"Claude-Session", "https://claude.ai/code/session_019EHHuMgXKUH7EhUtqHEhfj"}
           ]
  end
end
