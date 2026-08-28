defmodule GitTrailers.ParserTest do
  use ExUnit.Case, async: true

  describe "trailer values" do
    test "unfolds continuation lines by default and preserves exact raw text" do
      assert {:ok, %{trailers: [trailer]}} = GitTrailers.parse("s\n\nKey: one\n  two\n\tthree\n")
      assert trailer.value == "one two three"
      assert trailer.raw == "Key: one\n  two\n\tthree\n"
    end

    test "retains folded line endings when unfolding is disabled" do
      assert {:ok, %{trailers: [trailer]}} =
               GitTrailers.parse("s\r\n\r\nKey: one\r\n  two\r\n", unfold: false)

      assert trailer.value == "one\r\n  two"
      assert trailer.raw == "Key: one\r\n  two\r\n"
    end
  end

  describe "block detection" do
    test "accepts the built-in recognized-prefix 25 percent boundary" do
      message = "s\n\nSigned-off-by: A\nnot trailer\nnot trailer\nnot trailer\n"

      assert {:ok, %{trailers: [%{key: "Signed-off-by"}], body: "", block_start: 2}} =
               GitTrailers.parse(message)
    end

    test "rejects a recognized block below the 25 percent boundary" do
      message = "s\n\nSigned-off-by: A\none\ntwo\nthree\nfour\n"

      assert {:ok, %{trailers: [], block_start: -1}} = GitTrailers.parse(message)
    end

    test "uses a case-insensitive known key at the 25 percent boundary" do
      message = "s\n\nAudit-key: yes\none\ntwo\nthree\n"

      assert {:ok, %{trailers: [%{key: "Audit-key"}], block_start: 2}} =
               GitTrailers.parse(message, known_keys: ["AUDIT-KEY"])
    end

    test "counts a folded trailer atomically for the 25 percent rule" do
      message = "s\n\nKnown: A\n  folded\none\ntwo\nthree\nfour\n"

      assert {:ok, %{trailers: [], block_start: -1}} =
               GitTrailers.parse(message, known_keys: ["Known"])
    end

    test "accepts a cherry-pick prefix without returning it as a trailer" do
      message = "s\n\n(cherry picked from commit abcdef)\none\ntwo\nthree\n"

      assert {:ok, %{trailers: [], body: "", block_start: 2}} = GitTrailers.parse(message)
    end

    test "rejects an orphan continuation before a trailer" do
      assert {:ok, %{trailers: [], block_start: -1}} =
               GitTrailers.parse("s\n\n  orphan\nKey: value\n")
    end

    test "ignores default comments inside an all-trailer block" do
      message = "s\n\nKey: one\n# note\nOther: two\n"

      assert {:ok, %{trailers: trailers, block_start: 2}} = GitTrailers.parse(message)
      assert Enum.map(trailers, & &1.key) == ["Key", "Other"]
    end
  end

  describe "separators and effective end" do
    test "retains the configured separator used by the source line" do
      assert {:ok, %{trailers: [trailer]}} =
               GitTrailers.parse("s\n\nBug% 42\n", separators: "%")

      assert trailer.key == "Bug"
      assert trailer.value == "42"
      assert trailer.separator == "%"
    end

    test "uses the first matching separator even when it overlaps key characters" do
      assert {:ok, %{trailers: [trailer]}} =
               GitTrailers.parse("s\n\nSigned-off-by: Alice\n", separators: "-:")

      assert trailer.key == "Signed"
      assert trailer.value == "off-by: Alice"
      assert trailer.separator == "-"
    end

    test "stops before an enabled divider and preserves CRLF raw bytes" do
      message = "s\r\n\r\nKey: before\r\n---\r\nKey: after\r\n"

      assert {:ok, %{trailers: [trailer], block_start: 2, has_divider: true}} =
               GitTrailers.parse(message)

      assert trailer.raw == "Key: before\r\n"
    end

    test "does not treat a divider as effective when divider handling is disabled" do
      assert {:ok, %{has_divider: false}} =
               GitTrailers.parse("s\n\nKey: before\n---\nKey: after\n", divider: false)
    end
  end

  describe "option validation" do
    test "raises ArgumentError for invalid options" do
      assert_raise ArgumentError, fn -> GitTrailers.parse("s", separators: "") end
      assert_raise ArgumentError, fn -> GitTrailers.parse("s", divider: :yes) end
      assert_raise ArgumentError, fn -> GitTrailers.parse("s", unfold: :yes) end
      assert_raise ArgumentError, fn -> GitTrailers.parse("s", known_keys: [:known]) end
      assert_raise ArgumentError, fn -> GitTrailers.parse("s", unknown: true) end
      assert_raise ArgumentError, fn -> GitTrailers.parse("s", [:not_a_keyword]) end
      assert_raise ArgumentError, fn -> GitTrailers.parse(:not_a_binary) end
    end
  end
end
