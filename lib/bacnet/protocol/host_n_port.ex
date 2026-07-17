defmodule BACnet.Protocol.HostNPort do
  @moduledoc """
  A BACnetHostNPort describes a host address together with a UDP (or equivalent)
  port number. It is used in several Network Port object properties, most
  notably:

  - `BACnet_IP_Global_Address` - the public-side address of a NAT-traversing port
  - `FD_BBMD_Address` - the BBMD with which a foreign device registers

  The host portion is a CHOICE that can be:

  - `:none` - no address is known / not configured (port should be 0)
  - an IP address (`:ip_address`, OCTET STRING, typically 4 or 16 octets)
  - a DNS host name (`:name`, CharacterString)

  ### ASN.1 (ASHRAE 135)

      BACnetHostAddress ::= CHOICE {
          none       [0] NULL,
          ip-address [1] OCTET STRING,
          name       [2] CharacterString
      }

      BACnetHostNPort ::= SEQUENCE {
          host [0] BACnetHostAddress,
          port [1] Unsigned16
      }
  """

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  The host part of a HostNPort.

  - `:none` - no address configured
  - `{:ip_address, :inet.ip_address()}` - raw IP address octets (IPv4 = 4 bytes, IPv6 = 16 bytes)
  - `{:name, String.t()}` - DNS host name (RFC 1123)
  """
  @type host :: :none | {:ip_address, :inet.ip_address()} | {:name, String.t()}

  @typedoc """
  A BACnetHostNPort value.
  """
  @type t :: %__MODULE__{
          host: host(),
          port: 0..65_535
        }

  @fields [:host, :port]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Parses a BACnetHostNPort from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:constructed, {0, host_tags, _len1}},
        {:tagged, {1, port_bytes, _len2}}
        | rest
      ] ->
        with {:ok, host} <- parse_host(host_tags),
             {:ok, {:unsigned_integer, port}} <-
               ApplicationTags.unfold_to_type(:unsigned_integer, port_bytes) do
          if port >= 0 and port <= 65_535 do
            hnp = %__MODULE__{host: host, port: port}
            {:ok, {hnp, rest}}
          else
            {:error, :invalid_port}
          end
        else
          {:error, _err} = err -> err
        end

      _tags ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Encodes a BACnetHostNPort into application tags encoding (list of tags).
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = hnp, opts \\ []) do
    with {:ok, host_tag} <- encode_host(hnp.host, opts),
         {:ok, port_tag} <- ApplicationTags.create_tag_encoding(1, :unsigned_integer, hnp.port) do
      {:ok, [{:constructed, {0, host_tag, 0}}, port_tag]}
    end
  end

  @doc """
  Validates whether the given HostNPort is well-formed.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{host: :none, port: port})
      when is_integer(port) and port >= 0 and port <= 65_535,
      do: true

  def valid?(%__MODULE__{host: {:ip_address, ip}, port: port})
      when is_tuple(ip) and tuple_size(ip) in [4, 8] and is_integer(port) and port >= 0 and
             port <= 65_535,
      do: true

  def valid?(%__MODULE__{host: {:name, name}, port: port})
      when is_binary(name) and byte_size(name) > 0 and byte_size(name) <= 255 and
             is_integer(port) and port >= 0 and port <= 65_535,
      do: true

  def valid?(%__MODULE__{}), do: false

  @spec encode_host(host(), Keyword.t()) :: {:ok, ApplicationTags.encoding()}
  defp encode_host(host, _opts)

  defp encode_host(:none, _opts) do
    # context tag 0, NULL (empty value)
    ApplicationTags.create_tag_encoding(0, :null, nil)
  end

  defp encode_host({:ip_address, ip}, _opts) when is_tuple(ip) and tuple_size(ip) == 4 do
    bytes =
      ip
      |> Tuple.to_list()
      |> :binary.list_to_bin()

    ApplicationTags.create_tag_encoding(1, :octet_string, bytes)
  end

  defp encode_host({:ip_address, ip}, _opts) when is_tuple(ip) and tuple_size(ip) == 8 do
    bytes =
      ip
      |> Tuple.to_list()
      |> Enum.map(fn int -> <<int::size(16)>> end)
      |> :binary.list_to_bin()

    ApplicationTags.create_tag_encoding(1, :octet_string, bytes)
  end

  defp encode_host({:name, name}, _opts) when is_binary(name) do
    ApplicationTags.create_tag_encoding(2, :character_string, name)
  end

  defp encode_host(_host, _opts), do: {:error, :invalid_host}

  @spec parse_host(ApplicationTags.encoding()) :: {:ok, host()} | {:error, term()}
  defp parse_host(tags)

  defp parse_host({:tagged, {0, _bytes, _len}}) do
    # NULL (context tag 0)
    {:ok, :none}
  end

  defp parse_host({:tagged, {1, bytes, len}}) when is_binary(bytes) and len == 4 do
    ip =
      bytes
      |> :binary.bin_to_list()
      |> List.to_tuple()

    {:ok, {:ip_address, ip}}
  end

  defp parse_host({:tagged, {1, bytes, len}}) when is_binary(bytes) and len == 16 do
    ip =
      bytes
      |> :binary.bin_to_list()
      |> Stream.chunk_every(2)
      |> Enum.map(fn [a, b] -> Bitwise.bsl(a, 8) + b end)
      |> List.to_tuple()

    {:ok, {:ip_address, ip}}
  end

  defp parse_host({:tagged, {2, bytes, _len}}) do
    case ApplicationTags.unfold_to_type(:character_string, bytes) do
      {:ok, {:character_string, name}} -> {:ok, {:name, name}}
      err -> err
    end
  end

  defp parse_host(_tags), do: {:error, :invalid_host}
end
