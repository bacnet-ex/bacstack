defmodule BACnet.Protocol.Services.IHave do
  @moduledoc """
  This module represents the BACnet I-Have service.

  The I-Have service is used as a response to the Who-Has service.

  Service Description (ASHRAE 135):
  > The IHave service is used to respond to Who-Has service requests or to advertise the existence of an object with a given
  > Object_Name or Object_Identifier. The I-Have service request may be issued at any time and does not need to be preceded
  > by the receipt of a Who-Has service request.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          device: Protocol.ObjectIdentifier.t(),
          object: Protocol.ObjectIdentifier.t(),
          object_name: String.t()
        }

  @fields [
    :device,
    :object,
    :object_name
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(:unconfirmed_service_choice, :i_have)

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
  Converts the given Unconfirmed Service Request into an I-Have Service.

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
        {:object_identifier, %Protocol.ObjectIdentifier{} = device_identifier},
        {:object_identifier, %Protocol.ObjectIdentifier{} = object_identifier},
        {:character_string, name} | _tail
      ] ->
        ihave = %__MODULE__{
          device: device_identifier,
          object: object_identifier,
          object_name: name
        }

        {:ok, ihave}

      _term ->
        {:error, :invalid_request_parameters}
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given I-Have Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(
        %__MODULE__{
          device: %Protocol.ObjectIdentifier{} = device,
          object: %Protocol.ObjectIdentifier{} = object,
          object_name: object_name
        } = _service,
        _request_data
      )
      when is_binary(object_name) do
    unless String.valid?(object_name) and String.printable?(object_name) do
      raise ArgumentError,
            "Invalid UTF-8 string for object name (must be valid UTF-8 and printable)"
    end

    req = %Protocol.APDU.UnconfirmedServiceRequest{
      service: @service_name,
      parameters: [
        object_identifier: device,
        object_identifier: object,
        character_string: object_name
      ]
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
