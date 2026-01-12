defmodule BACnet.Protocol.Services.Ack.ConfirmedPrivateTransferAck do
  # TODO: Docs

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          vendor_id: ApplicationTags.unsigned16(),
          service_number: non_neg_integer(),
          result: [ApplicationTags.Encoding.t()]
        }

  @fields [:vendor_id, :service_number, :result]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :confirmed_private_transfer
                )

  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(%ComplexACK{service: @service_name} = ack) do
    with {:ok, vendor_id, rest} <-
           pattern_extract_tags(
             ack.payload,
             {:tagged, {0, _c, _l}},
             :unsigned_integer,
             false
           ),
         :ok <-
           if(ApplicationTags.valid_int?(vendor_id, 16),
             do: :ok,
             else: {:error, :invalid_vendor_id_value}
           ),
         {:ok, service_num, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _c, _l}}, :unsigned_integer, false),
         {:ok, result, _rest} <-
           pattern_extract_tags(
             rest,
             {:constructed, {2, _c, _l}},
             fn {:constructed, {2, result, _len}} -> {:ok, result} end,
             true
           ) do
      struc = %__MODULE__{
        vendor_id: vendor_id,
        service_number: service_num,
        result:
          if(result,
            do: Enum.map(List.wrap(result), &ApplicationTags.Encoding.create!(&1)),
            else: []
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
    with :ok <-
           if(ApplicationTags.valid_int?(ack.vendor_id, 16),
             do: :ok,
             else: {:error, :invalid_vendor_id_value}
           ),
         {:ok, vendor, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, ack.vendor_id}),
         {:ok, service_num, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, ack.service_number}) do
      new_ack = %ComplexACK{
        invoke_id: invoke_id,
        sequence_number: nil,
        proposed_window_size: nil,
        service: @service_name,
        payload:
          Enum.reject(
            [
              {:tagged, {0, vendor, byte_size(vendor)}},
              {:tagged, {1, service_num, byte_size(service_num)}},
              if(ack.result == [],
                do: nil,
                else:
                  {:constructed,
                   {2, Enum.map(ack.result, &ApplicationTags.Encoding.to_encoding!/1), 0}}
              )
            ],
            &is_nil/1
          )
      }

      {:ok, new_ack}
    end
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end
end
