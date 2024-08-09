defmodule BACnet.Protocol.NPCI do
  @moduledoc """
  Network Protocol Control Information (NPCI) are used to determine
  priority, whether reply is expected, for who by who this frame is
  and what kind of BACnet Data Unit this is.

  BACnet Data Units can be divided into Application and Network Service.
  Where Application frames are called APDU and Network Service frames are
  called NSDU. Network Service frames are mostly used by and for BACnet routers.
  """

  # TODO: Docs

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NpciTarget

  require Constants

  @typedoc """
  Represents Network Protocol Control Information (NPCI).
  """
  @type t :: %__MODULE__{
          priority: Constants.npdu_control_priority(),
          expects_reply: boolean(),
          destination: NpciTarget.t() | nil,
          source: NpciTarget.t() | nil,
          hopcount: non_neg_integer() | nil,
          is_network_message: boolean()
        }

  @fields [
    :priority,
    :expects_reply,
    :destination,
    :source,
    :hopcount,
    :is_network_message
  ]
  @enforce_keys @fields
  defstruct @fields

  @npci_version 0x01

  @doc """
  Get the NPCI version.
  """
  @spec get_version() :: non_neg_integer()
  def get_version(), do: @npci_version

  @doc """
  Creates a new NPCI struct with the given fields.

  The following default values are applied:
  ```ex
  priority: :normal,
  expects_reply: false,
  destination: nil,
  source: nil,
  hopcount: nil,
  is_network_message: false
  ```
  """
  @spec new(Keyword.t()) :: t()
  def new(fields) when is_list(fields) do
    Enum.reduce(
      fields,
      %__MODULE__{
        priority: :normal,
        expects_reply: false,
        destination: nil,
        source: nil,
        hopcount: nil,
        is_network_message: false
      },
      fn
        {:priority, value}, acc
        when value in Constants.macro_list_names(:npdu_control_priority) ->
          %{acc | priority: value}

        {:expects_reply, value}, acc when is_boolean(value) ->
          %{acc | expects_reply: value}

        {:destination, value}, acc
        when is_nil(value) or (is_struct(value, NpciTarget) and value.net in 1..65_535) ->
          %{acc | destination: value}

        {:source, value}, acc
        when is_nil(value) or (is_struct(value, NpciTarget) and value.net in 1..65_534) ->
          %{acc | source: value}

        {:hopcount, value}, acc when is_nil(value) or value in 1..255 ->
          %{acc | hopcount: value}

        {:is_network_message, value}, acc when is_boolean(value) ->
          %{acc | is_network_message: value}

        {field, value}, _acc when field in @fields ->
          raise ArgumentError, "Invalid value for field #{field}, got: #{inspect(value)}"

        term, _acc ->
          raise ArgumentError, "Unknown or invalid term, got: #{inspect(term)}"
      end
    )
  end

  @doc """
  Creates a NPCI iodata from the NPCI struct.

  If `destination` is not nil, but `net` is nil, `net` will default to `1`.
  """
  @spec encode(t(), Keyword.t()) :: iodata()
  def encode(%__MODULE__{} = npci, _opts \\ []) do
    priority = Constants.by_name!(:npdu_control_priority, npci.priority)

    {destination_specifier, destination} =
      case npci.destination do
        %NpciTarget{} = target ->
          npci_target(npci, target)

        nil ->
          {0, <<>>}

        term ->
          raise ArgumentError,
                "Invalid destination, expected nil or NpciTarget, got: #{inspect(term)}"
      end

    {source_specifier, source} =
      case npci.source do
        %NpciTarget{net: 65_535} ->
          raise ArgumentError, "Invalid source, net 65535 is not allowed"

        %NpciTarget{address: nil} ->
          raise ArgumentError, "Invalid source, address nil is not allowed"

        %NpciTarget{} = target ->
          npci_target(npci, target)

        nil ->
          {0, <<>>}

        term ->
          raise ArgumentError, "Invalid source, expected nil or NpciTarget, got: #{inspect(term)}"
      end

    hopcount =
      if destination_specifier == 1 do
        hop = if is_integer(npci.hopcount), do: min(max(npci.hopcount, 1), 255), else: 255
        <<hop::size(8)>>
      else
        <<>>
      end

    # Hint: res. = reserved
    # npci = apdu_0_or_npdu_1, res., destination_specifier, res., source_specifier, expects_reply, priority_two_bits
    npci =
      <<@npci_version::size(8), intify(npci.is_network_message)::size(1), 0::size(1),
        destination_specifier::size(1), 0::size(1), source_specifier::size(1),
        intify(npci.expects_reply)::size(1), priority::size(2)>>

    [
      npci,
      destination,
      source,
      hopcount
    ]
  end

  @spec intify(boolean()) :: 0..1
  defp intify(true), do: 1
  defp intify(false), do: 0

  @spec npci_target(t(), NpciTarget.t()) :: {0..1, binary()}
  defp npci_target(%__MODULE__{} = _npci, %NpciTarget{} = target) do
    if target.net == 0 or target.net == nil do
      raise ArgumentError, "Invalid net, must be in the range of 1..65535"
    end

    {len, addr_bin} =
      case target.address do
        nil ->
          {0, <<>>}

        # {ipaddr, port}
        # when is_tuple(ipaddr) and tuple_size(ipaddr) == 4 and port in 1..65_535 ->
        #   addr =
        #     ipaddr
        #     |> Tuple.to_list()
        #     |> List.to_string()
        #
        #   finaddr = <<addr::binary, port::size(16)>>
        #
        #   {byte_size(finaddr), finaddr}
        #
        # netaddr when is_tuple(netaddr) when tuple_size(netaddr) in 1..6 ->
        #   addr =
        #     netaddr
        #     |> Tuple.to_list()
        #     |> List.to_string()
        #
        #   {byte_size(addr), addr}
        #
        # netaddr when netaddr in 0..255 ->
        #   {1, <<netaddr::size(8)>>}

        netaddr when is_integer(netaddr) and netaddr >= 0 and netaddr <= 72_057_594_037_927_935 ->
          int_length = div(byte_size(Integer.to_string(netaddr, 2)) + 7, 8)
          bin = <<netaddr::integer-size(int_length)-unit(8)>>
          {int_length, bin}

        term ->
          raise ArgumentError,
                "Invalid destination address, expected nil or " <>
                  "a positive integer with max. 48 bits set, " <>
                  "got: #{inspect(term)}"
      end

    net = target.net || 1
    addr = <<net::size(16), len::size(8), addr_bin::binary>>

    {1, addr}
  end
end
