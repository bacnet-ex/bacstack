defmodule BACnet.Protocol.Services.AcknowledgeAlarm do
  @moduledoc """
  This module represents the BACnet Acknowledge Alarm service.

  The Acknowledge Alarm service is used to acknowledge a human operator has seen the alarm notification.

  Service Description (ASHRAE 135):
  > In some systems a device may need to know that an operator has seen the alarm notification. The AcknowledgeAlarm service
  > is used by a notification-client to acknowledge that a human operator has seen and responded to an event notification with
  > 'AckRequired' = TRUE. Ensuring that the acknowledgment actually comes from a person with appropriate authority is a local
  > matter. This service may be used in conjunction with either the ConfirmedEventNotification service or the
  > UnconfirmedEventNotification service.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          process_identifier: ApplicationTags.unsigned32(),
          event_object: Protocol.ObjectIdentifier.t(),
          event_state_acknowledged: Constants.event_state(),
          event_timestamp: Protocol.BACnetTimestamp.t(),
          acknowledge_source: String.t(),
          time_of_ack: Protocol.BACnetTimestamp.t()
        }

  @fields [
    :process_identifier,
    :event_object,
    :event_state_acknowledged,
    :event_timestamp,
    :acknowledge_source,
    :time_of_ack
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :acknowledge_alarm
                )

  @doc """
  Get the service name atom.
  """
  @spec get_name() :: atom()
  def get_name(), do: @service_name

  @doc """
  Whether the service is of type confirmed or unconfirmed.
  """
  @spec is_confirmed() :: true
  def is_confirmed(), do: true

  @doc """
  Converts the given Confirmed Service Request into an Acknowledge Alarm Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {:ok, process_identifier, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :unsigned_integer,
             false
           ),
         :ok <-
           if(ApplicationTags.valid_int?(process_identifier, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         {:ok, object_identifier, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :object_identifier, false),
         {:ok, event_state, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :enumerated, false),
         {:ok, event_state_c} <-
           Constants.by_value_with_reason(
             :event_state,
             event_state,
             {:unknown_event_state, event_state}
           ),
         {:ok, {:constructed, {_tag, timestamp_raw, _len}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {3, _t, _l}}, nil, false),
         {:ok, {timestamp, _rest}} <- Protocol.BACnetTimestamp.parse(List.wrap(timestamp_raw)),
         {:ok, source, rest} <-
           (case pattern_extract_tags(rest, {:tagged, {4, _t, _l}}, :character_string, false) do
              {:ok, _source, _rest} = source ->
                source

              err ->
                # ASHRAE 135 - 13.5.2
                # A device shall not fail to process, or issue a Result(-), upon receiving an AcknowledgeAlarm
                # service request containing an 'Acknowledgment Source' parameter in an unsupported character set.
                # In this case, it is a local matter whether the 'Acknowledgment Source' parameter is used as
                # provided or whether a character string, in a supported character set, of length
                # 0 is used in its place.
                case rest do
                  [{:tagged, {4, _t, _l}} | tl] -> {:ok, "", tl}
                  _term -> err
                end
            end),
         {:ok, {:constructed, {_tag, acktime_raw, _len}}, _rest} <-
           pattern_extract_tags(rest, {:constructed, {5, _t, _l}}, nil, false),
         {:ok, {acktime, _rest}} <- Protocol.BACnetTimestamp.parse(List.wrap(acktime_raw)) do
      ack = %__MODULE__{
        process_identifier: process_identifier,
        event_object: object_identifier,
        event_state_acknowledged: event_state_c,
        event_timestamp: timestamp,
        acknowledge_source: source,
        time_of_ack: acktime
      }

      {:ok, ack}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Acknowledge Alarm Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with :ok <-
           if(ApplicationTags.valid_int?(service.process_identifier, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         {:ok, process_identifier, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.process_identifier}),
         {:ok, object_identifier, _header} <-
           ApplicationTags.encode_value({:object_identifier, service.event_object}),
         {:ok, state_ackd_c} <-
           Constants.by_name_with_reason(
             :event_state,
             service.event_state_acknowledged,
             {:unknown_event_state, service.event_state_acknowledged}
           ),
         {:ok, state_ackd, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, state_ackd_c}),
         {:ok, [timestamp]} <- Protocol.BACnetTimestamp.encode(service.event_timestamp),
         {:ok, charstr, _header} <-
           ApplicationTags.encode_value({:character_string, service.acknowledge_source}),
         {:ok, [acktime]} <- Protocol.BACnetTimestamp.encode(service.time_of_ack) do
      params = [
        {:tagged, {0, process_identifier, byte_size(process_identifier)}},
        {:tagged, {1, object_identifier, byte_size(object_identifier)}},
        {:tagged, {2, state_ackd, byte_size(state_ackd)}},
        {:constructed, {3, timestamp, 0}},
        {:tagged, {4, charstr, byte_size(charstr)}},
        {:constructed, {5, acktime, 0}}
      ]

      req = %Protocol.APDU.ConfirmedServiceRequest{
        segmented_response_accepted: request_data[:segmented_response_accepted] || true,
        max_segments: request_data[:max_segments] || :more_than_64,
        max_apdu:
          request_data[:max_apdu] ||
            Constants.macro_by_name(:max_apdu_length_accepted_value, :octets_1476),
        invoke_id: request_data[:invoke_id] || 0,
        sequence_number: nil,
        proposed_window_size: nil,
        service: @service_name,
        parameters: params
      }

      {:ok, req}
    end
  end

  defimpl Protocol.Services.Protocol do
    alias BACnet.Protocol
    alias BACnet.Protocol.Constants
    require Constants

    @spec get_name(@for.t()) :: atom()
    def get_name(%@for{} = _service), do: @for.get_name()

    @spec is_confirmed(@for.t()) :: boolean()
    def is_confirmed(%@for{} = _service), do: @for.is_confirmed()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
