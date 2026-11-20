defmodule BACnet.Protocol.NpciTarget do
  @moduledoc """
  Network Protocol Control Information targets are used to describe
  source and destination targets (network and address information) inside
  of Network Protocol Control Information (`BACnet.Protocol.NPCI`).

  `address` contains the exact MAC address octets, including leading zero octets.
  Use `nil` for a destination broadcast (DLEN = 0). An absent source is represented
  by `NPCI.source == nil` - a present source must have a nonempty address.
  An empty binary is not a valid address, while `<<0>>` is a one-octet station address.

  Addresses are opaque binaries of one to seven octets. The required length and
  encoding depend on the remote data link, which may differ from the local transport.
  NPCI encoding and decoding do not validate data-link-specific address contents.

  BACnet describes the following address sizes for the different
  transport layers (data link layer):

  | Data Link Layer     | DLEN | SLEN | Encoding Rules                               |
  |:-------------------:|:----:|:----:|:---------------------------------------------|
  | ARCnet              | 1    | 1    | MAC layer representation                     |
  | BACnet/IP           | 6    | 6    | IP address and Port (ASHRAE 135 Annex J.1.2) |
  | BACnet/IPv6         | 3    | 3    | VMAC address (ASHRAE 135 Annex H.7.2)        |
  | BACnet/SC           | 6    | 6    | VMAC address (ASHRAE 135 Annex AB)           |
  | Ethernet            | 6    | 6    | MAC layer representation                     |
  | LonTalk (broadcast) | 2    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
  | LonTalk (multicast) | 2    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
  | LonTalk (unicast)   | 2    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
  | LonTalk (Neuron ID) | 7    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
  | MS/TP               | 1    | 1    | MAC layer representation                     |
  | ZigBee              | 3    | 3    | VMAC address (ASHRAE 135 Annex H.7)          |
  """

  @typedoc """
  Represents a NPCI target, such as used for source or destination.
  """
  @type t :: %__MODULE__{
          net: 1..65_535,
          address: binary() | nil
        }

  @fields [:net, :address]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Checks if the NPCI target is a global broadcast (net == 65535).
  """
  defguard is_global_broadcast(target)
           when is_struct(target, __MODULE__) and :erlang.map_get(:net, target) == 65_535

  @doc """
  Checks if the NPCI target is a remote broadcast (address == nil).
  """
  defguard is_remote_broadcast(target)
           when is_struct(target, __MODULE__) and is_nil(:erlang.map_get(:address, target))

  @doc """
  Checks if the NPCI target is neither a global broadcast nor a remote broadcast.
  """
  defguard is_remote_station(target)
           when not is_global_broadcast(target) and not is_remote_broadcast(target)
end
