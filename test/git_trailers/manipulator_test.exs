defmodule GitTrailers.ManipulatorTest do
  use ExUnit.Case, async: true

  @base "subject\n\nFixes: one\nReviewed-by: A\nFixes: two\n"

  describe "placement" do
    test "places trailers using every where policy" do
      cases = [
        end: "subject\n\nFixes: one\nReviewed-by: A\nFixes: two\nFixes: three\n",
        start: "subject\n\nFixes: three\nFixes: one\nReviewed-by: A\nFixes: two\n",
        after: "subject\n\nFixes: one\nReviewed-by: A\nFixes: two\nFixes: three\n",
        before: "subject\n\nFixes: three\nFixes: one\nReviewed-by: A\nFixes: two\n"
      ]

      for {where, expected} <- cases do
        assert GitTrailers.add(@base, [{"Fixes", "three"}], where: where) == expected
      end
    end

    test "places start at the beginning of the whole block" do
      message = "subject\n\nReviewed-by: A\nFixes: one\n"

      assert GitTrailers.add(message, [{"Fixes", "two"}], where: :start, if_exists: :add) ==
               "subject\n\nFixes: two\nReviewed-by: A\nFixes: one\n"
    end
  end

  describe "existing and missing policies" do
    test "suppresses an identical insertion neighbor by default" do
      assert GitTrailers.add(@base, [{"Fixes", "two"}]) == @base
    end

    test "adds when the same value is not the insertion neighbor" do
      assert GitTrailers.add(@base, [{"Fixes", "one"}]) ==
               "subject\n\nFixes: one\nReviewed-by: A\nFixes: two\nFixes: one\n"
    end

    test "supports add_if_different, add, replace, and do_nothing" do
      assert GitTrailers.add(@base, [{"fixes", "ONE"}], if_exists: :add_if_different) ==
               @base

      assert GitTrailers.add(@base, [{"Fixes", "two"}], if_exists: :add) ==
               "subject\n\nFixes: one\nReviewed-by: A\nFixes: two\nFixes: two\n"

      assert GitTrailers.add(@base, [{"Fixes", "three"}], if_exists: :replace) ==
               "subject\n\nFixes: one\nReviewed-by: A\nFixes: three\n"

      assert GitTrailers.add(@base, [{"Fix", "three"}], if_exists: :do_nothing) == @base
    end

    test "does nothing for a missing key when configured" do
      assert GitTrailers.add(@base, [{"Acked-by", "A"}], if_missing: :do_nothing) == @base
    end

    test "uses the actual insertion neighbor for duplicate suppression" do
      leading = "subject\n\nFixes: one\nReviewed-by: A\n"
      assert GitTrailers.add(leading, [{"Fixes", "one"}], where: :start) == leading

      following = "subject\n\nReviewed-by: A\nFixes: two\n"
      assert GitTrailers.add(following, [{"Fixes", "two"}], where: :before) == following

      with_record = "subject\n\n(cherry picked from commit abc)\nFixes: one\n"

      assert GitTrailers.add(with_record, [{"Fixes", "two"}], where: :start) ==
               "subject\n\nFixes: two\n(cherry picked from commit abc)\nFixes: one\n"
    end

    test "compares folded values without unfolding them" do
      message = "subject\n\nKey: one\n  two\n"

      expected_by_placement = %{
        start: "subject\n\nKey: one two\nKey: one\n  two\n",
        before: "subject\n\nKey: one two\nKey: one\n  two\n",
        after: "subject\n\nKey: one\n  two\nKey: one two\n",
        end: "subject\n\nKey: one\n  two\nKey: one two\n"
      }

      for {where, expected} <- expected_by_placement do
        assert GitTrailers.add(message, [{"Key", "one two"}], where: where) == expected
      end

      assert GitTrailers.add(message, [{"Key", "one two"}], if_exists: :add_if_different) ==
               expected_by_placement.end
    end
  end

  describe "block reconstruction" do
    test "trims existing and incoming empty values" do
      message = "subject\n\nFixes:   \nReviewed-by: A\n"

      assert GitTrailers.add(message, [{"Acked-by", " \t "}], trim_empty: true) ==
               "subject\n\nReviewed-by: A\n"
    end

    test "trims existing empty values without incoming trailers" do
      message = "subject\n\nFixes:   \nReviewed-by: A\n"

      assert GitTrailers.add(message, [], trim_empty: true) ==
               "subject\n\nReviewed-by: A\n"
    end

    test "keeps non-trailer records while trimming empty trailers" do
      message = "subject\n\nSigned-off-by: A\nrecord\nFixes:   \n"

      assert GitTrailers.add(message, [{"Reviewed-by", "B"}], trim_empty: true) ==
               "subject\n\nSigned-off-by: A\nrecord\nReviewed-by: B\n"
    end

    test "returns no-op mutations byte-for-byte" do
      message = "subject\r\n\r\nFixes: one\r\n"
      assert GitTrailers.add(message, []) == message

      assert GitTrailers.add("subject\n\nFixes : one\n", [{"Fixes", "one"}], trim_empty: true) ==
               "subject\n\nFixes : one\n"
    end

    test "creates parseable newline-terminated blocks" do
      assert GitTrailers.add("subject", [{"Reviewed-by", "A"}]) ==
               "subject\n\nReviewed-by: A\n"

      assert GitTrailers.add("", [{"a", ""}]) == "\na: \n"
    end

    test "applies additions sequentially" do
      assert GitTrailers.add("subject", [{"Reviewed-by", "A"}, {"Reviewed-by", "B"}]) ==
               "subject\n\nReviewed-by: A\nReviewed-by: B\n"
    end

    test "canonicalizes a changed block to LF while preserving bytes outside it" do
      assert GitTrailers.add("subject\r\n\r\nFixes: one\r\n", [{"Reviewed-by", "A"}]) ==
               "subject\r\n\r\nFixes: one\nReviewed-by: A\n"

      assert GitTrailers.add("subject\r\n", [{"Reviewed-by", "A"}]) ==
               "subject\r\n\nReviewed-by: A\n"
    end

    test "retains folded values and non-trailer records" do
      message = "subject\n\nSigned-off-by: A\n  folded value\nnot trailer\n"

      assert GitTrailers.add(message, [{"Reviewed-by", "B"}]) ==
               "subject\n\nSigned-off-by: A\n  folded value\nnot trailer\nReviewed-by: B\n"
    end

    test "preserves whitespace immediately before a folded newline" do
      message = "subject\n\nKey: one   \n  two\n"

      assert GitTrailers.add(message, [{"Other", "x"}]) ==
               message <> "Other: x\n"
    end

    test "trims only the complete folded value's outer whitespace" do
      assert GitTrailers.add("subject\n\nKey: one\n  two   \n", [{"Other", "x"}]) ==
               "subject\n\nKey: one\n  two\nOther: x\n"

      assert GitTrailers.add("subject\n\nKey:    \n  two\n", [{"Other", "x"}]) ==
               "subject\n\nKey: two\nOther: x\n"
    end
  end

  describe "configured separators" do
    test "recognizes overlapping and alphanumeric separators" do
      assert GitTrailers.add(
               "subject\n\nFixes- one\n",
               [{"fixes", "two"}],
               separators: "-:",
               if_exists: :replace
             ) == "subject\n\nfixes- two\n"

      assert GitTrailers.add(
               "subject\n\nFixesa one\n",
               [{"Fixes", "two"}],
               separators: "a:",
               if_exists: :replace
             ) == "subject\n\nFixesa two\n"
    end

    test "supports horizontal whitespace separators" do
      assert GitTrailers.add("subject\n\nKey value\n", [{"Other", "next"}], separators: " ") ==
               "subject\n\nKey  value\nOther  next\n"

      assert GitTrailers.add("subject", [{"Key", "value"}], separators: "\t") ==
               "subject\n\nKey\t value\n"
    end

    test "creates a separate block when a configured separator occurs at offset zero" do
      message = "subject\n\nKey: value\n"

      assert GitTrailers.add(message, [{"Reviewed-by", "A"}], separators: "K:") ==
               "subject\n\nKey: value\n\nReviewed-byK A\n"
    end

    test "uses the first repeated overlapping separator when canonicalizing" do
      assert GitTrailers.add(
               "subject\n\nSigned-off-by: A\n",
               [{"Signed", "B"}],
               separators: "-:",
               if_exists: :add
             ) == "subject\n\nSigned- off-by: A\nSigned- B\n"
    end

    test "keeps folded comparisons distinct and rejects orphan continuations" do
      folded = "subject\n\nFixes- one\n  continued\n"

      assert GitTrailers.add(folded, [{"Fixes", "one continued"}], separators: "-:") ==
               folded <> "Fixes- one continued\n"

      assert GitTrailers.add(
               "subject\n\n  orphan\nFixes- one\n",
               [{"Reviewed-by", "A"}],
               separators: "-:"
             ) == "subject\n\n  orphan\nFixes- one\n\nReviewed-by- A\n"
    end
  end

  describe "ignored suffixes" do
    test "inserts before trailing blank and comment material" do
      message = "subject\n\nbody\n\n# keep\n"

      assert GitTrailers.add(message, [{"Reviewed-by", "A"}]) ==
               "subject\n\nbody\n\nReviewed-by: A\n\n# keep\n"
    end

    test "preserves divider and scissors suffixes byte-for-byte" do
      divider = "subject\n\n---\ndiff --git a/a b/a\n"

      assert GitTrailers.add(divider, [{"Reviewed-by", "A"}]) ==
               "subject\n\nReviewed-by: A\n\n---\ndiff --git a/a b/a\n"

      scissors = "subject\n\n# ------------------------ >8 ------------------------\nignored\n"

      assert GitTrailers.add(scissors, [{"Reviewed-by", "A"}], divider: false) ==
               "subject\n\nReviewed-by: A\n\n# ------------------------ >8 ------------------------\nignored\n"
    end

    test "preserves a trailing comment after mutating an existing block" do
      message = "subject\n\nFixes: one\n# keep\n"

      assert GitTrailers.add(message, [{"Reviewed-by", "A"}]) ==
               "subject\n\nFixes: one\nReviewed-by: A\n# keep\n"
    end

    test "does not mutate a rejected block separated by a comment and orphan continuation" do
      message = "subject\n\nKey: one\n# note\n  orphan\nOther: two\n"

      assert GitTrailers.add(message, [{"Reviewed-by", "A"}]) ==
               message <> "\nReviewed-by: A\n"
    end
  end

  describe "validation" do
    test "validates arguments and options before mutation" do
      assert_raise ArgumentError, fn -> GitTrailers.add(:subject, []) end
      assert_raise ArgumentError, fn -> GitTrailers.add("subject", :trailers) end
      assert_raise ArgumentError, fn -> GitTrailers.add("subject", [], where: :middle) end
      assert_raise ArgumentError, fn -> GitTrailers.add("subject", [], if_exists: :invalid) end
      assert_raise ArgumentError, fn -> GitTrailers.add("subject", [], if_missing: :invalid) end
      assert_raise ArgumentError, fn -> GitTrailers.add("subject", [], trim_empty: :yes) end
      assert_raise ArgumentError, fn -> GitTrailers.add("subject", [], divider: :yes) end
      assert_raise ArgumentError, fn -> GitTrailers.add("subject", [{"bad key", "A"}]) end
      assert_raise ArgumentError, fn -> GitTrailers.add("subject", [{"Key", "one\ntwo"}]) end

      assert_raise ArgumentError, fn ->
        GitTrailers.add("subject", [{"Key", "A"}], separators: "")
      end

      assert_raise ArgumentError, fn ->
        GitTrailers.add("subject", [{"Key", "A"}], separators: "\n")
      end

      assert_raise ArgumentError, fn ->
        GitTrailers.add("subject", [{"Key", "A"}], unknown: true)
      end
    end
  end
end
