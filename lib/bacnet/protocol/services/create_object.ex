defmodule BACnet.Protocol.Services.CreateObject do
  @moduledoc """
  This module represents the BACnet Create Object service.

  The Create Object service is used to dynamically create an object in the remote device.

  Service Description (ASHRAE 135):
  > The CreateObject service is used by a client BACnet-user to create a new instance of an object. This service may be used to
  > create instances of both standard and vendor specific objects. The standard object types supported by this service shall be
  > specified in the PICS. The properties of standard objects created with this service may be initialized in two ways: initial
  > values may be provided as part of the CreateObject service request or values may be written to the newly created object using
  > the BACnet WriteProperty services. The initialization of non-standard objects is a local matter. The behavior of objects
  > created by this service that are not supplied, or only partially supplied, with initial property values is dependent upon the
  > device and is a local matter.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

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
  @spec is_confirmed() :: true
  def is_confirmed(), do: true

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
                   {:ok, const_enum} <-
                     (case Constants.by_value(:object_type, enum) do
                        {:ok, _val} = val -> val
                        :error -> {:error, {:unknown_object_type, enum}}
                      end),
                   do: {:ok, const_enum}

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

    @spec is_confirmed(@for.t()) :: boolean()
    def is_confirmed(%@for{} = _service), do: @for.is_confirmed()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
