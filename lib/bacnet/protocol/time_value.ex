defmodule BACnet.Protocol.TimeValue do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetTime

  @typedoc """
  Represents a BACnet Time Value (used in Daily Schedule and Special Event).
  """
  @type t :: %__MODULE__{
          time: BACnetTime.t(),
          value: ApplicationTags.Encoding.t()
        }

  @fields [
    :time,
    :value
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet time value into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = time_value, _opts \\ []) do
    with {:ok, value} <- ApplicationTags.Encoding.to_encoding(time_value.value) do
      params = [
        {:time, time_value.time},
        value
      ]

      {:ok, params}
    end
  end

  @doc """
  Parses a BACnet time value from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:time, time},
        value
        | rest
      ] ->
        with {:ok, value} <- ApplicationTags.Encoding.create(value) do
          tv = %__MODULE__{
            time: time,
            value: value
          }

          {:ok, {tv, rest}}
        end

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given time value is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          time: %BACnetTime{} = time,
          value: %ApplicationTags.Encoding{encoding: :primitive}
        } = _t
      ) do
    BACnetTime.valid?(time)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
