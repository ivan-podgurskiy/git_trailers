defmodule GitTrailers do
  @moduledoc """
  Parses, serializes, and manipulates Git commit-message trailers.

  Trailer blocks are detected using the rules from
  `git-interpret-trailers(1)`, including folded values, the 25% rule,
  configurable separators, and patch-divider handling. All operations are
  performed on in-memory binaries without invoking Git or reading repository
  configuration.

  `parse/2` is total for binary message content: text that does not contain an
  accepted trailer block returns an empty `trailers` list. Invalid arguments
  and options raise `ArgumentError`.
  """

  alias GitTrailers.Manipulator
  alias GitTrailers.Parser
  alias GitTrailers.Result
  alias GitTrailers.Serializer

  @type trailer_input ::
          {binary(), binary()} | %{required(:key) => binary(), required(:value) => binary()}
  @type where :: :end | :start | :after | :before
  @type if_exists ::
          :add_if_different_neighbor | :add_if_different | :add | :replace | :do_nothing
  @type if_missing :: :add | :do_nothing
  @type parse_option ::
          {:separators, binary()}
          | {:divider, boolean()}
          | {:unfold, boolean()}
          | {:known_keys, [binary()]}
  @type add_option ::
          {:where, where()}
          | {:if_exists, if_exists()}
          | {:if_missing, if_missing()}
          | {:trim_empty, boolean()}
          | {:separators, binary()}
          | {:divider, boolean()}

  @doc """
  Parses the accepted trailer block at the end of `message`.

  Supported options are:

    * `:separators` — accepted separator characters; defaults to `":"`
    * `:divider` — stop before a patch divider; defaults to `true`
    * `:unfold` — join continuation lines with spaces; defaults to `true`
    * `:known_keys` — additional case-insensitive keys that satisfy Git's
      recognized-trailer requirement for the 25% rule

  Source lines, including their original line endings, remain available in
  each trailer's `GitTrailers.Trailer.raw` field.
  """
  @spec parse(binary(), [parse_option()]) :: {:ok, Result.t()}
  def parse(message, options \\ [])

  def parse(message, options) when is_binary(message) and is_list(options) do
    Parser.parse(message, options)
  end

  def parse(_message, _options) do
    raise ArgumentError, "message must be a binary and options must be a keyword list"
  end

  @doc """
  Formats one trailer as `key<separator> value`.

  The separator must be one non-whitespace character. The key and value are
  trimmed, and values containing CR or LF are rejected.
  """
  @spec format(trailer_input(), binary()) :: binary()
  def format(trailer, separator \\ ":"), do: Serializer.format(trailer, separator)

  @doc """
  Serializes trailers in canonical `Key: value` form, joined with LF.

  The returned binary does not have a terminal newline.
  """
  @spec serialize([trailer_input()]) :: binary()
  defdelegate serialize(trailers), to: Serializer

  @doc """
  Adds trailers to a commit message using Git-compatible placement policies.

  Supported options are:

    * `:where` — `:end`, `:start`, `:after`, or `:before`; defaults to `:end`
    * `:if_exists` — `:add_if_different_neighbor`, `:add_if_different`,
      `:add`, `:replace`, or `:do_nothing`; defaults to
      `:add_if_different_neighbor`
    * `:if_missing` — `:add` or `:do_nothing`; defaults to `:add`
    * `:trim_empty` — remove trailers with whitespace-only values; defaults
      to `false`
    * `:separators` — accepted separators and the source of the first
      separator used for inserted lines; defaults to `":"`
    * `:divider` — insert before patch divider material; defaults to `true`

  Existing messages are returned byte-for-byte when no mutation is required.
  Changed trailer blocks use LF and canonical spacing while bytes outside the
  block are preserved.
  """
  @spec add(binary(), [trailer_input()], [add_option()]) :: binary()
  def add(message, trailers, options \\ []), do: Manipulator.add(message, trailers, options)
end
