defmodule GitTrailers.Result do
  @moduledoc """
  The structured result returned by `GitTrailers.parse/2`.

  `block_start` is the zero-based physical line index of the accepted trailer
  block, or `-1` when no block was found. `body` excludes the subject, the
  separating blank line, and the trailer block.
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
