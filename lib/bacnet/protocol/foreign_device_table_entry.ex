defmodule BACnet.Protocol.ForeignDeviceTableEntry do
  @moduledoc """
  A Foreign Device Table Entry represents one foreign device that has registered
  with a BACnet/IP Broadcast Management Device (BBMD). Foreign devices use this
  registration mechanism to participate in BACnet broadcasts even when they are
  not on the same IP subnet as the devices they need to communicate with.

  The entry stores the IP address and port of the foreign device, the Time To
  Live (TTL) value that was requested at registration time, and the remaining
  time until the registration expires. The BBMD is responsible for sending a
  Forwarded NPDU to each registered foreign device for every broadcast
  it receives, and for removing entries whose remaining time reaches zero.

  ## BACnet Specification References

  - Annex J.5.2.1 defines the FDT entry layout (6-octet B/IP address + 2-octet
    Time-to-Live + 2-octet Remaining Time) and the two message contexts in which
    entries appear.
  - J.5.2.2 and J.5.2.3 describe the Register-Foreign-Device flow and the timer
    rule: remaining time is initialized to the supplied TTL **plus a fixed 30
    second grace period**. The entry is purged when the timer expires without a
    re-registration.
  - J.2.8.1 and J.2.9.1 give the exact wire formats (10 octets in Read-FDT-Ack,
    only 6 octets for Delete-Foreign-Device-Table-Entry).

  ## Two Wire Representations

  - **Normal / Ack form** (10 octets): used inside `Read-Foreign-Device-Table-Ack`
    (BVLC function 0x07). Both `time_to_live` and `remaining_time` are present
    (remaining_time already includes the +30 s grace).
  - **Delete form** (6 octets): used for `Delete-Foreign-Device-Table-Entry`
    (function 0x08) and when the BBMD itself needs to remove an entry. Both
    time fields **must be `nil`**. The encoder deliberately emits the short form.

  Maximum TTL / remaining value is 65535 (J.5.2.1.1). The BBMD in this library
  caps the number of concurrent FDT entries (default 512, configurable).

  ## Construction & Gotchas

  Full registration entry (as it would appear in a Read-FDT-Ack):

      iex> alias BACnet.Protocol.ForeignDeviceTableEntry
      iex> e = %ForeignDeviceTableEntry{
      ...>   ip: {10, 1, 2, 3},
      ...>   port: 0xBAC0,
      ...>   time_to_live: 3600,
      ...>   remaining_time: 3630
      ...> }
      iex> ForeignDeviceTableEntry.encode(e)
      {:ok, <<10, 1, 2, 3, 186, 192, 14, 16, 14, 46>>}

  Delete form (the special case used with `BACnet.Protocol.BvlcFunction` for function 0x08):

      iex> alias BACnet.Protocol.ForeignDeviceTableEntry
      iex> del = %ForeignDeviceTableEntry{
      ...>   ip: {10, 1, 2, 3},
      ...>   port: 0xBAC0,
      ...>   time_to_live: nil,
      ...>   remaining_time: nil
      ...> }
      iex> ForeignDeviceTableEntry.encode(del)
      {:ok, <<10, 1, 2, 3, 186, 192>>}

  Passing a mix of nil and integer values, or an out-of-range port, produces
  `{:error, :invalid_data}`.

  ## See Also

  - `BACnet.Protocol` - BVLL decoding that materialises FDT entries via BvlcFunction
  - `BACnet.Protocol.BvlcFunction` - the Register, Read-FDT, Read-FDT-Ack and Delete operations that transport these entries
  - `BACnet.Protocol.BvlcResult` - NAK codes that may be returned for FDT operations
  - `BACnet.Stack.BBMD` - the server that owns the live FDT, enforces max size, runs the timers, and emits Forwarded-NPDUs to registered foreign devices
  - `BACnet.Stack.ForeignDevice` - the client that creates registrations (and therefore indirectly causes FDT entries to be created on the remote BBMD)
  """

  @typedoc """
  An entry in the Foreign Device Table (FDT) maintained by a BBMD.

  When both `time_to_live` and `remaining_time` are `nil` the struct represents
  a *Delete-Foreign-Device-Table-Entry* request (J.2.9.1) and encodes to the
  short 6-octet form. In all other cases (normal FDT rows and Read-FDT-Ack)
  the fields contain the original TTL and the current remaining time (already
  including the 30-second grace period defined in J.5.2.3).
  """
  @type t :: %__MODULE__{
          ip: :inet.ip4_address(),
          port: :inet.port_number(),
          time_to_live: non_neg_integer() | nil,
          remaining_time: non_neg_integer() | nil
        }

  @fields [:ip, :port, :time_to_live, :remaining_time]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Decodes a Foreign Device Table Entry from binary data.
  """
  @spec decode(binary()) :: {:ok, {t(), rest :: binary()}} | {:error, term()}
  def decode(data)

  def decode(
        <<ip_a, ip_b, ip_c, ip_d, port::size(16), ttl::size(16), remaining::size(16),
          rest::binary>>
      ) do
    fd = %__MODULE__{
      ip: {ip_a, ip_b, ip_c, ip_d},
      port: port,
      time_to_live: ttl,
      remaining_time: remaining
    }

    {:ok, {fd, rest}}
  end

  def decode(data) when is_binary(data) do
    {:error, :invalid_data}
  end

  @doc """
  Encodes the Foreign Device Table Entry to binary data.

  If both `time_to_live` and `remaining_time` are nil,
  they are not included in the binary
  (useful for `Delete-Foreign-Device-Table-Entry`)
  """
  @spec encode(t()) :: {:ok, binary()} | {:error, term()}
  def encode(entry)

  def encode(
        %__MODULE__{
          ip: {ip_a, ip_b, ip_c, ip_d},
          port: port,
          time_to_live: nil,
          remaining_time: nil
        } = _entry
      )
      when is_integer(port) do
    {:ok, <<ip_a, ip_b, ip_c, ip_d, port::size(16)>>}
  end

  def encode(
        %__MODULE__{
          ip: {ip_a, ip_b, ip_c, ip_d},
          port: port,
          time_to_live: ttl,
          remaining_time: rem
        } = _entry
      )
      when is_integer(port) and is_integer(ttl) and is_integer(rem) do
    {:ok, <<ip_a, ip_b, ip_c, ip_d, port::size(16), ttl::size(16), rem::size(16)>>}
  end

  def encode(%__MODULE__{} = _entry), do: {:error, :invalid_data}
end
