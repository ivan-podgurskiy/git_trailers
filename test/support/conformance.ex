defmodule GitTrailers.Conformance do
  @moduledoc false

  @fixture Path.expand("../fixtures/conformance.json", __DIR__)

  @spec load!() :: map()
  def load! do
    @fixture
    |> File.read!()
    |> Jason.decode!()
  end

  @spec parse_options(map()) :: keyword()
  def parse_options(options) do
    options
    |> Enum.map(fn
      {"separators", value} -> {:separators, value}
      {"divider", value} -> {:divider, value}
      {"unfold", value} -> {:unfold, value}
      {"knownKeys", value} -> {:known_keys, value}
    end)
  end

  @spec add_options(map()) :: keyword()
  def add_options(options) do
    options
    |> Enum.map(fn
      {"where", value} -> {:where, String.to_existing_atom(value)}
      {"ifExists", value} -> {:if_exists, if_exists(value)}
      {"ifMissing", value} -> {:if_missing, if_missing(value)}
      {"trimEmpty", value} -> {:trim_empty, value}
      {"separators", value} -> {:separators, value}
      {"divider", value} -> {:divider, value}
    end)
  end

  @spec normalize_result(GitTrailers.Result.t()) :: map()
  def normalize_result(result) do
    %{
      "trailers" =>
        Enum.map(result.trailers, fn trailer ->
          %{
            "key" => trailer.key,
            "value" => trailer.value,
            "raw" => trailer.raw,
            "separator" => trailer.separator
          }
        end),
      "subject" => result.subject,
      "body" => result.body,
      "blockStart" => result.block_start,
      "hasDivider" => result.has_divider
    }
  end

  defp if_exists("addIfDifferentNeighbor"), do: :add_if_different_neighbor
  defp if_exists("addIfDifferent"), do: :add_if_different
  defp if_exists("add"), do: :add
  defp if_exists("replace"), do: :replace
  defp if_exists("doNothing"), do: :do_nothing

  defp if_missing("add"), do: :add
  defp if_missing("doNothing"), do: :do_nothing
end
