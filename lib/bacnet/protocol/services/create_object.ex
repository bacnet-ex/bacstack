defmodule BACnet.Protocol.Services.CreateObject do
  @moduledoc """
  This module represents the BACnet Create Object service.

  The Create Object service is used to dynamically create an object in the remote device.

  #### Service Description (ASHRAE 135)

  > The CreateObject service is used by a client BACnet-user to create a new instance of an object. This service may be used to
  > create instances of both standard and vendor specific objects. The standard object types supported by this service shall be
  > specified in the PICS. The properties of standard objects created with this service may be initialized in two ways: initial
  > values may be provided as part of the CreateObject service request or values may be written to the newly created object using
  > the BACnet WriteProperty services. The initialization of non-standard objects is a local matter. The behavior of objects
  > created by this service that are not supplied, or only partially supplied, with initial property values is dependent upon the
  > device and is a local matter.

  #### Service Procedure (ASHRAE 135)

  > After verifying the validity of the request, the responding BACnet-user shall attempt to create a new object of the type
  > specified in the 'Object Specifier' parameter. If the 'Object Specifier' parameter contains an object type, the Object_Identifier
  > property of the newly created object shall be initialized to a value that is unique within the responding BACnet-user device.
  > The method used to generate the object identifier is a local matter. The Object_Type property shall be initialized to the value
  > of the 'Object Specifier' parameter. If a new object of the specified type cannot be created, a 'Result(-)' primitive shall be
  > returned and the 'First Failed Element Number' parameter shall have a value of zero. If the 'Object Specifier' parameter
  > contains an object identifier, the responding BACnet-user shall determine if an object with this identifier already exists. If
  > such an object exists, then a new object shall not be created, and a 'Result(-)' primitive shall be returned and the 'First Failed
  > Element Number' parameter shall have a value of zero. If such an object does not exist and it cannot be created, a 'Result(-)'
  > primitive shall be returned and the 'First Failed Element Number' parameter shall have a value of zero. If such an object does
  > not exist but it can be created, the new object shall be created. The Object_Identifier property of the new object shall have the
  > value specified in the 'Object Specifier' parameter, and the Object_Type property shall have a value consistent with the object
  > type field of the Object_Identifier.
  > If the optional 'List of Initial Values' parameter is included, then all properties in the list shall be initialized as indicated. The
  > initial values of all other properties are a local matter. If this initialization cannot be done, then a 'Result(-)' primitive shall be
  > returned. The 'First Failed Element Number' parameter shall indicate the first property in the 'List of Initial Values' that
  > cannot be initialized, and the object shall not be created. If the attempt to create the object is successful, a 'Result(+)'
  > response primitive shall be issued that conveys the value of the Object_Identifier property of the newly created object.

  #### Result(+) Response (ASHRAE 135)

  On success, the responding BACnet-user returns a 'Result(+)' primitive containing the 'Object Identifier' of the newly created object.
  This allows the client to know the instance number that was assigned (especially important when the client only specified an object type).

  #### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that the service request failed. The reason for failure is specified by the 'Error Type'
  parameter.

  The 'Error Class' and 'Error Code' to be returned for specific situations are as follows:

  | Situation | Error Class | Error Code |
  |-----------|-------------|------------|
  | The device cannot allocate the space needed for the new object. | RESOURCES | NO_SPACE_FOR_OBJECT |
  | The device supports the object type and may have sufficient space, but does not support the creation of the object for some other reason. | OBJECT | DYNAMIC_CREATION_NOT_SUPPORTED |
  | The device does not support the specified object type. | OBJECT | UNSUPPORTED_OBJECT_TYPE |
  | The object being created already exists. | OBJECT | OBJECT_IDENTIFIER_ALREADY_EXISTS |
  | A datatype of a property value specified in the List of Initial Values does not match the datatype of the property specified by the Property_Identifier. | PROPERTY | INVALID_DATATYPE |
  | A value used in the List of Initial Values is outside the range of values defined for the property specified by the Property_Identifier. | PROPERTY | VALUE_OUT_OF_RANGE |
  | A Property_Identifier has been specified in the List of Initial Values that is unknown for objects of the type being created. | PROPERTY | UNKNOWN_PROPERTY |
  | A character string value was encountered in the List of Initial Values that is not a supported character set. | PROPERTY | CHARACTER_SET_NOT_SUPPORTED |
  | A property specified by the Property_Identifier in the List of Initial Values does not support initialization during the CreateObject service. | PROPERTY | WRITE_ACCESS_DENIED |
  | The data being written has a datatype not supported by the property. | PROPERTY | DATATYPE_NOT_SUPPORTED |
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  require Constants

  @behaviour Protocol.Services.Behaviour

  @typedoc """
  Parameters for the Create Object service.

  Specifies either an object type (for the device to assign an instance) or a specific object identifier,
  plus a list of initial PropertyValue settings to apply to the newly created object.
  """
  @type t :: %__MODULE__{
          object_specifier: Protocol.ObjectIdentifier.t() | Constants.object_type(),
          initial_values: [Protocol.PropertyValue.t()]
        }

  @fields [
    :object_specifier,
    :initial_values
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :create_object
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
  Converts the given Confirmed Service Request into a Create Object Service.
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
        {:constructed, {0, {:tagged, {tag_num, object_specifier, _length2}}, _length}}
        | rest
      ]
      when tag_num in [0, 1] ->
        object =
          case tag_num do
            0 ->
              with {:ok, {:enumerated, enum}} <-
                     ApplicationTags.unfold_to_type(:enumerated, object_specifier),
                   do:
                     (case Constants.by_value(:object_type, enum) do
                        {:ok, _val} = val -> val
                        :error -> {:error, {:unknown_object_type, enum}}
                      end)

            1 ->
              with {:ok, {:object_identifier, obj}} <-
                     ApplicationTags.unfold_to_type(:object_identifier, object_specifier),
                   do: {:ok, obj}
          end

        with {:ok, specifier} <- object,
             {:ok, values} <-
               (case rest do
                  [{:constructed, {1, [_hd | _tl] = list_of_initial, _length}} | _tl2]
                  when is_list(list_of_initial) ->
                    Protocol.PropertyValue.parse_all(list_of_initial)

                  [{:constructed, {1, [], _length}} | _tl2] ->
                    {:ok, []}

                  _else ->
                    {:ok, []}
                end) do
          obj = %__MODULE__{
            object_specifier: specifier,
            initial_values: values
          }

          {:ok, obj}
        else
          {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
          {:error, _err} = err -> err
        end

      _else ->
        {:error, :invalid_request_parameters}
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Create Object Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    specifier =
      if is_struct(service.object_specifier, Protocol.ObjectIdentifier) do
        {1, ApplicationTags.encode_value({:object_identifier, service.object_specifier})}
      else
        result =
          with {:ok, object_type_c} <-
                 Constants.by_name_with_reason(
                   :object_type,
                   service.object_specifier,
                   {:unknown_object_type, service.object_specifier}
                 ) do
            ApplicationTags.encode_value({:enumerated, object_type_c})
          end

        {0, result}
      end

    case specifier do
      {tag, {:ok, specifier, _hd}} ->
        with {:ok, proplist} <- Protocol.PropertyValue.encode_all(service.initial_values) do
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
            parameters: [
              {:constructed, {0, {:tagged, {tag, specifier, byte_size(specifier)}}, 0}}
              | if(proplist == [], do: [], else: [{:constructed, {1, proplist, 0}}])
            ]
          }

          {:ok, req}
        end

      {_tag, term} ->
        term
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
