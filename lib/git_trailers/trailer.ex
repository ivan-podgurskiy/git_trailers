defmodule GitTrailers.Trailer do
  @moduledoc """
  A parsed Git trailer and its exact source text.

  `value` is unfolded by default. `raw` preserves the complete physical source
  lines and line endings, while `separator` records the character that was
  actually parsed.
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
