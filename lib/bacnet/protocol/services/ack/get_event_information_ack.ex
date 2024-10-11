defmodule BACnet.Protocol.Services.Ack.GetEventInformationAck do
  # TODO: Docs

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventInformation

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

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

  @spec to_apdu(t(), 0..255) :: {:ok, ComplexACK.t()} | {:error, term()}
  def to_apdu(ack, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = ack, invoke_id) when invoke_id in 0..255 do
    with {:ok, events} <- encode_events(ack.events) do
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
    else
      {:error, :missing_pattern} -> {:error, :invalid_service_ack}
      {:error, _err} = err -> err
    end
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end

  defp parse_events(payload) do
    Enum.reduce_while(1..100_000//1, {payload, []}, fn
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
