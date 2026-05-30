defmodule BACnet.Protocol.Services.GetEventInformation do
  @moduledoc """
  This module represents the BACnet Get Event Information service.

  The Get Event Information service is used to get a list of active event states from a device.
  Active event states refers to all abnormal events of event-initiating objects.

  #### Service Description (ASHRAE 135)

  > The GetEventInformation service is used by a client BACnet-user to obtain a summary of all "active event states". The term
  > "active event states" refers to all event-initiating objects that
  >   (a) have an Event_State property whose value is not equal to NORMAL, or
  >   (b) have an Acked_Transitions property, which has at least one of the bits (TO_OFFNORMAL, TO_FAULT, TO_NORMAL) set to FALSE.
  > This service is intended to be implemented in all devices that generate event notifications.

  #### Service Procedure (ASHRAE 135)

  > After verifying the validity of the request, the responding BACnet-user shall search for all event-initiating objects that do not
  > have an Event_Detection_Enable property with a value of FALSE and that meet the following conditions, beginning with the
  > object following (in whatever internal ordering of objects is used by the responding device) the object specified by the 'Last
  > Received Object Identifier' parameter, if present:
  > (a) have an Event_State property whose value is not equal to NORMAL, or
  > (b) have an Acked_Transitions property that has at least one of the following bits (TO_OFFNORMAL, TO_FAULT,
  > TO_NORMAL) set to FALSE.
  > A positive response containing the event summaries for objects found in this search shall be constructed. If no objects are
  > found that meet these criteria, then a list of length zero shall be returned. As many of the included objects as can be returned
  > within the APDU shall be returned. If more objects exist that meet the criteria but cannot be returned in the APDU, the 'More
  > Events' parameter shall be set to TRUE, otherwise it shall be set to FALSE.

  #### Result(+) Response (ASHRAE 135)

  On success, the responding BACnet-user returns a 'Result(+)' primitive containing:

  - A list of event summaries for all qualifying objects.
  - 'More Events' - A Boolean indicating whether additional events exist that could not fit in this response (used for pagination).

  Each summary includes the object identifier, event state, acknowledged transitions, event timestamps, etc.

  #### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that the service request has failed. The reason for failure shall be specified by the
  'Error Type' parameter.

  The 'Error Class' and 'Error Code' are per Clause 18, with the following specific case noted in the specification:

  If the 'Last Received Object Identifier' parameter (when provided) has become invalid in the responding device, the service
  shall return an error with Error Class = OBJECT and Error Code = UNKNOWN_OBJECT.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  @typedoc """
  Parameters for the Get Event Information service (last received object for pagination).
  """
  @type t :: %__MODULE__{
          last_received_object_identifier: Protocol.ObjectIdentifier.t() | nil
        }

  @fields [
    :last_received_object_identifier
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :get_event_information
                )

  @doc """
  Get the service name atom.
  """
  @spec get_name() :: atom()
  def get_name(), do: @service_name

  @doc """
  Whether the service is of type confirmed or unconfirmed.
  """
  @spec confirmed?() :: true
  def confirmed?(), do: true

  @doc """
  Converts the given Confirmed Service Request into a Get Event Information Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    # credo:disable-for-next-line Credo.Check.Readability.WithSingleClause
    with {:ok, last_received_object_identifier, _rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :object_identifier,
             true
           ) do
      event = %__MODULE__{
        last_received_object_identifier: last_received_object_identifier
      }

      {:ok, event}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Get Event Information Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, parameters} <-
           (case service.last_received_object_identifier do
              nil ->
                {:ok, []}

              _term ->
                with {:ok, bytes, _header} <-
                       ApplicationTags.encode_value(
                         {:object_identifier, service.last_received_object_identifier}
                       ) do
                  {:ok, [{:tagged, {0, bytes, byte_size(bytes)}}]}
                end
            end) do
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
        parameters: parameters
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

    @spec confirmed?(@for.t()) :: boolean()
    def confirmed?(%@for{} = _service), do: @for.confirmed?()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
