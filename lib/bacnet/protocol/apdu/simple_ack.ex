defmodule BACnet.Protocol.APDU.SimpleACK do
  @moduledoc """
  Simple ACK APDUs are the minimal successful reply to a confirmed service.

  ### APDU Description (ASHRAE 135)

  > The BACnet-SimpleACK-PDU is used to convey the information contained in a
  > positive service response primitive that contains no other information except that
  > the service request was successfully carried out. (Clause 21)

  They are sent when the requested operation completed successfully and the
  service definition does not require any data to be returned to the client.
  Typical examples:
  - `WriteProperty`
  - `SubscribeCOV`
  - `AcknowledgeAlarm`
  - `DeviceCommunicationControl`
  - `ReinitializeDevice`

  A SimpleACK only carries the original invoke ID and the service choice.
  It has no payload.

  This module implements the `BACnet.Stack.EncoderProtocol`.

  Decoding is performed by `BACnet.Protocol.APDU.decode/1` (and
  `BACnet.Protocol.APDU.decode_simple_ack/1`).

  ### Examples

      iex> ack = %SimpleACK{invoke_id: 70, service: :write_property}
      iex> SimpleACK.encode(ack)
      {:ok, <<32, 70, 15>>}

  Decoding a SimpleACK from the wire:

      iex> raw = <<0x20, 0x46, 0x0F>>
      iex> BACnet.Protocol.APDU.decode(raw)
      {:ok, %SimpleACK{invoke_id: 70, service: :write_property}}
  """

  alias BACnet.Protocol.Constants

  @typedoc """
  Represents the Application Data Unit (APDU) Simple ACK.

  To allow forward compatibility, service is allowed to be an integer.
  """
  @type t :: %__MODULE__{
          invoke_id: 0..255,
          service: Constants.confirmed_service_choice() | non_neg_integer()
        }

  @fields [
    :invoke_id,
    :service
  ]
  @enforce_keys @fields
  defstruct @fields

  @encoder_module Module.concat([BACnet.Stack.EncoderProtocol, __MODULE__])

  @doc """
  Encodes the Simple ACK APDU into binary data.
  """
  @spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
  def encode(%__MODULE__{} = apdu) do
    res = @encoder_module.encode(apdu)
    {:ok, res}
  rescue
    e -> {:error, e}
  end

  defimpl BACnet.Stack.EncoderProtocol do
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
    @spec request?(@for.t()) :: boolean()
    def request?(%@for{} = _apdu), do: false

    @doc """
    Whether the struct is a response.
    """
    @spec response?(@for.t()) :: boolean()
    def response?(%@for{} = _apdu), do: true

    @spec encode(@for.t()) :: iodata()
    def encode(
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

      <<Constants.macro_by_name(:pdu_type, :simple_ack)::size(4), 0::size(4), invoke_id::size(8),
        service::size(8)>>
    end

    @spec supports_segmentation(@for.t()) :: boolean()
    def supports_segmentation(_apdu), do: false

    @spec encode_segmented(@for.t(), integer()) :: [binary()]
    def encode_segmented(%@for{} = _t, _apdu_size) do
      raise "Illegal function call, APDU can not be segmented"
    end

    @spec encode_to_segmented(@for.t(), iodata(), integer()) :: [iodata()]
    def encode_to_segmented(%@for{} = _t, _data, _apdu_size) do
      raise "Illegal function call, APDU can not be segmented"
    end
  end
end
