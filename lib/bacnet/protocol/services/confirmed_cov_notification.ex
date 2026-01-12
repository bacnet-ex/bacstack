defmodule BACnet.Protocol.Services.ConfirmedCovNotification do
  @moduledoc """
  This module represents the BACnet Confirmed COV Notification service.

  The Confirmed COV Notification service is used to notify a subscriber of a changed value or changed values and requires an
  acknowledge by the subscriber of reception of this event notification.

  Service Description (ASHRAE 135):
  > The ConfirmedCOVNotification service is used to notify subscribers about changes that may have occurred to the properties
  > of a particular object. Subscriptions for COV notifications are made using the SubscribeCOV service or the
  > SubscribeCOVProperty service.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          process_identifier: Protocol.ApplicationTags.unsigned32(),
          initiating_device: Protocol.ObjectIdentifier.t(),
          monitored_object: Protocol.ObjectIdentifier.t(),
          time_remaining: non_neg_integer(),
          property_values: [Protocol.PropertyValue.t()]
        }

  @fields [
    :process_identifier,
    :initiating_device,
    :monitored_object,
    :time_remaining,
    :property_values
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :confirmed_cov_notification
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
  Converts the given Confirmed Service Request into a Confirmed COV Notification Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case Protocol.Services.Common.decode_cov_notification(request) do
      {:ok, event} -> {:ok, struct(__MODULE__, event)}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Confirmed COV Notification Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, req} <- Protocol.Services.Common.encode_cov_notification(service) do
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
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
