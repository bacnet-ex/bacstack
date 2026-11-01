defmodule BACnet.Stack.TrendLoggerTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventLogRecord
  alias BACnet.Protocol.LogMultipleRecord
  alias BACnet.Protocol.LogRecord
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.AnalogInput
  alias BACnet.Protocol.ObjectTypes.EventLog
  alias BACnet.Protocol.ObjectTypes.TrendLog
  alias BACnet.Protocol.ObjectTypes.TrendLogMultiple
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.Services.ConfirmedCovNotification
  alias BACnet.Protocol.Services.ConfirmedEventNotification
  alias BACnet.Protocol.Services.UnconfirmedCovNotification
  alias BACnet.Protocol.Services.UnconfirmedEventNotification
  alias BACnet.Protocol.StatusFlags
  alias BACnet.Stack.LogBuffer
  alias BACnet.Stack.LogBufferTree
  alias BACnet.Stack.TrendLogger

  use ExUnit.Case, async: true

  @moduletag :stack
  @moduletag :trend_logger

  setup do
    parent = self()

    lookup = fn ref ->
      send(parent, {:lookup, ref})
      {:ok, analog()}
    end

    {:ok, server} = TrendLogger.start_link(lookup_cb: lookup)
    %{server: server, parent: parent, lookup: lookup}
  end

  test "start_link rejects bad options and accepts the documented destinations" do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      TrendLogger.start_link(%{})
    end

    assert_raise ArgumentError, ~r/lookup_cb to be in opts/, fn ->
      TrendLogger.start_link([])
    end

    assert_raise ArgumentError, ~r/lookup_cb/, fn ->
      TrendLogger.start_link(lookup_cb: fn _a, _b -> :ok end)
    end

    assert_raise ArgumentError, ~r/cov_cb/, fn ->
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, cov_cb: fn -> :ok end)
    end

    assert_raise RuntimeError, ~r/log_buffer_module/, fn ->
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, log_buffer_module: :no_such_log_buffer)
    end

    for bad <- ["pid", 1] do
      assert_raise ArgumentError, ~r/notification_receiver/, fn ->
        TrendLogger.start_link(lookup_cb: &ok_lookup/1, notification_receiver: bad)
      end

      assert_raise ArgumentError, ~r/supervisor/, fn ->
        TrendLogger.start_link(lookup_cb: &ok_lookup/1, supervisor: bad)
      end
    end

    assert_raise ArgumentError, ~r/state/, fn ->
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, state: %{})
    end

    assert_raise ArgumentError, ~r/timezone/, fn ->
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, timezone: 1)
    end

    assert_raise ArgumentError, ~r/Not\/AZone/, fn ->
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, timezone: "Not/AZone")
    end

    port = Port.open({:spawn, "cat"}, [:binary])
    name = :"trend_logger_#{System.unique_integer([:positive])}"
    {:ok, supervisor} = Task.Supervisor.start_link()

    assert {:ok, pid} =
             TrendLogger.start_link(
               lookup_cb: &ok_lookup/1,
               notification_receiver: self(),
               supervisor: supervisor,
               timezone: "Etc/UTC",
               log_buffer_module: LogBuffer,
               name: name
             )

    assert Process.whereis(name) == pid

    assert {:ok, _logger} =
             TrendLogger.start_link(
               lookup_cb: &ok_lookup/1,
               notification_receiver: port,
               supervisor: port
             )

    assert {:ok, _logger} =
             TrendLogger.start_link(
               lookup_cb: &ok_lookup/1,
               notification_receiver: {name, node()},
               supervisor: {name, node()}
             )

    assert {:ok, _logger} =
             TrendLogger.start_link(
               lookup_cb: &ok_lookup/1,
               notification_receiver: name,
               supervisor: name
             )

    Port.close(port)
  end

  test "a triggered trend log records a local object value", %{server: server} do
    log = trend(1)
    assert :ok = TrendLogger.add_object(server, log)
    assert {:error, :already_known_object} = TrendLogger.add_object(server, log)

    assert :ok = TrendLogger.trigger_log(server, log, analog())
    assert {:ok, {1, LogBuffer, buffer}} = TrendLogger.get_buffer(server, log)

    assert [%LogRecord{log_datum: %Encoding{type: :real, value: 12.5}}] =
             LogBuffer.to_list(buffer)

    assert :ok = TrendLogger.remove_object(server, log)
    assert :ok = TrendLogger.remove_object(server, log)
    assert {:error, :unknown_object} = TrendLogger.get_buffer(server, log)
  end

  test "the tree backend retains ordered records and earlier buffer snapshots" do
    server = start_logger(log_buffer_module: LogBufferTree)
    object = unscheduled_trend(1, buffer_size: 3)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 1.0})
    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 2.0})
    assert {:ok, {2, LogBufferTree, snapshot}} = TrendLogger.get_buffer(server, object)

    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 3.0})
    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 4.0})
    assert {:ok, {4, LogBufferTree, buffer}} = TrendLogger.get_buffer(server, object)

    assert [
             %LogRecord{log_datum: {:time_change, 2.0}},
             %LogRecord{log_datum: {:time_change, 3.0}},
             %LogRecord{log_datum: {:time_change, 4.0}}
           ] = LogBufferTree.to_list(buffer)

    assert [%LogRecord{log_datum: {:time_change, 3.0}}] = LogBufferTree.read_range(buffer, 1, 1)

    assert [
             %LogRecord{log_datum: {:time_change, 1.0}},
             %LogRecord{log_datum: {:time_change, 2.0}}
           ] = LogBufferTree.to_list(snapshot)
  end

  test "the tree backend supports shrinking, growing and pruning a log buffer" do
    server = start_logger(log_buffer_module: LogBufferTree)
    object = unscheduled_trend(1, buffer_size: 4)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 1.0})
    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 2.0})

    smaller = %{object | buffer_size: 1}
    assert :ok = TrendLogger.update_object(server, smaller)
    assert {:ok, {2, LogBufferTree, buffer}} = TrendLogger.get_buffer(server, smaller)
    assert [%LogRecord{log_datum: {:time_change, 2.0}}] = LogBufferTree.to_list(buffer)

    larger = %{object | buffer_size: 3}
    assert :ok = TrendLogger.update_object(server, larger)
    assert :ok = TrendLogger.trigger_log(server, larger, {:time_change, 3.0})
    assert :ok = TrendLogger.trigger_log(server, larger, {:time_change, 4.0})
    assert {:ok, {4, LogBufferTree, buffer}} = TrendLogger.get_buffer(server, larger)
    assert LogBufferTree.get_size(buffer) == 3
    assert buffer.max_size == 3

    assert :ok = TrendLogger.prune_buffer(server, larger)
    assert {:ok, {5, LogBufferTree, buffer}} = TrendLogger.get_buffer(server, larger)

    assert [%LogRecord{log_datum: %LogStatus{buffer_purged: true}}] =
             LogBufferTree.to_list(buffer)
  end

  test "a full tree buffer notifies its receiver while logging continues" do
    server = start_logger(log_buffer_module: LogBufferTree, notification_receiver: self())
    object = unscheduled_trend(1, buffer_size: 2)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 1.0})
    assert {:ok, {1, LogBufferTree, _buffer}} = TrendLogger.get_buffer(server, object)
    refute_receive {:bacnet_trend_logger, nil, _object, %{event: :buffer_full}}, 0

    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 2.0})

    assert_receive {:bacnet_trend_logger, nil, %TrendLog{enable: true},
                    %{event: :buffer_full, buffer: {LogBufferTree, snapshot}}},
                   500

    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 3.0})

    assert_receive {:bacnet_trend_logger, nil, %TrendLog{enable: true},
                    %{event: :buffer_full, buffer: {LogBufferTree, buffer}}},
                   500

    assert [
             %LogRecord{log_datum: {:time_change, 2.0}},
             %LogRecord{log_datum: {:time_change, 3.0}}
           ] =
             LogBufferTree.to_list(buffer)

    assert [
             %LogRecord{log_datum: {:time_change, 1.0}},
             %LogRecord{log_datum: {:time_change, 2.0}}
           ] =
             LogBufferTree.to_list(snapshot)
  end

  test "stop_when_full disables logging with the tree backend" do
    server = start_logger(log_buffer_module: LogBufferTree, notification_receiver: self())
    object = unscheduled_trend(1, buffer_size: 2, stop_when_full: true)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 1.0})

    assert_receive {:bacnet_trend_logger, nil, %TrendLog{enable: false},
                    %{event: :buffer_full, buffer: {LogBufferTree, buffer}}},
                   500

    assert [
             %LogRecord{log_datum: {:time_change, 1.0}},
             %LogRecord{log_datum: %LogStatus{log_disabled: true}}
           ] = LogBufferTree.to_list(buffer)

    assert :ok = TrendLogger.trigger_log(server, object, {:time_change, 2.0})
    assert {:ok, {2, LogBufferTree, ^buffer}} = TrendLogger.get_buffer(server, object)
  end

  test "trigger_log records interrupted, time changes, and COV notifications", %{server: server} do
    log = trend(2)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)
    assert :ok = TrendLogger.trigger_log(server, log, {:time_change, 1.5})

    source = analog()

    cov = cov_notification(ObjectsUtility.get_object_identifier(source), real(3.0))

    cov =
      Map.update!(cov, :property_values, fn values ->
        values ++
          [
            %PropertyValue{
              property_identifier: :status_flags,
              property_array_index: nil,
              property_value: %StatusFlags{
                in_alarm: false,
                fault: false,
                overridden: false,
                out_of_service: true
              },
              priority: nil
            }
          ]
      end)

    assert :ok = TrendLogger.trigger_log(server, log, cov)

    assert {:ok, {3, LogBuffer, buffer}} = TrendLogger.get_buffer(server, log)

    assert [
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}},
             %LogRecord{log_datum: {:time_change, 1.5}},
             %LogRecord{
               log_datum: %Encoding{type: :real, value: 3.0},
               status_flags: %StatusFlags{out_of_service: true}
             }
           ] = LogBuffer.to_list(buffer)
  end

  test "an event log records status, time changes, and event notifications", %{server: server} do
    log = event_log(3)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)
    assert :ok = TrendLogger.trigger_log(server, log, {:time_change, -2.0})

    assert :ok = TrendLogger.trigger_log(server, log, event_notification())
    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(1.0)))

    assert {:ok, {_seq, LogBuffer, buffer}} = TrendLogger.get_buffer(server, log)

    assert [
             %EventLogRecord{log_datum: %LogStatus{log_interrupted: true}},
             %EventLogRecord{log_datum: {:time_change, -2.0}},
             %EventLogRecord{log_datum: %ConfirmedEventNotification{event_type: :out_of_range}}
           ] = LogBuffer.to_list(buffer)
  end

  test "a trend log multiple records each referenced object", %{server: server} do
    source = analog()
    log = trend_multiple(4, [property_ref(source, nil)])
    assert :ok = TrendLogger.add_object(server, log)

    assert :ok = TrendLogger.trigger_log(server, log, [source])
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)
    assert :ok = TrendLogger.trigger_log(server, log, {:time_change, 0.5})

    assert {:ok, {_seq, LogBuffer, buffer}} = TrendLogger.get_buffer(server, log)

    assert [
             %LogMultipleRecord{log_data: [%Encoding{type: :real, value: 12.5}]},
             %LogMultipleRecord{log_data: %LogStatus{log_interrupted: true}},
             %LogMultipleRecord{log_data: {:time_change, 0.5}}
           ] = LogBuffer.to_list(buffer)

    assert_raise ArgumentError, ~r/list of BACnet objects/, fn ->
      TrendLogger.trigger_log(server, log, [:not_an_object])
    end
  end

  test "trend log multiple rejects COV logging and an uninitialized reference", %{server: server} do
    cov = %{trend_multiple(5, [property_ref(analog(), nil)]) | logging_type: :cov}
    assert {:error, :invalid_logging_type} = TrendLogger.add_object(server, cov)

    uninitialized = ObjectsMacro.get_default_dev_object_ref()
    log = trend_multiple(6, [uninitialized])
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, [analog()])

    assert {:ok, {_seq, LogBuffer, buffer}} = TrendLogger.get_buffer(server, log)

    assert [%LogMultipleRecord{log_data: [%BACnetError{code: :no_property_specified}]}] =
             LogBuffer.to_list(buffer)
  end

  test "a remote object without a device id is rejected", %{server: server} do
    log = trend(7)
    remote = put_in(log._metadata.remote_object, true)
    assert {:error, :remote_object_with_no_id} = TrendLogger.add_object(server, remote)
  end

  test "enable, disable, and purge write status records", %{server: server} do
    log = %{trend(8) | enable: false}
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)
    assert {:ok, {0, LogBuffer, buffer}} = TrendLogger.get_buffer(server, log)
    assert [] = LogBuffer.to_list(buffer)

    assert :ok = TrendLogger.change_log_state(server, log, :enable)
    assert {:ok, {1, LogBuffer, buffer}} = TrendLogger.get_buffer(server, log)
    assert [%LogRecord{log_datum: %LogStatus{log_disabled: true}}] = LogBuffer.to_list(buffer)

    assert :ok = TrendLogger.change_log_state(server, :global, :disable)
    assert {:ok, {2, LogBuffer, buffer}} = TrendLogger.get_buffer(server, log)

    assert [
             %LogRecord{log_datum: %LogStatus{log_disabled: true}},
             %LogRecord{log_datum: %LogStatus{log_disabled: false}}
           ] = LogBuffer.to_list(buffer)

    assert :ok = TrendLogger.prune_buffer(server, log)
    assert {:ok, {3, LogBuffer, buffer}} = TrendLogger.get_buffer(server, log)
    assert [%LogRecord{log_datum: %LogStatus{buffer_purged: true}}] = LogBuffer.to_list(buffer)

    other = trend(9)
    assert :ok = TrendLogger.add_object(server, other)
    assert :ok = TrendLogger.prune_buffer(server, :global)
    assert {:ok, {4, _buffer_module, _buffer}} = TrendLogger.get_buffer(server, log)
    assert {:ok, {1, _buffer_module, buffer}} = TrendLogger.get_buffer(server, other)
    assert [%LogRecord{log_datum: %LogStatus{buffer_purged: true}}] = LogBuffer.to_list(buffer)

    missing = trend(10)
    assert {:error, :unknown_object} = TrendLogger.change_log_state(server, missing, :enable)
    assert {:error, :unknown_object} = TrendLogger.prune_buffer(server, missing)
    assert {:error, :unknown_object} = TrendLogger.update_object(server, missing)
  end

  test "update_object transfers the buffer and logs an enable change", %{server: server} do
    log = trend(11, buffer_size: 4)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, analog())

    updated = %{log | buffer_size: 1, enable: false}
    assert :ok = TrendLogger.update_object(server, updated)

    assert {:ok, {_seq, LogBuffer, buffer}} = TrendLogger.get_buffer(server, updated)
    records = LogBuffer.to_list(buffer)
    assert [%LogRecord{log_datum: %LogStatus{log_disabled: false}}] = records
  end

  test "a full buffer notifies the receiver and stop_when_full disables logging" do
    {:ok, logger} =
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, notification_receiver: self())

    log = trend(12, buffer_size: 1, stop_when_full: true)
    assert :ok = TrendLogger.add_object(logger, log)
    assert :ok = TrendLogger.trigger_log(logger, log, analog())
    assert {:ok, _buffer} = TrendLogger.get_buffer(logger, log)

    assert_receive {:bacnet_trend_logger, nil, %TrendLog{enable: false},
                    %{event: :buffer_full, intrinsic_reporting: nil}}

    assert :ok = TrendLogger.trigger_log(logger, log, analog())
    assert {:ok, {2, _buffer_module, buffer}} = TrendLogger.get_buffer(logger, log)
    assert length(LogBuffer.to_list(buffer)) == 1
  end

  test "a polled trend log stores the looked up object", %{server: server, parent: parent} do
    log = trend(13, logging_type: :polled, log_interval: 6_000)
    assert :ok = TrendLogger.add_object(server, log)

    fire_poll(server, log)
    assert_receive {:lookup, _ref}, 500
    records = await_records(server, log, 1)
    assert [%LogRecord{log_datum: %Encoding{type: :real, value: 12.5}}] = records

    send(server, {:timeout, make_ref(), {:poll_log, {:trend_log, 0}}})
    send(server, {:submit_poll, {:trend_log, 0}, make_ref(), analog()})
    send(server, :unused)
    assert {:ok, _buffer} = TrendLogger.get_buffer(server, log)
    refute_receive {:lookup, _}, 30
    assert parent == self()
  end

  test "a failed lookup does not append a record" do
    lookup = fn _ref -> {:error, :down} end
    {:ok, server} = TrendLogger.start_link(lookup_cb: lookup)
    log = trend(14, logging_type: :polled, log_interval: 6_000)
    assert :ok = TrendLogger.add_object(server, log)
    fire_poll(server, log)
    Process.sleep(50)
    assert [] = records(server, log)
  end

  test "COV notification and resubscription use the callback", %{server: _server} do
    parent = self()

    cov_cb = fn server, ref, op, lifetime, increment ->
      send(parent, {:cov, op, ref.property_identifier, lifetime, increment, server})
      :ok
    end

    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1, cov_cb: cov_cb)
    source = analog()
    device = %ObjectIdentifier{type: :device, instance: 77}

    log =
      trend(15,
        logging_type: :cov,
        log_interval: 0,
        cov_resubscription_interval: 60,
        client_cov_increment: 0.5,
        log_device_object_property: property_ref(source, device)
      )

    assert :ok = TrendLogger.add_object(server, log)
    assert_receive {:cov, :sub, :present_value, 120, 0.5, ^server}, 500

    note = cov_notification(ObjectsUtility.get_object_identifier(source), real(8.0), device)
    assert :ok = TrendLogger.notify(server, note)
    assert {:ok, _buffer} = TrendLogger.get_buffer(server, log)

    assert [%LogRecord{log_datum: %Encoding{value: 8.0}}] =
             records(server, log)

    assert :ok = TrendLogger.resubscribe_cov(server, log)
    assert_receive {:cov, :sub, :present_value, 120, 0.5, ^server}, 500

    assert :ok = TrendLogger.change_log_state(server, log, :disable)
    assert_receive {:cov, :unsub, :present_value, 0, nil, ^server}, 500
  end

  test "a COV callback error is retried and an unknown notification is ignored" do
    parent = self()

    cov_cb = fn _server, _ref, op, _lifetime, _increment ->
      send(parent, {:cov, op})
      {:error, :busy}
    end

    {:ok, logger} = TrendLogger.start_link(lookup_cb: &ok_lookup/1, cov_cb: cov_cb)
    source = analog()

    log =
      trend(16,
        logging_type: :cov,
        log_interval: 0,
        cov_resubscription_interval: 60,
        log_device_object_property:
          property_ref(source, %ObjectIdentifier{type: :device, instance: 8})
      )

    assert :ok = TrendLogger.add_object(logger, log)
    assert_receive {:cov, :sub}, 500

    send(logger, {:cov_resub, make_id(log)})
    assert_receive {:cov, :sub}, 500

    other = cov_notification(%ObjectIdentifier{type: :analog_input, instance: 99}, real(1.0))
    assert :ok = TrendLogger.notify(logger, other)
    assert {:ok, {0, _buffer_module, buffer}} = TrendLogger.get_buffer(logger, log)
    assert [] = LogBuffer.to_list(buffer)
  end

  test "check_time disables a log once the stop time is in the past", %{server: server} do
    log = trend(17)
    assert :ok = TrendLogger.add_object(server, log)
    assert :sys.get_state(server).logs[make_id(log)].enabled
    assert {:ok, {0, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    assert [] = LogBuffer.to_list(buffer)

    past = DateTime.utc_now() |> DateTime.add(-3_600) |> BACnetDateTime.from_datetime()

    # Move the stored window across its stop boundary without a clock change
    # or a timing-dependent sleep, then exercise the periodic clock check.
    :sys.replace_state(server, fn state ->
      put_in(state.logs[make_id(log)].object.stop_time, past)
    end)

    send(server, :check_time)

    assert {:ok, {1, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    refute :sys.get_state(server).logs[make_id(log)].enabled
    assert [%LogRecord{log_datum: %LogStatus{}}] = LogBuffer.to_list(buffer)
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)
    assert {:ok, {1, _buffer_module, ^buffer}} = TrendLogger.get_buffer(server, log)
  end

  test "check_time enables a log once its start time has passed", %{server: server} do
    now = DateTime.utc_now()
    future = now |> DateTime.add(3_600) |> BACnetDateTime.from_datetime()
    log = trend(17, start_time: future)
    assert :ok = TrendLogger.add_object(server, log)
    refute :sys.get_state(server).logs[make_id(log)].enabled

    past = now |> DateTime.add(-3_600) |> BACnetDateTime.from_datetime()

    :sys.replace_state(server, fn state ->
      put_in(state.logs[make_id(log)].object.start_time, past)
    end)

    send(server, :check_time)

    assert {:ok, {1, _buffer_module, _buffer}} = TrendLogger.get_buffer(server, log)
    assert :sys.get_state(server).logs[make_id(log)].enabled
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)
    assert {:ok, {2, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    assert length(LogBuffer.to_list(buffer)) == 2
  end

  test "restored state wraps the sequence number and keeps the buffer", %{server: server} do
    log = trend(18)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)

    state = :sys.get_state(server)
    id = make_id(log)

    logs =
      Map.update!(state.logs, id, fn entry ->
        %{entry | seq_number: 4_294_967_295}
      end)

    {:ok, restored} =
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, state: %{state | logs: logs})

    assert :ok = TrendLogger.prune_buffer(restored, log)
    assert {:ok, {1, LogBuffer, buffer}} = TrendLogger.get_buffer(restored, log)
    assert [%LogRecord{log_datum: %LogStatus{buffer_purged: true}}] = LogBuffer.to_list(buffer)
  end

  test "intrinsic reporting notifies the receiver" do
    {:ok, server} =
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, notification_receiver: self())

    log = trend(40, [buffer_size: 4, notification_threshold: 1], intrinsic_reporting: true)

    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)
    assert {:ok, _buffer} = TrendLogger.get_buffer(server, log)

    assert_receive {:bacnet_trend_logger, nil, %TrendLog{},
                    %{event: :intrinsic_reporting, intrinsic_reporting: notify}}

    assert notify != nil
  end

  test "resubscribe_cov global and removal unsubscribe a remote log" do
    parent = self()

    cov_cb = fn _server, _ref, op, _lifetime, _increment ->
      send(parent, {:cov, op})
      :ok
    end

    {:ok, sup} = Task.Supervisor.start_link()

    {:ok, server} =
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, cov_cb: cov_cb, supervisor: sup)

    source = analog()
    device = %ObjectIdentifier{type: :device, instance: 9}

    log =
      trend(41,
        logging_type: :cov,
        log_interval: 0,
        cov_resubscription_interval: 30,
        log_device_object_property: property_ref(source, device)
      )

    assert :ok = TrendLogger.add_object(server, log)
    assert_receive {:cov, :sub}, 500

    assert :ok = TrendLogger.resubscribe_cov(server, :global)
    assert_receive {:cov, :sub}, 500

    assert :ok = TrendLogger.remove_object(server, log)
    assert_receive {:cov, :unsub}, 500
  end

  test "a polled trend log multiple collects one value per reference" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    source = analog()

    log =
      trend_multiple(90, [property_ref(source, nil)],
        logging_type: :polled,
        log_interval: 6_000
      )

    log = %{
      log
      | log_device_object_property:
          BACnetArray.from_list([
            %{
              property_ref(source, nil)
              | object_identifier: uninitialized_identifier(:analog_input)
            },
            property_ref(source, nil)
          ])
    }

    assert :ok = TrendLogger.add_object(server, log)
    fire_poll(server, log)
    assert [%LogMultipleRecord{log_data: data}] = await_records(server, log, 1)
    assert length(data) == 2
  end

  test "a supervised polled trend log multiple collects the referenced value" do
    {:ok, sup} = Task.Supervisor.start_link()
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1, supervisor: sup)
    source = analog()

    log =
      trend_multiple(42, [property_ref(source, nil)],
        logging_type: :polled,
        log_interval: 6_000
      )

    assert :ok = TrendLogger.add_object(server, log)
    fire_poll(server, log)

    assert [%LogMultipleRecord{log_data: [%Encoding{type: :real, value: 12.5}]}] =
             await_records(server, log, 1)
  end

  test "lookup results that are not objects become internal errors and are discarded" do
    error = %BACnetError{class: :device, code: :other}

    for result <- [{:ok, :nope}, {:error, error}, :weird] do
      lookup = fn _ref -> result end
      {:ok, server} = TrendLogger.start_link(lookup_cb: lookup)
      log = trend(43, logging_type: :polled, log_interval: 6_000)
      assert :ok = TrendLogger.add_object(server, log)
      fire_poll(server, log)
      Process.sleep(40)
      assert [] = records(server, log)
    end

    lookup = fn _ref -> throw(:boom) end
    {:ok, server} = TrendLogger.start_link(lookup_cb: lookup)
    log = trend(44, logging_type: :polled, log_interval: 6_000)
    assert :ok = TrendLogger.add_object(server, log)
    fire_poll(server, log)
    Process.sleep(40)
    assert [] = records(server, log)
  end

  test "COV notifications accept the plain encoding types and a status flag" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    source = analog()
    log = trend(45, log_device_object_property: property_ref(source, nil))
    assert :ok = TrendLogger.add_object(server, log)

    for value <- [
          Encoding.create!({:boolean, true}),
          Encoding.create!({:enumerated, 1}),
          Encoding.create!({:unsigned_integer, 4}),
          Encoding.create!({:signed_integer, -2}),
          Encoding.create!({:bitstring, {1, <<1::1>>}}),
          Encoding.create!({:character_string, "log"}),
          Encoding.create!({:octet_string, <<9>>}),
          Encoding.create!({:null, nil})
        ] do
      note =
        cov_notification(ObjectsUtility.get_object_identifier(source), value, nil)

      note = %{
        note
        | property_values:
            note.property_values ++
              [
                %PropertyValue{
                  property_identifier: :status_flags,
                  property_array_index: nil,
                  property_value: %StatusFlags{
                    in_alarm: false,
                    fault: false,
                    overridden: false,
                    out_of_service: false
                  },
                  priority: nil
                }
              ]
      }

      assert :ok = TrendLogger.notify(server, note)
    end

    assert {:ok, {8, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    assert length(LogBuffer.to_list(buffer)) == 8
  end

  test "check_time leaves an enabled log and an event log unchanged" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    log = trend(46)
    event = event_log(47)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.add_object(server, event)
    send(server, :check_time)
    assert {:ok, {0, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    assert [] = LogBuffer.to_list(buffer)
    assert {:ok, {0, _buffer_module, buffer}} = TrendLogger.get_buffer(server, event)
    assert [] = LogBuffer.to_list(buffer)
  end

  test "disabling an already disabled log does not subscribe" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    log = %{trend(48) | enable: false}
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.change_log_state(server, log, :disable)
    assert {:ok, {1, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    assert length(LogBuffer.to_list(buffer)) == 1
  end

  test "update_object with the same buffer size keeps the records" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    log = trend(49)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)
    assert :ok = TrendLogger.update_object(server, log)
    assert {:ok, {1, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    assert [%LogRecord{log_datum: %LogStatus{log_interrupted: true}}] = LogBuffer.to_list(buffer)
  end

  test "a zero log interval schedules the one second poll" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    log = %{trend(50, logging_type: :polled, log_interval: 6_000) | log_interval: 0}
    assert :ok = TrendLogger.add_object(server, log)
    fire_poll(server, log)
    assert [_record] = await_records(server, log, 1)
  end

  test "COV without a callback and a throwing callback stay up" do
    source = analog()
    device = %ObjectIdentifier{type: :device, instance: 3}

    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)

    log =
      trend(51,
        logging_type: :cov,
        log_interval: 0,
        cov_resubscription_interval: 10,
        log_device_object_property: property_ref(source, device)
      )

    assert :ok = TrendLogger.add_object(server, log)
    send(server, {:cov_resub, make_id(log)})
    assert :ok = TrendLogger.change_log_state(server, log, :disable)
    assert {:ok, _buffer} = TrendLogger.get_buffer(server, log)

    cov_cb = fn _server, _ref, _op, _life, _inc -> throw(:nope) end
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1, cov_cb: cov_cb)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.change_log_state(server, log, :disable)
    Process.sleep(30)
    assert Process.alive?(server)
  end

  test "a local COV reference is not subscribed" do
    parent = self()

    cov_cb = fn _s, _r, op, _l, _i ->
      send(parent, {:cov, op})
      :ok
    end

    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1, cov_cb: cov_cb)

    log =
      trend(52,
        logging_type: :cov,
        log_interval: 0,
        cov_resubscription_interval: 10,
        log_device_object_property: property_ref(analog(), nil)
      )

    assert :ok = TrendLogger.add_object(server, log)
    send(server, {:cov_resub, make_id(log)})
    assert {:ok, _buffer} = TrendLogger.get_buffer(server, log)
    refute_receive {:cov, _}, 40
  end

  test "restoring a polled log arms its poll timer" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    log = trend(60, logging_type: :polled, log_interval: 6_000)
    assert :ok = TrendLogger.add_object(server, log)
    state = :sys.get_state(server)

    {:ok, restored} = TrendLogger.start_link(lookup_cb: &ok_lookup/1, state: state)
    fire_poll(restored, log)
    assert [_record] = await_records(restored, log, 1)
  end

  test "intrinsic reporting without a receiver still updates the log" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)

    log = trend(61, [buffer_size: 4, notification_threshold: 100], intrinsic_reporting: true)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, :interrupted)
    assert {:ok, {1, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    assert [%LogRecord{log_datum: %LogStatus{log_interrupted: true}}] = LogBuffer.to_list(buffer)
  end

  test "a full buffer without a receiver disables logging" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    log = trend(62, buffer_size: 1, stop_when_full: true)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, analog())
    assert {:ok, {2, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    assert Enum.any?(LogBuffer.to_list(buffer), &match?(%LogRecord{log_datum: %LogStatus{}}, &1))
  end

  test "property reads for other datatypes are stored" do
    source = analog()

    for property <- [:status_flags, :object_name, :out_of_service] do
      {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)

      ref = %{property_ref(source, nil) | property_identifier: property}
      log = trend(63, log_device_object_property: ref)
      assert :ok = TrendLogger.add_object(server, log)

      case TrendLogger.trigger_log(server, log, source) do
        :ok ->
          assert {:ok, {1, _buffer_module, _buffer}} = TrendLogger.get_buffer(server, log)

        {:error, _reason} ->
          assert Process.alive?(server)
      end
    end
  end

  test "an encoding submitted for a poll is stored" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    log = trend(64, logging_type: :polled, log_interval: 6_000)
    assert :ok = TrendLogger.add_object(server, log)
    timer = :sys.get_state(server).logs[make_id(log)].poll_timer
    Process.cancel_timer(timer)
    send(server, {:submit_poll, make_id(log), timer, real(4.0)})
    assert {:ok, _buffer} = TrendLogger.get_buffer(server, log)
    assert [%LogRecord{log_datum: %Encoding{type: :real, value: 4.0}}] = records(server, log)
  end

  test "a trend log multiple can subscribe each remote reference" do
    parent = self()

    cov_cb = fn _server, ref, op, _life, _inc ->
      send(parent, {:cov, op, ref.device_identifier && ref.device_identifier.instance})
      :ok
    end

    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1, cov_cb: cov_cb)
    source = analog()
    device = %ObjectIdentifier{type: :device, instance: 12}

    log = %{
      trend_multiple(65, [property_ref(source, device)])
      | logging_type: :cov,
        cov_resubscription_interval: 15
    }

    assert :ok = TrendLogger.add_object(server, %{log | logging_type: :triggered})
    assert :ok = TrendLogger.update_object(server, log)
    assert_receive {:cov, :sub, 12}, 500

    assert :ok = TrendLogger.remove_object(server, log)
    assert_receive {:cov, :unsub, 12}, 500
  end

  test "an uninitialized monitored reference is ignored by the poll" do
    {:ok, server} =
      TrendLogger.start_link(lookup_cb: &ok_lookup/1, notification_receiver: self())

    log = trend(66, logging_type: :polled, log_interval: 6_000)

    log = %{
      log
      | log_device_object_property: %{
          log.log_device_object_property
          | object_identifier: uninitialized_identifier(:analog_input)
        }
    }

    assert :ok = TrendLogger.add_object(server, log)
    fire_poll(server, log)
    send(server, {:cov_resub, make_id(log)})
    send(server, {:maybe_notify_receiver, {:trend_log, 404}})
    assert {:ok, {0, _buffer_module, buffer}} = TrendLogger.get_buffer(server, log)
    assert [] = LogBuffer.to_list(buffer)
  end

  test "an unconfirmed event notification is stored as a confirmed record" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    event = event_log(67)
    assert :ok = TrendLogger.add_object(server, event)

    assert :ok =
             TrendLogger.trigger_log(
               server,
               event,
               struct!(UnconfirmedEventNotification, Map.from_struct(event_notification()))
             )

    assert [%EventLogRecord{log_datum: %ConfirmedEventNotification{event_type: :out_of_range}}] =
             records(server, event)
  end

  test "uninitialized COV references are not subscribed" do
    parent = self()

    cov_cb = fn _s, _r, op, _l, _i ->
      send(parent, {:cov, op})
      :ok
    end

    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1, cov_cb: cov_cb)
    device = %ObjectIdentifier{type: :device, instance: 4}

    device_log =
      trend(80,
        logging_type: :cov,
        log_interval: 0,
        cov_resubscription_interval: 10,
        log_device_object_property: property_ref(analog(), device)
      )

    device_log = %{
      device_log
      | log_device_object_property: %{
          device_log.log_device_object_property
          | device_identifier: uninitialized_identifier(:device)
        }
    }

    object_log =
      trend(81,
        logging_type: :cov,
        log_interval: 0,
        cov_resubscription_interval: 10,
        log_device_object_property: property_ref(analog(), device)
      )

    object_log = %{
      object_log
      | log_device_object_property: %{
          object_log.log_device_object_property
          | object_identifier: uninitialized_identifier(:analog_input)
        }
    }

    assert :ok = TrendLogger.add_object(server, device_log)
    assert :ok = TrendLogger.add_object(server, object_log)
    refute_receive {:cov, _op}, 40
  end

  test "a non-array property index is stored as a property error" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    source = analog()

    ref_prop = %{property_ref(source, nil) | property_array_index: 1}
    log = trend(91, log_device_object_property: ref_prop)
    assert :ok = TrendLogger.add_object(server, log)
    assert :ok = TrendLogger.trigger_log(server, log, source)
    assert Process.alive?(server)

    assert [
             %LogRecord{
               log_datum: %BACnetError{class: :property, code: :property_is_not_an_array}
             }
           ] =
             records(server, log)
  end

  test "a lookup that exits is recorded as an internal error" do
    lookup = fn _ref -> exit(:kill) end
    {:ok, server} = TrendLogger.start_link(lookup_cb: lookup)
    source = analog()

    log =
      trend_multiple(92, [property_ref(source, nil)],
        logging_type: :polled,
        log_interval: 6_000
      )

    assert :ok = TrendLogger.add_object(server, log)
    fire_poll(server, log)

    assert [%LogMultipleRecord{log_data: [nil]}] = await_records(server, log, 1)
  end

  test "an unconfirmed COV notification is stored" do
    {:ok, server} = TrendLogger.start_link(lookup_cb: &ok_lookup/1)
    source = analog()
    log = trend(93, log_device_object_property: property_ref(source, nil))
    assert :ok = TrendLogger.add_object(server, log)

    note =
      struct!(
        UnconfirmedCovNotification,
        Map.from_struct(cov_notification(id_of(source), real(1.0), nil))
      )

    assert :ok = TrendLogger.notify(server, note)
    assert [%LogRecord{log_datum: %Encoding{type: :real, value: 1.0}}] = records(server, log)
  end

  test "unknown messages are ignored", %{server: server} do
    log = trend(19)
    assert :ok = TrendLogger.add_object(server, log)
    send(server, {:maybe_notify_receiver, {:trend_log, 404}})
    send(server, {:submit_poll, make_id(log), make_ref(), :not_a_sample})

    parent = self()

    spawn(fn ->
      result =
        try do
          GenServer.call(server, :not_a_call, 50)
        catch
          :exit, reason -> {:exit, reason}
        end

      send(parent, {:call, result})
    end)

    assert_receive {:call, {:exit, {:timeout, _}}}, 500
    assert {:ok, {0, _buffer_module, _buffer}} = TrendLogger.get_buffer(server, log)
  end

  test "logging is disabled before its time window" do
    now = DateTime.utc_now()

    object =
      trend(1,
        start_time: BACnetDateTime.from_datetime(DateTime.add(now, 3_600)),
        stop_time: BACnetDateTime.from_datetime(DateTime.add(now, 7_200))
      )

    server = start_logger()
    assert :ok = TrendLogger.add_object(server, object)
    refute :sys.get_state(server).logs[make_id(object)].enabled
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert records(server, object) == []
  end

  test "logging is enabled inside its time window" do
    now = DateTime.utc_now()

    object =
      trend(1,
        start_time: BACnetDateTime.from_datetime(DateTime.add(now, -3_600)),
        stop_time: BACnetDateTime.from_datetime(DateTime.add(now, 3_600))
      )

    server = start_logger()
    assert :ok = TrendLogger.add_object(server, object)
    assert :sys.get_state(server).logs[make_id(object)].enabled
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert [%LogRecord{log_datum: %LogStatus{log_interrupted: true}}] = records(server, object)
  end

  test "logging is disabled after its time window" do
    now = DateTime.utc_now()

    object =
      trend(1,
        start_time: BACnetDateTime.from_datetime(DateTime.add(now, -7_200)),
        stop_time: BACnetDateTime.from_datetime(DateTime.add(now, -3_600))
      )

    server = start_logger()
    assert :ok = TrendLogger.add_object(server, object)
    refute :sys.get_state(server).logs[make_id(object)].enabled
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert records(server, object) == []
  end

  test "one confirmed COV notification appends to every matching log" do
    server = start_logger()
    first = unscheduled_trend(1, logging_type: :cov)
    second = unscheduled_trend(2, logging_type: :cov)
    assert :ok = TrendLogger.add_object(server, first)
    assert :ok = TrendLogger.add_object(server, second)
    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(3.0)))

    assert [%LogRecord{log_datum: %Encoding{type: :real, value: 3.0}}] = records(server, first)
    assert [%LogRecord{log_datum: %Encoding{type: :real, value: 3.0}}] = records(server, second)
  end

  test "unconfirmed COV fanout preserves existing records and unrelated logs" do
    server = start_logger()
    first = unscheduled_trend(1, logging_type: :cov)

    unrelated =
      unscheduled_trend(2,
        logging_type: :cov,
        log_device_object_property: %{
          first.log_device_object_property
          | object_identifier: %ObjectIdentifier{type: :analog_input, instance: 2}
        }
      )

    third = unscheduled_trend(3, logging_type: :cov)
    assert :ok = TrendLogger.add_object(server, first)
    assert :ok = TrendLogger.add_object(server, unrelated)
    assert :ok = TrendLogger.add_object(server, third)
    assert :ok = TrendLogger.trigger_log(server, first, :interrupted)
    assert :ok = TrendLogger.trigger_log(server, unrelated, :interrupted)
    assert :ok = TrendLogger.trigger_log(server, third, :interrupted)
    unrelated_records = records(server, unrelated)

    notification =
      struct!(
        UnconfirmedCovNotification,
        Map.from_struct(cov_notification(id_of(analog()), real(4.0)))
      )

    assert :ok = TrendLogger.notify(server, notification)

    assert [
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}},
             %LogRecord{log_datum: %Encoding{type: :real, value: 4.0}}
           ] = records(server, first)

    assert [
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}},
             %LogRecord{log_datum: %Encoding{type: :real, value: 4.0}}
           ] = records(server, third)

    assert records(server, unrelated) == unrelated_records
  end

  test "a disabled log ignores matching confirmed COV notifications" do
    server = start_logger()
    object = unscheduled_trend(1, enable: false, logging_type: :cov)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(3.0)))
    assert records(server, object) == []
  end

  test "disabling one log preserves its buffer while another continues recording COV data" do
    server = start_logger()
    active = unscheduled_trend(1, logging_type: :cov)
    disabled = unscheduled_trend(2, logging_type: :cov)
    assert :ok = TrendLogger.add_object(server, active)
    assert :ok = TrendLogger.add_object(server, disabled)
    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(3.0)))
    assert :ok = TrendLogger.change_log_state(server, disabled, :disable)
    refute :sys.get_state(server).logs[make_id(disabled)].enabled
    assert {:ok, disabled_buffer} = TrendLogger.get_buffer(server, disabled)

    notification =
      struct!(
        UnconfirmedCovNotification,
        Map.from_struct(cov_notification(id_of(analog()), real(4.0)))
      )

    assert :ok = TrendLogger.notify(server, notification)
    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(5.0)))

    assert {:ok, ^disabled_buffer} = TrendLogger.get_buffer(server, disabled)

    assert [
             %LogRecord{log_datum: %Encoding{type: :real, value: 3.0}},
             %LogRecord{log_datum: %Encoding{type: :real, value: 4.0}},
             %LogRecord{log_datum: %Encoding{type: :real, value: 5.0}}
           ] = records(server, active)
  end

  test "a log past its stop time ignores matching unconfirmed COV notifications" do
    now = DateTime.utc_now()

    object =
      trend(1,
        logging_type: :cov,
        start_time: BACnetDateTime.from_datetime(DateTime.add(now, -7_200)),
        stop_time: BACnetDateTime.from_datetime(DateTime.add(now, -3_600))
      )

    server = start_logger()
    assert :ok = TrendLogger.add_object(server, object)
    assert object.enable
    refute :sys.get_state(server).logs[make_id(object)].enabled

    notification =
      struct!(
        UnconfirmedCovNotification,
        Map.from_struct(cov_notification(id_of(analog()), real(3.0)))
      )

    assert :ok = TrendLogger.notify(server, notification)
    assert {:ok, {0, LogBuffer, buffer}} = TrendLogger.get_buffer(server, object)
    assert LogBuffer.to_list(buffer) == []
  end

  test "a log stopped by a full buffer ignores further COV data" do
    server = start_logger()
    object = unscheduled_trend(1, logging_type: :cov, buffer_size: 2, stop_when_full: true)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    refute :sys.get_state(server).logs[make_id(object)].enabled
    assert {:ok, full_buffer} = TrendLogger.get_buffer(server, object)

    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(3.0)))
    assert {:ok, ^full_buffer} = TrendLogger.get_buffer(server, object)
  end

  test "repeated identical updates keep exactly one polling chain" do
    parent = self()

    server =
      start_logger(
        lookup_cb: fn _ref ->
          send(parent, :lookup)
          {:ok, analog()}
        end
      )

    object = unscheduled_trend(1, logging_type: :polled, log_interval: 6)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.update_object(server, object)
    assert :ok = TrendLogger.update_object(server, object)

    assert_receive :lookup, 2_000
    refute_receive :lookup, 150
  end

  test "changing from polled to triggered mode invalidates a pending poll" do
    parent = self()

    server =
      start_logger(
        lookup_cb: fn _ref ->
          send(parent, :lookup)
          {:ok, analog()}
        end
      )

    object = unscheduled_trend(1, logging_type: :polled, log_interval: 5)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.update_object(server, %{object | logging_type: :triggered})

    refute_receive :lookup, 800
    assert records(server, object) == []
  end

  test "intrinsic reporting without a receiver preserves stop-when-full" do
    server = start_logger()

    object =
      unscheduled_trend(
        1,
        [
          buffer_size: 2,
          stop_when_full: true,
          notification_threshold: 100,
          logging_type: :polled,
          log_interval: 6_000
        ],
        intrinsic_reporting: true
      )

    assert :ok = TrendLogger.add_object(server, object)
    timer = :sys.get_state(server).logs[make_id(object)].poll_timer
    assert is_reference(timer)
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    log = :sys.get_state(server).logs[make_id(object)]

    refute log.enabled
    refute log.object.enable
    assert log.poll_timer == nil
    assert Process.read_timer(timer) == false

    before = records(server, object)

    assert [
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}},
             %LogRecord{log_datum: %LogStatus{log_disabled: true}}
           ] = before

    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert records(server, object) == before
  end

  test "intrinsic reporting with a receiver preserves stop-when-full" do
    server = start_logger(notification_receiver: self())

    object =
      unscheduled_trend(1, [buffer_size: 2, stop_when_full: true, notification_threshold: 1],
        intrinsic_reporting: true
      )

    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    log = :sys.get_state(server).logs[make_id(object)]
    refute log.enabled
    refute log.object.enable
    before = records(server, object)

    assert [
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}},
             %LogRecord{log_datum: %LogStatus{log_disabled: true}}
           ] = before

    assert_receive {:bacnet_trend_logger, nil, %TrendLog{enable: false},
                    %{event: :buffer_full, buffer: {LogBuffer, buffer}}}

    assert LogBuffer.to_list(buffer) == before

    assert_receive {:bacnet_trend_logger, nil, %TrendLog{enable: false},
                    %{event: :intrinsic_reporting}}

    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert records(server, object) == before
  end

  test "intrinsic reporting without a receiver keeps logging when stop-when-full is false" do
    server = start_logger()

    object =
      unscheduled_trend(1, [buffer_size: 2, stop_when_full: false, notification_threshold: 1],
        intrinsic_reporting: true
      )

    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    log = :sys.get_state(server).logs[make_id(object)]
    assert log.enabled
    assert log.object.enable
    assert log.intrinsic_reporting.monitored_value == 3

    assert [
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}},
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}}
           ] = records(server, object)
  end

  test "intrinsic reporting with a receiver keeps logging when stop-when-full is false" do
    server = start_logger(notification_receiver: self())

    object =
      unscheduled_trend(1, [buffer_size: 2, stop_when_full: false, notification_threshold: 1],
        intrinsic_reporting: true
      )

    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    log = :sys.get_state(server).logs[make_id(object)]
    assert log.enabled
    assert log.object.enable
    assert log.intrinsic_reporting.monitored_value == 3

    assert [
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}},
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}}
           ] = records(server, object)

    assert_receive {:bacnet_trend_logger, nil, %TrendLog{enable: true},
                    %{event: :intrinsic_reporting}}
  end

  test "COV records advance the sequence when older records are overwritten" do
    server = start_logger()
    object = unscheduled_trend(1, logging_type: :cov, buffer_size: 1)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(3.0)))
    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(4.0)))

    assert {:ok, {2, LogBuffer, buffer}} = TrendLogger.get_buffer(server, object)
    assert [%LogRecord{log_datum: %Encoding{type: :real, value: 4.0}}] = LogBuffer.to_list(buffer)
  end

  test "COV records reach the intrinsic reporting threshold" do
    server = start_logger(notification_receiver: self())

    object =
      unscheduled_trend(1, [logging_type: :cov, notification_threshold: 2],
        intrinsic_reporting: true
      )

    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(3.0)))
    refute_receive {:bacnet_trend_logger, _, _, %{event: :intrinsic_reporting}}, 0
    assert :ok = TrendLogger.notify(server, cov_notification(id_of(analog()), real(3.0)))

    assert_receive {:bacnet_trend_logger, _, _,
                    %{
                      event: :intrinsic_reporting,
                      intrinsic_reporting: %{current_notification: 2}
                    }},
                   500
  end

  test "single enable/disable records each advance the sequence" do
    server = start_logger()
    object = unscheduled_trend(1)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.change_log_state(server, object, :disable)
    assert :ok = TrendLogger.change_log_state(server, object, :enable)

    assert {:ok, {2, LogBuffer, buffer}} = TrendLogger.get_buffer(server, object)
    assert length(LogBuffer.to_list(buffer)) == 2
  end

  test "global enable/disable records each advance the sequence" do
    server = start_logger()
    object = unscheduled_trend(1)
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.change_log_state(server, :global, :disable)
    assert :ok = TrendLogger.change_log_state(server, :global, :enable)

    assert {:ok, {2, LogBuffer, buffer}} = TrendLogger.get_buffer(server, object)
    assert length(LogBuffer.to_list(buffer)) == 2
  end

  test "the automatic stop record advances the sequence too" do
    server = start_logger()
    object = unscheduled_trend(1, buffer_size: 2, stop_when_full: true)
    assert :ok = TrendLogger.add_object(server, object)
    data_records = trigger_until_stopped(server, object, 3)

    assert {:ok, {sequence, LogBuffer, buffer}} = TrendLogger.get_buffer(server, object)
    # Count every inserted record even if the ring buffer dropped an old one
    assert sequence == data_records + 1

    assert Enum.any?(
             LogBuffer.to_list(buffer),
             &match?(%LogRecord{log_datum: %LogStatus{log_disabled: true}}, &1)
           )
  end

  test "unconfirmed COV records wrap the sequence and unmatched notifications leave it unchanged" do
    server = start_logger()
    object = unscheduled_trend(1, logging_type: :cov)
    assert :ok = TrendLogger.add_object(server, object)

    :sys.replace_state(server, fn state ->
      update_in(state.logs[make_id(object)], &%{&1 | seq_number: 4_294_967_295})
    end)

    notification =
      struct!(
        UnconfirmedCovNotification,
        Map.from_struct(cov_notification(id_of(analog()), real(3.0)))
      )

    assert :ok = TrendLogger.notify(server, notification)
    assert {:ok, {1, LogBuffer, buffer}} = TrendLogger.get_buffer(server, object)
    assert [%LogRecord{log_datum: %Encoding{type: :real, value: 3.0}}] = LogBuffer.to_list(buffer)

    unrelated = %ObjectIdentifier{type: :analog_input, instance: 99}
    assert :ok = TrendLogger.notify(server, cov_notification(unrelated, real(4.0)))
    assert {:ok, {1, LogBuffer, ^buffer}} = TrendLogger.get_buffer(server, object)
  end

  test "single and global status records wrap each log's sequence independently" do
    server = start_logger()
    object = unscheduled_trend(1)
    multiple = trend_multiple(2, [property_ref(analog(), nil)])
    assert :ok = TrendLogger.add_object(server, object)
    assert :ok = TrendLogger.add_object(server, multiple)

    :sys.replace_state(server, fn state ->
      logs =
        state.logs
        |> Map.update!(make_id(object), &%{&1 | seq_number: 4_294_967_295})
        |> Map.update!(make_id(multiple), &%{&1 | seq_number: 4_294_967_295})

      %{state | logs: logs}
    end)

    assert :ok = TrendLogger.change_log_state(server, object, :disable)
    assert {:ok, {1, LogBuffer, _buffer}} = TrendLogger.get_buffer(server, object)
    assert {:ok, {4_294_967_295, LogBuffer, _buffer}} = TrendLogger.get_buffer(server, multiple)

    assert :ok = TrendLogger.change_log_state(server, :global, :disable)
    assert {:ok, {2, LogBuffer, _buffer}} = TrendLogger.get_buffer(server, object)
    assert {:ok, {1, LogBuffer, _buffer}} = TrendLogger.get_buffer(server, multiple)

    assert :ok = TrendLogger.change_log_state(server, :global, :enable)
    assert {:ok, {3, LogBuffer, buffer}} = TrendLogger.get_buffer(server, object)
    assert length(LogBuffer.to_list(buffer)) == 3
    assert {:ok, {2, LogBuffer, buffer}} = TrendLogger.get_buffer(server, multiple)
    assert [%LogMultipleRecord{}, %LogMultipleRecord{}] = LogBuffer.to_list(buffer)
  end

  test "the automatic stop record wraps the sequence and rejected triggers leave it unchanged" do
    server = start_logger()
    object = unscheduled_trend(1, buffer_size: 2, stop_when_full: true)
    assert :ok = TrendLogger.add_object(server, object)

    :sys.replace_state(server, fn state ->
      update_in(state.logs[make_id(object)], &%{&1 | seq_number: 4_294_967_294})
    end)

    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert {:ok, {1, LogBuffer, buffer}} = TrendLogger.get_buffer(server, object)

    assert [
             %LogRecord{log_datum: %LogStatus{log_interrupted: true}},
             %LogRecord{log_datum: %LogStatus{log_disabled: true}}
           ] = LogBuffer.to_list(buffer)

    assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
    assert {:ok, {1, LogBuffer, ^buffer}} = TrendLogger.get_buffer(server, object)
  end

  defp start_logger(opts \\ []) do
    start_supervised!(
      {TrendLogger,
       Keyword.merge(
         [lookup_cb: fn _reference -> {:ok, analog()} end, timezone: "Etc/UTC"],
         opts
       )}
    )
  end

  defp unscheduled_trend(instance, overrides \\ [], opts \\ []) do
    # Exercise the logger's explicit nil/nil (no schedule) branch. This keeps
    # notification and polling tests independent of the time-window predicate
    %{trend(instance, overrides, opts) | start_time: nil, stop_time: nil}
  end

  defp trigger_until_stopped(server, object, remaining) do
    if :sys.get_state(server).logs[make_id(object)].enabled do
      assert remaining > 0, "logger did not stop after filling the buffer"
      assert :ok = TrendLogger.trigger_log(server, object, :interrupted)
      1 + trigger_until_stopped(server, object, remaining - 1)
    else
      0
    end
  end

  defp fire_poll(server, object) do
    timer = :sys.get_state(server).logs[make_id(object)].poll_timer
    assert is_reference(timer)
    Process.cancel_timer(timer)
    send(server, {:timeout, timer, {:poll_log, make_id(object)}})
  end

  defp ok_lookup(_ref), do: {:ok, analog()}

  defp await_records(server, object, count, tries \\ 25) do
    records = records(server, object)

    if length(records) >= count or tries == 0 do
      records
    else
      Process.sleep(20)
      await_records(server, object, count, tries - 1)
    end
  end

  defp records(server, object) do
    assert {:ok, {_seq, LogBuffer, buffer}} = TrendLogger.get_buffer(server, object)
    LogBuffer.to_list(buffer)
  end

  defp make_id(object), do: {ObjectsUtility.get_object_type(object), object.object_instance}

  defp analog() do
    {:ok, object} = AnalogInput.create(1, "AI", %{present_value: 12.5})
    object
  end

  defp property_ref(object, device) do
    %DeviceObjectPropertyRef{
      object_identifier: ObjectsUtility.get_object_identifier(object),
      property_identifier: :present_value,
      property_array_index: nil,
      device_identifier: device
    }
  end

  defp trend(instance, overrides \\ [], opts \\ []) do
    start = BACnetDateTime.from_datetime(~U[2000-01-01 00:00:00Z])
    stop = BACnetDateTime.from_datetime(~U[2100-01-01 00:00:00Z])

    props =
      Map.merge(
        %{
          buffer_size: 8,
          enable: true,
          log_device_object_property: property_ref(analog(), nil),
          log_interval: 0,
          logging_type: :triggered,
          start_time: start,
          stop_time: stop,
          stop_when_full: false
        },
        Map.new(overrides)
      )

    {:ok, object} = TrendLog.create(instance, "T#{instance}", props, opts)
    object
  end

  defp event_log(instance) do
    {:ok, object} = EventLog.create(instance, "E#{instance}", %{buffer_size: 8})
    object
  end

  defp trend_multiple(instance, refs, overrides \\ []) do
    start = BACnetDateTime.from_datetime(~U[2000-01-01 00:00:00Z])
    stop = BACnetDateTime.from_datetime(~U[2100-01-01 00:00:00Z])

    props =
      Map.merge(
        %{
          buffer_size: 8,
          enable: true,
          log_device_object_property: BACnetArray.from_list(refs),
          log_interval: 0,
          logging_type: :triggered,
          start_time: start,
          stop_time: stop
        },
        Map.new(overrides)
      )

    {:ok, object} = TrendLogMultiple.create(instance, "M#{instance}", props)
    object
  end

  defp id_of(object), do: ObjectsUtility.get_object_identifier(object)

  defp uninitialized_identifier(type) do
    %ObjectIdentifier{
      type: type,
      instance: ObjectsMacro.get_default_dev_object_ref().object_identifier.instance
    }
  end

  defp real(value), do: Encoding.create!({:real, value})

  defp cov_notification(object_id, value, device \\ %ObjectIdentifier{type: :device, instance: 1}) do
    %ConfirmedCovNotification{
      process_identifier: 1,
      initiating_device: device,
      monitored_object: object_id,
      time_remaining: 60,
      property_values: [
        %PropertyValue{
          property_identifier: :description,
          property_array_index: nil,
          property_value: Encoding.create!({:character_string, "skip"}),
          priority: nil
        },
        %PropertyValue{
          property_identifier: :present_value,
          property_array_index: nil,
          property_value: value,
          priority: nil
        }
      ]
    }
  end

  defp event_notification() do
    %ConfirmedEventNotification{
      process_identifier: 1,
      initiating_device: %ObjectIdentifier{type: :device, instance: 1},
      event_object: %ObjectIdentifier{type: :analog_input, instance: 1},
      timestamp: ObjectsMacro.get_default_bacnet_timestamp(),
      notification_class: 1,
      priority: 100,
      event_type: :out_of_range,
      message_text: nil,
      notify_type: :alarm,
      ack_required: false,
      from_state: :normal,
      to_state: :offnormal,
      event_values: nil
    }
  end
end
