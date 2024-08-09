defmodule BACnet.Protocol.NetworkLayerProtocolMessage do
  @moduledoc """
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
  """

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Represents a network number.
  """
  @type dnet :: ApplicationTags.unsigned16()

  @typedoc """
  Represents data for known BACnet network layer message types.
  """
  @type data ::
          (who_is_router_to_network :: dnet() | nil)
          | (i_am_router_to_network :: [dnet()])
          | (i_could_be_router_to_network :: {dnet(), perf_index :: byte()})
          | (reject_message_to_network :: {dnet, reason :: byte(), reason_string :: String.t()})
          | (router_busy_to_network :: [dnet()])
          | (router_available_to_network :: [dnet()])
          | (initialize_routing_table :: [{dnet(), port_id :: byte(), port_info :: binary()}])
          | (initialize_routing_table_ack :: [{dnet(), port_id :: byte(), port_info :: binary()}])
          | (establish_connection_to_network :: {dnet(), termination_time :: non_neg_integer()})
          | (disconnect_connection_to_network :: dnet())
          | (what_is_network_number :: nil)
          | (network_number_is :: {dnet(), :configured | :learned})

  @typedoc """
  Represents a message layer message (Network Service Data Unit - NSDU).

  `data` is a binary if the type is in the reserved area (`:reserved_area-start`).
  `data` is a tuple for vendor proprietary messages, the actual data is a binary in the tuple.
  """
  @type t :: %__MODULE__{
          network_message_type: BACnet.Protocol.Constants.network_layer_message_type(),
          data: data() | binary() | {vendor_id :: non_neg_integer(), binary()}
        }

  @fields [
    :network_message_type,
    :data
  ]
  @enforce_keys @fields
  defstruct @fields
end
