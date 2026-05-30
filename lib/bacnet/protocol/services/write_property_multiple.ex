defmodule BACnet.Protocol.Services.WritePropertyMultiple do
  @moduledoc """
  This module represents the BACnet Write Property Multiple service.

  The Write Property Multiple service is used to write to one or more properties of one or more objects,
  if commandable, with priority.

  #### Service Description (ASHRAE 135)

  > The WritePropertyMultiple service is used by a client BACnet-user to modify the value of one or more specified properties
  > of a BACnet object. This service potentially allows write access to any property of any object, whether a BACnet-defined
  > object or not. Properties shall be modified by the WritePropertyMultiple service in the order specified in the 'List of Write Access
  > Specifications' parameter, and execution of the service shall continue until all of the specified properties have been written to
  > or a property is encountered that for some reason cannot be modified as requested.
  > Some implementors may wish to restrict write access to certain properties of certain objects. In such cases, an attempt to
  > modify a restricted property shall result in the return of an error of 'Error Class' PROPERTY and 'Error Code'
  > WRITE_ACCESS_DENIED. Note that these restricted properties may be accessible through the use of Virtual Terminal
  > services or other means at the discretion of the implementor.

  #### Service Procedure (ASHRAE 135)

  > For each 'Write Access Specification' contained in the 'List of Write Access Specifications', the value of each specified
  > property shall be replaced by the property value provided in the 'Write Access Specification' and a 'Result(+)' primitive shall
  > be issued, indicating that the service request was carried out in its entirety. Interpretation of the conditional Priority parameter
  > shall be as specified in Clause 19. If, in the process of carrying out the modification of the indicated properties in the order specified in the 'List of Write Access
  > Specifications', a property is encountered that cannot be modified, the responding BACnet-user shall issue a 'Result(-)'
  > response primitive indicating the reason for the failure. The result of this service shall be either that all of the specified
  > properties or only the properties up to, but not including, the property specified in the 'First Failed Write Attempt' parameter
  > were successfully modified. A BACnet-Reject-PDU shall be issued only if no write operations have been successfully executed,
  > indicating that the service request was rejected in its entirety. If any of the write operations contained in the 'List of Write Access Specifications'
  > have been successfully executed, a Result(-) response indicating the reason for the failure shall be issued as described above.

  #### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that at least one of the specified properties could not be modified as requested. The
  reason for the failure shall be conveyed by the 'Error Type' parameter along with the 'Object Identifier', 'Property Identifier',
  and 'Property Array Index' of the first encountered property that could not be properly written.

  The 'Error Class' and 'Error Code' to be returned in a 'Result(-)' for specific situations are as follows:

  | Situation | Error Class | Error Code |
  |-----------|-------------|------------|
  | Specified object does not exist. | OBJECT | UNKNOWN_OBJECT |
  | Specified property does not exist. | PROPERTY | UNKNOWN_PROPERTY |
  | An array index is provided but the property is not an array. | PROPERTY | PROPERTY_IS_NOT_AN_ARRAY |
  | An array index is provided that is outside the range existing in the property. | PROPERTY | INVALID_ARRAY_INDEX |
  | The specified property is currently read-only. | PROPERTY | WRITE_ACCESS_DENIED |
  | The datatype of the value provided is incorrect for the specified property. | PROPERTY | INVALID_DATATYPE |
  | The property is Object_Name and the name is already in use in the device. | PROPERTY | DUPLICATE_NAME |
  | The property is Object Identifier and the identifier is already in use in the device. | PROPERTY | DUPLICATE_OBJECT_ID |
  | The value provided is outside the range of values that the property can take on. | PROPERTY | VALUE_OUT_OF_RANGE |
  | There is not enough space to store the new value. | RESOURCES | NO_SPACE_TO_WRITE_PROPERTY |
  | The data being written has a datatype not supported by the property. | PROPERTY | DATATYPE_NOT_SUPPORTED |
  | The Priority parameter is not within the defined range of 1..16. This condition may be ignored if the property is not commandable. | SERVICES | PARAMETER_OUT_OF_RANGE |
  | A syntax error is encountered in the message after one or more properties have been successfully written. | SERVICES | INVALID_TAG |
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants

  require Constants

  @behaviour Protocol.Services.Behaviour

  @typedoc """
  Parameters for the Write Property Multiple service.

  Contains a list of Access Specifications, each describing an object and one or more properties with
  their new values and (for commandable properties) the priority to use for the write.
  """
  @type t :: %__MODULE__{
          list: [Protocol.AccessSpecification.t()]
        }

  @fields [
    :list
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :write_property_multiple
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
  Converts the given Confirmed Service Request into a Write Property Multiple Service.
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
        writeprop = %__MODULE__{
          list: Enum.reverse(list)
        }

        {:ok, writeprop}

      term ->
        term
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Write Property Multiple Service.

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
