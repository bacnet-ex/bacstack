defmodule BACnet.Protocol.Services.ConfirmedEventNotification do
  @moduledoc """
  This module represents the BACnet Confirmed Event Notification service.

  The Confirmed Event Notification service is used to notify a subscriber of an event that has occurred and requires an
  acknowledge by the subscriber of reception of this event notification.

  Service Description (ASHRAE 135):
  > The ConfirmedEventNotification service is used by a notification-server to notify a remote device that an event has occurred
  > and that the notification-server needs a confirmation that the notification has been received. This confirmation means only
  > that the device received the message. It does not imply that a human operator has been notified. A separate
  > AcknowledgeAlarm service is used to indicate that an operator has acknowledged the receipt of the notification if the
  > notification specifies that acknowledgment is required. If multiple recipients must be notified, a separate invocation of this
  > service shall be used to notify each intended recipient. If a confirmation that a notification was received is not needed, then
  > the UnconfirmedEventNotification may be used.
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
          notify_type: Constants.notify_type(),
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
                  :confirmed_service_choice,
                  :confirmed_event_notification
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
  Converts the given Confirmed Service Request into a Confirmed Event Notification Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case Protocol.Services.Common.decode_event_notification(request) do
      {:ok, event} -> {:ok, struct(__MODULE__, event)}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Confirmed Event Notification Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, req} <- Protocol.Services.Common.encode_event_notification(service) do
      Protocol.Services.Common.after_encode_convert(
        req,
        request_data,
        Protocol.APDU.ConfirmedServiceRequest,
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
