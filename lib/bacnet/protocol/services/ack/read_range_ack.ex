defmodule BACnet.Protocol.Services.Ack.ReadRangeAck do
  # TODO: Docs

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ResultFlags
  alias BACnet.Protocol.Constants

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil,
          result_flags: ResultFlags.t(),
          item_count: non_neg_integer(),
          item_data: [ApplicationTags.Encoding.t()],
          first_sequence_number: ApplicationTags.unsigned32() | nil
        }

  @fields [
    :object_identifier,
    :property_identifier,
    :property_array_index,
    :result_flags,
    :item_count,
    :item_data,
    :first_sequence_number
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :read_range
                )

  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(%ComplexACK{service: @service_name} = ack) do
    with {:ok, obj, rest} <-
           pattern_extract_tags(
             ack.payload,
             {:tagged, {0, _t, _l}},
             :object_identifier,
             false
           ),
         {:ok, property, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :enumerated, false),
         {:ok, array_index, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :unsigned_integer, true),
         {:ok, {first, last, more}, rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _t, _l}}, :bitstring, false),
         {:ok, item_count, rest} <-
           pattern_extract_tags(rest, {:tagged, {4, _t, _l}}, :unsigned_integer, false),
         {:ok, {:constructed, {5, item_data, _len}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {5, _t, _l}}, nil, false),
         {:ok, first_seq_num, _rest} <-
           pattern_extract_tags(rest, {:tagged, {6, _t, _l}}, :unsigned_integer, true),
         :ok <-
           if(ApplicationTags.valid_int?(first_seq_num, 32),
             do: :ok,
             else: {:error, :invalid_first_sequence_number_value}
           ) do
      struc = %__MODULE__{
        object_identifier: obj,
        property_identifier: Constants.by_value(:property_identifier, property, property),
        property_array_index: array_index,
        result_flags: %ResultFlags{
          first_item: first,
          last_item: last,
          more_items: more
        },
        item_count: item_count,
        item_data: Enum.map(item_data, &ApplicationTags.Encoding.create!/1),
        first_sequence_number: first_seq_num
      }

      {:ok, struc}
    else
      {:error, :missing_pattern} -> {:error, :invalid_service_ack}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(_ack) do
    {:error, :invalid_service_ack}
  end

  @spec to_apdu(t(), 0..255) :: {:ok, ComplexACK.t()} | {:error, term()}
  def to_apdu(ack, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = ack, invoke_id) when invoke_id in 0..255 do
    with :ok <-
           if(ApplicationTags.valid_int?(ack.first_sequence_number, 32),
             do: :ok,
             else: {:error, :invalid_first_sequence_number_value}
           ),
         {:ok, obj, _header} <-
           ApplicationTags.encode_value({:object_identifier, ack.object_identifier}),
         {:ok, property, _header} <-
           ApplicationTags.encode_value(
             {:enumerated, Constants.by_name_atom(:property_identifier, ack.property_identifier)}
           ),
         {:ok, array_index} <-
           (if ack.property_array_index do
              with {:ok, index, _header} <-
                     ApplicationTags.encode_value({:unsigned_integer, ack.property_array_index}),
                   do: {:ok, {:tagged, {2, index, byte_size(index)}}}
            else
              {:ok, nil}
            end),
         {:ok, result_flags, _header} <- encode_result_flag(ack.result_flags),
         {:ok, item_count, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, ack.item_count}),
         {:ok, value} <- encode_item_data(ack.item_data),
         {:ok, first_seq_num} <-
           (if ack.first_sequence_number do
              with {:ok, num, _header} <-
                     ApplicationTags.encode_value({:unsigned_integer, ack.first_sequence_number}),
                   do: {:ok, {:tagged, {6, num, byte_size(num)}}}
            else
              {:ok, nil}
            end) do
      parameters = [
        {:tagged, {0, obj, byte_size(obj)}},
        {:tagged, {1, property, byte_size(property)}},
        array_index,
        {:tagged, {3, result_flags, byte_size(result_flags)}},
        {:tagged, {4, item_count, byte_size(item_count)}},
        {:constructed, {5, value, 0}},
        first_seq_num
      ]

      new_ack = %ComplexACK{
        invoke_id: invoke_id,
        sequence_number: nil,
        proposed_window_size: nil,
        service: @service_name,
        payload: Enum.reject(parameters, &is_nil/1)
      }

      {:ok, new_ack}
    end
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end

  defp encode_result_flag(%ResultFlags{} = flags) do
    ApplicationTags.encode_value(
      {:bitstring, {flags.first_item, flags.last_item, flags.more_items}}
    )
  end

  defp encode_item_data(list) when is_list(list) do
    result =
      Enum.reduce_while(list, {:ok, []}, fn item, {:ok, acc} ->
        case ApplicationTags.Encoding.to_encoding(item) do
          {:ok, val} -> {:cont, {:ok, [val | acc]}}
          term -> {:halt, term}
        end
      end)

    case result do
      {:ok, list} ->
        # TODO: Do we need to flatten the list?
        # new_list =
        #   list
        #   |> Enum.reverse()
        #   |> List.flatten()

        {:ok, Enum.reverse(list)}

      term ->
        term
    end
  end
end
