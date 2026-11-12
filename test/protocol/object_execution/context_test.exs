defmodule BACnet.Test.Protocol.ObjectExecution.ContextTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject

  use ExUnit.Case, async: false

  @moduletag :object_test

  doctest Context

  test "write metadata normalizes known IDs and retains origin, index and priority" do
    for source <- [:property_write, :application_write] do
      context = Context.new({source, 85, 1, 8})
      assert Context.write_trigger(context) == {source, :present_value, 1, 8}
      assert Context.normalize_write(context).trigger == {source, :present_value, 1, 8}
      assert Context.written_property(context, source) == :present_value
    end

    context = Context.new({:application_write, 4_194_300, nil, nil})
    assert Context.written_property(context) == 4_194_300
    assert Context.written_property(context, :property_write) == nil
    read = Context.new({:property_read, 85, nil})
    assert Context.write_trigger(read) == nil
    assert Context.normalize_write(read) == read
  end

  test "initialization starts without retained execution state" do
    assert Context.previous_state(Context.new(:initialization, state: :old)) == nil
    assert Context.previous_state(Context.new(:periodic, state: :old)) == :old
  end

  defmodule TimezoneDatabase do
    @moduledoc false
    @behaviour Calendar.TimeZoneDatabase

    @period %{utc_offset: 9000, std_offset: 0, zone_abbr: "TEST"}

    @impl true
    @spec time_zone_period_from_utc_iso_days(Calendar.iso_days(), Calendar.time_zone()) ::
            {:ok, Calendar.TimeZoneDatabase.time_zone_period()} | {:error, :time_zone_not_found}
    def time_zone_period_from_utc_iso_days(days, timezone)

    def time_zone_period_from_utc_iso_days(_days, "Test/Configured"), do: {:ok, @period}
    def time_zone_period_from_utc_iso_days(_days, _timezone), do: {:error, :time_zone_not_found}

    @impl true
    @spec time_zone_periods_from_wall_datetime(Calendar.naive_datetime(), Calendar.time_zone()) ::
            {:ok, Calendar.TimeZoneDatabase.time_zone_period()} | {:error, :time_zone_not_found}
    def time_zone_periods_from_wall_datetime(datetime, timezone)

    def time_zone_periods_from_wall_datetime(_datetime, "Test/Configured"), do: {:ok, @period}

    def time_zone_periods_from_wall_datetime(_datetime, _timezone),
      do: {:error, :time_zone_not_found}
  end

  setup do
    previous =
      for {application, key} <- [bacstack: :default_timezone, elixir: :time_zone_database],
          do: {application, key, Application.fetch_env(application, key)}

    on_exit(fn ->
      for {application, key, value} <- previous do
        case value do
          {:ok, previous_value} -> Application.put_env(application, key, previous_value)
          :error -> Application.delete_env(application, key)
        end
      end
    end)

    :ok
  end

  @context %Context{
    device_identifier: nil,
    now: ~U[2026-11-06 12:00:00Z],
    timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
    monotonic_time: -1000,
    trigger: :periodic,
    state: nil,
    lookup_object: nil,
    read_property_multiple: nil,
    read_property: nil,
    write_property: nil,
    options: []
  }
  @object_reference %DeviceObjectRef{
    object_identifier: %ObjectIdentifier{type: :calendar, instance: 1},
    device_identifier: %ObjectIdentifier{type: :device, instance: 42}
  }
  @property_reference %DeviceObjectPropertyRef{
    object_identifier: %ObjectIdentifier{type: :schedule, instance: 2},
    device_identifier: @object_reference.device_identifier,
    property_identifier: :weekly_schedule,
    property_array_index: 3
  }

  test "every execution struct field must be supplied explicitly" do
    {:ok, object} = CalendarObject.create(1, "Calendar")

    for sample <- [
          @context,
          %Result{object: object, state: nil, next_execution: nil},
          %Wakeup{wall_time: nil, monotonic_time: nil}
        ] do
      module = sample.__struct__
      fields = Map.from_struct(sample)

      for field <- Map.keys(fields) do
        assert_raise ArgumentError, fn ->
          struct!(module, Map.delete(fields, field))
        end
      end

      assert struct!(module, fields) == sample
    end
  end

  test "new samples both clocks and initializes every field" do
    before_wall = DateTime.utc_now()
    before_monotonic = System.monotonic_time(:millisecond)

    Application.delete_env(:bacstack, :default_timezone)
    Calendar.put_time_zone_database(Calendar.UTCOnlyTimeZoneDatabase)

    context = Context.new(:timer)

    after_monotonic = System.monotonic_time(:millisecond)
    after_wall = DateTime.utc_now()

    assert DateTime.compare(context.now, before_wall) in [:eq, :gt]
    assert DateTime.compare(context.now, after_wall) in [:eq, :lt]
    assert context.monotonic_time >= before_monotonic
    assert context.monotonic_time <= after_monotonic

    assert context == %{
             @context
             | now: context.now,
               monotonic_time: context.monotonic_time,
               trigger: :timer
           }
  end

  test "new samples now in the configured timezone through Elixir's configured database" do
    Application.put_env(:bacstack, :default_timezone, "Test/Configured")
    Calendar.put_time_zone_database(TimezoneDatabase)
    before_wall = DateTime.utc_now()

    context = Context.new(:initialization)

    assert context.now.time_zone == "Test/Configured"
    assert context.now.utc_offset == 9000
    assert context.timezone_database == TimezoneDatabase
    assert DateTime.compare(context.now, before_wall) in [:eq, :gt]
    assert DateTime.compare(context.now, DateTime.utc_now()) in [:eq, :lt]
  end

  test "new preserves every supplied field and bypasses timezone lookup for explicit now" do
    Application.put_env(:bacstack, :default_timezone, "Unknown/Timezone")
    Calendar.put_time_zone_database(Calendar.UTCOnlyTimeZoneDatabase)
    lookup = fn _reference -> {:error, :unknown_object} end
    read = fn _reference -> {:ok, 42} end
    read_multiple = fn _reference, _properties -> {:ok, %{present_value: 42}} end
    write = fn _reference, _value, _priority -> :ok end

    fields = [
      now: @context.now,
      monotonic_time: @context.monotonic_time,
      timezone_database: TimezoneDatabase,
      device_identifier: @object_reference.device_identifier,
      state: %{count: 3},
      lookup_object: lookup,
      read_property: read,
      read_property_multiple: read_multiple,
      write_property: write,
      options: [mode: :automatic]
    ]

    assert Context.new(:timer, fields) == struct!(@context, [trigger: :timer] ++ fields)
  end

  test "new samples only missing clocks" do
    Application.put_env(:bacstack, :default_timezone, "Unknown/Timezone")
    before_monotonic = System.monotonic_time(:millisecond)
    context = Context.new(:periodic, now: @context.now)
    assert context.now == @context.now
    assert context.monotonic_time >= before_monotonic
    assert context.monotonic_time <= System.monotonic_time(:millisecond)

    Application.put_env(:bacstack, :default_timezone, "Test/Configured")
    Calendar.put_time_zone_database(TimezoneDatabase)
    context = Context.new(:timer, monotonic_time: -1234)
    assert context.now.time_zone == "Test/Configured"
    assert context.monotonic_time == -1234
  end

  test "new allows a per-context database override without changing Elixir configuration" do
    Application.put_env(:bacstack, :default_timezone, "Test/Configured")
    Calendar.put_time_zone_database(Calendar.UTCOnlyTimeZoneDatabase)

    context = Context.new(:timer, timezone_database: TimezoneDatabase)

    assert context.now.time_zone == "Test/Configured"
    assert context.timezone_database == TimezoneDatabase
    assert Calendar.get_time_zone_database() == Calendar.UTCOnlyTimeZoneDatabase
  end

  test "new reports an unsupported configured timezone when now needs to be sampled" do
    Application.put_env(:bacstack, :default_timezone, "Test/Configured")
    Calendar.put_time_zone_database(Calendar.UTCOnlyTimeZoneDatabase)

    assert_raise ArgumentError, fn -> Context.new(:initialization) end
  end

  test "new accepts every trigger shape and preserves supplied state" do
    reference = %DeviceObjectRef{
      device_identifier: nil,
      object_identifier: @object_reference.object_identifier
    }

    for trigger <- [
          :periodic,
          :initialization,
          :clock_change,
          :timer,
          :continuation,
          {:property_read, :present_value, nil},
          {:property_read, 85, 0},
          {:property_write, :present_value, nil, nil},
          {:property_write, 85, 0, 16},
          {:object_changed, reference}
        ] do
      context = Context.new(trigger, now: @context.now, state: :retained)
      assert context.trigger == trigger
      assert context.state == :retained
    end
  end

  test "new rejects malformed triggers and constructor fields" do
    for trigger <- [
          nil,
          :unknown,
          {:property_read, nil, nil},
          {:property_read, 85, -1},
          {:property_write, 85, nil, 0},
          {:object_changed, :invalid}
        ] do
      assert_raise ArgumentError, fn -> Context.new(trigger, now: @context.now) end
    end

    for fields <- [
          [:not_a_keyword],
          [unknown: 1],
          [trigger: :periodic],
          [now: nil],
          [monotonic_time: 1.0],
          [timezone_database: nil],
          [lookup_object: fn -> :ok end],
          [read_property: fn -> :ok end],
          [write_property: fn _reference -> :ok end],
          [options: %{}],
          [options: [:invalid]],
          [device_identifier: %ObjectIdentifier{type: :calendar, instance: 1}],
          [device_identifier: %ObjectIdentifier{type: :device, instance: -1}]
        ] do
      assert_raise ArgumentError, fn -> Context.new(:timer, fields) end
    end
  end

  test "lookup preserves local and remote object references and propagates host errors" do
    assert {:ok, calendar} = CalendarObject.create(1, "Calendar")

    for reference <- [@object_reference, %{@object_reference | device_identifier: nil}] do
      context = %{
        @context
        | lookup_object: fn actual_reference ->
            assert actual_reference == reference
            {:ok, calendar}
          end
      }

      assert {:ok, ^calendar} = Context.lookup_object(context, reference)
    end

    context = %{@context | lookup_object: fn _reference -> {:error, :unknown_object} end}
    assert {:error, :unknown_object} = Context.lookup_object(context, @object_reference)
  end

  test "read forwards the complete property reference and the host's value or error" do
    for response <- [{:ok, [1, 2, 3]}, {:ok, nil}, {:error, :unknown_property}] do
      context = %{
        @context
        | read_property: fn reference ->
            assert reference == @property_reference
            response
          end
      }

      assert Context.read_property(context, @property_reference) == response
    end
  end

  test "write preserves array indices, NULL values and every allowed priority" do
    for priority <- [nil | Enum.to_list(1..16)], value <- [nil, 42.5] do
      context = %{
        @context
        | write_property: fn reference, actual_value, actual_priority ->
            assert reference == @property_reference
            assert actual_value == value
            assert actual_priority == priority
            :ok
          end
      }

      assert :ok = Context.write_property(context, @property_reference, value, priority)
    end
  end

  test "an omitted write priority is nil and write failures propagate" do
    context = %{
      @context
      | write_property: fn reference, value, priority ->
          assert reference == @property_reference
          assert value == false
          assert priority == nil
          {:error, :write_access_denied}
        end
    }

    assert {:error, :write_access_denied} =
             Context.write_property(context, @property_reference, false)
  end

  test "write forwards encodings and encoding lists unchanged" do
    null = BACnet.Protocol.ApplicationTags.Encoding.create!({:null, nil})

    values = [
      null,
      [BACnet.Protocol.ApplicationTags.Encoding.create!({:unsigned_integer, 7}), null]
    ]

    for value <- values do
      context = %{
        @context
        | write_property: fn reference, actual_value, priority ->
            assert reference == @property_reference
            assert actual_value === value
            assert priority == 8
            :ok
          end
      }

      assert :ok = Context.write_property(context, @property_reference, value, 8)
    end
  end

  test "multiple-property reads use a separate callback and preserve native-value maps" do
    values = %{
      {:priority_array, 0} => 16,
      present_value: 42,
      description: {:error, :read_access_denied}
    }

    properties = [:all, :required, :optional]

    callback = fn reference, requested ->
      assert reference == @object_reference
      assert requested == properties
      {:ok, values}
    end

    context =
      Context.new(:periodic,
        now: @context.now,
        monotonic_time: -1000,
        read_property_multiple: callback
      )

    assert {:ok, ^values} = Context.read_property_multiple(context, @object_reference, properties)
    assert :ok = Context.require_operations(context, [:read_property_multiple])

    assert {:error, {:unsupported_operation, :read_property}} =
             Context.require_operations(context, [:read_property])

    assert {:error, {:unsupported_operation, :read_property_multiple}} =
             Context.read_property_multiple(@context, @object_reference, properties)

    assert {:error, {:unsupported_operation, :read_property_multiple}} =
             Context.require_operations(@context, [:read_property_multiple])

    assert_raise ArgumentError, fn ->
      Context.new(:periodic, read_property_multiple: fn _reference -> :ok end)
    end
  end

  test "multiple-property callback errors and exceptions are forwarded" do
    context = %{
      @context
      | read_property_multiple: fn _reference, _properties -> {:error, :timeout} end
    }

    assert {:error, :timeout} = Context.read_property_multiple(context, @object_reference, [:all])

    context = %{
      context
      | read_property_multiple: fn _reference, _properties -> raise "host bug" end
    }

    assert_raise RuntimeError, "host bug", fn ->
      Context.read_property_multiple(context, @object_reference, [:all])
    end
  end

  test "missing callbacks report unsupported operations" do
    assert {:error, {:unsupported_operation, :lookup_object}} =
             Context.lookup_object(@context, @object_reference)

    assert {:error, {:unsupported_operation, :read_property}} =
             Context.read_property(@context, @property_reference)

    assert {:error, {:unsupported_operation, :write_property}} =
             Context.write_property(@context, @property_reference, true)
  end

  test "operation preflight checks arities and missing operations without invoking callbacks" do
    context = %{
      @context
      | lookup_object: fn _ref -> flunk("preflight invoked lookup") end,
        read_property: fn _ref -> flunk("preflight invoked read") end,
        write_property: fn _ref, _value, _priority -> flunk("preflight invoked write") end
    }

    assert :ok = Context.require_operations(@context, [])

    assert :ok =
             Context.require_operations(context, [:lookup_object, :read_property, :write_property])

    assert {:error, {:unsupported_operation, :lookup_object}} =
             Context.require_operations(@context, [:lookup_object, :read_property])

    assert {:error, {:unsupported_operation, :write_property}} =
             Context.require_operations(%{context | write_property: fn _ref -> :ok end}, [
               :write_property
             ])

    assert_raise FunctionClauseError, fn ->
      Context.require_operations(context, [:unknown_operation])
    end
  end

  test "invalid priorities never reach the host callback" do
    context = %{
      @context
      | write_property: fn _ref, _value, _priority ->
          flunk("invalid priority reached the host")
        end
    }

    for priority <- [0, 17, 1.0, :invalid] do
      assert_raise FunctionClauseError, fn ->
        Context.write_property(context, @property_reference, true, priority)
      end
    end
  end

  test "callback exceptions remain visible to the caller" do
    context = %{@context | read_property: fn _reference -> raise "host bug" end}

    assert_raise RuntimeError, "host bug", fn ->
      Context.read_property(context, @property_reference)
    end
  end

  test "application writes accept the same property, index and priority shapes as BACnet writes" do
    for property <- [:present_value, 85], index <- [nil, 0, 3], priority <- [nil, 1, 6, 16] do
      trigger = {:application_write, property, index, priority}
      assert Context.new(trigger).trigger == trigger
    end

    for trigger <- [
          {:application_write, nil, nil, nil},
          {:application_write, :present_value, -1, nil},
          {:application_write, :present_value, nil, 17}
        ] do
      assert_raise ArgumentError, fn -> Context.new(trigger) end
    end
  end
end
