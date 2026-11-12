defmodule BACnet.Protocol.ObjectTypes.NetworkPort do
  @moduledoc """
  A Network Port exposes a device's communication settings and status through
  BACnet. A client can read the port configuration and request supported
  changes. The application connects those requests to its running transport.

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
  >
  > It is suggested that instances greater than 255 be used for Network Port objects with a
  > Protocol_Level of PHYSICAL or PROTOCOL.
  > When the Protocol_Level property has a value of BACNET_APPLICATION, the
  > instance number (see Clause 20.2.14) shall correspond to the Port ID of the associated network
  > as described in Clause 6.

  ### Behaviour and Operation

  Writes to configuration properties expose the proposed settings and set
  `changes_pending`. The first write to each property retains its previous value
  in the object metadata. The host can call `active_configuration/1` for settings
  still in effect, such as the BDT used by the BVLL layer. The object and its
  pending metadata need to be persisted together when pending writes survive a reset.

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  handles `BACnet.Protocol.Services.ReinitializeDevice`. It needs to apply the pending
  configuration across affected ports as a single transaction for ACTIVATE_CHANGES
  or WARMSTART. After successful activation, execute each affected object with
  `:periodic` and `network_port_event: {:configuration_activated, :activate_changes}`
  or `{:configuration_activated, :warmstart}` in the context options. The host
  needs to serialize activation with configuration writes. RESTART_PORT is a
  command to reinitialize one port with its active settings.

  #### Commands

  Set `supports_command_execution: true` to select `command` with the initial
  value `:idle`. The object handles `:discard_changes` and accepts other commands
  through callbacks in the `:network_port_runtime` creation option. Each
  callback implements one action and receives the committed Network Port object.
  For a command write, the host needs to build a candidate with `update_property/3`
  and call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`. On success
  it commits the candidate, acknowledges the BACnet write and then executes the
  committed object with the command write trigger. While the command is outstanding,
  another command write returns `{:error, {:object, :busy}}`.

  Execution restores `:idle` after the callback returns. For slave discovery,
  the callback should return once discovery has started. For restart, DHCP,
  foreign-device renewal, autonegotiation and proprietary commands, an error
  updates `reliability` and the fault flag. The execution result retains the
  callback outcome as a `t:command_result/0`. With intrinsic reporting selected,
  the command outcome is in the result state's `execution_state` field.
  DISCARD_CHANGES restores the active configuration while preserving live observations.

  #### Host responsibilities

  An `:out_of_service` runtime callback must disable or enable communication at the
  object's `protocol_level`. For an Out_Of_Service write,
  the host needs to prepare the candidate, execute the write on it and commit the
  successful result before acknowledging it. If the callback fails, the host
  needs to retain the original object. The callback must leave communication
  in its previous state on failure. If the write arrived on the affected port,
  the host and adapter need to allow the service response through.

  The host owns lower-layer port references, inherited settings, transport I/O,
  DHCP and foreign-device timers, and routing tables. It needs to validate the
  reference hierarchy and apply shared settings and referenced-port faults
  consistently across affected objects. It may enforce the optional single-client
  pending-change policy in Clause 12.56.13. Use `update_operating_property/3` to
  record live transport values such as the negotiated link speed or DHCP addresses.
  The host supplies `{:network_number_learned, number, configured?}` as
  the `:network_port_event` when processing a Network-Number-Is message for
  an unconfigured port. See `t:port_event/0` for the supported events.
  With `intrinsic_reporting: true`, reliability changes can generate FAULT and
  NORMAL transitions. The host retrieves the transition with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after retaining
  the result.

  The IPv6 UDP port uses the general pending-configuration mechanism in
  Clause 12.56.13. The ACTIVATE command mentioned in Clause 12.56.42 has no
  corresponding command value in Clause 12.56.14.

  #### Exposing IP addresses as read-only

  The host can expose a static IP address for discovery and diagnostics while
  restricting configuration to local administration. Use `property_writable?/2`
  for the object's access rules, which make the IPv4 address read-only when DHCP
  is enabled and the IPv6 address read-only when automatic addressing is enabled.
  For a static address, add a host write policy that denies `:ip_address` and
  `:ipv6_address` for the selected Network Port instances.

  In `BACnet.Protocol.Services.WriteProperty`, resolve the object and property,
  then apply the policy before building a candidate. Return a BACnet error with
  class `:property` and code `:write_access_denied` for a denied write. Use the
  same policy for each write in `BACnet.Protocol.Services.WritePropertyMultiple`
  as it is processed in request order. Identify the denied object, property, and
  array index in the first failed write attempt of
  `BACnet.Protocol.Services.Error.WritePropertyMultipleError`.

  Reads still expose the configured address. If a local administrator or the
  operating system changes it, the host can record the new operating address
  with `update_operating_property/3`. To restrict client-triggered automatic
  address changes as well, apply the policy to writes to `:ip_dhcp_enable` and
  `:ipv6_auto_addressing_enable` and to commands that can restart address
  assignment, such as `:renew_dhcp`.

  This example applies the policy to every Network Port handled by the function.
  The same policy can use the port's object identifier to select individual ports.

      iex> alias BACnet.Protocol.BACnetArray
      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.NetworkPort
      iex> {:ok, port} = NetworkPort.create(2, "Static IPv4 port", %{
      ...>   network_type: :ipv4,
      ...>   protocol_level: :bacnet_application,
      ...>   bacnet_ip_mode: :normal,
      ...>   bacnet_ip_udp_port: 47_808,
      ...>   ip_address: {192, 0, 2, 10},
      ...>   ip_subnet_mask: {255, 255, 255, 0},
      ...>   ip_default_gateway: {192, 0, 2, 1},
      ...>   ip_dns_server: BACnetArray.new(),
      ...>   ip_dhcp_enable: false,
      ...>   description: "Static address"
      ...> })
      iex> prepare_write = fn port, property, value ->
      ...>   if property not in [:ip_address, :ipv6_address] and
      ...>        NetworkPort.property_writable?(port, property) do
      ...>     with {:ok, candidate} <- NetworkPort.update_property(port, property, value) do
      ...>       context = Context.new({:property_write, property, nil, nil})
      ...>       Lifecycle.prepare_write(port, candidate, context)
      ...>     end
      ...>   else
      ...>     {:error, {:property, :write_access_denied}}
      ...>   end
      ...> end
      iex> prepare_write.(port, :ip_address, {192, 0, 2, 20})
      {:error, {:property, :write_access_denied}}
      iex> {:ok, candidate} = prepare_write.(port, :description, "Administration network")
      iex> NetworkPort.get_property(candidate, :description)
      {:ok, "Administration network"}
      iex> NetworkPort.get_property(port, :ip_address)
      {:ok, {192, 0, 2, 10}}
      iex> {:ok, observed} = NetworkPort.update_operating_property(port, :ip_address, {192, 0, 2, 30})
      iex> NetworkPort.get_property(observed, :ip_address)
      {:ok, {192, 0, 2, 30}}
      iex> observed.changes_pending
      false

  ### Example

  Stage a network number, then discard the pending change through the command
  property. The call to execute represents the step after the host commits and
  acknowledges the command write.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.NetworkPort
      iex> {:ok, port} = NetworkPort.create(1, "Virtual port", %{
      ...>   network_type: :virtual,
      ...>   protocol_level: :bacnet_application,
      ...>   mac_address: <<1>>,
      ...>   network_number: 7,
      ...>   network_number_quality: :configured
      ...> }, supports_command_execution: true)
      iex> {:ok, staged} = NetworkPort.update_property(port, :network_number, 8)
      iex> staged.network_number
      8
      iex> {:ok, active} = NetworkPort.active_configuration(staged)
      iex> active.network_number
      7
      iex> {:ok, candidate} = NetworkPort.update_property(staged, :command, :discard_changes)
      iex> write = Context.new({:property_write, :command, nil, nil})
      iex> {:ok, accepted} = Lifecycle.prepare_write(staged, candidate, write)
      iex> accepted.command
      :discard_changes
      iex> {:ok, finished} = Lifecycle.execute(accepted, write)
      iex> {finished.object.network_number, finished.object.changes_pending, finished.object.command}
      {7, false, :idle}

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
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ForeignDeviceTableEntry
  alias BACnet.Protocol.HostNPort
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.RouterEntry
  alias BACnet.Protocol.VmacEntry

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Network Port object.

  Supports enabling intrinsic reporting via `intrinsic_reporting`.

  In addition to the common options, Network Port supports:
  - `supports_command_execution` - Selects the Command property.
  - `network_port_runtime` - Binds host actions to this port.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | {:supports_command_execution, boolean()}
          | {:network_port_runtime, runtime()}
          | common_object_opts()

  @typedoc """
  A command defined by Clause 12.56.14 or a vendor command in the range 128 to 255.
  Enable `:allow_numeric_constants` to supply a vendor command.
  """
  @type port_command :: Constants.network_port_command() | 128..255

  @typedoc """
  Host actions keyed by command or by `:out_of_service`. The port argument carries
  the selected command or the requested out-of-service state. Return `:ok` when the
  object may accept its next write, or an error with the reason the action failed.
  """
  @type runtime :: %{
          optional(port_command() | :out_of_service) => (port :: t() ->
                                                           :ok | {:error, reason :: term()})
        }

  @typedoc """
  The last command and its outcome, returned as lifecycle state after execution.
  """
  @type command_result ::
          {:command_result, command :: port_command(),
           outcome :: :ok | {:error, reason :: term()}}

  @typedoc """
  A completed configuration activation or a network number learned from a received
  Network-Number-Is message. The boolean is the sender's configured flag.
  """
  @type port_event ::
          {:configuration_activated, :activate_changes | :warmstart}
          | {:network_number_learned, network_number :: 1..65_534, configured? :: boolean()}

  @typedoc """
  Represents a Network Port object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.
  Many properties are conditional on `network_type` and `protocol_level`.
  """
  bac_object Constants.macro_assert_name(:object_type, :network_port) do
    services(intrinsic: true)

    # Common / always present properties
    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:event_state, Constants.event_state(), intrinsic: true, default: :normal)
    field(:out_of_service, boolean(), required: true, default: false)

    field(:reliability, Constants.reliability(), required: true, default: :no_fault_detected)

    field(:reliability_evaluation_inhibit, boolean())

    field(:network_type, Constants.network_type(), required: true, readonly: true)

    field(:protocol_level, Constants.protocol_level(),
      required: true,
      readonly: true,
      validator_fun: fn value, object ->
        (value != Constants.macro_assert_name(:network_type, :non_bacnet) and
           value != Constants.macro_by_name(:network_type, :non_bacnet)) or
          !!object._metadata.remote_object
      end
    )

    field(:reference_port, non_neg_integer())

    field(:network_number, ApplicationTags.unsigned16(),
      default: 0,
      annotation: [
        required_when: fn props, _meta ->
          Map.get(props, :protocol_level) in [:bacnet_application, :non_bacnet_application]
        end
      ]
    )

    field(:network_number_quality, Constants.network_number_quality(),
      readonly: true,
      default: :unknown,
      annotation: [
        required_when: fn props, _meta ->
          Map.get(props, :protocol_level) in [:bacnet_application, :non_bacnet_application]
        end
      ]
    )

    field(:changes_pending, boolean(), required: true, readonly: true, default: false)

    field(:command, Constants.network_port_command(),
      default: :idle,
      annotation: [required_when: {:opts, :supports_command_execution}]
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
        end
      ]
    )

    field(:apdu_length, non_neg_integer(),
      readonly: true,
      default: 1476,
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :protocol_level) in [:bacnet_application, :non_bacnet_application]
        end
      ]
    )

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

    field(:link_speeds, BACnetArray.t(float()), readonly: true, default: BACnetArray.new())

    field(:link_speed_autonegotiate, boolean(), default: false)

    field(:network_interface_name, String.t(), readonly: true)

    # BACnet/IP (IPv4) related properties
    field(:bacnet_ip_mode, Constants.ip_mode(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    field(:bacnet_ip_udp_port, ApplicationTags.unsigned16(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    field(:ip_address, :inet.ip4_address(),
      annotation: [
        decoder: &decode_ipv4_address(:ip_address, &1),
        encoder: &encode_ipv4_address(:ip_address, &1),
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    field(:ip_subnet_mask, :inet.ip4_address(),
      annotation: [
        decoder: &decode_ipv4_address(:ip_subnet_mask, &1),
        encoder: &encode_ipv4_address(:ip_subnet_mask, &1),
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    field(:ip_default_gateway, :inet.ip4_address(),
      annotation: [
        decoder: &decode_ipv4_address(:ip_default_gateway, &1),
        encoder: &encode_ipv4_address(:ip_default_gateway, &1),
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    # Property is required when the port is IPv4, protocol level is application and port supports multicast
    field(:bacnet_ip_multicast_address, :inet.ip4_address(),
      annotation: [
        decoder: &decode_ipv4_address(:bacnet_ip_multicast_address, &1),
        encoder: &encode_ipv4_address(:bacnet_ip_multicast_address, &1)
        # bacstack does not support multicast - so no annotation required_when
      ]
    )

    field(:ip_dns_server, BACnetArray.t(:inet.ip4_address()),
      annotation: [
        decoder: &decode_ipv4_address(:ip_dns_server, &1),
        encoder: &encode_ipv4_address(:ip_dns_server, &1),
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    field(:ip_dhcp_enable, boolean(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv4
        end
      ]
    )

    field(:ip_dhcp_server, :inet.ip4_address(),
      readonly: true,
      annotation: [
        decoder: &decode_ipv4_address(:ip_dhcp_server, &1),
        encoder: &encode_ipv4_address(:ip_dhcp_server, &1)
      ]
    )

    field(:ip_dhcp_lease_time, non_neg_integer(), readonly: true)
    field(:ip_dhcp_lease_time_remaining, non_neg_integer(), readonly: true)

    # Required to be present if the Network_Type is IPV4, Protocol_Level is BACNET_APPLICATION, and the device is
    # capable of communicating through a NAT router as described in Clause J.7.8.
    field(:bacnet_ip_nat_traversal, boolean())

    # Required if Network_Type is IPV4, Protocol_Level is BACNET_APPLICATION, and the device is configured to
    # communicate through a NAT router as described in Clause J.7.8
    field(:bacnet_ip_global_address, HostNPort.t(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :bacnet_ip_nat_traversal) == true
        end
      ]
    )

    # BBMD / Foreign Device
    field(:bbmd_broadcast_distribution_table, [BroadcastDistributionTableEntry.t()],
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :bacnet_ip_mode) == :bbmd
        end
      ]
    )

    field(:bbmd_accept_fd_registrations, boolean(),
      implicit_relationship: :bbmd_broadcast_distribution_table
    )

    field(:bbmd_foreign_device_table, [ForeignDeviceTableEntry.t()],
      readonly: true,
      implicit_relationship: :bbmd_broadcast_distribution_table
    )

    field(:fd_bbmd_address, HostNPort.t(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :bacnet_ip_mode) == :foreign
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
          Map.get(props, :network_type) == :ipv6 and
            Map.get(props, :protocol_level) == :bacnet_application
        end
      ]
    )

    field(:bacnet_ipv6_udp_port, ApplicationTags.unsigned16(),
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6 and
            Map.get(props, :protocol_level) == :bacnet_application
        end
      ]
    )

    field(:bacnet_ipv6_multicast_address, {:inet.ip6_address(), :inet.port_number()},
      bac_type:
        {:with_validator, :any,
         fn
           {ip, port} ->
             ipv6_address?(ip) and is_integer(port) and port >= 0 and port <= 65_535

           _ip ->
             false
         end},
      annotation: [
        decoder: &decode_ipv6_address(:bacnet_ipv6_multicast_address, &1),
        encoder: &encode_ipv6_address(:bacnet_ipv6_multicast_address, &1),
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6 and
            Map.get(props, :protocol_level) == :bacnet_application
        end
      ]
    )

    field(:ipv6_address, :inet.ip6_address(),
      annotation: [
        decoder: &decode_ipv6_address(:ipv6_address, &1),
        encoder: &encode_ipv6_address(:ipv6_address, &1),
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:ipv6_prefix_length, 0..128,
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:ipv6_default_gateway, :inet.ip6_address(),
      annotation: [
        decoder: &decode_ipv6_address(:ipv6_default_gateway, &1),
        encoder: &encode_ipv6_address(:ipv6_default_gateway, &1),
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:ipv6_dns_server, BACnetArray.t(:inet.ip6_address()),
      default: BACnetArray.new(),
      annotation: [
        decoder: &decode_ipv6_address(:ipv6_dns_server, &1),
        encoder: &encode_ipv6_address(:ipv6_dns_server, &1),
        required_when: fn props, _object ->
          Map.get(props, :network_type) == :ipv6
        end
      ]
    )

    field(:ipv6_auto_addressing_enable, boolean(),
      annotation: [
        # required_when: fn props, object ->
        #   Map.get(props, :network_type) == :ipv6 and Keyword.get(object._metadata.other, :supports_ipv6_auto_address_assignment) == true
        # end
      ]
    )

    field(:ipv6_dhcp_lease_time, non_neg_integer(), readonly: true)
    field(:ipv6_dhcp_lease_time_remaining, non_neg_integer(), readonly: true)

    field(:ipv6_dhcp_server, :inet.ip6_address(),
      annotation: [
        decoder: &decode_ipv6_address(:ipv6_dhcp_server, &1),
        encoder: &encode_ipv6_address(:ipv6_dhcp_server, &1)
      ]
    )

    field(:ipv6_zone_index, String.t(),
      annotation: [
        # required_when: fn props, _object ->
        #   Map.get(props, :network_type) == :ipv6
        # end
      ]
    )

    # MS/TP related

    # Required to be present and writable if Network_Type is MSTP, the device is an MS/TP master node,
    # and the device supports the WriteProperty service
    field(:max_master, 0..127,
      implicit_relationship: :max_info_frames,
      bac_type: {:with_validator, :unsigned_integer, &(&1 >= 0 and &1 <= 127)},
      annotation: [
        # required_when: fn props, _object ->
        #   Map.get(props, :network_type) == :mstp and
        #     Map.get(props, :protocol_level) == :bacnet_application
        # end
      ]
    )

    # Required to be present and writable if Network_Type is MSTP, the device is an MS/TP master node,
    # and the device supports the WriteProperty service
    field(:max_info_frames, 1..255,
      bac_type: {:with_validator, :unsigned_integer, &(&1 >= 1 and &1 <= 255)},
      annotation: [
        # required_when: fn props, _object ->
        #   Map.get(props, :network_type) == :mstp
        # end
      ]
    )

    # Properties for slave proxy functionality (per-se not provided by this bacstack)

    # Required to be present and writable if Network_Type is MSTP,
    # and the device is capable of being a Slave-Proxy device
    field(:manual_slave_address_binding, [AddressBinding.t()])

    # Required if Network_Type is MSTP, Protocol_Level is BACNET_APPLICATION,
    # and the device is capable of being a Slave-Proxy device
    field(:slave_address_binding, [AddressBinding.t()], readonly: true)

    # Required to be present and writable if Network_Type is MSTP,
    # and the device is capable of being a Slave-Proxy device
    field(:slave_proxy_enable, boolean())
    # Required if Network_Type is MSTP, Protocol_Level is BACNET_APPLICATION,
    # and the device is capable of being a Slave-Proxy device that implements automatic discovery of slaves
    field(:auto_slave_discovery, boolean(), implicit_relationship: :slave_proxy_enable)

    # Virtual MAC (for certain network types that require VMAC)
    # Required if the network represented by this object requires VMAC addressing
    field(:virtual_mac_address_table, [VmacEntry.t()],
      annotation: [
        required_when: fn props, _object ->
          Map.get(props, :network_type) in [:ipv6, :sc, :zigbee]
        end
      ]
    )

    field(:routing_table, [RouterEntry.t()], readonly: true)
  end

  @pending_properties [
    :bacnet_ip_global_address,
    :bacnet_ip_mode,
    :bacnet_ip_multicast_address,
    :bacnet_ip_nat_traversal,
    :bacnet_ip_udp_port,
    :bacnet_ipv6_mode,
    :bacnet_ipv6_multicast_address,
    :bacnet_ipv6_udp_port,
    :bbmd_accept_fd_registrations,
    :bbmd_broadcast_distribution_table,
    :fd_bbmd_address,
    :fd_subscription_lifetime,
    :ip_address,
    :ip_default_gateway,
    :ip_dhcp_enable,
    :ip_dns_server,
    :ip_subnet_mask,
    :ipv6_address,
    :ipv6_auto_addressing_enable,
    :ipv6_default_gateway,
    :ipv6_dns_server,
    :ipv6_prefix_length,
    :ipv6_zone_index,
    :link_speed,
    :link_speed_autonegotiate,
    :mac_address,
    :max_info_frames,
    :max_master,
    :network_interface_name,
    :network_number,
    :reference_port,
    :virtual_mac_address_table
  ]
  @configuration_properties [:network_number_quality | @pending_properties]
  @commands [
    :discard_changes,
    :renew_fd_registration,
    :restart_slave_discovery,
    :renew_dhcp,
    :restart_autonegotiation,
    :disconnect,
    :restart_port
  ]

  @spec update_property(t(), Constants.property_identifier(), term()) ::
          {:ok, t()} | property_update_error()
  def update_property(%__MODULE__{} = object, property, value) when is_atom(property) do
    with {:ok, updated} <- super(object, property, value) do
      if is_nil(object._metadata.remote_object) and property in @pending_properties do
        {:ok, stage_configuration(object, updated, property)}
      else
        {:ok, updated}
      end
    end
  end

  @doc """
  Returns the active values of settings that participate in pending changes, along
  with the network number quality. During pending changes, the corresponding
  property reads on the object return the staged values.
  """
  @spec active_configuration(t()) :: {:ok, map()} | {:error, term()}
  def active_configuration(object)

  def active_configuration(%__MODULE__{_metadata: %{remote_object: remote}})
      when not is_nil(remote),
      do: {:error, :operation_not_available_for_remote_objects}

  def active_configuration(%__MODULE__{} = object) do
    with {:ok, originals} <- pending_originals(object) do
      visible =
        Map.take(object, Enum.filter(@configuration_properties, &has_property?(object, &1)))

      {:ok, Map.merge(visible, originals)}
    end
  end

  @doc """
  Records a property value reported by the operating port without staging a write.

  When that property already has a staged write, its active value changes and
  the pending value remains visible through `get_property/2`. The host should
  call this for observations such as DHCP addresses, actual link speed and
  live tables. Command and Changes_Pending are managed by the lifecycle.
  """
  @spec update_operating_property(t(), Constants.property_identifier(), term()) ::
          {:ok, t()} | {:error, term()}
  def update_operating_property(object, property, value)

  def update_operating_property(
        %__MODULE__{_metadata: %{remote_object: remote}},
        _property,
        _value
      )
      when not is_nil(remote),
      do: {:error, :operation_not_available_for_remote_objects}

  def update_operating_property(%__MODULE__{}, property, _value)
      when property in [:command, :changes_pending, :out_of_service],
      do: {:error, {:property, :write_access_denied}}

  def update_operating_property(%__MODULE__{} = object, property, value) do
    with {:ok, originals} <- pending_originals(object),
         {:ok, updated} <-
           ObjectOperations.update_property(
             object_contract(),
             object,
             property,
             value,
             operation_hooks()
           ) do
      if Map.has_key?(originals, property) do
        {:ok,
         put_originals(object, Map.replace!(originals, property, Map.fetch!(updated, property)))}
      else
        {:ok, updated}
      end
    end
  end

  @doc """
  Checks a proposed Network Port write against the port's access rules.

  Validates command writes and changes to port configuration before the host
  commits the candidate. Pending configuration is applied during execution
  of the relevant command.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote),
      do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(
        %__MODULE__{} = original,
        %__MODULE__{} = candidate,
        %Context{trigger: {source, _property, _index, _priority}} = context
      )
      when source in [:property_write, :application_write] do
    with :ok <- validate_write(original, candidate, Context.written_property(context)) do
      {:ok, candidate}
    end
  end

  @doc """
  Executes a Network Port command or an Out_Of_Service update.

  Initialization resets a selected Command to idle. Committed commands
  apply or discard pending configuration as appropriate and may invoke the
  configured network runtime. Each successful local step evaluates
  reliability reporting.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote),
      do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    context = Context.normalize_write(context)

    with {:ok, result} <- execute_port(object, context) do
      {:ok, IntrinsicReporting.evaluate(result, context, EventAlgorithms.None, [])}
    end
  end

  @spec execute_port(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  defp execute_port(object, context)

  defp execute_port(
         %__MODULE__{} = object,
         %Context{trigger: {source, :command, nil, nil}} = context
       )
       when source in [:property_write, :application_write] do
    execute_command(object, context)
  end

  defp execute_port(
         %__MODULE__{} = object,
         %Context{trigger: {source, :out_of_service, nil, nil}} = context
       )
       when source in [:property_write, :application_write] do
    with :ok <- invoke_runtime(object, :out_of_service) do
      port_result(object, context)
    end
  end

  defp execute_port(%__MODULE__{} = object, %Context{trigger: :initialization} = context) do
    port_result(put_selected(object, :command, :idle), context)
  end

  defp execute_port(%__MODULE__{} = object, %Context{trigger: :periodic} = context) do
    with {:ok, updated} <- apply_event(object, context.options[:network_port_event]) do
      port_result(updated, context)
    end
  end

  defp execute_port(%__MODULE__{} = object, %Context{} = context),
    do: port_result(object, context)

  @spec port_result(t(), Context.t()) :: {:ok, Result.t(t())}
  defp port_result(object, context) do
    {:ok, %Result{object: object, state: context.state, next_execution: nil}}
  end

  @spec stage_configuration(t(), t(), Constants.property_identifier()) :: t()
  defp stage_configuration(original, updated, property) do
    properties =
      if property == :network_number, do: [property, :network_number_quality], else: [property]

    updated =
      case pending_originals(original) do
        {:ok, originals} ->
          selected = Enum.filter(properties, &has_property?(original, &1))
          put_originals(updated, Map.merge(Map.take(original, selected), originals))

        {:error, :missing_active_configuration} ->
          updated
      end

    if property == :network_number do
      quality = if updated.network_number == 0, do: :unknown, else: :configured
      put_selected(%{updated | changes_pending: true}, :network_number_quality, quality)
    else
      %{updated | changes_pending: true}
    end
  end

  @spec pending_originals(t()) :: {:ok, map()} | {:error, :missing_active_configuration}
  defp pending_originals(object)

  defp pending_originals(%__MODULE__{changes_pending: true, _metadata: %{other: options}}) do
    case Map.fetch(options, :network_port_pending_originals) do
      {:ok, originals} when is_map(originals) -> {:ok, originals}
      _other -> {:error, :missing_active_configuration}
    end
  end

  defp pending_originals(%__MODULE__{}), do: {:ok, %{}}

  @spec put_originals(t(), map()) :: t()
  defp put_originals(object, originals) do
    put_in(object._metadata.other[:network_port_pending_originals], originals)
  end

  @spec clear_pending(t()) :: t()
  defp clear_pending(object) do
    update_in(
      %{object | changes_pending: false}._metadata.other,
      &Map.delete(&1, :network_port_pending_originals)
    )
  end

  @spec put_selected(t(), Constants.property_identifier(), term()) :: t()
  defp put_selected(object, property, value) do
    if has_property?(object, property), do: %{object | property => value}, else: object
  end

  @spec validate_write(t(), t(), Constants.property_identifier()) :: :ok | {:error, term()}
  defp validate_write(original, candidate, property)

  defp validate_write(original, candidate, :command) do
    if original.command in [nil, :idle],
      do: validate_command(original, candidate.command),
      else: {:error, {:object, :busy}}
  end

  defp validate_write(_original, _candidate, :changes_pending),
    do: {:error, {:property, :write_access_denied}}

  defp validate_write(_original, candidate, :out_of_service) do
    with {:ok, _handler} <- runtime_action(candidate, :out_of_service), do: :ok
  end

  defp validate_write(%__MODULE__{network_type: :ptp}, _candidate, :network_number),
    do: {:error, {:property, :write_access_denied}}

  defp validate_write(_original, candidate, :network_number) do
    if candidate.network_number in 0..65_534,
      do: :ok,
      else: {:error, {:property, :value_out_of_range}}
  end

  defp validate_write(%__MODULE__{link_speed_autonegotiate: true}, _candidate, :link_speed),
    do: {:error, {:property, :write_access_denied}}

  defp validate_write(original, candidate, :link_speed) do
    case original[:link_speeds] do
      %BACnetArray{} = speeds ->
        if candidate.link_speed in BACnetArray.to_list(speeds),
          do: :ok,
          else: {:error, {:property, :value_out_of_range}}

      nil ->
        {:error, {:property, :write_access_denied}}
    end
  end

  defp validate_write(original, candidate, :reference_port) do
    if candidate.reference_port in 0..4_194_303 and
         candidate.reference_port != original.object_instance,
       do: :ok,
       else: {:error, {:property, :value_out_of_range}}
  end

  defp validate_write(_original, _candidate, _property), do: :ok

  @spec validate_command(t(), port_command() | nil) :: :ok | {:error, term()}
  defp validate_command(object, command) do
    cond do
      not has_property?(object, :command) ->
        {:error, {:property, :unknown_property}}

      object.out_of_service and command not in [:restart_port, :disconnect, :discard_changes] ->
        {:error, {:property, :value_out_of_range}}

      object.changes_pending and command != :discard_changes ->
        {:error, {:property, :invalid_value_in_this_state}}

      command == :discard_changes ->
        case pending_originals(object) do
          {:ok, _originals} ->
            :ok

          {:error, :missing_active_configuration} ->
            {:error, {:property, :optional_functionality_not_supported}}
        end

      command in @commands ->
        with :ok <- validate_command_configuration(object, command),
             {:ok, _handler} <- runtime_action(object, command),
             do: :ok

      is_integer(command) and command in 128..255 ->
        case runtime_action(object, command) do
          {:ok, _handler} -> :ok
          {:error, _reason} -> {:error, {:property, :value_out_of_range}}
        end

      true ->
        {:error, {:property, :value_out_of_range}}
    end
  end

  @spec validate_command_configuration(t(), port_command()) :: :ok | {:error, term()}
  defp validate_command_configuration(object, command)

  defp validate_command_configuration(object, :renew_fd_registration) do
    case {object.network_type, object[:bacnet_ip_mode], object[:bacnet_ipv6_mode]} do
      {:ipv4, :foreign, _mode} -> :ok
      {:ipv6, _mode, :foreign} -> :ok
      _other -> {:error, {:property, :value_out_of_range}}
    end
  end

  defp validate_command_configuration(object, :renew_dhcp) do
    case {object.network_type, object[:ip_dhcp_enable], object[:ipv6_auto_addressing_enable]} do
      {:ipv4, true, _enable} -> :ok
      {:ipv6, _enable, true} -> :ok
      {:ipv4, false, _enable} -> {:error, {:property, :value_out_of_range}}
      {:ipv4, nil, _enable} -> {:error, {:property, :optional_functionality_not_supported}}
      {:ipv6, _enable, _automatic} -> {:error, {:property, :optional_functionality_not_supported}}
      _other -> {:error, {:property, :value_out_of_range}}
    end
  end

  defp validate_command_configuration(object, :restart_autonegotiation) do
    case object[:link_speed_autonegotiate] do
      true -> :ok
      false -> {:error, {:property, :value_out_of_range}}
      nil -> {:error, {:property, :optional_functionality_not_supported}}
    end
  end

  defp validate_command_configuration(%__MODULE__{network_type: :mstp}, :restart_slave_discovery),
    do: :ok

  defp validate_command_configuration(%__MODULE__{network_type: :ptp}, :disconnect), do: :ok
  defp validate_command_configuration(_object, :restart_port), do: :ok

  defp validate_command_configuration(_object, _command),
    do: {:error, {:property, :value_out_of_range}}

  @spec runtime_action(t(), port_command() | :out_of_service) ::
          {:ok, (t() -> :ok | {:error, term()})} | {:error, term()}
  defp runtime_action(object, action) do
    case object._metadata.other[:network_port_runtime] do
      %{^action => handler} when is_function(handler, 1) -> {:ok, handler}
      _other -> {:error, {:property, :optional_functionality_not_supported}}
    end
  end

  @spec invoke_runtime(t(), port_command() | :out_of_service) :: :ok | {:error, term()}
  defp invoke_runtime(object, action) do
    with {:ok, handler} <- runtime_action(object, action), do: handler.(object)
  end

  @spec execute_command(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  defp execute_command(object, context)

  defp execute_command(%__MODULE__{command: command} = object, context)
       when command in [nil, :idle] do
    {:ok, %Result{object: object, state: context.state, next_execution: nil}}
  end

  defp execute_command(%__MODULE__{command: :discard_changes} = object, _context) do
    with {:ok, originals} <- pending_originals(object) do
      updated =
        object
        |> struct!(originals)
        |> clear_pending()

      {:ok, command_result(updated, :discard_changes, :ok)}
    end
  end

  defp execute_command(%__MODULE__{command: command} = object, _context) do
    with :ok <- validate_command(object, command),
         outcome = invoke_runtime(object, command),
         {:ok, updated} <- update_command_reliability(object, command, outcome) do
      {:ok, command_result(updated, command, outcome)}
    end
  end

  @spec command_result(t(), port_command(), :ok | {:error, term()}) :: Result.t(t())
  defp command_result(object, command, outcome) do
    %Result{
      object: %{object | command: :idle},
      state: {:command_result, command, outcome},
      next_execution: nil
    }
  end

  @spec update_command_reliability(t(), port_command(), :ok | {:error, term()}) ::
          {:ok, t()} | {:error, term()}
  defp update_command_reliability(object, command, outcome) do
    failure = command_failure(command)

    cond do
      failure == nil or not has_property?(object, :reliability) or
          object[:reliability_evaluation_inhibit] == true ->
        {:ok, object}

      outcome == :ok and object.reliability == failure ->
        update_property(object, :reliability, :no_fault_detected)

      match?({:error, _reason}, outcome) ->
        update_property(object, :reliability, failure)

      true ->
        {:ok, object}
    end
  end

  @spec command_failure(port_command()) :: Constants.reliability() | nil
  defp command_failure(command)

  defp command_failure(:renew_fd_registration), do: :renew_fd_registration_failure
  defp command_failure(:renew_dhcp), do: :renew_dhcp_failure
  defp command_failure(:restart_autonegotiation), do: :restart_auto_negotiation_failure
  defp command_failure(:restart_port), do: :restart_failure
  defp command_failure(command) when is_integer(command), do: :proprietary_command_failure
  defp command_failure(_command), do: nil

  @spec apply_event(t(), term()) :: {:ok, t()} | {:error, term()}
  defp apply_event(object, event)

  defp apply_event(object, nil), do: {:ok, object}

  defp apply_event(object, {:configuration_activated, reason})
       when reason in [:activate_changes, :warmstart],
       do: {:ok, clear_pending(object)}

  defp apply_event(object, {:network_number_learned, number, configured})
       when number in 1..65_534 and is_boolean(configured) do
    with {:ok, active} <- active_configuration(object) do
      if active[:network_number] == 0 and object.network_type != :ptp do
        quality = if configured, do: :learned_configured, else: :learned

        with {:ok, updated} <- update_operating_property(object, :network_number, number) do
          update_operating_property(updated, :network_number_quality, quality)
        end
      else
        {:ok, object}
      end
    end
  end

  defp apply_event(_object, _event), do: {:error, :invalid_network_port_event}

  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
  def property_writable?(%__MODULE__{} = object, property) when is_atom(property) do
    case property do
      :network_number ->
        object.network_type != :ptp and super(object, property)

      :link_speed ->
        object[:link_speed_autonegotiate] != true and super(object, property)

      :ip_address ->
        object[:ip_dhcp_enable] != true

      :ip_subnet_mask ->
        object[:ip_dhcp_enable] != true

      :ip_default_gateway ->
        object[:ip_dhcp_enable] != true

      :ip_dns_server ->
        object[:ip_dhcp_enable] != true

      :ipv6_address ->
        object[:ipv6_auto_addressing_enable] != true

      :ipv6_prefix_length ->
        object[:ipv6_auto_addressing_enable] != true

      :ipv6_default_gateway ->
        object[:ipv6_auto_addressing_enable] != true

      :ipv6_dns_server ->
        object[:ipv6_auto_addressing_enable] != true

      :mac_address ->
        object.network_type not in [
          # BACnet/IP
          :ipv4,
          # VMAC Addressing
          :ipv6,
          :sc,
          :zigbee
        ]

      _term ->
        super(object, property)
    end
  end

  defp decode_ipv4_address(_property, %Encoding{encoding: :primitive, type: :octet_string} = tags) do
    case tags.value do
      # Parse empty string as unused
      <<>> ->
        {:ok, {0, 0, 0, 0}}

      <<ip_a, ip_b, ip_c, ip_d>> ->
        {:ok, {ip_a, ip_b, ip_c, ip_d}}

      _other ->
        {:error, :invalid_tags}
    end
  end

  defp encode_ipv4_address(_property, {ip_a, ip_b, ip_c, ip_d}) do
    {:ok, {:octet_string, <<ip_a, ip_b, ip_c, ip_d>>}}
  end

  defp encode_ipv4_address(_property, {{ip_a, ip_b, ip_c, ip_d}, port})
       when is_integer(port) and port >= 0 and port <= 65_535 do
    {:ok, {:octet_string, <<ip_a, ip_b, ip_c, ip_d, port::size(16)>>}}
  end

  defp encode_ipv4_address(_property, _data), do: {:error, :invalid_value}

  # defp ipv4_address?({ip_a, ip_b, ip_c, ip_d})
  #      when is_integer(ip_a) and ip_a in 0..255//1 and
  #             is_integer(ip_b) and ip_b in 0..255//1 and is_integer(ip_c) and ip_c in 0..255//1 and
  #             is_integer(ip_d) and ip_d in 0..255//1,
  #      do: true

  # defp ipv4_address?(_ip), do: false

  defp decode_ipv6_address(_property, %Encoding{encoding: :primitive, type: :octet_string} = tags) do
    case tags.value do
      # Parse empty string as unused
      <<>> ->
        {:ok, {{0, 0, 0, 0, 0, 0, 0, 0}, 0}}

      <<ip_a::size(16), ip_b::size(16), ip_c::size(16), ip_d::size(16), ip_e::size(16),
        ip_f::size(16), ip_g::size(16), ip_h::size(16), port::size(16)>> ->
        {:ok, {{ip_a, ip_b, ip_c, ip_d, ip_e, ip_f, ip_g, ip_h}, port}}

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

  defp encode_ipv6_address(_property, {{ip_a, ip_b, ip_c, ip_d, ip_e, ip_f, ip_g, ip_h}, port})
       when is_integer(port) and port >= 0 and port <= 65_535 do
    {:ok,
     {:octet_string,
      <<ip_a::size(16), ip_b::size(16), ip_c::size(16), ip_d::size(16), ip_e::size(16),
        ip_f::size(16), ip_g::size(16), ip_h::size(16), port::size(16)>>}}
  end

  defp encode_ipv6_address(_property, _data), do: {:error, :invalid_value}

  defp ipv6_address?({ip_a, ip_b, ip_c, ip_d, ip_e, ip_f, ip_g, ip_h})
       when is_integer(ip_a) and ip_a in 0..65_535//1 and
              is_integer(ip_b) and ip_b in 0..65_535//1 and is_integer(ip_c) and
              ip_c in 0..65_535//1 and
              is_integer(ip_d) and ip_d in 0..65_535//1 and is_integer(ip_e) and
              ip_e in 0..65_535//1 and is_integer(ip_f) and ip_f in 0..65_535//1 and
              is_integer(ip_g) and ip_g in 0..65_535//1 and is_integer(ip_h) and
              ip_h in 0..65_535//1,
       do: true

  defp ipv6_address?(_ip), do: false
end
