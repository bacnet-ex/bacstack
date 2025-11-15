defmodule BACnet.Protocol.APDU.ComplexACK do
  @moduledoc """
  Complex ACK APDUs are used to convey the information contained
  in a positive service response primitive that contains information
  in addition to the fact that the service request
  was successfully carried out.

  This module has functions for encoding Complex ACK APDUs.
  Decoding is handled by `BACnet.Protocol.APDU`.

  This module implements the `BACnet.Stack.EncoderProtocol`.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  @typedoc """
  Represents the Application Data Unit (APDU) Complex ACK.

  To allow forward compatibility, service is allowed to be an integer.
  """
  @type t :: %__MODULE__{
          invoke_id: 0..255,
          sequence_number: 0..255 | nil,
          proposed_window_size: 1..127 | nil,
          service: Constants.confirmed_service_choice() | non_neg_integer(),
          payload: ApplicationTags.encoding_list()
        }

  @fields [
    :invoke_id,
    :sequence_number,
    :proposed_window_size,
    :service,
    :payload
  ]
  @enforce_keys @fields
  defstruct @fields

  @encoder_module Module.concat([BACnet.Stack.EncoderProtocol, __MODULE__])

  @doc """
  Encodes the Complex ACK APDU into binary data.

  Note that segmentation is ignored.
  """
  @spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
  def encode(%__MODULE__{} = apdu) do
    res = @encoder_module.encode(apdu)
    {:ok, res}
  rescue
    e -> {:error, e}
  end

  defimpl BACnet.Stack.EncoderProtocol do
    alias BACnet.Protocol.ApplicationTags
    alias BACnet.Protocol.Constants

    require Constants

    @doc """
    Whether the struct expects a reply (i.e. Confirmed Service Request).

    This is useful for NPCI calculation.
    """
    @spec expects_reply(@for.t()) :: boolean()
    def expects_reply(%@for{} = _apdu), do: false

    @doc """
    Whether the struct is a request.
    """
    @spec is_request(@for.t()) :: boolean()
    def is_request(%@for{} = _apdu), do: false

    @doc """
    Whether the struct is a response.
    """
    @spec is_response(@for.t()) :: boolean()
    def is_response(%@for{} = _apdu), do: true

    @spec encode(@for.t()) :: iodata()
    def encode(%@for{} = apdu) do
      {header, data} = encode_struct(apdu)
      <<header::binary, data::binary>>
    end

    @spec supports_segmentation(@for.t()) :: boolean()
    def supports_segmentation(_apdu), do: true

    @spec encode_segmented(@for.t(), integer()) :: [binary()]
    def encode_segmented(%@for{proposed_window_size: window_size} = apdu, apdu_size)
        when window_size != nil do
      case encode_struct(apdu) do
        {header, ""} ->
          [<<header::binary>>]

        {header, data} ->
          # Rework header, add Segmentation and More Follows bit as set
          <<pdu_type::size(4), _segmented::size(2), rest1::bitstring-size(10), service::size(8)>> =
            header

          seg_header = <<pdu_type::size(4), 1::size(1), 1::size(1), rest1::bitstring>>
          last_header = <<pdu_type::size(4), 1::size(1), 0::size(1), rest1::bitstring>>

          0..255//1
          |> Enum.reduce_while({data, []}, fn
            _index, {<<>>, segments} ->
              {:halt, segments}

            index, {data, segments} ->
              start = binary_part(data, 0, min(byte_size(data), apdu_size))

              rest =
                case max(0, byte_size(data) - byte_size(start)) do
                  0 -> ""
                  len -> binary_part(data, apdu_size, len)
                end

              this_header =
                if byte_size(rest) == 0 do
                  last_header
                else
                  seg_header
                end

              # Inject Sequence Number (index) and Window Size into the APCI
              {:cont,
               {rest,
                [
                  <<this_header::bitstring, index::size(8), window_size::size(8),
                    service::size(8), start::binary>>
                  | segments
                ]}}
          end)
          |> Enum.reverse()
      end
    end

    @spec encode_struct(@for.t()) ::
            {header :: binary(), data :: binary()}
    defp encode_struct(
           %@for{
             invoke_id: invoke_id
           } = apdu
         ) do
      unless invoke_id >= 0 and invoke_id <= 255 do
        raise ArgumentError,
              "Invoke ID must be between 0 and 255 inclusive, got: #{inspect(invoke_id)}"
      end

      service =
        if is_atom(apdu.service) do
          Constants.by_name!(:confirmed_service_choice, apdu.service)
        else
          apdu.service
        end

      payload = encode_payload(apdu.payload)

      header =
        <<Constants.macro_by_name(:pdu_type, :complex_ack)::size(4), 0::size(4),
          invoke_id::size(8), service::size(8)>>

      {header, payload}
    end

    @spec encode_payload(term()) :: binary()
    defp encode_payload(payload) when is_list(payload) do
      payload
      |> Enum.reduce([], fn param, acc ->
        case ApplicationTags.encode(param) do
          {:ok, bin} ->
            [bin | acc]

          {:error, err} ->
            raise "Unable to encode service ack in complex ack encode, error: #{inspect(err)}"
        end
      end)
      |> Enum.reverse()
      |> IO.iodata_to_binary()
    end
  end
end
