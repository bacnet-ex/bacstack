defmodule BACnet.Protocol.Services.ReadRange do
  @moduledoc """
  This module represents the BACnet Read Range service.

  The Read Range service is used to read range of a property of an object.

  ### Service Description (ASHRAE 135)

  > The ReadRange service is used by a client BACnet-user to read a specific range of data items representing a subset of data
  > available within a specified object property. The service may be used with any list or array of lists property.

  ### Service Procedure (ASHRAE 135)

  > The responding BACnet-user shall first verify the validity of the 'Object Identifier', 'Property Identifier' and 'Property Array
  > Index' parameters and return a 'Result(-)' response with the appropriate error class and code if the object or property is
  > unknown, if the referenced data is not a list or array, or if it is currently inaccessible for another reason.
  > If the 'Range' parameter is not present, then the responding BACnet-user shall read and attempt to return all of the available
  > items in the list or array. If the 'Range' parameter is present and specifies the 'By Position' parameters, then the responding
  > BACnet-user shall read and attempt to return all of the items specified. The items specified include the item at the index
  > specified by the 'Reference Index' plus up to 'Count' - 1 items following if 'Count' is positive, or up to -1 - 'Count' items
  > preceding if 'Count' is negative. The first element of a list shall be associated with index 1.
  > If the 'Range' parameter is present and specifies the 'By Time' parameter, then the responding BACnet-user shall read and
  > attempt to return all of the items specified. If 'By Time' parameters are specified and the property values are not timestamped
  > an error shall be returned. If 'Count' is positive, the records specified include the first record with a timestamp newer than
  > 'Reference Time' plus up to 'Count'-1 items following. If 'Count' is negative, the records specified include the newest record
  > with a timestamp older than 'Reference Time' and up to -1-'Count' records preceding. The sequence number of the first item
  > returned shall be included in the response. The items shall be returned in chronological order.
  > If the 'Range' parameter is present and specifies the 'By Sequence Number' parameters, then the responding BACnet-user
  > shall read and attempt to return all of the items specified. The items specified are all items with a sequence number in the
  > range 'Reference Sequence Number' to 'Reference Sequence Number' plus 'Count'-1 if 'Count' is positive, or in the range
  > 'Reference Sequence Number' plus 'Count'+1 to 'Reference Sequence' if 'Count' is negative.
  > To avoid missing items when using chained time-based reads, the first item in the desired set should be found using the 'By
  > Time' form of the 'Range' parameter. Subsequent requests to retrieve the remaining items in the desired set should use the 'By
  > Sequence Number' form of the 'Range' parameter.
  > The returned response shall convey the number of items read and returned using the 'Item Count' parameter. The actual items
  > shall be returned in the 'Item Data' parameter. If the returned response includes the first positional index and a 'By Position'
  > request had been made, or the oldest sequence number and a 'By Sequence Number' or 'By Time' request had been made, then
  > the 'Result Flags' parameter shall contain the FIRST_ITEM flag set to TRUE; otherwise it shall be FALSE.
  > If the returned response includes the last positional index and a 'By Position' request had been made, or the newest sequence
  > number and a 'By Sequence Number' or 'By Time' request had been made, then the 'Result Flags' shall contain the
  > LAST_ITEM flag set to TRUE; otherwise it shall be FALSE.
  > If there are no items in the list that match the 'Range' parameter criteria, then a Result(+) shall be returned with an 'Item
  > Count' of 0 and no 'First Sequence Number' parameter.

  ### Result(+) Response (ASHRAE 135)

  On success, the responding BACnet-user returns a 'Result(+)' primitive containing:

  - 'Item Count' - The number of items returned.
  - 'Item Data' - The list of items read (BACnetARRAY of the appropriate datatype).
  - 'Result Flags' - A bit string indicating whether the first item ('FIRST_ITEM') and/or last item ('LAST_ITEM') of the list were returned.
  - 'First Sequence Number' (optional) - Present when the 'By Sequence Number' or 'By Time' form of 'Range' was used. Indicates the sequence number of the first item returned.

  If no items matched the request criteria, a 'Result(+)' is still returned with 'Item Count' = 0 and no 'First Sequence Number'.

  ### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that the service request has failed. The reason for the failure shall be specified by the
  'Error Type' parameter.

  The 'Error Class' and 'Error Code' to be returned for specific situations are as follows:

  | Situation | Error Class | Error Code |
  |-----------|-------------|------------|
  | Specified property does not exist. The specified property is currently not readable by the requester. | PROPERTY | UNKNOWN_PROPERTY / READ_ACCESS_DENIED |
  | Property is not a list or array of lists | SERVICES | PROPERTY_IS_NOT_A_LIST |
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
  Range selector for the Read Range service.

  One of three forms used to identify a contiguous window of results when reading array-like or sequenced
  properties (e.g. Trend Log records): by position (array index + count), by sequence number, or by time.

  The `property_identifier` must not be a special value, such as `:all`, `:required` or `:optional`.
  Count of range must not be zero.
  """
  @type range ::
          {:by_position,
           {reference_index :: non_neg_integer(), count :: ApplicationTags.signed16()}}
          | {:by_seq_number,
             {reference_seq_number :: ApplicationTags.unsigned32(),
              count :: ApplicationTags.signed16()}}
          | {:by_time,
             {reference_time :: Protocol.BACnetDateTime.t(), count :: ApplicationTags.signed16()}}

  @typedoc """
  Parameters for the Read Range service.

  Identifies the object property to read along with an optional range selector that limits the returned
  results to a window (used for properties that are lists or logs with many entries).
  """
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
  @spec confirmed?() :: true
  def confirmed?(), do: true

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

    @spec confirmed?(@for.t()) :: boolean()
    def confirmed?(%@for{} = _service), do: @for.confirmed?()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
