defmodule GitTrailers.Parser do
  @moduledoc false

  alias GitTrailers.Lines
  alias GitTrailers.Result
  alias GitTrailers.Trailer
  alias GitTrailers.TrailerLine

  @built_in_prefixes ["Signed-off-by: ", "(cherry picked from commit "]
  @default_options %{separators: ":", divider: true, unfold: true, known_keys: []}
  @option_keys Map.keys(@default_options)

  @type options :: %{
          separators: binary(),
          divider: boolean(),
          unfold: boolean(),
          known_keys: [binary()]
        }

  @spec parse(binary(), keyword()) :: {:ok, Result.t()}
  def parse(message, options) do
    normalized = normalize_options(options)
    lines = Lines.scan(message)
    {effective_end, has_divider} = effective_end(message, lines, normalized.divider)

    block_start =
      block_start(lines, effective_end, normalized.separators, normalized.known_keys)

    subject = lines |> List.first() |> line_content()

    result =
      if block_start == -1 do
        %Result{
          subject: subject,
          body: slice_from(message, lines |> List.first() |> line_stop()),
          block_start: -1,
          has_divider: has_divider
        }
      else
        boundary_start = boundary_start(lines, block_start)

        %Result{
          trailers: parse_entries(lines, block_start, effective_end, normalized),
          subject: subject,
          body: slice(message, lines |> List.first() |> line_stop(), boundary_start),
          block_start: block_start,
          has_divider: has_divider
        }
      end

    {:ok, result}
  end

  @spec normalize_options(keyword()) :: options()
  def normalize_options(options) do
    unless Keyword.keyword?(options) do
      raise ArgumentError, "options must be a keyword list"
    end

    case Keyword.keys(options) -- @option_keys do
      [] -> :ok
      [unknown | _rest] -> raise ArgumentError, "unknown option: #{inspect(unknown)}"
    end

    normalized = Map.merge(@default_options, Map.new(options))
    validate_options!(normalized)
    normalized
  end

  defp validate_options!(options) do
    unless is_binary(options.separators) and options.separators != "" do
      raise ArgumentError, ":separators must be a non-empty string"
    end

    unless is_boolean(options.divider) do
      raise ArgumentError, ":divider must be a boolean"
    end

    unless is_boolean(options.unfold) do
      raise ArgumentError, ":unfold must be a boolean"
    end

    unless is_list(options.known_keys) and Enum.all?(options.known_keys, &is_binary/1) do
      raise ArgumentError, ":known_keys must be a list of strings"
    end
  end

  defp effective_end(message, lines, divider?) do
    scissors_end =
      Enum.find_value(lines, byte_size(message), fn line ->
        if scissors?(line.content), do: line.start
      end)

    {divider_end, has_divider} =
      if divider? do
        case Enum.find(lines, &(Map.fetch!(&1, :start) < scissors_end and divider?(&1.content))) do
          nil -> {scissors_end, false}
          line -> {line.start, true}
        end
      else
        {scissors_end, false}
      end

    effective_end =
      lines
      |> Enum.reverse()
      |> Enum.reduce_while(divider_end, fn line, offset ->
        cond do
          line.stop > offset -> {:cont, offset}
          blank?(line.content) or comment?(line.content) -> {:cont, line.start}
          true -> {:halt, offset}
        end
      end)

    {effective_end, has_divider}
  end

  defp block_start(lines, effective_end, separators, known_keys) do
    case last_line_before(lines, effective_end) do
      -1 -> -1
      end_index -> scan_block(lines, end_index, separators, known_keys, {0, 0, 0, false})
    end
  end

  defp scan_block(_lines, index, _separators, _known_keys, _counts) when index < 0, do: -1

  defp scan_block(lines, index, separators, known_keys, counts) do
    line = Enum.at(lines, index)
    {trailer_lines, non_trailer_lines, possible_continuations, recognized?} = counts

    cond do
      blank?(line.content) ->
        non_trailer_lines = non_trailer_lines + possible_continuations

        if accepted_block?(trailer_lines, non_trailer_lines, recognized?) do
          index + 1
        else
          -1
        end

      comment?(line.content) ->
        scan_block(lines, index - 1, separators, known_keys, counts)

      recognized_prefix?(line.content) ->
        scan_block(lines, index - 1, separators, known_keys, {
          trailer_lines + 1,
          non_trailer_lines,
          0,
          true
        })

      true ->
        scan_non_prefix_line(lines, index, separators, known_keys, counts)
    end
  end

  defp scan_non_prefix_line(lines, index, separators, known_keys, counts) do
    line = Enum.at(lines, index)
    {trailer_lines, non_trailer_lines, possible_continuations, recognized?} = counts

    case TrailerLine.parse(line.content, separators) do
      {:ok, trailer} ->
        scan_block(lines, index - 1, separators, known_keys, {
          trailer_lines + 1,
          non_trailer_lines,
          0,
          recognized? or known_key?(trailer.key, known_keys)
        })

      :error ->
        if continuation?(line.content) do
          scan_block(lines, index - 1, separators, known_keys, {
            trailer_lines,
            non_trailer_lines,
            possible_continuations + 1,
            recognized?
          })
        else
          scan_block(lines, index - 1, separators, known_keys, {
            trailer_lines,
            non_trailer_lines + possible_continuations + 1,
            0,
            recognized?
          })
        end
    end
  end

  defp accepted_block?(trailer_lines, non_trailer_lines, recognized?) do
    trailer_lines > 0 and
      (non_trailer_lines == 0 or (recognized? and trailer_lines * 3 >= non_trailer_lines))
  end

  defp parse_entries(lines, block_start, effective_end, options) do
    end_index = last_line_before(lines, effective_end)
    do_parse_entries(lines, block_start, end_index, options, []) |> Enum.reverse()
  end

  defp do_parse_entries(_lines, index, end_index, _options, trailers) when index > end_index,
    do: trailers

  defp do_parse_entries(lines, index, end_index, options, trailers) do
    line = Enum.at(lines, index)

    case TrailerLine.parse(line.content, options.separators) do
      :error ->
        do_parse_entries(lines, index + 1, end_index, options, trailers)

      {:ok, parsed} ->
        continuation_end = continuation_end(lines, index, end_index)
        value_lines = Enum.slice(lines, index, continuation_end - index + 1)

        trailer = %Trailer{
          key: parsed.key,
          value: normalize_value(value_lines, parsed.separator_offset, options.unfold),
          raw: Enum.map_join(value_lines, & &1.raw),
          separator: parsed.separator
        }

        do_parse_entries(lines, continuation_end + 1, end_index, options, [trailer | trailers])
    end
  end

  defp continuation_end(lines, start, end_index) do
    Enum.reduce_while((start + 1)..end_index//1, start, fn index, current_end ->
      if continuation?(Enum.at(lines, index).content) do
        {:cont, index}
      else
        {:halt, current_end}
      end
    end)
  end

  defp normalize_value([first | rest], separator_offset, true) do
    value_offset = separator_offset + 1

    first_value =
      binary_part(first.content, value_offset, byte_size(first.content) - value_offset)

    [first_value | Enum.map(rest, & &1.content)]
    |> Enum.map(&TrailerLine.trim_horizontal/1)
    |> Enum.join(" ")
    |> TrailerLine.trim_horizontal()
  end

  defp normalize_value([first | rest], separator_offset, false) do
    value_offset = separator_offset + 1

    first_value =
      binary_part(first.content, value_offset, byte_size(first.content) - value_offset)

    rest
    |> Enum.reduce({first_value, first}, fn line, {value, previous} ->
      {value <> previous.eol <> line.content, line}
    end)
    |> elem(0)
    |> TrailerLine.trim_horizontal()
  end

  defp last_line_before(lines, offset) do
    lines
    |> Enum.reverse()
    |> Enum.find_value(-1, fn line -> if line.stop <= offset, do: line.index end)
  end

  defp boundary_start(lines, block_start) do
    case Enum.at(lines, block_start - 1) do
      %{content: content, start: start} ->
        if blank?(content), do: start, else: Enum.at(lines, block_start).start

      nil ->
        Enum.at(lines, block_start).start
    end
  end

  defp line_content(nil), do: ""
  defp line_content(line), do: line.content
  defp line_stop(nil), do: 0
  defp line_stop(line), do: line.stop

  defp slice_from(message, start), do: binary_part(message, start, byte_size(message) - start)
  defp slice(message, start, stop), do: binary_part(message, start, stop - start)

  defp blank?(line), do: Regex.match?(~r/^[ \t]*$/, line)
  defp continuation?(line), do: String.starts_with?(line, [" ", "\t"])
  defp comment?(line), do: String.starts_with?(line, "#")
  defp divider?(line), do: Regex.match?(~r/^---(?:[ \t].*)?$/, line)
  defp scissors?(line), do: Regex.match?(~r/^#\s*-{20,}\s*>8\s*-{20,}\s*$/, line)
  defp recognized_prefix?(line), do: Enum.any?(@built_in_prefixes, &String.starts_with?(line, &1))

  defp known_key?(key, known_keys) do
    normalized_key = String.downcase(key)
    Enum.any?(known_keys, &(String.downcase(&1) == normalized_key))
  end
end
