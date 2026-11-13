defmodule BACnet.Test.Protocol.ObjectTypes.EventEnrollmentTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.EventMessageTexts
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.FaultParameters
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.EventEnrollment
  alias BACnet.Protocol.ObjectTypes.NotificationClass
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  doctest EventEnrollment

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_event_enrollment

  test "event and fault types follow their parameters on creation and update" do
    event = %EventParameters.UnsignedRange{
      low_limit: 1,
      high_limit: 10,
      time_delay: 0,
      time_delay_normal: nil
    }

    fault = %FaultParameters.FaultCharacterString{fault_values: ["failed"]}

    assert {:ok, object} =
             EventEnrollment.create(1, "enrollment", %{
               notification_class: 1,
               event_parameters: event,
               fault_parameters: fault,
               fault_type: :none
             })

    assert object.event_type == :unsigned_range
    assert object.fault_type == :fault_characterstring

    assert {:ok, object} =
             EventEnrollment.update_property(object, :fault_parameters, %FaultParameters.None{})

    assert object.fault_type == :none

    assert {:ok, object} =
             EventEnrollment.update_property(object, :event_parameters, %EventParameters.None{})

    assert object.event_type == :none
  end

  describe "execution" do
    test "honors elapsed delays, updates transition metadata and preserves the wakeup on reads" do
      object =
        enrollment(%{
          event_parameters: range(5),
          event_message_texts: texts("", "", ""),
          event_message_texts_config: texts("High limit", "Sensor fault", "Recovered"),
          time_delay_normal: 2
        })

      class = notification_class()
      context = context(:initialization, 1_000, input(11), lookup_object: lookup_class(class))
      assert :ok = EventEnrollment.validate_execution(object, context)
      assert {:ok, initial} = EventEnrollment.execute(object, context)
      assert initial.object.event_state == :normal
      assert initial.next_execution == %Wakeup{wall_time: nil, monotonic_time: 6_000}
      assert EventEnrollment.transition(initial) == nil

      read = %{context | trigger: {:property_read, :event_state, nil}, state: initial.state}
      assert {:ok, refreshed} = Lifecycle.prepare_read(initial.object, read)
      assert refreshed.object == initial.object
      assert refreshed.next_execution == initial.next_execution

      changed = %{
        context
        | trigger: :clock_change,
          now: ~U[2026-06-01 15:00:00Z],
          monotonic_time: 5_999,
          state: refreshed.state
      }

      assert {:ok, pending} = EventEnrollment.execute(refreshed.object, changed)
      assert pending.next_execution == initial.next_execution
      assert EventEnrollment.transition(pending) == nil

      due = %{changed | trigger: :timer, monotonic_time: 6_000, state: pending.state}
      assert {:ok, high} = EventEnrollment.execute(pending.object, due)
      assert high.next_execution == nil
      assert high.object.event_state == :high_limit
      assert high.object.status_flags.in_alarm
      refute high.object.status_flags.fault
      refute high.object.acked_transitions.to_offnormal
      assert high.object.event_message_texts.to_offnormal == "High limit"

      assert %{
               transition: :to_offnormal,
               from_state: :normal,
               to_state: :high_limit,
               event_type: :unsigned_range,
               event_values: %NotificationParameters.UnsignedRange{exceeding_value: 11},
               message_text: "High limit",
               enabled: true,
               routing: %{ack_required: true},
               timestamp: stamp
             } = EventEnrollment.transition(high)

      assert EventReporting.transition(high) == EventEnrollment.transition(high)

      assert high.object.event_timestamps.to_offnormal == stamp
      assert stamp.datetime == BACnetDateTime.from_datetime(due.now)

      returning = %{due | trigger: :periodic, read_property: input(5), state: high.state}
      assert {:ok, settling} = EventEnrollment.execute(high.object, returning)
      assert settling.next_execution == %Wakeup{wall_time: nil, monotonic_time: 8_000}
      assert settling.object.event_state == :high_limit

      done = %{returning | trigger: :timer, monotonic_time: 8_000, state: settling.state}
      assert {:ok, normal} = EventEnrollment.execute(settling.object, done)
      assert normal.object.event_state == :normal
      assert normal.object.acked_transitions.to_normal
      refute normal.object.status_flags.in_alarm

      assert %{transition: :to_normal, message_text: "Recovered"} =
               EventEnrollment.transition(normal)
    end

    test "read errors and the monitored object's reliability take precedence over fault detection" do
      reference = reference(:character_string_value, :present_value, 99)
      fault = %FaultParameters.FaultCharacterString{fault_values: ["failed"]}

      object =
        enrollment(%{
          object_property_reference: reference,
          fault_parameters: fault
        })

      timeout = fn ^reference -> {:error, :timeout} end
      assert {:ok, unreachable} = EventEnrollment.execute(object, context(:periodic, 0, timeout))
      assert unreachable.object.reliability == :communication_failure
      assert unreachable.object.event_state == :fault
      assert unreachable.object.status_flags.fault

      assert %{event_type: :change_of_reliability, event_values: unavailable} =
               EventEnrollment.transition(unreachable)

      assert [%PropertyValue{property_identifier: :object_property_reference}] =
               unavailable.property_values

      source_fault = input("failed", :unreliable_other)
      step = context(:periodic, 1, source_fault, state: unreachable.state)
      assert {:ok, monitored} = EventEnrollment.execute(unreachable.object, step)
      assert monitored.object.reliability == :monitored_object_fault

      assert %{from_state: :fault, to_state: :fault, event_values: values} =
               EventEnrollment.transition(monitored)

      assert Enum.map(values.property_values, & &1.property_identifier) ==
               [:object_property_reference, :present_value, :reliability, :status_flags]

      step = context(:periodic, 2, input("failed"), state: monitored.state)
      assert {:ok, faulted} = EventEnrollment.execute(monitored.object, step)
      assert faulted.object.reliability == :multi_state_fault

      assert %{event_type: :change_of_reliability, to_state: :fault} =
               EventEnrollment.transition(faulted)

      step = context(:periodic, 3, input("ok"), state: faulted.state)
      assert {:ok, recovered} = EventEnrollment.execute(faulted.object, step)
      assert recovered.object.reliability == :no_fault_detected
      assert recovered.object.event_state == :normal

      assert %{event_type: :change_of_reliability, to_state: :normal} =
               EventEnrollment.transition(recovered)
    end

    test "remote unknown-property responses are allowed for optional reliability" do
      reference = %{
        reference(:positive_integer_value, :present_value, 99)
        | property_array_index: 2
      }

      object = enrollment(%{object_property_reference: reference, event_parameters: range(0)})

      reader = fn
        ^reference ->
          {:ok, 11}

        %{property_identifier: :reliability, property_array_index: nil} ->
          {:error,
           %APDU.Error{
             invoke_id: 1,
             service: :read_property,
             class: :property,
             code: :unknown_property,
             payload: []
           }}

        %{property_identifier: :status_flags, property_array_index: nil} = sibling ->
          input(nil).(sibling)
      end

      assert {:ok, result} = EventEnrollment.execute(object, context(:periodic, 0, reader))
      assert result.object.event_state == :high_limit
      assert result.object.reliability == :no_fault_detected
    end

    test "fault recovery requests a continuation to evaluate offnormal conditions" do
      object = enrollment(%{event_parameters: range(0), reliability_evaluation_inhibit: false})

      assert {:ok, faulted} =
               EventEnrollment.execute(
                 object,
                 context(:periodic, 0, input(11, :unreliable_other))
               )

      assert faulted.object.event_state == :fault

      assert {:ok, inhibited} =
               EventEnrollment.update_property(
                 faulted.object,
                 :reliability_evaluation_inhibit,
                 true
               )

      context = context(:periodic, 1, input(11, :unreliable_other), state: faulted.state)
      assert {:ok, recovered} = EventEnrollment.execute(inhibited, context)
      assert recovered.object.reliability == :no_fault_detected
      assert recovered.object.event_state == :normal
      assert recovered.next_execution == :immediate

      assert %{event_type: :change_of_reliability, to_state: :normal} =
               EventEnrollment.transition(recovered)

      assert {:ok, alarm} =
               EventEnrollment.execute(recovered.object, %{
                 context
                 | trigger: :continuation,
                   state: recovered.state
               })

      assert alarm.object.event_state == :high_limit
      assert alarm.next_execution == nil
    end

    test "preflight rejects an enabled vendor-specific algorithm" do
      object =
        enrollment(%{
          event_parameters: %EventParameters.Extended{
            vendor_id: 42,
            extended_event_type: 1,
            parameters: []
          }
        })

      context = Context.new(:initialization)

      assert EventEnrollment.validate_execution(object, context) ==
               {:error, {:unsupported_event_algorithm, :extended}}

      assert EventEnrollment.execute(object, context) ==
               {:error, {:unsupported_event_algorithm, :extended}}
    end

    test "an inhibit reference returns to normal, then starts a fresh delay when released" do
      inhibit_ref = %ObjectPropertyRef{
        object_identifier: %ObjectIdentifier{type: :binary_value, instance: 9},
        property_identifier: :present_value,
        property_array_index: nil
      }

      object =
        enrollment(%{
          event_parameters: range(3),
          event_algorithm_inhibit_ref: inhibit_ref
        })

      refute EventEnrollment.property_writable?(object, :event_algorithm_inhibit)

      assert {:ok, candidate} =
               EventEnrollment.update_property(object, :event_algorithm_inhibit, true)

      assert EventEnrollment.prepare_write(
               object,
               candidate,
               Context.new({:property_write, :event_algorithm_inhibit, nil, nil})
             ) == {:error, {:write_access_denied, :event_algorithm_inhibit}}

      reader = fn active ->
        fn
          %{object_identifier: %{instance: 9}} -> {:ok, active}
          ref -> input(11).(ref)
        end
      end

      assert {:ok, initial} =
               EventEnrollment.execute(object, context(:periodic, 0, reader.(:inactive)))

      assert {:ok, alarm} =
               EventEnrollment.execute(
                 initial.object,
                 context(:timer, 3_000, reader.(:inactive), state: initial.state)
               )

      assert alarm.object.event_state == :high_limit

      assert {:ok, inhibited} =
               EventEnrollment.execute(
                 alarm.object,
                 context(:periodic, 4_000, reader.(:active), state: alarm.state)
               )

      assert inhibited.object.event_algorithm_inhibit
      assert inhibited.object.event_state == :normal

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.UnsignedRange{exceeding_value: 11}
             } =
               EventEnrollment.transition(inhibited)

      assert inhibited.next_execution == nil

      assert {:ok, released} =
               EventEnrollment.execute(
                 inhibited.object,
                 context(:periodic, 9_000, reader.(:inactive), state: inhibited.state)
               )

      assert released.object.event_state == :normal
      refute released.object.event_algorithm_inhibit
      assert released.next_execution == %Wakeup{wall_time: nil, monotonic_time: 12_000}

      for {response, expected_reliability} <- [
            {{:error, :unknown_object}, :no_fault_detected},
            {{:error, :timeout}, :configuration_error},
            {{:ok, :invalid}, :configuration_error}
          ] do
        read = fn
          %{object_identifier: %{instance: 9}} -> response
          ref -> input(11).(ref)
        end

        assert {:ok, result} = EventEnrollment.execute(object, context(:periodic, 0, read))
        assert result.object.reliability == expected_reliability
        refute result.object.event_algorithm_inhibit
      end
    end

    test "disabling event detection resets state, timestamps, messages and acknowledgments" do
      object =
        enrollment(%{
          event_parameters: range(0),
          event_message_texts: texts("", "", ""),
          event_message_texts_config: texts("Alarm", "Fault", "Normal")
        })

      context =
        context(:periodic, 0, input(12), lookup_object: lookup_class(notification_class()))

      assert {:ok, alarm} = EventEnrollment.execute(object, context)
      assert alarm.object.event_state == :high_limit
      refute alarm.object.acked_transitions.to_offnormal

      assert {:ok, disabled} =
               EventEnrollment.update_property(alarm.object, :event_detection_enable, false)

      read = fn _reference -> flunk("disabled enrollment tried to read") end

      assert {:ok, reset} =
               EventEnrollment.execute(disabled, context(:periodic, 1, read, state: alarm.state))

      assert reset.object.event_state == :normal
      refute reset.object.status_flags.in_alarm
      assert reset.object.acked_transitions == ObjectsMacro.get_default_event_transbits(true)
      assert reset.object.event_timestamps == object.event_timestamps
      assert reset.object.event_message_texts == object.event_message_texts
      assert reset.next_execution == nil
      assert EventEnrollment.transition(reset) == nil
    end

    test "Buffer Ready emits a same-state transition and carries the record count forward" do
      reference = reference(:trend_log, :total_record_count, nil)

      object =
        enrollment(%{
          event_parameters: %EventParameters.BufferReady{threshold: 2, previous_count: 5},
          object_property_reference: reference
        })

      assert {:ok, notified} =
               EventEnrollment.execute(object, context(:periodic, 0, input(7)))

      assert notified.object.event_parameters.previous_count == 7

      assert %{from_state: :normal, to_state: :normal, event_values: payload} =
               EventEnrollment.transition(notified)

      assert payload.buffer_property == %{reference | property_identifier: :log_buffer}

      assert {:ok, still} =
               EventEnrollment.execute(
                 notified.object,
                 context(:periodic, 1, input(7), state: notified.state)
               )

      assert EventEnrollment.transition(still) == nil
    end

    test "Command Failure resolves the configured feedback reference" do
      command_ref = reference(:binary_output, :present_value, nil)
      feedback_ref = %{command_ref | property_identifier: :feedback_value}

      object =
        enrollment(%{
          event_algorithm_inhibit_ref: ObjectsMacro.get_default_object_ref(),
          event_parameters: %EventParameters.CommandFailure{
            feedback_value: feedback_ref,
            time_delay: 0
          },
          object_property_reference: command_ref
        })

      command = Encoding.create!({:enumerated, 1})
      feedback = Encoding.create!({:enumerated, 0})

      read = fn
        ^command_ref -> {:ok, command}
        ^feedback_ref -> {:ok, feedback}
        ref -> input(nil).(ref)
      end

      assert {:ok, result} = EventEnrollment.execute(object, context(:periodic, 0, read))
      assert result.object.event_state == :offnormal
      assert result.object.event_parameters.feedback_value == feedback_ref

      assert %{
               event_values: %NotificationParameters.CommandFailure{
                 command_value: ^command,
                 feedback_value: ^feedback
               }
             } =
               EventEnrollment.transition(result)

      inhibited = inhibit(result, command, inputs: %{feedback_ref => feedback})

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.CommandFailure{
                 command_value: ^command,
                 feedback_value: ^feedback,
                 status_flags: %StatusFlags{in_alarm: false}
               }
             } = EventEnrollment.transition(inhibited)
    end

    test "Event_Enable controls distribution while keeping the transition and acknowledgment state" do
      object =
        enrollment(%{
          event_parameters: range(0),
          event_enable: ObjectsMacro.get_default_event_transbits(false)
        })

      assert {:ok, result} =
               EventEnrollment.execute(
                 object,
                 context(:periodic, 0, input(11),
                   lookup_object: lookup_class(notification_class())
                 )
               )

      assert %{enabled: false, timestamp: stamp} = EventEnrollment.transition(result)
      assert result.object.event_timestamps.to_offnormal == stamp
      refute result.object.acked_transitions.to_offnormal

      assert EventEnrollment.acknowledge(
               result.object,
               :to_offnormal,
               object.event_timestamps.to_offnormal
             ) ==
               {:error, {:services, :invalid_timestamp}}

      assert {:ok, acknowledged} =
               EventEnrollment.acknowledge(result.object, :to_offnormal, stamp)

      assert acknowledged.acked_transitions.to_offnormal
    end

    test "remote snapshots are passive and reject lifecycle writes" do
      local = enrollment(%{event_parameters: range(0)})

      properties =
        local
        |> Map.from_struct()
        |> Map.take(local._metadata.properties_list)
        |> Map.drop([:object_instance, :object_name])

      assert {:ok, remote} = EventEnrollment.create(3, "Remote", properties, remote_object: 4)
      read = fn _reference -> flunk("remote snapshot tried to read") end
      context = context(:periodic, 0, read, state: :retained)
      assert :ok = EventEnrollment.validate_execution(remote, context)

      assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil} = result} =
               EventEnrollment.execute(remote, context)

      assert EventEnrollment.transition(result) == nil

      assert EventEnrollment.prepare_write(remote, remote, context) ==
               {:error, :operation_not_available_for_remote_objects}

      assert EventEnrollment.acknowledge(remote, :to_normal, local.event_timestamps.to_normal) ==
               {:error, :operation_not_available_for_remote_objects}
    end
  end

  describe "event algorithm inputs and transitions" do
    test "ChangeOfBitstring applies its mask and reports the full monitored bitstring" do
      object =
        enrollment(%{
          event_algorithm_inhibit_ref: ObjectsMacro.get_default_object_ref(),
          object_property_reference: reference(:bitstring_value, :present_value, nil),
          event_parameters: %EventParameters.ChangeOfBitstring{
            alarm_values: [{true, false}],
            bitmask: {true, false},
            time_delay: 0
          }
        })

      initial = evaluate_sample(object, {false, true})
      assert EventEnrollment.transition(initial) == nil

      alarm = evaluate_sample(initial.object, {true, true}, state: initial.state)
      assert alarm.object.event_state == :offnormal

      assert %{
               event_type: :change_of_bitstring,
               event_values: %NotificationParameters.ChangeOfBitstring{
                 referenced_bitstring: {true, true},
                 status_flags: %StatusFlags{in_alarm: true}
               }
             } = EventEnrollment.transition(alarm)

      normal = evaluate_sample(alarm.object, {false, true}, state: alarm.state)
      assert normal.object.event_state == :normal

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.ChangeOfBitstring{
                 referenced_bitstring: {false, true}
               }
             } = EventEnrollment.transition(normal)

      inhibited = inhibit(alarm, {true, true})

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.ChangeOfBitstring{
                 referenced_bitstring: {true, true},
                 status_flags: %StatusFlags{in_alarm: false}
               }
             } = EventEnrollment.transition(inhibited)
    end

    test "ChangeOfState wraps a native value in the configured property state type" do
      active = %PropertyState{type: :binary_value, value: true}
      inactive = %PropertyState{type: :binary_value, value: false}

      object =
        enrollment(%{
          object_property_reference: reference(:binary_input, :present_value, nil),
          event_parameters: %EventParameters.ChangeOfState{
            alarm_values: [active],
            time_delay: 0
          }
        })

      alarm = evaluate_sample(object, true)
      assert alarm.object.event_state == :offnormal

      assert %{
               event_type: :change_of_state,
               event_values: %NotificationParameters.ChangeOfState{new_state: ^active}
             } = EventEnrollment.transition(alarm)

      normal = evaluate_sample(alarm.object, false, state: alarm.state)
      assert normal.object.event_state == :normal

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.ChangeOfState{new_state: ^inactive}
             } = EventEnrollment.transition(normal)
    end

    test "ChangeOfValue retains its numeric baseline and emits a same-state transition" do
      object =
        enrollment(%{
          object_property_reference: reference(:analog_value, :present_value, nil),
          event_parameters: %EventParameters.ChangeOfValue{increment: 2.0, time_delay: 0}
        })

      baseline = evaluate_sample(object, 10.0)
      assert EventEnrollment.transition(baseline) == nil

      below_threshold = evaluate_sample(baseline.object, 11.0, state: baseline.state)
      assert EventEnrollment.transition(below_threshold) == nil

      changed = evaluate_sample(below_threshold.object, 12.0, state: below_threshold.state)
      assert changed.object.event_state == :normal

      assert %{
               from_state: :normal,
               to_state: :normal,
               transition: :to_normal,
               event_type: :change_of_value,
               event_values: %NotificationParameters.ChangeOfValue{
                 changed_value: 12.0,
                 changed_bits: nil
               }
             } = EventEnrollment.transition(changed)

      unchanged = evaluate_sample(changed.object, 12.0, state: changed.state)
      assert EventEnrollment.transition(unchanged) == nil
    end

    test "ChangeOfValue can monitor a bitstring using its configured bitmask" do
      object =
        enrollment(%{
          object_property_reference: reference(:bitstring_value, :present_value, nil),
          event_parameters: %EventParameters.ChangeOfValue{bitmask: {true, false}, time_delay: 0}
        })

      baseline = evaluate_sample(object, {false, false})
      masked = evaluate_sample(baseline.object, {false, true}, state: baseline.state)
      assert EventEnrollment.transition(masked) == nil

      changed = evaluate_sample(masked.object, {true, true}, state: masked.state)
      assert changed.object.event_state == :normal

      assert %{
               transition: :to_normal,
               event_type: :change_of_value,
               event_values: %NotificationParameters.ChangeOfValue{
                 changed_bits: {true, true},
                 changed_value: nil
               }
             } = EventEnrollment.transition(changed)
    end

    test "ChangeOfLifeSafety reads the mode reference and the monitored object's expected operation" do
      monitored = reference(:life_safety_point, :present_value, nil)
      mode = reference(:life_safety_zone, :mode, 99)
      operation = %{monitored | property_identifier: :operation_expected}

      object =
        enrollment(%{
          event_algorithm_inhibit_ref: ObjectsMacro.get_default_object_ref(),
          object_property_reference: monitored,
          event_parameters: %EventParameters.ChangeOfLifeSafety{
            mode: mode,
            alarm_values: [:pre_alarm],
            life_safety_alarm_values: [:alarm],
            time_delay: 0
          }
        })

      alarm = evaluate_sample(object, :alarm, inputs: %{mode => :on, operation => :reset_alarm})
      assert alarm.object.event_state == :life_safety_alarm

      assert %{
               event_type: :change_of_life_safety,
               event_values: %NotificationParameters.ChangeOfLifeSafety{
                 new_state: :alarm,
                 new_mode: :on,
                 operation_expected: :reset_alarm
               }
             } = EventEnrollment.transition(alarm)

      normal =
        evaluate_sample(alarm.object, :quiet,
          inputs: %{mode => :test, operation => :none},
          state: alarm.state
        )

      assert normal.object.event_state == :normal

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.ChangeOfLifeSafety{
                 new_state: :quiet,
                 new_mode: :test,
                 operation_expected: :none
               }
             } = EventEnrollment.transition(normal)

      inhibited = inhibit(alarm, :alarm, inputs: %{mode => :on, operation => :reset_alarm})

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.ChangeOfLifeSafety{
                 new_state: :alarm,
                 new_mode: :on,
                 operation_expected: :reset_alarm,
                 status_flags: %StatusFlags{in_alarm: false}
               }
             } = EventEnrollment.transition(inhibited)
    end

    test "ChangeOfCharacterString reports the monitored string and the matching alarm value" do
      object =
        enrollment(%{
          event_algorithm_inhibit_ref: ObjectsMacro.get_default_object_ref(),
          object_property_reference: reference(:character_string_value, :present_value, nil),
          event_parameters: %EventParameters.ChangeOfCharacterString{
            alarm_values: ["fault"],
            time_delay: 0
          }
        })

      alarm = evaluate_sample(object, "sensor fault detected")
      assert alarm.object.event_state == :offnormal

      assert %{
               event_type: :change_of_characterstring,
               event_values: %NotificationParameters.ChangeOfCharacterString{
                 alarm_value: "fault",
                 changed_value: "sensor fault detected"
               }
             } = EventEnrollment.transition(alarm)

      normal = evaluate_sample(alarm.object, "ready", state: alarm.state)
      assert normal.object.event_state == :normal

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.ChangeOfCharacterString{
                 alarm_value: "fault",
                 changed_value: "ready"
               }
             } = EventEnrollment.transition(normal)

      inhibited = inhibit(alarm, "sensor fault persists")

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.ChangeOfCharacterString{
                 alarm_value: "fault",
                 changed_value: "sensor fault persists",
                 status_flags: %StatusFlags{in_alarm: false}
               }
             } = EventEnrollment.transition(inhibited)
    end

    test "ChangeOfStatusFlags reads and encodes the monitored object's present value" do
      monitored = reference(:positive_integer_value, :status_flags, nil)
      present = %{monitored | property_identifier: :present_value}
      selected = StatusFlags.from_bitstring({false, false, true, false})
      flags = StatusFlags.from_bitstring({false, false, true, true})
      cleared = StatusFlags.from_bitstring({false, false, false, true})

      object =
        enrollment(%{
          event_algorithm_inhibit_ref: ObjectsMacro.get_default_object_ref(),
          object_property_reference: monitored,
          event_parameters: %EventParameters.ChangeOfStatusFlags{
            selected_flags: selected,
            time_delay: 0
          }
        })

      alarm = evaluate_sample(object, flags, inputs: %{present => 41})
      assert alarm.object.event_state == :offnormal

      assert %{
               event_type: :change_of_status_flags,
               event_values: %NotificationParameters.ChangeOfStatusFlags{
                 referenced_flags: ^flags,
                 present_value: %Encoding{type: :unsigned_integer, value: 41}
               }
             } = EventEnrollment.transition(alarm)

      normal =
        evaluate_sample(alarm.object, cleared, inputs: %{present => 42}, state: alarm.state)

      assert normal.object.event_state == :normal

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.ChangeOfStatusFlags{
                 referenced_flags: ^cleared,
                 present_value: %Encoding{type: :unsigned_integer, value: 42}
               }
             } = EventEnrollment.transition(normal)

      inhibited =
        inhibit(alarm, flags, inputs: %{present => Encoding.create!({:unsigned_integer, 43})})

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.ChangeOfStatusFlags{
                 referenced_flags: ^flags,
                 present_value: %Encoding{type: :unsigned_integer, value: 43}
               }
             } = EventEnrollment.transition(inhibited)

      absent = evaluate_sample(object, flags, inputs: %{present => nil})

      assert %{event_values: %NotificationParameters.ChangeOfStatusFlags{present_value: nil}} =
               EventEnrollment.transition(absent)
    end

    test "FloatingLimit reads the configured setpoint on each evaluation" do
      setpoint = reference(:analog_value, :present_value, 99)

      object =
        enrollment(%{
          event_algorithm_inhibit_ref: ObjectsMacro.get_default_object_ref(),
          object_property_reference: reference(:analog_value, :present_value, nil),
          event_parameters: %EventParameters.FloatingLimit{
            setpoint: setpoint,
            low_diff_limit: 2.0,
            high_diff_limit: 3.0,
            deadband: 1.0,
            time_delay: 0
          }
        })

      alarm = evaluate_sample(object, 14.0, inputs: %{setpoint => 10.0})
      assert alarm.object.event_state == :high_limit

      assert %{
               event_type: :floating_limit,
               event_values: %NotificationParameters.FloatingLimit{
                 reference_value: 14.0,
                 setpoint_value: 10.0,
                 error_limit: 3.0
               }
             } = EventEnrollment.transition(alarm)

      normal =
        evaluate_sample(alarm.object, 14.0, inputs: %{setpoint => 13.0}, state: alarm.state)

      assert normal.object.event_state == :normal

      assert %{
               transition: :to_normal,
               event_values: %NotificationParameters.FloatingLimit{setpoint_value: 13.0}
             } = EventEnrollment.transition(normal)

      low = evaluate_sample(object, 7.0, inputs: %{setpoint => 10.0})
      assert low.object.event_state == :low_limit

      for {alarm, value, limit} <- [{alarm, 14.0, 3.0}, {low, 7.0, 2.0}] do
        inhibited = inhibit(alarm, value, inputs: %{setpoint => 10.0})

        assert %{
                 transition: :to_normal,
                 event_values: %NotificationParameters.FloatingLimit{
                   reference_value: ^value,
                   setpoint_value: 10.0,
                   error_limit: ^limit,
                   status_flags: %StatusFlags{in_alarm: false}
                 }
               } = EventEnrollment.transition(inhibited)
      end
    end

    for {event_type, parameters_module, notification_module, object_type, low, high, deadband} <-
          [
            {:out_of_range, EventParameters.OutOfRange, NotificationParameters.OutOfRange,
             :analog_value, 1.0, 10.0, 1.0},
            {:double_out_of_range, EventParameters.DoubleOutOfRange,
             NotificationParameters.DoubleOutOfRange, :large_analog_value, 1.0, 10.0, 1.0},
            {:signed_out_of_range, EventParameters.SignedOutOfRange,
             NotificationParameters.SignedOutOfRange, :integer_value, -10, 10, 1},
            {:unsigned_out_of_range, EventParameters.UnsignedOutOfRange,
             NotificationParameters.UnsignedOutOfRange, :positive_integer_value, 1, 10, 1}
          ] do
      test "#{event_type} evaluates both limits and reports a typed transition payload" do
        event_type = unquote(event_type)
        notification_module = unquote(notification_module)
        low = unquote(low)
        high = unquote(high)
        deadband = unquote(deadband)
        above = high + deadband
        below = low - deadband
        in_range = low + 2 * deadband

        object =
          enrollment(%{
            event_algorithm_inhibit_ref: ObjectsMacro.get_default_object_ref(),
            object_property_reference: reference(unquote(object_type), :present_value, nil),
            event_parameters:
              struct!(unquote(parameters_module),
                low_limit: low,
                high_limit: high,
                deadband: deadband,
                time_delay: 0
              )
          })

        high_alarm = evaluate_sample(object, above)
        assert high_alarm.object.event_state == :high_limit

        assert %{
                 event_type: ^event_type,
                 transition: :to_offnormal,
                 to_state: :high_limit,
                 event_values: %{
                   __struct__: ^notification_module,
                   exceeding_value: ^above,
                   exceeded_limit: ^high,
                   deadband: ^deadband
                 }
               } = EventEnrollment.transition(high_alarm)

        recovered = evaluate_sample(high_alarm.object, in_range, state: high_alarm.state)
        assert recovered.object.event_state == :normal

        assert %{
                 transition: :to_normal,
                 event_values: %{__struct__: ^notification_module, exceeded_limit: ^high}
               } = EventEnrollment.transition(recovered)

        low_alarm = evaluate_sample(recovered.object, below, state: recovered.state)
        assert low_alarm.object.event_state == :low_limit

        assert %{
                 event_type: ^event_type,
                 to_state: :low_limit,
                 event_values: %{
                   __struct__: ^notification_module,
                   exceeding_value: ^below,
                   exceeded_limit: ^low,
                   deadband: ^deadband
                 }
               } = EventEnrollment.transition(low_alarm)

        inhibited = inhibit(low_alarm, below)

        assert %{
                 transition: :to_normal,
                 event_values: %{
                   __struct__: ^notification_module,
                   exceeding_value: ^below,
                   exceeded_limit: ^low,
                   deadband: ^deadband,
                   status_flags: %StatusFlags{in_alarm: false}
                 }
               } = EventEnrollment.transition(inhibited)
      end
    end
  end

  describe "fault algorithm inputs and transitions" do
    test "FaultLifeSafety reads the mode reference and reports a same-fault transition when it changes" do
      mode = reference(:life_safety_zone, :mode, 99)

      object =
        enrollment(%{
          object_property_reference: reference(:life_safety_point, :present_value, nil),
          fault_parameters: %FaultParameters.FaultLifeSafety{mode: mode, fault_values: [:fault]}
        })

      fault = evaluate_sample(object, :fault, inputs: %{mode => :on})
      assert_fault_transition(fault, :normal, :fault, :multi_state_fault)

      unchanged =
        evaluate_sample(fault.object, :fault, inputs: %{mode => :on}, state: fault.state)

      assert EventEnrollment.transition(unchanged) == nil

      changed =
        evaluate_sample(unchanged.object, :fault,
          inputs: %{mode => :test},
          state: unchanged.state
        )

      assert_fault_transition(changed, :fault, :fault, :multi_state_fault)

      recovered =
        evaluate_sample(changed.object, :quiet, inputs: %{mode => :test}, state: changed.state)

      assert_fault_transition(recovered, :fault, :normal, :no_fault_detected)
    end

    test "FaultState compares the monitored native value using the configured property state type" do
      object =
        enrollment(%{
          object_property_reference: reference(:multi_state_input, :present_value, nil),
          fault_parameters: %FaultParameters.FaultState{
            fault_values: [%PropertyState{type: :unsigned_value, value: 3}]
          }
        })

      fault = evaluate_sample(object, 3)
      assert_fault_transition(fault, :normal, :fault, :multi_state_fault)

      recovered = evaluate_sample(fault.object, 2, state: fault.state)
      assert_fault_transition(recovered, :fault, :normal, :no_fault_detected)
    end

    test "FaultStatusFlags detects the fault bit from its own configured reference" do
      status = reference(:binary_input, :status_flags, 99)

      object =
        enrollment(%{
          fault_parameters: %FaultParameters.FaultStatusFlags{status_flags: status}
        })

      fault_flags = StatusFlags.from_bitstring({false, true, false, false})
      normal_flags = StatusFlags.from_bitstring({true, false, false, false})
      fault = evaluate_sample(object, 42, inputs: %{status => fault_flags})
      assert_fault_transition(fault, :normal, :fault, :member_fault)

      recovered =
        evaluate_sample(fault.object, 42, inputs: %{status => normal_flags}, state: fault.state)

      assert_fault_transition(recovered, :fault, :normal, :no_fault_detected)
    end

    test "NONE event and fault parameters can execute without a configured reference" do
      assert {:ok, object} =
               EventEnrollment.create(1, "Enrollment", %{
                 notification_class: 7,
                 event_parameters: %EventParameters.None{},
                 fault_parameters: %FaultParameters.None{}
               })

      read = fn reference ->
        flunk("unconfigured enrollment tried to read #{inspect(reference)}")
      end

      assert {:ok, result} = EventEnrollment.execute(object, context(:initialization, 0, read))
      assert result.object.event_state == :normal
      assert result.object.reliability == :no_fault_detected
      assert result.next_execution == nil
      assert EventEnrollment.transition(result) == nil
    end
  end

  test "inhibited enrollment clears pending work and suppresses acquisition faults" do
    object =
      enrollment(%{
        event_parameters: range(5),
        event_algorithm_inhibit_ref: ObjectsMacro.get_default_object_ref(),
        reliability_evaluation_inhibit: true
      })

    assert EventEnrollment.property_writable?(object, :event_algorithm_inhibit)
    assert EventEnrollment.property_writable?(object, :event_detection_enable)
    refute EventEnrollment.property_writable?(object, :event_state)

    pending = evaluate_sample(object, 11)
    assert %Wakeup{} = pending.next_execution

    read =
      context({:property_read, :event_state, nil}, 0, fn _arg -> flunk("unexpected read") end)

    assert {:ok, %Result{object: ^object, state: nil, next_execution: nil}} =
             EventEnrollment.execute(object, read)

    inhibited = inhibit(pending, 11)
    assert inhibited.object.event_state == :normal
    assert inhibited.next_execution == nil
    assert EventEnrollment.transition(inhibited) == nil

    failed_read = context(:periodic, 1, fn _ref -> {:error, :timeout} end, state: pending.state)
    assert {:ok, suppressed} = EventEnrollment.execute(pending.object, failed_read)
    assert suppressed.object.reliability == :no_fault_detected
    assert suppressed.next_execution == nil
    assert EventEnrollment.transition(suppressed) == nil
  end

  test "invalid event and fault samples report a configuration fault" do
    object = enrollment(%{event_parameters: range(0)})
    ref = object.object_property_reference
    flags = %{ref | property_identifier: :status_flags}

    fault =
      enrollment(%{
        fault_parameters: %FaultParameters.FaultCharacterString{fault_values: ["failed"]}
      })

    for result <- [
          evaluate_sample(object, "wrong type"),
          evaluate_sample(object, 11, inputs: %{flags => :invalid}),
          evaluate_sample(fault, 11)
        ] do
      assert_fault_transition(result, :normal, :fault, :configuration_error)
    end

    for error <- [
          :unknown_object,
          {:unknown_property, ref},
          {:unsupported_operation, :read_property}
        ] do
      assert {:ok, result} =
               EventEnrollment.execute(
                 object,
                 context(:periodic, 0, fn ^ref -> {:error, error} end)
               )

      assert_fault_transition(result, :normal, :fault, :configuration_error)
    end
  end

  test "ChangeOfState accepts typed states and infers primitive types with an empty alarm list" do
    object =
      enrollment(%{
        event_parameters: %EventParameters.ChangeOfState{alarm_values: [], time_delay: 0}
      })

    for value <- [true, 1, -1, %PropertyState{type: :binary_value, value: true}] do
      result = evaluate_sample(object, value)
      assert result.object.reliability == :no_fault_detected
      assert result.object.event_state == :normal
      assert EventEnrollment.transition(result) == nil
    end

    assert_fault_transition(
      evaluate_sample(object, "invalid state"),
      :normal,
      :fault,
      :configuration_error
    )
  end

  test "disabling detection while reliability evaluation is inhibited clears the fault" do
    object =
      enrollment(%{
        event_parameters: range(0),
        event_detection_enable: false,
        reliability_evaluation_inhibit: true,
        reliability: :configuration_error
      })

    read = fn _reference -> flunk("disabled enrollment tried to read") end

    assert {:ok, reset} = EventEnrollment.execute(object, context(:periodic, 0, read))
    assert reset.object.event_state == :normal
    assert reset.object.reliability == :no_fault_detected
  end

  test "an inhibited offnormal enrollment faults when monitored status flags cannot be read" do
    object =
      enrollment(%{
        event_parameters: range(0),
        event_algorithm_inhibit: false,
        event_algorithm_inhibit_ref: ObjectsMacro.get_default_object_ref()
      })

    assert {:ok, alarm} = EventEnrollment.execute(object, context(:periodic, 0, input(11)))
    assert alarm.object.event_state == :high_limit

    assert {:ok, inhibited} =
             EventEnrollment.update_property(alarm.object, :event_algorithm_inhibit, true)

    read = fn
      %{property_identifier: :status_flags} -> {:error, :timeout}
      %{property_identifier: :reliability} -> {:ok, :no_fault_detected}
      %{property_identifier: :present_value} -> {:ok, 11}
    end

    assert {:ok, failed} =
             EventEnrollment.execute(
               inhibited,
               context(:periodic, 1, read, state: alarm.state)
             )

    assert_fault_transition(failed, :high_limit, :fault, :configuration_error)
  end

  test "inhibited reliability evaluation clears an existing fault when acquisition fails" do
    object =
      enrollment(%{
        event_parameters: range(0),
        reliability_evaluation_inhibit: false
      })

    read = fn
      %{property_identifier: :reliability} -> {:ok, :unreliable_other}
      reference -> input(11).(reference)
    end

    assert {:ok, fault} = EventEnrollment.execute(object, context(:periodic, 0, read))
    assert fault.object.event_state == :fault

    assert {:ok, inhibited} =
             EventEnrollment.update_property(fault.object, :reliability_evaluation_inhibit, true)

    assert {:ok, cleared} =
             EventEnrollment.execute(
               inhibited,
               context(:periodic, 1, fn _reference -> {:error, :timeout} end, state: fault.state)
             )

    assert cleared.object.event_state == :normal
    assert cleared.object.reliability == :no_fault_detected
  end

  test "a retained ChangeOfState delay that is already due produces no wakeup" do
    active = %PropertyState{type: :binary_value, value: true}

    object =
      enrollment(%{
        object_property_reference: reference(:binary_input, :present_value, nil),
        event_parameters: %EventParameters.ChangeOfState{
          alarm_values: [active],
          time_delay: 5
        }
      })

    assert {:ok, pending} = EventEnrollment.execute(object, context(:periodic, 0, input(true)))
    assert pending.object.event_state == :normal
    assert %Wakeup{} = pending.next_execution

    assert {:ok, expired} =
             EventEnrollment.execute(
               pending.object,
               context(:periodic, 6_000, input(false), state: pending.state)
             )

    assert expired.object.event_state == :normal
    assert expired.next_execution == nil
    assert EventEnrollment.transition(expired) == nil
  end

  test "an uninitialized monitored reference is a configuration fault" do
    assert {:ok, object} =
             EventEnrollment.create(1, "Enrollment", %{
               notification_class: 7,
               event_parameters: range(0)
             })

    read = fn reference ->
      flunk("unconfigured enrollment tried to read #{inspect(reference)}")
    end

    assert {:ok, result} = EventEnrollment.execute(object, context(:initialization, 0, read))
    assert_fault_transition(result, :normal, :fault, :configuration_error)
  end

  test "a corrupted delay timestamp is reported as a configuration fault" do
    object = enrollment(%{event_parameters: range(5)})
    assert {:ok, pending} = EventEnrollment.execute(object, context(:periodic, 0, input(11)))
    assert pending.object.event_state == :normal
    state = put_in(pending.state.event.dt_offnormal, :bogus).state

    assert {:ok, failed} =
             EventEnrollment.execute(
               pending.object,
               context(:periodic, 1, input(11), state: state)
             )

    assert_fault_transition(failed, :normal, :fault, :configuration_error)
  end

  test "a faulted monitored value that is already encoded is kept" do
    reference = reference(:binary_output, :present_value, nil)
    encoding = Encoding.create!({:enumerated, 1})

    object =
      enrollment(%{
        object_property_reference: reference,
        event_parameters: range(0)
      })

    read = fn
      ^reference ->
        {:ok, encoding}

      %{property_identifier: :reliability} ->
        {:ok, :unreliable_other}

      %{property_identifier: :status_flags} ->
        {:ok, StatusFlags.from_bitstring({false, false, false, false})}
    end

    assert {:ok, fault} = EventEnrollment.execute(object, context(:periodic, 0, read))
    assert_fault_transition(fault, :normal, :fault, :monitored_object_fault)

    monitored =
      Enum.find(EventEnrollment.transition(fault).event_values.property_values, fn value ->
        value.property_identifier == :present_value
      end)

    assert monitored.property_value == encoding
  end

  test "an unknown numeric monitored property is a configuration fault" do
    command = reference(:binary_output, 600, nil)
    feedback = reference(:binary_output, :feedback_value, nil)

    object =
      enrollment(%{
        object_property_reference: command,
        event_parameters: %EventParameters.CommandFailure{
          feedback_value: feedback,
          time_delay: 0
        }
      })

    read = fn
      ^command -> {:ok, true}
      ^feedback -> {:ok, false}
      reference -> input(true).(reference)
    end

    assert {:ok, fault} = EventEnrollment.execute(object, context(:periodic, 0, read))
    assert_fault_transition(fault, :normal, :fault, :configuration_error)
  end

  defp inhibit(result, value, options \\ []) do
    assert {:ok, object} =
             EventEnrollment.update_property(result.object, :event_algorithm_inhibit, true)

    evaluate_sample(object, value, Keyword.put(options, :state, result.state))
  end

  defp evaluate_sample(object, value, options \\ []) do
    reference = object.object_property_reference

    inputs = %{
      %{reference | property_identifier: :reliability, property_array_index: nil} =>
        :no_fault_detected,
      %{reference | property_identifier: :status_flags, property_array_index: nil} =>
        StatusFlags.from_bitstring({false, false, false, false}),
      reference => value
    }

    inputs = Map.merge(inputs, Keyword.get(options, :inputs, %{}))
    read = fn ref -> {:ok, Map.fetch!(inputs, ref)} end
    context = context(:periodic, 0, read, state: options[:state])
    assert {:ok, result} = EventEnrollment.execute(object, context)
    result
  end

  defp assert_fault_transition(result, from_state, to_state, reliability) do
    assert result.object.event_state == to_state
    assert result.object.reliability == reliability
    assert result.object.status_flags.fault == (to_state == :fault)

    assert %{
             from_state: ^from_state,
             to_state: ^to_state,
             event_type: :change_of_reliability,
             event_values: %NotificationParameters.ChangeOfReliability{
               reliability: ^reliability,
               status_flags: flags
             }
           } = EventEnrollment.transition(result)

    assert flags == result.object.status_flags
  end

  defp enrollment(properties) do
    defaults = %{
      notification_class: 7,
      object_property_reference: reference(:positive_integer_value, :present_value, nil)
    }

    {:ok, object} = EventEnrollment.create(1, "Enrollment", Map.merge(defaults, properties))
    object
  end

  defp reference(type, property, device) do
    %DeviceObjectPropertyRef{
      object_identifier: %ObjectIdentifier{type: type, instance: 2},
      property_identifier: property,
      property_array_index: nil,
      device_identifier: if(device, do: %ObjectIdentifier{type: :device, instance: device})
    }
  end

  defp range(delay) do
    %EventParameters.UnsignedRange{
      low_limit: 1,
      high_limit: 10,
      time_delay: delay,
      time_delay_normal: nil
    }
  end

  defp context(trigger, monotonic, read, options \\ []) do
    Context.new(
      trigger,
      Keyword.merge(
        [now: ~U[2026-06-01 12:00:00Z], monotonic_time: monotonic, read_property: read],
        options
      )
    )
  end

  defp input(value, reliability \\ :no_fault_detected) do
    fn
      %{property_identifier: :reliability} ->
        {:ok, reliability}

      %{property_identifier: :status_flags} ->
        {:ok, StatusFlags.from_bitstring({false, false, false, false})}

      %{property_identifier: property} when property in [:present_value, :total_record_count] ->
        {:ok, value}
    end
  end

  defp notification_class() do
    {:ok, class} =
      NotificationClass.create(7, "Notify", %{
        notification_class: 7,
        ack_required: %EventTransitionBits{to_offnormal: true, to_fault: false, to_normal: false}
      })

    class
  end

  defp lookup_class(class) do
    fn %DeviceObjectRef{
         object_identifier: %ObjectIdentifier{type: :notification_class, instance: 7}
       } ->
      {:ok, class}
    end
  end

  defp texts(offnormal, fault, normal) do
    %EventMessageTexts{to_offnormal: offnormal, to_fault: fault, to_normal: normal}
  end
end
