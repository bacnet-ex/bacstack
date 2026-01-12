defmodule BACnet.Protocol.Services.Ack.ReadPropertyAck do
  # TODO: Docs

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil,
          property_value: ApplicationTags.Encoding.t() | [ApplicationTags.Encoding.t()]
        }

  @fields [
    :object_identifier,
    :property_identifier,
    :property_array_index,
    :property_value
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :read_property
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
         {:ok, {:constructed, {3, value, _l}}, _rest} <-
           pattern_extract_tags(rest, {:constructed, {3, _t, _l}}, nil, false) do
      struc = %__MODULE__{
        object_identifier: obj,
        property_identifier: Constants.by_value(:property_identifier, property, property),
        property_array_index: array_index,
        property_value:
          if(is_list(value),
            do: Enum.map(value, &ApplicationTags.Encoding.create!/1),
            else: ApplicationTags.Encoding.create!(value)
          )
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
    with {:ok, obj, _header} <-
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
         {:ok, value} <-
           (if is_list(ack.property_value) do
              result =
                Enum.reduce_while(ack.property_value, {:ok, []}, fn value, {:ok, acc} ->
                  case ApplicationTags.Encoding.to_encoding(value) do
                    {:ok, res} -> {:cont, {:ok, [res | acc]}}
                    {:error, _err} = err -> {:halt, err}
                  end
                end)

              case result do
                {:ok, result} -> {:ok, Enum.reverse(result)}
                term -> term
              end
            else
              ApplicationTags.Encoding.to_encoding(ack.property_value)
            end) do
      parameters = [
        {:tagged, {0, obj, byte_size(obj)}},
        {:tagged, {1, property, byte_size(property)}},
        array_index,
        {:constructed, {3, value, 0}}
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
end
