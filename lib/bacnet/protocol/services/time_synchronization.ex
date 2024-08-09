defmodule BACnet.Protocol.Services.TimeSynchronization do
  @moduledoc """
  This module represents the BACnet Time Synchronization service.

  The Time Synchronization service is used to send the correct local date and time onto the BACnet network or to a single recipient.

  Service Description (ASHRAE 135):
  > The TimeSynchronization service is used by a requesting BACnet-user to notify a remote device of the correct current time.
  > This service may be broadcast, multicast, or addressed to a single recipient. Its purpose is to notify recipients of the correct
  > current time so that devices may synchronize their internal clocks with one another.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          date: Protocol.BACnetDate.t(),
          time: Protocol.BACnetTime.t()
        }

  @fields [
    :date,
    :time
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(:unconfirmed_service_choice, :time_synchronization)

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
  Converts the given Unconfirmed Service Request into an TimeSynchronization Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec from_apdu(Protocol.APDU.UnconfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.UnconfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case request.parameters do
      [
        {:date, %Protocol.BACnetDate{} = date},
        {:time, %Protocol.BACnetTime{} = time}
        | _tail
      ] ->
        sync = %__MODULE__{
          date: date,
          time: time
        }

        {:ok, sync}

      _term ->
        {:error, :invalid_request_parameters}
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given TimeSynchronization Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(
        %__MODULE__{date: %Protocol.BACnetDate{} = date, time: %Protocol.BACnetTime{} = time} =
          _service,
        _request_data
      ) do
    req = %Protocol.APDU.UnconfirmedServiceRequest{
      service: @service_name,
      parameters: [{:date, date}, {:time, time}]
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
