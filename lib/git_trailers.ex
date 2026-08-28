defmodule GitTrailers do
  @moduledoc """
  Parses and manipulates Git commit-message trailers.
  """

  alias GitTrailers.Parser
  alias GitTrailers.Result

  @spec parse(binary(), keyword()) :: {:ok, Result.t()}
  def parse(message, options \\ [])

  def parse(message, options) when is_binary(message) and is_list(options) do
    Parser.parse(message, options)
  end

  def parse(_message, _options) do
    raise ArgumentError, "message must be a binary and options must be a keyword list"
  end
end
