defmodule BACnet.Test.Protocol.ObjectTypes.DeviceTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.Device
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.RecipientAddress
  alias BACnet.Protocol.Services.TimeSynchronization
  alias BACnet.Protocol.Services.UnconfirmedCovNotification
  alias BACnet.Protocol.Services.UtcTimeSynchronization

  use ExUnit.Case, async: true

  doctest Device

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_device

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "slave proxy properties are available only before revision 19 on local devices" do
    slave_properties = %{
      slave_proxy_enable: BACnetArray.new(),
      auto_slave_discovery: BACnetArray.new(),
      slave_address_binding: [],
      manual_slave_address_binding: []
    }

    properties = %{
      vendor_identifier: 999,
      segmentation_supported: :no_segmentation
    }

    for name <- Map.keys(slave_properties) do
      assert Device.get_annotation(name)[:forbidden_when] == {:opts, :revision, :>=, 19}
    end

    for revision <- [:revision_14, 18] do
      assert {:ok, device} =
               Device.create(1, "device", Map.merge(properties, slave_properties),
                 revision: revision
               )

      for {name, value} <- slave_properties do
        assert Device.get_property(device, name) == {:ok, value}
      end
    end

    for revision <- [19, 22] do
      assert {:ok, device} = Device.create(1, "device", properties, revision: revision)

      for name <- Map.keys(slave_properties) do
        refute name in device._metadata.properties_list
      end

      assert {:error, {:property_not_allowed, name}} =
               Device.create(1, "device", Map.merge(properties, slave_properties),
                 revision: revision
               )

      assert Map.has_key?(slave_properties, name)
    end

    assert {:ok, local} =
             Device.create(1, "local", Map.merge(properties, slave_properties), revision: 18)

    remote_properties =
      local
      |> Map.from_struct()
      |> Map.take(local._metadata.properties_list)
      |> Map.drop([:object_instance, :object_name])

    assert {:ok, remote} =
             Device.create(2, "remote", remote_properties, revision: 19, remote_object: 42)

    for {name, value} <- slave_properties do
      assert Device.get_property(remote, name) == {:ok, value}
    end
  end

  test "vendor IDs resolve to names while explicit vendor names are preserved" do
    vendors = Device.get_vendor_ids()
    assert is_map(vendors)
    {vendor_id, vendor_name} = Enum.min_by(vendors, &elem(&1, 0))
    assert is_binary(vendor_name)

    assert {:ok, %Device{vendor_name: ^vendor_name}} =
             Device.create(1, "device", %{
               vendor_identifier: vendor_id,
               segmentation_supported: :no_segmentation
             })

    assert {:ok, %Device{vendor_name: "custom"}} =
             Device.create(1, "device", %{
               vendor_identifier: vendor_id,
               vendor_name: "custom",
               segmentation_supported: :no_segmentation
             })
  end

  test "unvalidated remote vendor identifiers fall back to an empty vendor name" do
    {:ok, local} =
      Device.create(1, "local", %{
        vendor_identifier: 1,
        segmentation_supported: :no_segmentation,
        description: "old"
      })

    properties =
      local
      |> Map.from_struct()
      |> Map.take(Device.get_required_properties() ++ [:description])
      |> Map.drop([:object_instance, :object_name])
      |> Map.put(:vendor_identifier, :invalid)
      |> Map.put(:vendor_name, "")

    assert {:ok, remote} =
             Device.create(2, "remote", properties,
               remote_object: 42,
               skip_property_validation_remote_object: true
             )

    assert {:ok, %Device{vendor_name: "", description: "new"}} =
             Device.update_property(remote, :description, "new")
  end

  test "Property local_date has on_read_function and works" do
    annotations = Device.get_annotation(:local_date)
    assert Keyword.keyword?(annotations)

    fun = Keyword.fetch!(annotations, :on_read_function)
    assert is_function(fun, 1)

    assert {:ok, %Device{} = dev} =
             Device.create(1, "Dev", %{
               local_date: BACnetDate.from_date(Date.add(Date.utc_today(), -1)),
               segmentation_supported: :no_segmentation,
               vendor_identifier: 999
             })

    assert {:ok, %Device{} = dev2} = fun.(dev)

    # Dev2 date must be newer
    assert BACnetDate.compare(dev.local_date, dev2.local_date) == :lt
  end

  test "Property local_time has on_read_function and works" do
    annotations = Device.get_annotation(:local_time)
    assert Keyword.keyword?(annotations)

    fun = Keyword.fetch!(annotations, :on_read_function)
    assert is_function(fun, 1)

    assert {:ok, %Device{} = dev} =
             Device.create(1, "Dev", %{
               local_time: BACnetTime.from_time(Time.add(Time.utc_now(), -1)),
               segmentation_supported: :no_segmentation,
               vendor_identifier: 999
             })

    assert {:ok, %Device{} = dev2} = fun.(dev)

    # Dev2 time must be newer
    assert BACnetTime.compare(dev.local_time, dev2.local_time) == :lt
  end

  describe "lifecycle" do
    test "each clock property read samples only the requested property" do
      stored = %{
        local_date: BACnetDate.from_date(~D[2026-05-31]),
        local_time: BACnetTime.from_time(~T[23:59:59]),
        utc_offset: 0,
        daylight_savings_status: false
      }

      device = device(stored)
      now = %{~U[2026-06-01 00:30:17.540000Z] | utc_offset: 3600, std_offset: 3600}

      sampled = %{
        local_date: BACnetDate.from_date(~D[2026-06-01]),
        local_time: BACnetTime.from_time(~T[00:30:17.54]),
        utc_offset: -60,
        daylight_savings_status: true
      }

      for {property, value} <- sampled do
        context = Context.new({:property_read, property, nil}, now: now)
        assert :ok = Device.validate_execution(device, context)

        assert {:ok, %Result{object: refreshed, next_execution: nil}} =
                 Device.execute(device, context)

        for {key, expected} <- Map.put(stored, property, value) do
          assert Device.get_property(refreshed, key) == {:ok, expected}
        end
      end
    end

    test "periodic execution and unrelated reads leave stored clock properties alone" do
      device =
        device(%{
          local_date: BACnetDate.from_date(~D[2026-05-31]),
          local_time: BACnetTime.from_time(~T[23:59:59]),
          utc_offset: 0,
          daylight_savings_status: false
        })

      now = %{~U[2026-06-01 00:30:00Z] | utc_offset: 3600, std_offset: 3600}

      assert {:ok, %Result{object: periodic}} =
               Device.execute(device, Context.new(:periodic, now: now))

      assert {:ok, %Result{object: read}} =
               Lifecycle.prepare_read(
                 device,
                 Context.new({:property_read, :system_status, nil}, now: now)
               )

      for result <- [periodic, read] do
        assert result.local_date == device.local_date
        assert result.local_time == device.local_time
        assert result.utc_offset == device.utc_offset
        assert result.daylight_savings_status == device.daylight_savings_status
      end
    end

    test "a UTC offset that cannot be expressed in whole minutes only fails an offset read" do
      device = device(%{utc_offset: 0})
      now = %{~U[2026-06-01 00:30:00Z] | utc_offset: 3601}
      periodic = Context.new(:periodic, now: now)
      read = Context.new({:property_read, :utc_offset, nil}, now: now)

      assert :ok = Device.validate_execution(device, periodic)
      assert {:ok, %Result{object: ^device}} = Device.execute(device, periodic)

      assert Device.validate_execution(device, read) ==
               {:error, {:invalid_device_clock, :utc_offset}}

      assert Device.execute(device, read) == {:error, {:invalid_device_clock, :utc_offset}}
    end

    test "execution leaves unselected properties and remote snapshots alone" do
      {:ok, without_date} = Device.remove_property(device(), :local_date)
      {:ok, local} = Device.remove_property(without_date, :local_time)
      now = ~U[2026-06-01 00:30:00Z]
      options = [device_event: {:database_change, :object_created}]
      context = Context.new(:periodic, now: now, options: options)

      assert {:ok, %Result{object: changed}} = Device.execute(local, context)
      assert changed._metadata.properties_list == local._metadata.properties_list
      assert changed.local_time == local.local_time
      assert changed.local_date == local.local_date

      properties =
        local
        |> Map.from_struct()
        |> Map.take(local._metadata.properties_list)
        |> Map.drop([:object_instance, :object_name])

      remote = device(properties, remote_object: 42)
      context = %{context | state: :retained}

      assert :ok = Device.validate_execution(remote, context)

      assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil} = result} =
               Device.execute(remote, context)

      assert Device.time_synchronization_requests(result) == []

      assert Device.restart_notification(remote) ==
               {:error, :operation_not_available_for_remote_objects}
    end

    test "database changes and restore advance the revision, temporary files and ordinary writes do not" do
      now = ~U[2026-06-01 00:30:00Z]

      stamp = %BACnetTimestamp{
        type: :sequence_number,
        sequence_number: 0,
        time: nil,
        datetime: nil
      }

      device =
        device(
          %{
            database_revision: 9,
            configuration_files: BACnetArray.new(),
            last_restore_time: stamp,
            backup_failure_timeout: 30,
            backup_preparation_time: 0,
            restore_preparation_time: 0,
            restore_completion_time: 0,
            backup_and_restore_state: :idle
          },
          supports_backup_restore: true
        )

      changes = [
        :object_created,
        :object_deleted,
        :object_name_changed,
        :object_identifier_changed
      ]

      device =
        Enum.reduce(changes, device, fn change, previous ->
          {:ok, %Result{object: updated}} =
            execute_event(previous, now, {:database_change, change})

          assert updated.database_revision == previous.database_revision + 1
          updated
        end)

      for change <- [:temporary_configuration_file_created, :temporary_configuration_file_deleted] do
        assert {:ok, %Result{object: ^device}} =
                 execute_event(device, now, {:database_change, change})
      end

      assert {:ok, updated} = Device.update_property(device, :system_status, :non_operational)
      assert updated.database_revision == 13

      assert {:ok, %Result{object: restored}} = execute_event(updated, now, :restore_completed)
      assert restored.database_revision == 14
      assert restored.last_restore_time == datetime_stamp(now)
    end

    test "rejects invalid event reasons and validates date range when a date is sampled" do
      device = device(%{local_date: BACnetDate.from_date(~D[2026-06-01])})

      context =
        Context.new(:periodic,
          now: ~U[2026-06-01 00:00:00Z],
          options: [device_event: {:restart_completed, :unrecognized}]
        )

      assert Device.validate_execution(device, context) == {:error, :invalid_device_event}
      assert Device.execute(device, context) == {:error, :invalid_device_event}

      now = ~U[2155-01-01 00:00:00Z]
      periodic = Context.new(:periodic, now: now)
      assert :ok = Device.validate_execution(device, periodic)
      assert {:ok, %Result{object: sampled}} = Device.execute(device, periodic)
      assert sampled.local_date == device.local_date

      context = Context.new({:property_read, :local_date, nil}, now: now)

      assert Device.validate_execution(device, context) ==
               {:error, {:invalid_device_clock, :local_date}}

      assert Device.execute(device, context) == {:error, {:invalid_device_clock, :local_date}}
    end
  end

  describe "restart_notification/1" do
    test "uses the current status, recorded restart time and reason and defaults to local broadcast" do
      now = ~U[2026-06-01 00:30:00Z]
      device = device(%{system_status: :non_operational}, supports_restart: true)
      identifier = Device.get_object_identifier(device)

      assert {:ok, %Result{object: restarted}} =
               execute_event(device, now, {:restart_completed, :warmstart})

      assert restarted.database_revision == device.database_revision
      assert restarted.last_restart_reason == :warmstart
      assert restarted.time_of_device_restart == datetime_stamp(now)

      assert {:ok, {[recipient], %UnconfirmedCovNotification{} = notification}} =
               Device.restart_notification(restarted)

      assert recipient == %Recipient{
               type: :address,
               device: nil,
               address: %RecipientAddress{network: 0, address: :broadcast}
             }

      assert notification.process_identifier == 0
      assert notification.time_remaining == 0
      assert notification.initiating_device == identifier
      assert notification.monitored_object == identifier

      assert {:ok, apdu} = UnconfirmedCovNotification.to_apdu(notification, [])
      assert {:ok, encoded} = APDU.UnconfirmedServiceRequest.encode(apdu)
      assert {:ok, decoded_apdu} = APDU.decode(IO.iodata_to_binary(encoded))
      assert {:ok, decoded} = UnconfirmedCovNotification.from_apdu(decoded_apdu)

      assert Enum.map(decoded.property_values, & &1.property_identifier) ==
               [:system_status, :time_of_device_restart, :last_restart_reason]

      for property <- decoded.property_values do
        assert property.property_array_index == nil
        assert property.priority == nil

        assert ObjectsUtility.cast_property_to_value(
                 identifier,
                 property.property_identifier,
                 property.property_value
               ) == Device.get_property(restarted, property.property_identifier)
      end
    end

    test "restart timestamps can be recorded on devices that do not send notifications" do
      now = ~U[2026-06-01 00:30:00Z]
      device = device(%{last_restart_reason: :unknown})

      assert {:ok, %Result{object: restarted}} =
               execute_event(device, now, {:restart_completed, :hardware_watchdog})

      assert restarted.last_restart_reason == :hardware_watchdog
      assert restarted.time_of_device_restart == datetime_stamp(now)
      assert Device.restart_notification(restarted) == {:ok, nil}
    end

    test "an empty or absent recipient list suppresses the notification" do
      assert Device.restart_notification(device()) == {:ok, nil}

      assert Device.restart_notification(
               device(%{restart_notification_recipients: []},
                 supports_restart: true
               )
             ) == {:ok, nil}
    end
  end

  defmodule TimezoneDatabase do
    @moduledoc false
    @behaviour Calendar.TimeZoneDatabase

    @standard %{utc_offset: 3600, std_offset: 0, zone_abbr: "STD"}
    @summer %{utc_offset: 3600, std_offset: 3600, zone_abbr: "DST"}

    @impl true
    @spec time_zone_period_from_utc_iso_days(Calendar.iso_days(), Calendar.time_zone()) ::
            {:error, :time_zone_not_found}
    def time_zone_period_from_utc_iso_days(_days, _timezone), do: {:error, :time_zone_not_found}

    @impl true
    @spec time_zone_periods_from_wall_datetime(Calendar.naive_datetime(), Calendar.time_zone()) ::
            {:ok, Calendar.TimeZoneDatabase.time_zone_period()}
            | {:gap, {Calendar.TimeZoneDatabase.time_zone_period(), NaiveDateTime.t()},
               {Calendar.TimeZoneDatabase.time_zone_period(), NaiveDateTime.t()}}
    def time_zone_periods_from_wall_datetime(datetime, timezone)

    def time_zone_periods_from_wall_datetime(%NaiveDateTime{hour: hour}, "Test/Gap")
        when hour < 2,
        do: {:ok, @standard}

    def time_zone_periods_from_wall_datetime(%NaiveDateTime{hour: 2}, "Test/Gap"),
      do: {:gap, {@standard, ~N[2026-03-29 02:00:00]}, {@summer, ~N[2026-03-29 03:00:00]}}

    def time_zone_periods_from_wall_datetime(_datetime, "Test/Gap"), do: {:ok, @summer}
  end

  describe "periodic time synchronization" do
    test "relative scheduling sends local and UTC requests once per step and uses monotonic time" do
      local = device_recipient(42)
      utc = device_recipient(43)

      device =
        device(%{
          time_synchronization_interval: 5,
          time_synchronization_recipients: [local],
          utc_time_synchronization_recipients: [utc]
        })

      now = %{~U[2026-06-01 00:03:00Z] | utc_offset: 3600, std_offset: 3600}
      context = Context.new(:initialization, now: now, monotonic_time: 1000)

      assert {:ok, initial} = Device.execute(device, context)
      assert initial.next_execution == %Wakeup{wall_time: nil, monotonic_time: 301_000}
      assert Device.time_synchronization_requests(initial) == []

      changed = %{context | trigger: :clock_change, now: %{now | hour: 1}, state: initial.state}
      assert {:ok, rescheduled} = Device.execute(initial.object, changed)
      assert rescheduled.next_execution == initial.next_execution

      due = %{context | trigger: :timer, monotonic_time: 301_000, state: rescheduled.state}

      assert {:ok, sent} = Device.execute(rescheduled.object, due)
      assert sent.next_execution == %Wakeup{wall_time: nil, monotonic_time: 601_000}

      assert Device.time_synchronization_requests(sent) == [
               {local,
                %TimeSynchronization{
                  date: BACnetDate.from_date(~D[2026-06-01]),
                  time: BACnetTime.from_time(~T[00:03:00])
                }},
               {utc,
                %UtcTimeSynchronization{
                  date: BACnetDate.from_date(~D[2026-05-31]),
                  time: BACnetTime.from_time(~T[22:03:00])
                }}
             ]

      assert {:ok, subsequent} = Device.execute(sent.object, %{due | state: sent.state})
      assert Device.time_synchronization_requests(subsequent) == []
      assert subsequent.next_execution == sent.next_execution

      assert {:ok, disabled} =
               Device.update_property(sent.object, :time_synchronization_interval, 0)

      assert {:ok, stopped} = Device.execute(disabled, %{due | state: sent.state})
      assert Device.time_synchronization_requests(stopped) == []
      assert stopped.next_execution == nil
    end

    test "aligned scheduling applies the modulo offset and replans after a clock change" do
      recipient = device_recipient(42)

      device =
        device(%{
          align_intervals: true,
          interval_offset: 31,
          time_synchronization_interval: 30,
          time_synchronization_recipients: [recipient]
        })

      context = Context.new(:initialization, now: ~U[2026-06-01 11:44:00Z])
      assert {:ok, initial} = Device.execute(device, context)

      assert initial.next_execution == %Wakeup{
               wall_time: ~U[2026-06-01 12:01:00.000000Z],
               monotonic_time: nil
             }

      clock_change = %{
        context
        | trigger: :clock_change,
          now: ~U[2026-06-01 12:04:00Z],
          state: initial.state
      }

      assert {:ok, shifted} = Device.execute(initial.object, clock_change)

      assert shifted.next_execution == %Wakeup{
               wall_time: ~U[2026-06-01 12:31:00.000000Z],
               monotonic_time: nil
             }

      assert Device.time_synchronization_requests(shifted) == []

      due = %{context | trigger: :periodic, now: ~U[2026-06-01 12:31:00Z], state: shifted.state}
      assert {:ok, sent} = Device.execute(shifted.object, due)
      assert [{^recipient, %TimeSynchronization{}}] = Device.time_synchronization_requests(sent)

      assert sent.next_execution == %Wakeup{
               wall_time: ~U[2026-06-01 13:01:00.000000Z],
               monotonic_time: nil
             }
    end

    test "an aligned deadline skips a local clock gap and keeps its phase" do
      device =
        device(%{
          align_intervals: true,
          interval_offset: 15,
          time_synchronization_interval: 30,
          time_synchronization_recipients: [device_recipient(42)]
        })

      now = DateTime.from_naive!(~N[2026-03-29 01:50:00], "Test/Gap", TimezoneDatabase)
      context = Context.new(:initialization, now: now, timezone_database: TimezoneDatabase)

      assert {:ok, %Result{next_execution: %Wakeup{wall_time: deadline, monotonic_time: nil}}} =
               Device.execute(device, context)

      assert DateTime.compare(deadline, ~U[2026-03-29 01:15:00Z]) == :eq
      assert deadline.hour == 3
      assert deadline.minute == 15
    end

    test "an interval that does not divide an hour or day is relative even with alignment enabled" do
      device =
        device(%{
          align_intervals: true,
          interval_offset: 4,
          time_synchronization_interval: 7,
          utc_time_synchronization_recipients: [device_recipient(42)]
        })

      context = Context.new(:initialization, now: ~U[2026-06-01 12:00:00Z], monotonic_time: 10)

      assert {:ok, %Result{next_execution: %Wakeup{wall_time: nil, monotonic_time: 420_010}}} =
               Device.execute(device, context)
    end

    test "removing the time synchronization interval cancels a retained wakeup" do
      device =
        device(%{
          time_synchronization_interval: 5,
          time_synchronization_recipients: [device_recipient(42)]
        })

      context = Context.new(:initialization, now: ~U[2026-06-01 12:00:00Z], monotonic_time: 0)
      assert {:ok, initial} = Device.execute(device, context)
      assert %Wakeup{} = initial.next_execution

      assert {:ok, device} =
               Device.remove_property(initial.object, :time_synchronization_interval)

      assert {:ok, stopped} =
               Device.execute(device, %{context | trigger: :periodic, state: initial.state})

      assert stopped.next_execution == nil
      assert Device.time_synchronization_requests(stopped) == []
    end

    test "empty recipient lists leave periodic synchronization inactive" do
      device = device(%{time_synchronization_interval: 5, time_synchronization_recipients: []})

      assert {:ok, result} =
               Device.execute(device, Context.new(:initialization, now: ~U[2026-06-01 12:00:00Z]))

      assert result.next_execution == nil
      assert Device.time_synchronization_requests(result) == []
    end
  end

  defp execute_event(device, now, event) do
    Device.execute(device, Context.new(:periodic, now: now, options: [device_event: event]))
  end

  defp datetime_stamp(now) do
    %BACnetTimestamp{
      type: :datetime,
      time: nil,
      sequence_number: nil,
      datetime: BACnetDateTime.from_datetime(now)
    }
  end

  defp device_recipient(instance) do
    %Recipient{
      type: :device,
      address: nil,
      device: %ObjectIdentifier{type: :device, instance: instance}
    }
  end

  defp device(properties \\ %{}, opts \\ []) do
    defaults = %{vendor_identifier: 999, segmentation_supported: :no_segmentation}
    {:ok, device} = Device.create(1, "device", Map.merge(defaults, properties), opts)
    device
  end
end
