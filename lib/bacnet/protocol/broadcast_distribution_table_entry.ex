defmodule BACnet.Protocol.BroadcastDistributionTableEntry do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

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
