defmodule BACnet.Protocol.Services.ReadRange do
  @moduledoc """
  This module represents the BACnet Read Range service.

  The Read Range service is used to read range of a property of an object.

  Service Description (ASHRAE 135):
  > The ReadRange service is used by a client BACnet-user to read a specific range of data items representing a subset of data
  > available within a specified object property. The service may be used with any list or array of lists property.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs
  # property_identifier MUST NOT be one of ALL, REQUIRED or OPTIONAL
  # Count of range MAY NOT be zero

  @type range ::
          {:by_position,
           {reference_index :: non_neg_integer(), count :: ApplicationTags.signed16()}}
          | {:by_seq_number,
             {reference_seq_number :: ApplicationTags.unsigned32(),
              count :: ApplicationTags.signed16()}}
          | {:by_time,
             {reference_time :: Protocol.BACnetDateTime.t(), count :: ApplicationTags.signed16()}}

  @type t :: %__MODULE__{
          object_identifier: Protocol.ObjectIdentifier.t(),
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil,
          range: range() | nil
        }

  @fields [
    :object_identifier,
    :property_identifier,
    :property_array_index,
    :range
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :read_range
                )

  # Checks whether the argument is a valid count (INTEGER16 and not zero)
  defguardp is_valid_count(range)
            when is_integer(range) and range != 0 and range in -32_768..32_767

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
  Converts the given Confirmed Service Request into a Read Range Service.
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
         prop_identifier <- Constants.by_value(:property_identifier, property, property),
         :ok <-
           (if prop_identifier in [:all, :required, :optional] do
              {:error, :invalid_property_identifier}
            else
              :ok
            end),
         {:ok, array_index, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :unsigned_integer, true),
         {:ok, range} <- parse_range(rest) do
      readrange = %__MODULE__{
        object_identifier: object,
        property_identifier: prop_identifier,
        property_array_index: array_index,
        range: range
      }

      {:ok, readrange}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Read Range Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with :ok <-
           (if service.property_identifier in [:all, :required, :optional] do
              {:error, :invalid_property_identifier}
            else
              :ok
            end),
         {:ok, object_identifier, _header} <-
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
         {:ok, range} <- encode_range(service.range) do
      parameters = [
        {:tagged, {0, object_identifier, byte_size(object_identifier)}},
        {:tagged, {1, property_identifier, byte_size(property_identifier)}},
        array_index,
        range
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

  defp parse_range([
         {:constructed,
          {3,
           [
             unsigned_integer: ref_index,
             signed_integer: count
           ], _len}}
         | _rest
       ])
       when is_valid_count(count),
       do: {:ok, {:by_position, {ref_index, count}}}

  defp parse_range([
         {:constructed,
          {6,
           [
             unsigned_integer: seq_number,
             signed_integer: count
           ], _len}}
         | _rest
       ])
       when is_valid_count(count),
       do: {:ok, {:by_seq_number, {seq_number, count}}}

  defp parse_range([
         {:constructed,
          {7,
           [
             date: ref_date,
             time: ref_time,
             signed_integer: count
           ], _len}}
         | _rest
       ])
       when is_valid_count(count),
       do: {:ok, {:by_time, {%Protocol.BACnetDateTime{date: ref_date, time: ref_time}, count}}}

  # range missing
  defp parse_range([]), do: {:ok, nil}

  # unsupported context tag/payload
  defp parse_range(_term), do: {:error, :invalid_range_param}

  defp encode_range(nil), do: {:ok, nil}

  defp encode_range({:by_position, {ref_index, count}})
       when is_integer(ref_index) and is_valid_count(count) do
    {:ok, {:constructed, {3, [unsigned_integer: ref_index, signed_integer: count], 0}}}
  end

  defp encode_range({:by_seq_number, {ref_seq_number, count}})
       when is_integer(ref_seq_number) and is_valid_count(count) do
    {:ok, {:constructed, {6, [unsigned_integer: ref_seq_number, signed_integer: count], 0}}}
  end

  defp encode_range({:by_time, {%Protocol.BACnetDateTime{} = ref_datetime, count}})
       when is_valid_count(count) do
    {:ok,
     {:constructed,
      {7, [date: ref_datetime.date, time: ref_datetime.time, signed_integer: count], 0}}}
  end

  defp encode_range(_term), do: {:error, :invalid_range}

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
