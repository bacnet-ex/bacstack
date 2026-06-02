defmodule BACnet.Protocol.Services.ReadPropertyMultiple do
  @moduledoc """
  This module represents the BACnet Read Property Multiple service.

  The Read Property Multiple service is used to read multiple properties of one or multiple objects.

  ### Service Description (ASHRAE 135)

  > The ReadPropertyMultiple service is used by a client BACnet-user to request the values of one or more specified properties
  > of one or more BACnet Objects. This service allows read access to any property of any object, whether a BACnet-defined
  > object or not. The user may read a single property of a single object, a list of properties of a single object, or any number of
  > properties of any number of objects. A 'Read Access Specification' with the property identifier ALL can be used to learn the
  > implemented properties of an object along with their values.

  ### Service Procedure (ASHRAE 135)

  > After verifying the validity of the request, the responding BACnet-user shall attempt to access the specified properties of the
  > specified objects and shall construct a 'List of Read Access Results' in the order specified in the request. If the 'List of
  > Property References' portion of the 'List of Read Access Specifications' parameter contains the property identifier ALL,
  > REQUIRED, or OPTIONAL, then the 'List of Read Access Results' shall be constructed as if each property being returned
  > had been explicitly referenced. While there is no requirement that the request be carried out "atomically," the responding
  > BACnet-user shall ensure that all readings are taken in the shortest possible time subject only to higher priority processing.
  > The request shall continue to be executed until an attempt has been made to access all specified properties. If none of the
  > specified objects is found or if none of the specified properties of the specified objects can be accessed, either a 'Result(-)'
  > primitive or a Result(+) primitive that returns error codes for all properties shall be issued. If any of the specified properties
  > of the specified objects can be accessed, then a 'Result(+)' primitive shall be issued, which returns all accessed values and
  > error codes for all properties that could not be accessed.
  > When the object-type in the Object Identifier portion of the Read Access Specification parameter contains the value 'Device
  > Object' and the instance of that 'Object Identifier' parameter contains the value 4194303, the responding BACnet-user shall
  > treat the Object Identifier as if it correctly matched the local Device object. This allows the device instance of a device that
  > does not generate I-Am messages to be determined.

  ### Result(+) Response (ASHRAE 135)

  On success, the responding BACnet-user returns a 'Result(+)' primitive containing a 'List of Read Access Results'.
  Each entry corresponds to one 'Read Access Specification' from the request and contains:

  - The 'Object Identifier' and 'Property Identifier' (and optional 'Property Array Index').
  - Either the successfully read property value(s), or an error code if that specific property could not be read.

  The order of results matches the order of the original request. Partial success is allowed - some properties may succeed while others return errors.

  ### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that the service request has failed in its entirety. The reason for the failure shall be
  specified by the 'Error Type' parameter.

  The 'Error Class' and 'Error Code' to be returned for specific situations are as follows:

  | Situation | Error Class | Error Code |
  |-----------|-------------|------------|
  | Specified object does not exist. | OBJECT | UNKNOWN_OBJECT |
  | Specified property does not exist. | PROPERTY | UNKNOWN_PROPERTY |
  | An array index is provided but the property is not an array. | PROPERTY | PROPERTY_IS_NOT_AN_ARRAY |
  | An array index is provided that is outside the range existing in the property. | PROPERTY | INVALID_ARRAY_INDEX |
  | The property is not accessible using this service. | PROPERTY | READ_ACCESS_DENIED |
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants

  require Constants

  @behaviour Protocol.Services.Behaviour

  @typedoc """
  Parameters for the Read Property Multiple service.

  Contains a list of Access Specifications describing one or more objects and the properties (or property ranges)
  to be read atomically in a single request. The response is a Read Property Multiple ACK.
  """
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
  @spec confirmed?() :: true
  def confirmed?(), do: true

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

    @spec confirmed?(@for.t()) :: boolean()
    def confirmed?(%@for{} = _service), do: @for.confirmed?()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
