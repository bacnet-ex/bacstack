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
  alias BACnet.Protocol.Constants

  require Constants

  @msg_type_max_vendor 255 -
                         Constants.macro_by_name(
                           :network_layer_message_type,
                           :vendor_proprietary_area_start
                         )
  @msg_type_max_reserved Constants.macro_by_name(
                           :network_layer_message_type,
                           :vendor_proprietary_area_start
                         ) -
                           1 -
                           Constants.macro_by_name(
                             :network_layer_message_type,
                             :reserved_area_start
                           )

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
          | (reject_message_to_network ::
               {dnet, reason :: byte(), reason_string :: String.t() | :undefined})
          | (router_busy_to_network :: [dnet()])
          | (router_available_to_network :: [dnet()])
          | (initialize_routing_table :: [{dnet(), port_id :: byte(), port_info :: binary()}])
          | (initialize_routing_table_ack :: [{dnet(), port_id :: byte(), port_info :: binary()}])
          | (establish_connection_to_network :: {dnet(), termination_time :: non_neg_integer()})
          | (disconnect_connection_to_network :: dnet())
          | (what_is_network_number :: nil)
          | (network_number_is :: {dnet(), :configured | :learned})

  @typedoc """
  The message type number range for vendor proprietary messages.
  """
  @type msg_type_vendor() :: 0..unquote(@msg_type_max_vendor)

  @typedoc """
  The message type number range for reserved area messages.
  """
  @type msg_type_reserved() :: 0..unquote(@msg_type_max_reserved)

  @typedoc """
  Represents a message layer message (Network Service Data Unit - NSDU).

  `data` is a binary if the type is in the reserved area (`:reserved_area_start`).
  `data` is a tuple for vendor proprietary messages, the actual data is a binary in the tuple.
  """
  @type t :: %__MODULE__{
          network_message_type: BACnet.Protocol.Constants.network_layer_message_type(),
          msg_type: msg_type_vendor() | msg_type_reserved() | nil,
          data: data() | binary() | {vendor_id :: non_neg_integer(), binary()}
        }

  @fields [
    :network_message_type,
    :msg_type,
    :data
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode the network layer protocol message into binary data.
  """
  @spec encode(t()) :: {:ok, binary()} | {:error, term()}
  def encode(message)

  def encode(%__MODULE__{
        network_message_type: :who_is_router_to_network,
        data: dnet
      })
      when is_integer(dnet) and dnet in 0..65_535 do
    message =
      <<Constants.macro_by_name(:network_layer_message_type, :who_is_router_to_network),
        dnet::size(16)>>

    {:ok, message}
  end

  def encode(%__MODULE__{
        network_message_type: :who_is_router_to_network,
        data: nil
      }) do
    message = <<Constants.macro_by_name(:network_layer_message_type, :who_is_router_to_network)>>

    {:ok, message}
  end

  def encode(%__MODULE__{
        network_message_type: :i_am_router_to_network,
        data: dnet_list
      })
      when is_list(dnet_list) do
    with {:ok, {_count, dnets}} <- nsdu_encode_dnet_list(dnet_list) do
      message =
        <<Constants.macro_by_name(:network_layer_message_type, :i_am_router_to_network),
          dnets::binary>>

      {:ok, message}
    end
  end

  def encode(%__MODULE__{
        network_message_type: :i_could_be_router_to_network,
        data: {dnet, perf_index}
      })
      when is_integer(dnet) and dnet in 0..65_535 and is_integer(perf_index) and
             perf_index in 0..255 do
    message =
      <<Constants.macro_by_name(:network_layer_message_type, :i_could_be_router_to_network),
        dnet::size(16), perf_index>>

    {:ok, message}
  end

  def encode(%__MODULE__{
        network_message_type: :reject_message_to_network,
        data: {dnet, reason, _reason_string}
      })
      when is_integer(dnet) and dnet in 0..65_535 and is_integer(reason) and reason in 0..255 do
    message =
      <<Constants.macro_by_name(:network_layer_message_type, :reject_message_to_network), reason,
        dnet::size(16)>>

    {:ok, message}
  end

  def encode(%__MODULE__{
        network_message_type: :router_busy_to_network,
        data: dnet_list
      })
      when is_list(dnet_list) do
    with {:ok, {_count, dnets}} <- nsdu_encode_dnet_list(dnet_list) do
      message =
        <<Constants.macro_by_name(:network_layer_message_type, :router_busy_to_network),
          dnets::binary>>

      {:ok, message}
    end
  end

  def encode(%__MODULE__{
        network_message_type: :router_available_to_network,
        data: dnet_list
      })
      when is_list(dnet_list) do
    with {:ok, {_count, dnets}} <- nsdu_encode_dnet_list(dnet_list) do
      message =
        <<Constants.macro_by_name(:network_layer_message_type, :router_available_to_network),
          dnets::binary>>

      {:ok, message}
    end
  end

  def encode(%__MODULE__{
        network_message_type: :initialize_routing_table,
        data: ports_list
      })
      when is_list(ports_list) do
    with {:ok, {ports_count, ports}} <- nsdu_encode_routing_table_ports(ports_list) do
      message =
        <<Constants.macro_by_name(:network_layer_message_type, :initialize_routing_table),
          ports_count, ports::binary>>

      {:ok, message}
    end
  end

  def encode(%__MODULE__{
        network_message_type: :initialize_routing_table_ack,
        data: ports_list
      })
      when is_list(ports_list) do
    with {:ok, {ports_count, ports}} <- nsdu_encode_routing_table_ports(ports_list) do
      message =
        <<Constants.macro_by_name(:network_layer_message_type, :initialize_routing_table_ack),
          ports_count, ports::binary>>

      {:ok, message}
    end
  end

  def encode(%__MODULE__{
        network_message_type: :establish_connection_to_network,
        data: {dnet, term_time}
      })
      when is_integer(dnet) and dnet in 0..65_535 and is_integer(term_time) and
             term_time in 0..255 do
    message =
      <<Constants.macro_by_name(:network_layer_message_type, :establish_connection_to_network),
        dnet::size(16), term_time>>

    {:ok, message}
  end

  def encode(%__MODULE__{
        network_message_type: :disconnect_connection_to_network,
        data: dnet
      })
      when is_integer(dnet) and dnet in 0..65_535 do
    message =
      <<Constants.macro_by_name(:network_layer_message_type, :disconnect_connection_to_network),
        dnet::size(16)>>

    {:ok, message}
  end

  def encode(%__MODULE__{
        network_message_type: :what_is_network_number,
        data: nil
      }) do
    message = <<Constants.macro_by_name(:network_layer_message_type, :what_is_network_number)>>

    {:ok, message}
  end

  def encode(%__MODULE__{
        network_message_type: :network_number_is,
        data: {dnet, flag}
      })
      when is_integer(dnet) and dnet in 0..65_535 and flag in [:configured, :learned] do
    flag_num = if(flag == :configured, do: 1, else: 0)

    message =
      <<Constants.macro_by_name(:network_layer_message_type, :network_number_is), dnet::size(16),
        flag_num>>

    {:ok, message}
  end

  def encode(%__MODULE__{
        network_message_type: :vendor_proprietary_area_start,
        msg_type: msg_type,
        data: {vendor_id, payload}
      })
      when is_integer(vendor_id) and vendor_id in 0..65_535 and is_integer(msg_type) and
             msg_type in 0..@msg_type_max_vendor and is_binary(payload) do
    msg_num =
      msg_type +
        Constants.macro_by_name(:network_layer_message_type, :vendor_proprietary_area_start)

    message = <<msg_num, vendor_id::size(16), payload::binary>>

    {:ok, message}
  end

  def encode(%__MODULE__{
        network_message_type: :reserved_area_start,
        msg_type: msg_type,
        data: data
      })
      when is_integer(msg_type) and msg_type in 0..@msg_type_max_reserved and is_binary(data) do
    msg_num =
      msg_type + Constants.macro_by_name(:network_layer_message_type, :reserved_area_start)

    message = <<msg_num, data::binary>>

    {:ok, message}
  end

  def encode(%__MODULE__{}) do
    {:error, :invalid_data}
  end

  @spec nsdu_encode_dnet_list([dnet()]) ::
          {:ok, {count :: non_neg_integer(), binary()}} | {:error, term()}
  defp nsdu_encode_dnet_list(dnet_list) when is_list(dnet_list) do
    Enum.reduce_while(dnet_list, {:ok, {0, <<>>}}, fn
      dnet, {:ok, {count, acc}} when is_integer(dnet) and dnet in 0..65_535 ->
        {:cont, {:ok, {count + 1, <<acc::binary, dnet::size(16)>>}}}

      _else, _acc ->
        {:halt, {:error, :invalid_dnet}}
    end)
  end

  @spec nsdu_encode_routing_table_ports([{dnet(), port_id :: byte(), port_info :: binary()}]) ::
          {:ok, {count :: non_neg_integer(), binary()}} | {:error, term()}
  defp nsdu_encode_routing_table_ports(ports_list) when is_list(ports_list) do
    Enum.reduce_while(ports_list, {:ok, {0, <<>>}}, fn
      {dnet, port_id, bin}, {:ok, {count, acc}}
      when is_integer(dnet) and dnet in 0..65_535 and is_integer(port_id) and port_id in 0..255 and
             is_binary(bin) and byte_size(bin) <= 255 ->
        length = byte_size(bin)

        {:cont,
         {:ok,
          {count + 1, <<acc::binary, dnet::size(16), port_id, length, bin::binary-size(length)>>}}}

      _else, _acc ->
        {:halt, {:error, :invalid_ports_info}}
    end)
  end
end
