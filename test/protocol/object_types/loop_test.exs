defmodule BACnet.Test.Protocol.ObjectTypes.LoopTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.AnalogValue
  alias BACnet.Protocol.ObjectTypes.Loop
  alias BACnet.Protocol.SetpointReference
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host
  alias HvacPid.Controller

  @moduletag :object_test
  @now ~U[2026-11-10 08:00:00Z]

  doctest Loop

  test "initialization publishes P before writing the captured output at its priority" do
    object = object(%{priority_for_writing: 8})
    ctx = context(:initialization, monotonic_time: -1000)
    assert :ok = Loop.validate_execution(object, ctx)
    assert {:ok, first} = Loop.execute(object, ctx)
    assert first.object.controlled_variable_value == 19.0
    assert first.object.present_value == 4.0
    assert first.next_execution == :immediate
    refute_received {:write, _reference, _value, _priority}

    assert {:ok, waiting} = continue(first, ctx)
    assert_received {:write, reference, 4.0, 8}
    assert reference == device_reference(2)
    assert waiting.next_execution.monotonic_time == 0
    assert waiting.next_execution.wall_time == nil
    assert waiting.object.reliability == :no_fault_detected
    assert waiting.state.pending_write == nil
  end

  test "external mode is passive without callbacks and retains arbitrary supplied state" do
    object = object(%{proportional_constant_units: :percent}, pid_enabled: false)
    ctx = Context.new(:initialization, now: @now, monotonic_time: 0, state: :external)
    assert object._metadata.other.pid_enabled == false
    assert :ok = Loop.validate_execution(object, ctx)

    assert {:ok, %Result{object: ^object, state: :external, next_execution: nil}} =
             Loop.execute(object, ctx)

    {:ok, candidate} = Loop.update_property(object, :present_value, 42.0)
    application = %{ctx | trigger: {:application_write, :present_value, nil, nil}}
    assert {:ok, ^candidate} = Loop.prepare_write(object, candidate, application)

    assert {:ok, %Result{object: ^candidate, next_execution: nil}} =
             Loop.execute(candidate, application)

    {:ok, simulation} = Loop.update_property(candidate, :out_of_service, true)
    ctx = %{ctx | trigger: {:property_write, :present_value, nil, nil}}

    assert {:ok, %Result{object: ^simulation, next_execution: nil}} =
             Loop.execute(simulation, ctx)

    refute_received {:write, _reference, _value, _priority}
  end

  test "reports a floating low limit alongside a PID command" do
    object = object(%{error_limit: 1.0}, intrinsic_reporting: true)
    assert {:ok, result} = Loop.execute(object, context(:initialization))
    assert result.object.present_value == 4.0

    assert %{
             event_type: :floating_limit,
             to_state: :low_limit,
             event_values: %{reference_value: 19.0, setpoint_value: 21.0, error_limit: 1.0}
           } =
             EventReporting.transition(result)

    assert result.next_execution == :immediate
  end

  test "reapplying the PID setting retains a pending reporting wakeup" do
    stored =
      initial(
        object(%{error_limit: 1.0, time_delay: 2, update_interval: 10_000},
          intrinsic_reporting: true
        )
      )

    assert stored.next_execution.monotonic_time == 2000

    context = context(:periodic, state: stored.state, monotonic_time: 100)
    assert {:ok, pending} = Loop.set_pid_enabled(stored.object, true, context)
    assert pending.next_execution.monotonic_time == 2000
    assert EventReporting.transition(pending) == nil
  end

  test "runtime PID toggle commands the configured stop and start values" do
    stored = initial(object(%{integral_constant: 2.0, integral_constant_units: :seconds}))
    {:ok, object} = Loop.set_pid_start_value(stored.object, 30.0)
    {:ok, object} = Loop.set_pid_stop_value(object, 12.0)
    stored = %{stored | object: object}

    ctx =
      context(:periodic,
        monotonic_time: 500,
        state: stored.state,
        read_property: nil,
        write_property: nil
      )

    assert Loop.pid_enabled?(stored.object)
    assert {:ok, ^stored} = Loop.set_pid_enabled(stored.object, true, ctx)

    assert {:error, {:unsupported_operation, :write_property}} =
             Loop.set_pid_enabled(stored.object, false, ctx)

    write_context =
      context(:periodic, monotonic_time: 500, state: stored.state, read_property: nil)

    assert {:ok, stopping} = Loop.set_pid_enabled(stored.object, false, write_context)
    refute Loop.pid_enabled?(stopping.object)
    refute stopping.object.out_of_service
    assert stopping.object.present_value == 12.0
    assert stopping.next_execution == :immediate
    assert Controller.output(stopping.state.controller) == 12.0
    assert {:ok, 12.0, _controller} = Controller.step(stopping.state.controller, 40.0, 0.0, 1.0)
    refute_received {:write, _reference, _value, _priority}

    assert {:error, :busy} =
             Loop.set_pid_enabled(stopping.object, true, %{write_context | state: stopping.state})

    assert {:ok, disabled} = continue(stopping, write_context)
    assert_received {:write, _reference, 12.0, 16}
    assert disabled.next_execution == nil

    ctx = %{ctx | trigger: :timer, monotonic_time: 100_000, state: disabled.state}
    assert {:ok, ^disabled} = Loop.execute(disabled.object, ctx)
    assert {:ok, ^disabled} = Loop.set_pid_enabled(disabled.object, false, ctx)

    assert {:error, {:unsupported_operation, :read_property}} =
             Loop.set_pid_enabled(disabled.object, true, ctx)

    ctx =
      context(:periodic,
        monotonic_time: 100_000,
        state: disabled.state,
        read_property: fn _reference -> {:ok, 20.0} end
      )

    assert {:ok, enabled} = Loop.set_pid_enabled(disabled.object, true, ctx)
    assert Loop.pid_enabled?(enabled.object)
    refute enabled.object.out_of_service
    assert enabled.object.controlled_variable_value == 20.0
    assert enabled.object.present_value == 30.0
    assert enabled.next_execution == :immediate
    assert {:ok, running} = continue(enabled, ctx)
    assert_received {:write, _reference, 30.0, 16}
    assert running.next_execution.monotonic_time == 101_000
    assert step(running, 101_000, 20.0).object.present_value == 31.0
  end

  test "enabling a Loop with application readings applies the start value on the first sample" do
    reference = ObjectsMacro.get_default_object_ref()

    object =
      object(
        %{
          controlled_variable_reference: reference,
          manipulated_variable_reference: reference,
          present_value: 35.0,
          integral_constant: 2.0,
          integral_constant_units: :seconds
        },
        pid_enabled: false,
        pid_start_value: 25.0
      )

    ctx = context(:periodic, state: :external, read_property: nil, write_property: nil)

    assert {:ok, enabled} = Loop.set_pid_enabled(object, true, ctx)
    assert Loop.pid_enabled?(enabled.object)
    assert enabled.next_execution == nil
    assert enabled.object.present_value == 35.0

    first = submit_measurement(enabled, ctx, 250, 19.0)
    assert first.object.present_value == 25.0
    assert first.next_execution == nil
    assert submit_measurement(first, ctx, 1250, 19.0).object.present_value == 27.0
  end

  test "runtime PID toggle preserves out of service and waits for pending actuator writes" do
    object =
      object(
        %{
          out_of_service: true,
          present_value: 27.0,
          manipulated_variable_reference: ObjectsMacro.get_default_object_ref()
        },
        pid_enabled: false
      )

    ctx = context(:periodic, read_property: nil, write_property: nil)

    assert {:ok, enabled} = Loop.set_pid_enabled(object, true, ctx)
    assert Loop.pid_enabled?(enabled.object)
    assert enabled.object.out_of_service
    assert enabled.next_execution == nil
    assert Controller.output(enabled.state.controller) == 27.0
    assert {:ok, 27.0, _controller} = Controller.step(enabled.state.controller, 40.0, 0.0, 1.0)

    assert {:ok, disabled} =
             Loop.set_pid_enabled(enabled.object, false, %{ctx | state: enabled.state})

    assert disabled.object.out_of_service
    refute Loop.pid_enabled?(disabled.object)
    assert disabled.object.present_value == 0.0
    assert Controller.output(disabled.state.controller) == 0.0

    ctx = context(:initialization)
    assert {:ok, pending} = Loop.execute(object(), ctx)
    assert pending.next_execution == :immediate

    assert {:error, :busy} =
             Loop.set_pid_enabled(pending.object, false, %{ctx | state: pending.state})

    refute_received {:write, _reference, _value, _priority}
  end

  test "start and stop options respect limits and nil restores the defaults" do
    reference = ObjectsMacro.get_default_object_ref()

    object =
      object(%{min_output: -5.0, max_output: 10.0, manipulated_variable_reference: reference},
        pid_start_value: 30.0,
        pid_stop_value: -30.0
      )

    ctx = context(:initialization, write_property: nil)
    assert {:ok, running} = Loop.execute(object, ctx)
    assert running.object.present_value == 10.0

    assert {:ok, stopped} =
             Loop.set_pid_enabled(running.object, false, %{ctx | state: running.state})

    assert stopped.object.present_value == -5.0
    assert stopped.next_execution == nil

    assert {:ok, object} = Loop.set_pid_start_value(stopped.object, nil)
    assert {:ok, object} = Loop.set_pid_stop_value(object, 5.0)
    assert {:ok, object} = Loop.set_pid_stop_value(object, nil)

    assert {:error, {:invalid_configuration, :pid_start_value}} =
             Loop.set_pid_start_value(object, :NaN)

    assert {:error, {:invalid_configuration, :pid_stop_value}} =
             Loop.set_pid_stop_value(object, 1.0e39)

    assert {:ok, running} = Loop.set_pid_enabled(object, true, %{ctx | state: stopped.state})
    assert running.object.present_value == 4.0

    assert {:ok, stopped} =
             Loop.set_pid_enabled(running.object, false, %{ctx | state: running.state})

    assert stopped.object.present_value == -5.0

    {:ok, unbounded} = Loop.create(11, "No limits", %{present_value: 15.0})
    assert {:ok, stopped} = Loop.set_pid_enabled(unbounded, false, ctx)
    assert stopped.object.present_value == 0.0
  end

  test "a failed stop command leaves the PID disabled without scheduling another attempt" do
    stored = initial(object(%{}, pid_stop_value: 10.0))

    ctx =
      context(:periodic,
        state: stored.state,
        monotonic_time: 1000,
        read_property: nil,
        write_property: fn _reference, _value, _priority -> {:error, :timeout} end
      )

    assert {:ok, stopping} = Loop.set_pid_enabled(stored.object, false, ctx)
    assert {:ok, stopped} = continue(stopping, ctx)
    refute Loop.pid_enabled?(stopped.object)
    assert stopped.object.present_value == 10.0
    assert stopped.object.reliability == :communication_failure
    assert stopped.state.pending_write == nil
    assert stopped.next_execution == nil

    ctx = %{ctx | trigger: :timer, state: stopped.state, write_property: nil}
    assert {:ok, ^stopped} = Loop.execute(stopped.object, ctx)
  end

  test "startup applies the configured command after an initial read failure" do
    object = object(%{}, pid_start_value: 30.0)
    ctx = context(:initialization, read_property: fn _reference -> {:error, :timeout} end)

    assert {:ok, failed} = Loop.execute(object, ctx)
    assert failed.object.present_value == 0.0
    assert step(failed, 1000, 19.0).object.present_value == 30.0
  end

  test "remote snapshots preserve values and state without validating local PID settings" do
    device = %ObjectIdentifier{type: :device, instance: 20}
    local = object()

    object = %{
      local
      | _metadata: %{local._metadata | remote_object: device, other: %{pid_enabled: :invalid}}
    }

    ctx = Context.new(:initialization, now: @now, monotonic_time: 0, state: :remote)
    assert :ok = Loop.validate_execution(object, ctx)

    assert {:ok, %Result{object: ^object, state: :remote, next_execution: nil}} =
             Loop.execute(object, ctx)

    assert {:error, :operation_not_available_for_remote_objects} =
             Loop.prepare_write(object, object, ctx)

    assert {:error, :operation_not_available_for_remote_objects} =
             Loop.set_pid_enabled(object, true, ctx)

    assert {:error, :operation_not_available_for_remote_objects} =
             Loop.set_pid_start_value(object, 0.0)

    assert {:error, :operation_not_available_for_remote_objects} =
             Loop.set_pid_stop_value(object, 0.0)

    assert {:error, :operation_not_available_for_remote_objects} =
             Loop.set_pid_deadzone(object, 1.0)
  end

  test "default output cadence is one second and early or duplicate calls do not sample" do
    {:ok, object} =
      Loop.create(1, "Defaults", %{
        controlled_variable_reference: reference(1),
        manipulated_variable_reference: reference(2)
      })

    first = initial(object)
    assert first.object.present_value == 0.0
    assert first.next_execution.monotonic_time == 1000

    for now <- [0, 500, 999] do
      ctx =
        context(:timer,
          state: first.state,
          monotonic_time: now,
          read_property: fn _reference -> flunk("early acquisition") end
        )

      assert {:ok, result} = Loop.execute(first.object, ctx)
      assert result.state == first.state
      assert result.next_execution == first.next_execution
    end
  end

  test "one millisecond periods use elapsed seconds and late delivery takes one current sample" do
    stored =
      initial(
        object(%{update_interval: 1, integral_constant: 2.0, integral_constant_units: :seconds})
      )

    next = step(stored, 1, 19.0)
    assert_in_delta next.object.present_value, 4.002, 1.0e-10
    late = step(next, 251, 19.0)
    assert_in_delta late.object.present_value, 4.502, 1.0e-10
    assert late.next_execution.monotonic_time == 252
    assert late.state.last_sample == 251
  end

  test "direct heats below setpoint and reverse cools above setpoint" do
    for {action, reading} <- [direct: 19.0, reverse: 23.0] do
      stored = initial(object(%{action: action}), reading)
      assert stored.object.present_value == 4.0
    end
  end

  test "zero constants disable only their own terms, including negative zero" do
    <<negative_zero::float-64>> = <<1::1, 0::63>>

    for zero <- [0.0, negative_zero],
        {properties, expected} <- [
          {%{
             proportional_constant: zero,
             integral_constant: 2.0,
             integral_constant_units: :seconds
           }, 1.0},
          {%{
             proportional_constant: zero,
             derivative_constant: 0.5,
             derivative_constant_units: :seconds
           }, 1.0},
          {%{
             proportional_constant: zero,
             integral_constant: 2.0,
             integral_constant_units: :seconds,
             derivative_constant: 0.5,
             derivative_constant_units: :seconds
           }, 2.0},
          {%{
             integral_constant: zero,
             integral_constant_units: :seconds,
             derivative_constant: 0.5,
             derivative_constant_units: :seconds
           }, 6.0},
          {%{
             integral_constant: 2.0,
             integral_constant_units: :seconds,
             derivative_constant: zero,
             derivative_constant_units: :seconds
           }, 6.0},
          {%{
             integral_constant: zero,
             integral_constant_units: :seconds,
             derivative_constant: zero,
             derivative_constant_units: :seconds
           }, 4.0},
          {%{
             proportional_constant: zero,
             integral_constant: zero,
             integral_constant_units: :seconds,
             derivative_constant: zero,
             derivative_constant_units: :seconds
           }, 0.0}
        ] do
      stored = initial(object(properties), 21.0)
      next = step(stored, 1000, 19.0)
      assert_in_delta next.object.present_value, expected, 1.0e-10
    end
  end

  test "both derivative sources react to measurement changes and only error reacts to setpoint" do
    for {source, expected} <- [measurement: 4.0, error: 6.0] do
      stored =
        initial(
          object(%{derivative_constant: 0.5, derivative_constant_units: :seconds},
            pid_derivative_on: source
          ),
          21.0
        )

      {:ok, changed} = Loop.update_property(stored.object, :setpoint, 23.0)
      next = step(%{stored | object: changed}, 1000, 21.0)
      assert next.object.present_value == expected
    end
  end

  test "integral reset rates and time units convert to seconds" do
    for {constant, units} <- [
          {2.0, :seconds},
          {2000.0, :milliseconds},
          {200.0, :hundredths_seconds},
          {1.0 / 30, :minutes},
          {1.0 / 1800, :hours},
          {0.5, :per_second},
          {30.0, :per_minute}
        ] do
      stored = initial(object(%{integral_constant: constant, integral_constant_units: units}))
      next = step(stored, 1000, 19.0)
      assert_in_delta next.object.present_value, 6.0, 1.0e-9
    end
  end

  test "referenced setpoints and array indices are read locally and published" do
    object =
      object(%{
        setpoint_reference: %SetpointReference{ref: reference(3, 2)},
        controlled_variable_reference: reference(1, 1),
        manipulated_variable_reference: reference(2, 4)
      })

    read = fn ref ->
      send(self(), {:read, ref})
      {:ok, if(ref.object_identifier.instance == 3, do: 22.0, else: 20.0)}
    end

    ctx = context(:initialization, read_property: read)
    assert {:ok, stored} = Loop.execute(object, ctx)
    assert stored.object.setpoint == 22.0
    assert stored.object.controlled_variable_value == 20.0
    assert stored.object.present_value == 4.0

    assert_received {:read,
                     %DeviceObjectPropertyRef{device_identifier: nil, property_array_index: 1}}

    assert_received {:read,
                     %DeviceObjectPropertyRef{device_identifier: nil, property_array_index: 2}}

    assert {:ok, _stored} = continue(stored, ctx)
    assert_received {:write, %DeviceObjectPropertyRef{property_array_index: 4}, 4.0, 16}
  end

  test "native and encoded numeric samples are accepted" do
    for sample <- [
          19,
          19.0,
          Encoding.create!({:real, 19.0}),
          [Encoding.create!({:unsigned_integer, 19})],
          Encoding.create!({:double, 19.0})
        ] do
      stored = initial(object(), sample)
      assert stored.object.present_value == 4.0
    end
  end

  test "output bounds and bias are applied and saturated integral recovers" do
    stored =
      initial(
        object(%{
          bias: 10.0,
          max_output: 12.0,
          integral_constant: 1.0,
          integral_constant_units: :seconds
        })
      )

    assert stored.object.present_value == 12.0
    saturated = step(stored, 1000, 19.0)
    assert saturated.object.present_value == 12.0
    recovered = step(saturated, 2000, 21.0)
    assert recovered.object.present_value == 10.0
  end

  test "PID deadzone holds at the radius and can be changed without resetting integration" do
    object =
      object(%{integral_constant: 2.0, integral_constant_units: :seconds, deadband: 10.0},
        intrinsic_reporting: true,
        pid_deadzone: 1.0
      )

    initial = initial(object)
    assert initial.object.present_value == 4.0

    held = step(initial, 1000, 20.0)
    assert held.object.controlled_variable_value == 20.0
    assert held.object.present_value == 4.0

    outside = step(held, 2000, 19.5)
    assert outside.object.present_value == 4.5

    assert {:ok, widened} = Loop.set_pid_deadzone(outside.object, 2.0)
    held = step(%{outside | object: widened}, 3000, 20.5)
    assert held.object.present_value == 4.5

    assert {:ok, cleared} = Loop.set_pid_deadzone(held.object, 0)
    resumed = step(%{held | object: cleared}, 4000, 20.5)
    assert resumed.object.present_value == 3.0
    assert resumed.object.deadband == 10.0
  end

  test "PID deadzone rejects invalid settings through the setter and at preflight" do
    for value <- [-1.0, :NaN, :inf, nil, 1.0e39] do
      assert {:error, {:invalid_configuration, :pid_deadzone}} =
               Loop.set_pid_deadzone(object(), value)

      assert {:error, {:invalid_configuration, :pid_deadzone}} =
               Loop.validate_execution(object(%{}, pid_deadzone: value), context(:initialization))
    end
  end

  test "retuning is applied bumplessly at the next due sample" do
    stored = initial(object())
    {:ok, candidate} = Loop.update_property(stored.object, :proportional_constant, 5.0)

    ctx =
      context({:property_write, :proportional_constant, nil, nil},
        state: stored.state,
        monotonic_time: 100
      )

    assert {:ok, ^candidate} = Loop.prepare_write(stored.object, candidate, ctx)
    assert {:ok, early} = Loop.execute(candidate, ctx)
    assert early.next_execution.monotonic_time == 1000
    first = step(early, 1000, 19.0)
    assert first.object.present_value == 4.0
    next = step(first, 2000, 20.0)
    assert next.object.present_value == 0.0
  end

  test "changing the update interval reschedules from the last attempt" do
    stored = initial(object())
    {:ok, changed} = Loop.update_property(stored.object, :update_interval, 200)

    ctx =
      context({:property_write, :update_interval, nil, nil},
        state: stored.state,
        monotonic_time: 100
      )

    assert {:ok, early} = Loop.execute(changed, ctx)
    assert early.next_execution.monotonic_time == 200
    next = step(early, 200, 19.0)
    assert next.next_execution.monotonic_time == 400
  end

  test "reported effective output reanchors once and ordinary integration then resumes" do
    stored = initial(object(%{integral_constant: 2.0, integral_constant_units: :seconds}))

    ctx =
      context(:timer,
        monotonic_time: 1000,
        state: stored.state,
        options: [loop_effective_output: 40.0]
      )

    assert {:ok, anchored} = Loop.execute(stored.object, ctx)
    assert anchored.object.present_value == 40.0
    {:ok, anchored} = continue(anchored, ctx)
    next = step(anchored, 2000, 19.0)
    assert next.object.present_value == 42.0
  end

  test "simulation preserves reliability and propagates same-value writes beyond PID bounds" do
    stored = initial(object())
    {:ok, simulated} = Loop.update_property(stored.object, :out_of_service, true)

    enter =
      context({:property_write, :out_of_service, nil, nil},
        state: stored.state,
        monotonic_time: 400,
        read_property: nil,
        write_property: nil
      )

    assert {:ok, manual} = Loop.execute(simulated, enter)
    assert manual.next_execution == nil
    assert Controller.output(manual.state.controller) == manual.object.present_value
    assert {:ok, 4.0, _controller} = Controller.step(manual.state.controller, 40.0, 0.0, 1.0)

    {:ok, simulated} = Loop.update_property(manual.object, :present_value, 250.0)
    {:ok, simulated} = Loop.update_property(simulated, :reliability, :unreliable_other)

    ctx =
      context({:property_write, :present_value, nil, nil},
        state: manual.state,
        monotonic_time: 500,
        read_property: fn _reference -> flunk("simulation read") end
      )

    assert Loop.property_writable?(simulated, :present_value)
    assert {:ok, ^simulated} = Loop.prepare_write(manual.object, simulated, ctx)
    assert {:ok, pending} = Loop.execute(simulated, ctx)
    assert pending.next_execution == :immediate
    assert Controller.output(pending.state.controller) == 250.0
    assert {:ok, result} = continue(pending, ctx)
    assert result.next_execution == nil
    assert result.object.reliability == :unreliable_other
    assert_received {:write, _reference, 250.0, 16}
    assert {:ok, same} = Loop.execute(result.object, %{ctx | state: result.state})
    assert {:ok, result} = continue(same, ctx)
    assert_received {:write, _reference, 250.0, 16}

    {:ok, resumed} = Loop.update_property(result.object, :out_of_service, false)

    ctx =
      context({:property_write, :out_of_service, nil, nil},
        state: result.state,
        monotonic_time: 1000
      )

    assert {:ok, automatic} = Loop.execute(resumed, ctx)
    assert automatic.object.present_value == 100.0
    assert Controller.output(automatic.state.controller) == 100.0
  end

  test "out-of-service initialization needs no I/O and service resumption anchors the simulated output" do
    object = object(%{out_of_service: true, present_value: 42.0})
    ctx = Context.new(:initialization, now: @now, monotonic_time: 0)
    assert :ok = Loop.validate_execution(object, ctx)
    assert {:ok, simulated} = Loop.execute(object, ctx)
    assert simulated.next_execution == nil
    {:ok, resumed} = Loop.update_property(object, :out_of_service, false)

    ctx =
      context({:property_write, :out_of_service, nil, nil},
        state: simulated.state,
        monotonic_time: 1000
      )

    assert {:ok, pending} = Loop.execute(resumed, ctx)
    assert pending.object.present_value == 42.0
    assert {:ok, _result} = continue(pending, ctx)
  end

  test "returning to service selects automatic mode while waiting for an application reading" do
    uninitialized = ObjectsMacro.get_default_object_ref()

    object =
      object(%{
        out_of_service: true,
        present_value: 42.0,
        controlled_variable_reference: uninitialized,
        manipulated_variable_reference: uninitialized,
        integral_constant: 2.0,
        integral_constant_units: :seconds
      })

    ctx = context(:initialization, read_property: nil, write_property: nil)
    assert {:ok, manual} = Loop.execute(object, ctx)
    {:ok, candidate} = Loop.update_property(manual.object, :out_of_service, false)
    ctx = %{ctx | trigger: {:property_write, :out_of_service, nil, nil}, state: manual.state}
    assert {:ok, automatic} = Loop.execute(candidate, ctx)
    assert automatic.next_execution == nil

    assert {:ok, 42.0, controller} = Controller.step(automatic.state.controller, 21.0, 19.0, 1.0)
    assert {:ok, 44.0, _controller} = Controller.step(controller, 21.0, 19.0, 1.0)
  end

  test "non-finite simulation writes are forwarded and a fresh PID history resumes control" do
    initial = initial(object(%{derivative_constant: 1.0, derivative_constant_units: :seconds}))
    {:ok, simulated} = Loop.update_property(initial.object, :out_of_service, true)
    {:ok, simulated} = Loop.update_property(simulated, :present_value, :NaN)

    ctx =
      context({:property_write, :present_value, nil, nil},
        state: initial.state,
        monotonic_time: 500,
        read_property: nil
      )

    assert {:ok, pending} = Loop.execute(simulated, ctx)
    assert Controller.output(pending.state.controller) == 4.0
    assert {:ok, simulated} = continue(pending, ctx)
    assert_received {:write, _reference, :NaN, 16}
    {:ok, resumed} = Loop.update_property(simulated.object, :out_of_service, false)

    ctx =
      context({:property_write, :out_of_service, nil, nil},
        state: simulated.state,
        monotonic_time: 1000,
        read_property: fn _reference -> {:ok, 20.0} end
      )

    assert {:ok, pending} = Loop.execute(resumed, ctx)
    assert pending.object.present_value == 2.0
  end

  test "a failed first sample after resuming service waits for the next deadline" do
    object = object(%{out_of_service: true, present_value: 42.0})
    {:ok, simulated} = Loop.execute(object, context(:initialization))
    {:ok, resumed} = Loop.update_property(object, :out_of_service, false)

    ctx =
      context({:property_write, :out_of_service, nil, nil},
        state: simulated.state,
        monotonic_time: 500,
        read_property: fn _reference -> {:error, :timeout} end
      )

    assert {:ok, failed} = Loop.execute(resumed, ctx)
    assert failed.next_execution.monotonic_time == 1500

    early =
      context(:timer,
        state: failed.state,
        monotonic_time: 1000,
        read_property: fn _reference -> flunk("early retry") end
      )

    assert {:ok, ^failed} = Loop.execute(failed.object, early)
    assert step(failed, 1500, 19.0).object.present_value == 42.0
  end

  test "BACnet computed writes are rejected and external application values are accepted" do
    object = object()
    refute Loop.property_writable?(object, :present_value)
    refute Loop.property_writable?(object, :controlled_variable_value)

    for property <- [:present_value, :controlled_variable_value, :status_flags] do
      ctx = context({:property_write, property, nil, nil})
      assert {:error, :write_access_denied} = Loop.prepare_write(object, object, ctx)
    end

    identifier = Constants.by_name!(:property_identifier, :present_value)

    assert {:error, :write_access_denied} =
             Loop.prepare_write(object, object, context({:property_write, identifier, nil, nil}))

    external = object(%{}, pid_enabled: false)

    for property <- [:present_value, :controlled_variable_value, :reliability] do
      ctx = context({:application_write, property, nil, nil})
      assert {:ok, ^external} = Loop.prepare_write(external, external, ctx)
    end
  end

  test "read failures retain output, set reliability and recover without integrating across the gap" do
    stored = initial(object(%{integral_constant: 2.0, integral_constant_units: :seconds}))

    ctx =
      context(:timer,
        monotonic_time: 1000,
        state: stored.state,
        read_property: fn _reference -> {:error, :timeout} end
      )

    assert {:ok, failed} = Loop.execute(stored.object, ctx)
    assert failed.object.present_value == 4.0
    assert failed.object.reliability == :communication_failure
    assert failed.object.status_flags.fault
    assert failed.state.last_sample == 0
    assert failed.next_execution.monotonic_time == 2000
    assert failed.state.last_error != nil
    recovered = step(failed, 2000, 19.0)
    assert recovered.object.present_value == 4.0
    assert recovered.object.reliability == :no_fault_detected
    assert recovered.state.last_error == nil
  end

  test "invalid samples and unknown properties report configuration errors" do
    for response <- [
          {:ok, true},
          {:ok, :NaN},
          {:ok, "invalid"},
          {:ok, []},
          {:error, {:unknown_property, :present_value}},
          {:error, :unknown_property}
        ] do
      ctx = context(:initialization, read_property: fn _reference -> response end)
      assert {:ok, failed} = Loop.execute(object(), ctx)
      assert failed.object.reliability == :configuration_error
      assert failed.object.present_value == 0.0
      assert failed.state.pending_write == nil
      assert failed.next_execution.monotonic_time == 1000
    end
  end

  test "write failures retain the computed object and controller and do not repeat the write" do
    ctx =
      context(:initialization,
        write_property: fn _reference, _value, _priority -> {:error, :timeout} end
      )

    assert {:ok, pending} = Loop.execute(object(), ctx)
    assert {:ok, failed} = continue(pending, ctx)
    assert failed.object.present_value == 4.0
    assert failed.state.controller == pending.state.controller
    assert failed.state.last_sample == 0
    assert failed.object.reliability == :communication_failure
    assert failed.next_execution.monotonic_time == 1000

    ctx = %{
      ctx
      | trigger: :continuation,
        state: failed.state,
        write_property: fn _reference, _value, _priority -> flunk("duplicate write") end
    }

    assert {:ok, same} = Loop.execute(failed.object, ctx)
    assert same.state == failed.state
  end

  test "inhibited reliability and objects without reliability still retain operational errors" do
    for properties <- [%{reliability_evaluation_inhibit: true}, %{}] do
      object = object(properties)

      object =
        if properties == %{},
          do: elem(Loop.remove_property(object, :reliability), 1),
          else: object

      ctx = context(:initialization, read_property: fn _reference -> {:error, :timeout} end)
      assert {:ok, result} = Loop.execute(object, ctx)
      assert result.object.reliability == object.reliability
      assert result.state.last_error != nil
    end
  end

  test "PID overflow reports process error and initialization discards previous VM state" do
    huge =
      object(%{
        proportional_constant: 3.0e38,
        integral_constant: 1.0e-300,
        integral_constant_units: :seconds
      })

    stored = initial(huge)
    failed = step(stored, 1000, 19.0)
    assert failed.object.reliability == :process_error
    assert failed.state.last_error == :numeric_overflow
    ctx = context(:initialization, monotonic_time: -5000, state: stored.state)
    assert {:ok, restarted} = Loop.execute(object(), ctx)
    assert restarted.state.last_sample == -5000
    assert restarted.state.last_error == nil
  end

  test "preflight rejects bad settings and missing callbacks without I/O" do
    for {properties, opts} <- [
          {%{}, [pid_enabled: :invalid]},
          {%{}, [pid_derivative_on: :invalid]},
          {%{update_interval: 0}, []},
          {%{min_output: 100.0, max_output: 1.0}, []},
          {%{proportional_constant: -1.0}, []},
          {%{proportional_constant_units: :percent}, []},
          {%{integral_constant: 1.0, integral_constant_units: :degrees_celsius}, []},
          {%{derivative_constant: 1.0, derivative_constant_units: :per_second}, []}
        ] do
      ctx = context(:initialization, read_property: fn _reference -> flunk("preflight I/O") end)
      assert {:error, _reason} = Loop.validate_execution(object(properties, opts), ctx)
    end

    ctx = Context.new(:initialization, now: @now, monotonic_time: 0)

    assert {:error, {:unsupported_operation, :read_property}} =
             Loop.validate_execution(object(), ctx)

    assert {:error, {:unsupported_operation, :write_property}} =
             Loop.validate_execution(object(), %{
               ctx
               | read_property: fn _reference -> {:ok, 19.0} end
             })
  end

  test "an uninitialized controlled-variable reference needs no callbacks or wakeup" do
    {:ok, object} = Loop.create(10, "Unconfigured")
    ctx = context(:initialization, read_property: nil, write_property: nil)

    assert :ok = Loop.validate_execution(object, ctx)
    assert {:ok, %Result{object: ^object, next_execution: nil}} = Loop.execute(object, ctx)

    {:ok, candidate} = Loop.update_property(object, :manipulated_variable_reference, reference(2))
    ctx = %{ctx | trigger: {:property_write, :manipulated_variable_reference, nil, nil}}
    assert {:ok, ^candidate} = Loop.prepare_write(object, candidate, ctx)
    assert {:ok, %Result{object: ^candidate, next_execution: nil}} = Loop.execute(candidate, ctx)
  end

  test "an uninitialized manipulated-variable reference allows local PID output" do
    default = ObjectsMacro.get_default_object_ref()

    target = %{
      reference(2)
      | object_identifier: %{default.object_identifier | type: :analog_output}
    }

    object = object(%{manipulated_variable_reference: target})
    ctx = context(:initialization, write_property: nil)

    assert :ok = Loop.validate_execution(object, ctx)
    assert {:ok, result} = Loop.execute(object, ctx)
    assert result.object.present_value == 4.0
    assert result.object.controlled_variable_value == 19.0
    assert result.object.reliability == :no_fault_detected
    assert result.next_execution.monotonic_time == 1000
    assert result.state.pending_write == nil
  end

  test "an uninitialized setpoint reference selects the fixed setpoint" do
    object =
      object(%{
        setpoint_reference: %SetpointReference{ref: ObjectsMacro.get_default_object_ref()}
      })

    source = device_reference(1)

    ctx = context(:initialization, read_property: fn ^source -> {:ok, 19.0} end)
    assert :ok = Loop.validate_execution(object, ctx)
    assert {:ok, result} = Loop.execute(object, ctx)
    assert result.object.setpoint == 21.0
    assert result.object.present_value == 4.0
    assert result.next_execution == :immediate
  end

  test "restoring the same controlled-variable reference reanchors after a pause" do
    stored = initial(object(%{integral_constant: 2.0, integral_constant_units: :seconds}))

    {:ok, candidate} =
      Loop.update_property(
        stored.object,
        :controlled_variable_reference,
        ObjectsMacro.get_default_object_ref()
      )

    ctx =
      context({:property_write, :controlled_variable_reference, nil, nil},
        state: stored.state,
        monotonic_time: 500,
        read_property: nil,
        write_property: nil
      )

    assert {:ok, ^candidate} = Loop.prepare_write(stored.object, candidate, ctx)
    assert {:ok, paused} = Loop.execute(candidate, ctx)
    assert paused.object == candidate
    assert paused.next_execution == nil

    {:ok, restored} =
      Loop.update_property(paused.object, :controlled_variable_reference, reference(1))

    resumed = step(%{paused | object: restored}, 100_000, 19.0)
    assert resumed.object.present_value == 4.0
    assert step(resumed, 101_000, 19.0).object.present_value == 6.0
  end

  test "application readings drive PID at the configured cadence without sampling wakeups" do
    reference = ObjectsMacro.get_default_object_ref()

    object =
      object(%{
        controlled_variable_reference: reference,
        manipulated_variable_reference: reference,
        integral_constant: 2.0,
        integral_constant_units: :seconds
      })

    ctx = context(:initialization, read_property: nil, write_property: nil)
    assert {:ok, initial} = Loop.execute(object, ctx)
    assert initial.object.present_value == 0.0

    first = submit_measurement(initial, ctx, 0, 19.0)
    assert first.object.present_value == 4.0
    assert first.next_execution == nil

    early = submit_measurement(first, ctx, 500, 20.0)
    assert early.object.controlled_variable_value == 20.0
    assert early.object.present_value == 4.0
    assert early.next_execution == nil

    timer = %{ctx | trigger: :timer, monotonic_time: 1000, state: early.state}
    assert {:ok, ^early} = Loop.execute(early.object, timer)

    due = submit_measurement(early, ctx, 1000, 20.0)
    assert due.object.present_value == 3.0
    assert due.next_execution == nil
    assert submit_measurement(due, ctx, 2000, 20.0).object.present_value == 4.0
  end

  test "application readings can still read a referenced setpoint and command the actuator" do
    object =
      object(%{
        controlled_variable_reference: ObjectsMacro.get_default_object_ref(),
        setpoint_reference: %SetpointReference{ref: reference(3)}
      })

    setpoint = device_reference(3)

    ctx = context(:initialization, read_property: fn ^setpoint -> {:ok, 22.0} end)
    assert {:ok, initial} = Loop.execute(object, ctx)
    pending = submit_measurement(initial, ctx, 0, 19.0)
    assert pending.object.setpoint == 22.0
    assert pending.object.present_value == 6.0
    assert pending.next_execution == :immediate
    assert {:ok, finished} = continue(pending, %{ctx | read_property: nil})
    assert_received {:write, target, 6.0, 16}
    assert target == device_reference(2)
    assert finished.next_execution == nil
  end

  test "built-in control accepts only finite application readings for an unreferenced in-service input" do
    property = Constants.by_name!(:property_identifier, :controlled_variable_value)
    ctx = context({:application_write, property, nil, nil}, read_property: nil)
    uninitialized = ObjectsMacro.get_default_object_ref()
    object = object(%{controlled_variable_reference: uninitialized})

    assert {:ok, ^object} = Loop.prepare_write(object, object, ctx)
    refute Loop.property_writable?(object, :controlled_variable_value)

    for value <- [:NaN, :inf, :infn, 1.0e39] do
      {:ok, candidate} = Loop.update_property(object, :controlled_variable_value, value)

      assert {:error, {:property_out_of_range, :controlled_variable_value}} =
               Loop.prepare_write(object, candidate, ctx)
    end

    for unavailable <- [
          object(),
          object(%{out_of_service: true, controlled_variable_reference: uninitialized})
        ] do
      assert {:error, :write_access_denied} = Loop.prepare_write(unavailable, unavailable, ctx)
    end
  end

  test "out-of-service simulation keeps the local output when the target is uninitialized" do
    {:ok, object} = Loop.create(10, "Unconfigured", %{out_of_service: true})
    {:ok, candidate} = Loop.update_property(object, :present_value, 42.0)

    ctx =
      context({:property_write, :present_value, nil, nil},
        read_property: nil,
        write_property: nil
      )

    assert {:ok, ^candidate} = Loop.prepare_write(object, candidate, ctx)
    assert {:ok, %Result{object: ^candidate, next_execution: nil}} = Loop.execute(candidate, ctx)
  end

  test "preparation rejects invalid configuration atomically and runtime rejects unrelated or backward state" do
    stored = initial(object())
    {:ok, invalid} = Loop.update_property(stored.object, :update_interval, 0)

    ctx =
      context({:property_write, :update_interval, nil, nil},
        state: stored.state,
        monotonic_time: 500
      )

    assert {:error, _reason} = Loop.prepare_write(stored.object, invalid, ctx)
    assert stored.next_execution.monotonic_time == 1000

    for state <- [
          :invalid,
          %{stored.state | identifier: %ObjectIdentifier{type: :loop, instance: 999}}
        ] do
      assert {:error, :invalid_execution_state} =
               Loop.validate_execution(stored.object, %{ctx | state: state})
    end

    assert {:error, :invalid_execution_state} =
             Loop.validate_execution(
               stored.object,
               %{ctx | monotonic_time: -1}
             )
  end

  test "host integration drives local reads, priority writes, retained state and computed reads" do
    {:ok, source} = AnalogValue.create(1, "Sensor", %{present_value: 19.0})

    {:ok, target} =
      AnalogValue.create(2, "Valve", %{priority_array: %BACnet.Protocol.PriorityArray{}})

    loop =
      object(%{
        priority_for_writing: 8,
        integral_constant: 2.0,
        integral_constant_units: :seconds
      })

    id = Loop.get_object_identifier(loop)
    host = Host.new([{source, []}, {target, []}, {loop, []}], @now, 0)
    assert :ok = Host.execute(host, AnalogValue.get_object_identifier(source), :initialization)
    assert :ok = Host.execute(host, AnalogValue.get_object_identifier(target), :initialization)
    assert :ok = Host.execute(host, id, :initialization)
    assert Host.snapshot(host, id).object.present_value == 4.0

    assert Host.snapshot(host, AnalogValue.get_object_identifier(target)).object.present_value ==
             4.0

    Host.advance(host, @now, 1000)

    ref = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: id,
      property_identifier: :present_value,
      property_array_index: nil
    }

    assert {:ok, 6.0} = Host.read(host, ref)
    assert Host.snapshot(host, id).object.present_value == 6.0
  end

  defp object(properties \\ %{}, options \\ []) do
    defaults = %{
      controlled_variable_reference: reference(1),
      manipulated_variable_reference: reference(2),
      setpoint: 21.0,
      proportional_constant: 2.0,
      proportional_constant_units: :no_units,
      min_output: 0.0,
      max_output: 100.0,
      update_interval: 1000,
      reliability: :no_fault_detected
    }

    {:ok, object} = Loop.create(10, "Controller", Map.merge(defaults, properties), options)
    object
  end

  defp reference(instance, index \\ nil) do
    %ObjectPropertyRef{
      object_identifier: %ObjectIdentifier{type: :analog_value, instance: instance},
      property_identifier: :present_value,
      property_array_index: index
    }
  end

  defp device_reference(instance) do
    ref = reference(instance)

    %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: ref.object_identifier,
      property_identifier: ref.property_identifier,
      property_array_index: ref.property_array_index
    }
  end

  defp context(trigger, options \\ []) do
    defaults = [
      now: @now,
      monotonic_time: 0,
      read_property: fn _reference -> {:ok, 19.0} end,
      write_property: fn reference, value, priority ->
        send(self(), {:write, reference, value, priority})
        :ok
      end
    ]

    Context.new(trigger, Keyword.merge(defaults, options))
  end

  defp initial(object, reading \\ 19.0) do
    ctx = context(:initialization, read_property: fn _reference -> {:ok, reading} end)
    {:ok, stored} = Loop.execute(object, ctx)
    {:ok, stored} = continue(stored, ctx)
    flush_writes()
    stored
  end

  defp step(stored, now, reading) do
    ctx =
      context(:timer,
        state: stored.state,
        monotonic_time: now,
        read_property: fn _reference -> {:ok, reading} end
      )

    {:ok, stored} = Loop.execute(stored.object, ctx)
    {:ok, stored} = continue(stored, ctx)
    flush_writes()
    stored
  end

  defp continue(stored, context) do
    Loop.execute(stored.object, %{context | trigger: :continuation, state: stored.state})
  end

  defp submit_measurement(stored, context, time, value) do
    context = %{
      context
      | trigger: {:application_write, :controlled_variable_value, nil, nil},
        monotonic_time: time,
        state: stored.state
    }

    {:ok, candidate} = Loop.update_property(stored.object, :controlled_variable_value, value)
    assert {:ok, prepared} = Loop.prepare_write(stored.object, candidate, context)
    assert {:ok, result} = Loop.execute(prepared, context)
    result
  end

  defp flush_writes() do
    receive do
      {:write, _reference, _value, _priority} -> flush_writes()
    after
      0 -> :ok
    end
  end
end
