# `BACnet.Protocol.NetworkLayerProtocolMessage`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/network_layer_protocol_message.ex#L1)

Network layer messages are used for prividing the basis for
router auto-configuration, router maintenance and
network layer congestion control.

The purpose of the BACnet network layer is to provide the means by which
messages can be relayed from one BACnet network to another,
regardless of the BACnet data link technology in use on that network.
Whereas the data link layer provides the capability to address messages
to a single device or broadcast them to all devices on the local network,
the network layer allows messages to be directed to a single remote device,
broadcast on a remote network, or broadcast globally to all devices on all networks.

See also ASHRAE 135 Clause 6.4.

# `data`

```elixir
@type data() ::
  (who_is_router_to_network :: dnet() | nil)
  | (i_am_router_to_network :: [dnet()])
  | (i_could_be_router_to_network :: {dnet(), perf_index :: byte()})
  | (reject_message_to_network ::
       {dnet(), reason :: byte(), reason_string :: String.t() | :undefined})
  | (router_busy_to_network :: [dnet()])
  | (router_available_to_network :: [dnet()])
  | (initialize_routing_table :: [
       {dnet(), port_id :: byte(), port_info :: binary()}
     ])
  | (initialize_routing_table_ack :: [
       {dnet(), port_id :: byte(), port_info :: binary()}
     ])
  | (establish_connection_to_network ::
       {dnet(), termination_time :: non_neg_integer()})
  | (disconnect_connection_to_network :: dnet())
  | (what_is_network_number :: nil)
  | (network_number_is :: {dnet(), :configured | :learned})
```

Represents data for known BACnet network layer message types.

# `dnet`

```elixir
@type dnet() :: BACnet.Protocol.ApplicationTags.unsigned16()
```

Represents a network number.

# `msg_type_reserved`

```elixir
@type msg_type_reserved() :: 0..107
```

The message type number range for reserved area messages.

# `msg_type_vendor`

```elixir
@type msg_type_vendor() :: 0..127
```

The message type number range for vendor proprietary messages.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NetworkLayerProtocolMessage{
  data: data() | binary() | {vendor_id :: non_neg_integer(), binary()},
  msg_type: msg_type_vendor() | msg_type_reserved() | nil,
  network_message_type: BACnet.Protocol.Constants.network_layer_message_type()
}
```

Represents a message layer message (Network Service Data Unit - NSDU).

`data` is a binary if the type is in the reserved area (`:reserved_area_start`).
`data` is a tuple for vendor proprietary messages, the actual data is a binary in the tuple.

# `encode`

```elixir
@spec encode(t()) :: {:ok, binary()} | {:error, term()}
```

Encode the network layer protocol message into binary data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
