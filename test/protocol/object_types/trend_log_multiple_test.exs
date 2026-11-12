defmodule BACnet.Test.Protocol.ObjectTypes.TrendLogMultipleTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.LogMultipleRecord
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.AnalogInput
  alias BACnet.Protocol.ObjectTypes.TrendLogMultiple
  alias BACnet.Stack.TrendLogger

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_trend_log_multiple

  doctest TrendLogMultiple

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 fails with cov" do
    assert {:error, {:value_failed_property_validation, :logging_type}} =
             TrendLogMultiple.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property:
                 BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
               log_interval: 1,
               logging_type: :cov
             })
  end

  test "verify create/4 auto corrects with log_interval = 0 and polled" do
    assert {:ok, %{log_interval: 1}} =
             TrendLogMultiple.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property:
                 BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
               log_interval: 0,
               logging_type: :polled
             })
  end

  test "verify create/4 succeeds with any log_interval and triggered" do
    assert {:ok, %{log_interval: 0, logging_type: :triggered}} =
             TrendLogMultiple.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property:
                 BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
               log_interval: 0,
               logging_type: :triggered
             })

    assert {:ok, %{log_interval: 0, logging_type: :triggered}} =
             TrendLogMultiple.create(1, "TEST", %{
               buffer_size: 100,
               log_device_object_property:
                 BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
               log_interval: 1,
               logging_type: :triggered
             })
  end

  test "alignment properties remain absent when neither is supplied" do
    assert {:ok, object} = create_alignment_log(%{})
    refute TrendLogMultiple.has_property?(object, :align_intervals)
    refute TrendLogMultiple.has_property?(object, :interval_offset)
  end

  test "supplying align_intervals adds a zero interval_offset" do
    for enabled <- [false, true] do
      assert {:ok, object} = create_alignment_log(%{align_intervals: enabled})
      assert object.align_intervals == enabled
      assert object.interval_offset == 0
      assert TrendLogMultiple.has_property?(object, :align_intervals)
      assert TrendLogMultiple.has_property?(object, :interval_offset)
    end
  end

  test "supplying interval_offset adds align_intervals disabled by default" do
    assert {:ok, object} = create_alignment_log(%{interval_offset: 3_000})
    refute object.align_intervals
    assert object.interval_offset == 3_000
    assert TrendLogMultiple.has_property?(object, :align_intervals)
    assert TrendLogMultiple.has_property?(object, :interval_offset)
  end

  test "supplying both alignment properties preserves their values" do
    assert {:ok, %{align_intervals: true, interval_offset: 3_000}} =
             create_alignment_log(%{align_intervals: true, interval_offset: 3_000})
  end

  test "adding either alignment property adds its partner" do
    assert {:ok, object} = create_alignment_log(%{})

    for {property, value} <- [align_intervals: true, interval_offset: 3_000] do
      assert {:ok, updated} = TrendLogMultiple.add_property(object, property, value)
      assert TrendLogMultiple.has_property?(updated, :align_intervals)
      assert TrendLogMultiple.has_property?(updated, :interval_offset)
      assert Map.fetch!(updated, property) == value
      assert updated.align_intervals == (property == :align_intervals)
      assert updated.interval_offset == if(property == :interval_offset, do: 3_000, else: 0)
    end
  end

  test "removing either alignment property removes the pair" do
    assert {:ok, object} =
             create_alignment_log(%{align_intervals: true, interval_offset: 3_000})

    for property <- [:align_intervals, :interval_offset] do
      assert {:ok, updated} = TrendLogMultiple.remove_property(object, property)
      refute TrendLogMultiple.has_property?(updated, :align_intervals)
      refute TrendLogMultiple.has_property?(updated, :interval_offset)
    end
  end

  test "verify create/4 adds Log_Buffer for remote objects" do
    assert {:ok, %TrendLogMultiple{log_buffer: []} = remote} =
             TrendLogMultiple.create(
               1,
               "TEST",
               %{
                 align_intervals: false,
                 interval_offset: 0,
                 buffer_size: 100,
                 enable: false,
                 log_device_object_property:
                   BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
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

    context = Context.new(:initialization, state: :retained)

    assert :ok = TrendLogMultiple.validate_execution(remote, Context.new(:initialization))

    write = Context.new({:property_write, :enable, nil, nil})

    assert {:error, :operation_not_available_for_remote_objects} =
             TrendLogMultiple.prepare_write(remote, remote, write)

    assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil}} =
             TrendLogMultiple.execute(remote, context)

    assert {:error, :operation_not_available_for_remote_objects} =
             TrendLogMultiple.get_log_buffer(remote, context)
  end

  test "accepts registered logger names and rejects writes to logger-owned properties" do
    object = triggered_log([reference(2)])

    for name <- [
          {__MODULE__, node()},
          {:global, {__MODULE__, :history}},
          {:via, Registry, {__MODULE__, :history}}
        ] do
      assert :ok =
               TrendLogMultiple.validate_execution(
                 object,
                 Context.new(:initialization, options: [trend_logger: name])
               )
    end

    write = Context.new({:property_write, :log_buffer, nil, nil})

    assert {:error, {:write_access_denied, :log_buffer}} =
             TrendLogMultiple.prepare_write(object, object, write)
  end

  test "verify property_writable?/2 for log_interval and polled is true" do
    {:ok, obj} =
      TrendLogMultiple.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property:
          BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
        log_interval: 1,
        logging_type: :polled
      })

    assert true == TrendLogMultiple.property_writable?(obj, :log_interval)
  end

  test "verify property_writable?/2 for log_interval and triggered is false" do
    {:ok, obj} =
      TrendLogMultiple.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property:
          BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
        log_interval: 0,
        logging_type: :triggered
      })

    assert false == TrendLogMultiple.property_writable?(obj, :log_interval)
  end

  test "verify property_writable?/2 for buffer_size and enabled is false" do
    {:ok, obj} =
      TrendLogMultiple.create(1, "TEST", %{
        buffer_size: 100,
        enable: true,
        log_device_object_property:
          BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
        log_interval: 0,
        logging_type: :triggered
      })

    assert false == TrendLogMultiple.property_writable?(obj, :buffer_size)
  end

  test "verify property_writable?/2 for buffer_size and disabled is true" do
    {:ok, obj} =
      TrendLogMultiple.create(1, "TEST", %{
        buffer_size: 100,
        enable: false,
        log_device_object_property:
          BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
        log_interval: 0,
        logging_type: :triggered
      })

    assert true == TrendLogMultiple.property_writable?(obj, :buffer_size)
  end

  test "verify property_writable?/2 for any other works" do
    {:ok, obj} =
      TrendLogMultiple.create(1, "TEST", %{
        buffer_size: 100,
        enable: false,
        log_device_object_property:
          BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
        log_interval: 0,
        logging_type: :triggered
      })

    assert true == TrendLogMultiple.property_writable?(obj, :logging_type)
  end

  test "verify update_property/3 for buffer_size accepts valid lists" do
    {:ok, obj} =
      TrendLogMultiple.create(1, "TEST", %{
        buffer_size: 1,
        log_device_object_property:
          BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:ok, %{}} =
             TrendLogMultiple.update_property(obj, :log_buffer, [
               %LogMultipleRecord{
                 timestamp: ObjectsMacro.get_default_bacnet_datetime(),
                 log_data: {:time_change, 0.0}
               }
             ])
  end

  test "verify update_property/3 for buffer_size accepts rejects too large lists" do
    {:ok, obj} =
      TrendLogMultiple.create(1, "TEST", %{
        buffer_size: 1,
        log_device_object_property:
          BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:error, {:value_failed_property_validation, :log_buffer}} =
             TrendLogMultiple.update_property(obj, :log_buffer, [
               %LogMultipleRecord{
                 timestamp: ObjectsMacro.get_default_bacnet_datetime(),
                 log_data: {:time_change, 0.0}
               },
               %LogMultipleRecord{
                 timestamp: ObjectsMacro.get_default_bacnet_datetime(),
                 log_data: {:time_change, 1.0}
               }
             ])
  end

  test "verify update_property/3 for log_interval = 0 sets logging_type = triggered" do
    {:ok, obj} =
      TrendLogMultiple.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property:
          BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
        log_interval: 1,
        logging_type: :triggered
      })

    assert {:ok, %{log_interval: 0, logging_type: :triggered}} =
             TrendLogMultiple.update_property(obj, :log_interval, 0)
  end

  test "a nonzero Log_Interval write preserves the requested interval" do
    object = triggered_log([reference(1)])

    assert {:ok, %{log_interval: 200, logging_type: :polled}} =
             TrendLogMultiple.update_property(object, :log_interval, 200)
  end

  test "a zero Record_Count update stages the value for execution" do
    record = %LogMultipleRecord{
      timestamp: ObjectsMacro.get_default_bacnet_datetime(),
      log_data: {:time_change, 0.0}
    }

    object =
      triggered_log(
        [reference(1)],
        %{log_buffer: [record], record_count: 1, records_since_notification: 1},
        intrinsic_reporting: true
      )

    assert {:ok, %{record_count: 0, log_buffer: [^record], records_since_notification: 1}} =
             TrendLogMultiple.update_property(object, :record_count, 0)
  end

  test "verify update_property/3 for record_count > 0 fails" do
    {:ok, obj} =
      TrendLogMultiple.create(1, "TEST", %{
        buffer_size: 100,
        log_device_object_property:
          BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
        log_interval: 0,
        logging_type: :triggered
      })

    assert {:error, {:invalid_property_value, :record_count}} =
             TrendLogMultiple.update_property(obj, :record_count, 1)
  end

  test "execute holds Trigger until one ordered sample has settled" do
    parent = self()
    error = %BACnetError{class: :property, code: :read_access_denied}

    context =
      logger_context(fn %DeviceObjectRef{object_identifier: identifier} ->
        send(parent, {:lookup, identifier.instance})

        case identifier.instance do
          1 -> {:error, error}
          2 -> AnalogInput.create(2, "Temperature", %{present_value: 12.5})
        end
      end)

    object =
      triggered_log(
        [reference(1), ObjectsMacro.get_default_dev_object_ref(), reference(2)],
        %{},
        intrinsic_reporting: true
      )

    assert :ok = TrendLogMultiple.validate_execution(object, context)
    assert {:ok, %Result{object: object}} = TrendLogMultiple.execute(object, context)

    write = %{context | trigger: {:property_write, :trigger, nil, nil}}
    assert {:ok, candidate} = TrendLogMultiple.update_property(object, :trigger, true)
    assert {:ok, ^candidate} = TrendLogMultiple.prepare_write(object, candidate, write)

    assert {:ok,
            %Result{object: %{trigger: true} = pending, next_execution: :immediate, state: state}} =
             TrendLogMultiple.execute(candidate, write)

    refute_received {:lookup, _instance}

    assert {:error, :busy} =
             TrendLogMultiple.prepare_write(pending, candidate, %{write | state: state})

    continuation = %{context | trigger: :continuation, state: state}

    assert {:ok, %Result{object: current, state: %{execution_state: nil}, next_execution: nil}} =
             TrendLogMultiple.execute(pending, continuation)

    assert_received {:lookup, 1}
    assert_received {:lookup, 2}
    refute_received {:lookup, _instance}
    refute current.trigger
    assert current.record_count == 1
    assert current.total_record_count == 1
    assert current.records_since_notification == 1
    assert current.log_buffer == []
    assert {:ok, {1, backend, buffer}} = TrendLogMultiple.get_log_buffer(current, context)

    assert [
             %LogMultipleRecord{
               log_data: [
                 ^error,
                 %BACnetError{class: :property, code: :no_property_specified},
                 %Encoding{type: :real, value: 12.5}
               ]
             }
           ] = backend.read_range(buffer, 0, 1)
  end

  test "execute purges the buffer on reference changes and zero Record_Count writes" do
    context = logger_context(fn _reference -> flunk("unexpected lookup") end)
    logger = context.options[:trend_logger]
    object = triggered_log([reference(1), reference(2)], %{}, intrinsic_reporting: true)

    assert {:ok, %Result{object: object}} = TrendLogMultiple.execute(object, context)
    assert :ok = TrendLogger.trigger_log(logger, object, {:time_change, 1.0})

    references = BACnetArray.from_list([reference(2), reference(1)])
    write = %{context | trigger: {:property_write, :log_device_object_property, nil, nil}}

    assert {:ok, candidate} =
             TrendLogMultiple.update_property(object, :log_device_object_property, references)

    assert {:ok, ^candidate} = TrendLogMultiple.prepare_write(object, candidate, write)
    assert {:ok, %Result{object: current}} = TrendLogMultiple.execute(candidate, write)
    assert current.log_device_object_property == references
    assert current.record_count == 1
    assert current.total_record_count == 2
    assert current.records_since_notification == 0
    assert current.log_buffer == []
    assert {:ok, {2, backend, buffer}} = TrendLogMultiple.get_log_buffer(current, context)

    assert [%LogMultipleRecord{log_data: %LogStatus{buffer_purged: true}}] =
             backend.to_list(buffer)

    assert :ok = TrendLogger.trigger_log(logger, current, {:time_change, 2.0})
    write = %{context | trigger: {:property_write, :record_count, nil, nil}}
    assert {:ok, candidate} = TrendLogMultiple.update_property(current, :record_count, 0)
    assert {:ok, ^candidate} = TrendLogMultiple.prepare_write(current, candidate, write)
    assert {:ok, %Result{object: purged}} = TrendLogMultiple.execute(candidate, write)
    assert purged.record_count == 1
    assert purged.total_record_count == 4
    assert purged.records_since_notification == 0
    assert {:ok, {4, ^backend, buffer}} = TrendLogMultiple.get_log_buffer(purged, context)

    assert [%LogMultipleRecord{log_data: %LogStatus{buffer_purged: true}}] =
             backend.to_list(buffer)
  end

  test "preflight requires a logger and restricts Trigger to triggered mode" do
    object = triggered_log([reference(1)], %{logging_type: :polled, log_interval: 6_000})
    context = Context.new(:initialization)

    assert {:error, {:unsupported_operation, :trend_logger}} =
             TrendLogMultiple.validate_execution(object, context)

    assert {:error, :invalid_logging_type} =
             TrendLogMultiple.validate_execution(%{object | logging_type: :cov}, context)

    assert {:ok, candidate} = TrendLogMultiple.update_property(object, :trigger, true)
    write = %{context | trigger: {:application_write, :trigger, nil, nil}}

    assert {:error, :not_configured_for_triggered_logging} =
             TrendLogMultiple.prepare_write(object, candidate, write)
  end

  test "get_log_buffer returns logger and registration errors" do
    object = triggered_log([reference(1)])
    context = logger_context(fn _reference -> flunk("unexpected lookup") end)

    assert {:error, :unknown_object} = TrendLogMultiple.get_log_buffer(object, context)

    assert {:error, {:unsupported_operation, :trend_logger}} =
             TrendLogMultiple.get_log_buffer(object, %{context | options: []})

    assert {:error, {:invalid_execution_option, :trend_logger}} =
             TrendLogMultiple.get_log_buffer(object, %{context | options: [trend_logger: 123]})
  end

  test "commits a Buffer Ready transition from the logger receiver" do
    context =
      logger_context(fn _reference -> flunk("unexpected lookup") end,
        notification_receiver: self()
      )

    logger = context.options[:trend_logger]

    object =
      triggered_log([reference(1)], %{notification_threshold: 1}, intrinsic_reporting: true)

    assert {:ok, initial} = TrendLogMultiple.execute(object, context)
    assert :ok = TrendLogger.trigger_log(logger, initial.object, {:time_change, 1.0})

    assert {:ok, %{last_notify_record: 0, records_since_notification: 1}} =
             TrendLogger.get_snapshot(logger, initial.object)

    assert_received {:bacnet_trend_logger, nil, %TrendLogMultiple{},
                     %{
                       event: :intrinsic_reporting,
                       intrinsic_reporting: %{current_notification: 1}
                     }}

    context = %{context | trigger: :periodic, state: initial.state}

    assert {:ok, result} = TrendLogMultiple.execute(initial.object, context)

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

    assert {:ok, duplicate} =
             TrendLogMultiple.execute(result.object, %{context | state: result.state})

    assert EventReporting.transition(duplicate) == nil
  end

  test "linked inhibition is resolved before consuming a Buffer Ready threshold" do
    context = logger_context(fn _reference -> flunk("unexpected lookup") end)
    logger = context.options[:trend_logger]
    identifier = %ObjectIdentifier{type: :binary_value, instance: 2}

    reference = %ObjectPropertyRef{
      object_identifier: identifier,
      property_identifier: :present_value,
      property_array_index: nil
    }

    object =
      triggered_log(
        [reference(1)],
        %{notification_threshold: 1, event_algorithm_inhibit_ref: reference},
        intrinsic_reporting: true
      )

    context = %{
      context
      | read_property: fn
          %{object_identifier: ^identifier, property_identifier: :present_value} -> {:ok, true}
        end
    }

    assert {:ok, initial} = TrendLogMultiple.execute(object, context)
    assert :ok = TrendLogger.trigger_log(logger, initial.object, {:time_change, 1.0})
    periodic = %{context | trigger: :periodic, state: initial.state}
    assert {:ok, inhibited} = TrendLogMultiple.execute(initial.object, periodic)
    assert inhibited.object.event_algorithm_inhibit
    assert inhibited.object.last_notify_record == 0
    assert inhibited.object.records_since_notification == 1
    assert EventReporting.transition(inhibited) == nil

    resumed = %{
      periodic
      | state: inhibited.state,
        read_property: fn _reference -> {:ok, false} end
    }

    assert {:ok, ready} = TrendLogMultiple.execute(inhibited.object, resumed)
    refute ready.object.event_algorithm_inhibit
    assert ready.object.last_notify_record == 1
    assert %{event_type: :buffer_ready} = EventReporting.transition(ready)
  end

  test "initialization adopts a registered buffer without losing its records" do
    context = logger_context(fn _reference -> flunk("unexpected lookup") end)
    logger = context.options[:trend_logger]
    object = triggered_log([reference(1)])
    assert :ok = TrendLogger.add_object(logger, object)
    assert :ok = TrendLogger.trigger_log(logger, object, {:time_change, 1.0})

    assert {:ok, %Result{object: current, next_execution: nil}} =
             TrendLogMultiple.execute(object, context)

    assert current.record_count == 1
    assert current.total_record_count == 1
    assert {:ok, {1, backend, buffer}} = TrendLogMultiple.get_log_buffer(current, context)
    assert [%LogMultipleRecord{log_data: {:time_change, 1.0}}] = backend.read_range(buffer, 0, 1)
  end

  defp triggered_log(references, overrides \\ %{}, opts \\ []) do
    properties =
      Map.merge(
        %{
          buffer_size: 8,
          log_device_object_property: BACnetArray.from_list(references),
          log_interval: 0,
          logging_type: :triggered,
          trigger: false
        },
        overrides
      )

    {:ok, object} = TrendLogMultiple.create(1, "Triggered", properties, opts)
    object
  end

  defp reference(instance) do
    %DeviceObjectPropertyRef{
      object_identifier: %ObjectIdentifier{type: :analog_input, instance: instance},
      property_identifier: :present_value,
      property_array_index: nil,
      device_identifier: nil
    }
  end

  defp logger_context(lookup, options \\ []) do
    logger = start_supervised!({TrendLogger, Keyword.put(options, :lookup_cb, lookup)})
    Context.new(:initialization, options: [trend_logger: logger])
  end

  defp create_alignment_log(properties) do
    TrendLogMultiple.create(
      1,
      "TEST",
      Map.merge(
        %{
          buffer_size: 100,
          log_device_object_property:
            BACnetArray.from_list([ObjectsMacro.get_default_dev_object_ref()]),
          log_interval: 90_000,
          logging_type: :polled
        },
        properties
      )
    )
  end
end
