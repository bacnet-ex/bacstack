defmodule BACnet.Protocol.Services.Ack.GetAlarmSummaryAck do
  @moduledoc """
  The Get Alarm Summary Acknowledgment is the response to a Get Alarm Summary
  service request. It returns a list of Alarm Summary records, one for each
  object in the device that is currently in an alarm or fault state and that
  the requesting client is authorized to observe.

  Each entry in the list contains the object identifier, its current event
  state, and the acknowledged transitions bit string. This service is primarily
  intended for operator workstations that need to build or refresh a list of
  active alarms without having to poll every object individually.

  Although newer installations often prefer the more capable Get Event
  Information service, Get Alarm Summary remains widely supported for
  compatibility with older clients and devices.
  """

  alias BACnet.Protocol.AlarmSummary
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants

  require Constants

  @typedoc """
  Response for Get Alarm Summary containing the list of active alarm summaries from the device.
  """
  @type t :: %__MODULE__{
          summaries: [AlarmSummary.t()]
        }

  @fields [:summaries]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :get_alarm_summary
                )

  @doc """
  Converts a received `BACnet.Protocol.APDU.ComplexACK` APDU into a struct.
  """
  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(%ComplexACK{service: @service_name} = ack) do
    case parse_summaries(ack.payload) do
      {:ok, summary} ->
        struc = %__MODULE__{
          summaries: summary
        }

        {:ok, struc}

      {:error, :invalid_tags} ->
        {:error, :invalid_service_ack}

      {:error, _err} = err ->
        err
    end
  end

  def from_apdu(_ack) do
    {:error, :invalid_service_ack}
  end

  @doc """
  Constructs a `BACnet.Protocol.APDU.ComplexACK` APDU from a
  `BACnet.Protocol.Services.Ack.GetAlarmSummaryAck` struct.

  Used by a server when responding to a Get Alarm Summary request.
  """
  @spec to_apdu(t(), 0..255) :: {:ok, ComplexACK.t()} | {:error, term()}
  def to_apdu(ack, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = ack, invoke_id) when invoke_id in 0..255 do
    with {:ok, summaries} <- encode_summaries(ack.summaries) do
      new_ack = %ComplexACK{
        invoke_id: invoke_id,
        sequence_number: nil,
        proposed_window_size: nil,
        service: @service_name,
        payload: summaries
      }

      {:ok, new_ack}
    end
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end

  defp parse_summaries(payload) do
    result =
      Enum.reduce_while(1..100_000//1, {payload, []}, fn
        _iter, {tags, acc} ->
          case AlarmSummary.parse(tags) do
            {:ok, {item, []}} -> {:halt, {:ok, [item | acc]}}
            {:ok, {item, rest}} -> {:cont, {rest, [item | acc]}}
            {:error, _term} = term -> {:halt, term}
          end
      end)

    case result do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      term -> term
    end
  end

  defp encode_summaries(summaries) do
    result =
      Enum.reduce_while(summaries, {:ok, []}, fn
        summary, {:ok, acc} ->
          case AlarmSummary.encode(summary) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _term} = term -> {:halt, term}
          end
      end)

    case result do
      {:ok, list} ->
        params =
          list
          |> Enum.reverse()
          |> List.flatten()

        {:ok, params}

      term ->
        term
    end
  end
end
