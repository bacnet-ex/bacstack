defmodule BACnet.Protocol.Services.DeleteObject do
  @moduledoc """
  This module represents the BACnet Delete Object service.

  The Delete Object service is used to delete an existing object in the remote device.

  Service Description (ASHRAE 135):
  > The DeleteObject service is used by a client BACnet-user to delete an existing object. Although this service is general in the
  > sense that it can be applied to any object type, it is expected that most objects in a control system cannot be deleted by this
  > service because they are protected as a security feature. There are some objects, however, that may be created and deleted
  > dynamically. Group objects and Event Enrollment objects are examples. This service is primarily used to delete objects of
  > these types but may also be used to remove vendor-specific deletable objects.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants

  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          object_specifier: Protocol.ObjectIdentifier.t()
        }

  @fields [
    :object_specifier
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :delete_object
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
  Converts the given Confirmed Service Request into a Delete Object Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case request.parameters do
      [
        {:object_identifier, specifier}
        | _tail
      ] ->
        obj = %__MODULE__{
          object_specifier: specifier
        }

        {:ok, obj}

      _else ->
        {:error, :invalid_request_parameters}
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Delete Object Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(
        %__MODULE__{object_specifier: %Protocol.ObjectIdentifier{} = obspec} = _service,
        request_data
      ) do
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
      parameters: [object_identifier: obspec]
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
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
