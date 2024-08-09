defmodule BACnet.Protocol.ForeignDeviceTableEntry do
  # TODO: Docs
  # ttl and remaining are nil on Delete-Foreign-Device-Table-Entry

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
