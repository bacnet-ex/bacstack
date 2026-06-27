defmodule BACnet.Protocol.Services.Ack.GetEventInformationAck do
  @moduledoc """
  The Get Event Information Acknowledgment is the response to a Get Event
  Information service request. It provides a detailed snapshot of every object
  in the device that is configured for event reporting.

  Each entry includes the object identifier, current event state, acknowledged
  transitions, timestamps of recent state changes, notification class, and
  priority information. This is the richest and most commonly used service for
  modern alarm management workstations to maintain an accurate, up-to-date
  view of all active and recently cleared events.

  The acknowledgment also contains a `more_events` flag that indicates whether
  the device has additional event-generating objects beyond what was returned
  in this response (useful for paging through very large systems).
  """

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventInformation

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @typedoc """
  Response for Get Event Information. Returns a page of event information records plus a flag
  indicating if more events remain on the device (for pagination of large systems).
  """
  @type t :: %__MODULE__{
          events: [EventInformation.t()],
          more_events: boolean()
        }

  @fields [:events, :more_events]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :get_event_information
                )

  @doc """
  Converts a received `BACnet.Protocol.APDU.ComplexACK` APDU into a struct.
  """
  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(%ComplexACK{service: @service_name} = ack) do
    with {:ok, {:constructed, {0, events_raw, _len}}, rest} <-
           pattern_extract_tags(ack.payload, {:constructed, {0, _c, _l}}, nil, false),
         {:ok, event} <- parse_events(events_raw),
         {:ok, more_events, _rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _c, _l}}, :boolean, false) do
      struc = %__MODULE__{
        events: event,
        more_events: more_events
      }

      {:ok, struc}
    else
      {:error, :invalid_tags} -> {:error, :invalid_service_ack}
      {:error, :missing_pattern} -> {:error, :invalid_service_ack}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(_ack) do
    {:error, :invalid_service_ack}
  end

  @doc """
  Constructs a `BACnet.Protocol.APDU.ComplexACK` APDU from a
  `BACnet.Protocol.Services.Ack.GetEventInformationAck` struct.

  The `more_events` flag in the struct controls the "more events" bit in the
  response.
  """
  @spec to_apdu(t(), 0..255) :: {:ok, ComplexACK.t()} | {:error, term()}
  def to_apdu(ack, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = ack, invoke_id) when invoke_id in 0..255 do
    case encode_events(ack.events) do
      {:ok, events} ->
        new_ack = %ComplexACK{
          invoke_id: invoke_id,
          sequence_number: nil,
          proposed_window_size: nil,
          service: @service_name,
          payload: [
            {:constructed, {0, events, 0}},
            {:tagged, {1, <<intify(ack.more_events)>>, 1}}
          ]
        }

        {:ok, new_ack}

      {:error, :missing_pattern} ->
        {:error, :invalid_service_ack}

      {:error, _err} = err ->
        err
    end
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end

  defp parse_events(payload) do
    Enum.reduce_while(1..100_000//1, {payload, []}, fn
      _iter, {[], acc} ->
        {:halt, {:ok, Enum.reverse(acc)}}

      _iter, {tags, acc} ->
        case EventInformation.parse(tags) do
          {:ok, {item, []}} -> {:halt, {:ok, Enum.reverse([item | acc])}}
          {:ok, {item, rest}} -> {:cont, {rest, [item | acc]}}
          {:error, _term} = term -> {:halt, term}
        end
    end)
  end

  defp encode_events(events) do
    result =
      Enum.reduce_while(events, {:ok, []}, fn
        event, {:ok, acc} ->
          case EventInformation.encode(event) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _err} = err -> {:halt, err}
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

  defp intify(false), do: 0
  defp intify(true), do: 1
end
