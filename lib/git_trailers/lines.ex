defmodule GitTrailers.Lines do
  @moduledoc false

  @type line :: %{
          index: non_neg_integer(),
          start: non_neg_integer(),
          stop: non_neg_integer(),
          content: binary(),
          raw: binary(),
          eol: binary()
        }

  @spec scan(binary()) :: [line()]
  def scan(input) when is_binary(input) do
    input
    |> do_scan(0, 0, [])
    |> Enum.reverse()
  end

  @spec newline([line()]) :: binary()
  def newline(lines) do
    case Enum.find(lines, &(&1.eol != "")) do
      nil -> "\n"
      line -> line.eol
    end
  end

  defp do_scan("", _index, _offset, lines), do: lines

  defp do_scan(input, index, offset, lines) do
    case :binary.match(input, "\n") do
      :nomatch ->
        length = byte_size(input)
        [line(index, offset, offset + length, input, input, "") | lines]

      {newline_offset, 1} ->
        {content_length, eol} = content_length_and_eol(input, newline_offset)
        raw_length = newline_offset + 1
        content = binary_part(input, 0, content_length)
        raw = binary_part(input, 0, raw_length)
        rest = binary_part(input, raw_length, byte_size(input) - raw_length)
        stop = offset + raw_length

        do_scan(rest, index + 1, stop, [line(index, offset, stop, content, raw, eol) | lines])
    end
  end

  defp content_length_and_eol(input, newline_offset) when newline_offset > 0 do
    if :binary.at(input, newline_offset - 1) == ?\r do
      {newline_offset - 1, "\r\n"}
    else
      {newline_offset, "\n"}
    end
  end

  defp content_length_and_eol(_input, newline_offset), do: {newline_offset, "\n"}

  defp line(index, start, stop, content, raw, eol) do
    %{index: index, start: start, stop: stop, content: content, raw: raw, eol: eol}
  end
end
