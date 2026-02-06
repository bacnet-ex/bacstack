defmodule BACnet.Protocol.Services.WhoIs do
  @moduledoc """
  This module represents the BACnet Who-Is service.

  The Who-Is service is used to discover the BACnet network and devices in it.

  Service Description (ASHRAE 135):
  > The Who-Is service is used by a sending BACnet-user to determine the device object identifier, the network address, or both,
  > of other BACnet devices that share the same internetwork. The Who-Is service is an unconfirmed service.
  > The Who-Is service may be used to determine the device object identifier and network addresses of all devices on the network,
  > or to determine the network address of a specific device whose device object identifier is known, but whose address is not.
  > The IAm service is also an unconfirmed service. The I-Am service is used to respond to Who-Is service requests.
  > However, the IAm service request may be issued at any time. It does not need to be preceded by the receipt
  > of a Who-Is service request. In particular, a device may wish to broadcast an I-Am service request when it powers up.
  > The network address is derived either from the MAC address associated with the I-Am service request, if the device issuing
  > the request is on the local network, or from the NPCI if the device is on a remote network.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          device_id_low_limit: non_neg_integer() | nil,
          device_id_high_limit: non_neg_integer() | nil
        }

  @fields [
    :device_id_low_limit,
    :device_id_high_limit
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(:unconfirmed_service_choice, :who_is)

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
  Converts the given Unconfirmed Service Request into a Who-Is Service.
  """
  @spec from_apdu(Protocol.APDU.UnconfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.UnconfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {id_low, id_high} <-
           (case request.parameters do
              [
                {:tagged, {0, low_limit, low_length}},
                {:tagged, {1, high_limit, high_length}} | _tail
              ] ->
                <<id_low::size(^low_length)-unit(8)>> = low_limit
                <<id_high::size(^high_length)-unit(8)>> = high_limit
                {id_low, id_high}

              _term ->
                {nil, nil}
            end) do
      whois = %__MODULE__{
        device_id_low_limit: id_low,
        device_id_high_limit: id_high
      }

      {:ok, whois}
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given Who-Is Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    params =
      if service.device_id_low_limit && service.device_id_high_limit do
        if service.device_id_low_limit > service.device_id_high_limit do
          raise ArgumentError, "Low limit must be less than or equal to high limit"
        end

        unless service.device_id_low_limit >= 0 and service.device_id_low_limit <= 4_194_303 do
          raise ArgumentError,
                "Low limit must be between 0 and 4194303 inclusive, got: " <>
                  inspect(service.device_id_low_limit)
        end

        unless service.device_id_high_limit >= 0 and service.device_id_high_limit <= 4_194_303 do
          raise ArgumentError,
                "High limit must be between 0 and 4194303 inclusive, got: " <>
                  inspect(service.device_id_high_limit)
        end

        {:ok, id_low, _header} =
          ApplicationTags.encode_value(
            {:unsigned_integer, service.device_id_low_limit},
            request_data
          )

        low_size = byte_size(id_low)

        {:ok, id_high, _header} =
          ApplicationTags.encode_value(
            {:unsigned_integer, service.device_id_high_limit},
            request_data
          )

        high_size = byte_size(id_high)

        [{:tagged, {0, id_low, low_size}}, {:tagged, {1, id_high, high_size}}]
      else
        if service.device_id_low_limit || service.device_id_high_limit do
          raise ArgumentError,
                "Both of device_id_low_limit and device_id_high_limit must be set or unset"
        end

        []
      end

    req = %Protocol.APDU.UnconfirmedServiceRequest{
      service: @service_name,
      parameters: params
    }

    {:ok, req}
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
