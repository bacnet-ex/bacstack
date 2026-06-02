defmodule BACnet.Protocol.APDU.Error do
  @moduledoc """
  Error APDUs report that a confirmed service request could not be completed.

  ### APDU Description (ASHRAE 135)

  > The BACnet-Error-PDU is used to convey the information contained in a service
  > response primitive that indicates the reason why a previous confirmed service request
  > failed, either in its entirety or only partially. (Clause 21)

  They are the normal way a server signals a semantic failure (as opposed to
  a protocol problem, which would use Reject or Abort).

  The `class` / `code` pair gives a standardized reason
  (see `t:BACnet.Protocol.Constants.error_class/0` and `t:BACnet.Protocol.Constants.error_code/0`,
  and Clause 18). Many services also return additional error information in the `payload`
  field.

  This module implements the `BACnet.Stack.EncoderProtocol`.

  Decoding is performed by `BACnet.Protocol.APDU.decode/1` (and `BACnet.Protocol.APDU.decode_error/1`).

  ### Examples

      iex> err = %Error{
      ...>   invoke_id: 5,
      ...>   service: :write_property,
      ...>   class: :property,
      ...>   code: :write_access_denied,
      ...>   payload: []
      ...> }
      iex> Error.encode(err)
      {:ok, <<80, 5, 15, 145, 2, 145, 40>>}

  Decoding an Error APDU:

      iex> raw = <<0x50, 0x05, 0x0F, 0x91, 0x02, 0x91, 0x28>>
      iex> BACnet.Protocol.APDU.decode(raw)
      {:ok, %Error{invoke_id: 5, service: :write_property, class: :property, code: :write_access_denied, payload: []}}
  """

  alias BACnet.Protocol.Constants

  @typedoc """
  Represents the Application Data Unit (APDU) Error.

  To allow forward compatibility, some fields are allowed to be an integer.
  """
  @type t :: %__MODULE__{
          invoke_id: 0..255,
          service: Constants.confirmed_service_choice() | non_neg_integer(),
          class: Constants.error_class() | non_neg_integer(),
          code: Constants.error_code() | non_neg_integer(),
          payload: BACnet.Protocol.ApplicationTags.encoding_list()
        }

  @fields [
    :invoke_id,
    :service,
    :class,
    :code,
    :payload
  ]
  @enforce_keys @fields
  defstruct @fields

  @encoder_module Module.concat([BACnet.Stack.EncoderProtocol, __MODULE__])

  @doc """
  Encodes the Error APDU into binary data.
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

      enum_class =
        if is_atom(apdu.class) do
          Constants.by_name!(:error_class, apdu.class)
        else
          apdu.class
        end

      enum_code =
        if is_atom(apdu.code) do
          Constants.by_name!(:error_code, apdu.code)
        else
          apdu.code
        end

      {class, code} =
        if apdu.payload == [] do
          {:ok, class} = ApplicationTags.encode({:enumerated, enum_class})
          {:ok, code} = ApplicationTags.encode({:enumerated, enum_code})

          {class, code}
        else
          {:ok, binary} =
            ApplicationTags.encode(
              {:constructed,
               {0,
                [
                  enumerated: enum_class,
                  enumerated: enum_code
                ], 0}}
            )

          {binary, <<>>}
        end

      payload =
        Enum.reduce(apdu.payload, <<>>, fn tag, acc ->
          case ApplicationTags.encode(tag) do
            {:ok, bytes} ->
              <<acc::binary, bytes::binary>>

            {:error, error} ->
              raise "Unable to encode payload in error encode, error: #{inspect(error)}"
          end
        end)

      <<Constants.macro_by_name(:pdu_type, :error)::size(4), 0::size(4), invoke_id::size(8),
        service::size(8), class::binary, code::binary, payload::binary>>
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
