defmodule BACnet.Protocol.APDU.Abort do
  @moduledoc """
  Abort APDUs are used to terminate a transaction between two peers.

  This module has functions for encoding Abort APDUs.
  Decoding is handled by `BACnet.Protocol.APDU`.

  This module implements the `BACnet.Stack.EncoderProtocol`.
  """

  @typedoc """
  Represents the Application Data Unit (APDU) Abort.

  To allow forward compatibility, reason is allowed to be an integer.
  """
  @type t :: %__MODULE__{
          sent_by_server: boolean(),
          invoke_id: 0..255,
          reason: BACnet.Protocol.Constants.abort_reason() | non_neg_integer()
        }

  @fields [
    :sent_by_server,
    :invoke_id,
    :reason
  ]
  @enforce_keys @fields
  defstruct @fields

  @encoder_module Module.concat([BACnet.Stack.EncoderProtocol, __MODULE__])

  @doc """
  Encodes the Abort APDU into binary data.
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
            invoke_id: invoke_id
          } = apdu
        ) do
      unless invoke_id >= 0 and invoke_id <= 255 do
        raise ArgumentError,
              "Invoke ID must be between 0 and 255 inclusive, got: #{inspect(invoke_id)}"
      end

      reason =
        if is_atom(apdu.reason) do
          Constants.by_name!(:abort_reason, apdu.reason)
        else
          apdu.reason
        end

      <<Constants.macro_by_name(:pdu_type, :abort)::size(4), 0::size(3),
        intify(apdu.sent_by_server)::size(1), invoke_id::size(8), reason::size(8)>>
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
