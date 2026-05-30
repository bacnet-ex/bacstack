defmodule BACnet.Protocol.Services.AddListElement do
  @moduledoc """
  This module represents the BACnet Add List Element service.

  The Add List Element service is used to add elements to a list property.

  #### Service Description (ASHRAE 135)

  > The AddListElement service is used by a client BACnet-user to add one or more list elements
  > to an object property that is a list.

  #### Service Procedure (ASHRAE 135)

  > After verifying the validity of the request, the responding BACnet-user shall attempt to modify the object identified in the
  > 'Object Identifier' parameter. If the identified object exists and has the property specified in the 'Property Identifier'
  > parameter, an attempt shall be made to add all of the elements specified in the 'List of Elements' parameter to the specified
  > property. If this attempt is successful, a 'Result(+)' primitive shall be issued.
  > When comparing elements in the List of Elements with elements in the specified property, the complete element shall be
  > compared unless the property description specifies otherwise. If one or more of the elements is already present in the list, it
  > shall be updated with the provided element, that is, the existing element is over-written with the provided element.
  > Optionally, if the provided element is exactly the same as the existing element in every way, it can be ignored, that is, not
  > added to the list. Ignoring an element that already exists shall not cause the service to fail.
  > If the specified object does not exist, the specified property does not exist, or the specified property is not a list, then the
  > service shall fail and a 'Result(-)' response primitive shall be issued. If one or more elements cannot be added to, or updated
  > in, the list, a 'Result(-)' response primitive shall be issued and no elements shall be added to, or updated in, the list.
  > The effect of this service shall be to add to, or update in, the list all of the specified elements, or to neither add nor update any
  > elements at all.

  #### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that the service request failed and none of the specified elements were added to the
  list. The reason for failure is specified by the 'Error Type' parameter.

  The 'Error Class' and 'Error Code' to be returned for specific situations are as follows:

  | Situation | Error Class | Error Code |
  |-----------|-------------|------------|
  | Specified object does not exist. | OBJECT | UNKNOWN_OBJECT |
  | Specified property does not exist. | PROPERTY | UNKNOWN_PROPERTY |
  | The element datatype does not match the property. | PROPERTY | INVALID_DATATYPE |
  | The data being written has a datatype not supported by the property. | PROPERTY | DATATYPE_NOT_SUPPORTED |
  | The element value is out of range for the property. | PROPERTY | VALUE_OUT_OF_RANGE |
  | The specified property is currently not modifiable by the requester. | PROPERTY | WRITE_ACCESS_DENIED |
  | There is not enough free memory for the element. | RESOURCES | NO_SPACE_TO_ADD_LIST_ELEMENT |
  | The property or specified array element is not a list. | RESOURCES | PROPERTY_IS_NOT_A_LIST |
  | An array index is provided but the property is not an array. | PROPERTY | PROPERTY_IS_NOT_AN_ARRAY |
  | An array index is provided that is outside the range existing in the property. | PROPERTY | INVALID_ARRAY_INDEX |
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  @typedoc """
  Parameters for the Add List Element service.

  Specifies the target object and list property (with optional array index) along with one or more elements
  (as application tag encodings) to append to the list.
  """
  @type t :: %__MODULE__{
          object_identifier: Protocol.ObjectIdentifier.t(),
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil,
          elements: [ApplicationTags.Encoding.t()]
        }

  @fields [
    :object_identifier,
    :property_identifier,
    :property_array_index,
    :elements
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :add_list_element
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
  Converts the given Confirmed Service Request into an Add List Element Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {:ok, object, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :object_identifier,
             false
           ),
         {:ok, property, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :enumerated, false),
         {:ok, array_index, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :unsigned_integer, true),
         {:ok, {:constructed, {3, elements, _l}}, _rest} <-
           pattern_extract_tags(rest, {:constructed, {3, _t, _l}}, nil, false) do
      add_list = %__MODULE__{
        object_identifier: object,
        property_identifier: Constants.by_value(:property_identifier, property, property),
        property_array_index: array_index,
        elements: Enum.map(List.wrap(elements), &ApplicationTags.Encoding.create!/1)
      }

      {:ok, add_list}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Add List Element Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{elements: elements} = service, request_data) when is_list(elements) do
    with {:ok, object_identifier, _header} <-
           ApplicationTags.encode_value({:object_identifier, service.object_identifier}),
         {:ok, property_identifier, _header} <-
           ApplicationTags.encode_value(
             {:enumerated,
              Constants.by_name_atom(:property_identifier, service.property_identifier)}
           ),
         {:ok, array_index} <-
           (if service.property_array_index do
              with {:ok, array_index, _header} <-
                     ApplicationTags.encode_value(
                       {:unsigned_integer, service.property_array_index}
                     ) do
                {:ok, {:tagged, {2, array_index, byte_size(array_index)}}}
              end
            else
              {:ok, nil}
            end) do
      parameters = [
        {:tagged, {0, object_identifier, byte_size(object_identifier)}},
        {:tagged, {1, property_identifier, byte_size(property_identifier)}},
        array_index,
        {:constructed, {3, Enum.map(elements, &ApplicationTags.Encoding.to_encoding!/1), 0}}
      ]

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
        parameters: Enum.reject(parameters, &is_nil/1)
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
