defmodule BACnet.Protocol.NpciTarget do
  @moduledoc """
  Network Protocol Control Information targets are used to describe
  source and destination targets (network and address information) inside
  of Network Protocol Control Information (`BACnet.Protocol.NPCI`).

  BACnet describes the following address sizes for the different
  transport layers (data link layer):

  | Data Link Layer     | DLEN | SLEN | Encoding Rules                               |
  |:-------------------:|:----:|:----:|:---------------------------------------------|
  | ARCnet              | 1    | 1    | MAC layer representation                     |
  | BACnet/IP           | 6    | 6    | IP address and Port (ASHRAE 135 Annex J.1.2) |
  | Ethernet            | 6    | 6    | MAC layer representation                     |
  | LonTalk (broadcast) | 2    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
  | LonTalk (multicast) | 2    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
  | LonTalk (unicast)   | 2    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
  | LonTalk (Neuron ID) | 7    | 6    | Special encoding (ASHRAE 135 6.2.2.2)        |
  | MS/TP               | 1    | 1    | MAC layer representation                     |
  | ZigBee              | 3    | 3    | VMAC address (ASHRAE 135 Annex H.7)          |
  """

  @typedoc """
  Represents a NPCI target, such as used for source or destination.
  """
  @type t :: %__MODULE__{
          net: 1..65_535,
          address: non_neg_integer() | nil
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
