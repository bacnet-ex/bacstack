defmodule BACnet.Test.Protocol.ObjectTypes.EventLogTest do
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.EventLogRecord
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.EventLog
  alias BACnet.Protocol.Services.ConfirmedEventNotification
  alias BACnet.Stack.TrendLogger

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_event_log

  doctest EventLog

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 adds Log_Buffer for remote objects" do
    assert {:ok, %EventLog{log_buffer: []} = remote} =
             EventLog.create(
               1,
               "TEST",
               %{
                 buffer_size: 100,
                 enable: false,
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

    assert :ok = EventLog.validate_execution(remote, Context.new(:initialization))

    write = Context.new({:property_write, :enable, nil, nil})

    assert {:error, :operation_not_available_for_remote_objects} =
             EventLog.prepare_write(remote, remote, write)

    assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil}} =
             EventLog.execute(remote, context)

    assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil}} =
             Lifecycle.execute(remote, context)
  end

  test "accepts registered logger names and rejects invalid logger options during preflight" do
    {:ok, object} = EventLog.create(1, "History", %{buffer_size: 8})

    for name <- [
          __MODULE__,
          {__MODULE__, node()},
          {:global, {__MODULE__, :history}},
          {:via, Registry, {__MODULE__, :history}}
        ] do
      assert :ok =
               EventLog.validate_execution(
                 object,
                 Context.new(:initialization, options: [trend_logger: name])
               )
    end

    assert {:error, {:invalid_execution_option, :trend_logger}} =
             EventLog.validate_execution(
               object,
               Context.new(:initialization, options: [trend_logger: "history"])
             )
  end

  test "initialization registers once and reads project the counters without copying records" do
    {logger, context} = logger_context()

    assert {:ok, object} =
             EventLog.create(1, "Event history", %{buffer_size: 8, notification_threshold: 2},
               intrinsic_reporting: true
             )

    assert {:error, {:unsupported_operation, :trend_logger}} =
             Lifecycle.execute(object, Context.new(:initialization))

    read = %{context | trigger: {:property_read, :record_count, nil}}
    assert {:error, :unknown_object} = Lifecycle.prepare_read(object, read)

    assert {:ok, %Result{object: ^object, next_execution: nil}} =
             Lifecycle.execute(object, context)

    event = event_notification()
    assert :ok = TrendLogger.trigger_log(logger, object, event)
    assert {:ok, %Result{object: current}} = Lifecycle.prepare_read(object, read)
    assert current.record_count == 1
    assert current.total_record_count == 1
    assert current.records_since_notification == 1
    assert current.last_notify_record == 0
    assert EventLog.get_property(current, :log_buffer) == {:ok, []}

    assert {:ok, %{buffer: {backend, buffer}, total_record_count: 1}} =
             TrendLogger.get_snapshot(logger, current)

    assert [%EventLogRecord{log_datum: ^event}] = backend.read_range(buffer, 0, 1)

    assert :ok = TrendLogger.trigger_log(logger, current, event)

    assert {:ok, %Result{object: current, next_execution: nil}} =
             EventLog.execute(current, context)

    assert current.record_count == 2
    assert current.total_record_count == 2
    assert current.records_since_notification == 0
    assert current.last_notify_record == 2
    assert current.log_buffer == []
  end

  test "full-buffer writes are checked against live state and zero purges the backend" do
    {logger, context} = logger_context()

    {:ok, object} = EventLog.create(1, "Event history", %{buffer_size: 2, stop_when_full: true})
    assert {:ok, %Result{object: object}} = Lifecycle.execute(object, context)

    enable_write = %{context | trigger: {:property_write, :enable, nil, nil}}
    assert {:ok, prepared} = Lifecycle.prepare_write(object, object, enable_write)

    # A notification can fill the buffer between preparation and execution.
    assert :ok = TrendLogger.trigger_log(logger, object, event_notification())
    assert {:error, :log_buffer_full} = Lifecycle.execute(prepared, enable_write)

    assert {:ok, %Result{object: stopped}} =
             Lifecycle.execute(object, %{context | trigger: :periodic})

    refute stopped.enable
    assert stopped.total_record_count == 2
    assert {:ok, candidate} = EventLog.update_property(stopped, :enable, true)
    assert {:error, :log_buffer_full} = Lifecycle.prepare_write(stopped, candidate, enable_write)

    assert {:ok, %Result{object: stopped}} = write(stopped, context, :stop_when_full, true)
    refute stopped.enable
    assert stopped.record_count == 2
    assert stopped.total_record_count == 3
    assert {:ok, %{buffer: {backend, buffer}}} = TrendLogger.get_snapshot(logger, stopped)

    assert Enum.all?(
             backend.to_list(buffer),
             &match?(%EventLogRecord{log_datum: %LogStatus{log_disabled: true}}, &1)
           )

    assert {:ok, candidate} = EventLog.update_property(stopped, :record_count, 1)
    count_write = %{context | trigger: {:property_write, :record_count, nil, nil}}

    assert {:error, {:invalid_property_value, :record_count}} =
             Lifecycle.prepare_write(stopped, candidate, count_write)

    assert {:error, {:write_access_denied, :log_buffer}} =
             EventLog.prepare_write(stopped, stopped, %{
               context
               | trigger: {:property_write, :log_buffer, nil, nil}
             })

    refute EventLog.property_writable?(stopped, :log_buffer)

    assert {:ok, %Result{object: purged}} = write(stopped, context, :record_count, 0)
    assert purged.record_count == 1
    assert purged.total_record_count == 4
    assert purged.log_buffer == []
    assert {:ok, %{buffer: {backend, buffer}}} = TrendLogger.get_snapshot(logger, purged)

    assert [%EventLogRecord{log_datum: %LogStatus{buffer_purged: true, log_disabled: true}}] =
             backend.to_list(buffer)
  end

  test "a numeric Enable write updates the logger and the returned object" do
    {logger, context} = logger_context()
    {:ok, object} = EventLog.create(1, "Audit", %{buffer_size: 8})
    assert {:ok, initial} = Lifecycle.execute(object, context)
    assert {:ok, candidate} = EventLog.update_property(initial.object, :enable, false)
    context = %{context | trigger: {:property_write, 133, nil, nil}, state: initial.state}
    assert {:ok, prepared} = EventLog.prepare_write(initial.object, candidate, context)
    assert {:ok, %{object: %{enable: false}}} = EventLog.execute(prepared, context)
    assert {:ok, %{enable: false}} = TrendLogger.get_snapshot(logger, initial.object)
  end

  test "a window write updates collection without overwriting the logger's Enable state" do
    {logger, context} = logger_context()
    open = ObjectsMacro.get_default_bacnet_datetime()
    past = BACnetDateTime.from_datetime(~U[2000-01-01 00:00:00Z])

    {:ok, object} =
      EventLog.create(1, "Event history", %{buffer_size: 4, start_time: open, stop_time: open})

    assert {:ok, %Result{object: object}} = Lifecycle.execute(object, context)

    assert {:ok, %Result{object: closed}} = write(object, context, :stop_time, past)
    assert closed.enable
    assert closed.record_count == 1
    assert :ok = TrendLogger.trigger_log(logger, closed, event_notification())
    assert {:ok, %{collecting: false, record_count: 1}} = TrendLogger.get_snapshot(logger, closed)

    assert {:ok, %Result{object: reopened}} = write(closed, context, :stop_time, open)
    assert reopened.enable
    assert :ok = TrendLogger.trigger_log(logger, reopened, event_notification())

    assert {:ok, %{collecting: true, record_count: 3}} =
             TrendLogger.get_snapshot(logger, reopened)

    assert :ok = TrendLogger.change_log_state(logger, reopened, :disable)
    assert {:ok, %Result{object: disabled}} = write(reopened, context, :stop_time, past)
    refute disabled.enable
    assert {:ok, %{collecting: false}} = TrendLogger.get_snapshot(logger, disabled)
  end

  test "counts records while inhibited and consumes the threshold when reporting resumes" do
    {logger, context} = logger_context()

    assert {:ok, object} =
             EventLog.create(
               1,
               "History",
               %{buffer_size: 8, notification_threshold: 1, event_algorithm_inhibit: true},
               intrinsic_reporting: true
             )

    assert {:ok, initial} = EventLog.execute(object, context)
    assert :ok = TrendLogger.trigger_log(logger, initial.object, event_notification())

    periodic = %{context | trigger: :periodic, state: initial.state}
    assert {:ok, inhibited} = EventLog.execute(initial.object, periodic)
    assert inhibited.object.records_since_notification == 1
    assert inhibited.object.last_notify_record == 0
    assert EventReporting.transition(inhibited) == nil

    assert {:ok, candidate} =
             EventLog.update_property(inhibited.object, :event_algorithm_inhibit, false)

    write = %{
      periodic
      | trigger: {:property_write, :event_algorithm_inhibit, nil, nil},
        state: inhibited.state
    }

    assert {:ok, resumed} = EventLog.execute(candidate, write)
    assert resumed.object.records_since_notification == 0
    assert resumed.object.last_notify_record == 1
    assert %{event_type: :buffer_ready, enabled: false} = EventReporting.transition(resumed)
  end

  test "commits a Buffer Ready transition from the logger receiver" do
    {logger, context} = logger_context(notification_receiver: self())

    assert {:ok, object} =
             EventLog.create(1, "History", %{buffer_size: 8, notification_threshold: 1},
               intrinsic_reporting: true
             )

    assert {:ok, initial} = EventLog.execute(object, context)
    assert :ok = TrendLogger.trigger_log(logger, initial.object, event_notification())

    assert {:ok, %{last_notify_record: 0, records_since_notification: 1}} =
             TrendLogger.get_snapshot(logger, initial.object)

    assert_received {:bacnet_trend_logger, nil, %EventLog{},
                     %{
                       event: :intrinsic_reporting,
                       intrinsic_reporting: %{current_notification: 1}
                     }}

    context = %{context | trigger: :periodic, state: initial.state}

    assert {:ok, result} = EventLog.execute(initial.object, context)

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

    assert {:ok, duplicate} = EventLog.execute(result.object, %{context | state: result.state})
    assert EventReporting.transition(duplicate) == nil
  end

  defp logger_context(options \\ []) do
    logger =
      start_supervised!(
        {TrendLogger,
         Keyword.put(options, :lookup_cb, fn _reference ->
           {:error, %BACnetError{class: :object, code: :unknown_object}}
         end)}
      )

    {logger, Context.new(:initialization, options: [trend_logger: logger])}
  end

  defp write(object, context, property, value) do
    context = %{context | trigger: {:property_write, property, nil, nil}}
    assert {:ok, candidate} = EventLog.update_property(object, property, value)
    assert {:ok, prepared} = Lifecycle.prepare_write(object, candidate, context)
    Lifecycle.execute(prepared, context)
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
