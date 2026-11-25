defmodule BACnet.Test.Stack.Transport.ScTransport.IntegrationTest do
  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.AccessSpecification.Property
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectTypes.Device
  alias BACnet.Protocol.ObjectTypes.File, as: FileObject
  alias BACnet.Protocol.ObjectTypes.NetworkPort
  alias BACnet.Protocol.SecureConnect.BVLC
  alias BACnet.Protocol.SecureConnect.Health
  alias BACnet.Protocol.Services.Ack.AtomicReadFileAck
  alias BACnet.Protocol.Services.Ack.AtomicWriteFileAck
  alias BACnet.Protocol.Services.Ack.ReadPropertyAck
  alias BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck
  alias BACnet.Protocol.Services.AtomicReadFile
  alias BACnet.Protocol.Services.AtomicWriteFile
  alias BACnet.Protocol.Services.DeviceCommunicationControl
  alias BACnet.Protocol.Services.Error.WritePropertyMultipleError
  alias BACnet.Protocol.Services.IAm
  alias BACnet.Protocol.Services.ReadProperty
  alias BACnet.Protocol.Services.ReadPropertyMultiple
  alias BACnet.Protocol.Services.ReinitializeDevice
  alias BACnet.Protocol.Services.WhoIs
  alias BACnet.Protocol.Services.WriteProperty
  alias BACnet.Protocol.Services.WritePropertyMultiple

  alias BACnet.Stack.Client
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Stack.Transport.ScTransport.Audit
  alias BACnet.Stack.Transport.ScTransport.Audit.Event
  alias BACnet.Stack.Transport.ScTransport.Connection
  alias BACnet.Stack.Transport.ScTransport.Credentials
  alias BACnet.Stack.Transport.ScTransport.Hub
  alias BACnet.Stack.Transport.ScTransport.Hub.WebSocket
  alias BACnet.Stack.Transport.ScTransport.ManagedPort
  alias BACnet.Stack.Transport.ScTransport.Node
  alias BACnet.Stack.Transport.ScTransport.Objects
  alias BACnet.Stack.Transport.ScTransport.Store
  alias BACnet.Stack.TransportBehaviour

  use BACnet.Test.Stack.Case, async: false

  @moduletag skip: not BACstack.MixProject.sc_enabled?()

  @loopback {127, 0, 0, 1}
  @hub <<2, 0, 0, 0, 0, 1>>
  @peer <<2, 0, 0, 0, 0, 2>>
  @managed <<2, 0, 0, 0, 0, 3>>
  @file_ids %{operational: 10, issuer_1: 11, issuer_2: 12, csr: 13}
  @audit_object %ObjectIdentifier{type: :analog_output, instance: 7}

  setup do
    ca_key = X509.PrivateKey.new_ec(:secp256r1)
    ca = X509.Certificate.self_signed(ca_key, "/CN=SC integration CA", template: :root_ca)
    %{ca: ca, ca_key: ca_key, ca_pem: X509.Certificate.to_pem(ca)}
  end

  test "audits TLS peer identity, routed write retries, and the reply", context do
    {hub, writer, target} = audit_peers(context, :writes)
    expected_fingerprint = :crypto.hash(:sha256, :sys.get_state(writer).config.credentials.cert)
    source = %NpciTarget{net: 10, address: <<4>>}
    destination = %NpciTarget{net: 20, address: <<7>>}
    request = audit_write(13, 20.5)

    assert :ok = Node.send(writer, @managed, request, source: source, destination: destination)
    assert_receive {:audit, %{__struct__: Event, kind: :write_request} = write}, 1000

    assert %{
             __struct__: Event,
             capture_id: write_id,
             hub: %{uuid: <<1::128>>, vmac: @hub},
             ingress: %{
               vmac: @peer,
               uuid: <<2::128>>,
               remote: {@loopback, _port},
               certificate_sha256: ^expected_fingerprint
             },
             egress: %{vmac: @managed, uuid: <<3::128>>},
             npci: %{source: ^source, destination: ^destination},
             routing: {:queued, 1},
             timestamp: %DateTime{time_zone: "Etc/UTC"}
           } = write

    assert %{
             write_id: ^write_id,
             invoke_id: 13,
             service: :write_property,
             retry: false,
             writes: [
               %{
                 object_identifier: @audit_object,
                 property_identifier: :present_value,
                 property_array_index: nil,
                 priority: 8,
                 property_value: value
               }
             ]
           } = write.details

    assert [%Encoding{type: :real, value: 20.5}] = List.wrap(value)

    assert :ok = Node.send(writer, @managed, request, source: source, destination: destination)

    assert_receive {:audit, %{__struct__: Event, details: %{write_id: ^write_id, retry: true}}},
                   1000

    ack = %APDU.SimpleACK{invoke_id: 13, service: :write_property}
    # The link peers are correct, but this is from a different downstream device.
    assert :ok =
             Node.send(target, @peer, ack,
               source: %{destination | address: <<8>>},
               destination: source
             )

    assert :ok = Node.send(target, @peer, ack, source: destination, destination: source)

    assert_receive {:audit,
                    %{
                      __struct__: Event,
                      kind: :write_result,
                      ingress: %{vmac: @managed},
                      egress: %{vmac: @peer},
                      npci: %{source: ^destination, destination: ^source},
                      details: %{write_id: ^write_id, outcome: :acknowledged, reply: ^ack}
                    }},
                   1000

    refute_receive {:audit, _event}

    assert %{__struct__: Audit.Status, mode: :writes, queue_drops: 0, sink_failures: 0} =
             Hub.audit_status(hub)

    stop_test_fixtures()
  end

  test "audits a segmented batch write and identifies the failed property", context do
    {_hub, writer, target} = audit_peers(context, :writes)
    second_object = %ObjectIdentifier{type: :analog_output, instance: 8}

    batch = %WritePropertyMultiple{
      list: [
        %AccessSpecification{
          object_identifier: @audit_object,
          properties: [
            %Property{
              property_identifier: :present_value,
              property_array_index: nil,
              property_value: Encoding.create!({:real, 24.0}),
              priority: 5
            }
          ]
        },
        %AccessSpecification{
          object_identifier: second_object,
          properties: [
            %Property{
              property_identifier: :priority_array,
              property_array_index: 10,
              property_value: Encoding.create!({:null, nil}),
              priority: nil
            }
          ]
        }
      ]
    }

    assert {:ok, request} = WritePropertyMultiple.to_apdu(batch, invoke_id: 21)

    <<flags, limits, invoke, service, tags::binary>> =
      request
      |> BACnet.Stack.EncoderProtocol.encode()
      |> IO.iodata_to_binary()

    <<first::binary-size(7), rest::binary>> = tags
    # Preserve the lower capability flags while setting segmentation and More Follows.
    segment = <<Bitwise.bor(flags, 12), limits, invoke, 0, 2, service, first::binary>>
    assert :ok = Node.send(writer, @managed, segment)
    assert :ok = Node.send(writer, @managed, segment)

    assert :ok =
             Node.send(
               writer,
               @managed,
               <<Bitwise.bor(flags, 8), limits, invoke, 1, 2, service, rest::binary>>
             )

    assert_receive {:audit,
                    %{
                      __struct__: Event,
                      kind: :write_request,
                      details: %{
                        service: :write_property_multiple,
                        write_id: write_id,
                        writes: [
                          %{object_identifier: @audit_object, priority: 5},
                          %{
                            object_identifier: ^second_object,
                            property_identifier: :priority_array,
                            property_array_index: 10,
                            priority: nil,
                            property_value: value
                          }
                        ]
                      }
                    }},
                   1000

    assert [%Encoding{type: :null, value: nil}] = List.wrap(value)

    failed = %ObjectPropertyRef{
      object_identifier: second_object,
      property_identifier: :priority_array,
      property_array_index: 10
    }

    assert {:ok, error} =
             WritePropertyMultipleError.to_apdu(
               %WritePropertyMultipleError{
                 first_failed_write_attempt: failed,
                 error_class: :property,
                 error_code: :write_access_denied
               },
               invoke
             )

    assert :ok = Node.send(target, @peer, error)

    assert_receive {:audit,
                    %{
                      __struct__: Event,
                      kind: :write_result,
                      details: %{
                        write_id: ^write_id,
                        outcome: :error,
                        first_failed_write_attempt: ^failed,
                        reply: %APDU.Error{code: :write_access_denied}
                      }
                    }},
                   1000

    stop_test_fixtures()
  end

  test "captures one raw record for a broadcast or drop and tolerates a stalled and failing sink",
       context do
    owner = self()

    sink = fn event ->
      send(owner, {:audit, self(), event})

      receive do
        :release -> :ok
        :fail -> raise "sink failed"
      end
    end

    {hub, writer, target} = audit_peers(context, :traffic, sink: sink, queue_limit: 1)

    assert :ok = Node.send(writer, @managed, audit_write(42, 20.5))

    assert_receive {:audit, worker, %{__struct__: Event, kind: :frame, capture_id: write_id}},
                   1000

    send(worker, :release)

    assert_receive {:audit, ^worker,
                    %{__struct__: Event, kind: :write_request, capture_id: ^write_id}},
                   1000

    send(worker, :release)
    eventually(fn -> Hub.audit_status(hub).queued == 0 end)

    broadcast = BVLC.broadcast()
    assert :ok = Node.send(writer, broadcast, <<0x10, 8>>, data_options: [{1, true, nil}])

    assert_receive {:audit, ^worker,
                    %{
                      __struct__: Event,
                      kind: :frame,
                      destination_vmac: ^broadcast,
                      routing: {:queued, 1},
                      egress: nil,
                      details: %BVLC{data_options: [{1, true, nil}], payload: payload}
                    }},
                   1000

    assert {:ok, {%{is_network_message: false}, <<0x10, 8>>}} =
             BACnet.Protocol.decode_npci(payload)

    assert_receive {:bacnet_transport, _, @peer, {:apdu, _, _, <<0x10, 8>>}, ^target}, 1000
    assert :ok = Node.send(writer, @managed, <<0x10, 8>>)
    assert_receive {:bacnet_transport, _, @peer, {:apdu, _, _, <<0x10, 8>>}, ^target}, 1000

    assert %{__struct__: Audit.Status, mode: :traffic, queue_drops: 1, queued: 1} =
             Hub.audit_status(hub)

    send(worker, :release)
    eventually(fn -> match?(%{queued: 0, correlation_losses: 1}, Hub.audit_status(hub)) end)
    unknown = <<7::48>>
    assert :ok = Node.send(writer, unknown, <<0x10, 8>>)

    assert_receive {:audit, ^worker,
                    %{
                      __struct__: Event,
                      kind: :frame,
                      destination_vmac: ^unknown,
                      routing: :no_recipient
                    }},
                   1000

    send(worker, :fail)
    eventually(fn -> Hub.audit_status(hub).sink_failures == 1 end)
    assert :ok = Node.send(writer, @managed, <<0x10, 8>>)

    assert_receive {:audit, ^worker, %{__struct__: Event, kind: :frame, routing: {:queued, 1}}},
                   1000

    send(worker, :release)
    stop_test_fixtures()
  end

  test "enables and disables write auditing for already connected peers", context do
    opts = hub_opts(context, 0, @hub)
    hub = start_supervised!({Hub, opts})
    primary = uri(Hub.port(hub))
    writer = start_node(context, primary, nil, @peer, <<2::128>>, self())
    target = start_node(context, primary, nil, @managed, <<3::128>>, self())
    eventually(fn -> Node.status(writer).active == :primary end)
    eventually(fn -> Node.status(target).active == :primary end)

    owner = self()

    sink = fn event ->
      send(owner, {:audit, event})
      :ok
    end

    assert :ok = Hub.reconfigure(hub, Keyword.put(opts, :audit, mode: :writes, sink: sink))
    assert %{mode: :writes} = Hub.audit_status(hub)

    session = :sys.get_state(writer).attempts.primary.pid

    address_request = %BVLC{
      function: :address_resolution,
      id: 42,
      source: nil,
      destination: @managed,
      destination_options: [],
      data_options: [],
      payload: <<>>
    }

    assert :ok = GenServer.call(session, {:send_frame, address_request})
    assert_receive {:bacnet_transport, _, @managed, {:bvlc, %BVLC{id: 42}}, ^writer}

    assert :ok = Node.send(writer, @managed, audit_write(20, 20.5))
    assert_receive {:audit, %{kind: :write_request, details: %{invoke_id: 20}}}
    refute_received {:audit, _event}

    assert :ok = Hub.reconfigure(hub, opts)
    assert %{mode: :disabled, queued: 0} = Hub.audit_status(hub)
    assert :ok = Node.send(writer, @managed, audit_write(21, 21.5))

    assert_receive {:bacnet_transport, _, @peer,
                    {:apdu, _, _, <<_flags, _limits, 21, _tags::binary>>}, ^target}

    refute_receive {:audit, _event}
    stop_test_fixtures()
  end

  test "restarts a crashed audit worker and accounts for captures it lost", context do
    owner = self()

    sink = fn event ->
      send(owner, {:audit, self(), event})

      receive do
        :release -> :ok
      end
    end

    {hub, writer, target} = audit_peers(context, :traffic, sink: sink)
    assert :ok = Node.send(writer, @managed, <<0x10, 8>>)
    assert_receive {:audit, worker, %{kind: :frame}}
    assert_receive {:bacnet_transport, _, @peer, {:apdu, _, _, <<0x10, 8>>}, ^target}
    assert %{queued: 1} = Hub.audit_status(hub)

    log =
      ExUnit.CaptureLog.capture_log([level: :warning], fn ->
        Process.exit(worker, :kill)

        eventually(fn ->
          match?(%{queue_drops: 1, queued: 0, correlation_losses: 1}, Hub.audit_status(hub))
        end)
      end)

    assert log =~ "Audit worker exited"

    assert :ok = Node.send(writer, @managed, <<0x10, 8>>)
    assert_receive {:audit, replacement, %{kind: :frame}}
    refute replacement == worker
    send(replacement, :release)

    assert_receive {:bacnet_transport, _, @peer, {:apdu, _, _, <<0x10, 8>>}, ^target}
    eventually(fn -> Hub.audit_status(hub).queued == 0 end)
    stop_test_fixtures()
  end

  test "serves BACnet management and rotates the operational certificate", context do
    next_key = X509.PrivateKey.new_ec(:secp256r1)
    next_ca = X509.Certificate.self_signed(next_key, "/CN=Next SC CA", template: :root_ca)
    next_pem = X509.Certificate.to_pem(next_ca)
    {hub_cert, hub_key} = certificate(context, "Hub")
    {:ok, trust} = Credentials.from_pem(hub_cert, hub_key, [context.ca_pem, next_pem])
    hub_opts = Keyword.put(hub_opts(context, 0, @hub), :credentials, trust)
    hub = start_supervised!({Hub, hub_opts})
    primary = uri(Hub.port(hub))
    {manager, client} = start_requester(context, primary, @peer, <<2::size(128)>>)
    {certificate, private_key} = certificate(context, "Managed")

    directory =
      Path.join(System.tmp_dir!(), "bacstack-sc-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(directory) end)

    managed_opts = [
      storage_dir: directory,
      device_instance: 123,
      port_instance: 1,
      file_instances: @file_ids,
      vendor_id: 0,
      certificate_pem: certificate,
      private_key_pem: private_key,
      issuer_pems: [context.ca_pem],
      transport: [primary_hub_uri: primary, vmac: @managed, min_reconnect_time: 2],
      hub: [port: Hub.port(hub), ip: @loopback, enabled: false, accept_uris: [primary]],
      authorize: fn _request, source -> source.vmac == @peer end
    ]

    managed = start_supervised!({ManagedPort, managed_opts})
    %{transport: node} = ManagedPort.endpoints(managed)
    assert {:error, :standalone_mode} = ManagedPort.refresh_objects(managed, %{})
    eventually(fn -> Node.status(manager).active == :primary end)
    eventually(fn -> Node.status(node).active == :primary end)

    port_id = %ObjectIdentifier{type: :network_port, instance: 1}
    device_id = %ObjectIdentifier{type: :device, instance: 123}
    uuid = read(client, @managed, device_id, :device_uuid)
    assert <<_uuid::size(128)>> = uuid
    assert read(client, @managed, port_id, :sc_primary_hub_uri) == primary
    assert read(client, @managed, port_id, :sc_hub_connector_state) == 1

    {:ok, reply} =
      request(client, @managed, %ReadProperty{
        object_identifier: port_id,
        property_identifier: :current_health,
        property_array_index: nil
      })

    {:ok, %{property_value: health}} = ReadPropertyAck.from_apdu(reply)

    assert {:ok, {%Health{result: %{class: :object, code: :success}}, []}} =
             Health.parse(Enum.map(health, &Encoding.to_encoding!/1))

    exercise_property_access(client, device_id, port_id, primary)
    exercise_file_validation(client, port_id)

    {outsider, outsider_client} =
      start_requester(context, primary, <<2, 0, 0, 0, 0, 4>>, <<4::size(128)>>)

    eventually(fn -> Node.status(outsider).active == :primary end)

    assert {:ok, %APDU.Error{code: :service_request_denied}} =
             write(outsider_client, @managed, port_id, :command, {:enumerated, 8})

    assert {:ok, %APDU.SimpleACK{}} =
             write(
               client,
               @managed,
               port_id,
               :sc_failover_hub_uri,
               {:character_string, "wss://localhost:4443/"}
             )

    assert read(client, @managed, port_id, :changes_pending)

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :command, {:enumerated, 1})

    refute read(client, @managed, port_id, :changes_pending)

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :command, {:enumerated, 8})

    csr_id = %ObjectIdentifier{type: :file, instance: @file_ids.csr}
    operational = %ObjectIdentifier{type: :file, instance: @file_ids.operational}

    assert {:ok, apdu} =
             request(client, @managed, %AtomicReadFile{
               object_identifier: csr_id,
               stream_access: true,
               start_position: 0,
               requested_count: 1000
             })

    assert {:ok, %{data: pem, eof: true}} = AtomicReadFileAck.from_apdu(apdu)
    csr = X509.CSR.from_pem!(pem)
    assert X509.CSR.valid?(csr)

    # An operational renewal can still use the installed key after a CSR was generated.
    %{snapshot: snapshot} = :sys.get_state(managed)
    active = snapshot.certificates.operational

    assert {:ok, %{key: key}} =
             ManagedPort.runtime_config(
               %{snapshot | uploads: %{operational: active}},
               :proposed
             )

    assert key == snapshot.active_key

    {mismatched, _key} = certificate(context, "Wrong key")

    assert {:error, {:operational_certificate_file, :security, :unknown_certificate_key}} =
             ManagedPort.runtime_config(
               %{snapshot | uploads: %{operational: mismatched}},
               :proposed
             )

    assert {:error, {:sc_primary_hub_uri, :property, :value_out_of_range}} =
             ManagedPort.runtime_config(
               %{snapshot | pending: %{sc_primary_hub_uri: "ws://invalid/"}},
               :proposed
             )

    replacement =
      csr
      |> X509.CSR.public_key()
      |> X509.Certificate.new(X509.CSR.subject(csr), next_ca, next_key, template: :server)
      |> X509.Certificate.to_pem()

    issuer = %ObjectIdentifier{type: :file, instance: @file_ids.issuer_2}

    assert {:ok, apdu} =
             request(client, @managed, %AtomicWriteFile{
               object_identifier: issuer,
               stream_access: true,
               start_position: 0,
               data: next_pem
             })

    assert {:ok, %{start_position: 0}} = AtomicWriteFileAck.from_apdu(apdu)

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, operational, :file_size, {:unsigned_integer, 0})

    assert {:ok, apdu} =
             request(client, @managed, %AtomicWriteFile{
               object_identifier: operational,
               stream_access: true,
               start_position: 0,
               data: replacement
             })

    assert {:ok, %{start_position: 0}} = AtomicWriteFileAck.from_apdu(apdu)
    assert read(client, @managed, port_id, :changes_pending)

    assert {:ok, %APDU.SimpleACK{}} =
             request(client, @managed, %ReinitializeDevice{
               reinitialized_state: :activate_changes,
               password: nil
             })

    eventually(fn -> Node.status(node).active == :primary end)
    refute read(client, @managed, port_id, :changes_pending)
    assert read(client, @managed, issuer, :file_size) == byte_size(next_pem)

    # The configured local hub cannot bind while the external hub holds its port.
    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :sc_hub_function_enable, {:boolean, true})

    assert {:ok, %APDU.Error{code: :operational_problem}} =
             request(client, @managed, %ReinitializeDevice{
               reinitialized_state: :activate_changes,
               password: nil
             })

    assert %{hub: nil} = ManagedPort.endpoints(managed)
    assert read(client, @managed, port_id, :changes_pending)

    :ok = stop_supervised(ManagedPort)
    restarted = start_supervised!({ManagedPort, managed_opts})
    %{transport: restarted_node} = ManagedPort.endpoints(restarted)
    eventually(fn -> Node.status(restarted_node).active == :primary end)
    assert read(client, @managed, device_id, :device_uuid) == uuid
    assert read(client, @managed, operational, :file_size) == byte_size(replacement)
    assert read(client, @managed, port_id, :changes_pending)

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :command, {:enumerated, 1})

    refute read(client, @managed, port_id, :sc_hub_function_enable)

    before_restart = Node.status(restarted_node).primary.connected_at

    assert {:ok, %APDU.SimpleACK{}} =
             request(client, @managed, %ReinitializeDevice{
               reinitialized_state: :warmstart,
               password: nil
             })

    eventually(fn ->
      status = Node.status(restarted_node)
      status.active == :primary and status.primary.connected_at != before_restart
    end)

    stop_test_fixtures()
  end

  test "delegates discovery to the host and rotates credentials on its existing objects",
       context do
    hub = start_supervised!({Hub, hub_opts(context, 0, @hub)})
    primary = uri(Hub.port(hub))
    {requester, client} = start_requester(context, primary, @peer, <<2::size(128)>>)
    original = host_objects(primary)
    {cert, key} = certificate(context, "Hosted Device")

    directory =
      Path.join(System.tmp_dir!(), "bacstack-sc-hosted-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(directory) end)

    opts = [
      mode: :hosted,
      host: self(),
      objects: original,
      storage_dir: directory,
      certificate_pem: cert,
      private_key_pem: key,
      issuer_pems: [context.ca_pem],
      authorize: fn _request, source -> source.vmac == @peer end
    ]

    managed = start_supervised!({ManagedPort, opts})
    %{client: port_client, transport: node} = ManagedPort.endpoints(managed)
    eventually(fn -> Node.status(node).active == :primary end)
    eventually(fn -> Node.status(requester).active == :primary end)
    assert %{device: nil, port: nil, files: nil} = :sys.get_state(managed)
    assert {:ok, objects} = ManagedPort.refresh_objects(managed, original)
    assert objects.device == original.device
    assert objects.port.object_name == "Host SC Port"
    assert objects.port.sc_hub_connector_state == :connected_to_primary
    assert objects.files.operational.object_name == "Host operational"
    assert objects.files.operational.file_size == byte_size(cert)

    assert {:error, :not_object_host} =
             Task.await(Task.async(fn -> ManagedPort.refresh_objects(managed, objects) end))

    assert {:error, :invalid_host_objects} =
             ManagedPort.refresh_objects(
               managed,
               put_in(objects.device.device_uuid, <<19::size(128)>>)
             )

    assert {:error, :invalid_client_notification} =
             ManagedPort.handle_request(managed, {:unrelated, client}, objects)

    {:ok, who_is} = WhoIs.to_apdu(%WhoIs{device_id_low_limit: nil, device_id_high_limit: nil}, [])
    assert :ok = Node.send(requester, BVLC.broadcast(), who_is)

    assert_receive {:bacnet_client, nil, %APDU.UnconfirmedServiceRequest{service: :who_is},
                    {@peer, _bvlc, _npci}, ^port_client}

    refute_receive {:bacnet_client, nil, %APDU.UnconfirmedServiceRequest{service: :i_am}, _source,
                    ^client},
                   50

    device = %ObjectIdentifier{type: :device, instance: 4_194_303}
    port = %ObjectIdentifier{type: :network_port, instance: 7}
    csr_file = %ObjectIdentifier{type: :file, instance: @file_ids.csr}
    operational = %ObjectIdentifier{type: :file, instance: @file_ids.operational}

    service = %ReadProperty{
      object_identifier: device,
      property_identifier: :object_name,
      property_array_index: nil
    }

    assert {{:ok, response}, {:ok, objects}} =
             hosted_exchange(managed, client, objects, service)

    assert {:ok, %{property_value: %{value: "Central BACnet host"}}} =
             ReadPropertyAck.from_apdu(response)

    for {id, property} <- [{port, :object_name}, {operational, :object_name}] do
      assert {{:ok, %APDU.ComplexACK{}}, {:ok, ^objects}} =
               hosted_exchange(managed, client, objects, %{
                 service
                 | object_identifier: id,
                   property_identifier: property
               })
    end

    owned_read = %ReadPropertyMultiple{
      list: [%AccessSpecification{object_identifier: port, properties: [:required]}]
    }

    assert {{:ok, %APDU.ComplexACK{}}, {:ok, ^objects}} =
             hosted_exchange(managed, client, objects, owned_read)

    assert {{:ok, %APDU.SimpleACK{}}, :unhandled} =
             hosted_exchange(managed, client, objects, %DeviceCommunicationControl{
               state: :enable,
               time_duration: nil,
               password: nil
             })

    mixed = %ReadPropertyMultiple{
      list: [
        %AccessSpecification{object_identifier: port, properties: [:required]},
        %AccessSpecification{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 2},
          properties: [:required]
        }
      ]
    }

    assert {{:ok, %APDU.Error{code: :unknown_object}}, :unhandled} =
             hosted_exchange(managed, client, objects, mixed)

    other_writes = [
      host_write(device, :object_name, {:character_string, "Renamed by host"}),
      host_write(port, :object_name, {:character_string, "Renamed by host"}),
      host_write(operational, :object_name, {:character_string, "Renamed by host"})
    ]

    for service <- other_writes do
      assert {{:ok, %APDU.Error{code: :unknown_object}}, :unhandled} =
               hosted_exchange(managed, client, objects, service)
    end

    assert {{:ok, %APDU.SimpleACK{}}, {:ok, objects}} =
             hosted_exchange(
               managed,
               client,
               objects,
               host_write(port, :command, {:enumerated, 8})
             )

    assert objects.files.csr.file_size > 0
    assert objects.files.csr.read_only

    assert {{:ok, response}, {:ok, objects}} =
             hosted_exchange(managed, client, objects, %AtomicReadFile{
               object_identifier: csr_file,
               stream_access: true,
               start_position: 0,
               requested_count: 1000
             })

    assert {:ok, %{data: pem, eof: true}} = AtomicReadFileAck.from_apdu(response)
    csr = X509.CSR.from_pem!(pem)
    assert X509.CSR.valid?(csr)
    public_key = X509.CSR.public_key(csr)

    replacement =
      public_key
      |> X509.Certificate.new(X509.CSR.subject(csr), context.ca, context.ca_key,
        template: :server
      )
      |> X509.Certificate.to_pem()

    assert {{:ok, %APDU.SimpleACK{}}, {:ok, objects}} =
             hosted_exchange(
               managed,
               client,
               objects,
               host_write(operational, :file_size, {:unsigned_integer, 0})
             )

    assert {{:ok, %APDU.ComplexACK{}}, {:ok, objects}} =
             hosted_exchange(managed, client, objects, %AtomicWriteFile{
               object_identifier: operational,
               stream_access: true,
               start_position: 0,
               data: replacement
             })

    assert {{:ok, %APDU.SimpleACK{}}, {:ok, objects}} =
             hosted_exchange(
               managed,
               client,
               objects,
               host_write(port, :sc_heartbeat_timeout, {:unsigned_integer, 40})
             )

    assert {{:ok, %APDU.SimpleACK{}}, {:ok, objects}} =
             hosted_exchange(
               managed,
               client,
               objects,
               host_write(port, :network_number, {:unsigned_integer, 42})
             )

    assert objects.port.changes_pending
    assert {:ok, %{sc_heartbeat_timeout: 300}} = NetworkPort.active_configuration(objects.port)
    assert objects.files.operational.file_size == byte_size(replacement)
    refute objects.files.operational.archive

    activate = %ReinitializeDevice{reinitialized_state: :activate_changes, password: nil}

    assert {{:ok, %APDU.SimpleACK{}}, {:ok, objects}} =
             hosted_exchange(managed, client, objects, activate)

    refute objects.port.changes_pending
    assert {:ok, %{sc_heartbeat_timeout: 40}} = NetworkPort.active_configuration(objects.port)
    eventually(fn -> Node.status(node).active == :primary end)

    assert {{:ok, %APDU.SimpleACK{}}, {:ok, objects}} =
             hosted_exchange(
               managed,
               client,
               objects,
               host_write(port, :sc_heartbeat_timeout, {:unsigned_integer, 50})
             )

    assert {{:ok, %APDU.ComplexACK{}}, {:ok, objects}} =
             hosted_exchange(managed, client, objects, %AtomicWriteFile{
               object_identifier: operational,
               stream_access: true,
               start_position: -1,
               data: "staged"
             })

    assert objects.port.sc_heartbeat_timeout == 50
    :ok = stop_supervised(ManagedPort)
    restarted = start_supervised!({ManagedPort, opts})
    {:ok, host_port} = NetworkPort.add_property(original.port, :reference_port, 11)
    {:ok, host_port} = NetworkPort.update_property(host_port, :reference_port, 12)
    original = %{original | port: host_port}
    assert {:error, :refresh_required} = ManagedPort.activate(restarted, original)
    assert {:ok, restored} = ManagedPort.refresh_objects(restarted, original)
    assert restored.device == original.device
    assert restored.port.changes_pending
    assert restored.port.sc_heartbeat_timeout == 50
    assert restored.port.reference_port == 12

    assert {:ok,
            %{
              sc_heartbeat_timeout: 40,
              reference_port: 11,
              network_number: 42,
              network_number_quality: :configured
            }} =
             NetworkPort.active_configuration(restored.port)

    assert restored.files.operational.file_size == byte_size(replacement) + byte_size("staged")
    assert restored.files.operational.object_name == original.files.operational.object_name

    %{transport: restarted_node} = ManagedPort.endpoints(restarted)
    eventually(fn -> Node.status(restarted_node).active == :primary end)

    assert {{:ok, %APDU.Error{code: :operational_problem}}, {:error, :refresh_required}} =
             hosted_exchange(
               restarted,
               client,
               original,
               host_write(port, :sc_heartbeat_timeout, {:unsigned_integer, 65})
             )

    assert {{:ok, %APDU.SimpleACK{}}, {:ok, discarded}} =
             hosted_exchange(
               restarted,
               client,
               restored,
               host_write(port, :command, {:enumerated, 1})
             )

    refute discarded.port.changes_pending
    assert discarded.port.sc_heartbeat_timeout == 40
    assert discarded.files.operational.file_size == byte_size(replacement)

    assert {{:ok, %APDU.SimpleACK{}}, {:ok, staged}} =
             hosted_exchange(
               restarted,
               client,
               discarded,
               host_write(port, :sc_heartbeat_timeout, {:unsigned_integer, 60})
             )

    assert :ok = stop_supervised(Hub)
    eventually(fn -> Node.status(restarted_node).active == nil end)
    assert {:ok, activated} = ManagedPort.activate(restarted, staged)
    assert {:ok, %{sc_heartbeat_timeout: 60}} = NetworkPort.active_configuration(activated.port)
    refute activated.port.changes_pending

    stop_test_fixtures()
  end

  test "validates hosted bindings and exposes the host's local hub", context do
    host_name = {__MODULE__, make_ref()}
    assert :yes = :global.register_name(host_name, self())
    original = host_objects("", sc_hub_function_enable: true)
    {cert, key} = certificate(context, "Hosted Hub")

    directory =
      Path.join(System.tmp_dir!(), "bacstack-sc-hosted-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(directory) end)

    opts = [
      mode: :hosted,
      host: {:global, host_name},
      objects: original,
      storage_dir: directory,
      hub: [port: 0, ip: @loopback],
      certificate_pem: cert,
      private_key_pem: key,
      issuer_pems: [context.ca_pem]
    ]

    for overrides <- [
          [mode: :unknown],
          [host: nil],
          [host: {:global, make_ref()}],
          [hub: nil],
          [hub: []],
          [objects: put_in(original.files.csr.read_only, false)],
          [objects: put_in(original.files.issuer_2, original.files.issuer_1)],
          [objects: put_in(original.port.mac_address, <<0::size(48)>>)],
          [
            objects:
              put_in(
                original.port.operational_certificate_file,
                original.port.certificate_signing_request_file
              )
          ]
        ] do
      spec = Supervisor.child_spec({ManagedPort, Keyword.merge(opts, overrides)}, id: make_ref())
      assert {:error, _reason} = start_supervised(spec)
    end

    managed = start_supervised!({ManagedPort, opts})
    %{hub: hub} = ManagedPort.endpoints(managed)
    assert is_pid(hub)
    assert {:ok, objects} = ManagedPort.refresh_objects(managed, original)
    assert objects.port.sc_hub_function_binding == Integer.to_string(Hub.port(hub))

    assert {:error, :invalid_host_objects} =
             ManagedPort.refresh_objects(managed, %{objects | files: %{}})

    :ok = stop_supervised(ManagedPort)
    wrong_device = put_in(original.device.device_uuid, <<9::size(128)>>)
    opts = Keyword.put(opts, :objects, wrong_device)
    assert {:error, _reason} = start_supervised({ManagedPort, opts})
    stop_test_fixtures()
  end

  test "forwards broadcast once and returns to the primary hub", context do
    primary_hub = start_supervised!({Hub, hub_opts(context, 0, @hub)})

    assert %{
             __struct__: Audit.Status,
             mode: :disabled,
             queued: 0,
             queue_drops: 0,
             sink_failures: 0,
             correlation_losses: 0
           } = Hub.audit_status(primary_hub)

    failover_hub =
      start_supervised!(
        Supervisor.child_spec({Hub, hub_opts(context, 0, <<5::size(48)>>)}, id: :backup)
      )

    primary_port = Hub.port(primary_hub)
    primary = uri(primary_port)
    failover = uri(Hub.port(failover_hub))
    first = start_node(context, primary, failover, @hub, <<1::size(128)>>, self())
    second = start_node(context, primary, failover, @peer, <<2::size(128)>>, self())
    eventually(fn -> Node.status(first).active == :primary end)
    eventually(fn -> Node.status(second).active == :primary end)

    assert %{
             __struct__: Node.Status,
             primary: %{__struct__: Node.ConnectionStatus, failed_at: nil},
             failover: nil
           } = Node.status(first)

    {:ok, apdu} = WhoIs.to_apdu(%WhoIs{device_id_low_limit: nil, device_id_high_limit: nil}, [])

    assert :ok =
             Node.send(first, Node.get_broadcast_address(first), apdu,
               data_options: [{1, true, nil}]
             )

    assert_receive {:bacnet_transport, {:bacnet_sc, Node}, @hub,
                    {:apdu, %{data_options: [{1, true, nil}]}, _, _}, ^second},
                   1000

    refute_receive {:bacnet_transport, _, @hub, _, ^first}

    warnings =
      ExUnit.CaptureLog.capture_log([level: :warning], fn ->
        assert :ok = stop_supervised(Hub)
        eventually(fn -> Node.status(first).active == :failover end)
        eventually(fn -> Node.status(second).active == :failover end)
      end)

    assert warnings =~ "[warning] BacScNode: Lost active primary hub connection"
    assert warnings =~ ~s({"127.0.0.1", #{primary_port}})

    assert %{connected_at: %DateTime{}, failed_at: %DateTime{}} =
             Node.status(first).primary

    assert :ok = Node.send(first, @peer, apdu)
    assert_receive {:bacnet_transport, _, @hub, {:apdu, %{destination: nil}, _, _}, ^second}

    restarted = start_supervised!({Hub, hub_opts(context, primary_port, @hub)})
    eventually(fn -> Node.status(first).active == :primary end)
    eventually(fn -> Node.status(second).active == :primary end)
    eventually(fn -> Hub.status(failover_hub).connections == [] end)

    eventually(fn ->
      match?(%{error: nil, disconnected_at: %DateTime{}}, Node.status(first).failover)
    end)

    first_connection = Node.status(first).primary.connected_at
    assert :ok = Hub.reconfigure(restarted, hub_opts(context, primary_port, @hub))

    eventually(fn ->
      status = Node.status(first)
      status.active == :primary and status.primary.connected_at != first_connection
    end)

    assert Hub.port(restarted) == primary_port

    stop_test_fixtures()
  end

  test "warns about Gun errors and treats a BACnet disconnect as graceful", context do
    hub = start_supervised!({Hub, hub_opts(context, 0, @hub)})
    port = Hub.port(hub)
    node = start_node(context, uri(port), nil, @peer, <<2::size(128)>>, self())
    eventually(fn -> Node.status(node).active == :primary end)

    warnings =
      ExUnit.CaptureLog.capture_log([level: :warning], fn ->
        assert :ok = Hub.restart_connections(hub)
        eventually(fn -> Node.status(node).primary.error == :closed end)
      end)

    refute warnings =~ "BacScNode:"
    eventually(fn -> Node.status(node).active == :primary end)
    session = :sys.get_state(node).attempts.primary.pid
    %{socket: socket, stream: stream} = :sys.get_state(session)

    warnings =
      ExUnit.CaptureLog.capture_log([level: :warning], fn ->
        send(session, {:gun_error, socket, stream, :econnreset})

        eventually(fn ->
          Node.status(node).primary.error == {:gun_error, :econnreset}
        end)
      end)

    assert warnings =~ "[warning] BacScNode: Lost active primary hub connection"
    assert warnings =~ ~s({"127.0.0.1", #{port}} with {:gun_error, :econnreset})
    assert length(Regex.scan(~r/BacScNode: Lost active primary hub connection/, warnings)) == 1
    stop_test_fixtures()
  end

  test "enforces the hub subprotocol and certificate trust and resolves VMAC conflicts",
       context do
    hub = start_supervised!({Hub, hub_opts(context, 0, @hub)})
    port = Hub.port(hub)
    primary = uri(port)
    first = start_node(context, primary, nil, @peer, <<2::size(128)>>, self())
    eventually(fn -> Node.status(first).active == :primary end)
    conflicting = start_node(context, primary, nil, @peer, <<3::size(128)>>, self())
    eventually(fn -> Node.status(conflicting).active == :primary end)

    <<_high::size(4), 2::size(4), _rest::size(40)>> =
      new_vmac = Node.get_local_address(conflicting)

    refute new_vmac == @peer

    assert %{
             __struct__: Hub.Status,
             connections: [%{__struct__: Hub.Session} | _connections],
             failed: [%{__struct__: Hub.Failure, code: 151} | _older_failures]
           } = Hub.status(hub)

    # Keep the original node from racing the replacement with an immediate retry.
    :sys.replace_state(first, fn state ->
      put_in(state.last_start[:primary], System.monotonic_time(:millisecond))
    end)

    replacement_vmac = <<2, 0, 0, 0, 0, 9>>
    replacement = start_node(context, primary, nil, replacement_vmac, <<2::size(128)>>, self())
    eventually(fn -> Node.status(replacement).active == :primary end)
    :ok = Node.close(first)

    eventually(fn ->
      registered = Enum.map(Hub.status(hub).connections, & &1.peer.vmac)
      Enum.sort(registered) == Enum.sort([new_vmac, replacement_vmac])
    end)

    tls = Credentials.tls(%{credentials: credentials(context, "Raw client")}, :client)

    {:ok, socket} =
      :gun.open(~c"127.0.0.1", port, %{transport: :tls, tls_opts: tls, protocols: [:http]})

    on_exit(fn -> :gun.close(socket) end)
    assert {:ok, :http} = :gun.await_up(socket, 2000)
    stream = :gun.ws_upgrade(socket, "/")
    assert {:response, :fin, 400, _headers} = :gun.await(socket, stream, 2000)

    other_key = X509.PrivateKey.new_ec(:secp256r1)
    other_ca = X509.Certificate.self_signed(other_key, "/CN=Untrusted CA", template: :root_ca)
    untrusted = %{ca: other_ca, ca_key: other_key, ca_pem: X509.Certificate.to_pem(other_ca)}
    node = start_node(untrusted, primary, nil, <<2, 0, 0, 0, 0, 10>>, <<10::size(128)>>, self())
    eventually(fn -> not is_nil(Node.status(node).primary) end)
    assert Node.status(node).active == nil
    assert {:error, :not_connected} = Node.send(node, @peer, <<0x10, 8>>)

    stop_test_fixtures()
  end

  test "disconnects a session after an unmatched heartbeat acknowledgment" do
    config = %{
      vmac: @hub,
      device_uuid: <<1::size(128)>>,
      connect_wait_timeout: 5,
      heartbeat_timeout: 1,
      disconnect_wait_timeout: 1
    }

    {:ok, connection} = Connection.start(self(), {:server, self()}, config)

    request = %BVLC{
      function: :connect_request,
      id: 8,
      source: nil,
      destination: nil,
      destination_options: [],
      data_options: [],
      payload: BVLC.identity(@peer, <<2::size(128)>>)
    }

    send(connection, {:sc_websocket, self(), {:binary, BVLC.encode(request)}})
    assert_receive {:"$gen_call", from, {:register, ^connection, _peer}}
    GenServer.reply(from, :ok)
    assert_receive {:sc_send, {:binary, accept}}
    assert {:ok, %BVLC{function: :connect_accept, id: 8}} = BVLC.decode(accept)

    assert_receive {:sc_send, {:binary, probe}}, 2000
    assert {:ok, %BVLC{function: :heartbeat_request, id: probe_id}} = BVLC.decode(probe)

    unexpected = %BVLC{
      function: :heartbeat_ack,
      id: probe_id + 1,
      source: nil,
      destination: nil,
      destination_options: [],
      data_options: [],
      payload: <<>>
    }

    send(connection, {:sc_websocket, self(), {:binary, BVLC.encode(unexpected)}})
    assert_receive {:sc_send, {:binary, disconnect}}, 2000
    assert {:ok, %BVLC{function: :disconnect_request} = disconnect} = BVLC.decode(disconnect)

    ack = BVLC.response(disconnect, :disconnect_ack)
    send(connection, {:sc_websocket, self(), {:binary, BVLC.encode(ack)}})
    assert_receive {:sc_send, {:close, 1000, ""}}
    send(connection, {:sc_websocket, self(), :close})
    assert_receive {:sc_connection, ^connection, {:closed, :heartbeat_timeout}}
  end

  test "forwards raw BVLC exchanges and applies the receiving endpoint's NAK rules", context do
    hub = start_supervised!({Hub, hub_opts(context, 0, @hub)})
    primary = uri(Hub.port(hub))
    first = start_node(context, primary, nil, @peer, <<2::size(128)>>, self())
    second = start_node(context, primary, nil, @managed, <<3::size(128)>>, self())
    eventually(fn -> Node.status(first).active == :primary end)
    eventually(fn -> Node.status(second).active == :primary end)
    session = :sys.get_state(first).attempts.primary.pid

    npdu = %BVLC{
      function: :npdu,
      id: 312,
      source: nil,
      destination: @managed,
      destination_options: [],
      data_options: [],
      payload: <<1, 0, 0x10, 8>>
    }

    logs =
      capture_sc_debug(fn ->
        assert :ok = Node.send(first, @managed, BVLC.encode(npdu), skip_headers: true)

        assert_receive {:bacnet_transport, {:bacnet_sc, Node}, @peer,
                        {:apdu, %BVLC{id: 312, source: @peer}, _npci, _data}, ^second}
      end)

    assert logs =~ "Sending npdu message 312 from VMAC 020000000002 to VMAC 020000000003"
    assert logs =~ "Routed npdu message 312 from VMAC 020000000002 (Device UUID"
    assert logs =~ "to VMAC 020000000003 (queued 1, queue drops 0)"
    assert logs =~ "Received npdu message 312 from VMAC 020000000002 to VMAC 020000000003"

    assert {:error, :invalid_bvlc} =
             Node.send(first, @peer, BVLC.encode(npdu), skip_headers: true)

    assert {:error, :npdu_too_long} =
             Node.send(
               first,
               @managed,
               BVLC.encode(%{npdu | payload: :binary.copy(<<0>>, 1498)}),
               skip_headers: true
             )

    assert {:error, :peer_bvlc_too_long} =
             Node.send(first, @managed, <<0x10, 8>>,
               data_options: [{2, false, :binary.copy(<<0>>, 65_521)}]
             )

    assert {:error, :data_empty} = Node.send(first, @managed, "")

    assert {:error, :invalid_data_options} =
             Node.send(first, @managed, <<0x10, 8>>, data_options: :invalid)

    assert {:error, :invalid_data_options} =
             Node.send(first, @managed, <<0x10, 8>>, data_options: [{1, false, nil}])

    assert {:error, :invalid_destination} = Node.send(first, "", <<0x10, 8>>)

    assert :ok = GenServer.call(session, {:send_frame, %{npdu | source: @peer}})

    assert_receive {:bacnet_transport, _, @hub,
                    {:bvlc, %BVLC{id: 312, payload: <<1, 1, 0, 7::size(16), 80::size(16)>>}},
                    ^first}

    assert :ok = GenServer.call(session, {:send_frame, %{npdu | destination: nil}})

    assert_receive {:bacnet_transport, _, @hub,
                    {:bvlc, %BVLC{id: 312, payload: <<1, 1, 0, 7::size(16), 80::size(16)>>}},
                    ^first}

    address_request = %{npdu | function: :address_resolution, id: 313, payload: <<>>}
    assert :ok = GenServer.call(session, {:send_frame, address_request})

    assert_receive {:bacnet_transport, _, @managed,
                    {:bvlc, %BVLC{id: 313, payload: <<2, 1, 0, 7::size(16), 45::size(16)>>}},
                    ^first}

    solicitation = %{npdu | function: :advertisement_solicitation, id: 314, payload: <<>>}
    assert :ok = GenServer.call(session, {:send_frame, solicitation})

    assert_receive {:bacnet_transport, _, @managed, {:bvlc, %BVLC{function: :advertisement}},
                    ^first}

    assert %{__struct__: Node.Advertisement, hub: 1, max_npdu: 1497} =
             Node.status(first).advertisements[@managed]

    must_understand = %{npdu | destination_options: [{7, true, nil}]}
    assert :ok = GenServer.call(session, {:send_frame, must_understand})

    assert_receive {:bacnet_transport, _, @managed,
                    {:bvlc, %BVLC{id: 312, payload: <<1, 1, 71, 7::size(16), 146::size(16)>>}},
                    ^first}

    assert :ok =
             GenServer.call(
               session,
               {:send_frame, %{must_understand | destination: BVLC.broadcast()}}
             )

    assert :ok = Node.flush(first)
    refute_receive {:bacnet_transport, _, _, {:bvlc, %BVLC{id: 312}}, ^first}

    assert :ok = Node.send(first, <<7::size(48)>>, <<0x10, 8>>)
    assert :ok = Node.flush(first)
    refute_receive {:bacnet_transport, _, _, {:apdu, _, _, _}, ^second}

    config = :sys.get_state(first).config
    assert :ok = Node.reconfigure(first, Map.to_list(config))
    assert :sys.get_state(first).attempts.primary.pid == session
    assert Node.bacnet_protocol() == :bacnet_sc
    refute Node.destination_routed?(first, @managed)
    callback = self()

    assert %{start: {Node, :open, [^callback, []]}} =
             Node.child_spec(callback, [])

    assert %{start: {Node, :open, [^callback, []]}} =
             Node.child_spec([callback, []])

    assert Process.register(first, :sc_named_test_node)
    assert Node.get_portal(:sc_named_test_node) == first

    stop_test_fixtures()
  end

  test "drains an upgraded hub session and releases concurrent callers", context do
    hub =
      start_supervised!(
        Supervisor.child_spec({Hub, hub_opts(context, 0, @hub)}, restart: :temporary)
      )

    remote = {@loopback, 40_000}
    assert {:ok, {session, monitor} = adapter} = WebSocket.websocket_init({hub, remote})
    assert {:ok, ^adapter} = WebSocket.websocket_info(:ignored, adapter)

    options =
      Keyword.put(
        hub_opts(context, 0, @hub),
        :credentials,
        :sys.get_state(hub).config.credentials
      )

    assert :ok = Hub.reconfigure(hub, options)

    assert :ok = GenServer.call(hub, {:set_vmac, @managed})

    frame = %BVLC{
      function: :npdu,
      id: 1,
      source: nil,
      destination: @peer,
      destination_options: [],
      data_options: [],
      payload: <<1, 0, 0x10, 8>>
    }

    assert :ok = GenServer.call(hub, {:route, self(), frame})

    hub_monitor = Process.monitor(hub)
    first = Task.async(fn -> Hub.close(hub) end)
    assert_receive {:sc_send, {:close, 1000, ""}}
    assert {:stop, nil} = WebSocket.websocket_init({hub, remote})
    second = Task.async(fn -> Hub.close(hub) end)
    eventually(fn -> length(:sys.get_state(hub).drain) == 2 end)

    assert {:ok, ^adapter} = WebSocket.websocket_handle(:close, adapter)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal} = message
    assert {:stop, ^adapter} = WebSocket.websocket_info(message, adapter)
    assert :ok = Task.await(first)
    assert :ok = Task.await(second)
    assert_receive {:DOWN, ^hub_monitor, :process, ^hub, :normal}
  end

  test "serves discovery and hub diagnostics through the local listener", context do
    {:ok, reserved} = :gen_tcp.listen(0, ip: @loopback)
    {:ok, {_ip, port}} = :inet.sockname(reserved)
    :ok = :gen_tcp.close(reserved)
    primary = uri(port)
    {cert, key} = certificate(context, "Managed local hub")

    directory =
      Path.join(System.tmp_dir!(), "bacstack-sc-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(directory) end)
    owner = self()

    audit = [
      mode: :writes,
      sink: fn event ->
        send(owner, {:audit, event})
        :ok
      end
    ]

    opts = [
      storage_dir: directory,
      device_instance: 123,
      port_instance: 1,
      file_instances: @file_ids,
      vendor_id: 0,
      certificate_pem: cert,
      private_key_pem: key,
      issuer_pems: [context.ca_pem],
      transport: [primary_hub_uri: primary, vmac: @managed, min_reconnect_time: 2],
      hub: [port: port, ip: @loopback, audit: audit]
    ]

    assert {:error, _reason} =
             start_supervised(
               Supervisor.child_spec({ManagedPort, Keyword.delete(opts, :vendor_id)},
                 id: :invalid
               )
             )

    managed = start_supervised!(Supervisor.child_spec({ManagedPort, opts}, restart: :temporary))
    %{transport: transport, hub: hub} = ManagedPort.endpoints(managed)
    assert %{mode: :writes} = Hub.audit_status(hub)
    refute Keyword.has_key?(:sys.get_state(managed).snapshot.hub, :audit)
    eventually(fn -> Node.status(transport).active == :primary end)
    {requester, client} = start_requester(context, primary, @peer, <<2::size(128)>>)
    eventually(fn -> Node.status(requester).active == :primary end)

    {:ok, who_is} =
      WhoIs.to_apdu(%WhoIs{device_id_low_limit: 100, device_id_high_limit: 150}, [])

    assert :ok = Node.send(requester, BVLC.broadcast(), who_is)

    assert_receive {:bacnet_client, nil, %APDU.UnconfirmedServiceRequest{service: :i_am} = reply,
                    {@managed, _bvlc, _npci}, ^client}

    assert {:ok, %IAm{device: %ObjectIdentifier{instance: 123}}} = IAm.from_apdu(reply)

    duplicate = start_node(context, primary, nil, @peer, <<4::size(128)>>, self())
    eventually(fn -> Node.status(duplicate).active == :primary end)
    assert [%{code: 151} | _failures] = Hub.status(hub).failed

    port_id = %ObjectIdentifier{type: :network_port, instance: 1}

    for property <- [:sc_hub_function_connection_status, :sc_failed_connection_requests] do
      assert {:ok, %APDU.ComplexACK{}} =
               request(client, @managed, %ReadProperty{
                 object_identifier: port_id,
                 property_identifier: property,
                 property_array_index: nil
               })
    end

    assert {:ok, %APDU.Error{code: :service_request_denied}} =
             write(client, @managed, port_id, :command, {:enumerated, 9})

    send(managed, :ignored)
    send(managed, {:EXIT, self(), :normal})
    send(managed, {:sc_vmac, transport, <<0x52, 0, 0, 0, 0, 4>>})
    assert %{hub: ^hub} = ManagedPort.endpoints(managed)
    assert {:ok, %{transport: settings}} = Store.read(Path.join(directory, "sc-port.term"))
    assert settings[:vmac] == <<0x52, 0, 0, 0, 0, 4>>
    send(managed, {:sc_vmac, transport, @managed})
    assert %{hub: ^hub} = ManagedPort.endpoints(managed)

    observation =
      struct!(Node.ConnectionStatus,
        peer: nil,
        connected_at: nil,
        disconnected_at: nil,
        failed_at: nil,
        error: {:connect_rejected, 151}
      )

    now = DateTime.utc_now()

    assert %{state: 2, error: %{code: :websocket_error}} =
             Objects.connector(false, %{observation | connected_at: now, error: :closed_by_peer})

    assert %{state: 3, error: %{code: 151}} =
             Objects.connector(false, observation)

    assert {:ok, %APDU.Reject{reason: :unrecognized_service}} =
             request(client, @managed, %DeviceCommunicationControl{
               state: :enable,
               time_duration: nil,
               password: nil
             })

    for authorize <- [
          fn _service, _source -> raise "policy unavailable" end,
          fn _service, _source -> throw(:policy_unavailable) end
        ] do
      :sys.replace_state(managed, &%{&1 | authorize: authorize})

      assert {:ok, %APDU.Error{code: :service_request_denied}} =
               write(client, @managed, port_id, :command, {:enumerated, 9})
    end

    :sys.replace_state(managed, &%{&1 | authorize: fn _service, _source -> true end})
    exercise_local_reconfiguration(managed, hub, transport, requester, client, port_id)

    %{segmentator: segmentator} = :sys.get_state(managed)
    monitor = Process.monitor(managed)
    :ok = GenServer.stop(segmentator)
    assert_receive {:DOWN, ^monitor, :process, ^managed, {:sc_child_exited, :normal}}

    assert Enum.all?([Node, Hub, ManagedPort, Connection, Audit], fn module ->
             module.format_status(%{state: :sensitive, message: :sensitive, log: [:sensitive]}) ==
               %{state: :redacted, message: :redacted, log: []}
           end)

    stop_test_fixtures()
  end

  defp exercise_local_reconfiguration(managed, hub, transport, requester, client, port_id) do
    activate = %ReinitializeDevice{reinitialized_state: :activate_changes, password: nil}
    assert {:ok, %APDU.SimpleACK{}} = request(client, @managed, activate)

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :sc_connect_wait_timeout, {:unsigned_integer, 12})

    assert {:ok, %APDU.SimpleACK{}} = request(client, @managed, activate)
    assert %{hub: ^hub} = ManagedPort.endpoints(managed)
    eventually(fn -> Node.status(transport).active == :primary end)
    assert %{config: %{connect_wait_timeout: 12}} = :sys.get_state(hub)
    assert %{mode: :writes} = Hub.audit_status(hub)

    connected_at =
      Map.new([transport, requester], fn node ->
        {node, Node.status(node).primary.connected_at}
      end)

    assert :ok = Hub.restart_connections(hub)

    eventually(fn ->
      Enum.all?(connected_at, fn {node, before} ->
        status = Node.status(node)
        status.active == :primary and status.primary.connected_at != before
      end)
    end)

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :sc_hub_function_enable, {:boolean, false})

    assert_receive {:audit,
                    %{
                      __struct__: Event,
                      kind: :write_request,
                      details: %{writes: [%{property_identifier: :sc_hub_function_enable}]}
                    }}

    assert {:ok, %APDU.SimpleACK{}} = request(client, @managed, activate)
    assert %{hub: nil} = ManagedPort.endpoints(managed)
    eventually(fn -> not Process.alive?(hub) end)
  end

  test "reserves the listener VMAC before its local node joins and forwards over IPv6", context do
    loopback = {0, 0, 0, 0, 0, 0, 0, 1}
    hub = start_supervised!({Hub, Keyword.put(hub_opts(context, 0, @hub), :ip, loopback)})
    primary = "wss://[::1]:#{Hub.port(hub)}/"

    peer = start_node(context, primary, nil, @hub, <<2::128>>, self())
    eventually(fn -> Node.status(peer).active == :primary end)
    changed_vmac = Node.get_local_address(peer)
    refute changed_vmac == @hub
    assert [%{code: 151, remote: {^loopback, _port}}] = Hub.status(hub).failed

    local = start_node(context, primary, nil, @hub, <<1::128>>, self())
    eventually(fn -> Node.status(local).active == :primary end)
    assert Node.get_local_address(local) == @hub
    assert :ok = Node.send(peer, @hub, <<0x10, 8>>)

    assert_receive {:bacnet_transport, {:bacnet_sc, Node}, ^changed_vmac,
                    {:apdu, _bvlc, _npci, <<0x10, 8>>}, ^local}

    stop_test_fixtures()
  end

  test "replaces failed connections by peer IP and evicts the oldest at capacity", context do
    hub = start_supervised!({Hub, hub_opts(context, 0, @hub)})

    for last <- 1..33 do
      remote = {{127, 0, 1, last}, 40_001}
      assert {:ok, {session, _monitor} = adapter} = WebSocket.websocket_init({hub, remote})
      send(hub, {:sc_connection, session, {:closed, :connect_timeout}})
      assert {:ok, ^adapter} = WebSocket.websocket_handle(:close, adapter)
    end

    assert Enum.map(Hub.status(hub).failed, fn %{remote: {{127, 0, 1, last}, _port}} -> last end) ==
             Enum.to_list(33..2//-1)

    remote = {{127, 0, 1, 10}, 40_002}
    assert {:ok, {session, _monitor} = adapter} = WebSocket.websocket_init({hub, remote})
    send(hub, {:sc_connection, session, {:closed, :connect_timeout}})
    assert {:ok, ^adapter} = WebSocket.websocket_handle(:close, adapter)
    assert [%{remote: ^remote, code: 30} | other] = Hub.status(hub).failed
    assert length(other) == 31
    refute Enum.any?(other, fn %{remote: {ip, _port}} -> ip == {127, 0, 1, 10} end)

    stop_test_fixtures()
  end

  test "applies WebSocket path and CRL policy changes to the running listener", context do
    opts = hub_opts(context, 0, @hub)
    hub = start_supervised!({Hub, opts})
    port = Hub.port(hub)
    listener = :sys.get_state(hub).listener
    original = start_node(context, uri(port), nil, @peer, <<2::128>>, self())
    eventually(fn -> Node.status(original).active == :primary end)

    path_opts = Keyword.put(opts, :path, "/sc")
    assert :ok = Hub.reconfigure(hub, path_opts)
    assert Hub.port(hub) == port
    assert :primary == Node.status(original).active

    updated = start_node(context, uri(port) <> "sc", nil, @managed, <<3::128>>, self())
    eventually(fn -> Node.status(updated).active == :primary end)

    rejected = start_node(context, uri(port), nil, <<2, 0, 0, 0, 0, 4>>, <<4::128>>, self())
    eventually(fn -> match?(%{primary: %{error: {:http_status, 404}}}, Node.status(rejected)) end)

    assert :ok = Hub.reconfigure(hub, Keyword.put(path_opts, :crl_check, :peer))
    assert Hub.port(hub) == port

    assert :proplists.get_value(:crl_check, :ranch.get_transport_options(listener).socket_opts) ==
             :peer

    eventually(fn -> Node.status(updated).active == nil end)

    assert :ok = Hub.reconfigure(hub, path_opts)

    assert :proplists.get_value(:crl_check, :ranch.get_transport_options(listener).socket_opts) ==
             false

    eventually(fn -> Node.status(updated).active == :primary end)

    stop_test_fixtures()
  end

  test "records a handshake timeout and restores the listener after a failed rebind", context do
    options = hub_opts(context, 0, @hub)
    hub = start_supervised!(Supervisor.child_spec({Hub, options}, restart: :temporary))
    port = Hub.port(hub)
    {:ok, occupied} = :gen_tcp.listen(0, ip: @loopback)
    {:ok, {_address, occupied_port}} = :inet.sockname(occupied)
    listener = :sys.get_state(hub).listener
    dispatch = :cowboy.get_env(listener, :dispatch)
    next = Keyword.merge(options, port: occupied_port, path: "/sc", crl_check: :peer)
    assert {:error, _reason} = Hub.reconfigure(hub, next)
    assert Hub.port(hub) == port
    assert :cowboy.get_env(listener, :dispatch) == dispatch
    original_socket_opts = :ranch.get_transport_options(listener).socket_opts
    assert :proplists.get_value(:crl_check, original_socket_opts) == false
    :ok = :gen_tcp.close(occupied)

    remote = {@loopback, 40_000}
    assert {:ok, {session, _monitor} = adapter} = WebSocket.websocket_init({hub, remote})
    %{timer: {timer, token}} = :sys.get_state(session)
    Process.cancel_timer(timer)
    send(session, {:sc_timeout, token})
    assert_receive {:sc_send, {:close, 1000, ""}}
    assert {:ok, ^adapter} = WebSocket.websocket_handle(:close, adapter)
    eventually(fn -> match?([%{code: 30, remote: ^remote}], Hub.status(hub).failed) end)
    send(hub, {:sc_connection, self(), {:closed, :connect_timeout}})
    send(hub, {:DOWN, make_ref(), :process, self(), :normal})
    send(hub, :drain_timeout)
    assert [%{code: 30}] = Hub.status(hub).failed

    assert {:ok, {session, monitor} = adapter} = WebSocket.websocket_init({hub, remote})
    assert {:ok, ^adapter} = WebSocket.websocket_handle({:binary, <<6, 0, 0, 21>>}, adapter)
    assert_receive {:sc_send, {:binary, _nak}}

    eventually(fn -> match?([%{code: 149, remote: ^remote}], Hub.status(hub).failed) end)
    assert {:ok, ^adapter} = WebSocket.websocket_handle(:close, adapter)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}
    assert [%{code: 149}] = Hub.status(hub).failed

    assert {:ok, {session, monitor} = adapter} = WebSocket.websocket_init({hub, remote})
    assert :ok = Hub.reconfigure(hub, options, false)
    assert {:stop, nil} = WebSocket.websocket_init({hub, remote})
    peer = %{vmac: @peer, uuid: <<2::128>>, max_bvlc: 65_535, max_npdu: 1497}
    code = BVLC.error_code(:operational_problem)
    assert {:error, ^code} = GenServer.call(hub, {:register, session, peer})
    assert [%{code: ^code, peer: ^peer}] = Hub.status(hub).failed
    assert {:ok, ^adapter} = WebSocket.websocket_handle(:close, adapter)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}
    assert :ok = Hub.finish_reconfigure(hub, false)
    hub_monitor = Process.monitor(hub)
    assert :ok = Hub.close(hub)
    assert_receive {:DOWN, ^hub_monitor, :process, ^hub, :normal}
  end

  test "ignores stale connector events and frames addressed to another node", context do
    hub = start_supervised!({Hub, hub_opts(context, 0, @hub)})
    node = start_node(context, uri(Hub.port(hub)), nil, @peer, <<2::size(128)>>, self())
    eventually(fn -> Node.status(node).active == :primary end)
    session = :sys.get_state(node).attempts.primary.pid

    frame = %BVLC{
      function: :npdu,
      id: 4,
      source: @hub,
      destination: @managed,
      destination_options: [],
      data_options: [],
      payload: <<1, 0, 0x10, 8>>
    }

    send(node, {:sc_dial, :primary, make_ref()})
    send(node, {:sc_connection, self(), {:ready, %{}}})
    send(node, {:sc_connection, self(), {:frame, %{frame | destination: nil}}})
    send(node, {:sc_connection, session, {:frame, frame}})

    send(
      node,
      {:sc_connection, session, {:frame, %{frame | function: :heartbeat_ack, destination: nil}}}
    )

    send(node, {:DOWN, make_ref(), :process, self(), :normal})
    send(node, :ignored)
    assert Node.status(node).active == :primary
    refute_receive {:bacnet_transport, _, _, _, ^node}, 25

    broadcast = %{frame | destination: BVLC.broadcast(), destination_options: [{3, true, nil}]}
    send(node, {:sc_connection, session, {:frame, broadcast}})
    assert Node.status(node).active == :primary
    refute_receive {:bacnet_transport, _, _, _, ^node}, 25

    stop_test_fixtures()
  end

  test "stops the hub when the Ranch listener exits", context do
    hub =
      start_supervised!(
        Supervisor.child_spec({Hub, hub_opts(context, 0, @hub)}, restart: :temporary)
      )

    listener = :sys.get_state(hub).listener
    monitor = Process.monitor(hub)

    :cowboy.stop_listener(listener)
    assert_receive {:DOWN, ^monitor, :process, ^hub, {:hub_listener_closed, _reason}}
  end

  test "reports store failures and refuses to run with an unpersisted VMAC", context do
    hub = start_supervised!({Hub, hub_opts(context, 0, @hub)})
    primary = uri(Hub.port(hub))
    {cert, key} = certificate(context, "Standalone managed node")

    directory =
      Path.join(System.tmp_dir!(), "bacstack-sc-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(directory) end)

    opts = [
      storage_dir: directory,
      device_instance: 123,
      port_instance: 1,
      file_instances: @file_ids,
      vendor_id: 0,
      certificate_pem: cert,
      private_key_pem: key,
      issuer_pems: [context.ca_pem],
      transport: [failover_hub_uri: primary, vmac: @managed, min_reconnect_time: 2],
      authorize: fn _request, source -> source.vmac == @peer end
    ]

    managed = start_supervised!(Supervisor.child_spec({ManagedPort, opts}, restart: :temporary))
    %{transport: node, hub: nil} = ManagedPort.endpoints(managed)
    {requester, client} = start_requester(context, primary, @peer, <<2::size(128)>>)
    eventually(fn -> Node.status(node).active == :failover end)
    eventually(fn -> Node.status(requester).active == :primary end)
    port_id = %ObjectIdentifier{type: :network_port, instance: 1}
    assert read(client, @managed, port_id, :sc_hub_connector_state) == 2

    assert {:ok, %APDU.Error{code: :unknown_property}} =
             write(client, @managed, port_id, :sc_hub_function_enable, {:boolean, true})

    # Redirect writes to a missing parent to simulate an inaccessible store.
    %{path: path} = :sys.get_state(managed)
    :sys.replace_state(managed, &%{&1 | path: Path.join(directory, "missing/snapshot")})

    assert {:ok, %APDU.Error{code: :operational_problem}} =
             write(client, @managed, port_id, :network_number, {:unsigned_integer, 3})

    assert {:ok, %APDU.Error{code: :operational_problem}} =
             request(client, @managed, %ReinitializeDevice{
               reinitialized_state: :activate_changes,
               password: nil
             })

    monitor = Process.monitor(managed)
    send(managed, {:sc_vmac, node, <<0x12, 0, 0, 0, 0, 5>>})
    assert_receive {:DOWN, ^monitor, :process, ^managed, :vmac_persistence_failed}
    assert {:ok, %{transport: settings, pending: pending}} = Store.read(path)
    assert settings[:vmac] == @managed
    assert pending == %{}

    File.write!(path, "invalid snapshot")

    assert {:error, _reason} =
             start_supervised(Supervisor.child_spec({ManagedPort, opts}, id: :corrupt))

    stop_test_fixtures()
  end

  defp exercise_property_access(client, device_id, port_id, primary) do
    wildcard = %{device_id | instance: 4_194_303}
    absent = %{device_id | instance: 1000}
    assert read(client, @managed, wildcard, :object_identifier) == device_id
    assert is_integer(read(client, @managed, device_id, :object_type))

    for {property, index, code} <- [
          {:property_list, 500, :invalid_array_index},
          {:sc_hub_function_accept_uris, 500, :invalid_array_index},
          {:sc_primary_hub_uri, 1, :property_is_not_an_array},
          {9000, nil, :unknown_property},
          {:present_value, nil, :unknown_property}
        ] do
      assert {:ok, %APDU.Error{code: ^code}} =
               request(client, @managed, %ReadProperty{
                 object_identifier: port_id,
                 property_identifier: property,
                 property_array_index: index
               })
    end

    for {property, index, expected} <- [
          {:sc_hub_function_accept_uris, 0, 1},
          {:sc_hub_function_accept_uris, 1, primary}
        ] do
      assert {:ok, response} =
               request(client, @managed, %ReadProperty{
                 object_identifier: port_id,
                 property_identifier: property,
                 property_array_index: index
               })

      assert {:ok, %{property_value: %{value: ^expected}}} = ReadPropertyAck.from_apdu(response)
    end

    property_list = %Property{
      property_identifier: :property_list,
      property_array_index: nil,
      property_value: nil,
      priority: nil
    }

    assert {:ok, response} =
             request(client, @managed, %ReadPropertyMultiple{
               list: [
                 %AccessSpecification{
                   object_identifier: wildcard,
                   properties: [
                     :required,
                     property_list,
                     %{property_list | property_array_index: 0},
                     %{property_list | property_array_index: 1}
                   ]
                 },
                 %AccessSpecification{
                   object_identifier: absent,
                   properties: [:all, property_list]
                 }
               ]
             })

    assert {:ok, %{results: [known, unknown]}} = ReadPropertyMultipleAck.from_apdu(response)
    assert known.object_identifier == device_id
    assert Enum.any?(known.results, &(&1.property_identifier == :property_list))
    assert unknown.object_identifier == absent

    assert [
             %{
               property_identifier: :property_list,
               error: %{class: :object, code: :unknown_object}
             }
           ] = unknown.results

    missing = %AccessSpecification{object_identifier: absent, properties: [:all]}
    readable = %AccessSpecification{object_identifier: wildcard, properties: [:required]}

    assert {:ok, %APDU.Error{class: :object, code: :unknown_object}} =
             request(client, @managed, %ReadPropertyMultiple{list: [missing]})

    assert {:ok, response} =
             request(client, @managed, %ReadPropertyMultiple{list: [missing, readable]})

    assert {:ok, %{results: [%{object_identifier: ^device_id}]}} =
             ReadPropertyMultipleAck.from_apdu(response)

    for {property, value, code} <- [
          {:sc_primary_hub_uri, {:character_string, "ws://localhost/"}, :value_out_of_range},
          {:sc_heartbeat_timeout, {:character_string, "thirty"}, :invalid_parameter_data_type},
          {:mac_address, {:octet_string, @managed}, :write_access_denied},
          {:command, {:enumerated, 0}, :optional_functionality_not_supported},
          {:command, {:character_string, "validate"}, :invalid_parameter_data_type}
        ] do
      assert {:ok, %APDU.Error{code: ^code}} = write(client, @managed, port_id, property, value)
    end

    for {property, value, index, result} <- [
          {:sc_hub_function_accept_uris, {:character_string, "wss://localhost:443/sc"}, 1, :ok},
          {:sc_hub_function_accept_uris, {:character_string, "ws://localhost/"}, 1,
           :value_out_of_range},
          {:sc_hub_function_accept_uris, {:character_string, primary}, 500, :invalid_array_index},
          {:sc_primary_hub_uri, {:character_string, primary}, 1, :property_is_not_an_array}
        ] do
      assert {:ok, reply} =
               request(client, @managed, %WriteProperty{
                 object_identifier: port_id,
                 property_identifier: property,
                 property_array_index: index,
                 property_value: Encoding.create!(value),
                 priority: nil
               })

      case result do
        :ok -> assert %APDU.SimpleACK{} = reply
        code -> assert %APDU.Error{code: ^code} = reply
      end
    end

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :command, {:enumerated, 9})

    assert {:ok, %APDU.Error{code: :invalid_value_in_this_state}} =
             write(client, @managed, port_id, :command, {:enumerated, 8})

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :command, {:enumerated, 1})

    assert {:ok, %APDU.Error{code: :optional_functionality_not_supported}} =
             request(client, @managed, %ReinitializeDevice{
               reinitialized_state: :coldstart,
               password: nil
             })
  end

  test "exposes the normal transport supervisor entry point" do
    opts = [primary_hub_uri: "wss://localhost:4443/"]

    assert %{id: :sc, start: {Node, :open, [receiver, ^opts]}} =
             TransportBehaviour.child_spec(Node, self(), opts, id: :sc)

    assert receiver == self()
  end

  defp exercise_file_validation(client, port_id) do
    issuer = %ObjectIdentifier{type: :file, instance: @file_ids.issuer_1}
    csr = %ObjectIdentifier{type: :file, instance: @file_ids.csr}
    assert read(client, @managed, issuer, :object_name) == "SC Issuer Certificate 1"

    assert {:ok, %APDU.Error{code: :value_out_of_range}} =
             write(client, @managed, issuer, :file_size, {:unsigned_integer, 1})

    assert {:ok, %APDU.Error{code: :write_access_denied}} =
             write(client, @managed, csr, :file_size, {:unsigned_integer, 0})

    upload = %AtomicWriteFile{
      object_identifier: issuer,
      stream_access: true,
      start_position: 0,
      data: "bad"
    }

    assert {:ok, %APDU.ComplexACK{}} = request(client, @managed, upload)

    assert {:ok, %APDU.Error{code: :no_space_to_write_property}} =
             request(client, @managed, %{upload | start_position: 65_536})

    assert {:ok, %APDU.Error{code: :unknown_object}} =
             request(client, @managed, %{upload | object_identifier: %{issuer | instance: 999}})

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :command, {:enumerated, 9})

    assert {:ok, %APDU.Error{}} =
             request(client, @managed, %ReinitializeDevice{
               reinitialized_state: :activate_changes,
               password: nil
             })

    assert {:ok, %APDU.SimpleACK{}} =
             write(client, @managed, port_id, :command, {:enumerated, 1})
  end

  defp stop_test_fixtures() do
    # ExUnit stops its supervisor after capture_log ends. SC connections can
    # also outlive their owners while closing, so wait for them here.
    {:ok, supervisor} = ExUnit.fetch_test_supervisor()

    monitors =
      supervisor
      |> Supervisor.which_children()
      |> Enum.flat_map(fn
        {_id, pid, :worker, [module]} when is_pid(pid) -> fixture_connections(module, pid)
        _child -> []
      end)
      |> Enum.uniq()
      |> Enum.map(&Process.monitor/1)

    :ok = Supervisor.stop(supervisor)

    for monitor <- monitors do
      assert_receive {:DOWN, ^monitor, :process, _pid, _reason}
    end
  end

  defp fixture_connections(Hub, hub) do
    Map.keys(:sys.get_state(hub).sessions)
  end

  defp fixture_connections(Node, node) do
    %{attempts: attempts, retiring: retiring} = :sys.get_state(node)
    Enum.map(attempts, fn {_role, session} -> session.pid end) ++ Map.keys(retiring)
  end

  defp fixture_connections(ManagedPort, managed) do
    %{hub: hub, transport: node} = ManagedPort.endpoints(managed)
    hub_connections = if hub, do: fixture_connections(Hub, hub), else: []
    fixture_connections(Node, node) ++ hub_connections
  end

  defp fixture_connections(_module, _pid), do: []

  defp capture_sc_debug(fun) do
    modules = [Connection, Hub, Node]
    levels = Logger.get_module_level(modules)
    Logger.put_module_level(modules, :debug)

    try do
      ExUnit.CaptureLog.capture_log([level: :debug], fun)
    after
      Logger.delete_module_level(modules)
      Enum.each(levels, fn {module, level} -> Logger.put_module_level(module, level) end)
    end
  end

  defp host_objects(primary, hub_properties \\ []) do
    port_id = %ObjectIdentifier{type: :network_port, instance: 7}
    device_id = %ObjectIdentifier{type: :device, instance: 123}
    application_object = %ObjectIdentifier{type: :analog_value, instance: 2}

    file_ids =
      Map.new(@file_ids, fn {role, instance} ->
        {role, %ObjectIdentifier{type: :file, instance: instance}}
      end)

    object_list =
      BACnetArray.from_list([device_id, port_id, application_object | Map.values(file_ids)])

    {:ok, device} =
      Device.create(
        123,
        "Central BACnet host",
        %{
          vendor_identifier: 42,
          protocol_revision: 24,
          device_uuid: <<3::size(128)>>,
          segmentation_supported: :segmented_both,
          max_segments_accepted: 64,
          apdu_segment_timeout: 3000,
          object_list: object_list
        },
        revision: 24,
        supports_secure_connect: true
      )

    properties =
      Map.merge(
        %{
          network_type: :sc,
          protocol_level: :bacnet_application,
          mac_address: @managed,
          sc_primary_hub_uri: primary,
          sc_minimum_reconnect_time: 2,
          max_bvlc_length_accepted: BVLC.max_bvlc(),
          max_npdu_length_accepted: BVLC.max_npdu(),
          operational_certificate_file: file_ids.operational,
          issuer_certificate_files:
            BACnetArray.from_list([file_ids.issuer_1, file_ids.issuer_2], true),
          certificate_signing_request_file: file_ids.csr
        },
        Map.new(hub_properties)
      )

    {:ok, port} =
      NetworkPort.create(7, "Host SC Port", properties,
        revision: 24,
        supports_command_execution: true,
        supports_sc_hub: hub_properties != []
      )

    files =
      Map.new(@file_ids, fn {role, instance} ->
        {:ok, file} =
          FileObject.create(instance, "Host #{role}", %{read_only: role == :csr, archive: true},
            revision: 24
          )

        {role, file}
      end)

    %{device: device, port: port, files: files}
  end

  defp host_write(id, property, value) do
    %WriteProperty{
      object_identifier: id,
      property_identifier: property,
      property_array_index: nil,
      property_value: Encoding.create!(value),
      priority: nil
    }
  end

  defp hosted_exchange(managed, requester, objects, %service{} = request) do
    %{client: client} = ManagedPort.endpoints(managed)
    task = Task.async(fn -> request(requester, @managed, request) end)

    assert_receive {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{} = apdu,
                    {@peer, _bvlc, _npci}, ^client} = notification,
                   1000

    result = ManagedPort.handle_request(managed, notification, objects)

    if result in [:unhandled, {:error, :refresh_required}] do
      response =
        case {result, service} do
          {{:error, :refresh_required}, _service} ->
            %APDU.Error{
              invoke_id: apdu.invoke_id,
              service: apdu.service,
              class: :services,
              code: :operational_problem,
              payload: []
            }

          {:unhandled, DeviceCommunicationControl} ->
            %APDU.SimpleACK{invoke_id: apdu.invoke_id, service: apdu.service}

          _other ->
            %APDU.Error{
              invoke_id: apdu.invoke_id,
              service: apdu.service,
              class: :object,
              code: :unknown_object,
              payload: []
            }
        end

      assert :ok = Client.reply(client, ref, response)
    end

    {Task.await(task), result}
  end

  defp start_node(context, primary, failover, vmac, uuid, receiver) do
    opts = [
      primary_hub_uri: primary,
      failover_hub_uri: failover,
      vmac: vmac,
      device_uuid: uuid,
      credentials: credentials(context, "Node"),
      min_reconnect_time: 2,
      max_reconnect_time: 4
    ]

    start_supervised!(
      Supervisor.child_spec({Node, {receiver, opts}},
        id: make_ref(),
        restart: :temporary
      )
    )
  end

  defp audit_peers(context, mode, overrides \\ []) do
    owner = self()

    sink = fn event ->
      send(owner, {:audit, event})
      :ok
    end

    audit = Keyword.merge([mode: mode, sink: sink], overrides)
    opts = Keyword.put(hub_opts(context, 0, @hub), :audit, audit)
    hub = start_supervised!({Hub, opts})
    primary = uri(Hub.port(hub))
    writer = start_node(context, primary, nil, @peer, <<2::128>>, owner)
    target = start_node(context, primary, nil, @managed, <<3::128>>, owner)
    eventually(fn -> Node.status(writer).active == :primary end)
    eventually(fn -> Node.status(target).active == :primary end)
    {hub, writer, target}
  end

  defp audit_write(invoke, value) do
    {:ok, request} =
      WriteProperty.to_apdu(
        %WriteProperty{
          object_identifier: @audit_object,
          property_identifier: :present_value,
          property_array_index: nil,
          property_value: Encoding.create!({:real, value}),
          priority: 8
        },
        invoke_id: invoke
      )

    request
  end

  defp start_requester(context, primary, vmac, uuid) do
    {:ok, relay} = Agent.start_link(fn -> nil end)

    callback = fn source, frame, portal ->
      if client = Agent.get(relay, & &1) do
        send(client, {:bacnet_transport, {:bacnet_sc, Node}, source, frame, portal})
      end
    end

    node = start_node(context, primary, nil, vmac, uuid, callback)
    client = start_client(node, self())
    Agent.update(relay, fn _old -> client end)
    {node, client}
  end

  defp start_client(node, receiver) do
    store = start_supervised!(Supervisor.child_spec({SegmentsStore, []}, id: make_ref()))
    segmentator = start_supervised!(Supervisor.child_spec({Segmentator, []}, id: make_ref()))

    start_supervised!(
      Supervisor.child_spec(
        {Client,
         [
           transport: {Node, node},
           notification_receiver: receiver,
           segmentator: segmentator,
           segments_store: store,
           apdu_timeout: 800,
           apdu_retries: 2
         ]},
        id: make_ref()
      )
    )
  end

  defp hub_opts(context, port, vmac),
    do: [
      ip: @loopback,
      port: port,
      vmac: vmac,
      device_uuid: <<1::size(128)>>,
      credentials: credentials(context, "Hub")
    ]

  defp uri(port), do: "wss://127.0.0.1:#{port}/"

  defp credentials(context, name) do
    {cert, key} = certificate(context, name)
    {:ok, credentials} = Credentials.from_pem(cert, key, [context.ca_pem])
    credentials
  end

  defp certificate(context, name) do
    key = X509.PrivateKey.new_ec(:secp256r1)

    certificate =
      X509.Certificate.new(
        X509.PublicKey.derive(key),
        "/CN=#{name}",
        context.ca,
        context.ca_key,
        template: :server
      )

    {X509.Certificate.to_pem(certificate), X509.PrivateKey.to_pem(key)}
  end

  defp request(client, vmac, %module{} = service) do
    {:ok, apdu} = module.to_apdu(service, max_apdu: 1476)
    Client.send(client, vmac, apdu)
  end

  defp read(client, vmac, id, property) do
    assert {:ok, apdu} =
             request(client, vmac, %ReadProperty{
               object_identifier: id,
               property_identifier: property,
               property_array_index: nil
             })

    assert {:ok, %{property_value: value}} = ReadPropertyAck.from_apdu(apdu)
    value.value
  end

  defp write(client, vmac, id, property, value) do
    request(client, vmac, %WriteProperty{
      object_identifier: id,
      property_identifier: property,
      property_array_index: nil,
      property_value: Encoding.create!(value),
      priority: nil
    })
  end

  defp eventually(fun, attempts \\ 160)
  defp eventually(fun, 0), do: assert(fun.())

  defp eventually(fun, attempts) do
    unless fun.() do
      Process.sleep(50)
      eventually(fun, attempts - 1)
    end
  end
end
