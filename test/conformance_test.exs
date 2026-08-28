defmodule GitTrailers.ConformanceTest do
  use ExUnit.Case, async: true

  alias GitTrailers.Conformance

  @corpus Conformance.load!()

  test "matches every shared parse case" do
    for test_case <- @corpus["parseCases"] do
      options = Conformance.parse_options(test_case["options"] || %{})
      assert {:ok, result} = GitTrailers.parse(test_case["input"], options)

      assert Conformance.normalize_result(result) == test_case["expected"],
             "shared parse case failed: #{test_case["name"]}"
    end
  end

  test "matches every shared add case" do
    for test_case <- @corpus["addCases"] do
      trailers = Enum.map(test_case["trailers"], &{&1["key"], &1["value"]})
      options = Conformance.add_options(test_case["options"] || %{})

      assert GitTrailers.add(test_case["input"], trailers, options) == test_case["expected"],
             "shared add case failed: #{test_case["name"]}"
    end
  end

  test "records the pinned Git source version" do
    assert @corpus["source"]["gitVersion"] == "2.54.0"
  end
end
