defmodule BACnet.Test.Protocol.ObjectTypes.TrendLogTest do
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.LogRecord
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.TrendLog
  alias BACnet.Stack.TrendLogger

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_trend_log

  doctest TrendLog

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 auto corrects with log_interval = 1 and cov" do
    assert {:ok, %{log_interval: 0}} =
             TrendLog.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
               log_interval: 1,
               logging_type: :cov
             })
  end

  test "verify create/4 auto corrects with log_interval = 0 and polled" do
    assert {:ok, %{log_interval: 1}} =
             TrendLog.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
               log_interval: 0,
               logging_type: :polled
             })
  end

  test "verify create/4 succeeds with any log_interval and triggered" do
    assert {:ok, %{log_interval: 0, logging_type: :triggered}} =
             TrendLog.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
               log_interval: 0,
               logging_type: :triggered
             })

    assert {:ok, %{log_interval: 0, logging_type: :triggered}} =
             TrendLog.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
               log_interval: 1,
               logging_type: :triggered
             })
  end

  test "alignment properties remain absent when neither is supplied" do
    assert {:ok, object} = create_alignment_log(%{})
    refute TrendLog.has_property?(object, :align_intervals)
    refute TrendLog.has_property?(object, :interval_offset)
  end

  test "supplying align_intervals adds a zero interval_offset" do
    for enabled <- [false, true] do
      assert {:ok, object} = create_alignment_log(%{align_intervals: enabled})
      assert object.align_intervals == enabled
      assert object.interval_offset == 0
      assert TrendLog.has_property?(object, :align_intervals)
      assert TrendLog.has_property?(object, :interval_offset)
    end
  end

  test "supplying interval_offset adds align_intervals disabled by default" do
    assert {:ok, object} = create_alignment_log(%{interval_offset: 3_000})
    refute object.align_intervals
    assert object.interval_offset == 3_000
    assert TrendLog.has_property?(object, :align_intervals)
    assert TrendLog.has_property?(object, :interval_offset)
  end

  test "supplying both alignment properties preserves their values" do
    assert {:ok, %{align_intervals: true, interval_offset: 3_000}} =
             create_alignment_log(%{align_intervals: true, interval_offset: 3_000})
  end

  test "adding either alignment property adds its partner" do
    assert {:ok, object} = create_alignment_log(%{})

    for {property, value} <- [align_intervals: true, interval_offset: 3_000] do
      assert {:ok, updated} = TrendLog.add_property(object, property, value)
      assert TrendLog.has_property?(updated, :align_intervals)
      assert TrendLog.has_property?(updated, :interval_offset)
      assert Map.fetch!(updated, property) == value
      assert updated.align_intervals == (property == :align_intervals)
      assert updated.interval_offset == if(property == :interval_offset, do: 3_000, else: 0)
    end
  end

  test "removing either alignment property removes the pair" do
    assert {:ok, object} =
             create_alignment_log(%{align_intervals: true, interval_offset: 3_000})

    for property <- [:align_intervals, :interval_offset] do
      assert {:ok, updated} = TrendLog.remove_property(object, property)
      refute TrendLog.has_property?(updated, :align_intervals)
      refute TrendLog.has_property?(updated, :interval_offset)
    end
  end

  test "verify create/4 adds Log_Buffer for remote objects" do
    assert {:ok, %TrendLog{log_buffer: []} = remote} =
             TrendLog.create(
               1,
               "TEST",
               %{
                 align_intervals: false,
                 interval_offset: 0,
                 buffer_size: 100,
                 enable: false,
                 log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
                 log_interval: 0,
                 logging_type: :triggered,
                 event_state: :normal,
                 record_count: 0,
                 total_record_count: 0,
                 stop_when_full: false,
                 start_time: ObjectsMacro.get_default_bacnet_datetime(),
                 stop_time: ObjectsMacro.get_default_bacnet_datetime(),
                 status_flags:
                   BACnet.Protocol.StatusFlags.from_bitstring({false, false, false, false})
               },
               remote_object: 1
             )

    assert :ok = TrendLog.validate_execution(remote, Context.new(:initialization))

    write = Context.new({:property_write, :enable, nil, nil})

    assert {:error, :operation_not_available_for_remote_objects} =
             TrendLog.prepare_write(remote, remote, write)

    assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil}} =
             TrendLog.execute(remote, Context.new(:initialization, state: :retained))

    {logger, context} = logger_context(fn _reference -> flunk("unexpected lookup") end)
    assert :ok = TrendLogger.add_object(logger, triggered_log())

    assert {:error, :operation_not_available_for_remote_objects} =
             TrendLog.get_log_buffer(remote, context)
  end

  test "accepts registered logger names and rejects writes to logger-owned properties" do
    object = triggered_log()

    for name <- [
          {__MODULE__, node()},
          {:global, {__MODULE__, :history}},
          {:via, Registry, {__MODULE__, :history}}
        ] do
      assert :ok =
               TrendLog.validate_execution(
                 object,
                 Context.new(:initialization, options: [trend_logger: name])
               )
    end

    write = Context.new({:property_write, :log_buffer, nil, nil})

    assert {:error, {:write_access_denied, :log_buffer}} =
             TrendLog.prepare_write(object, object, write)
  end

  test "verify property_writable?/2 for log_interval and cov is true" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :cov
      })

    assert true == TrendLog.property_writable?(obj, :log_interval)
  end

  test "verify property_writable?/2 for log_interval and polled is true" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 1,
        logging_type: :polled
      })

    assert true == TrendLog.property_writable?(obj, :log_interval)
  end

  test "verify property_writable?/2 for log_interval and triggered is false" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert false == TrendLog.property_writable?(obj, :log_interval)
  end

  test "verify property_writable?/2 for buffer_size and enabled is false" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        enable: true,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert false == TrendLog.property_writable?(obj, :buffer_size)
  end

  test "verify property_writable?/2 for buffer_size and disabled is true" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        enable: false,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert true == TrendLog.property_writable?(obj, :buffer_size)
  end

  test "verify property_writable?/2 for any other works" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        enable: false,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert true == TrendLog.property_writable?(obj, :logging_type)
  end

  test "verify update_property/3 for buffer_size accepts valid lists" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 1,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:ok, %{}} =
             TrendLog.update_property(obj, :log_buffer, [
               %LogRecord{
                 timestamp: ObjectsMacro.get_default_bacnet_datetime(),
                 log_datum: {:time_change, 0.0},
                 status_flags: nil
               }
             ])
  end

  test "verify update_property/3 for buffer_size accepts rejects too large lists" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 1,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:error, {:value_failed_property_validation, :log_buffer}} =
             TrendLog.update_property(obj, :log_buffer, [
               %LogRecord{
                 timestamp: ObjectsMacro.get_default_bacnet_datetime(),
                 log_datum: {:time_change, 0.0},
                 status_flags: nil
               },
               %LogRecord{
                 timestamp: ObjectsMacro.get_default_bacnet_datetime(),
                 log_datum: {:time_change, 1.0},
                 status_flags: nil
               }
             ])
  end

  test "verify update_property/3 for log_interval = 0 sets logging_type = cov" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 1,
        logging_type: :triggered
      })

    assert {:ok, %{log_interval: 0, logging_type: :cov}} =
             TrendLog.update_property(obj, :log_interval, 0)
  end

  test "a nonzero Log_Interval write preserves the requested interval when switching from COV" do
    {:ok, object} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :cov
      })

    assert {:ok, %{log_interval: 200, logging_type: :polled}} =
             TrendLog.update_property(object, :log_interval, 200)
  end

  test "a zero Record_Count update stages the value before lifecycle execution" do
    record = %LogRecord{
      timestamp: ObjectsMacro.get_default_bacnet_datetime(),
      log_datum: {:time_change, 0.0},
      status_flags: nil
    }

    {:ok, object} =
      TrendLog.create(
        1,
        "TEST",
        %{
          buffer_size: 100,
          log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
          log_interval: 0,
          logging_type: :triggered,
          log_buffer: [record],
          record_count: 1,
          records_since_notification: 1
        },
        intrinsic_reporting: true
      )

    assert {:ok, %{record_count: 0, log_buffer: [^record], records_since_notification: 1}} =
             TrendLog.update_property(object, :record_count, 0)
  end

  test "verify update_property/3 for record_count > 0 fails" do
    {:ok, obj} =
      TrendLog.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:error, {:invalid_property_value, :record_count}} =
             TrendLog.update_property(obj, :record_count, 1)
  end

  test "execute retains Trigger until the continuation records a failed sample" do
    parent = self()
    error = %BACnetError{class: :property, code: :read_access_denied}

    {logger, context} =
      logger_context(fn reference ->
        send(parent, {:lookup, reference})
        {:error, error}
      end)

    object = triggered_log()
    assert :ok = TrendLog.validate_execution(object, context)
    assert {:ok, %Result{object: object, state: nil}} = TrendLog.execute(object, context)

    write = %{context | trigger: {:property_write, :trigger, nil, nil}}
    assert {:ok, candidate} = TrendLog.update_property(object, :trigger, true)
    assert {:ok, ^candidate} = TrendLog.prepare_write(object, candidate, write)

    assert {:ok,
            %Result{object: %{trigger: true} = pending, next_execution: :immediate, state: state}} =
             TrendLog.execute(candidate, write)

    refute_received {:lookup, _reference}
    assert {:error, :busy} = TrendLog.prepare_write(pending, candidate, %{write | state: state})

    assert {:ok, %Result{object: current, state: nil, next_execution: nil}} =
             TrendLog.execute(pending, %{context | trigger: :continuation, state: state})

    assert_received {:lookup, _reference}
    refute current.trigger
    assert current.record_count == 1
    assert current.total_record_count == 1
    assert current.log_buffer == []
    assert {:ok, %{buffer: {backend, buffer}}} = TrendLogger.get_snapshot(logger, current)
    assert [%LogRecord{log_datum: ^error}] = backend.to_list(buffer)
  end

  test "execute purges the logger on a zero Record_Count write" do
    {logger, context} = logger_context(fn _reference -> flunk("unexpected lookup") end)
    assert {:ok, %Result{object: object}} = TrendLog.execute(triggered_log(), context)
    assert :ok = TrendLogger.trigger_log(logger, object, {:time_change, 1.0})

    assert {:ok, %Result{object: object}} =
             TrendLog.execute(object, %{context | trigger: :periodic})

    assert object.record_count == 1

    write = %{context | trigger: {:property_write, :record_count, nil, nil}}
    assert {:ok, candidate} = TrendLog.update_property(object, :record_count, 0)
    assert {:ok, ^candidate} = TrendLog.prepare_write(object, candidate, write)
    assert {:ok, %Result{object: purged}} = TrendLog.execute(candidate, write)

    assert purged.record_count == 1
    assert purged.total_record_count == 2
    assert purged.log_buffer == []
    assert {:ok, %{buffer: {backend, buffer}}} = TrendLogger.get_snapshot(logger, purged)
    assert [%LogRecord{log_datum: %LogStatus{buffer_purged: true}}] = backend.to_list(buffer)
  end

  test "preflight requires a logger and rejects Trigger outside triggered mode" do
    object = triggered_log()
    context = Context.new(:initialization)

    assert {:error, {:unsupported_operation, :trend_logger}} =
             TrendLog.validate_execution(object, context)

    assert {:ok, cov} = TrendLog.update_property(object, :logging_type, :cov)
    assert {:ok, candidate} = TrendLog.update_property(cov, :trigger, true)
    write = %{context | trigger: {:application_write, :trigger, nil, nil}}

    assert {:error, :not_configured_for_triggered_logging} =
             TrendLog.prepare_write(cov, candidate, write)
  end

  test "execute applies a committed reference change and refreshes the purge counters" do
    {logger, context} = logger_context(fn _reference -> flunk("unexpected lookup") end)
    assert {:ok, %Result{object: object}} = TrendLog.execute(triggered_log(), context)
    assert :ok = TrendLogger.trigger_log(logger, object, {:time_change, 1.0})

    previous = object.log_device_object_property
    reference = %{previous | property_identifier: :status_flags}
    write = %{context | trigger: {:property_write, :log_device_object_property, nil, nil}}

    assert {:ok, candidate} =
             TrendLog.update_property(object, :log_device_object_property, reference)

    assert {:ok, ^candidate} = TrendLog.prepare_write(object, candidate, write)

    assert {:ok, %Result{object: current}} = TrendLog.execute(candidate, write)
    assert current.log_device_object_property == reference
    assert current.record_count == 1
    assert current.total_record_count == 2
    assert current.log_buffer == []
  end

  test "get_log_buffer captures the backend and sequence number together" do
    {logger, context} = logger_context(fn _reference -> flunk("unexpected lookup") end)
    object = triggered_log()

    assert {:error, :unknown_object} = TrendLog.get_log_buffer(object, context)
    assert :ok = TrendLogger.add_object(logger, object)
    assert :ok = TrendLogger.trigger_log(logger, object, {:time_change, 1.0})
    assert {:ok, {1, backend, buffer}} = TrendLog.get_log_buffer(object, context)

    assert :ok = TrendLogger.trigger_log(logger, object, {:time_change, 2.0})
    assert {:ok, {2, ^backend, updated_buffer}} = TrendLog.get_log_buffer(object, context)

    assert [%LogRecord{log_datum: {:time_change, 1.0}}] = backend.read_range(buffer, 0, 2)

    assert [
             %LogRecord{log_datum: {:time_change, 1.0}},
             %LogRecord{log_datum: {:time_change, 2.0}}
           ] = backend.read_range(updated_buffer, 0, 2)
  end

  test "get_log_buffer reports missing or invalid logger options" do
    object = triggered_log()
    context = Context.new(:periodic)

    assert {:error, {:unsupported_operation, :trend_logger}} =
             TrendLog.get_log_buffer(object, context)

    assert {:error, {:invalid_execution_option, :trend_logger}} =
             TrendLog.get_log_buffer(object, %{context | options: [trend_logger: 123]})
  end

  test "commits a Buffer Ready transition from the logger receiver" do
    {logger, context} =
      logger_context(fn _reference -> flunk("unexpected lookup") end,
        notification_receiver: self()
      )

    defaults = triggered_log()

    assert {:ok, object} =
             TrendLog.create(
               1,
               "History",
               %{
                 buffer_size: 8,
                 notification_threshold: 1,
                 log_interval: 0,
                 logging_type: :triggered,
                 log_device_object_property: defaults.log_device_object_property
               },
               intrinsic_reporting: true
             )

    assert {:ok, initial} = TrendLog.execute(object, context)
    assert :ok = TrendLogger.trigger_log(logger, initial.object, {:time_change, 1.0})

    assert {:ok, %{last_notify_record: 0, records_since_notification: 1}} =
             TrendLogger.get_snapshot(logger, initial.object)

    assert_received {:bacnet_trend_logger, nil, %TrendLog{},
                     %{
                       event: :intrinsic_reporting,
                       intrinsic_reporting: %{current_notification: 1}
                     }}

    context = %{context | trigger: :periodic, state: initial.state}

    assert {:ok, result} = TrendLog.execute(initial.object, context)

    assert %{
             event_type: :buffer_ready,
             transition: :to_normal,
             from_state: :normal,
             to_state: :normal,
             event_values: %{
               current_notification: 1,
               previous_notification: 0,
               buffer_property: %{property_identifier: :log_buffer, property_array_index: nil}
             },
             timestamp: timestamp
           } = EventReporting.transition(result)

    assert result.object.event_timestamps.to_normal == timestamp
    assert result.object.last_notify_record == 1
    assert result.object.log_buffer == []

    assert {:ok, duplicate} = TrendLog.execute(result.object, %{context | state: result.state})
    assert EventReporting.transition(duplicate) == nil
  end

  test "fault recovery and Buffer Ready are recorded in separate executions" do
    {logger, context} = logger_context(fn _reference -> flunk("unexpected lookup") end)
    defaults = triggered_log()

    assert {:ok, object} =
             TrendLog.create(
               1,
               "History",
               %{
                 buffer_size: 8,
                 notification_threshold: 2,
                 reliability: :communication_failure,
                 log_interval: 0,
                 logging_type: :triggered,
                 log_device_object_property: defaults.log_device_object_property
               },
               intrinsic_reporting: true
             )

    assert {:ok, fault} = TrendLog.execute(object, context)
    assert %{to_state: :fault} = EventReporting.transition(fault)
    assert :ok = TrendLogger.trigger_log(logger, fault.object, {:time_change, 1.0})
    assert {:ok, candidate} = TrendLog.update_property(fault.object, :notification_threshold, 1)

    threshold = %{
      context
      | trigger: {:property_write, :notification_threshold, nil, nil},
        state: fault.state
    }

    assert {:ok, waiting} = TrendLog.execute(candidate, threshold)
    assert waiting.object.last_notify_record == 0
    assert waiting.object.records_since_notification == 1

    assert {:ok, candidate} =
             TrendLog.update_property(waiting.object, :reliability, :no_fault_detected)

    recovery = %{
      context
      | trigger: {:application_write, :reliability, nil, nil},
        state: waiting.state
    }

    assert {:ok, recovered} = TrendLog.execute(candidate, recovery)

    assert %{event_type: :change_of_reliability, to_state: :normal} =
             EventReporting.transition(recovered)

    assert recovered.object.last_notify_record == 0
    assert recovered.next_execution == :immediate

    continuation = %{context | trigger: :continuation, state: recovered.state}
    assert {:ok, ready} = TrendLog.execute(recovered.object, continuation)
    assert ready.object.last_notify_record == 1
    assert ready.object.records_since_notification == 0
    assert %{event_type: :buffer_ready, to_state: :normal} = EventReporting.transition(ready)
  end

  test "initialization adopts a registered buffer without losing its records" do
    {logger, context} = logger_context(fn _reference -> flunk("unexpected lookup") end)
    object = triggered_log()
    assert :ok = TrendLogger.add_object(logger, object)
    assert :ok = TrendLogger.trigger_log(logger, object, {:time_change, 1.0})

    assert {:ok, %Result{object: current, next_execution: nil}} =
             TrendLog.execute(object, context)

    assert current.record_count == 1
    assert current.total_record_count == 1
    assert {:ok, {1, backend, buffer}} = TrendLog.get_log_buffer(current, context)
    assert [%LogRecord{log_datum: {:time_change, 1.0}}] = backend.read_range(buffer, 0, 1)
  end

  defp triggered_log() do
    {:ok, object} =
      TrendLog.create(1, "Triggered", %{
        buffer_size: 8,
        log_device_object_property: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        log_interval: 0,
        logging_type: :triggered,
        trigger: false
      })

    object
  end

  defp logger_context(lookup, options \\ []) do
    logger = start_supervised!({TrendLogger, Keyword.put(options, :lookup_cb, lookup)})
    {logger, Context.new(:initialization, options: [trend_logger: logger])}
  end

  defp create_alignment_log(properties) do
    TrendLog.create(
      1,
      "TEST",
      Map.merge(
        %{
          buffer_size: 100,
          log_device_object_property: ObjectsMacro.get_default_dev_object_ref(),
          log_interval: 90_000,
          logging_type: :polled
        },
        properties
      )
    )
  end
end
