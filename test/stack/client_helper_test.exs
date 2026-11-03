defmodule BACnet.Stack.ClientHelperTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services
  alias BACnet.Protocol.Services.Ack.ReadPropertyAck
  alias BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck
  alias BACnet.Protocol.Services.Error.WritePropertyMultipleError
  alias BACnet.Stack.Client
  alias BACnet.Stack.ClientHelper
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport

  require Constants

  use BACnet.Test.Stack.Case, async: true

  @moduletag :stack
  @moduletag :client_helper

  @dest :peer

  setup do
    {:ok, transport} = FakeTransport.start_link()
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 1)
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 1)

    {:ok, client} =
      Client.start_link(
        transport: {FakeTransport, transport},
        segmentator: segmentator,
        segments_store: store,
        notification_receiver: self(),
        apdu_timeout: 60_000,
        apdu_retries: 1
      )

    Process.put(:client_helper_client, client)
    %{client: client, transport: transport}
  end

  test "i_am rejects bad options and sends the vendor id", %{client: client} do
    device = obj(:device, 7)

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.i_am(client, @dest, device, 1, [1])
    end

    assert :ok = ClientHelper.i_am(client, @dest, device, 42)
    assert %Services.IAm{device: ^device, vendor_id: 42, max_apdu: 480} = sent_unconfirmed(@dest)

    assert :ok = ClientHelper.i_am(client, :broadcast, device, 7)
    assert_receive {:fake_transport_send, :broadcast, _raw, _opts}
  end

  test "read_property returns a raw value, an array size, and a cast value", %{
    client: client,
    transport: transport
  } do
    analog = obj(:analog_input, 5)

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.read_property(client, @dest, analog, :present_value, nil, [1])
    end

    task =
      Task.async(fn ->
        ClientHelper.read_property(client, @dest, analog, :present_value, nil, raw: true)
      end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, analog, :present_value, real(72.3))
    end)

    assert {:ok, %Encoding{type: :real, value: 72.3}} = Task.await(task)

    wildcard = obj(:device, 4_194_303)

    task =
      Task.async(fn ->
        ClientHelper.read_property(client, @dest, wildcard, :object_name, 0, raw: true)
      end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, obj(:device, 15), :object_name, real(3.0), 0)
    end)

    assert {:ok, %Encoding{value: 3.0}} = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.read_property(client, @dest, analog, :object_list, 0)
      end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, analog, :object_list, unsigned(4), 0)
    end)

    assert {:ok, 4} = Task.await(task)

    task = Task.async(fn -> ClientHelper.read_property(client, @dest, analog, :present_value) end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, analog, :present_value, real(72.3))
    end)

    assert {:ok, 72.3} = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.read_property(client, @dest, analog, :present_value, nil,
          allow_numeric_constants: true,
          allow_unknown_properties: true
        )
      end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, analog, :present_value, real(72.3))
    end)

    assert {:ok, 72.3} = Task.await(task)

    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    assert {:error, :down} = ClientHelper.read_property(client, @dest, analog, :present_value)
    assert :ok = FakeTransport.set_send_result(transport, :ok)
    flush_sends()

    task = Task.async(fn -> ClientHelper.read_property(client, @dest, analog, :present_value) end)

    reply_confirmed(@dest, fn invoke_id ->
      %APDU.SimpleACK{invoke_id: invoke_id, service: :read_property}
    end)

    assert {:error, %APDU.SimpleACK{}} = Task.await(task)

    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    assert {:error, :down} = ClientHelper.read_object(client, @dest, analog)

    assert {:error, :down} =
             ClientHelper.read_property_multiple(client, @dest, analog, [:present_value])

    assert {:error, :down} =
             ClientHelper.subscribe_cov_property(client, @dest, analog, :present_value)

    assert {:error, :down} = ClientHelper.reinitialize_device(client, @dest, :coldstart)

    assert {:error, :down} =
             ClientHelper.write_property(client, @dest, analog, :present_value, real(1.0))

    assert :ok = FakeTransport.set_send_result(transport, :ok)
    flush_sends()
  end

  test "read_object selects properties and returns an error apdu", %{client: client} do
    analog = obj(:analog_input, 5)

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.read_object(client, @dest, analog, [1])
    end

    assert_raise ArgumentError, ~r/read_level/, fn ->
      ClientHelper.read_object(client, @dest, analog, read_level: :some)
    end

    assert_raise ArgumentError, ~r/properties/, fn ->
      ClientHelper.read_object(client, @dest, analog, properties: :present_value)
    end

    assert_raise ArgumentError, ~r/Invalid property identifier/, fn ->
      ClientHelper.read_object(client, @dest, analog, properties: ["nope"])
    end

    task =
      Task.async(fn ->
        ClientHelper.read_object(client, @dest, analog, properties: [:present_value])
      end)

    assert_receive {:fake_transport_send, @dest, raw, _opts}

    {:ok, %APDU.ConfirmedServiceRequest{invoke_id: invoke_id, service: :read_property_multiple}} =
      APDU.decode(raw)

    deliver(
      @dest,
      %APDU.ComplexACK{
        invoke_id: invoke_id,
        sequence_number: nil,
        proposed_window_size: nil,
        service: :read_property,
        payload: []
      }
    )

    assert {:error, :invalid_service_ack} = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.read_object(client, @dest, analog, properties: [:all], read_level: :required)
      end)

    assert_receive {:fake_transport_send, @dest, raw, _opts}
    {:ok, request} = APDU.decode(raw)
    assert request.service == :read_property_multiple
    deliver(@dest, ApduFactory.simple_ack(request.invoke_id))
    assert {:error, %APDU.SimpleACK{}} = Task.await(task)

    wildcard = obj(:device, 4_194_303)

    task =
      Task.async(fn ->
        ClientHelper.read_object(client, @dest, wildcard, properties: [:object_name])
      end)

    reply_confirmed(@dest, fn invoke_id ->
      {:ok, ack} =
        ReadPropertyMultipleAck.to_apdu(
          %ReadPropertyMultipleAck{
            results: [
              %BACnet.Protocol.ReadAccessResult{
                object_identifier: obj(:device, 15),
                results: [result(:object_name, real(1.0))]
              }
            ]
          },
          invoke_id
        )

      ack
    end)

    assert {:error, _reason} = Task.await(task)

    analog_value = obj(:analog_value, 4)

    task =
      Task.async(fn ->
        ClientHelper.read_object(client, @dest, analog_value,
          properties: [:present_value],
          ignore_unknown_properties: true
        )
      end)

    reply_confirmed(@dest, &analog_ack(&1, analog_value))

    assert {:ok, %BACnet.Protocol.ObjectTypes.AnalogValue{present_value: 1.0, object_name: "AV1"}} =
             Task.await(task)
  end

  test "read_property_multiple returns raw results and the device named in the ack", %{
    client: client
  } do
    analog = obj(:analog_input, 16)

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.read_property_multiple(client, @dest, analog, [:present_value], [1])
    end

    task =
      Task.async(fn ->
        ClientHelper.read_property_multiple(client, @dest, analog, [:present_value, :reliability],
          raw: true
        )
      end)

    reply_confirmed(@dest, fn invoke_id ->
      {:ok, ack} =
        ReadPropertyMultipleAck.to_apdu(
          %ReadPropertyMultipleAck{
            results: [
              %BACnet.Protocol.ReadAccessResult{
                object_identifier: analog,
                results: [
                  result(:present_value, real(72.3)),
                  result(:reliability, %Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :enumerated,
                    value: 0
                  })
                ]
              }
            ]
          },
          invoke_id
        )

      ack
    end)

    assert {:ok, [%BACnet.Protocol.ReadAccessResult{object_identifier: ^analog}]} =
             Task.await(task)

    wildcard = obj(:device, 4_194_303)

    task =
      Task.async(fn ->
        ClientHelper.read_property_multiple(client, @dest, wildcard, [:object_name], raw: true)
      end)

    named = obj(:device, 15)

    reply_confirmed(@dest, fn invoke_id ->
      {:ok, ack} =
        ReadPropertyMultipleAck.to_apdu(
          %ReadPropertyMultipleAck{
            results: [
              %BACnet.Protocol.ReadAccessResult{
                object_identifier: named,
                results: [result(:object_name, real(1.0))]
              }
            ]
          },
          invoke_id
        )

      ack
    end)

    assert {:ok, [%BACnet.Protocol.ReadAccessResult{object_identifier: ^named}]} =
             Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.read_property_multiple(client, @dest, analog, [:present_value])
      end)

    reply_confirmed(@dest, fn invoke_id ->
      {:ok, ack} =
        ReadPropertyMultipleAck.to_apdu(
          %ReadPropertyMultipleAck{
            results: [
              %BACnet.Protocol.ReadAccessResult{
                object_identifier: analog,
                results: [result(:present_value, real(72.3))]
              }
            ]
          },
          invoke_id
        )

      ack
    end)

    assert {:ok, %{present_value: 72.3}} = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.read_property_multiple(client, @dest, analog, [:present_value])
      end)

    reply_confirmed(@dest, &ApduFactory.simple_ack/1)
    assert {:error, %APDU.SimpleACK{}} = Task.await(task)
  end

  test "reinitialize_device accepts a simple ack", %{client: client} do
    task = Task.async(fn -> ClientHelper.reinitialize_device(client, @dest) end)
    reply_confirmed(@dest, &ApduFactory.simple_ack/1)
    assert :ok = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.reinitialize_device(client, @dest, :coldstart, "secret")
      end)

    reply_confirmed(@dest, fn invoke_id ->
      %APDU.Error{
        invoke_id: invoke_id,
        service: :reinitialize_device,
        class: :device,
        code: :password_failure,
        payload: []
      }
    end)

    assert {:error, %APDU.Error{code: :password_failure}} = Task.await(task)
  end

  test "time synchronization uses utc or local time and the broadcast address", %{client: client} do
    dt = ~U[2024-05-06 07:08:09Z]
    assert :ok = ClientHelper.send_time_synchronization(client, @dest, utc: true)
    assert_receive {:fake_transport_send, @dest, raw, opts}
    refute Keyword.has_key?(opts, :utc)
    {:ok, apdu} = APDU.decode(raw)
    assert apdu.service == :utc_time_synchronization

    assert :ok = ClientHelper.send_time_synchronization(client)
    assert_receive {:fake_transport_send, :broadcast, raw, _opts}
    {:ok, apdu} = APDU.decode(raw)
    assert apdu.service == :utc_time_synchronization

    assert :ok = ClientHelper.send_time_synchronization(client, :broadcast, datetime: dt)
    assert_receive {:fake_transport_send, :broadcast, raw, _opts}
    {:ok, apdu} = APDU.decode(raw)
    assert apdu.service == :time_synchronization

    local = DateTime.new!(~D[2024-05-06], ~T[07:08:09], "Etc/UTC")

    assert :ok =
             ClientHelper.send_time_synchronization(client, @dest, datetime: local, utc: true)

    assert_receive {:fake_transport_send, @dest, raw, opts}
    refute Keyword.has_key?(opts, :datetime)
    refute Keyword.has_key?(opts, :utc)
    {:ok, apdu} = APDU.decode(raw)

    assert {:ok,
            %Services.UtcTimeSynchronization{
              date: date,
              time: time
            }} = Services.UtcTimeSynchronization.from_apdu(apdu)

    assert date == BACnet.Protocol.BACnetDate.from_date(~D[2024-05-06])
    assert time == BACnet.Protocol.BACnetTime.from_time(~T[07:08:09])
  end

  test "subscribe_cov_property sends the lifetime and confirmed flag", %{client: client} do
    analog = obj(:analog_input, 5)

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.subscribe_cov_property(client, @dest, analog, :present_value, [1])
    end

    task =
      Task.async(fn ->
        ClientHelper.subscribe_cov_property(client, @dest, analog, :present_value,
          confirmed: true,
          cov_increment: 1.5,
          lifetime: 60,
          pid: 9,
          array_index: 2
        )
      end)

    assert_receive {:fake_transport_send, @dest, raw, _opts}

    {:ok, %APDU.ConfirmedServiceRequest{invoke_id: invoke_id, service: :subscribe_cov_property}} =
      APDU.decode(raw)

    deliver(@dest, ApduFactory.simple_ack(invoke_id, :subscribe_cov_property))
    assert :ok = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.subscribe_cov_property(client, @dest, analog, :present_value, lifetime: nil)
      end)

    reply_confirmed(@dest, fn invoke_id ->
      %APDU.Abort{invoke_id: invoke_id, sent_by_server: true, reason: :other}
    end)

    assert {:error, %APDU.Abort{}} = Task.await(task)
  end

  test "who_is collects one i_am and stops at the limit", %{client: client} do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.who_is(client, 20, [1])
    end

    task =
      Task.async(fn ->
        ClientHelper.who_is(client, 1_000, max: 1, low_limit: 1, high_limit: 20)
      end)

    assert_receive {:fake_transport_send, :broadcast, raw, _opts}
    {:ok, %APDU.UnconfirmedServiceRequest{service: :who_is}} = APDU.decode(raw)
    send_iam(client, :remote, obj(:device, 11), 42)

    assert {:ok,
            [{:remote, %Services.IAm{device: %ObjectIdentifier{instance: 11}, vendor_id: 42}}]} =
             Task.await(task)

    flush_client()

    # The subscribed path also starts a task and calls the client to subscribe,
    # send and unsubscribe. A 10 ms window leaves only 5 ms for that work.
    assert {:ok, []} = ClientHelper.who_is(client, 1_000)

    assert {:ok, []} =
             ClientHelper.who_is(client, 10, no_subscribe: true, apdu_destination: :direct)

    assert_receive {:fake_transport_send, :direct, _raw, _opts}
  end

  test "who_is skips an i_am that cannot be decoded", %{client: client} do
    task = Task.async(fn -> ClientHelper.who_is(client, 80, no_subscribe: true) end)
    assert_receive {:fake_transport_send, :broadcast, _raw, _opts}

    send(
      task.pid,
      {:bacnet_client, nil, %APDU.UnconfirmedServiceRequest{service: :i_am, parameters: []},
       {:remote, nil, nil}, client}
    )

    send(
      client,
      {:bacnet_transport, {:bacnet_ipv4, FakeTransport}, :remote,
       {:apdu, :original_broadcast, NPCI.new([]),
        IO.iodata_to_binary(
          EncoderProtocol.encode(%APDU.UnconfirmedServiceRequest{service: :i_am, parameters: []})
        )}, self()}
    )

    assert {:ok, []} = Task.await(task, 500)
  end

  test "write_property encodes a value and an encoding", %{client: client} do
    analog = obj(:analog_input, 5)

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.write_property(client, @dest, analog, :present_value, 1.0, [1])
    end

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.write_property(client, @dest, analog, :present_value, real(1.0), [1])
    end

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.write_property(client, @dest, analog, :present_value, [real(1.0)], [1])
    end

    task =
      Task.async(fn ->
        ClientHelper.write_property(client, @dest, analog, :present_value, real(1.5),
          array_index: 1,
          priority: 8
        )
      end)

    reply_confirmed(@dest, &ApduFactory.simple_ack/1)
    assert :ok = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.write_property(client, @dest, analog, :present_value, [real(2.0)],
          priority: 8
        )
      end)

    reply_confirmed(@dest, fn invoke_id ->
      %APDU.Error{
        invoke_id: invoke_id,
        service: :write_property,
        class: :property,
        code: :write_access_denied,
        payload: []
      }
    end)

    assert {:error, %APDU.Error{code: :write_access_denied}} = Task.await(task)

    assert {:error, {:invalid_property_value, {:present_value, [1.25]}}} =
             ClientHelper.write_property(client, @dest, analog, :present_value, [1.25],
               priority: 8
             )

    task =
      Task.async(fn ->
        ClientHelper.write_property(client, @dest, analog, :present_value, 1.25, priority: 8)
      end)

    reply_confirmed(@dest, &ApduFactory.simple_ack/1)
    assert :ok = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.write_property(client, @dest, analog, :present_value, 1.25)
      end)

    reply_confirmed(@dest, &ApduFactory.simple_ack/1)
    assert :ok = Task.await(task)

    assert {:error, {:invalid_property_value, {:present_value, [1.25]}}} =
             ClientHelper.write_property(client, @dest, analog, :present_value, [1.25])
  end

  test "write_property_multiple accepts encodings and reports the first failure", %{
    client: client,
    transport: transport
  } do
    analog = obj(:analog_input, 5)

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ClientHelper.write_property_multiple(client, @dest, analog, %{present_value: 1.0}, [1])
    end

    assert {:error, {:invalid_property, :not_a_property}} =
             ClientHelper.write_property_multiple(client, @dest, analog, %{
               not_a_property: real(1.0)
             })

    assert {:error, {:invalid_tuple_or_index, :present_value}} =
             ClientHelper.write_property_multiple(client, @dest, analog, [:present_value])

    assert {:error, {:invalid_property, 80}} =
             ClientHelper.write_property_multiple(client, @dest, analog, [{80, 1.0}])

    task =
      Task.async(fn ->
        ClientHelper.write_property_multiple(client, @dest, analog, [
          {:present_value, nil, real(1.0)}
        ])
      end)

    reply_confirmed(@dest, fn invoke_id ->
      {:ok, error} =
        WritePropertyMultipleError.to_apdu(
          %WritePropertyMultipleError{
            error_class: :property,
            error_code: :write_access_denied,
            first_failed_write_attempt: %BACnet.Protocol.ObjectPropertyRef{
              object_identifier: analog,
              property_identifier: :present_value,
              property_array_index: nil
            }
          },
          invoke_id
        )

      error
    end)

    assert {:error, %WritePropertyMultipleError{error_code: :write_access_denied}} =
             Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.write_property_multiple(client, @dest, analog, %{
          present_value: {0, real(4.0)}
        })
      end)

    reply_confirmed(@dest, &ApduFactory.simple_ack/1)
    assert :ok = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.write_property_multiple(client, @dest, analog, %{present_value: 1.25})
      end)

    reply_confirmed(@dest, &ApduFactory.simple_ack/1)
    assert :ok = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.write_property_multiple(client, @dest, analog, %{
          present_value: [real(1.0), real(2.0)]
        })
      end)

    assert_receive {:fake_transport_send, @dest, raw, _opts}
    {:ok, %APDU.ConfirmedServiceRequest{invoke_id: invoke_id} = request} = APDU.decode(raw)

    assert {:ok, %Services.WritePropertyMultiple{list: [specification]}} =
             Services.WritePropertyMultiple.from_apdu(request)

    assert [
             %BACnet.Protocol.AccessSpecification.Property{
               property_identifier: :present_value,
               property_value: property_value
             }
           ] = specification.properties

    assert property_value == [real(1.0), real(2.0)]

    deliver(@dest, ApduFactory.simple_ack(invoke_id))
    assert :ok = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.write_property_multiple(client, @dest, analog, [
          %BACnet.Protocol.AccessSpecification.Property{
            property_identifier: :present_value,
            property_array_index: nil,
            property_value: real(4.0)
          }
        ])
      end)

    reply_confirmed(@dest, fn invoke_id ->
      %APDU.Abort{invoke_id: invoke_id, sent_by_server: true, reason: :other}
    end)

    assert {:error, %APDU.Abort{}} = Task.await(task)

    task =
      Task.async(fn ->
        ClientHelper.write_property_multiple(client, @dest, analog, %{present_value: real(4.0)})
      end)

    reply_confirmed(@dest, fn invoke_id ->
      %APDU.Error{
        invoke_id: invoke_id,
        service: :write_property_multiple,
        class: :property,
        code: :write_access_denied,
        payload: []
      }
    end)

    assert {:error, %APDU.Error{code: :write_access_denied}} = Task.await(task)

    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})

    assert {:error, :down} =
             ClientHelper.read_property_multiple(client, @dest, analog, [
               %BACnet.Protocol.AccessSpecification.Property{
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: nil
               }
             ])

    assert :ok = FakeTransport.set_send_result(transport, :ok)
    flush_sends()
  end

  test "scan_device stops on an object list entry that is not an identifier", %{client: client} do
    device = obj(:device, 3)

    task = Task.async(fn -> ClientHelper.scan_device(client, @dest, device) end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, device, :object_list, [real(1.0), real(2.0)])
    end)

    assert {:error, {:invalid_object_identifier, bad}} = Task.await(task)
    assert bad in [1.0, 2.0]

    {:ok, sup} = Task.Supervisor.start_link()

    task =
      Task.Supervisor.async_nolink(sup, fn ->
        ClientHelper.scan_device(client, @dest, device, exit_on_error: true)
      end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, device, :object_list, [real(1.0), real(2.0)])
    end)

    # The two entries are separate chunks when more than one scheduler is online,
    # and the stream is unordered, so either invalid value can be reported first
    assert {:exit, {:error, {:invalid_object_identifier, bad}}} =
             Task.yield(task, 1_000) || Task.shutdown(task)

    assert bad in [1.0, 2.0]
  end

  test "scan_device returns the objects it can read", %{client: client, transport: transport} do
    device = obj(:device, 3)
    first = obj(:analog_value, 4)
    second = obj(:analog_value, 5)

    assert :ok =
             FakeTransport.set_send_result(transport, fn @dest, raw, _opts ->
               {:ok, %APDU.ConfirmedServiceRequest{invoke_id: invoke_id} = request} =
                 APDU.decode(raw)

               response =
                 case request.service do
                   :read_property ->
                     assert {:ok,
                             %Services.ReadProperty{
                               object_identifier: ^device,
                               property_identifier: :object_list
                             }} = Services.ReadProperty.from_apdu(request)

                     read_ack(invoke_id, device, :object_list, [
                       identifier(first),
                       identifier(second)
                     ])

                   :read_property_multiple ->
                     assert [object_tag, {:constructed, {1, _properties, _length}}] =
                              request.parameters

                     assert {:ok, {:object_identifier, object}} =
                              ApplicationTags.unfold_to_type(:object_identifier, object_tag)

                     assert object in [first, second]
                     analog_ack(invoke_id, object)
                 end

               # Queue the reply while the client is completing this transport send.
               deliver(client, @dest, response)
               :ok
             end)

    assert {:ok, %{analog_value: objects}} =
             ClientHelper.scan_device(client, @dest, device,
               task_max_concurrency: 1,
               ignore_unknown_properties: true
             )

    assert %BACnet.Protocol.ObjectTypes.AnalogValue{object_name: "AV1"} = objects[4]
    assert %BACnet.Protocol.ObjectTypes.AnalogValue{object_name: "AV1"} = objects[5]

    for _request <- 1..3 do
      assert_received {:fake_transport_send, @dest, _raw, _opts}
    end

    refute_received {:fake_transport_send, _, _, _}
  end

  test "scan_device ignores an unsupported object and a failed read", %{
    client: client,
    transport: transport
  } do
    device = obj(:device, 3)

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    :ok =
      FakeTransport.set_send_result(transport, fn _destination, _data, _opts ->
        n = Agent.get_and_update(counter, &{&1, &1 + 1})
        if n == 0, do: :ok, else: {:error, :unsupported_object_type}
      end)

    task =
      Task.async(fn ->
        ClientHelper.scan_device(client, @dest, device, ignore_unsupported_object_types: true)
      end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, device, :object_list, [
        identifier(obj(:analog_value, 1)),
        identifier(obj(:analog_value, 2))
      ])
    end)

    assert :ok = FakeTransport.set_send_result(transport, {:error, :unsupported_object_type})
    assert {:ok, %{}} = Task.await(task)
    assert :ok = FakeTransport.set_send_result(transport, :ok)
    flush_sends()

    {:ok, sup} = Task.Supervisor.start_link()
    {:ok, again} = Agent.start_link(fn -> 0 end)

    :ok =
      FakeTransport.set_send_result(transport, fn _destination, _data, _opts ->
        n = Agent.get_and_update(again, &{&1, &1 + 1})
        if n == 0, do: :ok, else: {:error, :down}
      end)

    task =
      Task.async(fn ->
        ClientHelper.scan_device(client, @dest, device,
          ignore_errors: true,
          task_supervisor: sup,
          task_max_concurrency: 1
        )
      end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, device, :object_list, [
        identifier(obj(:analog_value, 8)),
        identifier(obj(:analog_value, 9))
      ])
    end)

    assert {:ok, %{}} = Task.await(task)
    assert :ok = FakeTransport.set_send_result(transport, :ok)
    flush_sends()

    task =
      Task.async(fn ->
        ClientHelper.scan_device(client, @dest, device, ignore_errors: true)
      end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, device, :object_list, [real(1.0), real(2.0)])
    end)

    assert {:ok, %{}} = Task.await(task)
    assert :ok = FakeTransport.set_send_result(transport, :ok)
    flush_sends()

    {:ok, halted} = Agent.start_link(fn -> 0 end)

    :ok =
      FakeTransport.set_send_result(transport, fn _destination, _data, _opts ->
        n = Agent.get_and_update(halted, &{&1, &1 + 1})
        if n == 0, do: :ok, else: {:error, :down}
      end)

    task = Task.async(fn -> ClientHelper.scan_device(client, @dest, device) end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, device, :object_list, [
        identifier(obj(:analog_value, 3)),
        identifier(obj(:analog_value, 4))
      ])
    end)

    assert {:error, {:down, %ObjectIdentifier{}}} = Task.await(task)
    # Failed object reads also notify the fake transport owner. Drain them so
    # the next reply targets the new scan's object-list request.
    flush_sends()

    {:ok, exiting} = Task.Supervisor.start_link()

    :ok = FakeTransport.set_send_result(transport, :ok)

    :ok =
      FakeTransport.set_send_result(transport, fn _destination, _data, _opts ->
        n = Agent.get_and_update(halted, &{&1, &1 + 1})
        if n == 0, do: :ok, else: {:error, :down}
      end)

    Agent.update(halted, fn _state -> 0 end)

    # Finish arranging the transport before the scan task can send its first read.
    task =
      Task.Supervisor.async_nolink(exiting, fn ->
        ClientHelper.scan_device(client, @dest, device, exit_on_error: true)
      end)

    reply_confirmed(@dest, fn invoke_id ->
      read_ack(invoke_id, device, :object_list, [
        identifier(obj(:analog_value, 3)),
        identifier(obj(:analog_value, 4))
      ])
    end)

    assert {:exit, {:error, {:down, %ObjectIdentifier{}}}} =
             Task.yield(task, 1_000) || Task.shutdown(task)

    assert :ok = FakeTransport.set_send_result(transport, :ok)
    flush_sends()
  end

  defp obj(type, instance), do: %ObjectIdentifier{type: type, instance: instance}

  defp real(value), do: %Encoding{encoding: :primitive, extras: [], type: :real, value: value}

  defp unsigned(value),
    do: %Encoding{encoding: :primitive, extras: [], type: :unsigned_integer, value: value}

  defp identifier(object),
    do: %Encoding{encoding: :primitive, extras: [], type: :object_identifier, value: object}

  defp analog_ack(invoke_id, object) do
    {:ok, ack} =
      ReadPropertyMultipleAck.to_apdu(
        %ReadPropertyMultipleAck{
          results: [
            %BACnet.Protocol.ReadAccessResult{
              object_identifier: object,
              results: [
                result(:object_name, text("AV1")),
                result(:present_value, real(1.0)),
                result(:event_state, enumerated(0)),
                result(:out_of_service, boolean(false)),
                result(:units, enumerated(95)),
                result(:status_flags, bits({false, false, false, false}))
              ]
            }
          ]
        },
        invoke_id
      )

    ack
  end

  defp text(value),
    do: %Encoding{encoding: :primitive, extras: [], type: :character_string, value: value}

  defp enumerated(value),
    do: %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: value}

  defp boolean(value),
    do: %Encoding{encoding: :primitive, extras: [], type: :boolean, value: value}

  defp bits(value),
    do: %Encoding{encoding: :primitive, extras: [], type: :bitstring, value: value}

  defp result(property, value) do
    %BACnet.Protocol.ReadAccessResult.ReadResult{
      property_identifier: property,
      property_array_index: nil,
      property_value: value,
      error: nil
    }
  end

  defp read_ack(invoke_id, object, property, value, index \\ nil) do
    {:ok, ack} =
      ReadPropertyAck.to_apdu(
        %ReadPropertyAck{
          object_identifier: object,
          property_identifier: property,
          property_array_index: index,
          property_value: value
        },
        invoke_id
      )

    ack
  end

  defp reply_confirmed(dest, fun) do
    assert_receive {:fake_transport_send, ^dest, raw, _opts}, 1_000
    {:ok, %APDU.ConfirmedServiceRequest{invoke_id: invoke_id}} = APDU.decode(raw)
    deliver(dest, fun.(invoke_id))
  end

  defp deliver(source, apdu) do
    deliver(client_pid(), source, apdu)
  end

  defp deliver(client, source, apdu) do
    raw = IO.iodata_to_binary(EncoderProtocol.encode(apdu))

    send(
      client,
      {:bacnet_transport, {:bacnet_ipv4, FakeTransport}, source,
       {:apdu, :original_unicast, NPCI.new([]), raw}, self()}
    )
  end

  defp flush_sends() do
    receive do
      {:fake_transport_send, _destination, _data, _opts} -> flush_sends()
    after
      20 -> :ok
    end
  end

  defp flush_client() do
    receive do
      {:bacnet_client, _reference, _apdu, _source_metadata, _client} -> flush_client()
    after
      0 -> :ok
    end
  end

  defp client_pid() do
    Process.get(:client_helper_client) ||
      raise "client pid was not stored"
  end

  defp sent_unconfirmed(dest) do
    assert_receive {:fake_transport_send, ^dest, raw, _opts}
    {:ok, apdu} = APDU.decode(raw)
    {:ok, service} = Services.IAm.from_apdu(apdu)
    service
  end

  defp send_iam(client, source, device, vendor) do
    {:ok, apdu} =
      Services.IAm.to_apdu(
        %Services.IAm{
          device: device,
          max_apdu: 50,
          segmentation_supported: Constants.macro_assert_name(:segmentation, :no_segmentation),
          vendor_id: vendor
        },
        []
      )

    raw = IO.iodata_to_binary(EncoderProtocol.encode(apdu))

    send(
      client,
      {:bacnet_transport, {:bacnet_ipv4, FakeTransport}, source,
       {:apdu, :original_broadcast, NPCI.new([]), raw}, self()}
    )
  end
end
