defmodule GitTrailers.Trailer do
  @moduledoc """
  A parsed Git trailer and its exact source text.
  """

  @enforce_keys [:key, :value, :raw, :separator]
  defstruct [:key, :value, :raw, :separator]

  @type t :: %__MODULE__{
          key: binary(),
          value: binary(),
          raw: binary(),
          separator: binary()
        }
end
