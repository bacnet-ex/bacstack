defmodule BACnet.Protocol do
  @moduledoc """
  This module is mostly used for basic decoding of BACnet frames (Protocol Data Units - PDU).

  This module handles decoding of BVLL (and delegates specifics), NPCI and NSDU.
  APDU is completely covered by `BACnet.Protocol.APDU`.

  For BACnet Virtual Link Layer (BVLL), it will handle it and delegate,
  once it determines it is a BVLC function. BVLC function codes
  such as distribute broadcast, original broad- and unicast and
  forwarded NPDU are handled by this module directly.
  Currently only BVLL type 0x81 (BACnet/IPv4) is implemented.

  For Network Protocol Control Information (NPCI),
  it will handle all decoding associated with it and handle field handling.

  For Network Service Data Unit (NSDU), it will handle all decoding associated
  with the regular BACnet types, excluding reserved and vendor proprietary.

  For Application Data Unit (APDU), see the `BACnet.Protocol.APDU` module.

  See also the following modules:
  - `BACnet.Protocol.APDU`
  - `BACnet.Protocol.BvlcFunction`
  - `BACnet.Protocol.NPCI`
  - `BACnet.Protocol.NetworkLayerProtocolMessage`
  """

  # TODO: Docs
  # TODO: Add encode functions

  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.BvlcForwardedNPDU
  alias BACnet.Protocol.BvlcFunction
  alias BACnet.Protocol.BvlcResult
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NetworkLayerProtocolMessage
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget

  require Constants

  @typedoc """
  BACnet Application Data Units (APDU).
  """
  @type apdu ::
          APDU.ConfirmedServiceRequest.t()
          | APDU.UnconfirmedServiceRequest.t()
          | APDU.ComplexACK.t()
          | APDU.SimpleACK.t()
          | APDU.SegmentACK.t()
          | APDU.Abort.t()
          | APDU.Error.t()
          | APDU.Reject.t()

  @typedoc """
  BACnet Virtual Link Control (BVLC), used in BACnet/IP.

  Transports that do not use BVLC shall use `:original_unicast` or
  `:original_broadcast`, depending on whether it's a broadcast or not.
  """
  @type bvlc ::
          BvlcForwardedNPDU.t()
          | BvlcFunction.t()
          | BvlcResult.t()
          | :distribute_broadcast_to_network
          | :original_broadcast
          | :original_unicast

  @npci_version NPCI.get_version()

  @doc """
  Decodes the BVLL header of a BACnet/IP packet.
  """
  @spec decode_bvll(non_neg_integer(), non_neg_integer(), binary()) ::
          {:ok, {bvlc_size :: non_neg_integer(), bvlc :: bvlc(), rest :: binary()}}
          | {:error, term()}
  def decode_bvll(bvll_type, bvlc_function, data)

  def decode_bvll(
        Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result),
        <<result_code::size(16), rest::binary>>
      ) do
    case Constants.by_value(:bvlc_result_format, result_code) do
      {:ok, result} ->
        payload = %BvlcResult{
          result_code: result
        }

        {:ok, {2, payload, rest}}

      :error ->
        {:error, {:unknown_result_code, result_code}}
    end
  end

  def decode_bvll(
        Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result),
        _rest
      ) do
    {:error, :insufficient_bvlc_data}
  end

  def decode_bvll(
        Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_forwarded_npdu),
        data
      ) do
    with {:ok, {payload, rest}} <- BvlcForwardedNPDU.decode(data) do
      {:ok, {6, payload, rest}}
    end
  end

  def decode_bvll(
        Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_original_unicast_npdu),
        data
      )
      when is_binary(data) do
    {:ok, {0, :original_unicast, data}}
  end

  def decode_bvll(
        Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_original_broadcast_npdu),
        data
      )
      when is_binary(data) do
    {:ok, {0, :original_broadcast, data}}
  end

  def decode_bvll(
        Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_distribute_broadcast_to_network),
        data
      )
      when is_binary(data) do
    {:ok, {0, :distribute_broadcast_to_network, data}}
  end

  def decode_bvll(
        Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
        bvlc_code,
        rest
      )
      when is_integer(bvlc_code) and is_binary(rest) do
    case BvlcFunction.decode(bvlc_code, rest) do
      {:ok, bvlc} -> {:ok, {byte_size(rest), bvlc, <<>>}}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Decodes the NPCI header of a BACnet packet.
  """
  @spec decode_npci(binary()) ::
          {:ok, {NPCI.t(), rest :: binary()}} | {:error, term()}
  def decode_npci(data)

  def decode_npci(<<@npci_version::size(8), npci::size(8), rest::binary>>) do
    with {:ok, {destination, rest}} <-
           (if Bitwise.band(npci, 0x20) > 0 do
              case rest do
                <<net::size(16), addr_length::size(8), address::integer-size(addr_length)-unit(8),
                  restn::binary>> ->
                  target = %NpciTarget{
                    net: net,
                    address: if(addr_length > 0, do: address)
                  }

                  {:ok, {target, restn}}

                _rest ->
                  {:error, :invalid_destination}
              end
            else
              {:ok, {nil, rest}}
            end),
         {:ok, {source, rest}} <-
           (if Bitwise.band(npci, 0x08) > 0 do
              case rest do
                <<net::size(16), addr_length::size(8), address::integer-size(addr_length)-unit(8),
                  restn::binary>> ->
                  target = %NpciTarget{
                    net: net,
                    address: if(addr_length > 0, do: address)
                  }

                  {:ok, {target, restn}}

                _rest ->
                  {:error, :invalid_source}
              end
            else
              {:ok, {nil, rest}}
            end),
         {:ok, {hopcount, rest}} <-
           (if Bitwise.band(npci, 0x20) > 0 do
              case rest do
                <<hopcount::size(8), restn::binary>> ->
                  {:ok, {hopcount, restn}}

                _rest ->
                  {:error, :invalid_hopcount}
              end
            else
              {:ok, {nil, rest}}
            end) do
      # Using by_value! is safe here, because only two bits are used and all (two) bits are covered by the protocol
      npci_prot = %NPCI{
        priority: Constants.by_value!(:npdu_control_priority, Bitwise.band(npci, 0x03)),
        expects_reply: Bitwise.band(npci, 0x04) > 0,
        destination: destination,
        source: source,
        hopcount: hopcount,
        is_network_message: Bitwise.band(npci, 0x80) > 0
      }

      {:ok, {npci_prot, rest}}
    end
  end

  def decode_npci(_data) do
    {:error, :invalid_npci}
  end

  @doc """
  Decodes the NPDU of a BACnet packet.

  For network messages, it decodes the NSDU.
  For application messages, it simply returns the APDU for further processing.
  """
  @spec decode_npdu(NPCI.t(), binary()) ::
          {:ok, {type :: :network | :apdu, NetworkLayerProtocolMessage.t() | binary()}}
          | {:error, term()}
  def decode_npdu(npci, data)

  def decode_npdu(%NPCI{is_network_message: true} = _npci, data) do
    with {:ok, nsdu} <- decode_nsdu(data) do
      {:ok, {:network, nsdu}}
    end
  end

  def decode_npdu(%NPCI{is_network_message: false} = _npci, data) do
    {:ok, {:apdu, data}}
  end

  @doc """
  Decodes the NSDU of a BACnet packet.
  """
  @spec decode_nsdu(binary()) :: {:ok, NetworkLayerProtocolMessage.t()} | {:error, term()}
  def decode_nsdu(data)

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :who_is_router_to_network),
          dnet::size(16)>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :who_is_router_to_network,
      msg_type: nil,
      data: dnet
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :who_is_router_to_network)>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :who_is_router_to_network,
      msg_type: nil,
      data: nil
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :i_am_router_to_network),
          rest::binary>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :i_am_router_to_network,
      msg_type: nil,
      data: nsdu_parse_dnet_list(rest)
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :i_could_be_router_to_network),
          dnet::size(16), perf_index>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :i_could_be_router_to_network,
      msg_type: nil,
      data: {dnet, perf_index}
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :reject_message_to_network),
          reason, dnet::size(16)>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :reject_message_to_network,
      msg_type: nil,
      data: {dnet, reason, nsdu_reject_reason_to_string(reason)}
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :router_busy_to_network),
          rest::binary>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :router_busy_to_network,
      msg_type: nil,
      data: nsdu_parse_dnet_list(rest)
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :router_available_to_network),
          rest::binary>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :router_available_to_network,
      msg_type: nil,
      data: nsdu_parse_dnet_list(rest)
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :initialize_routing_table),
          _num_ports, rest::binary>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :initialize_routing_table,
      msg_type: nil,
      data: nsdu_parse_routing_table_ports(rest)
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :initialize_routing_table_ack),
          _num_ports, rest::binary>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :initialize_routing_table_ack,
      msg_type: nil,
      data: nsdu_parse_routing_table_ports(rest)
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :establish_connection_to_network),
          dnet::size(16), term_time>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :establish_connection_to_network,
      msg_type: nil,
      data: {dnet, term_time}
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :disconnect_connection_to_network),
          dnet::size(16)>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :disconnect_connection_to_network,
      msg_type: nil,
      data: dnet
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :what_is_network_number)>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :what_is_network_number,
      msg_type: nil,
      data: nil
    }

    {:ok, message}
  end

  def decode_nsdu(
        <<Constants.macro_by_name(:network_layer_message_type, :network_number_is),
          dnet::size(16), flag>>
      ) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :network_number_is,
      msg_type: nil,
      data: {dnet, if(flag == 1, do: :configured, else: :learned)}
    }

    {:ok, message}
  end

  def decode_nsdu(<<msg_type, vendor_id::size(16), rest::binary>>)
      when msg_type >=
             Constants.macro_by_name(:network_layer_message_type, :vendor_proprietary_area_start) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :vendor_proprietary_area_start,
      msg_type:
        msg_type -
          Constants.macro_by_name(:network_layer_message_type, :vendor_proprietary_area_start),
      data: {vendor_id, rest}
    }

    {:ok, message}
  end

  def decode_nsdu(<<msg_type, rest::binary>>)
      when msg_type >= Constants.macro_by_name(:network_layer_message_type, :reserved_area_start) do
    message = %NetworkLayerProtocolMessage{
      network_message_type: :reserved_area_start,
      msg_type:
        msg_type - Constants.macro_by_name(:network_layer_message_type, :reserved_area_start),
      data: rest
    }

    {:ok, message}
  end

  def decode_nsdu(data) when is_binary(data) do
    {:error, :invalid_data}
  end

  @spec nsdu_parse_dnet_list(binary()) :: [non_neg_integer()]
  defp nsdu_parse_dnet_list(binary)

  defp nsdu_parse_dnet_list(<<>>) do
    []
  end

  defp nsdu_parse_dnet_list(bin) do
    {_rest, dnet} =
      Enum.reduce_while(1..65_535//1, {bin, []}, fn
        _entry, {<<dnet::size(16), rest::binary>>, acc} ->
          {:cont, {rest, [dnet | acc]}}

        _entry, {_bin, acc} ->
          {:halt, {nil, acc}}
      end)

    Enum.reverse(dnet)
  end

  @spec nsdu_parse_routing_table_ports(binary()) :: [
          {dnet :: non_neg_integer(), port_id :: byte(), port_info :: binary()}
        ]
  defp nsdu_parse_routing_table_ports(binary)

  defp nsdu_parse_routing_table_ports(<<>>) do
    []
  end

  defp nsdu_parse_routing_table_ports(bin) do
    {_rest, ports} =
      Enum.reduce_while(1..65_535//1, {bin, []}, fn
        _entry,
        {<<dnet::size(16), port_id, length, bin::binary-size(length), rest::binary>>, acc} ->
          {:cont, {rest, [{dnet, port_id, bin} | acc]}}

        _entry, {_bin, acc} ->
          {:halt, {nil, acc}}
      end)

    Enum.reverse(ports)
  end

  @spec nsdu_reject_reason_to_string(non_neg_integer()) :: String.t() | :undefined
  defp nsdu_reject_reason_to_string(reason)

  defp nsdu_reject_reason_to_string(0), do: "Other reason"

  defp nsdu_reject_reason_to_string(1),
    do:
      "The router is not directly connected to DNET and " <>
        "cannot find a router to DNET on any directly connected network " <>
        "using Who-Is-Router-To-Network messages"

  defp nsdu_reject_reason_to_string(2),
    do:
      "The router is busy and unable to accept messages for the specified DNET at the present time"

  defp nsdu_reject_reason_to_string(3),
    do:
      "It is an unknown network layer message type - the DNET returned in this case is a local matter"

  defp nsdu_reject_reason_to_string(4), do: "The message is too long to be routed to this DNET"

  defp nsdu_reject_reason_to_string(5),
    do:
      "The source message was rejected due to a BACnet security error " <>
        "and that error cannot be forwarded to the source device - " <>
        "see Clause 24.12.1.1 for more details " <>
        "on the generation of Reject-Message-To-Network messages indicating this reason"

  defp nsdu_reject_reason_to_string(6),
    do:
      "The source message was rejected due to errors in the addressing - " <>
        "the length of the DADR or SADR was determined to be invalid"

  defp nsdu_reject_reason_to_string(_reason), do: :undefined
end
