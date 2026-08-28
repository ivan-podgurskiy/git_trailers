defmodule GitTrailers do
  @moduledoc """
  Parses and manipulates Git commit-message trailers.
  """

  alias GitTrailers.Manipulator
  alias GitTrailers.Parser
  alias GitTrailers.Result
  alias GitTrailers.Serializer

  @type trailer_input :: Serializer.trailer_input()

  @spec parse(binary(), keyword()) :: {:ok, Result.t()}
  def parse(message, options \\ [])

  def parse(message, options) when is_binary(message) and is_list(options) do
    Parser.parse(message, options)
  end

  def parse(_message, _options) do
    raise ArgumentError, "message must be a binary and options must be a keyword list"
  end

  @spec format(trailer_input(), binary()) :: binary()
  def format(trailer, separator \\ ":"), do: Serializer.format(trailer, separator)

  @spec serialize([trailer_input()]) :: binary()
  defdelegate serialize(trailers), to: Serializer

  @spec add(binary(), [trailer_input()], keyword()) :: binary()
  def add(message, trailers, options \\ []), do: Manipulator.add(message, trailers, options)
end
