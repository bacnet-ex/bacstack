defmodule BACnet.Protocol.BroadcastDistributionTableEntry do
  @moduledoc """
  A Broadcast Distribution Table Entry describes one peer BBMD (BACnet Broadcast
  Management Device) or peer network that participates in the distribution of
  BACnet broadcasts across an IP network. The table as a whole defines the
  mesh of BBMDs that collectively provide broadcast emulation for an entire site
  and includes entries to local networks the BBMD should broadcast to.

  Each entry contains the IP address and UDP port of the peer together with
  a subnet mask.
  The Broadcast Distribution Table is configured either locally or via the
  Write Broadcast Distribution Table service.

  ## BACnet Specification References

  - Annex J.4.3.2 defines the exact format and the meaning of the broadcast
    distribution mask (the 4-octet field after the 6-octet B/IP address).
  - J.4.3 and J.4.5 describe how a BBMD uses the BDT to forward broadcasts
    (two-hop unicast vs. one-hop directed broadcast) and the rule that every
    BBMD must have an entry for itself.
  - J.7.8 covers NAT: when a NAT router sits between BBMDs the BDT entries must
    contain the *global* IP address of the far-end NAT router.

  ## The Broadcast Distribution Mask (J.4.3.2)

  The mask controls *how* the sending BBMD will reach the remote subnet:

  - All-1s mask (`255.255.255.255`) → two-hop distribution: the message is sent
    as a unicast UDP datagram directly to the peer BBMD's B/IP address. The
    peer BBMD is then responsible for the final local broadcast on its subnet.
    This method always works (no special router configuration required).
  - Subnet mask of the destination (e.g. `255.255.255.0` for a /24) → one-hop
    distribution: the sending BBMD emits a directed broadcast (e.g.
    `192.168.1.255`) that the IP router is expected to forward. Many routers
    block directed broadcasts by default for security reasons.

  All BDT entries that refer to the *same* remote IP subnet must carry identical
  masks (normative requirement). The library does not enforce this at runtime
  (see the TODO comment in the source).

  ## Wire Format

  Each BDT entry on the wire is exactly 10 octets: 6-octet B/IP address (IP +
  port) followed by the 4-octet mask. This is the format both for the
  Write-Broadcast-Distribution-Table payload and for the Read-BDT-Ack response.

  ## Construction & Examples

      iex> alias BACnet.Protocol.BroadcastDistributionTableEntry
      iex> e = %BroadcastDistributionTableEntry{
      ...>   ip: {192, 168, 0, 1},
      ...>   port: 0xBAC0,
      ...>   mask: {255, 255, 255, 0}
      ...> }
      iex> BroadcastDistributionTableEntry.encode(e)
      {:ok, <<192, 168, 0, 1, 186, 192, 255, 255, 255, 0>>}

  The port must be a valid 16-bit integer; the IP and mask fields must be
  4-tuples. Invalid data produces `{:error, :invalid_data}` from encode.

  ## See Also

  - `BACnet.Protocol` - central BVLL decoding that eventually yields BDT entries via BvlcFunction
  - `BACnet.Protocol.BvlcFunction` - the Write-BDT and Read-BDT-Ack messages that carry lists of these entries
  - `BACnet.Protocol.BvlcResult` - NAK that may be returned when a Write-BDT fails
  - `BACnet.Stack.BBMD` - the component that owns and uses the BDT (start option `:bdt`, readonly flag, distribution logic)
  """

  # TODO: Throw argument error in encode if not valid

  @typedoc """
  An entry in the Broadcast Distribution Table (BDT) used by BBMDs in BACnet/IP.

  The `mask` field determines one-hop (directed broadcast) vs. two-hop (unicast
  to peer BBMD) distribution per J.4.3.2. See the moduledoc for the exact rules
  and the requirement that masks for the same subnet must be identical across
  all BBMDs.
  """
  @type t :: %__MODULE__{
          ip: :inet.ip4_address(),
          port: :inet.port_number(),
          mask: :inet.ip4_address()
        }

  @fields [:ip, :port, :mask]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Decodes a Broadcast Distribution Table Entry from binary data.
  """
  @spec decode(binary()) :: {:ok, {t(), rest :: binary()}} | {:error, term()}
  def decode(data)

  def decode(
        <<ip_a, ip_b, ip_c, ip_d, port::size(16), mask_a, mask_b, mask_c, mask_d, rest::binary>>
      ) do
    bdt = %__MODULE__{
      ip: {ip_a, ip_b, ip_c, ip_d},
      port: port,
      mask: {mask_a, mask_b, mask_c, mask_d}
    }

    {:ok, {bdt, rest}}
  end

  def decode(data) when is_binary(data) do
    {:error, :invalid_data}
  end

  @doc """
  Encodes the Broadcast Distribution Table Entry to binary data.
  """
  @spec encode(t()) :: {:ok, binary()} | {:error, term()}
  def encode(entry)

  def encode(
        %__MODULE__{
          ip: {ip_a, ip_b, ip_c, ip_d},
          port: port,
          mask: {mask_a, mask_b, mask_c, mask_d}
        } = _entry
      )
      when is_integer(port) do
    {:ok, <<ip_a, ip_b, ip_c, ip_d, port::size(16), mask_a, mask_b, mask_c, mask_d>>}
  end

  def encode(%__MODULE__{} = _entry), do: {:error, :invalid_data}
end
