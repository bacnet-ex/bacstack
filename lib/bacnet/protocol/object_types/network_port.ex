defmodule BACnet.Protocol.ObjectTypes.NetworkPort do
  @moduledoc """
  The Network Port object type defines a standardized object whose properties represent
  the externally visible characteristics of a network port of a BACnet device.
  All BACnet devices shall contain at least one Network Port object per configured port.
  It is a local matter whether or not Network Port objects exist for non-configured ports.
  It is a local matter whether or not the Network Port object is used for non-BACnet ports.

  Verification and validation of property values within a Network Port object is a local matter.
  Property values which are required to maintain proper operation of the network shall be
  retained across a device reset.

  Network Port objects may optionally support intrinsic reporting to facilitate the reporting
  of fault conditions. Network Port objects that support intrinsic reporting shall apply the
  NONE event algorithm.

  As specified in the standard (ASHRAE 135-2016, Clause 12.56), some properties of the Network
  Port object are required if the object is used to represent a network of a given type and
  protocol level. For example, a Network Port object whose Network_Type is MSTP must include
  the Max_Master property (when applicable), and a Network Port object whose Network_Type is
  IPV4 must include the BACnet_IP_Subnet_Mask property (when Protocol_Level is BACNET_APPLICATION).

  Aside from the properties so required, it is a local matter whether a Network Port object
  contains properties that do not apply to its Network_Type. Some vendors may find it convenient
  to have all of their Network Port objects support the same list of properties regardless of
  Network_Type. This is permitted, but not required.

  ### Object Description (ASHRAE 135-2016)

  > The Network Port object provides access to the configuration and properties of network ports
  > of a device. All BACnet devices shall contain one Network Port object per configured port.
  > It is a local matter whether or not Network Port objects exist for non-configured ports.
  > It is a local matter whether or not the Network Port object is used for non-BACnet ports.

  ### Behaviour and Operation

  The Network Port object is used to configure and monitor the network interfaces of a BACnet
  device. Changes to many properties set the Changes_Pending property to TRUE. The Command
  property is used to apply pending changes (or discard them, renew DHCP, restart the port, etc.).

  Properties such as Network_Number must be retained across resets for routers and other devices
  that require knowledge of the network number. Many properties are conditional on Network_Type
  and Protocol_Level.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself** via `update_property/3` (never direct mutation).

  **Special / live properties and expected developer behaviour**

  - `changes_pending`: Set to true when configuration properties are written that require
    activation via Command.
    **Dev must**: Maintain this flag correctly; clear it when Command is written with
    appropriate value (e.g. discard_changes or restart_port that applies changes).

  - `command`: Writing a value other than :idle causes the device to perform the action
    (discard pending changes, renew FD registration, renew DHCP, restart autonegotiation,
    disconnect, restart port, etc.). After processing, the property reverts to :idle.
    **Dev must**: Implement the side effects of each command value and update related
    properties (e.g. after renew_dhcp update IP related properties).

  - `network_number`, `network_number_quality`: Critical for routers.
    **Dev must**: Persist network_number across restarts; update quality appropriately
    (configured vs learned).

  - `mac_address`, `apdu_length`, `link_speed`, `link_speeds`, IP/MS/TP specific properties:
    Changes often require port restart / application of configuration.
    **Dev must**: When writing configuration properties, set changes_pending = true.
    On successful Command (apply/restart), push the configuration into the lower-layer
    transport (IPv4Transport, MstpTransport, etc.) and clear changes_pending.

  - `status_flags`, `reliability`, `out_of_service`:
    **Dev must**: Keep reliability up to date based on the actual health of the physical/
    logical port (no_fault_detected, communication_failure, etc.). The fault bit of
    status_flags is maintained automatically. out_of_service suspends use of the port.

  - BBMD / Foreign Device properties (`bbmd_*`, `fd_*`):
    **Dev must**: Keep the tables in sync with the actual BBMD/FD implementation state.
    Writing to the tables or enabling BBMD usually sets changes_pending.

  - Intrinsic reporting (optional): Uses the NONE event algorithm. Only fault conditions
    (via reliability) generate events.

  **Creation**: `create(instance, name, %{network_type: :ipv4, protocol_level: :bacnet_application, ...}, ...)`

  See the generated tables at the end of the moduledoc for the full list of properties,
  their types, defaults, and annotations.

  ### See Also
  - ASHRAE Standard 135-2016 Clause 12.56 Network Port Object Type
  - Addendum ai to 135-2012 (introduction of the object)
  """

  alias BACnet.Protocol.AddressBinding
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ForeignDeviceTableEntry
  alias BACnet.Protocol.HostNPort
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.RouterEntry
  alias BACnet.Protocol.VmacEntry

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Network Port object.

  Supports enabling intrinsic reporting via `intrinsic_reporting`.

  In addition to the common options, Network Port supports:
  - `supports_command_execution` - Enables command execution properties.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | {:supports_command_execution, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Network Port object. All keys should be treated as read-only;
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil if disabled. If Intrinsic
  Reporting is enabled on the object, then the properties can not be nil.
  Many properties are conditional on `network_type` and `protocol_level`.
  """
  bac_object Constants.macro_assert_name(:object_type, :network_port) do
    services(intrinsic: true)

    # Common / always present properties
    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:network_type, Constants.network_type(), required: true)

    field(:protocol_level, Constants.protocol_level(),
      required: true,
      default: :bacnet_application
    )

    field(:reference_port, non_neg_integer())

    field(:network_number, ApplicationTags.unsigned16(), required: true, default: 0)

    field(:network_number_quality, Constants.network_number_quality(),
      required: true,
      default: :unknown
    )

    field(:changes_pending, boolean(), required: true, default: false, readonly: true)

    field(:command, Constants.network_port_command(),
      default: :idle,
      annotation: [required_when: {:opt, :supports_command_execution}]
    )

    field(:mac_address, binary(),
      annotation: [
        only_when: fn props, _meta ->
          if props[:network_type] == :ptp do
            false
          else
            :optional
          end
        end,
        required_when: fn props, _object ->
          Map.get(props, :network_type) in [
            :arcnet,
            :ethernet,
            :lontalk,
            :mstp,
            :serial,
            :virtual,
            :zigbee
          ]
        end,
        readonly_when: [
          {:property, :network_type, :==, :ipv4},
          {:property, :network_type, :==, :ipv6},
          :vmac_addressing
        ]
      ]
    )

    field(:apdu_length, non_neg_integer(), required: true, default: 1476)

    field(:link_speed, float(),
      default: 0.0,
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) in [
            :arcnet,
            :ethernet,
            :lontalk,
            :serial,
            :virtual,
            :zigbee
          ] and
            Map.get(props, :protocol_level) == :physical
        end
      ]
    )

    field(:link_speeds, BACnetArray.t(float()), default: BACnetArray.new())

    field(:link_speed_autonegotiate, boolean(), default: false)

    field(:network_interface_name, String.t())

    # BACnet/IP (IPv4) related properties
    field(:bacnet_ip_mode, Constants.ip_mode(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4 and
            Map.get(props, :protocol_level) == :bacnet_application
        end
      ]
    )

    field(:ip_address, :inet.ip4_address(),
      implicit_relationship: :bacnet_ip_mode,
      annotation: [
        decoder: &decode_ipv4_address(:ip_address, &1),
        encoder: &encode_ipv4_address(:ip_address, &1),
        only_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    field(:bacnet_ip_udp_port, ApplicationTags.unsigned16(),
      implicit_relationship: :bacnet_ip_mode,
      annotation: [
        only_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    field(:ip_subnet_mask, :inet.ip4_address(),
      implicit_relationship: :bacnet_ip_mode,
      annotation: [
        decoder: &decode_ipv4_address(:ip_subnet_mask, &1),
        encoder: &encode_ipv4_address(:ip_subnet_mask, &1),
        only_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    field(:ip_default_gateway, :inet.ip4_address(),
      implicit_relationship: :bacnet_ip_mode,
      annotation: [
        decoder: &decode_ipv4_address(:ip_default_gateway, &1),
        encoder: &encode_ipv4_address(:ip_default_gateway, &1),
        only_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    # Property is required when the port is IPv4, protocol level is application and port supports multicast
    field(:bacnet_ip_multicast_address, :inet.ip4_address(),
      annotation: [
        decoder: &decode_ipv4_address(:bacnet_ip_multicast_address, &1),
        encoder: &encode_ipv4_address(:bacnet_ip_multicast_address, &1),
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv4 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ip_dns_server, BACnetArray.t(:inet.ip4_address()),
      implicit_relationship: :bacnet_ip_mode,
      annotation: [
        decoder: &decode_ipv4_address(:ip_dns_server, &1),
        encoder: &encode_ipv4_address(:ip_dns_server, &1),
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv4 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ip_dhcp_enable, boolean(),
      implicit_relationship: :bacnet_ip_mode,
      annotation: [
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv4 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ip_dhcp_lease_time, non_neg_integer(),
      annotation: [
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv4 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ip_dhcp_lease_time_remaining, non_neg_integer(),
      readonly: true,
      annotation: [
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv4 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ip_dhcp_server, :inet.ip4_address(),
      annotation: [
        decoder: &decode_ipv4_address(:ip_dhcp_server, &1),
        encoder: &encode_ipv4_address(:ip_dhcp_server, &1),
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv4 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:bacnet_ip_nat_traversal, boolean())

    field(:bacnet_ip_global_address, HostNPort.t(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :bacnet_ip_nat_traversal) == true
        end
      ]
    )

    # BBMD / Foreign Device
    field(:bbmd_broadcast_distribution_table, [BroadcastDistributionTableEntry.t()])

    field(:bbmd_accept_fd_registrations, boolean(),
      implicit_relationship: :bbmd_broadcast_distribution_table
    )

    field(:bbmd_foreign_device_table, [ForeignDeviceTableEntry.t()],
      implicit_relationship: :bbmd_broadcast_distribution_table
    )

    field(:fd_bbmd_address, HostNPort.t(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :bacnet_ip_mode) == :foreign or
            Map.get(props, :bacnet_ipv6_mode) == :foreign
        end
      ]
    )

    field(:fd_subscription_lifetime, ApplicationTags.unsigned16(),
      implicit_relationship: :fd_bbmd_address
    )

    # BACnet/IPv6 related properties
    field(:bacnet_ipv6_mode, Constants.ip_mode(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:ipv6_address, :inet.ip6_address(),
      implicit_relationship: :bacnet_ipv6_mode,
      annotation: [
        decoder: &decode_ipv6_address(:ipv6_address, &1),
        encoder: &encode_ipv6_address(:ipv6_address, &1),
        only_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:ipv6_prefix_length, 0..128,
      implicit_relationship: :bacnet_ipv6_mode,
      annotation: [
        only_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:bacnet_ipv6_udp_port, ApplicationTags.unsigned16(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6 and
            Map.get(props, :protocol_level) == :bacnet_application
        end,
        only_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:ipv6_default_gateway, :inet.ip6_address(),
      implicit_relationship: :bacnet_ipv6_mode,
      annotation: [
        decoder: &decode_ipv6_address(:ipv6_default_gateway, &1),
        encoder: &encode_ipv6_address(:ipv6_default_gateway, &1),
        only_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:bacnet_ipv6_multicast_address, :inet.ip6_address(),
      annotation: [
        decoder: &decode_ipv6_address(:bacnet_ipv6_multicast_address, &1),
        encoder: &encode_ipv6_address(:bacnet_ipv6_multicast_address, &1),
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv6 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ipv6_dns_server, BACnetArray.t(:inet.ip6_address()),
      default: BACnetArray.new(),
      implicit_relationship: :bacnet_ipv6_mode,
      annotation: [
        decoder: &decode_ipv6_address(:ipv6_dns_server, &1),
        encoder: &encode_ipv6_address(:ipv6_dns_server, &1),
        only_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:ipv6_auto_addressing_enable, boolean(),
      annotation: [
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv6 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ipv6_dhcp_lease_time, non_neg_integer(),
      annotation: [
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv6 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ipv6_dhcp_lease_time_remaining, non_neg_integer(),
      readonly: true,
      annotation: [
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv6 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ipv6_dhcp_server, :inet.ip6_address(),
      annotation: [
        decoder: &decode_ipv6_address(:ipv6_dhcp_server, &1),
        encoder: &encode_ipv6_address(:ipv6_dhcp_server, &1),
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv6 do
            :optional
          else
            false
          end
        end
      ]
    )

    field(:ipv6_zone_index, String.t(),
      annotation: [
        only_when: fn props, _object ->
          if Map.get(props, :network_type) == :ipv6 do
            :optional
          else
            false
          end
        end
      ]
    )

    # MS/TP related
    field(:max_master, 1..127,
      readonly: true,
      implicit_relationship: :max_info_frames,
      bac_type: {:with_validator, :unsigned_integer, &(&1 >= 1 and &1 <= 127)},
      annotation: [
        # required_when: fn props, _object ->
        #   Map.get(props, :network_type) == :mstp and
        #     Map.get(props, :protocol_level) == :bacnet_application
        # end
      ]
    )

    field(:max_info_frames, pos_integer(),
      bac_type: {:with_validator, :unsigned_integer, &(&1 >= 1)},
      annotation: [
        # required_when: fn props, _object ->
        #   Map.get(props, :network_type) == :mstp
        # end
      ]
    )

    field(:manual_slave_address_binding, [AddressBinding.t()])
    field(:slave_address_binding, [AddressBinding.t()])

    # Properties for slave proxy functionality (per-se not provided by this bacstack)
    field(:slave_proxy_enable, boolean())
    field(:auto_slave_discovery, boolean(), implicit_relationship: :slave_proxy_enable)

    # Virtual MAC (for certain network types that require VMAC)
    field(:virtual_mac_address_table, [VmacEntry.t()])

    field(:routing_table, [RouterEntry.t()])

    # Common
    field(:profile_name, String.t(), default: "")
  end

  defp decode_ipv4_address(_property, %Encoding{encoding: :primitive, type: :octet_string} = tags) do
    case tags.value do
      <<ip_a, ip_b, ip_c, ip_d>> ->
        {:ok, {ip_a, ip_b, ip_c, ip_d}}

      _other ->
        {:error, :invalid_tags}
    end
  end

  defp encode_ipv4_address(_property, {ip_a, ip_b, ip_c, ip_d}) do
    {:ok, {:octet_string, <<ip_a, ip_b, ip_c, ip_d>>}}
  end

  defp encode_ipv4_address(_property, _data), do: {:error, :invalid_data}

  defp decode_ipv6_address(_property, %Encoding{encoding: :primitive, type: :octet_string} = tags) do
    case tags.value do
      <<ip_a::size(16), ip_b::size(16), ip_c::size(16), ip_d::size(16), ip_e::size(16),
        ip_f::size(16), ip_g::size(16), ip_h::size(16)>> ->
        {:ok, {ip_a, ip_b, ip_c, ip_d, ip_e, ip_f, ip_g, ip_h}}

      _other ->
        {:error, :invalid_tags}
    end
  end

  defp encode_ipv6_address(_property, {ip_a, ip_b, ip_c, ip_d, ip_e, ip_f, ip_g, ip_h}) do
    {:ok,
     {:octet_string,
      <<ip_a::size(16), ip_b::size(16), ip_c::size(16), ip_d::size(16), ip_e::size(16),
        ip_f::size(16), ip_g::size(16), ip_h::size(16)>>}}
  end

  defp encode_ipv6_address(_property, _data), do: {:error, :invalid_data}
end
