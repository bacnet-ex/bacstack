defmodule BACnet.Protocol.NPCI do
  @moduledoc """
  Network Protocol Control Information (NPCI) is the header that precedes every
  BACnet Network Protocol Data Unit (NPDU). It carries the information that
  BACnet routers and receiving devices need to correctly forward or deliver the
  message.

  The NPCI indicates the version of the protocol, the ultimate source and
  destination networks (when the message crosses routers), whether a reply is
  expected, the priority of the message, and whether the data that follows is
  an Application Protocol Data Unit (APDU) or a Network Service Data Unit
  (NSDU). Network-layer messages (NSDUs) are used for router-to-router
  communication, router configuration, and certain network management functions.
  """

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

  Source and destination targets are validated as described in `encode/2`.
  Invalid fields raise `ArgumentError`.

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
          if value, do: validate_target!(value, :destination)
          %{acc | destination: value}

        {:source, value}, acc
        when is_nil(value) or (is_struct(value, NpciTarget) and value.net in 1..65_534) ->
          if value, do: validate_target!(value, :source)
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

  Present targets require an explicit network number: 1..65535 for destinations
  and 1..65534 for sources. Addresses are binaries of one to seven octets and are
  preserved exactly, including leading zeros. A destination address of `nil`
  denotes a broadcast - a present source must have a nonempty address.

  Invalid targets raise `ArgumentError`, including when the NPCI was built directly
  rather than through `new/1`.
  """
  @spec encode(t(), Keyword.t()) :: iodata()
  def encode(%__MODULE__{} = npci, _opts \\ []) do
    priority = Constants.by_name!(:npdu_control_priority, npci.priority)

    {destination_specifier, destination} =
      case npci.destination do
        %NpciTarget{} = target ->
          npci_target(target, :destination)

        nil ->
          {0, <<>>}

        term ->
          raise ArgumentError,
                "Invalid destination, expected nil or NpciTarget, got: #{inspect(term)}"
      end

    {source_specifier, source} =
      case npci.source do
        %NpciTarget{} = target ->
          npci_target(target, :source)

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

  @spec npci_target(NpciTarget.t(), :destination | :source) :: {1, binary()}
  defp npci_target(%NpciTarget{} = target, role) do
    validate_target!(target, role)
    address = target.address || <<>>
    {1, <<target.net::size(16), byte_size(address)::size(8), address::binary>>}
  end

  @spec validate_target!(NpciTarget.t(), :destination | :source) :: :ok
  defp validate_target!(%NpciTarget{} = target, role) do
    max_net = if role == :source, do: 65_534, else: 65_535

    if not (is_integer(target.net) and target.net in 1..max_net) do
      raise ArgumentError, "Invalid #{role} net, must be in the range of 1..#{max_net}"
    end

    case target.address do
      nil when role == :destination ->
        :ok

      address when is_binary(address) and byte_size(address) in 1..7 ->
        :ok

      address ->
        nil_hint = if role == :destination, do: " or nil", else: ""

        raise ArgumentError,
              "Invalid #{role} address, expected a binary of 1..7 octets#{nil_hint}, " <>
                "got: #{inspect(address)}"
    end
  end
end
