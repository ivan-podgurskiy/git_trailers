defmodule GitTrailers.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  @token_characters Enum.concat([?A..?Z, ?a..?z, ?0..?9, [?-]])

  property "parse is total for generated UTF-8 strings" do
    check all(message <- string(:printable), max_runs: 500) do
      assert {:ok, %GitTrailers.Result{}} = GitTrailers.parse(message)
    end
  end

  property "adding a trailer makes its normalized key and value parseable" do
    check all(
            key <- key_generator(),
            value <- string(:alphanumeric, max_length: 40),
            subject <- string(:alphanumeric, min_length: 1, max_length: 40),
            max_runs: 500
          ) do
      updated = GitTrailers.add(subject, [{key, value}])
      assert {:ok, result} = GitTrailers.parse(updated)

      assert Enum.any?(result.trailers, fn trailer ->
               trailer.key == key and trailer.value == String.trim(value)
             end)
    end
  end

  property "unfolding remains stable after canonical serialization" do
    check all(
            segments <-
              list_of(string(:alphanumeric, min_length: 1), min_length: 1, max_length: 5),
            max_runs: 500
          ) do
      [first | rest] = segments
      folded = Enum.map_join(rest, "", &("\n  " <> &1))
      message = "subject\n\nKey: " <> first <> folded <> "\n"

      assert {:ok, %{trailers: [trailer]}} = GitTrailers.parse(message)
      canonical = "subject\n\n" <> GitTrailers.format({trailer.key, trailer.value}) <> "\n"
      assert {:ok, %{trailers: [reparsed]}} = GitTrailers.parse(canonical)
      assert reparsed.value == trailer.value
    end
  end

  property "canonical trailer serialization is stable after parsing" do
    check all(
            trailers <-
              list_of(
                tuple({key_generator(), string(:alphanumeric, max_length: 40)}),
                min_length: 1,
                max_length: 10
              ),
            max_runs: 500
          ) do
      canonical = GitTrailers.serialize(trailers)
      {:ok, result} = GitTrailers.parse("subject\n\n" <> canonical <> "\n")

      assert GitTrailers.serialize(result.trailers) == canonical
    end
  end

  property "adding before a divider preserves the surrounding byte regions" do
    check all(
            subject <- string(:alphanumeric, min_length: 1, max_length: 40),
            value <- string(:alphanumeric, max_length: 40),
            max_runs: 500
          ) do
      prefix = subject <> "\r\n\r\nBody\r\n"
      suffix = "\r\n---\r\ndiff --git a/a b/a\r\n"
      updated = GitTrailers.add(prefix <> suffix, [{"Reviewed-by", value}])

      assert String.starts_with?(updated, prefix)
      assert String.ends_with?(updated, suffix)
    end
  end

  defp key_generator do
    @token_characters
    |> member_of()
    |> list_of(min_length: 1, max_length: 40)
    |> map(&List.to_string/1)
  end
end
