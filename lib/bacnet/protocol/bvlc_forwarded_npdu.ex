defmodule BACnet.Protocol.BvlcForwardedNPDU do
  # TODO: Docs

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
      when is_integer(port) and port in 1..65535 do
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
