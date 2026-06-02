defmodule BACnet.Protocol.APDU.Reject do
  @moduledoc """
  Reject APDUs are sent when a confirmed service request cannot even be
  *interpreted* because of a protocol or syntactical error.

  ### APDU Description (ASHRAE 135)

  > The BACnet-Reject-PDU is used to reject a received confirmed service request
  > based on syntactical flaws or other protocol errors that prevent the PDU from being interpreted
  > or the requested service from being provided. Only confirmed request PDUs may be rejected.
  > A Reject APDU shall be sent only before the execution of the service. (Clause 18.8)

  Per ASHRAE 135, a Reject must only be generated **before** the service is
  executed. If the service started running and then failed, an Error APDU
  (or possibly Abort) is the correct reply.

  Common reject reasons (see `t:BACnet.Protocol.Constants.reject_reason/0` and Clause 18.8 "Reject Reason"):

  - `:other`, `:buffer_overflow`
  - `:inconsistent_parameters`, `:invalid_tag`, `:missing_required_parameter`
  - `:invalid_apdu_in_this_state`

  This module implements the `BACnet.Stack.EncoderProtocol`.

  Decoding is performed by `BACnet.Protocol.APDU.decode/1` (and `BACnet.Protocol.APDU.decode_reject/1`).

  ### Examples

      iex> reject = %Reject{invoke_id: 9, reason: :buffer_overflow}
      iex> Reject.encode(reject)
      {:ok, <<96, 9, 1>>}

  Decoding:

      iex> raw = <<0x60, 0x09, 0x01>>
      iex> {:ok, %Reject{invoke_id: 9, reason: :buffer_overflow}} = BACnet.Protocol.APDU.decode(raw)
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

    @spec encode_to_segmented(@for.t(), iodata(), integer()) :: [iodata()]
    def encode_to_segmented(%@for{} = _t, _data, _apdu_size) do
      raise "Illegal function call, APDU can not be segmented"
    end
  end
end
