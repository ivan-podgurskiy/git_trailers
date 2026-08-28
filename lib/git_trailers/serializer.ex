defmodule GitTrailers.Serializer do
  @moduledoc false

  @type trailer_input ::
          {binary(), binary()} | %{required(:key) => binary(), required(:value) => binary()}

  @spec format(trailer_input(), binary()) :: binary()
  def format(trailer, separator) do
    %{key: key, value: value} = validate_trailer!(trailer)
    validate_separator!(separator)
    key <> separator <> " " <> value
  end

  @spec serialize([trailer_input()]) :: binary()
  def serialize(trailers) when is_list(trailers) do
    Enum.map_join(trailers, "\n", &format(&1, ":"))
  end

  def serialize(_trailers), do: raise(ArgumentError, "trailers must be a list")

  @spec validate_trailer!(trailer_input()) :: %{key: binary(), value: binary()}
  def validate_trailer!({key, value}), do: validate_key_and_value!(key, value)
  def validate_trailer!(%{key: key, value: value}), do: validate_key_and_value!(key, value)

  def validate_trailer!(_trailer) do
    raise ArgumentError, "trailer must be a {key, value} tuple or a map with :key and :value"
  end

  @spec validate_separator!(binary()) :: :ok
  def validate_separator!(separator) when is_binary(separator) do
    if String.length(separator) == 1 and String.trim(separator) != "" do
      :ok
    else
      raise ArgumentError, "separator must be one non-whitespace character"
    end
  end

  def validate_separator!(_separator) do
    raise ArgumentError, "separator must be one non-whitespace character"
  end

  defp validate_key_and_value!(key, value) when is_binary(key) and is_binary(value) do
    normalized_key = String.trim(key)
    normalized_value = String.trim(value)

    unless Regex.match?(~r/^[A-Za-z0-9-]+$/, normalized_key) do
      raise ArgumentError, "trailer key must contain only letters, digits, and hyphens"
    end

    if String.contains?(value, ["\r", "\n"]) do
      raise ArgumentError, "trailer value must not contain CR or LF characters"
    end

    %{key: normalized_key, value: normalized_value}
  end

  defp validate_key_and_value!(_key, _value) do
    raise ArgumentError, "trailer key and value must be strings"
  end
end
