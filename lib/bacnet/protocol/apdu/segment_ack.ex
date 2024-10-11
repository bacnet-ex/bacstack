defmodule BACnet.Protocol.APDU.SegmentACK do
  @moduledoc """
  Segment ACK APDUs are used to acknowledge the receipt of one or more frames
  containing portions of a segmented message. It may also request the
  next segment or segments of the segmented message.

  This module has functions for encoding Segment ACK APDUs.
  Decoding is handled by `BACnet.Protocol.APDU`.

  This module implements the `BACnet.Stack.EncoderProtocol`.
  """

  @typedoc """
  Represents the Application Data Unit (APDU) Segment ACK.
  """
  @type t :: %__MODULE__{
          negative_ack: boolean(),
          sent_by_server: boolean(),
          invoke_id: 0..255,
          sequence_number: 0..255,
          actual_window_size: 1..127
        }

  @fields [
    :negative_ack,
    :sent_by_server,
    :invoke_id,
    :sequence_number,
    :actual_window_size
  ]
  @enforce_keys @fields
  defstruct @fields

  @encoder_module Module.concat([BACnet.Stack.EncoderProtocol, __MODULE__])

  @doc """
  Encodes the Segment ACK APDU into binary data.
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
    @spec is_request(@for.t()) :: boolean()
    def is_request(%@for{} = _apdu), do: false

    @doc """
    Whether the struct is a response.
    """
    @spec is_response(@for.t()) :: boolean()
    def is_response(%@for{} = _apdu), do: true

    @spec encode(@for.t()) :: iodata()
    def encode(
          %@for{
            invoke_id: invoke_id,
            sequence_number: sequence_number,
            actual_window_size: actual_window_size
          } = apdu
        ) do
      unless invoke_id >= 0 and invoke_id <= 255 do
        raise ArgumentError,
              "Invoke ID must be between 0 and 255 inclusive, got: #{inspect(invoke_id)}"
      end

      unless sequence_number >= 0 and sequence_number <= 255 do
        raise ArgumentError,
              "Sequence number must be between 0 and 255 inclusive, " <>
                "got: #{inspect(sequence_number)}"
      end

      unless actual_window_size >= 0 and actual_window_size <= 255 do
        raise ArgumentError,
              "Actual window size must be between 0 and 255 inclusive, " <>
                "got: #{inspect(actual_window_size)}"
      end

      <<Constants.macro_by_name(:pdu_type, :segment_ack)::size(4), 0::size(2),
        intify(apdu.negative_ack)::size(1), intify(apdu.sent_by_server)::size(1),
        invoke_id::size(8), sequence_number::size(8), actual_window_size::size(8)>>
    end

    @spec supports_segmentation(@for.t()) :: boolean()
    def supports_segmentation(_apdu), do: false

    @spec encode_segmented(@for.t(), integer()) :: [binary()]
    def encode_segmented(%@for{} = _t, _apdu_size) do
      raise "Illegal function call, APDU can not be segmented"
    end

    @spec intify(boolean()) :: 0..1
    defp intify(true), do: 1
    defp intify(false), do: 0
  end
end
