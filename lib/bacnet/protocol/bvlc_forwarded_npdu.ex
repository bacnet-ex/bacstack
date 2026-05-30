defmodule BACnet.Protocol.BvlcForwardedNPDU do
  @moduledoc """
  Represents a Forwarded NPDU BVLC function (BVLC function 0x04) used in BACnet/IP
  to forward a message from a foreign device or across a BBMD (ASHRAE 135 Annex J).

  A `Forwarded-NPDU` always carries the original source B/IP address (IP + UDP
  port) so that the receiving device can reply directly to the true originator
  even though the message arrived via a BBMD. This is essential for Foreign
  Devices (which are not on the same subnet) and for broadcasts that have been
  relayed between multiple IP subnets.

  ## BACnet Specification References

  - Annex J.2.5 defines the purpose and format of the Forwarded-NPDU message.
  - J.4.5 and J.5.2 describe exactly when a BBMD emits Forwarded-NPDU messages
    (on receipt of Original-Broadcast-NPDU or Distribute-Broadcast-To-Network,
    and to every entry in its FDT).
  - J.7.8 adds NAT considerations: when a NAT router is in the path the
    "originating" address in the Forwarded-NPDU must be the global address of
    the NAT router so replies can be routed back.

  ## Wire Format (J.2.5.1)

  The payload (after the 4-octet BVLL header) is exactly 6 octets of B/IP address
  (4 octets IPv4 + 2 octets port, big-endian) followed by the original BACnet
  NPDU. The `decode/1` function returns the 6-octet prefix as this struct and the
  remainder (the NPDU) as the `rest` binary so the caller can continue with
  `BACnet.Protocol.decode_npci/1` etc.

  ## Construction & Gotchas

  The struct only ever holds the source address; the actual NPDU bytes travel
  alongside it in the surrounding BVLL frame.

      iex> alias BACnet.Protocol.BvlcForwardedNPDU
      iex> fwd = %BvlcForwardedNPDU{
      ...>   originating_ip: {192, 168, 1, 99},
      ...>   originating_port: 0xBAC0
      ...> }
      iex> BvlcForwardedNPDU.encode(fwd)
      {:ok, <<192, 168, 1, 99, 186, 192>>}

  The port must be in 1..65535 (the guard in `encode/1` enforces this). IP
  tuples must be 4-tuples of 0..255 values; anything else yields
  `{:error, :invalid_ip}`.

  ## Usage Contexts

  `BACnet.Protocol.decode_bvll/3` produces a `BACnet.Protocol.BvlcForwardedNPDU` when it sees
  function code 0x04. The `BACnet.Stack.BBMD` then uses the originating address
  to decide whether the message also needs to be sent to the local subnet
  (two-hop vs. directed broadcast path) and always forwards the enclosed NPDU
  to its registered Foreign Devices. A `BACnet.Stack.ForeignDevice` receives
  these messages from its BBMD and treats the originating address as the true
  source for replies.

  ## See Also

  - `BACnet.Protocol` - `decode_bvll/3` and the `bvlc()` union that includes this type
  - `BACnet.Protocol.BvlcFunction` - the other (management) BVLC payloads
  - `BACnet.Protocol.BvlcResult` - result codes that may accompany BVLC operations
  - `BACnet.Stack.BBMD` - the component that generates and consumes the majority of Forwarded-NPDUs
  - `BACnet.Stack.ForeignDevice` - receives Forwarded-NPDUs from its registered BBMD
  """

  @typedoc """
  Represents a forwarded NPDU received via a BBMD (BVLC function 0x04).

  The two fields together form the 6-octet "B/IP Address of Originating Device"
  defined in J.2.5.1. The actual NPDU bytes follow this prefix in the BVLL
  message and are returned separately by `decode/1`.
  """
  @type t :: %__MODULE__{
          originating_ip: :inet.ip_address(),
          originating_port: :inet.port_number()
        }

  @fields [:originating_ip, :originating_port]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Decodes a BVLC Forwarded NPDU from binary data.
  """
  @spec decode(binary()) :: {:ok, {t(), rest :: binary()}} | {:error, term()}
  def decode(data)

  def decode(<<ip_a, ip_b, ip_c, ip_d, port::size(16), rest::binary>> = _data) do
    npdu = %__MODULE__{
      originating_ip: {ip_a, ip_b, ip_c, ip_d},
      originating_port: port
    }

    {:ok, {npdu, rest}}
  end

  def decode(_data) do
    {:error, :invalid_data}
  end

  @doc """
  Encodes a BVLC Forwarded NPDU to binary data.
  """
  @spec encode(t()) :: {:ok, binary()} | {:error, term()}
  def encode(npdu)

  def encode(%__MODULE__{originating_port: port} = npdu)
      when is_integer(port) and port in 1..65_535 do
    with {:ok, ip} <-
           (case npdu.originating_ip do
              {ip_a, ip_b, ip_c, ip_d} -> {:ok, <<ip_a, ip_b, ip_c, ip_d>>}
              _term -> {:error, :invalid_ip}
            end) do
      {:ok, <<ip::binary, port::size(16)>>}
    end
  end

  def encode(%__MODULE__{} = _npdu) do
    {:error, :invalid_npdu}
  end
end
