defmodule BACnet.Protocol.VmacEntry do
  @moduledoc """
  A BACnetVMACEntry maps a virtual MAC address (VMAC) to the native MAC
  address used by the underlying data link.

  It is used by the `Virtual_MAC_Address_Table` property of the Network Port
  object (see Annex H.7 of ASHRAE 135). Virtual MAC addressing is required by
  some network types (e.g. Zigbee, certain IPv6 configurations) so that the
  BACnet network layer can use an uniform 6-octet (or smaller) address space
  while the real data-link addresses remain larger or differently formatted.

  ### ASN.1 (ASHRAE 135)

      BACnetVMACEntry ::= SEQUENCE {
          virtual-mac-address [0] OCTET STRING,  -- maximum size 6 octets
          native-mac-address  [1] OCTET STRING
      }
  """

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  A single Virtual MAC Address table entry.
  """
  @type t :: %__MODULE__{
          virtual_mac_address: binary(),
          native_mac_address: binary()
        }

  @fields [:virtual_mac_address, :native_mac_address]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnetVMACEntry into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = entry, _opts \\ []) do
    with true <- byte_size(entry.virtual_mac_address) <= 6,
         {:ok, vmac_tag} <-
           ApplicationTags.create_tag_encoding(0, :octet_string, entry.virtual_mac_address),
         {:ok, nmac_tag} <-
           ApplicationTags.create_tag_encoding(1, :octet_string, entry.native_mac_address) do
      {:ok, [vmac_tag, nmac_tag]}
    else
      false -> {:error, :virtual_mac_too_long}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parses a BACnetVMACEntry from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:tagged, {0, vmac, _len1}},
        {:tagged, {1, nmac, _len2}}
        | rest
      ]
      when is_binary(vmac) and is_binary(nmac) and byte_size(vmac) <= 6 ->
        entry = %__MODULE__{
          virtual_mac_address: vmac,
          native_mac_address: nmac
        }

        {:ok, {entry, rest}}

      _other ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given VMAC entry is well-formed.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{
        virtual_mac_address: vmac,
        native_mac_address: nmac
      })
      when is_binary(vmac) and byte_size(vmac) <= 6 and is_binary(nmac) and byte_size(nmac) > 0 do
    true
  end

  def valid?(%__MODULE__{}), do: false
end
