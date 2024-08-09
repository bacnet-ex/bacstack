defmodule BACnet.Protocol.EventTimestamps do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetTimestamp

  @type t :: %__MODULE__{
          to_offnormal: BACnetTimestamp.t(),
          to_fault: BACnetTimestamp.t(),
          to_normal: BACnetTimestamp.t()
        }

  @fields [:to_offnormal, :to_fault, :to_normal]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet event timestamps into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = timestamps, _opts \\ []) do
    with {:ok, [offnormal]} <- BACnetTimestamp.encode(timestamps.to_offnormal),
         {:ok, [fault]} <- BACnetTimestamp.encode(timestamps.to_fault),
         {:ok, [normal]} <- BACnetTimestamp.encode(timestamps.to_normal) do
      {:ok, [offnormal, fault, normal]}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parses a BACnet event timestamps from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [stamp1, stamp2, stamp3 | rest] ->
        with {:ok, {offnormal, _rest}} <- BACnetTimestamp.parse([stamp1]),
             {:ok, {fault, _rest}} <- BACnetTimestamp.parse([stamp2]),
             {:ok, {normal, _rest}} <- BACnetTimestamp.parse([stamp3]) do
          eventstamps = %__MODULE__{
            to_offnormal: offnormal,
            to_fault: fault,
            to_normal: normal
          }

          {:ok, {eventstamps, rest}}
        else
          {:error, _err} = err -> err
        end

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given event timestamps is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          to_offnormal: %BACnetTimestamp{} = off,
          to_fault: %BACnetTimestamp{} = fault,
          to_normal: %BACnetTimestamp{} = normal
        } = _t
      ) do
    BACnetTimestamp.valid?(off) and BACnetTimestamp.valid?(fault) and
      BACnetTimestamp.valid?(normal)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
