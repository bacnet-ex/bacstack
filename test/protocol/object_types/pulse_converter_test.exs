defmodule BACnet.Test.Protocol.ObjectTypes.PulseConverterTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.Accumulator
  alias BACnet.Protocol.ObjectTypes.PulseConverter
  alias BACnet.Protocol.Prescale
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_pulse_converter

  @now ~U[2026-11-09 12:00:00Z]
  @source %ObjectIdentifier{type: :accumulator, instance: 2}

  test "raw pulses scale the accumulated count and stamp Update_Time only on acquisition" do
    stored = initialize(%{count: 5, scale_factor: 2.5, present_value: 99.0})
    assert stored.object.present_value == 12.5
    assert stored.object.update_time == ObjectsMacro.get_default_bacnet_datetime()

    {:ok, counted} = record(stored, 3, 100)
    assert counted.object.count == 8
    assert counted.object.present_value == 20.0
    assert counted.object.update_time == timestamp(100)
    assert counted.object.count_change_time == stored.object.count_change_time
    assert counted.next_execution == nil

    {:ok, idle} = record(counted, 0, 200)
    assert idle.object == counted.object
    assert {:error, :invalid_pulse_count} = record(idle, -1, 300)
  end

  test "Adjust_Value truncates the quotient and updates the count and history atomically" do
    stored = initialize(%{count: 10, scale_factor: 2.0})
    {:ok, candidate} = PulseConverter.update_property(stored.object, :adjust_value, 5.9)
    ctx = context(stored, {:property_write, :adjust_value, nil, nil}, 100)

    assert {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    assert prepared.adjust_value == 5.9
    assert prepared.count_before_change == 10
    assert prepared.count == 8
    assert prepared.present_value == 16.0
    assert prepared.count_change_time == timestamp(100)
    assert prepared.update_time == stored.object.update_time

    assert {:ok, adjusted} = Lifecycle.execute(prepared, ctx)
    assert adjusted.object == prepared

    {:ok, repeated} = write(adjusted, :adjust_value, 5.9, 200)
    assert repeated.object.count == 6
    assert repeated.object.count_before_change == 8
    assert repeated.object.count_change_time == timestamp(200)

    {:ok, increased} = write(repeated, :adjust_value, -5.9, 300)
    assert increased.object.count == 8
    assert increased.object.present_value == 16.0
  end

  test "rejects underflow, REAL overflow and unusable scale factors" do
    stored = initialize(%{count: 1, scale_factor: 3.402_823_466_385_288_6e38})

    assert {:error, {:property_out_of_range, :adjust_value}} =
             write(stored, :adjust_value, -stored.object.scale_factor, 100)

    assert {:error, {:property_out_of_range, :count}} = record(stored, 1, 100)

    direct = initialize(%{count: 2, scale_factor: 2.0})

    for adjustment <- [6.0, :inf, :NaN] do
      assert {:error, {:property_out_of_range, :adjust_value}} =
               write(direct, :adjust_value, adjustment, 100)
    end

    for scale <- [0.0, :inf, :NaN, 1.0e-100] do
      {:ok, object} = PulseConverter.create(1, "Converter", %{scale_factor: scale})

      assert {:error, {:invalid_configuration, :scale_factor}} =
               Lifecycle.execute(object, context(nil, :initialization, 0))
    end
  end

  test "direct input isolation preserves the simulated value and retains physical Reliability" do
    stored = initialize(%{count: 6, scale_factor: 2.0, reliability: :process_error})
    refute PulseConverter.property_writable?(stored.object, :present_value)
    assert {:error, :write_access_denied} = write(stored, :present_value, 8.0, 100)
    assert {:error, :write_access_denied} = write(stored, :count, 4, 100)

    {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true, 100)
    refute inhibited.object.status_flags.fault
    {:ok, isolated} = write(inhibited, :out_of_service, true, 200)
    assert PulseConverter.property_writable?(isolated.object, :present_value)

    {:ok, simulated} = write(isolated, :present_value, 123.0, 200)
    {:ok, simulated} = write(simulated, :reliability, :communication_failure, 200)
    assert simulated.object.status_flags.fault

    {:ok, ignored} = record(simulated, 10, 300)
    assert ignored.object.count == 6
    assert ignored.object.present_value == 123.0
    assert ignored.object.update_time == stored.object.update_time

    {:ok, adjusted} = write(ignored, :adjust_value, 2.0, 400)
    assert adjusted.object.count == 5
    assert adjusted.object.present_value == 123.0
    {:ok, resumed} = write(adjusted, :out_of_service, false, 500)
    assert resumed.object.present_value == 10.0
    assert resumed.object.reliability == :no_fault_detected
    {:ok, restored} = write(resumed, :reliability_evaluation_inhibit, false, 600)
    assert restored.object.reliability == :process_error
  end

  test "reads an initialized Accumulator without mirroring its Out_Of_Service property" do
    {:ok, input} =
      Accumulator.create(2, "Source", %{
        present_value: 100,
        out_of_service: true,
        scale: 1.0,
        prescale: %Prescale{multiplier: 1, modulo_divide: 1}
      })

    {:ok, object} =
      PulseConverter.create(1, "Converter", %{
        count: 10,
        scale_factor: 2.0,
        input_reference: source_ref()
      })

    host = Host.new([{input, []}, {object, []}], @now, 0)
    id = PulseConverter.get_object_identifier(object)
    assert :ok = Host.execute(host, @source, :initialization)
    assert :ok = Host.execute(host, id, :initialization)
    assert Host.snapshot(host, id).object.count == 10
    refute Host.snapshot(host, id).object.out_of_service

    Host.advance(host, wall_time(100), 100)
    assert :ok = Host.write(host, property_ref(@source, :present_value), 104)

    changed = %DeviceObjectRef{device_identifier: nil, object_identifier: @source}
    assert :ok = Host.execute(host, id, {:object_changed, changed})
    counted = Host.snapshot(host, id).object
    assert counted.count == 14
    assert counted.present_value == 28.0
    assert counted.update_time == timestamp(100)
    refute counted.out_of_service
    assert counted.reliability == :no_fault_detected
    assert counted.reliability_evaluation_inhibit == false

    assert :ok = Host.write(host, property_ref(id, :adjust_value), 4.0)
    assert Host.snapshot(host, id).object.count == 12
    assert :ok = Host.write(host, property_ref(@source, :present_value), 106)
    assert :ok = Host.execute(host, id, {:object_changed, changed})
    assert {:ok, 28.0} = Host.read(host, property_ref(id, :present_value))
  end

  test "reference baselines survive read failures and reset on a counter decrease" do
    stored = initialize(%{count: 5, input_reference: source_ref()}, read_source({:ok, -10}))
    assert stored.object.count == 5

    {:ok, missed} = poll(stored, 100, {:error, :timeout})
    assert missed.object.count == 5
    assert missed.object.reliability == :communication_failure

    reading = Encoding.create!({:signed_integer, -6})
    {:ok, recovered} = poll(missed, 200, {:ok, reading})
    assert recovered.object.count == 9
    assert recovered.object.reliability == :no_fault_detected
    refute recovered.object.status_flags.fault

    {:ok, reset} = poll(recovered, 300, {:ok, -20})
    assert reset.object.count == 9
    assert reset.object.update_time == timestamp(200)

    {:ok, resumed} = poll(reset, 400, {:ok, -19})
    assert resumed.object.count == 10
    assert resumed.object.update_time == timestamp(400)
    assert {:error, :input_reference_configured} = record(resumed, 1, 500)
  end

  test "unsupported reference types report a configuration fault and retain count" do
    stored = initialize(%{count: 5, input_reference: source_ref()}, read_source({:ok, 10.0}))
    assert stored.object.reliability == :configuration_error
    assert stored.object.status_flags.fault

    wrong_tag = Encoding.create!({:enumerated, 10})
    {:ok, wrong} = poll(stored, 100, {:ok, wrong_tag})
    assert wrong.object.count == 5
    assert wrong.object.reliability == :configuration_error

    {:ok, configured} = poll(wrong, 200, {:ok, Encoding.create!({:unsigned_integer, 10})})
    assert configured.object.count == 5
    assert configured.object.reliability == :no_fault_detected
    refute configured.object.status_flags.fault
  end

  test "reference overflow and unsupported reads preserve the last accepted baseline" do
    count = 1

    stored =
      initialize(
        %{count: count, scale_factor: 2.0e38, input_reference: source_ref()},
        read_source({:ok, 10})
      )

    assert {:ok, overflow} = poll(stored, 100, {:ok, 11})
    assert overflow.object.count == count
    assert overflow.object.reliability == :over_range
    assert overflow.state.source.value == 10

    for reason <- [:unknown_object, {:unknown_property, :present_value}] do
      assert {:ok, failed} = poll(stored, 200, {:error, reason})
      assert failed.object.count == count
      assert failed.object.reliability == :configuration_error
      assert failed.state.source.value == 10
    end

    invalid = %{stored | state: %{stored.state | source: :invalid}}
    assert {:error, :invalid_execution_state} = poll(invalid, 300, {:ok, 10})
  end

  test "referenced Count continues while simulated Present_Value and Reliability are isolated" do
    stored = initialize(%{count: 5, input_reference: source_ref()}, read_source({:ok, 10}))
    {:ok, isolated} = write(stored, :out_of_service, true, 100)
    {:ok, simulated} = write(isolated, :present_value, 123.0, 100)
    {:ok, counted} = poll(simulated, 200, {:ok, 14})
    assert counted.object.count == 9
    assert counted.object.present_value == 123.0
    assert counted.object.update_time == timestamp(200)

    {:ok, failed} = poll(counted, 300, {:error, :timeout})
    assert failed.object.reliability == :no_fault_detected
    {:ok, resumed} = write(failed, :out_of_service, false, 400)
    assert resumed.object.count == 9
    assert resumed.object.present_value == 9.0
    assert resumed.object.reliability == :communication_failure
  end

  test "changing the reference establishes a baseline without adding its total" do
    stored = initialize(%{count: 5, input_reference: source_ref()}, read_source({:ok, 10}))
    other = %{@source | instance: 3}
    new_ref = %ObjectPropertyRef{source_ref() | object_identifier: other, property_array_index: 2}
    {:ok, candidate} = PulseConverter.update_property(stored.object, :input_reference, new_ref)
    expected = %{property_ref(other, :present_value) | property_array_index: 2}
    callback = fn ^expected -> {:ok, 100} end
    ctx = context(stored, {:property_write, :input_reference, nil, nil}, 100, callback)

    {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    {:ok, changed} = Lifecycle.execute(prepared, ctx)
    assert changed.object.count == 5

    unrelated = %DeviceObjectRef{device_identifier: nil, object_identifier: @source}

    ctx =
      context(changed, {:object_changed, unrelated}, 200, fn _ref -> flunk("unexpected read") end)

    assert {:ok, %Result{object: %{count: 5}}} = Lifecycle.execute(changed.object, ctx)

    matching = %{unrelated | object_identifier: other}
    ctx = context(changed, {:object_changed, matching}, 300, fn ^expected -> {:ok, 102} end)
    assert {:ok, %Result{object: %{count: 7}}} = Lifecycle.execute(changed.object, ctx)
  end

  test "local instances require initialized state and remote snapshots stay passive" do
    stored = initialize(%{}, nil, intrinsic_reporting: true)
    assert stored.object.event_state == :normal

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(stored.object, context(nil, :periodic, 0))

    props =
      stored.object
      |> Map.take(PulseConverter.get_properties(stored.object))
      |> Map.drop(PulseConverter.get_intrinsic_properties())

    {:ok, remote} = PulseConverter.create(2, "Remote", props, remote_object: 42)
    ctx = %{context(nil, :periodic, 0) | state: :remote_state}

    assert :ok = PulseConverter.validate_execution(remote, ctx)
    write = %{ctx | trigger: {:property_write, :count, nil, nil}}

    assert {:error, :operation_not_available_for_remote_objects} =
             PulseConverter.prepare_write(remote, remote, write)

    assert {:ok, %Result{object: ^remote, state: :remote_state, next_execution: nil}} =
             PulseConverter.execute(remote, ctx)

    assert {:ok, %Result{object: ^remote, state: :remote_state, next_execution: nil}} =
             Lifecycle.execute(remote, ctx)

    assert {:error, :operation_not_available_for_remote_objects} =
             PulseConverter.record_pulses(remote, 1, ctx)
  end

  test "a count that cannot be represented as a real is rejected" do
    stored = initialize(%{count: 0, scale_factor: 1.0})

    assert {:error, {:property_out_of_range, :count}} =
             record(stored, Bitwise.bsl(1, 1024), 100)

    assert stored.object.count == 0
  end

  test "a reference increase with an unusable device clock is not applied" do
    stored = initialize(%{count: 5, input_reference: source_ref()}, read_source({:ok, 10}))
    now = DateTime.new!(~D[1899-06-01], ~T[12:00:00], "Etc/UTC")

    ctx =
      Context.new(:periodic,
        now: now,
        monotonic_time: 100,
        state: stored.state,
        read_property: read_source({:ok, 12})
      )

    assert {:error, :invalid_wall_time} = Lifecycle.execute(stored.object, ctx)
    assert stored.object.count == 5
  end

  test "the first referenced sample selects reliability when it was not configured" do
    {:ok, object} = PulseConverter.create(1, "Converter", %{count: 1, scale_factor: 2.0})
    refute PulseConverter.has_property?(object, :reliability)
    {:ok, object} = PulseConverter.add_property(object, :input_reference, source_ref())
    refute PulseConverter.has_property?(object, :reliability)

    {:ok, stored} =
      Lifecycle.execute(object, context(nil, :initialization, 0, read_source({:ok, 8})))

    assert PulseConverter.has_property?(stored.object, :reliability)
    assert stored.object.reliability == :no_fault_detected
    assert stored.state.physical_reliability == :no_fault_detected
  end

  test "dropping a referenced input clears the sampled reliability report" do
    stored = initialize(%{count: 5, input_reference: source_ref()}, read_source({:ok, 10}))
    {:ok, failed} = poll(stored, 100, {:error, :timeout})
    assert failed.object.reliability == :communication_failure
    assert is_map(failed.state.source)

    {:ok, direct} = PulseConverter.remove_property(failed.object, :input_reference)
    refute PulseConverter.has_property?(direct, :input_reference)

    {:ok, cleared} =
      Lifecycle.execute(direct, context(%{failed | object: direct}, :periodic, 200))

    assert cleared.state.physical_reliability == :no_fault_detected
    assert cleared.object.reliability == :no_fault_detected
  end

  test "initialization out of service has no physical reliability report" do
    stored = initialize(%{out_of_service: true, reliability: :process_error})
    assert stored.object.out_of_service
    assert stored.object.reliability == :process_error
    assert stored.state.physical_reliability == nil
  end

  test "reports a high limit after scaling a pulse" do
    stored =
      initialize(
        %{
          count: 0,
          scale_factor: 2.5,
          high_limit: 2.0,
          limit_enable: LimitEnable.from_bitstring({false, true})
        },
        nil,
        intrinsic_reporting: true
      )

    assert {:ok, counted} =
             PulseConverter.record_pulses(stored.object, 1, context(stored, :periodic, 100))

    assert counted.object.present_value == 2.5

    assert %{
             event_type: :out_of_range,
             to_state: :high_limit,
             event_values: %{exceeding_value: 2.5}
           } = EventReporting.transition(counted)
  end

  defp initialize(properties, callback \\ nil, opts \\ []) do
    {:ok, object} = PulseConverter.create(1, "Converter", properties, opts)
    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization, 0, callback))
    stored
  end

  defp record(stored, pulses, elapsed) do
    PulseConverter.record_pulses(stored.object, pulses, context(stored, :periodic, elapsed))
  end

  defp poll(stored, elapsed, response) do
    Lifecycle.execute(stored.object, context(stored, :periodic, elapsed, read_source(response)))
  end

  defp write(stored, property, value, elapsed) do
    with {:ok, candidate} <- PulseConverter.update_property(stored.object, property, value) do
      ctx = context(stored, {:property_write, property, nil, nil}, elapsed)

      with {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        Lifecycle.execute(prepared, ctx)
      end
    end
  end

  defp context(stored, trigger, elapsed, callback \\ nil) do
    Context.new(trigger,
      now: wall_time(elapsed),
      monotonic_time: elapsed,
      state: if(stored, do: stored.state),
      read_property: callback
    )
  end

  defp read_source(response) do
    expected = property_ref(@source, :present_value)
    fn ^expected -> response end
  end

  defp source_ref() do
    %ObjectPropertyRef{
      object_identifier: @source,
      property_identifier: :present_value,
      property_array_index: nil
    }
  end

  defp property_ref(identifier, property) do
    %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: identifier,
      property_identifier: property,
      property_array_index: nil
    }
  end

  defp wall_time(elapsed), do: DateTime.add(@now, elapsed, :millisecond)
  defp timestamp(elapsed), do: BACnetDateTime.from_datetime(wall_time(elapsed))
end
