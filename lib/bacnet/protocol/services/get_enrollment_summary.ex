defmodule BACnet.Protocol.Services.GetEnrollmentSummary do
  @moduledoc """
  This module represents the BACnet Get Enrollment Summary service.

  The Get Enrollment Summary service is used to get a list of event-initiating objects.
  Several different filters may be applied.

  Service Description (ASHRAE 135):
  > The GetEnrollmentSummary service is used by a client BACnet-user to obtain a summary of event-initiating objects. Several
  > different filters may be applied to define the search criteria. This service may be used to obtain summaries of objects with any
  > event type and is thus a superset of the functionality provided by the GetAlarmSummary Service.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.Recipient

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs
  # All fields except acknowledgment_filter are optional

  @type t :: %__MODULE__{
          acknowledgment_filter: :all | :acked | :not_acked,
          enrollment_filter:
            {process_identifier :: ApplicationTags.unsigned32(), Recipient.t()} | nil,
          event_state_filter: Constants.event_state() | nil,
          event_type_filter: Constants.event_type() | nil,
          priority_filter:
            {min :: ApplicationTags.unsigned8(), max :: ApplicationTags.unsigned8()} | nil,
          notification_class_filter: non_neg_integer() | nil
        }

  @fields [
    :acknowledgment_filter,
    :enrollment_filter,
    :event_state_filter,
    :event_type_filter,
    :priority_filter,
    :notification_class_filter
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :get_enrollment_summary
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
  Converts the given Confirmed Service Request into a Get Enrollment Summary Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {:ok, ack_filter_raw, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :enumerated,
             false
           ),
         ack_filter <-
           (case ack_filter_raw do
              0 -> :all
              1 -> :acked
              2 -> :not_acked
            end),
         {:ok, recipient_process_raw, rest} <-
           pattern_extract_tags(rest, {:constructed, {1, _t, _l}}, nil, true),
         {:ok, recipient_process} <-
           (case recipient_process_raw do
              nil ->
                {:ok, nil}

              {:constructed,
               {1,
                [
                  {:constructed, {0, recipient_raw, 0}},
                  {:tagged, {1, process, _t2}}
                  | _tl
                ], 0}} ->
                with {:ok, {recipient, _rest}} <- Recipient.parse([recipient_raw]),
                     {:ok, {:unsigned_integer, pid}} <-
                       ApplicationTags.unfold_to_type(:unsigned_integer, process),
                     :ok <-
                       if(ApplicationTags.valid_int?(pid, 32),
                         do: :ok,
                         else: {:error, :invalid_process_identifier_value}
                       ),
                     do: {:ok, {pid, recipient}}

              _else ->
                {:error, :invalid_recipient_process_param}
            end),
         {:ok, event_state, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :enumerated, true),
         {:ok, event_state_c} <-
           (if event_state do
              Constants.by_value_with_reason(
                :event_state,
                event_state,
                {:unknown_event_state, event_state}
              )
            else
              {:ok, nil}
            end),
         {:ok, event_type, rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _t, _l}}, :unsigned_integer, true),
         {:ok, event_type_c} <-
           (if event_type do
              Constants.by_value_with_reason(
                :event_type,
                event_type,
                {:unknown_event_type, event_type}
              )
            else
              {:ok, nil}
            end),
         {:ok, priority_raw, rest} <-
           pattern_extract_tags(rest, {:constructed, {4, _t, _l}}, nil, true),
         {:ok, priority} <-
           (case priority_raw do
              nil ->
                {:ok, nil}

              {:constructed,
               {4,
                [
                  {:tagged, {0, min, _t}},
                  {:tagged, {1, max, _t2}}
                  | _tl
                ], 0}} ->
                with {:ok, {:unsigned_integer, min_prio}} <-
                       ApplicationTags.unfold_to_type(:unsigned_integer, min),
                     {:ok, {:unsigned_integer, max_prio}} <-
                       ApplicationTags.unfold_to_type(:unsigned_integer, max),
                     do: {:ok, {min_prio, max_prio}}

              _else ->
                {:error, :invalid_priority_param}
            end),
         {:ok, notification_class, _rest} <-
           pattern_extract_tags(rest, {:tagged, {5, _t, _l}}, :unsigned_integer, true) do
      enroll = %__MODULE__{
        acknowledgment_filter: ack_filter,
        enrollment_filter: recipient_process,
        event_state_filter: event_state_c,
        event_type_filter: event_type_c,
        priority_filter: priority,
        notification_class_filter: notification_class
      }

      {:ok, enroll}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Get Enrollment Summary Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with ack_filter_num =
           (case service.acknowledgment_filter do
              :all -> 0
              :acked -> 1
              :not_acked -> 2
            end),
         {:ok, ack_filter, _header} <-
           ApplicationTags.encode_value({:enumerated, ack_filter_num}),
         {:ok, recipient_process} <- encode_recipient_process(service),
         {:ok, event_state} <-
           (case service.event_state_filter do
              nil ->
                {:ok, nil}

              _term ->
                with {:ok, event_state_c} <-
                       Constants.by_name_with_reason(
                         :event_state,
                         service.event_state_filter,
                         {:unknown_event_state, service.event_state_filter}
                       ),
                     {:ok, bytes, _header} <-
                       ApplicationTags.encode_value({:enumerated, event_state_c}) do
                  {:ok, {:tagged, {2, bytes, byte_size(bytes)}}}
                end
            end),
         {:ok, event_type} <-
           (case service.event_type_filter do
              nil ->
                {:ok, nil}

              _term ->
                with {:ok, event_type_c} <-
                       Constants.by_name_with_reason(
                         :event_type,
                         service.event_type_filter,
                         {:unknown_event_type, service.event_type_filter}
                       ),
                     {:ok, bytes, _header} <-
                       ApplicationTags.encode_value({:enumerated, event_type_c}) do
                  {:ok, {:tagged, {3, bytes, byte_size(bytes)}}}
                end
            end),
         {:ok, priority} <-
           (case service.priority_filter do
              nil ->
                {:ok, nil}

              {minp, maxp} ->
                with {:ok, min, _header} <-
                       ApplicationTags.encode_value({:unsigned_integer, minp}),
                     {:ok, max, _header} <-
                       ApplicationTags.encode_value({:unsigned_integer, maxp}) do
                  {:ok,
                   {:constructed,
                    {4,
                     [
                       {:tagged, {0, min, byte_size(min)}},
                       {:tagged, {1, max, byte_size(max)}}
                     ], 0}}}
                end
            end),
         {:ok, notification_class} <-
           (case service.notification_class_filter do
              nil ->
                {:ok, nil}

              _term ->
                with {:ok, bytes, _header} <-
                       ApplicationTags.encode_value(
                         {:unsigned_integer, service.notification_class_filter}
                       ) do
                  {:ok, {:tagged, {5, bytes, byte_size(bytes)}}}
                end
            end) do
      parameters = [
        {:tagged, {0, ack_filter, byte_size(ack_filter)}},
        recipient_process,
        event_state,
        event_type,
        priority,
        notification_class
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
        parameters: Enum.reject(parameters, &is_nil/1)
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
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end

  defp encode_recipient_process(%__MODULE__{enrollment_filter: nil} = _service) do
    {:ok, nil}
  end

  defp encode_recipient_process(
         %__MODULE__{enrollment_filter: {pid, %Protocol.Recipient{} = recipient}} = _service
       )
       when is_integer(pid) and pid >= 0 do
    with :ok <-
           if(ApplicationTags.valid_int?(pid, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         {:ok, [recip]} <- BACnet.Protocol.Recipient.encode(recipient),
         {:ok, process, _header} <- ApplicationTags.encode_value({:unsigned_integer, pid}) do
      {:ok,
       {:constructed,
        {1,
         [
           {:constructed, {0, recip, 0}},
           {:tagged, {1, process, byte_size(process)}}
         ], 0}}}
    end
  end

  defp encode_recipient_process(_else) do
    {:error, :invalid_enrollment_filter}
  end
end
