defmodule BACnet.Protocol.Services.UnconfirmedEventNotification do
  @moduledoc """
  This module represents the BACnet Unconfirmed Event Notification service.

  The Unconfirmed Event Notification service is used to notify a subscriber of an event that has occurred.

  Service Description (ASHRAE 135):
  > The UnconfirmedEventNotification service is used by a notification-server to notify a remote device that an event has
  > occurred. Its purpose is to notify recipients that an event has occurred, but confirmation that the notification was received is
  > not required. Applications that require confirmation that the notification was received by the remote device should use the
  > ConfirmedEventNotification service. The fact that this is an unconfirmed service does not mean it is inappropriate for
  > notification of alarms. Events of type Alarm may require a human acknowledgment that is conveyed using the
  > AcknowledgeAlarm service. Thus, using an unconfirmed service to announce the alarm has no effect on the ability to
  > confirm that an operator has been notified. Any device that executes this service shall support programmable process
  > identifiers to allow broadcast and multicast 'Process Identifier' parameters to be assigned on a per installation basis.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs
  # ack-required, from_state, to_state: not present if notify_type == :ack_notification

  @type t :: %__MODULE__{
          process_identifier: Protocol.ApplicationTags.unsigned32(),
          initiating_device: Protocol.ObjectIdentifier.t(),
          event_object: Protocol.ObjectIdentifier.t(),
          timestamp: Protocol.BACnetTimestamp.t(),
          notification_class: non_neg_integer(),
          priority: Protocol.ApplicationTags.unsigned8(),
          event_type: Constants.event_type(),
          message_text: String.t() | nil,
          notify_type: :alarm | :event | :ack_notification,
          ack_required: boolean() | nil,
          from_state: Constants.event_state() | nil,
          to_state: Constants.event_state() | nil,
          event_values: Protocol.NotificationParameters.notification_parameter() | nil
        }

  @fields [
    :process_identifier,
    :initiating_device,
    :event_object,
    :timestamp,
    :notification_class,
    :priority,
    :event_type,
    :message_text,
    :notify_type,
    :ack_required,
    :from_state,
    :to_state,
    :event_values
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :unconfirmed_service_choice,
                  :unconfirmed_event_notification
                )

  @doc """
  Get the service name atom.
  """
  @spec get_name() :: atom()
  def get_name(), do: @service_name

  @doc """
  Whether the service is of type confirmed or unconfirmed.
  """
  @spec is_confirmed() :: false
  def is_confirmed(), do: false

  @doc """
  Converts the given Unconfirmed Service Request into an Unconfirmed Event Notification Service.
  """
  @spec from_apdu(Protocol.APDU.UnconfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.UnconfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case Protocol.Services.Common.decode_event_notification(request) do
      {:ok, event} -> {:ok, struct(__MODULE__, event)}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given Unconfirmed Event Notification Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, req} <- Protocol.Services.Common.encode_event_notification(service) do
      Protocol.Services.Common.after_encode_convert(
        req,
        request_data,
        Protocol.APDU.UnconfirmedServiceRequest,
        @service_name
      )
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
