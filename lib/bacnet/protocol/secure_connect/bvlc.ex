defmodule BACnet.Protocol.SecureConnect.BVLC do
  @moduledoc """
  Encodes and decodes BACnet Secure Connect Virtual Link Control messages
  defined in Annex AB. Each WebSocket binary message carries one BVLC message.

  The flags determine which addresses and option lists precede the payload.
  Link-control messages use the connection peer as the implicit destination.
  Forwardable messages can carry an explicit destination and receive an
  originating VMAC as they pass through a hub.

  The codec retains unknown header option types during forwarding. A receiving
  endpoint checks whether it understands the destination options. A decoding
  error can carry a partial header so the endpoint can apply the Annex AB
  rules for returning a BVLC-Result NAK.
  """

  import Bitwise

  alias BACnet.Protocol.Constants

  @functions ~w(result npdu address_resolution address_resolution_ack advertisement
                advertisement_solicitation connect_request connect_accept disconnect_request
                disconnect_ack heartbeat_request heartbeat_ack proprietary)a
  @codes Map.new(Enum.with_index(@functions))
  @responses [:result, :address_resolution_ack, :connect_accept, :disconnect_ack, :heartbeat_ack]
  @link_functions Enum.slice(@functions, 6..11)
  @broadcast <<255, 255, 255, 255, 255, 255>>
  @max_bvlc 65_535
  @max_npdu 1497

  @typedoc """
  A symbolic Annex AB BVLC function name. Decoded headers for unknown
  functions can carry the numeric wire code instead.
  """
  @type function_name ::
          :result
          | :npdu
          | :address_resolution
          | :address_resolution_ack
          | :advertisement
          | :advertisement_solicitation
          | :connect_request
          | :connect_accept
          | :disconnect_request
          | :disconnect_ack
          | :heartbeat_request
          | :heartbeat_ack
          | :proprietary

  @typedoc """
  A header option with its numeric type, Must Understand flag, and optional
  bytes. A `nil` value means the header data field is absent.
  """
  @type option :: {1..31, boolean(), binary() | nil}

  @typedoc """
  Identity and receive limits advertised by a connection peer.
  """
  @type peer :: %{
          vmac: vmac(),
          uuid: <<_::128>>,
          max_bvlc: 0..65_535,
          max_npdu: 0..65_535
        }

  @typedoc """
  A six-octet virtual MAC address. Use `valid_vmac?/1` to check a unicast
  identity and `broadcast/0` for the reserved broadcast value.
  """
  @type vmac :: <<_::48>>

  @typedoc """
  An SC BVLC message before serialization or after decoding. Set an address
  to `nil` when the connection peer supplies it. Use empty lists for absent
  options and an empty binary for a message without a payload.
  """
  @type t :: %__MODULE__{
          function: function_name() | byte(),
          id: 0..65_535,
          source: vmac() | nil,
          destination: vmac() | nil,
          destination_options: [option()],
          data_options: [option()],
          payload: binary()
        }

  @fields [:function, :id, :source, :destination, :destination_options, :data_options, :payload]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Returns the numeric BACnet error code used in a BVLC Result.
  """
  @spec error_code(Constants.error_code()) :: non_neg_integer()
  def error_code(name), do: Constants.by_name!(:error_code, name)

  @doc """
  Returns the reserved all-ones VMAC used for local broadcasts.
  """
  @spec broadcast() :: vmac()
  def broadcast(), do: @broadcast

  @doc """
  Returns the maximum BVLC message size accepted by the codec, in octets.
  """
  @spec max_bvlc() :: non_neg_integer()
  def max_bvlc(), do: @max_bvlc

  @doc """
  Returns the maximum NPDU size advertised by the BACnet/SC implementation.
  """
  @spec max_npdu() :: non_neg_integer()
  def max_npdu(), do: @max_npdu

  @doc """
  Checks that the value is a six-octet VMAC other than the reserved all-zero
  and all-ones addresses.
  """
  @spec valid_vmac?(term()) :: boolean()
  def valid_vmac?(<<_address::size(48)>> = address),
    do: address not in [<<0::size(48)>>, @broadcast]

  def valid_vmac?(_address), do: false

  @doc """
  Generates a Random-48 VMAC with the low nibble of the first octet set to two.
  """
  @spec random_vmac() :: vmac()
  def random_vmac() do
    <<high::size(4), _low::size(4), rest::size(40)>> = :crypto.strong_rand_bytes(6)
    <<high::size(4), 2::size(4), rest::size(40)>>
  end

  @doc """
  Returns the wire code for a known BVLC function or an already numeric code.
  """
  @spec code(function_name() | byte()) :: byte()
  def code(function) when is_integer(function), do: function
  def code(function), do: Map.fetch!(@codes, function)

  @doc """
  Checks whether a function belongs to the connection lifecycle, including
  connection establishment, disconnection, and heartbeats.
  """
  @spec link_function?(function_name() | byte()) :: boolean()
  def link_function?(function), do: function in @link_functions

  @doc """
  Builds the Connect-Request or Connect-Accept payload from a VMAC, device UUID,
  and the advertised length limits.
  """
  @spec identity(vmac(), <<_::128>>) :: binary()
  def identity(vmac, uuid),
    do: <<vmac::binary-6, uuid::binary-16, @max_bvlc::size(16), @max_npdu::size(16)>>

  @doc """
  Extracts peer identity and size limits from a validated connection payload.
  """
  @spec peer(<<_::208>>) :: peer()
  def peer(<<vmac::binary-6, uuid::binary-16, bvlc::size(16), npdu::size(16)>>) do
    %{vmac: vmac, uuid: uuid, max_bvlc: bvlc, max_npdu: npdu}
  end

  @doc """
  Builds a communication-class BVLC-Result NAK for the request. Returns
  `nil` for broadcasts and responses, which cannot receive a result.
  """
  @spec nak(t(), 0..65_535, byte()) :: t() | nil
  def nak(%__MODULE__{} = message, error, marker \\ 0) do
    if message.destination != @broadcast and message.function not in @responses do
      response(
        message,
        :result,
        <<code(message.function), 1, marker,
          Constants.by_name!(:error_class, :communication)::size(16), error::size(16)>>
      )
    end
  end

  @doc """
  Builds a response that uses the request message ID and addresses its
  originating VMAC when that address was present.
  """
  @spec response(t(), function_name(), binary()) :: t()
  def response(%__MODULE__{} = request, function, payload \\ <<>>) do
    %__MODULE__{
      function: function,
      id: request.id,
      source: nil,
      destination: request.source,
      destination_options: [],
      data_options: [],
      payload: payload
    }
  end

  @doc """
  Serializes the fixed header, selected addresses, option lists, and payload
  as a binary WebSocket message.
  """
  @spec encode(t()) :: binary()
  def encode(%__MODULE__{} = message) do
    flags =
      flag(message.source, 8) ||| flag(message.destination, 4) |||
        flag(message.destination_options != [], 2) ||| flag(message.data_options != [], 1)

    IO.iodata_to_binary([
      <<code(message.function), flags, message.id::size(16)>>,
      message.source || <<>>,
      message.destination || <<>>,
      encode_options(message.destination_options),
      encode_options(message.data_options),
      message.payload
    ])
  end

  @spec flag(term(), non_neg_integer()) :: non_neg_integer()
  defp flag(value, bit), do: if(value, do: bit, else: 0)
  @spec encode_options([option()]) :: iodata()
  defp encode_options([]), do: []

  defp encode_options([{type, must_understand, data} | rest])
       when type in 1..31 and is_boolean(must_understand) do
    marker = flag(rest != [], 128) ||| flag(must_understand, 64) ||| flag(data, 32) ||| type
    field = if is_nil(data), do: <<>>, else: <<byte_size(data)::size(16), data::binary>>
    [<<marker>>, field | encode_options(rest)]
  end

  @doc """
  Parses and validates a complete BVLC message. An error includes the BACnet
  communication error code and, when the addressing fields were readable,
  the header needed to determine whether to send a NAK.
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, 0..65_535, t() | nil}
  def decode(<<function, flags, id::size(16), body::binary>> = binary)
      when byte_size(binary) <= @max_bvlc do
    with {:ok, source, rest} <- address(body, flags &&& 8),
         {:ok, destination, rest} <- address(rest, flags &&& 4) do
      message = %__MODULE__{
        function: Enum.at(@functions, function, function),
        id: id,
        source: source,
        destination: destination,
        destination_options: [],
        data_options: [],
        payload: <<>>
      }

      decode_body(message, flags, rest)
    else
      _error -> {:error, error_code(:message_incomplete), nil}
    end
  end

  def decode(_binary), do: {:error, error_code(:message_incomplete), nil}

  @spec decode_body(t(), byte(), binary()) :: {:ok, t()} | {:error, 0..65_535, t()}
  defp decode_body(message, flags, rest) do
    with true <- (flags &&& 240) == 0 or {:error, error_code(:parameter_out_of_range)},
         {:ok, destination_options, rest} <- options(rest, flags &&& 2),
         {:ok, data_options, payload} <- options(rest, flags &&& 1),
         decoded = %{
           message
           | destination_options: destination_options,
             data_options: data_options,
             payload: payload
         },
         :ok <- validate(decoded) do
      {:ok, decoded}
    else
      {:error, reason} -> {:error, reason, message}
    end
  end

  @spec address(binary(), non_neg_integer()) :: {:ok, vmac() | nil, binary()} | :error
  defp address(body, 0), do: {:ok, nil, body}
  defp address(<<address::binary-6, rest::binary>>, _flag), do: {:ok, address, rest}
  defp address(_body, _flag), do: :error

  @spec options(binary(), non_neg_integer()) :: {:ok, [option()], binary()} | {:error, 0..65_535}
  defp options(rest, 0), do: {:ok, [], rest}
  defp options(rest, _flag), do: options_list(rest, [])

  @spec options_list(binary(), [option()]) :: {:ok, [option()], binary()} | {:error, 0..65_535}
  defp options_list(
         <<more::size(1), must::size(1), has_data::size(1), type::size(5), rest::binary>>,
         acc
       )
       when type > 0 do
    with {:ok, data, rest} <- option_data(rest, has_data) do
      acc = [{type, must == 1, data} | acc]
      if more == 1, do: options_list(rest, acc), else: {:ok, Enum.reverse(acc), rest}
    end
  end

  defp options_list(_rest, _acc), do: {:error, error_code(:header_encoding_error)}

  @spec option_data(binary(), 0 | 1) ::
          {:ok, binary() | nil, binary()} | {:error, non_neg_integer()}
  defp option_data(rest, 0), do: {:ok, nil, rest}

  defp option_data(<<length::size(16), data::binary-size(length), rest::binary>>, 1),
    do: {:ok, data, rest}

  defp option_data(_rest, 1), do: {:error, error_code(:message_incomplete)}

  @spec validate(t()) :: :ok | {:error, 0..65_535}
  defp validate(%__MODULE__{function: function} = message) do
    cond do
      is_integer(function) ->
        {:error, error_code(:bvlc_function_unknown)}

      message.source && !valid_vmac?(message.source) ->
        {:error, error_code(:parameter_out_of_range)}

      message.destination == <<0::size(48)>> ->
        {:error, error_code(:parameter_out_of_range)}

      function in @link_functions and (message.source || message.destination) ->
        {:error, error_code(:parameter_out_of_range)}

      message.destination == @broadcast and function != :npdu and function != :proprietary ->
        {:error, error_code(:inconsistent_parameters)}

      message.data_options != [] and function != :npdu ->
        {:error, error_code(:parameter_out_of_range)}

      true ->
        validate_payload(function, message.payload)
    end
  end

  @spec validate_payload(function_name(), binary()) :: :ok | {:error, 0..65_535}
  defp validate_payload(function, <<>>)
       when function in [
              :npdu,
              :result,
              :connect_request,
              :connect_accept,
              :advertisement,
              :proprietary
            ],
       do: {:error, error_code(:payload_expected)}

  defp validate_payload(function, payload) when function in [:connect_request, :connect_accept] do
    case payload do
      <<vmac::binary-6, uuid::binary-16, bvlc::size(16), npdu::size(16)>> ->
        if valid_vmac?(vmac) and uuid != <<0::size(128)>> and bvlc >= 30 and npdu >= 2,
          do: :ok,
          else: {:error, error_code(:parameter_out_of_range)}

      _other ->
        {:error, error_code(:message_incomplete)}
    end
  end

  defp validate_payload(:address_resolution_ack, payload) do
    if String.valid?(payload), do: :ok, else: {:error, error_code(:parameter_out_of_range)}
  end

  defp validate_payload(:proprietary, payload) do
    if byte_size(payload) >= 3, do: :ok, else: {:error, error_code(:message_incomplete)}
  end

  defp validate_payload(:result, <<_function, 0>>), do: :ok

  defp validate_payload(
         :result,
         <<_function, 1, _marker, _class::size(16), _code::size(16), detail::binary>>
       ) do
    if String.valid?(detail), do: :ok, else: {:error, error_code(:parameter_out_of_range)}
  end

  defp validate_payload(:result, _payload), do: {:error, error_code(:message_incomplete)}

  defp validate_payload(:advertisement, <<hub, direct, _bvlc::size(16), _npdu::size(16)>>)
       when hub in 0..2 and direct in 0..1,
       do: :ok

  defp validate_payload(:advertisement, _payload),
    do: {:error, error_code(:parameter_out_of_range)}

  defp validate_payload(function, payload)
       when function in [
              :disconnect_request,
              :disconnect_ack,
              :heartbeat_request,
              :heartbeat_ack,
              :address_resolution,
              :advertisement_solicitation
            ] do
    if payload == <<>>, do: :ok, else: {:error, error_code(:unexpected_data)}
  end

  defp validate_payload(_function, _payload), do: :ok

  @doc """
  Returns the marker of the first destination option that requires understanding
  and is unsupported, or `nil` when the destination options may be ignored.
  """
  @spec unsupported_option(t()) :: byte() | nil
  def unsupported_option(%__MODULE__{destination_options: options}) do
    Enum.find_value(Enum.with_index(options), fn
      {{type, true, data}, index} ->
        type ||| 64 ||| flag(data, 32) ||| flag(index < length(options) - 1, 128)

      _option ->
        nil
    end)
  end
end
