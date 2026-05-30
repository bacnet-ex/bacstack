defmodule BACnet.Protocol.Services.WriteProperty do
  @moduledoc """
  This module represents the BACnet Write Property service.

  The Write Property service is used to write to a property of an object, if commandable, with priority.

  #### Service Description (ASHRAE 135)

  > The WriteProperty service is used by a client BACnet-user to modify the value of a single specified property of a BACnet
  > object. This service potentially allows write access to any property of any object, whether a BACnet-defined object or not.
  > Some implementors may wish to restrict write access to certain properties of certain objects. In such cases, an attempt to
  > modify a restricted property shall result in the return of an error of 'Error Class' PROPERTY and 'Error Code'
  > WRITE_ACCESS_DENIED. Note that these restricted properties may be accessible through the use of Virtual Terminal
  > services or other means at the discretion of the implementor.

  #### Service Procedure (ASHRAE 135)

  > After verifying the validity of the request, the responding BACnet-user shall attempt to modify the specified property of the
  > specified object using the value provided in the 'Property Value' parameter. If the modification attempt is successful, a
  > 'Result(+)' primitive shall be issued. If the modification attempt fails, a 'Result(-)' primitive shall be issued indicating the
  > reason for the failure. Interpretation of the conditional Priority parameter shall be as defined in Clause 19.

  #### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that the service request has failed in its entirety. The reason for the failure shall be
  specified by the 'Error Type' parameter.

  The 'Error Class' and 'Error Code' to be returned for specific situations are as follows:

  | Situation | Error Class | Error Code |
  |-----------|-------------|------------|
  | Specified object does not exist. | OBJECT | UNKNOWN_OBJECT |
  | Specified property does not exist. | PROPERTY | UNKNOWN_PROPERTY |
  | An array index is provided but the property is not an array. | PROPERTY | PROPERTY_IS_NOT_AN_ARRAY |
  | An array index is provided that is outside the range existing in the property. | PROPERTY | INVALID_ARRAY_INDEX |
  | The specified property is currently not writable by the requestor. | PROPERTY | WRITE_ACCESS_DENIED |
  | The datatype of the value provided is incorrect for the specified property. | PROPERTY | INVALID_DATATYPE |
  | The property is Object_Name and the name is already in use in the device. | PROPERTY | DUPLICATE_NAME |
  | The property is Object Identifier and the identifier is already in use in the device. | PROPERTY | DUPLICATE_OBJECT_ID |
  | The value provided is outside the range of values that the property can take on. | PROPERTY | VALUE_OUT_OF_RANGE |
  | There is not enough space to store the new value. | RESOURCES | NO_SPACE_TO_WRITE_PROPERTY |
  | The data being written has a datatype not supported by the property. | PROPERTY | DATATYPE_NOT_SUPPORTED |
  | The Priority parameter is not within the defined range of 1..16. This condition may be ignored if the property is not commandable. | SERVICES | PARAMETER_OUT_OF_RANGE |
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  @typedoc """
  Parameters for the Write Property service.

  Identifies the target object property (with optional array index and priority) and the new value
  (as one or more application tag encodings) to write.
  """
  @type t :: %__MODULE__{
          object_identifier: Protocol.ObjectIdentifier.t(),
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil,
          property_value: ApplicationTags.Encoding.t() | [ApplicationTags.Encoding.t()],
          priority: 1..16 | nil
        }

  @fields [
    :object_identifier,
    :property_identifier,
    :property_array_index,
    :property_value,
    :priority
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :write_property
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
  Converts the given Confirmed Service Request into a Write Property Service.
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
         {:ok, {:constructed, {3, value, _l}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {3, _t, _l}}, nil, false),
         {:ok, priority, _rest} <-
           pattern_extract_tags(rest, {:tagged, {4, _t, _l}}, :unsigned_integer, true) do
      readprop = %__MODULE__{
        object_identifier: object,
        property_identifier: Constants.by_value(:property_identifier, property, property),
        property_array_index: array_index,
        property_value:
          if(is_list(value),
            do: Enum.map(value, &ApplicationTags.Encoding.create!/1),
            else: ApplicationTags.Encoding.create!(value)
          ),
        priority: priority
      }

      {:ok, readprop}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Write Property Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
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
            end),
         {:ok, priority} <-
           (if service.priority do
              with {:ok, priority, _header} <-
                     ApplicationTags.encode_value({:unsigned_integer, service.priority}) do
                {:ok, {:tagged, {4, priority, byte_size(priority)}}}
              end
            else
              {:ok, nil}
            end),
         {:ok, values} <-
           (if is_list(service.property_value) do
              res =
                Enum.reduce_while(service.property_value, {:ok, []}, fn item, {:ok, acc} ->
                  case ApplicationTags.Encoding.to_encoding(item) do
                    {:ok, enc} -> {:cont, {:ok, [enc | acc]}}
                    term -> {:halt, term}
                  end
                end)

              case res do
                {:ok, list} -> {:ok, Enum.reverse(list)}
                term -> term
              end
            else
              ApplicationTags.Encoding.to_encoding(service.property_value)
            end) do
      parameters = [
        {:tagged, {0, object_identifier, byte_size(object_identifier)}},
        {:tagged, {1, property_identifier, byte_size(property_identifier)}},
        array_index,
        {:constructed, {3, values, 0}},
        priority
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
