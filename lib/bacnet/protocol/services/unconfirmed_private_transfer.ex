defmodule BACnet.Protocol.Services.UnconfirmedPrivateTransfer do
  @moduledoc """
  This module represents the BACnet Unconfirmed Private Transfer service.

  The Unconfirmed Private Transfer service is used to invoke proprietary or non-standard services in a BACnet device.

  Service Description (ASHRAE 135):
  > The UnconfirmedPrivateTransfer is used by a client BACnet-user to invoke proprietary or non-standard services in a
  > remote device. The specific proprietary services that may be provided by a given device are not defined by this standard.
  > The PrivateTransfer services provide a mechanism for specifying a particular proprietary service in a standardized manner.
  > The only required parameters for these services are a vendor identification code and a service number. Additional
  > parameters may be supplied for each service if required. The form and content of these additional parameters, if any, are not
  > defined by this standard. The vendor identification code and service number together serve to unambiguously identify the
  > intended purpose of the information conveyed by the remainder of the APDU or the service to be performed by the remote
  > device based on parameters in the remainder of the APDU.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          vendor_id: Protocol.ApplicationTags.unsigned16(),
          service_number: non_neg_integer(),
          parameters: [Protocol.ApplicationTags.Encoding.t()] | nil
        }

  @fields [
    :vendor_id,
    :service_number,
    :parameters
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :unconfirmed_service_choice,
                  :unconfirmed_private_transfer
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
  Converts the given Unconfirmed Service Request into an Unconfirmed Private Transfer Service.
  """
  @spec from_apdu(Protocol.APDU.UnconfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.UnconfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case Protocol.Services.Common.decode_private_transfer(request) do
      {:ok, event} -> {:ok, struct(__MODULE__, event)}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given Unconfirmed Private Transfer Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, req} <- Protocol.Services.Common.encode_private_transfer(service) do
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
