defmodule BACnet.Test.Protocol.ObjectExecution.LifecycleTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsBehaviour
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.BinaryOutput
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  @moduletag :object_test

  doctest Lifecycle

  defmodule UnsupportedSnapshot do
    defstruct _metadata: %{remote_object: 42}
  end

  # A contract probe, not an implementation of any standard object's algorithm.
  defmodule Probe do
    use BACnet.Protocol.ObjectsMacro
    @type object_opts :: common_object_opts()

    bac_object :binary_value do
      services(intrinsic: false)
      field(:present_value, boolean(), required: true, default: false)
      field(:description, String.t(), required: true, default: "")
      field(:in_process, boolean(), required: true, default: false)
    end

    @impl ObjectsBehaviour
    @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
    def validate_execution(object, context) do
      with :ok <- check_capability(object) do
        operations =
          case Keyword.get(context.options, :mode) do
            :consumer -> [:read_property | target_operations(context)]
            :staged -> target_operations(context)
            _other -> []
          end

        Context.require_operations(context, operations)
      end
    end

    @impl ObjectsBehaviour
    @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
    def prepare_write(original, candidate, context) do
      cond do
        original.in_process ->
          {:error, :busy}

        candidate.description == "invalid" ->
          {:error, {:invalid_configuration, :description}}

        candidate.description == "related" ->
          update_property(candidate, :in_process, true)

        Keyword.get(context.options, :change_identity, false) ->
          {:ok, %{candidate | object_instance: candidate.object_instance + 1}}

        true ->
          super(original, candidate, context)
      end
    end

    @impl ObjectsBehaviour
    @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
    def execute(object, context) do
      case Keyword.get(context.options, :mode) do
        :date ->
          date_step(object, context)

        :consumer ->
          consumer_step(object, context)

        :staged ->
          staged_step(object, context)

        :timer ->
          timer_step(object, context)

        :fail_after_write ->
          failure_step(object, context)

        _other ->
          {:ok, %Result{object: object, state: next_count(context), next_execution: nil}}
      end
    end

    defp check_capability(object)

    defp check_capability(%{description: "unsupported"}),
      do: {:error, {:unsupported_capability, :test_feature}}

    defp check_capability(_object), do: :ok

    defp target_operations(context),
      do: if(Keyword.get(context.options, :targets, []) == [], do: [], else: [:write_property])

    defp next_count(context),
      do: %{
        count: if(context.state, do: context.state.count + 1, else: 1),
        trigger: context.trigger
      }

    defp date_step(object, context) do
      today = DateTime.to_date(context.now)

      {:ok, updated} =
        update_property(object, :present_value, object.description == Date.to_iso8601(today))

      midnight = DateTime.new!(Date.add(today, 1), ~T[00:00:00])

      {:ok,
       %Result{
         object: updated,
         state: next_count(context),
         next_execution: %Wakeup{wall_time: midnight, monotonic_time: nil}
       }}
    end

    defp consumer_step(object, context) do
      with {:ok, value} <-
             Context.read_property(context, Keyword.fetch!(context.options, :source)),
           {:ok, updated} <- update_property(object, :present_value, value) do
        failures = fanout(context, value)

        {:ok,
         %Result{
           object: updated,
           state: Map.put(next_count(context), :failures, failures),
           next_execution: nil
         }}
      end
    end

    defp staged_step(object, context)

    defp staged_step(object, %Context{
           trigger: {:property_write, :present_value, _index, _priority}
         }) do
      {:ok, busy} = update_property(object, :in_process, true)

      {:ok,
       %Result{object: busy, state: %{pending: object.present_value}, next_execution: :immediate}}
    end

    defp staged_step(object, %Context{trigger: :continuation} = context) do
      if Keyword.get(context.options, :observe_busy, false) do
        reference = %DeviceObjectRef{
          object_identifier: get_object_identifier(object),
          device_identifier: nil
        }

        {:ok, published} = Context.lookup_object(context, reference)
        true = published.in_process
      end

      failures = fanout(context, context.state.pending)
      {:ok, idle} = update_property(object, :in_process, false)
      {:ok, %Result{object: idle, state: %{failures: failures}, next_execution: nil}}
    end

    defp staged_step(object, context),
      do: {:ok, %Result{object: object, state: context.state, next_execution: nil}}

    defp fanout(context, value) do
      for target <- Keyword.get(context.options, :targets, []),
          {:error, reason} <- [Context.write_property(context, target, value, 8)],
          do: {target, reason}
    end

    defp timer_step(object, context) do
      deadline =
        if context.trigger == :clock_change and context.state,
          do: context.state.deadline,
          else: context.monotonic_time + 1000

      {:ok,
       %Result{
         object: object,
         state: Map.put(next_count(context), :deadline, deadline),
         next_execution:
           if(object.description == "cancel",
             do: nil,
             else: %Wakeup{
               wall_time: DateTime.add(context.now, 3600),
               monotonic_time: deadline
             }
           )
       }}
    end

    defp failure_step(object, context)

    defp failure_step(_object, %Context{trigger: {:property_write, _property, _index, _priority}}),
         do: {:error, :execution_failed}

    defp failure_step(object, context),
      do:
        {:ok,
         %Result{
           object: object,
           state: next_count(context),
           next_execution: %Wakeup{wall_time: nil, monotonic_time: context.monotonic_time + 1000}
         }}
  end

  @context %Context{
    device_identifier: nil,
    now: ~U[2026-11-07 23:59:00Z],
    timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
    monotonic_time: -2000,
    trigger: :initialization,
    state: nil,
    lookup_object: nil,
    read_property_multiple: nil,
    read_property: nil,
    write_property: nil,
    options: []
  }

  test "all built-in default callbacks work through the lifecycle without requiring host operations" do
    for module <- Map.values(ObjectsUtility.get_object_type_mappings()) do
      if module not in [
           BACnet.Protocol.ObjectTypes.Accumulator,
           BACnet.Protocol.ObjectTypes.AnalogInput,
           BACnet.Protocol.ObjectTypes.AnalogOutput,
           BACnet.Protocol.ObjectTypes.AnalogValue,
           BACnet.Protocol.ObjectTypes.Averaging,
           BACnet.Protocol.ObjectTypes.BinaryInput,
           BACnet.Protocol.ObjectTypes.BinaryOutput,
           BACnet.Protocol.ObjectTypes.BinaryValue,
           BACnet.Protocol.ObjectTypes.BitstringValue,
           BACnet.Protocol.ObjectTypes.Calendar,
           BACnet.Protocol.ObjectTypes.CharacterStringValue,
           BACnet.Protocol.ObjectTypes.Command,
           BACnet.Protocol.ObjectTypes.DatePatternValue,
           BACnet.Protocol.ObjectTypes.DateTimePatternValue,
           BACnet.Protocol.ObjectTypes.DateTimeValue,
           BACnet.Protocol.ObjectTypes.DateValue,
           BACnet.Protocol.ObjectTypes.Device,
           BACnet.Protocol.ObjectTypes.EventEnrollment,
           BACnet.Protocol.ObjectTypes.EventLog,
           BACnet.Protocol.ObjectTypes.Group,
           BACnet.Protocol.ObjectTypes.IntegerValue,
           BACnet.Protocol.ObjectTypes.LargeAnalogValue,
           BACnet.Protocol.ObjectTypes.Loop,
           BACnet.Protocol.ObjectTypes.MultistateInput,
           BACnet.Protocol.ObjectTypes.MultistateOutput,
           BACnet.Protocol.ObjectTypes.MultistateValue,
           BACnet.Protocol.ObjectTypes.NetworkPort,
           BACnet.Protocol.ObjectTypes.OctetStringValue,
           BACnet.Protocol.ObjectTypes.PositiveIntegerValue,
           BACnet.Protocol.ObjectTypes.Program,
           BACnet.Protocol.ObjectTypes.PulseConverter,
           BACnet.Protocol.ObjectTypes.Schedule,
           BACnet.Protocol.ObjectTypes.TimePatternValue,
           BACnet.Protocol.ObjectTypes.TimeValue,
           BACnet.Protocol.ObjectTypes.TrendLog,
           BACnet.Protocol.ObjectTypes.TrendLogMultiple
         ] do
        object = struct(module)
        context = %{@context | state: :retained}

        assert {:ok, %Result{object: ^object, state: :retained, next_execution: nil}} =
                 Lifecycle.execute(object, context)

        assert {:ok, ^object} =
                 Lifecycle.prepare_write(object, object, %{
                   context
                   | trigger: {:property_write, :object_name, nil, nil}
                 })
      end
    end
  end

  test "preflight rejects unsupported capabilities and missing operations before I/O" do
    context = %{
      @context
      | options: [mode: :consumer, targets: [reference(2)]],
        read_property: fn _ref -> flunk("preflight must precede reads") end,
        write_property: fn _ref, _value, _priority -> flunk("preflight must precede writes") end
    }

    {:ok, object} = Probe.create(1, "Probe", %{description: "unsupported"})
    assert {:error, {:unsupported_capability, :test_feature}} = Lifecycle.execute(object, context)

    {:ok, object} = Probe.create(1, "Probe")

    assert {:error, {:unsupported_operation, :write_property}} =
             Lifecycle.execute(object, %{context | write_property: nil})

    assert {:error, {:unsupported_operation, :read_property}} =
             Lifecycle.execute(object, %{context | read_property: nil})

    assert :ok =
             Probe.validate_execution(object, %{@context | options: [mode: :staged, targets: []]})
  end

  test "remote snapshots bypass active callbacks regardless of revision or host availability" do
    for remote <- [true, 0, 42] do
      {:ok, snapshot} =
        Probe.create(
          1,
          "Remote",
          %{description: "unsupported", in_process: false, present_value: false},
          remote_object: remote,
          revision: 22
        )

      context = %{@context | state: :retained, options: [mode: :consumer]}

      assert {:ok, %Result{object: ^snapshot, state: :retained, next_execution: nil}} =
               Lifecycle.execute(snapshot, context)

      assert {:error, :operation_not_available_for_remote_objects} =
               Lifecycle.prepare_write(snapshot, snapshot, %{
                 context
                 | trigger: {:property_write, :description, nil, nil}
               })
    end
  end

  test "write rejection retains the original object, related properties, state and wakeup" do
    {:ok, object} = Probe.create(1, "Probe")
    host = Host.new([{object, [mode: :timer]}], @context.now, @context.monotonic_time)
    id = ObjectsUtility.get_object_identifier(object)
    assert :ok = Host.execute(host, id, :initialization)
    before_write = Host.snapshot(host, id)

    assert {:error, {:invalid_configuration, :description}} =
             Host.write(host, reference(1, :description), "invalid")

    assert Host.snapshot(host, id) == before_write

    assert {:error, {:unsupported_capability, :test_feature}} =
             Host.write(host, reference(1, :description), "unsupported")

    assert Host.snapshot(host, id) == before_write
  end

  test "prepare_write adds related changes, checks the original busy state and preserves identity" do
    {:ok, original} = Probe.create(1, "Probe")
    context = %{@context | trigger: {:property_write, :description, nil, nil}}
    {:ok, candidate} = Probe.update_property(original, :description, "related")

    assert {:ok, %{in_process: true, description: "related"}} =
             Lifecycle.prepare_write(original, candidate, context)

    refute original.in_process
    refute candidate.in_process

    {:ok, busy} = Probe.update_property(original, :in_process, true)
    assert {:error, :busy} = Lifecycle.prepare_write(busy, candidate, context)

    {:ok, candidate} = Probe.update_property(original, :description, "normal")

    assert {:error, :object_identity_mismatch} =
             Lifecycle.prepare_write(original, %{candidate | object_instance: 2}, context)

    assert {:error, :object_identity_mismatch} =
             Lifecycle.prepare_write(original, candidate, %{
               context
               | options: [change_identity: true]
             })

    assert {:error, :object_identity_mismatch} =
             Lifecycle.prepare_write(
               original,
               %{candidate | _metadata: %{candidate._metadata | remote_object: 42}},
               context
             )

    {:ok, revised_properties} = Probe.create(1, "Probe", %{description: "normal"}, revision: 19)

    assert {:ok, ^revised_properties} =
             Lifecycle.prepare_write(original, revised_properties, context)

    assert {:error, :object_identity_mismatch} =
             Lifecycle.prepare_write(original, struct(BinaryOutput), context)
  end

  test "prepare_write rejects a slot six change before preparing the binary hold" do
    {:ok, object} = BinaryOutput.create(1, "Fan", %{min_on_time: 2})
    {:ok, initial} = Lifecycle.execute(object, Context.new(:initialization, monotonic_time: 0))

    {:ok, candidate} = BinaryOutput.set_priority(initial.object, 8, true)

    write = Context.new({:property_write, 85, nil, 8}, state: initial.state, monotonic_time: 100)

    assert {:error, {:write_access_denied, :priority_array}} =
             Lifecycle.prepare_write(
               initial.object,
               put_in(candidate.priority_array.priority_6, true),
               write
             )

    assert {:ok, prepared} = Lifecycle.prepare_write(initial.object, candidate, write)
    assert prepared.priority_array.priority_6 == true

    array_write = %{write | trigger: {:application_write, 87, 6, nil}}

    assert {:error, :write_access_denied} =
             Lifecycle.prepare_write(prepared, prepared, array_write)
  end

  test "same-value writes each execute before the next write and retain priority metadata" do
    {:ok, object} = Probe.create(1, "Probe")
    host = Host.new([{object, []}], @context.now, @context.monotonic_time)
    id = ObjectsUtility.get_object_identifier(object)

    for count <- 1..2 do
      assert :ok = Host.write(host, reference(1), false, 8)

      assert Host.snapshot(host, id).state ==
               %{count: count, trigger: {:property_write, :present_value, nil, 8}}
    end
  end

  test "a failure after write commit preserves the accepted value and previous state and wakeup" do
    {:ok, object} = Probe.create(1, "Probe")
    host = Host.new([{object, [mode: :fail_after_write]}], @context.now, @context.monotonic_time)
    id = ObjectsUtility.get_object_identifier(object)
    assert :ok = Host.execute(host, id, :initialization)
    before_write = Host.snapshot(host, id)

    assert {:error, {:execution_failed_after_commit, :execution_failed}} =
             Host.write(host, reference(1), true)

    after_write = Host.snapshot(host, id)
    assert after_write.object.present_value
    assert after_write.state == before_write.state
    assert after_write.next_execution == before_write.next_execution
  end

  test "a consumer reads a fresh dependency without prior execution of that dependency" do
    {:ok, predicate} = Probe.create(1, "Predicate", %{description: "2026-11-07"})
    {:ok, consumer} = Probe.create(2, "Consumer")

    host =
      Host.new(
        [{predicate, [mode: :date]}, {consumer, [mode: :consumer, source: reference(1)]}],
        @context.now,
        @context.monotonic_time
      )

    id = ObjectsUtility.get_object_identifier(consumer)
    assert :ok = Host.execute(host, id, :initialization)
    assert Host.snapshot(host, id).object.present_value
    Host.advance(host, ~U[2026-11-08 00:00:00Z], -1000)
    assert :ok = Host.execute(host, id, :timer)
    refute Host.snapshot(host, id).object.present_value

    assert :ok = Host.write(host, reference(1, :description), "2026-11-08")

    dependency = %DeviceObjectRef{
      object_identifier: reference(1).object_identifier,
      device_identifier: nil
    }

    assert :ok = Host.execute(host, id, {:object_changed, dependency})
    assert Host.snapshot(host, id).object.present_value
    assert Host.snapshot(host, id).state.trigger == {:object_changed, dependency}
  end

  test "a host rejects cyclic dependency reads rather than recursively executing" do
    {:ok, first} = Probe.create(1, "First")
    {:ok, second} = Probe.create(2, "Second")

    host =
      Host.new(
        [
          {first, [mode: :consumer, source: reference(2)]},
          {second, [mode: :consumer, source: reference(1)]}
        ],
        @context.now,
        @context.monotonic_time
      )

    assert {:error, :cyclic_execution} =
             Host.execute(host, reference(1).object_identifier, :initialization)
  end

  test "partial fanout retains successful writes, records failures and attempts later targets" do
    {:ok, predicate} = Probe.create(1, "Predicate", %{description: "2026-11-07"})
    {:ok, consumer} = Probe.create(2, "Consumer")

    outputs =
      for id <- 3..5 do
        {:ok, output} = BinaryOutput.create(id, "Output #{id}")
        {output, []}
      end

    targets = for id <- 3..5, do: reference(id, :present_value, :binary_output)

    host =
      Host.new(
        [
          {predicate, [mode: :date]},
          {consumer, [mode: :consumer, source: reference(1), targets: targets]} | outputs
        ],
        @context.now,
        @context.monotonic_time
      )

    for target <- targets,
        do: assert(:ok = Host.execute(host, target.object_identifier, :initialization))

    Host.fail_writes(host, Enum.at(targets, 1).object_identifier, :write_access_denied)
    assert :ok = Host.execute(host, reference(2).object_identifier, :initialization)

    assert Host.snapshot(host, reference(2).object_identifier).state.failures ==
             [{Enum.at(targets, 1), :write_access_denied}]

    assert Enum.map(Host.writes(host), &elem(&1, 0)) == targets
    assert Host.snapshot(host, hd(targets).object_identifier).object.present_value
    refute Host.snapshot(host, Enum.at(targets, 1).object_identifier).object.present_value
    assert Host.snapshot(host, List.last(targets).object_identifier).object.present_value
  end

  test "immediate continuation exposes committed busy state before I/O and finishes before another write" do
    {:ok, object} = Probe.create(1, "Staged")
    target = reference(2)

    context = %{
      @context
      | trigger: {:property_write, :present_value, nil, nil},
        options: [mode: :staged, targets: [target]],
        write_property: fn _ref, _value, _priority ->
          flunk("first step must only publish busy state")
        end
    }

    {:ok, candidate} = Probe.update_property(object, :present_value, true)
    assert {:ok, prepared} = Lifecycle.prepare_write(object, candidate, context)

    assert {:ok, %Result{object: busy, state: state, next_execution: :immediate}} =
             Lifecycle.execute(prepared, context)

    assert busy.in_process
    assert {:error, :busy} = Lifecycle.prepare_write(busy, prepared, context)

    # The host has now published `busy` and `state` before resuming.
    context = %{
      context
      | state: state,
        trigger: :continuation,
        write_property: fn ^target, true, 8 ->
          assert busy.in_process
          assert state.pending
          :ok
        end
    }

    assert {:ok, %Result{object: %{in_process: false}, next_execution: nil}} =
             Lifecycle.execute(busy, context)

    {:ok, output} = BinaryOutput.create(2, "Output")

    host =
      Host.new(
        [
          {object,
           [
             mode: :staged,
             observe_busy: true,
             targets: [reference(2, :present_value, :binary_output)]
           ]},
          {output, []}
        ],
        @context.now,
        @context.monotonic_time
      )

    assert :ok = Host.execute(host, BinaryOutput.get_object_identifier(output), :initialization)
    assert :ok = Host.write(host, reference(1), true)
    record = Host.snapshot(host, reference(1).object_identifier)
    refute record.object.in_process
    assert record.next_execution == nil
    assert record.state == %{failures: []}
    assert :ok = Host.write(host, reference(1), false)
  end

  test "timer execution uses supplied monotonic time despite a backwards wall-clock jump" do
    {:ok, object} = Probe.create(1, "Timed")
    host = Host.new([{object, [mode: :timer]}], @context.now, -2000)
    id = reference(1).object_identifier
    assert :ok = Host.execute(host, id, :initialization)
    Host.advance(host, DateTime.add(@context.now, -3600), -1500)
    Host.run_due(host)
    assert Host.snapshot(host, id).state.count == 1
    assert :ok = Host.execute(host, id, :clock_change)
    assert Host.snapshot(host, id).state.trigger == :clock_change
    assert Host.snapshot(host, id).next_execution.monotonic_time == -1000
    Host.advance(host, DateTime.add(@context.now, -3599), -500)
    Host.run_due(host)
    assert %{count: 3, trigger: :timer} = Host.snapshot(host, id).state
    assert Host.snapshot(host, id).next_execution.monotonic_time == 500
  end

  test "read and write phases require their specific trigger" do
    {:ok, object} = Probe.create(1, "Probe")
    assert_raise FunctionClauseError, fn -> Lifecycle.prepare_read(object, @context) end
    assert_raise FunctionClauseError, fn -> Lifecycle.prepare_write(object, object, @context) end
  end

  test "lifecycle dispatch does not accept unrelated structs, including remote-shaped snapshots" do
    for object <- [%UnsupportedSnapshot{}, ~D[2026-11-07]] do
      assert_raise Protocol.UndefinedError, fn -> Lifecycle.execute(object, @context) end
    end
  end

  test "a successful result cancels an old wakeup and runtime state is independent per instance" do
    {:ok, first} = Probe.create(1, "First")
    {:ok, second} = Probe.create(2, "Second")
    host = Host.new([{first, [mode: :timer]}, {second, [mode: :timer]}], @context.now, -2000)
    assert :ok = Host.execute(host, reference(1).object_identifier, :initialization)
    assert :ok = Host.execute(host, reference(2).object_identifier, :initialization)
    assert :ok = Host.write(host, reference(1, :description), "cancel")
    assert Host.snapshot(host, reference(1).object_identifier).next_execution == nil
    Host.advance(host, @context.now, -1000)
    Host.run_due(host)
    assert Host.snapshot(host, reference(1).object_identifier).state.count == 2

    assert %{
             count: 2,
             trigger: :timer
           } = Host.snapshot(host, reference(2).object_identifier).state

    # A new VM/host starts with nil state rather than a persisted monotonic origin.
    restarted = Host.new([{first, [mode: :timer]}], @context.now, 100_000)
    assert :ok = Host.execute(restarted, reference(1).object_identifier, :initialization)
    record = Host.snapshot(restarted, reference(1).object_identifier)
    assert record.state.count == 1
    assert record.next_execution.monotonic_time == 101_000
  end

  defp reference(instance, property \\ :present_value, type \\ :binary_value) do
    %DeviceObjectPropertyRef{
      object_identifier: %ObjectIdentifier{type: type, instance: instance},
      property_identifier: property,
      property_array_index: nil,
      device_identifier: nil
    }
  end
end
