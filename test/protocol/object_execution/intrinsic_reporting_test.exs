defmodule BACnet.Test.Protocol.ObjectExecution.IntrinsicReportingTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.FaultAlgorithms
  alias BACnet.Protocol.FaultParameters
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.AnalogInput
  alias BACnet.Protocol.ObjectTypes.BinaryValue
  alias BACnet.Protocol.ObjectTypes.EventLog
  alias BACnet.Protocol.ObjectTypes.MultistateInput
  alias BACnet.Protocol.StatusFlags
  alias BACnet.Stack.TrendLogger

  doctest IntrinsicReporting

  defmodule LifeSafetySource do
    alias BACnet.Protocol.Constants
    alias BACnet.Protocol.StatusFlags

    use BACnet.Protocol.ObjectsMacro

    @type object_opts :: common_object_opts()

    bac_object :life_safety_point do
      services(intrinsic: true)

      field(:present_value, Constants.life_safety_state(), required: true, default: :quiet)
      field(:mode, Constants.life_safety_mode(), required: true, default: :on)
      field(:fault_values, [Constants.life_safety_state()], required: true, default: [])
      field(:reliability, Constants.reliability(), required: true)
      field(:event_state, Constants.event_state(), required: true)
      field(:status_flags, StatusFlags.t(), required: true)
    end
  end

  defmodule MemberStatusSource do
    alias BACnet.Protocol.Constants
    alias BACnet.Protocol.StatusFlags

    use BACnet.Protocol.ObjectsMacro

    @type object_opts :: common_object_opts()

    bac_object :global_group do
      services(intrinsic: true)

      field(:member_status_flags, StatusFlags.t(), required: true)
      field(:reliability, Constants.reliability(), required: true)
      field(:event_state, Constants.event_state(), required: true)
      field(:status_flags, StatusFlags.t(), required: true)
    end
  end

  @wall ~U[2026-11-11 10:00:00Z]

  defmodule CountingFault do
    @fields [:count, :increment, :current_reliability]
    @enforce_keys @fields
    defstruct @fields

    @spec new(pos_integer()) :: %__MODULE__{}
    def new(increment) do
      %__MODULE__{count: 0, increment: increment, current_reliability: :no_fault_detected}
    end

    @spec update(%__MODULE__{}, keyword()) :: %__MODULE__{}
    def update(state, increment: increment), do: %{state | increment: increment}

    @spec execute(%__MODULE__{}) :: {:no_event, %__MODULE__{}}
    def execute(state), do: {:no_event, %{state | count: state.count + state.increment}}
  end

  test "custom fault algorithms retain state with a one-argument constructor" do
    {:ok, object} = BinaryValue.create(1, "Custom fault", %{}, intrinsic_reporting: true)
    result = %Result{object: object, state: nil, next_execution: nil}
    initial = Context.new(:initialization, now: @wall, monotonic_time: 0)
    selection = {CountingFault, [1]}

    first = IntrinsicReporting.evaluate(result, initial, EventAlgorithms.None, [], selection)
    assert first.state.reporting.fault_state.count == 1

    periodic = %{initial | trigger: :periodic, state: first.state}
    second = IntrinsicReporting.evaluate(first, periodic, EventAlgorithms.None, [], selection)
    assert second.state.reporting.fault_state.count == 2

    third =
      IntrinsicReporting.evaluate(
        second,
        %{periodic | state: second.state},
        EventAlgorithms.None,
        [],
        {CountingFault, [1], [increment: 3]}
      )

    assert third.state.reporting.fault_state.count == 5
  end

  test "validates retained reporting state and monotonic deadlines" do
    {:ok, object} =
      BinaryValue.create(1, "Alarm", %{present_value: true, alarm_value: true, time_delay: 2},
        intrinsic_reporting: true
      )

    result = evaluate(object, nil, 100, EventAlgorithms.ChangeOfState)
    reporting = result.state.reporting
    assert {condition, 2, 2100} = reporting.pending

    assert IntrinsicReporting.valid_state?(nil)
    assert IntrinsicReporting.valid_state?(reporting)
    refute IntrinsicReporting.valid_state?(:invalid)
    refute IntrinsicReporting.valid_state?(%{reporting | pending: {condition, 2, :invalid}})
    refute IntrinsicReporting.valid_state?(%{reporting | reliability: :unknown_reliability})
  end

  test "alarm and recovery conditions must hold continuously on the monotonic clock" do
    {:ok, object} =
      AnalogInput.create(
        1,
        "Temperature",
        %{
          low_limit: -10.0,
          high_limit: 10.0,
          deadband: 2.0,
          time_delay: 2,
          time_delay_normal: 1,
          limit_enable: LimitEnable.from_bitstring({true, true})
        },
        intrinsic_reporting: true
      )

    wall_deadline = DateTime.add(@wall, 60, :second)
    wakeup = %Wakeup{wall_time: wall_deadline, monotonic_time: 500}

    pending =
      evaluate(%{object | present_value: 11.0}, nil, 0, EventAlgorithms.OutOfRange, wakeup)

    assert pending.next_execution == wakeup
    assert EventReporting.transition(pending) == nil

    cancelled =
      evaluate(
        %{pending.object | present_value: 0.0},
        pending.state,
        500,
        EventAlgorithms.OutOfRange
      )

    assert cancelled.next_execution == nil

    pending =
      evaluate(
        %{cancelled.object | present_value: 11.0},
        cancelled.state,
        800,
        EventAlgorithms.OutOfRange
      )

    assert pending.next_execution.monotonic_time == 2800

    early = evaluate(pending.object, pending.state, 2799, EventAlgorithms.OutOfRange)
    assert early.object.event_state == :normal
    assert early.next_execution.monotonic_time == 2800

    alarm = evaluate(early.object, early.state, 2800, EventAlgorithms.OutOfRange)
    assert %{to_state: :high_limit, enabled: false} = EventReporting.transition(alarm)

    deadband =
      evaluate(
        %{alarm.object | present_value: 9.0},
        alarm.state,
        2900,
        EventAlgorithms.OutOfRange
      )

    assert deadband.next_execution == nil
    assert deadband.object.event_state == :high_limit

    recovery =
      evaluate(
        %{deadband.object | present_value: 7.0},
        deadband.state,
        3000,
        EventAlgorithms.OutOfRange
      )

    assert recovery.next_execution.monotonic_time == 4000
    normal = evaluate(recovery.object, recovery.state, 4000, EventAlgorithms.OutOfRange)
    assert %{from_state: :high_limit, to_state: :normal} = EventReporting.transition(normal)
  end

  test "inhibition forces a normal transition and detection disable resets reporting" do
    reference = %ObjectPropertyRef{
      object_identifier: %ObjectIdentifier{type: :binary_value, instance: 2},
      property_identifier: :present_value,
      property_array_index: nil
    }

    {:ok, object} =
      BinaryValue.create(
        1,
        "Alarm",
        %{
          present_value: true,
          alarm_value: true,
          event_algorithm_inhibit_ref: reference,
          event_enable: EventTransitionBits.from_bitstring({true, false, true})
        },
        intrinsic_reporting: true
      )

    alarm = evaluate(object, nil, 0, EventAlgorithms.ChangeOfState)
    assert %{to_state: :offnormal, enabled: true} = EventReporting.transition(alarm)

    context =
      Context.new(:periodic,
        state: alarm.state,
        now: @wall,
        monotonic_time: 100,
        read_property: fn ref ->
          assert ref.object_identifier == reference.object_identifier
          assert ref.property_identifier == reference.property_identifier
          {:ok, true}
        end
      )

    result = %Result{object: alarm.object, state: %{}, next_execution: :immediate}

    inhibited =
      IntrinsicReporting.evaluate(result, context, EventAlgorithms.ChangeOfState, [:present_value])

    assert inhibited.object.event_algorithm_inhibit
    assert inhibited.next_execution == :immediate

    assert %{to_state: :normal, event_values: %{new_state: %{value: true}}} =
             EventReporting.transition(inhibited)

    disabled =
      evaluate(
        %{alarm.object | event_detection_enable: false},
        alarm.state,
        200,
        EventAlgorithms.ChangeOfState
      )

    assert disabled.object.event_state == :normal

    assert disabled.object.event_timestamps.to_offnormal ==
             ObjectsMacro.get_default_bacnet_timestamp()

    assert EventReporting.transition(disabled) == nil
  end

  test "fault notifications use BACnet property encodings and re-report changed reliability" do
    {:ok, object} =
      BinaryValue.create(
        1,
        "Alarm",
        %{reliability: :no_sensor, present_value: true, alarm_value: true},
        intrinsic_reporting: true
      )

    fault = evaluate(object, nil, 0, EventAlgorithms.ChangeOfState)

    assert %{
             to_state: :fault,
             event_values: %{
               reliability: :no_sensor,
               property_values: [
                 %{
                   property_identifier: :present_value,
                   property_value: %Encoding{type: :enumerated, value: 1}
                 }
               ]
             }
           } = EventReporting.transition(fault)

    same = evaluate(fault.object, fault.state, 100, EventAlgorithms.ChangeOfState)
    assert EventReporting.transition(same) == nil

    new_fault =
      evaluate(
        %{same.object | reliability: :communication_failure},
        same.state,
        200,
        EventAlgorithms.ChangeOfState
      )

    assert %{from_state: :fault, to_state: :fault} = EventReporting.transition(new_fault)

    recovered =
      evaluate(
        %{new_fault.object | reliability: :no_fault_detected},
        new_fault.state,
        300,
        EventAlgorithms.ChangeOfState
      )

    assert %{event_type: :change_of_reliability, to_state: :normal} =
             EventReporting.transition(recovered)

    assert recovered.next_execution == :immediate
  end

  test "selects FAULT_STATE independently of CHANGE_OF_STATE" do
    {:ok, object} =
      MultistateInput.create(
        1,
        "Fan status",
        %{
          number_of_states: 2,
          present_value: 2,
          reliability: :no_fault_detected,
          alarm_values: [2],
          fault_values: [2]
        },
        intrinsic_reporting: true
      )

    context = Context.new(:initialization, now: @wall, monotonic_time: 0)
    result = %Result{object: object, state: %{}, next_execution: nil}

    alarm =
      IntrinsicReporting.evaluate(result, context, EventAlgorithms.ChangeOfState, [:present_value])

    assert alarm.object.reliability == :no_fault_detected

    assert %{event_type: :change_of_state, to_state: :offnormal} =
             EventReporting.transition(alarm)

    fault =
      IntrinsicReporting.evaluate(
        result,
        context,
        EventAlgorithms.None,
        [:present_value],
        FaultAlgorithms.FaultState
      )

    assert fault.object.reliability == :multi_state_fault

    assert %{event_type: :change_of_reliability, to_state: :fault} =
             EventReporting.transition(fault)
  end

  test "reports and clears a fault from explicitly supplied status flags" do
    {:ok, object} =
      BinaryValue.create(
        1,
        "Alarm",
        %{present_value: true, alarm_value: true, reliability: :no_fault_detected},
        intrinsic_reporting: true
      )

    parameters = %FaultParameters.FaultStatusFlags{
      status_flags: %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :binary_input, instance: 2},
        property_identifier: :status_flags,
        property_array_index: nil
      }
    }

    flags = StatusFlags.from_bitstring({false, true, false, false})
    context = Context.new(:initialization, now: @wall, monotonic_time: 0)
    result = %Result{object: object, state: %{}, next_execution: nil}

    fault =
      IntrinsicReporting.evaluate(
        result,
        context,
        EventAlgorithms.ChangeOfState,
        [:present_value],
        {FaultAlgorithms.FaultStatusFlags, [flags, parameters]}
      )

    assert fault.object.reliability == :member_fault
    assert fault.object.status_flags.fault

    assert %{event_type: :change_of_reliability, to_state: :fault} =
             EventReporting.transition(fault)

    context = %{context | trigger: :periodic, monotonic_time: 100, state: fault.state}

    recovered =
      IntrinsicReporting.evaluate(
        %{result | object: fault.object},
        context,
        EventAlgorithms.ChangeOfState,
        [:present_value],
        {FaultAlgorithms.FaultStatusFlags, [%{flags | fault: false}, parameters]}
      )

    assert recovered.object.reliability == :no_fault_detected
    refute recovered.object.status_flags.fault

    assert %{event_type: :change_of_reliability, to_state: :normal} =
             EventReporting.transition(recovered)

    assert recovered.next_execution == :immediate
  end

  test "FAULT_LIFE_SAFETY uses local Present_Value, Mode and Fault_Values" do
    {:ok, object} =
      LifeSafetySource.create(
        1,
        "Point",
        %{present_value: :fault, fault_values: [:fault]},
        intrinsic_reporting: true
      )

    fault = evaluate_fault(object, nil, FaultAlgorithms.FaultLifeSafety)
    assert fault.object.reliability == :multi_state_fault
    assert %{from_state: :normal, to_state: :fault} = EventReporting.transition(fault)

    same = evaluate_fault(fault.object, fault.state, FaultAlgorithms.FaultLifeSafety)
    assert EventReporting.transition(same) == nil

    changed =
      evaluate_fault(%{same.object | mode: :test}, same.state, FaultAlgorithms.FaultLifeSafety)

    assert changed.object.reliability == :multi_state_fault
    assert %{from_state: :fault, to_state: :fault} = EventReporting.transition(changed)

    recovered =
      evaluate_fault(
        %{changed.object | present_value: :quiet},
        changed.state,
        FaultAlgorithms.FaultLifeSafety
      )

    assert recovered.object.reliability == :no_fault_detected
    assert %{from_state: :fault, to_state: :normal} = EventReporting.transition(recovered)
  end

  test "FAULT_STATUS_FLAGS uses Member_Status_Flags and clears when the members recover" do
    flags = StatusFlags.from_bitstring({false, true, false, false})

    {:ok, object} =
      MemberStatusSource.create(1, "Group", %{member_status_flags: flags},
        intrinsic_reporting: true
      )

    fault = evaluate_fault(object, nil, FaultAlgorithms.FaultStatusFlags)
    assert fault.object.reliability == :member_fault
    assert fault.object.status_flags.fault
    assert %{from_state: :normal, to_state: :fault} = EventReporting.transition(fault)

    healthy = %{fault.object | member_status_flags: %{flags | fault: false}}
    recovered = evaluate_fault(healthy, fault.state, FaultAlgorithms.FaultStatusFlags)
    assert recovered.object.reliability == :no_fault_detected
    refute recovered.object.status_flags.fault
    assert %{from_state: :fault, to_state: :normal} = EventReporting.transition(recovered)
  end

  test "publishes the configured algorithm reliability on fault and recovery" do
    {:ok, object} =
      MultistateInput.create(
        1,
        "Fan status",
        %{number_of_states: 2, present_value: 2, reliability: :no_sensor, fault_values: [2]},
        intrinsic_reporting: true
      )

    context = Context.new(:initialization, now: @wall, monotonic_time: 0)
    result = %Result{object: object, state: %{}, next_execution: nil}

    fault =
      IntrinsicReporting.evaluate(
        result,
        context,
        EventAlgorithms.None,
        [:present_value],
        FaultAlgorithms.FaultState
      )

    assert fault.object.reliability == :multi_state_fault
    assert fault.object.status_flags.fault

    assert %{event_type: :change_of_reliability, to_state: :fault} =
             EventReporting.transition(fault)

    context = %{context | trigger: :periodic, monotonic_time: 100, state: fault.state}
    object = %{fault.object | present_value: 1, reliability: :no_sensor}

    changed =
      IntrinsicReporting.evaluate(
        %{result | object: object},
        context,
        EventAlgorithms.None,
        [:present_value],
        FaultAlgorithms.FaultState
      )

    assert changed.object.reliability == :no_fault_detected
    refute changed.object.status_flags.fault

    assert %{event_type: :change_of_reliability, to_state: :normal} =
             EventReporting.transition(changed)
  end

  test "log evaluation projects the counters that accompany a recorded transition" do
    logger =
      start_supervised!({TrendLogger, lookup_cb: fn _reference -> flunk("unexpected lookup") end})

    {:ok, object} =
      EventLog.create(1, "Events", %{buffer_size: 8, notification_threshold: 1},
        intrinsic_reporting: true
      )

    assert :ok = TrendLogger.add_object(logger, object, :lifecycle)
    assert :ok = TrendLogger.trigger_log(logger, object, :interrupted)

    result = %Result{object: object, state: nil, next_execution: nil}
    context = Context.new(:periodic, now: @wall, monotonic_time: 0)
    assert {:ok, ready} = IntrinsicReporting.evaluate_log(result, context, logger)
    assert ready.object.last_notify_record == 1
    assert ready.object.records_since_notification == 0
    assert ready.object.log_buffer == []

    assert %{event_type: :buffer_ready, event_values: %{current_notification: 1}} =
             EventReporting.transition(ready)
  end

  test "extracts a log's continuation marker from retained reporting state" do
    assert IntrinsicReporting.log_execution_state(:sample_pending) == :sample_pending

    assert IntrinsicReporting.log_execution_state(%{
             reporting: %{},
             execution_state: :sample_pending
           }) == :sample_pending
  end

  defp evaluate_fault(object, state, module) do
    trigger = if state, do: :periodic, else: :initialization
    context = Context.new(trigger, now: @wall, monotonic_time: 0, state: state)
    result = %Result{object: object, state: %{}, next_execution: nil}
    IntrinsicReporting.evaluate(result, context, EventAlgorithms.None, [], module)
  end

  defp evaluate(object, state, time, kind, wakeup \\ nil) do
    context =
      Context.new(:periodic,
        now: DateTime.add(@wall, time * 10, :second),
        monotonic_time: time,
        state: state
      )

    result = %Result{object: object, state: %{}, next_execution: wakeup}
    IntrinsicReporting.evaluate(result, context, kind, [:present_value])
  end
end
