defmodule BACnet.Protocol.EventTimestamps do
  @moduledoc """
  Event Timestamps is a composite structure that holds three BACnet Timestamp values
  recording the most recent transitions of an event-generating object into the
  off-normal, fault, and normal states. It is carried inside Event Information
  entries and inside certain event notification parameters.

  The presence of these timestamps allows clients to determine exactly when an
  alarm condition appeared, when it became a fault, and when it returned to normal.
  This information is extremely valuable for post-mortem analysis, for computing
  the duration of an alarm, and for correlating events across multiple devices
  on a site. If a particular transition has never occurred, the corresponding
  timestamp field is usually encoded as a "time of day" with all fields set to
  255 (unspecified).
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetTimestamp

  @typedoc """
  Represents the timestamps of the last transitions to the offnormal, fault,
  and normal event states.
  """
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
