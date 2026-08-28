defmodule GitTrailers.Result do
  @moduledoc """
  The structured result of parsing a commit message.
  """

  alias GitTrailers.Trailer

  defstruct trailers: [], subject: "", body: "", block_start: -1, has_divider: false

  @type t :: %__MODULE__{
          trailers: [Trailer.t()],
          subject: binary(),
          body: binary(),
          block_start: integer(),
          has_divider: boolean()
        }
end
