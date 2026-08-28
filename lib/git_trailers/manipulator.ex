defmodule GitTrailers.Manipulator do
  @moduledoc false

  alias GitTrailers.Lines
  alias GitTrailers.Parser
  alias GitTrailers.Serializer
  alias GitTrailers.TrailerLine

  @default_options %{
    where: :end,
    if_exists: :add_if_different_neighbor,
    if_missing: :add,
    trim_empty: false,
    separators: ":",
    divider: true
  }
  @option_keys Map.keys(@default_options)
  @where_values [:end, :start, :after, :before]
  @if_exists_values [
    :add_if_different_neighbor,
    :add_if_different,
    :add,
    :replace,
    :do_nothing
  ]
  @if_missing_values [:add, :do_nothing]

  @type item ::
          {:trailer,
           %{key: binary(), value: binary(), first_value: binary(), continuations: [binary()]}}
          | {:other, binary()}

  @spec add(binary(), [Serializer.trailer_input()], keyword()) :: binary()
  def add(message, trailers, options) do
    validate_arguments!(message, trailers)
    normalized = normalize_options(options)

    if trailers == [] do
      message
    else
      incoming = Enum.map(trailers, &Serializer.validate_trailer!/1)
      mutate(message, incoming, normalized)
    end
  end

  defp validate_arguments!(message, trailers) do
    unless is_binary(message), do: raise(ArgumentError, "message must be a binary")
    unless is_list(trailers), do: raise(ArgumentError, "trailers must be a list")
  end

  defp normalize_options(options) do
    unless Keyword.keyword?(options), do: raise(ArgumentError, "options must be a keyword list")

    case Keyword.keys(options) -- @option_keys do
      [] -> :ok
      [unknown | _rest] -> raise ArgumentError, "unknown option: #{inspect(unknown)}"
    end

    normalized = Map.merge(@default_options, Map.new(options))
    validate_options!(normalized)
    normalized
  end

  defp validate_options!(options) do
    unless options.where in @where_values, do: raise(ArgumentError, ":where is invalid")

    unless options.if_exists in @if_exists_values,
      do: raise(ArgumentError, ":if_exists is invalid")

    unless options.if_missing in @if_missing_values,
      do: raise(ArgumentError, ":if_missing is invalid")

    unless is_boolean(options.trim_empty),
      do: raise(ArgumentError, ":trim_empty must be a boolean")

    unless is_boolean(options.divider), do: raise(ArgumentError, ":divider must be a boolean")

    unless is_binary(options.separators) and options.separators != "" and
             not String.contains?(options.separators, ["\r", "\n"]) do
      raise ArgumentError, ":separators must be a non-empty string without CR or LF"
    end
  end

  defp mutate(message, incoming, options) do
    lines = Lines.scan(message)

    {:ok, parsed} =
      Parser.parse(message,
        separators: options.separators,
        divider: options.divider,
        unfold: false
      )

    {suffix_start, _has_divider} = Parser.effective_end(message, lines, options.divider)

    fallback_start =
      if parsed.block_start == -1 do
        fallback_block_start(lines, suffix_start, options.separators)
      else
        -1
      end

    trailer_block_start =
      if parsed.block_start == -1, do: fallback_start, else: parsed.block_start

    has_block? = trailer_block_start != -1
    block_start = if has_block?, do: Enum.at(lines, trailer_block_start).start, else: suffix_start

    items =
      if has_block? do
        parse_block_items(lines, trailer_block_start, suffix_start, options.separators)
      else
        []
      end

    {items, trimmed?} = trim_empty(items, options.trim_empty)
    {items, inserted?} = add_all(items, incoming, options)

    reconstruct(
      message,
      lines,
      items,
      block_start,
      suffix_start,
      has_block?,
      inserted?,
      trimmed?,
      options
    )
  end

  defp trim_empty(items, false), do: {items, false}

  defp trim_empty(items, true) do
    kept = Enum.reject(items, &empty_trailer?/1)
    {kept, kept != items}
  end

  defp empty_trailer?({:trailer, trailer}), do: String.trim(trailer.value) == ""
  defp empty_trailer?({:other, _content}), do: false

  defp add_all(items, incoming, options) do
    Enum.reduce(incoming, {items, false}, fn trailer, {current, changed?} ->
      if options.trim_empty and trailer.value == "" do
        {current, changed?}
      else
        {next, added?} = apply_one(current, trailer, options)
        {next, changed? or added?}
      end
    end)
  end

  defp apply_one(items, trailer, options) do
    matching = matching_indexes(items, trailer.key)

    cond do
      matching == [] and options.if_missing == :do_nothing ->
        {items, false}

      matching != [] and options.if_exists == :do_nothing ->
        {items, false}

      matching != [] and options.if_exists == :add_if_different and
          Enum.any?(matching, &same_value?(trailer_at(items, &1).value, trailer.value)) ->
        {items, false}

      true ->
        insert_or_replace(items, trailer, matching, options)
    end
  end

  defp insert_or_replace(items, trailer, matching, options) do
    index = insertion_index(items, trailer.key, options.where, matching)

    if duplicate_neighbor?(items, trailer, matching, index, options) do
      {items, false}
    else
      {next, index} = maybe_replace(items, matching, index, options.if_exists)

      item =
        {:trailer,
         %{key: trailer.key, value: trailer.value, first_value: trailer.value, continuations: []}}

      {List.insert_at(next, index, item), true}
    end
  end

  defp duplicate_neighbor?(_items, _trailer, [], _index, _options), do: false

  defp duplicate_neighbor?(items, trailer, _matching, index, options) do
    if options.if_exists == :add_if_different_neighbor do
      neighbor_index = if options.where in [:before, :start], do: index, else: index - 1

      case Enum.at(items, neighbor_index) do
        {:trailer, neighbor} ->
          same_token?(neighbor.key, trailer.key) and same_value?(neighbor.value, trailer.value)

        _other ->
          false
      end
    else
      false
    end
  end

  defp maybe_replace(items, matching, index, :replace) when matching != [] do
    remove = Enum.min_by(matching, &abs(&1 - index))
    {List.delete_at(items, remove), if(remove < index, do: index - 1, else: index)}
  end

  defp maybe_replace(items, _matching, index, _if_exists), do: {items, index}

  defp matching_indexes(items, key) do
    items
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {{:trailer, trailer}, index} -> if same_token?(trailer.key, key), do: [index], else: []
      {{:other, _content}, _index} -> []
    end)
  end

  defp insertion_index(_items, _key, :start, _matching), do: 0
  defp insertion_index(items, _key, _where, []), do: length(items)
  defp insertion_index(_items, _key, :before, matching), do: hd(matching)
  defp insertion_index(_items, _key, :after, matching), do: List.last(matching) + 1
  defp insertion_index(items, _key, :end, _matching), do: length(items)

  defp trailer_at(items, index) do
    {:trailer, trailer} = Enum.at(items, index)
    trailer
  end

  defp same_token?(existing, incoming) do
    normalize = fn token ->
      ~r/[^A-Za-z0-9]+$/
      |> Regex.replace(token, "")
      |> String.downcase()
    end

    left = normalize.(existing)
    right = normalize.(incoming)
    String.starts_with?(left, right) or String.starts_with?(right, left)
  end

  defp same_value?(existing, incoming) do
    String.downcase(String.trim(existing)) == String.downcase(String.trim(incoming))
  end

  defp parse_block_items(lines, start, end_offset, separators) do
    do_parse_block_items(lines, start, end_offset, separators, []) |> Enum.reverse()
  end

  defp do_parse_block_items(lines, index, end_offset, separators, items) do
    case Enum.at(lines, index) do
      nil ->
        items

      %{start: start} when start >= end_offset ->
        items

      line ->
        case TrailerLine.parse(line.content, separators) do
          :error ->
            do_parse_block_items(lines, index + 1, end_offset, separators, [
              {:other, line.content} | items
            ])

          {:ok, trailer} ->
            {continuations, next_index} = take_continuations(lines, index + 1, end_offset, [])

            value =
              [trailer.value | continuations]
              |> Enum.map(&TrailerLine.trim_horizontal/1)
              |> Enum.join(" ")
              |> String.trim()

            item =
              {:trailer,
               %{
                 key: trailer.key,
                 value: value,
                 first_value: trailer.value,
                 continuations: continuations
               }}

            do_parse_block_items(lines, next_index, end_offset, separators, [item | items])
        end
    end
  end

  defp take_continuations(lines, index, end_offset, continuations) do
    case Enum.at(lines, index) do
      %{start: start, content: content} when start < end_offset ->
        if String.starts_with?(content, [" ", "\t"]) do
          take_continuations(lines, index + 1, end_offset, [content | continuations])
        else
          {Enum.reverse(continuations), index}
        end

      _line ->
        {Enum.reverse(continuations), index}
    end
  end

  defp fallback_block_start(lines, end_offset, separators) do
    if separator_overlaps_token?(separators) do
      scan_fallback_start(lines, length(lines) - 1, end_offset, separators, 0)
    else
      -1
    end
  end

  defp scan_fallback_start(_lines, index, _end_offset, _separators, _trailers) when index < 0,
    do: -1

  defp scan_fallback_start(lines, index, end_offset, separators, trailers) do
    line = Enum.at(lines, index)

    cond do
      line.stop > end_offset ->
        scan_fallback_start(lines, index - 1, end_offset, separators, trailers)

      blank?(line.content) ->
        start = index + 1

        if trailers > 0 and fallback_block?(lines, start, end_offset, separators) do
          start
        else
          -1
        end

      String.starts_with?(line.content, "#") ->
        scan_fallback_start(lines, index - 1, end_offset, separators, trailers)

      String.starts_with?(line.content, [" ", "\t"]) ->
        scan_fallback_start(lines, index - 1, end_offset, separators, trailers)

      match?({:ok, _trailer}, TrailerLine.parse(line.content, separators)) ->
        scan_fallback_start(lines, index - 1, end_offset, separators, trailers + 1)

      true ->
        -1
    end
  end

  defp fallback_block?(lines, start, end_offset, separators) do
    lines
    |> Enum.drop(start)
    |> Enum.reduce_while(false, fn line, saw_trailer? ->
      cond do
        line.start >= end_offset -> {:halt, saw_trailer?}
        String.starts_with?(line.content, "#") -> {:cont, saw_trailer?}
        String.starts_with?(line.content, [" ", "\t"]) and saw_trailer? -> {:cont, true}
        String.starts_with?(line.content, [" ", "\t"]) -> {:halt, false}
        match?({:ok, _trailer}, TrailerLine.parse(line.content, separators)) -> {:cont, true}
        true -> {:halt, false}
      end
    end)
  end

  defp separator_overlaps_token?(separators) do
    separators
    |> String.graphemes()
    |> Enum.any?(&Regex.match?(~r/^[A-Za-z0-9-]$/, &1))
  end

  defp reconstruct(
         message,
         _lines,
         _items,
         _block_start,
         _suffix_start,
         _has_block?,
         false,
         false,
         _options
       ),
       do: message

  defp reconstruct(
         message,
         _lines,
         [],
         _block_start,
         _suffix_start,
         false,
         _inserted?,
         _trimmed?,
         _options
       ),
       do: message

  defp reconstruct(
         message,
         lines,
         items,
         block_start,
         suffix_start,
         has_block?,
         inserted?,
         _trimmed?,
         options
       ) do
    separator = options.separators |> String.next_codepoint() |> elem(0)

    if has_block? do
      prefix = slice(message, 0, block_start)
      suffix = slice_from(message, suffix_start)
      had_terminal_newline? = last_line_before(lines, suffix_start).eol != ""
      prefix <> serialize_block(items, separator, inserted? or had_terminal_newline?) <> suffix
    else
      prefix = message |> slice(0, suffix_start) |> prepare_new_block_prefix()
      suffix = slice_from(message, suffix_start)
      prefix <> serialize_block(items, separator, true) <> suffix
    end
  end

  defp serialize_block(items, separator, terminal_newline?) do
    block =
      Enum.map_join(items, "\n", fn
        {:other, content} ->
          content

        {:trailer, trailer} ->
          Enum.join(
            [trailer.key <> separator <> " " <> trailer.first_value | trailer.continuations],
            "\n"
          )
      end)

    if terminal_newline? and block != "", do: block <> "\n", else: block
  end

  defp prepare_new_block_prefix(prefix) do
    cond do
      String.ends_with?(prefix, "\n\n") -> prefix
      String.ends_with?(prefix, "\n") -> prefix <> "\n"
      prefix == "" -> "\n"
      true -> prefix <> "\n\n"
    end
  end

  defp last_line_before(lines, offset) do
    Enum.find(Enum.reverse(lines), %{eol: ""}, &(&1.stop <= offset))
  end

  defp slice_from(message, start), do: binary_part(message, start, byte_size(message) - start)
  defp slice(message, start, stop), do: binary_part(message, start, stop - start)
  defp blank?(line), do: Regex.match?(~r/^[ \t]*$/, line)
end
