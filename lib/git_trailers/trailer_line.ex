defmodule GitTrailers.TrailerLine do
  @moduledoc false

  @type t :: %{
          key: binary(),
          value: binary(),
          separator: binary(),
          separator_offset: non_neg_integer()
        }

  @spec parse(binary(), binary()) :: {:ok, t()} | :error
  def parse(line, separators) do
    case find_separator(line, separators, 0, false) do
      :error ->
        :error

      {:ok, separator, separator_offset} ->
        value_offset = separator_offset + byte_size(separator)

        {:ok,
         %{
           key: line |> binary_part(0, separator_offset) |> trim_horizontal(),
           value:
             line
             |> binary_part(value_offset, byte_size(line) - value_offset)
             |> trim_horizontal(),
           separator: separator,
           separator_offset: separator_offset
         }}
    end
  end

  @spec trim_horizontal(binary()) :: binary()
  def trim_horizontal(value), do: Regex.replace(~r/^[ \t]+|[ \t]+$/, value, "")

  defp find_separator("", _separators, _offset, _whitespace_found), do: :error

  defp find_separator(remaining, separators, offset, whitespace_found) do
    {character, rest} = String.next_codepoint(remaining)

    cond do
      String.contains?(separators, character) ->
        if offset == 0, do: :error, else: {:ok, character, offset}

      not whitespace_found and token_character?(character) ->
        find_separator(rest, separators, offset + byte_size(character), false)

      offset != 0 and character in [" ", "\t"] ->
        find_separator(rest, separators, offset + byte_size(character), true)

      true ->
        :error
    end
  end

  defp token_character?(<<character>>) do
    character in ?A..?Z or character in ?a..?z or character in ?0..?9 or character == ?-
  end

  defp token_character?(_character), do: false
end
