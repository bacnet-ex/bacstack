defmodule BACnet.Protocol.Services.ReadPropertyMultiple do
  @moduledoc """
  This module represents the BACnet Read Property Multiple service.

  The Read Property Multiple service is used to read multiple properties of one or multiple objects.

  Service Description (ASHRAE 135):
  > The ReadPropertyMultiple service is used by a client BACnet-user to request the values of one or more specified properties
  > of one or more BACnet Objects. This service allows read access to any property of any object, whether a BACnet-defined
  > object or not. The user may read a single property of a single object, a list of properties of a single object, or any number of
  > properties of any number of objects. A 'Read Access Specification' with the property identifier ALL can be used to learn the
  > implemented properties of an object along with their values.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants

  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          list: [Protocol.AccessSpecification.t()]
        }

  @fields [:list]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :read_property_multiple
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
  Converts the given Confirmed Service Request into a Read Property Multiple Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    result =
      Enum.reduce_while(1..100_000//1, {request.parameters, []}, fn
        _iter, {tags, acc} ->
          case Protocol.AccessSpecification.parse(tags) do
            {:ok, {item, []}} -> {:halt, {:ok, [item | acc]}}
            {:ok, {item, rest}} -> {:cont, {rest, [item | acc]}}
            {:error, _term} = term -> {:halt, term}
          end
      end)

    case result do
      {:ok, list} ->
        readprop = %__MODULE__{
          list: Enum.reverse(list)
        }

        {:ok, readprop}

      term ->
        term
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Read Property Multiple Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, parameters} <-
           Enum.reduce_while(service.list, {:ok, []}, fn
             ras, {:ok, acc} ->
               case Protocol.AccessSpecification.encode(ras) do
                 {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
                 term -> {:halt, term}
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
        parameters: List.flatten(Enum.reverse(parameters))
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

    @spec is_confirmed(@for.t()) :: boolean()
    def is_confirmed(%@for{} = _service), do: @for.is_confirmed()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
