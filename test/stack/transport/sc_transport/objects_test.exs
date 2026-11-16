defmodule BACnet.Test.Stack.Transport.ScTransport.ObjectsTest do
  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.AccessSpecification.Property
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.File, as: FileObject
  alias BACnet.Stack.Transport.ScTransport.Hub.Failure
  alias BACnet.Stack.Transport.ScTransport.Hub.Session
  alias BACnet.Stack.Transport.ScTransport.ManagedPort
  alias BACnet.Stack.Transport.ScTransport.Node.ConnectionStatus
  alias BACnet.Stack.Transport.ScTransport.Objects

  use BACnet.Test.Stack.Case, async: false

  @moduletag skip: not BACstack.MixProject.sc_enabled?()

  @vmac <<2, 0, 0, 0, 0, 1>>
  @peer <<2, 0, 0, 0, 0, 2>>
  @file_ids %{operational: 10, issuer_1: 11, issuer_2: 12, csr: 13}
  @device %ObjectIdentifier{type: :device, instance: 123}
  @port %ObjectIdentifier{type: :network_port, instance: 1}
  @operational %ObjectIdentifier{type: :file, instance: 10}
  @unknown %ObjectIdentifier{type: :analog_value, instance: 5}

  setup do
    ca_key = X509.PrivateKey.new_ec(:secp256r1)
    ca = X509.Certificate.self_signed(ca_key, "/CN=Objects CA", template: :root_ca)
    key = X509.PrivateKey.new_ec(:secp256r1)

    cert =
      X509.Certificate.new(X509.PublicKey.derive(key), "/CN=Objects", ca, ca_key,
        template: :server
      )

    directory =
      Path.join(System.tmp_dir!(), "bacstack-sc-objects-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(directory) end)

    managed =
      start_supervised!(
        {ManagedPort,
         storage_dir: directory,
         device_instance: 123,
         port_instance: 1,
         file_instances: @file_ids,
         vendor_id: 0,
         certificate_pem: X509.Certificate.to_pem(cert),
         private_key_pem: X509.PrivateKey.to_pem(key),
         issuer_pems: [X509.Certificate.to_pem(ca)],
         transport: [vmac: @vmac],
         hub: [port: 0, ip: {127, 0, 0, 1}, enabled: true, accept_uris: ["wss://localhost/"]]}
      )

    %{state: :sys.get_state(managed)}
  end

  test "resolves identifiers and exposes live port and standalone File objects", %{state: state} do
    assert Objects.canonical_id(state, %{@device | instance: 4_194_303}) == @device
    assert Objects.canonical_id(state, @port) == @port
    assert {:ok, device} = Objects.get_object(state, @device)
    assert device.object_instance == 123
    assert {:ok, port} = Objects.get_object(state, @port)
    assert port.sc_hub_connector_state == :no_hub_connection
    assert port.mac_address == @vmac
    assert port.current_health.result.code == :success

    assert {:ok, file} = Objects.get_object(state, @operational)
    assert file.object_name == "SC Operational Certificate"
    assert file.file_size == byte_size(state.snapshot.certificates.operational)
    assert {:ok, :operational} = Objects.lookup_file(state, @operational)
    assert {:error, {:object, :unknown_object}} = Objects.lookup_file(state, @port)

    assert {:error, {:object, :unknown_object}} =
             Objects.get_object(state, %{@operational | instance: 99})

    assert {:error, {:object, :unknown_object}} = Objects.get_object(state, @unknown)

    assert {:ok, files} = Objects.project_files(state)
    assert files.csr.read_only
    assert files.csr.file_size == 0
    assert files.issuer_1.file_size > 0
    assert files.issuer_2.file_size == 0
    assert :ok = stop_supervised(ManagedPort)
  end

  test "encodes properties and distinguishes BACnet read errors", %{state: state} do
    port = state.port
    assert {:ok, %{value: @port}} = Objects.read_value(port, @port, :object_identifier, nil)
    assert {:ok, %{value: 56}} = Objects.read_value(port, @port, :object_type, nil)
    assert {:ok, list} = Objects.read_value(port, @port, :property_list, nil)
    assert {:ok, %{value: count}} = Objects.read_value(port, @port, :property_list, 0)
    assert count == length(list)
    assert {:ok, entry} = Objects.read_value(port, @port, :property_list, 1)
    assert entry == hd(list)

    assert {:error, {:property, :invalid_array_index}} =
             Objects.read_value(port, @port, :property_list, count + 1)

    assert {:ok, %{value: "BACnet/SC Port"}} = Objects.read_value(port, @port, :object_name, nil)
    assert {:ok, %{value: 1}} = Objects.read_value(port, @port, :sc_hub_function_accept_uris, 0)

    assert {:ok, %{value: "wss://localhost/"}} =
             Objects.read_value(port, @port, :sc_hub_function_accept_uris, 1)

    assert {:error, {:property, :invalid_array_index}} =
             Objects.read_value(port, @port, :sc_hub_function_accept_uris, 2)

    assert {:error, {:property, :property_is_not_an_array}} =
             Objects.read_value(port, @port, :object_name, 1)

    assert {:error, {:property, :unknown_property}} =
             Objects.read_value(port, @port, :present_value, nil)

    assert {:error, {:property, :unknown_property}} = Objects.read_value(port, @port, 9000, nil)
    assert :ok = stop_supervised(ManagedPort)
  end

  test "builds access results for selectors, concrete attributes, and missing objects", %{
    state: state
  } do
    attr = %Property{
      property_identifier: :object_name,
      property_array_index: nil,
      property_value: nil,
      priority: nil
    }

    request = %AccessSpecification{
      object_identifier: @port,
      properties: [attr, :required, :optional]
    }

    result = Objects.read_access_result(state, request)
    assert result.object_identifier == @port

    assert Enum.any?(
             result.results,
             &(&1.property_identifier == :object_name and &1.error == nil)
           )

    assert Enum.any?(
             result.results,
             &(&1.property_identifier == :sc_primary_hub_uri and &1.error == nil)
           )

    missing = %{
      request
      | object_identifier: @unknown,
        properties: [%{attr | property_array_index: 2}, :all]
    }

    assert %{results: [indexed, selector]} = Objects.read_access_result(state, missing)
    assert indexed.property_array_index == 2
    assert indexed.error.code == :unknown_object
    assert selector.property_identifier == :all
    assert selector.error.code == :unknown_object
    assert :ok = stop_supervised(ManagedPort)
  end

  test "projects hosted metadata and connector diagnostics", %{state: state} do
    assert {:ok, files} = Objects.project_files(state)
    {:ok, operational} = FileObject.create(10, "Host certificate", %{}, revision: 24)
    files = %{files | operational: operational}
    date = BACnetDateTime.utc_now()

    snapshot = %{
      state.snapshot
      | uploads: %{operational: "replacement"},
        upload_dates: %{operational: date},
        csr: "request"
    }

    hosted = %{state | hosted: :hosted, files: files, snapshot: snapshot}

    assert {:ok, port} = Objects.get_object(hosted, @port)
    assert port == state.port

    assert {:ok, %{object_name: "Host certificate", file_size: 11, modification_date: ^date}} =
             Objects.file_object(hosted, :operational)

    assert Objects.file_data(snapshot, :csr) == "request"

    now = DateTime.utc_now()
    peer = %{vmac: @peer, uuid: <<2::128>>, max_bvlc: 65_535, max_npdu: 1497}
    remote = {{127, 0, 0, 1}, 4443}

    :sys.replace_state(state.node, fn node ->
      %{
        node
        | active: :failover,
          statuses: %{failover: connection_status(peer: peer, connected_at: now)}
      }
    end)

    :sys.replace_state(state.hub, fn hub ->
      # A struct literal fails to compile when BACnet/SC is disabled.
      session =
        struct!(Session,
          connected_at: now,
          remote: remote,
          peer: peer,
          monitor: make_ref(),
          certificate_sha256: nil
        )

      failure = struct!(Failure, timestamp: now, remote: remote, peer: nil, code: 30)

      %{
        hub
        | sessions: %{self() => session},
          failed: [failure]
      }
    end)

    assert {:ok, %{port: live, files: projected}} = Objects.host_objects(hosted)
    assert live.sc_hub_connector_state == :connected_to_failover
    assert live.sc_failover_hub_connection_status.state == 1
    assert [%{vmac: @peer, uuid: <<2::128>>}] = live.sc_hub_function_connection_status
    assert [%{vmac: nil, error: %{code: 30}}] = live.sc_failed_connection_requests
    assert projected.operational.file_size == 11
    assert projected.csr.file_size == 7

    :sys.replace_state(state.node, &%{&1 | active: :primary})

    assert {:ok, %{sc_hub_connector_state: :connected_to_primary}} =
             Objects.get_object(state, @port)

    assert :ok = stop_supervised(ManagedPort)
  end

  test "reports a connector failure before and after it had been connected" do
    assert %{state: 0, error: nil} = Objects.connector(false, nil)
    now = DateTime.utc_now()

    assert %{state: 2, error: %{code: :websocket_error}} =
             Objects.connector(
               false,
               connection_status(connected_at: now, error: :closed_by_peer)
             )

    assert %{state: 3, error: %{code: 151}} =
             Objects.connector(false, connection_status(error: {:connect_rejected, 151}))

    failed = DateTime.add(now, 1)

    assert %{state: 3, connected_at: timestamp, error: %{code: :tcp_connection_refused}} =
             Objects.connector(
               false,
               connection_status(
                 connected_at: now,
                 failed_at: failed,
                 error: :econnrefused
               )
             )

    assert timestamp == BACnetDateTime.from_datetime(failed)

    assert %{result: %{code: :success}} = Objects.health()

    assert %{property: :sc_primary_hub_uri, result: %{code: :value_out_of_range}} =
             Objects.health(:sc_primary_hub_uri, :property, :value_out_of_range)

    assert :ok = stop_supervised(ManagedPort)
  end

  test "projects only active runtime conditions into Current_Health", %{state: state} do
    primary = :sc_primary_hub_uri
    failover = :sc_failover_hub_uri
    uri = "wss://localhost:4443/"
    pending = %{state | snapshot: %{state.snapshot | pending: %{primary => uri}}}

    assert {:ok, %{current_health: %{result: %{code: :success}}}} =
             Objects.get_object(pending, @port)

    active = put_in(state.snapshot.active[primary], uri)
    active = put_in(active.snapshot.active[failover], uri)

    assert {:ok, %{current_health: %{property: ^primary, result: %{code: :network_down}}}} =
             Objects.get_object(active, @port)

    now = DateTime.utc_now()

    :sys.replace_state(state.node, fn node ->
      %{
        node
        | statuses: %{
            primary: connection_status(error: :econnrefused, failed_at: now),
            failover:
              connection_status(
                error: {:websocket_closed, 1002},
                disconnected_at: DateTime.add(now, 1)
              )
          }
      }
    end)

    assert {:ok,
            %{current_health: %{property: ^failover, result: %{code: :websocket_protocol_error}}}} =
             Objects.get_object(active, @port)

    :sys.replace_state(state.node, &%{&1 | active: :failover})

    assert {:ok, %{current_health: %{result: %{code: :success}}}} =
             Objects.get_object(active, @port)

    :sys.replace_state(state.node, &%{&1 | active: nil})
    assert :ok = stop_supervised(ManagedPort)
  end

  defp connection_status(fields) do
    defaults = [peer: nil, connected_at: nil, disconnected_at: nil, failed_at: nil, error: nil]
    struct!(ConnectionStatus, Keyword.merge(defaults, fields))
  end
end
