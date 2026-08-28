defmodule GitTrailers.LinesTest do
  use ExUnit.Case, async: true

  alias GitTrailers.Lines

  describe "scan/1" do
    test "retains byte offsets, raw text, and mixed line endings" do
      assert Lines.scan("a\r\nb\n") == [
               %{index: 0, start: 0, stop: 3, content: "a", raw: "a\r\n", eol: "\r\n"},
               %{index: 1, start: 3, stop: 5, content: "b", raw: "b\n", eol: "\n"}
             ]
    end

    test "retains a final line without a line ending" do
      assert Lines.scan("a\nlast") == [
               %{index: 0, start: 0, stop: 2, content: "a", raw: "a\n", eol: "\n"},
               %{index: 1, start: 2, stop: 6, content: "last", raw: "last", eol: ""}
             ]
    end

    test "returns no physical lines for an empty binary" do
      assert Lines.scan("") == []
    end
  end

  describe "newline/1" do
    test "uses the first observed line ending" do
      assert "a\r\nb\n" |> Lines.scan() |> Lines.newline() == "\r\n"
    end

    test "falls back to LF when no line ending is present" do
      assert "last" |> Lines.scan() |> Lines.newline() == "\n"
    end
  end
end
