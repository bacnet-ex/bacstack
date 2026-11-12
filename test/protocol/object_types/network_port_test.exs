defmodule BACnet.Test.Protocol.ObjectTypes.NetworkPortTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.HostNPort
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.NetworkPort

  use ExUnit.Case, async: true

  doctest NetworkPort

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_network_port

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "network configuration updates mark changes pending while descriptive updates do not" do
    {:ok, object} =
      NetworkPort.create(1, "port", %{
        network_type: :ptp,
        protocol_level: :physical,
        description: "old",
        network_number: 1
      })

    refute object.changes_pending

    assert {:ok, %NetworkPort{description: "new", changes_pending: false}} =
             NetworkPort.update_property(object, :description, "new")

    assert {:ok, %NetworkPort{network_number: 2, changes_pending: true}} =
             NetworkPort.update_property(object, :network_number, 2)

    assert {:error, {:invalid_property_type, :network_number}} =
             NetworkPort.update_property(object, :network_number, -1)
  end

  test "reports changes in port reliability without an offnormal algorithm" do
    assert {:ok, object} =
             NetworkPort.create(
               1,
               "Port",
               %{
                 network_type: :ptp,
                 protocol_level: :physical,
                 reliability: :configuration_error
               },
               intrinsic_reporting: true
             )

    assert {:ok, fault} = NetworkPort.execute(object, Context.new(:initialization))

    assert %{
             event_type: :change_of_reliability,
             to_state: :fault,
             event_values: %{property_values: []}
           } = EventReporting.transition(fault)

    assert {:ok, object} =
             NetworkPort.update_property(fault.object, :reliability, :no_fault_detected)

    assert {:ok, normal} = NetworkPort.execute(object, Context.new(:periodic, state: fault.state))

    assert %{event_type: :change_of_reliability, to_state: :normal} =
             EventReporting.transition(normal)
  end

  describe "pending configuration" do
    test "discard restores the active settings across multiple writes and keeps live updates" do
      port = port(%{network_number: 7, network_number_quality: :configured, description: "old"})
      assert port.command == :idle
      assert {:ok, staged} = NetworkPort.update_property(port, :network_number, 8)
      assert {:ok, staged} = NetworkPort.update_property(staged, :network_number, 0)
      assert {:ok, staged} = NetworkPort.update_property(staged, :mac_address, <<2>>)
      assert {:ok, staged} = NetworkPort.update_property(staged, :description, "current")

      assert staged.network_number_quality == :unknown

      assert {:ok, %{network_number: 7, network_number_quality: :configured, mac_address: <<1>>}} =
               NetworkPort.active_configuration(staged)

      assert {:ok, observed} = NetworkPort.update_operating_property(staged, :mac_address, <<3>>)
      assert observed.mac_address == <<2>>
      assert {:ok, %{mac_address: <<3>>}} = NetworkPort.active_configuration(observed)

      assert {:ok, accepted, context} = prepare(observed, :command, :discard_changes)

      assert {:ok, %Result{object: restored, state: {:command_result, :discard_changes, :ok}}} =
               NetworkPort.execute(accepted, context)

      assert restored.command == :idle
      refute restored.changes_pending
      assert restored.network_number == 7
      assert restored.network_number_quality == :configured
      assert restored.mac_address == <<3>>
      assert restored.description == "current"
    end

    test "a completed device activation promotes the staged values" do
      port = port(%{network_number: 7, network_number_quality: :learned})
      assert {:ok, staged, _context} = prepare(port, :network_number, 8)
      assert staged.network_number_quality == :configured
      assert staged.changes_pending

      assert {:ok, %Result{object: ^staged}} =
               NetworkPort.execute(staged, Context.new(:initialization))

      for reason <- [:activate_changes, :warmstart] do
        context =
          Context.new(:periodic,
            options: [network_port_event: {:configuration_activated, reason}]
          )

        assert {:ok, %Result{object: active}} = NetworkPort.execute(staged, context)
        refute active.changes_pending

        assert {:ok, %{network_number: 8, network_number_quality: :configured}} =
                 NetworkPort.active_configuration(active)
      end

      assert NetworkPort.execute(
               staged,
               Context.new(:periodic,
                 options: [network_port_event: {:configuration_activated, :coldstart}]
               )
             ) == {:error, :invalid_network_port_event}
    end

    test "an operating update is validated and leaves a clean port clean" do
      port = port()
      assert {:ok, observed} = NetworkPort.update_operating_property(port, :mac_address, <<3>>)
      assert observed.mac_address == <<3>>
      refute observed.changes_pending

      assert NetworkPort.update_operating_property(observed, :mac_address, 3) ==
               {:error, {:invalid_property_type, :mac_address}}

      assert NetworkPort.update_operating_property(observed, :changes_pending, true) ==
               {:error, {:property, :write_access_denied}}
    end

    test "learning an active network number preserves a staged network number" do
      port = port(%{network_number: 0, network_number_quality: :unknown})

      for {flag, quality} <- [{false, :learned}, {true, :learned_configured}] do
        event =
          Context.new(:periodic,
            options: [network_port_event: {:network_number_learned, 7, flag}]
          )

        assert {:ok, %Result{object: learned}} = NetworkPort.execute(port, event)
        assert learned.network_number == 7
        assert learned.network_number_quality == quality
        refute learned.changes_pending
      end

      assert {:ok, staged} = NetworkPort.update_property(port, :network_number, 8)

      event =
        Context.new(:periodic, options: [network_port_event: {:network_number_learned, 7, true}])

      assert {:ok, %Result{object: learned}} = NetworkPort.execute(staged, event)
      assert learned.network_number == 8
      assert learned.network_number_quality == :configured

      assert {:ok, %{network_number: 7, network_number_quality: :learned_configured}} =
               NetworkPort.active_configuration(learned)

      later =
        Context.new(:periodic, options: [network_port_event: {:network_number_learned, 9, false}])

      assert {:ok, %Result{object: ^learned}} = NetworkPort.execute(learned, later)
    end

    test "an existing pending object without an active snapshot can be activated" do
      port = port(%{changes_pending: true})
      assert NetworkPort.active_configuration(port) == {:error, :missing_active_configuration}

      assert prepare(port, :command, :discard_changes) ==
               {:error, {:property, :optional_functionality_not_supported}}

      assert {:ok, updated} = NetworkPort.update_property(port, :network_number, 12)
      assert updated.network_number == 12
      assert updated.changes_pending
      assert NetworkPort.active_configuration(updated) == {:error, :missing_active_configuration}

      context =
        Context.new(:periodic,
          options: [network_port_event: {:configuration_activated, :warmstart}]
        )

      assert {:ok, %Result{object: active}} = NetworkPort.execute(port, context)
      refute active.changes_pending
    end
  end

  describe "command execution" do
    test "preparation is pure, outstanding commands are busy, and restart failures update reliability" do
      handler = fn port ->
        send(self(), {:restart_port, port.command})
        {:error, :transport_unavailable}
      end

      port = port(%{}, network_port_runtime: %{restart_port: handler})
      assert {:ok, accepted, context} = prepare(port, :command, :restart_port)
      refute_received {:restart_port, _}

      assert prepare(accepted, :command, :discard_changes) == {:error, {:object, :busy}}

      assert {:ok, %Result{object: ^accepted}} =
               Lifecycle.prepare_read(accepted, Context.new({:property_read, :command, nil}))

      refute_received {:restart_port, _}

      assert {:ok, %Result{object: failed, state: state}} = NetworkPort.execute(accepted, context)
      assert_received {:restart_port, :restart_port}
      assert state == {:command_result, :restart_port, {:error, :transport_unavailable}}
      assert failed.command == :idle
      assert failed.reliability == :restart_failure
      assert failed.status_flags.fault

      assert {:ok, %Result{object: ^failed, state: ^state}} =
               NetworkPort.execute(failed, %{context | state: state})

      refute_received {:restart_port, _}
    end

    test "rejects unavailable commands, incompatible modes, and pending or out-of-service requests" do
      port = port()
      assert prepare(port, :command, :idle) == {:error, {:property, :value_out_of_range}}

      assert prepare(port, :command, :restart_port) ==
               {:error, {:property, :optional_functionality_not_supported}}

      for command <- [:renew_fd_registration, :renew_dhcp, :restart_slave_discovery, :disconnect] do
        assert prepare(port, :command, command) == {:error, {:property, :value_out_of_range}}
      end

      assert {:ok, staged} = NetworkPort.update_property(port, :network_number, 7)

      assert prepare(staged, :command, :restart_port) ==
               {:error, {:property, :invalid_value_in_this_state}}

      handler = fn _port -> :ok end

      oos =
        port(%{out_of_service: true, link_speed_autonegotiate: true},
          network_port_runtime: %{restart_port: handler, restart_autonegotiation: handler}
        )

      assert prepare(oos, :command, :restart_autonegotiation) ==
               {:error, {:property, :value_out_of_range}}

      assert {:ok, accepted, context} = prepare(oos, :command, :restart_port)

      assert {:ok, %Result{object: %NetworkPort{command: :idle, out_of_service: true}}} =
               NetworkPort.execute(accepted, context)
    end

    test "dispatches only registered vendor commands and reports proprietary failures" do
      port =
        port(%{},
          allow_numeric_constants: true,
          network_port_runtime: %{128 => fn _port -> {:error, :vendor_failure} end}
        )

      for command <- [127, 129, 256] do
        assert prepare(port, :command, command) == {:error, {:property, :value_out_of_range}}
      end

      assert {:ok, accepted, context} = prepare(port, :command, 128)

      assert {:ok,
              %Result{object: finished, state: {:command_result, 128, {:error, :vendor_failure}}}} =
               NetworkPort.execute(accepted, context)

      assert finished.command == :idle
      assert finished.reliability == :proprietary_command_failure
    end

    test "foreign-device, DHCP and autonegotiation failures have distinct reliability values" do
      fail = fn _port -> {:error, :network_unavailable} end

      port =
        port(
          %{
            network_type: :ipv4,
            bacnet_ip_mode: :foreign,
            bacnet_ip_udp_port: 47_808,
            ip_address: {192, 0, 2, 2},
            ip_subnet_mask: {255, 255, 255, 0},
            ip_default_gateway: {192, 0, 2, 1},
            ip_dns_server: BACnetArray.new(),
            ip_dhcp_enable: true,
            fd_bbmd_address: %HostNPort{host: {:ip_address, {192, 0, 2, 3}}, port: 47_808},
            fd_subscription_lifetime: 60,
            link_speed_autonegotiate: true
          },
          network_port_runtime: %{
            renew_fd_registration: fail,
            renew_dhcp: fail,
            restart_autonegotiation: fail
          }
        )

      for {command, reliability} <- [
            renew_fd_registration: :renew_fd_registration_failure,
            renew_dhcp: :renew_dhcp_failure,
            restart_autonegotiation: :restart_auto_negotiation_failure
          ] do
        assert {:ok, accepted, context} = prepare(port, :command, command)

        assert {:ok, %Result{object: %NetworkPort{command: :idle, reliability: ^reliability}}} =
                 NetworkPort.execute(accepted, context)
      end

      assert {:ok, static} = NetworkPort.update_operating_property(port, :ip_dhcp_enable, false)
      assert prepare(static, :command, :renew_dhcp) == {:error, {:property, :value_out_of_range}}
    end

    test "MS/TP discovery and PTP disconnect dispatch their registered actions" do
      handler = fn port ->
        send(self(), {:action, port.command})
        :ok
      end

      for {type, command} <- [mstp: :restart_slave_discovery, ptp: :disconnect] do
        properties = %{network_type: type, protocol_level: :bacnet_application}

        properties =
          if type == :mstp, do: Map.put(properties, :mac_address, <<1>>), else: properties

        assert {:ok, port} =
                 NetworkPort.create(1, "Port", properties,
                   supports_command_execution: true,
                   network_port_runtime: %{command => handler}
                 )

        assert {:ok, accepted, context} = prepare(port, :command, command)
        refute_received {:action, _}

        assert {:ok, %Result{object: %{command: :idle}, state: {:command_result, ^command, :ok}}} =
                 NetworkPort.execute(accepted, context)

        assert_received {:action, ^command}
      end
    end

    test "a successful retry clears the matching command failure" do
      handler = fn port ->
        if port.reliability == :restart_failure, do: :ok, else: {:error, :network_unavailable}
      end

      port = port(%{}, network_port_runtime: %{restart_port: handler})
      assert {:ok, accepted, context} = prepare(port, :command, :restart_port)
      assert {:ok, %Result{object: failed}} = NetworkPort.execute(accepted, context)
      assert failed.reliability == :restart_failure

      assert {:ok, accepted, context} = prepare(failed, :command, :restart_port)
      assert {:ok, %Result{object: recovered}} = NetworkPort.execute(accepted, context)
      assert recovered.reliability == :no_fault_detected
      refute recovered.status_flags.fault
    end

    test "rejects commands when the port does not expose Command" do
      port = port(%{}, supports_command_execution: false)
      refute NetworkPort.has_property?(port, :command)
      context = Context.new({:property_write, :command, nil, nil})

      assert {:error, {:property, :unknown_property}} =
               NetworkPort.prepare_write(port, port, context)
    end

    test "initialization clears a transient command without replaying it" do
      port = port(%{command: :restart_port})

      assert {:ok, %Result{object: %NetworkPort{command: :idle}}} =
               NetworkPort.execute(port, Context.new(:initialization))
    end
  end

  test "applies Out_Of_Service at the modeled protocol level before publishing the write" do
    callback = fn port ->
      send(self(), {:communication, port.protocol_level, port.out_of_service})
      if port.out_of_service, do: :ok, else: {:error, :port_unavailable}
    end

    port = port(%{}, network_port_runtime: %{out_of_service: callback})
    assert {:ok, candidate, context} = prepare(port, :out_of_service, true)
    refute_received {:communication, _, _}
    assert {:ok, %Result{object: stopped}} = NetworkPort.execute(candidate, context)
    assert_received {:communication, :bacnet_application, true}
    assert stopped.out_of_service
    assert stopped.status_flags.out_of_service

    assert {:ok, candidate, context} = prepare(stopped, :out_of_service, false)
    assert NetworkPort.execute(candidate, context) == {:error, :port_unavailable}
    assert_received {:communication, :bacnet_application, false}

    assert prepare(port(), :out_of_service, true) ==
             {:error, {:property, :optional_functionality_not_supported}}
  end

  test "preflight checks the network number, reference and supported link speeds" do
    port =
      port(%{
        link_speed: 100.0,
        link_speeds: BACnetArray.from_list([100.0, 200.0]),
        reference_port: 2
      })

    for {property, value} <- [network_number: 65_535, link_speed: 300.0, reference_port: 1] do
      assert prepare(port, property, value) == {:error, {:property, :value_out_of_range}}
    end

    assert {:ok, staged, _context} = prepare(port, :link_speed, 200.0)
    assert staged.changes_pending

    {:ok, ptp} =
      NetworkPort.create(1, "ptp", %{
        network_type: :ptp,
        protocol_level: :bacnet_application,
        network_number: 0
      })

    refute NetworkPort.property_writable?(ptp, :network_number)
    assert prepare(ptp, :network_number, 5) == {:error, {:property, :write_access_denied}}
  end

  test "link speed requires a manual speed list and Changes_Pending rejects client writes" do
    speed = 100.0
    port = port(%{link_speed: speed, link_speed_autonegotiate: false})
    assert NetworkPort.property_writable?(port, :link_speed)
    assert prepare(port, :link_speed, speed) == {:error, {:property, :write_access_denied}}

    automatic =
      port(%{
        link_speed: speed,
        link_speed_autonegotiate: true,
        link_speeds: BACnetArray.from_list([speed])
      })

    refute NetworkPort.property_writable?(automatic, :link_speed)
    assert prepare(automatic, :link_speed, speed) == {:error, {:property, :write_access_denied}}
    assert prepare(port, :changes_pending, true) == {:error, {:property, :write_access_denied}}
  end

  test "MS/TP master settings are writable, bounded and staged together with the other settings" do
    port = port(%{network_type: :mstp, max_master: 127, max_info_frames: 1})
    assert NetworkPort.property_writable?(port, :max_master)
    assert NetworkPort.property_writable?(port, :max_info_frames)

    assert {:ok, staged, _context} = prepare(port, :max_master, 0)
    assert {:ok, staged, _context} = prepare(staged, :max_info_frames, 255)
    assert staged.changes_pending
    assert staged.max_master == 0
    assert staged.max_info_frames == 255

    assert {:ok, %{max_master: 127, max_info_frames: 1}} =
             NetworkPort.active_configuration(staged)

    for {property, value} <- [max_master: 128, max_info_frames: 256] do
      assert {:error, {:value_failed_property_validation, ^property}} =
               NetworkPort.update_property(port, property, value)
    end
  end

  test "remote snapshots do not run host actions or expose a local active configuration" do
    local = port()

    properties =
      local
      |> Map.from_struct()
      |> Map.take(local._metadata.properties_list)
      |> Map.drop([:object_instance, :object_name])

    remote = port(properties, remote_object: 42)
    context = Context.new({:property_write, :command, nil, nil}, state: :retained)

    assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil}} =
             NetworkPort.execute(remote, context)

    assert NetworkPort.prepare_write(remote, remote, context) ==
             {:error, :operation_not_available_for_remote_objects}

    assert NetworkPort.active_configuration(remote) ==
             {:error, :operation_not_available_for_remote_objects}

    assert NetworkPort.update_operating_property(remote, :mac_address, <<2>>) ==
             {:error, :operation_not_available_for_remote_objects}
  end

  test "automatic address configuration controls IPv4 and IPv6 writability" do
    {:ok, object} =
      NetworkPort.create(1, "port", %{
        network_type: :ptp,
        protocol_level: :physical,
        ip_dhcp_enable: false,
        ipv6_auto_addressing_enable: false,
        description: "port"
      })

    for property <- [
          :ip_address,
          :ip_subnet_mask,
          :ip_default_gateway,
          :ip_dns_server,
          :ipv6_address,
          :ipv6_prefix_length,
          :ipv6_default_gateway,
          :ipv6_dns_server
        ] do
      assert NetworkPort.property_writable?(object, property)
    end

    {:ok, automatic} = NetworkPort.update_property(object, :ip_dhcp_enable, true)
    {:ok, automatic} = NetworkPort.update_property(automatic, :ipv6_auto_addressing_enable, true)

    for property <- [
          :ip_address,
          :ip_subnet_mask,
          :ip_default_gateway,
          :ip_dns_server,
          :ipv6_address,
          :ipv6_prefix_length,
          :ipv6_default_gateway,
          :ipv6_dns_server
        ] do
      refute NetworkPort.property_writable?(automatic, property)
    end

    assert NetworkPort.property_writable?(object, :mac_address)
    refute NetworkPort.property_writable?(%{object | network_type: :ipv4}, :mac_address)
    refute NetworkPort.property_writable?(%{object | network_type: :ipv6}, :mac_address)
    assert NetworkPort.property_writable?(object, :description)
    refute NetworkPort.property_writable?(object, :network_type)
    refute NetworkPort.property_writable?(object, :unknown_property)
  end

  test "IP decoding handles unused addresses and rejects malformed lengths" do
    object_id = %ObjectIdentifier{type: :network_port, instance: 1}

    for {property, empty} <- [
          {:ip_address, {0, 0, 0, 0}},
          {:bacnet_ipv6_multicast_address, {{0, 0, 0, 0, 0, 0, 0, 0}, 0}}
        ] do
      assert {:ok, ^empty} =
               ObjectsUtility.cast_property_to_value(
                 object_id,
                 property,
                 Encoding.create!({:octet_string, <<>>})
               )

      assert {:error, {:invalid_tags, {^property, %Encoding{}}}} =
               ObjectsUtility.cast_property_to_value(
                 object_id,
                 property,
                 Encoding.create!({:octet_string, <<1, 2, 3>>})
               )
    end

    assert {:error, {:invalid_property_value, {:ipv6_address, :invalid}}} =
             ObjectsUtility.cast_value_to_property(object_id, :ipv6_address, :invalid)

    assert {:error, {:invalid_property_value, {:ip_address, :invalid}}} =
             ObjectsUtility.cast_value_to_property(object_id, :ip_address, :invalid)
  end

  test "IPv4 encoder supports port suffixes at both port boundaries" do
    for port <- [0, 65_535] do
      expected = <<192, 0, 2, 1, port::16>>

      assert {:ok, %Encoding{type: :octet_string, value: ^expected}} =
               ObjectsUtility.cast_value_to_property(
                 %ObjectIdentifier{type: :network_port, instance: 1},
                 :ip_address,
                 {{192, 0, 2, 1}, port}
               )
    end
  end

  test "IPv6 multicast addresses validate address words and port ranges" do
    {:ok, object} =
      NetworkPort.create(1, "port", %{network_type: :ptp, protocol_level: :physical})

    for value <- [{{65_535, 0, 0, 0, 0, 0, 0, 1}, 0}, {{0, 0, 0, 0, 0, 0, 0, 0}, 65_535}] do
      assert {:ok, %NetworkPort{bacnet_ipv6_multicast_address: ^value}} =
               NetworkPort.add_property(object, :bacnet_ipv6_multicast_address, value)
    end

    for value <- [
          {{65_536, 0, 0, 0, 0, 0, 0, 1}, 47_808},
          {{0, 0, 0, 0, 0, 0, 0, 1}, -1},
          {{0, 0, 0, 0, 0, 0, 0, 1}, 65_536},
          {:invalid, 47_808}
        ] do
      assert {:error, {:value_failed_property_validation, :bacnet_ipv6_multicast_address}} =
               NetworkPort.add_property(object, :bacnet_ipv6_multicast_address, value)
    end

    assert {:ok, %NetworkPort{ip_dns_server: %BACnetArray{}}} =
             NetworkPort.add_property(object, :ip_dns_server, BACnetArray.new())
  end

  for property <- [
        :ip_address,
        :ip_subnet_mask,
        :ip_default_gateway,
        :bacnet_ip_multicast_address,
        :ip_dns_server,
        :ip_dhcp_server
      ] do
    ip =
      nil
      |> List.duplicate(4)
      |> Enum.map(fn _el -> Enum.random(1..254//1) end)

    ip_tup = Macro.escape(List.to_tuple(ip))
    ip_bin = :binary.list_to_bin(ip)

    test "verify network port #{property} decoding" do
      assert {:ok, unquote(ip_tup)} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :network_port, instance: 0},
                 unquote(property),
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :octet_string,
                   value: unquote(ip_bin)
                 },
                 allow_partial: true
               )
    end

    test "verify network port #{property} encoding" do
      assert {:ok,
              %Encoding{
                encoding: :primitive,
                extras: [],
                type: :octet_string,
                value: unquote(ip_bin)
              }} =
               ObjectsUtility.cast_value_to_property(
                 %ObjectIdentifier{type: :network_port, instance: 0},
                 unquote(property),
                 unquote(ip_tup),
                 allow_partial: true
               )
    end
  end

  for property <- [:ipv6_address, :ipv6_default_gateway, :ipv6_dns_server, :ipv6_dhcp_server] do
    ip =
      nil
      |> List.duplicate(8)
      |> Enum.map(fn _el -> Enum.random(1..65_534//1) end)

    ip_tup = Macro.escape(List.to_tuple(ip))
    ip_bin = Enum.reduce(ip, <<>>, &<<&2::binary, &1::size(16)>>)

    test "verify network port #{property} decoding" do
      assert {:ok, unquote(ip_tup)} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :network_port, instance: 0},
                 unquote(property),
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :octet_string,
                   value: unquote(ip_bin)
                 },
                 allow_partial: true
               )
    end

    test "verify network port #{property} encoding" do
      assert {:ok,
              %Encoding{
                encoding: :primitive,
                extras: [],
                type: :octet_string,
                value: unquote(ip_bin)
              }} =
               ObjectsUtility.cast_value_to_property(
                 %ObjectIdentifier{type: :network_port, instance: 0},
                 unquote(property),
                 unquote(ip_tup),
                 allow_partial: true
               )
    end
  end

  test "verify network port bacnet_ipv6_multicast_address decoding" do
    ip =
      nil
      |> List.duplicate(8)
      |> Enum.map(fn _el -> Enum.random(1..65_534//1) end)

    ip_tup = List.to_tuple(ip)
    ip_bin = Enum.reduce(ip, <<>>, &<<&2::binary, &1::size(16)>>)
    port = Enum.random(1..65_535//1)
    final = {ip_tup, port}

    assert {:ok, ^final} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :network_port, instance: 0},
               :bacnet_ipv6_multicast_address,
               %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :octet_string,
                 value: <<ip_bin::binary, port::size(16)>>
               },
               allow_partial: true
             )
  end

  test "verify network port bacnet_ipv6_multicast_address encoding" do
    ip =
      nil
      |> List.duplicate(8)
      |> Enum.map(fn _el -> Enum.random(1..65_534//1) end)

    ip_tup = List.to_tuple(ip)
    ip_bin = Enum.reduce(ip, <<>>, &<<&2::binary, &1::size(16)>>)
    port = Enum.random(1..65_535//1)
    bin = <<ip_bin::binary, port::size(16)>>

    assert {:ok,
            %Encoding{
              encoding: :primitive,
              extras: [],
              type: :octet_string,
              value: ^bin
            }} =
             ObjectsUtility.cast_value_to_property(
               %ObjectIdentifier{type: :network_port, instance: 0},
               :bacnet_ipv6_multicast_address,
               {ip_tup, port},
               allow_partial: true
             )
  end

  defp port(properties \\ %{}, options \\ []) do
    defaults = %{network_type: :virtual, protocol_level: :bacnet_application, mac_address: <<1>>}
    opts = Keyword.put_new(options, :supports_command_execution, true)
    {:ok, port} = NetworkPort.create(1, "port", Map.merge(defaults, properties), opts)
    port
  end

  defp prepare(port, property, value) do
    context = Context.new({:property_write, property, nil, nil})

    with {:ok, candidate} <- NetworkPort.update_property(port, property, value),
         {:ok, accepted} <- NetworkPort.prepare_write(port, candidate, context) do
      {:ok, accepted, context}
    end
  end
end
