defmodule BACnet.Protocol.Services.UnconfirmedCovNotification do
  @moduledoc """
  This module represents the BACnet Unconfirmed COV Notification service (Change Of Value).

  The Unconfirmed COV Notification service is used to notify a subscriber of a changed value or changed values.

  Service Description (ASHRAE 135):
  > The UnconfirmedCOVNotification Service is used to notify subscribers about changes that may have occurred to the
  > properties of a particular object, or to distribute object properties of wide interest (such as outside air conditions) to many
  > devices simultaneously without a subscription. Subscriptions for COV notifications are made using the SubscribeCOV
  > service. For unsubscribed notifications, the algorithm for determining when to issue this service is a local matter and may be
  > based on a change of value, periodic updating, or some other criteria.
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
                  :unconfirmed_service_choice,
                  :unconfirmed_cov_notification
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
  Converts the given Unconfirmed Service Request into an Unconfirmed COV Notification Service.
  """
  @spec from_apdu(Protocol.APDU.UnconfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.UnconfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case Protocol.Services.Common.decode_cov_notification(request) do
      {:ok, cov} -> {:ok, struct(__MODULE__, cov)}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given Unconfirmed COV Notification Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, req} <- Protocol.Services.Common.encode_cov_notification(service) do
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
