defmodule BACnet.Protocol.Services.AddListElement do
  @moduledoc """
  This module represents the BACnet Add List Element service.

  The Add List Element service is used to add elements to a list property.

  Service Description (ASHRAE 135):
  > The AddListElement service is used by a client BACnet-user to add one or more list elements
  > to an object property that is a list.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

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
  @spec is_confirmed() :: true
  def is_confirmed(), do: true

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

    @spec is_confirmed(@for.t()) :: boolean()
    def is_confirmed(%@for{} = _service), do: @for.is_confirmed()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
