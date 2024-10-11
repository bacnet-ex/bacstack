defmodule BACnet.Protocol.APDU.Reject do
  @moduledoc """
  Reject APDUs are used to reject a received confirmed service request
  based on syntactical flaws or other protocol errors that prevent
  the PDU from being interpreted or the requested service from being provided.
  Only confirmed request PDUs may be rejected (see ASHRAE 135 Clause 18.8).
  A Reject APDU shall be sent only before the execution of the service.

  This module has functions for encoding Reject APDUs.
  Decoding is handled by `BACnet.Protocol.APDU`.

  This module implements the `BACnet.Stack.EncoderProtocol`.
  """

  @typedoc """
  Represents the Application Data Unit (APDU) Reject.

  To allow forward compatibility, reason is allowed to be an integer.
  """
  @type t :: %__MODULE__{
          invoke_id: 0..255,
          reason: BACnet.Protocol.Constants.reject_reason() | non_neg_integer()
        }

  @fields [
    :invoke_id,
    :reason
  ]
  @enforce_keys @fields
  defstruct @fields

  @encoder_module Module.concat([BACnet.Stack.EncoderProtocol, __MODULE__])

  @doc """
  Encodes the Reject APDU into binary data.
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
          Constants.by_name!(:reject_reason, apdu.reason)
        else
          apdu.reason
        end

      <<Constants.macro_by_name(:pdu_type, :reject)::size(4), 0::size(4), invoke_id::size(8),
        reason::size(8)>>
    end

    @spec supports_segmentation(@for.t()) :: boolean()
    def supports_segmentation(_apdu), do: false

    @spec encode_segmented(@for.t(), integer()) :: [binary()]
    def encode_segmented(%@for{} = _t, _apdu_size) do
      raise "Illegal function call, APDU can not be segmented"
    end
  end
end
