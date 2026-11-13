defmodule BACnet.Test.Protocol.ObjectTypes.CommandTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.ActionCommand
  alias BACnet.Protocol.ActionList
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.BinaryOutput
  alias BACnet.Protocol.ObjectTypes.Command
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  @moduletag :object_test
  @now ~U[2026-11-09 08:00:00Z]
  doctest Command

  test "computed flags are read-only and action configuration is writable" do
    object = command()
    refute Command.property_writable?(object, :in_process)
    refute Command.property_writable?(object, :all_writes_successful)
    assert Command.property_writable?(object, :action)
    assert Command.property_writable?(object, :present_value)
    assert {:error, :value_out_of_range} = Command.update_property(object, :present_value, 1)
  end

  test "initialization and non-write triggers do not replay a selected action" do
    object = command([[action()]], %{present_value: 1, all_writes_successful: true})

    for trigger <- [
          :initialization,
          :periodic,
          :clock_change,
          :timer,
          :continuation,
          {:property_read, :present_value, nil}
        ] do
      assert {:ok, %Result{object: ^object, next_execution: nil}} =
               Lifecycle.execute(object, context(trigger))
    end
  end

  test "a present-value write publishes busy state and clears stale selected success flags before I/O" do
    object = command([[action(write_successful: true)], [action(write_successful: true)]])
    {:ok, candidate} = Command.update_property(object, :present_value, 1)

    ctx =
      context(write_trigger(),
        write_property: fn _ref, _value, _priority -> flunk("too early") end
      )

    assert {:ok, prepared} = Lifecycle.prepare_write(object, candidate, ctx)
    assert {:ok, started} = Lifecycle.execute(prepared, ctx)
    assert started.next_execution == :immediate
    assert started.object.in_process
    refute started.object.all_writes_successful
    assert flags(started.object, 1) == [false]
    assert flags(started.object, 2) == [true]
    assert started.state.position == 0
  end

  test "local typed writes and same-value writes execute in order at each entry's priority" do
    {:ok, output} = BinaryOutput.create(2, "Lighting")
    object = command([[action(priority: 8), action(value: enc(:null, nil), priority: 8)]])
    host = host(object, [output])
    assert :ok = Host.write(host, ref(object), 1)

    assert target_writes(host) == [
             {ref(output), enc(:enumerated, 1), 8},
             {ref(output), enc(:null, nil), 8}
           ]

    assert flags(record(host).object) == [true, true]
    refute record(host).object.in_process
    assert record(host).object.all_writes_successful
    assert :ok = Host.write(host, ref(object), 1)
    assert length(target_writes(host)) == 4
    assert Host.snapshot(host, oid(:binary_output, 2)).object.priority_array.priority_8 == nil
  end

  test "zero and empty action lists publish busy state then complete without callbacks" do
    object = command([[]])

    for code <- [0, 1] do
      {:ok, candidate} = Command.update_property(object, :present_value, code)
      assert {:ok, started} = Lifecycle.execute(candidate, context(write_trigger()))
      assert started.object.in_process
      refute started.object.all_writes_successful
      assert {:ok, finished} = step(started)
      refute finished.object.in_process
      assert finished.object.all_writes_successful
      assert finished.next_execution == nil
    end
  end

  test "failed writes continue unless quit-on-failure is selected" do
    {:ok, output} = BinaryOutput.create(2, "Lighting")

    for quit <- [false, true] do
      object =
        command([
          [
            action(
              target: oid(:binary_output, 99),
              quit_on_failure: quit,
              write_successful: true
            ),
            action(write_successful: true)
          ]
        ])

      host = host(object, [output])
      assert :ok = Host.write(host, ref(object), 1)
      refute record(host).object.all_writes_successful
      refute record(host).object.in_process
      assert flags(record(host).object) == [false, not quit]
      assert length(target_writes(host)) == if(quit, do: 1, else: 2)

      assert [{%DeviceObjectPropertyRef{object_identifier: %{instance: 99}}, :unknown_object}] =
               record(host).state.failures
    end
  end

  test "nil and zero post-delays request no timers" do
    for delay <- [nil, 0] do
      object = command([[action(device: oid(:device, 42), post_delay: delay)]])
      host = host(object, [], remote_write: fn _ref, _value, _priority -> :ok end)
      assert :ok = Host.write(host, ref(object), 1)
      assert record(host).next_execution == nil
      assert record(host).object.all_writes_successful
    end
  end

  test "post-delay is in seconds and includes the final write before completion" do
    {:ok, output} = BinaryOutput.create(2, "Lighting")
    object = command([[action(post_delay: 2)]])
    host = Host.new([{object, []}, {output, []}], @now, -1000)
    assert :ok = Host.execute(host, BinaryOutput.get_object_identifier(output), :initialization)
    assert :ok = Host.execute(host, Command.get_object_identifier(object), :initialization)
    assert :ok = Host.write(host, ref(object), 1)
    assert record(host).object.in_process
    refute record(host).object.all_writes_successful
    assert flags(record(host).object) == [true]
    assert record(host).next_execution.monotonic_time == 1000
    assert record(host).next_execution.wall_time == nil
    Host.advance(host, DateTime.add(@now, 86_400), 999)
    assert :ok = Host.execute(host, oid(:command, 1), :clock_change)
    assert record(host).object.in_process
    assert record(host).next_execution.monotonic_time == 1000
    Host.advance(host, DateTime.add(@now, -86_400), 1000)
    Host.run_due(host)
    assert record(host).object.all_writes_successful
    refute record(host).object.in_process
    assert length(target_writes(host)) == 1
  end

  test "a failed quitting write still observes its post-delay and clears all unattempted flags" do
    object =
      command([
        [
          action(target: oid(:binary_output, 99), post_delay: 2, quit_on_failure: true),
          action(write_successful: true)
        ]
      ])

    host = host(object)
    assert :ok = Host.write(host, ref(object), 1)
    assert record(host).object.in_process
    assert flags(record(host).object) == [false, false]
    Host.advance(host, @now, 2000)
    Host.run_due(host)
    refute record(host).object.in_process
    refute record(host).object.all_writes_successful
    assert length(target_writes(host)) == 1
  end

  test "delay starts with a fresh sample after callback completion, not the callback start" do
    object = command([[action(device: oid(:device, 42), post_delay: 2)]])

    ctx =
      context(write_trigger(),
        write_property: fn _reference, _value, _priority ->
          Process.put(:write_finished_at, 5000)
          :ok
        end
      )

    {:ok, candidate} = Command.update_property(object, :present_value, 1)
    {:ok, started} = Lifecycle.execute(candidate, ctx)
    {:ok, written} = step(started, write_property: ctx.write_property)
    assert written.next_execution == :immediate
    assert Process.get(:write_finished_at) == 5000
    {:ok, waiting} = step(written, monotonic_time: 5000)
    assert waiting.next_execution.monotonic_time == 7000
    assert waiting.object.in_process
    {:ok, completed} = step(waiting, monotonic_time: 7000)
    assert completed.object.all_writes_successful
  end

  test "late delivery continues from the current time without replaying delays" do
    object =
      command([
        [
          action(device: oid(:device, 42), post_delay: 2),
          action(device: oid(:device, 42), post_delay: 3)
        ]
      ])

    host = host(object, [], remote_write: fn _ref, _value, _priority -> :ok end)
    assert :ok = Host.write(host, ref(object), 1)
    assert record(host).next_execution.monotonic_time == 2000
    Host.advance(host, @now, 20_000)
    Host.run_due(host)
    assert length(target_writes(host)) == 2
    assert record(host).next_execution.monotonic_time == 23_000
    Host.advance(host, @now, 23_000)
    Host.run_due(host)
    assert record(host).object.all_writes_successful
  end

  test "busy writes are rejected before acceptance, including the same value and numeric triggers" do
    object = command([[action(device: oid(:device, 42), post_delay: 2)]])
    host = host(object, [], remote_write: fn _ref, _value, _priority -> :ok end)
    assert :ok = Host.write(host, ref(object), 1)
    busy = record(host)
    assert {:error, :busy} = Host.write(host, ref(object), 1)
    assert record(host) == busy
    assert {:error, :busy} = Command.update_property(busy.object, :present_value, 99)
    candidate = %{busy.object | present_value: 0}

    assert {:error, :busy} =
             Lifecycle.prepare_write(
               busy.object,
               candidate,
               context({:property_write, 85, nil, nil}, state: busy.state)
             )

    for property <- [:action, :action_text] do
      assert {:error, :busy} =
               Command.prepare_write(
                 busy.object,
                 busy.object,
                 context({:property_write, property, nil, nil}, state: busy.state)
               )
    end
  end

  test "computed flags reject client write preparation" do
    object = command()

    for property <- [:in_process, :all_writes_successful] do
      assert {:error, {:write_access_denied, ^property}} =
               Lifecycle.prepare_write(
                 object,
                 object,
                 context({:property_write, property, nil, nil})
               )
    end
  end

  test "missing write callbacks reject preparation without accepting the candidate" do
    object = command([[action()]])
    {:ok, candidate} = Command.update_property(object, :present_value, 1)

    assert {:error, {:unsupported_operation, :write_property}} =
             Lifecycle.prepare_write(object, candidate, context(write_trigger()))

    assert object.present_value == 0
    refute object.in_process

    assert {:ok, %Result{next_execution: nil}} =
             Lifecycle.execute(object, context(:initialization))
  end

  test "action codes are checked against current array size on each write" do
    object = command([[]])
    assert {:error, :value_out_of_range} = Command.update_property(object, :present_value, 2)

    assert {:error, :value_out_of_range} =
             Lifecycle.prepare_write(
               object,
               %{object | present_value: 2},
               context(write_trigger())
             )

    assert {:error, :value_out_of_range} = Command.create(1, "Invalid", %{present_value: 1})
  end

  test "configuration arrays synchronize in both directions and fill new slots" do
    object = command([[action()]], %{action_text: BACnetArray.from_list(["Lights"])})

    {:ok, grown} =
      Command.update_property(
        object,
        :action_text,
        BACnetArray.from_list(["Lights", "Empty", "Other"])
      )

    assert grown.action.size == 3
    assert {:ok, %ActionList{actions: []}} = BACnetArray.get_item(grown.action, 2)
    assert {:ok, shrunk} = Command.update_property(grown, :action, BACnetArray.from_list([]))
    assert shrunk.action_text.size == 0

    {:ok, expanded} =
      Command.update_property(shrunk, :action, BACnetArray.from_list([%ActionList{actions: []}]))

    assert {:ok, ""} = BACnetArray.get_item(expanded.action_text, 1)
    {:ok, added} = Command.add_property(command(), :action_text, BACnetArray.from_list(["Empty"]))
    assert added.action.size == 1

    assert {:ok, text_only} =
             Command.create(1, "Text", %{
               action_text: BACnetArray.from_list(["Empty"]),
               present_value: 1
             })

    assert text_only.action.size == 1

    assert {:error, {:invalid_configuration, :action_text}} =
             Command.create(1, "Mismatch", %{
               action: BACnetArray.from_list([%ActionList{actions: []}]),
               action_text: BACnetArray.from_list([])
             })
  end

  test "default-filled action arrays retain empty lists at their actual indices" do
    object = command([], %{action: BACnetArray.new(3, %ActionList{actions: []})})
    {:ok, candidate} = Command.update_property(object, :present_value, 3)
    {:ok, started} = Lifecycle.execute(candidate, context(write_trigger()))
    {:ok, completed} = step(started)
    assert completed.object.all_writes_successful
  end

  test "self-command is rejected by the published busy interlock" do
    object =
      command([
        [action(target: oid(:command, 1), priority: nil, value: enc(:unsigned_integer, 1))]
      ])

    host = host(object)
    assert :ok = Host.write(host, ref(object), 1)
    assert record(host).state.failures == [{ref(object), :busy}]
    refute record(host).object.all_writes_successful
    assert flags(record(host).object) == [false]
  end

  test "indirect command cycles stop at the busy object" do
    first =
      command([
        [action(target: oid(:command, 2), priority: nil, value: enc(:unsigned_integer, 1))]
      ])

    {:ok, second} =
      Command.create(2, "Second", %{
        action:
          BACnetArray.from_list([
            %ActionList{
              actions: [
                action(target: oid(:command, 1), priority: nil, value: enc(:unsigned_integer, 1))
              ]
            }
          ])
      })

    host = host(first, [second])
    assert :ok = Host.write(host, ref(first), 1)
    assert record(host).object.all_writes_successful
    other = Host.snapshot(host, oid(:command, 2))
    refute other.object.all_writes_successful
    assert other.state.failures == [{ref(first), :busy}]
  end

  test "remote writes preserve list values, numeric properties, array indices and optional priority" do
    values = [enc(:unsigned_integer, 7), enc(:character_string, "payload")]

    entry =
      action(
        device: oid(:device, 42),
        target: oid(:device, 43),
        property: 512,
        index: 0,
        priority: nil,
        value: values
      )

    object = command([[entry]])

    host =
      host(object, [],
        remote_write: fn reference, value, priority ->
          assert reference.device_identifier == oid(:device, 42)
          assert reference.property_identifier == 512
          assert reference.property_array_index == 0
          assert value === values
          assert priority == nil
          :ok
        end
      )

    assert :ok = Host.write(host, ref(object), 1)
    assert record(host).object.all_writes_successful
  end

  test "explicit self-device references normalize to local, other devices remain remote" do
    {:ok, output} = BinaryOutput.create(2, "Lighting")
    object = command([[action(device: oid(:device, 42)), action(device: oid(:device, 43))]])

    host =
      host(object, [output],
        device_identifier: oid(:device, 42),
        remote_write: fn _ref, _value, _priority -> :ok end
      )

    assert :ok = Host.write(host, ref(object), 1)

    assert [
             {%{device_identifier: nil}, _local_value, 8},
             {%{device_identifier: %{instance: 43}}, _remote_value, 8}
           ] =
             target_writes(host)
  end

  test "remote errors remain entry failures and do not stop following writes by default" do
    object = command([[action(device: oid(:device, 42)), action(device: oid(:device, 43))]])

    host =
      host(object, [],
        remote_write: fn reference, _value, _priority ->
          if reference.device_identifier.instance == 42, do: {:error, :timeout}, else: :ok
        end
      )

    assert :ok = Host.write(host, ref(object), 1)
    assert flags(record(host).object) == [false, true]
    refute record(host).object.all_writes_successful
    assert length(record(host).state.failures) == 1
  end

  test "initialization clears an interrupted sequence without replaying writes" do
    object =
      command([[action(write_successful: true)]], %{
        present_value: 1,
        in_process: true,
        all_writes_successful: true
      })

    assert {:ok, recovered} =
             Lifecycle.execute(
               object,
               context(:initialization,
                 state: :old_vm,
                 write_property: fn _ref, _value, _priority -> flunk("must not replay") end
               )
             )

    refute recovered.object.in_process
    refute recovered.object.all_writes_successful
    assert flags(recovered.object) == [true]
    assert recovered.state == nil
    assert recovered.next_execution == nil
  end

  test "malformed configurations and runtime state fail preflight without I/O" do
    object = command([[action()]])

    for bad <- [
          %{object | action: BACnetArray.new(1)},
          %{object | action_text: BACnetArray.from_list([])}
        ] do
      assert {:error, {:invalid_configuration, _property}} = Lifecycle.execute(bad, context())
    end

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(object, context(:periodic, state: :invalid))

    busy = %{object | present_value: 1, in_process: true}
    assert {:error, :invalid_execution_state} = Lifecycle.execute(busy, context())
    ctx = context(write_trigger(), write_property: fn _ref, _value, _priority -> :ok end)
    {:ok, started} = Lifecycle.execute(%{object | present_value: 1}, ctx)
    changed = %{started.object | present_value: 99}

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(
               changed,
               context(:continuation,
                 state: %{started.state | action_code: 99},
                 write_property: ctx.write_property
               )
             )
  end

  test "remote snapshots remain passive and reject local preparation" do
    {:ok, object} =
      Command.create(
        1,
        "Remote",
        %{
          present_value: 17,
          in_process: true,
          all_writes_successful: false,
          action: BACnetArray.new()
        },
        remote_object: 42
      )

    assert {:ok, %Result{object: ^object, state: :retained, next_execution: nil}} =
             Lifecycle.execute(object, context(:initialization, state: :retained))

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(object, object, context(write_trigger(), state: :retained))

    assert {:ok, updated} = Command.update_property(object, :present_value, 4)
    assert updated.present_value == 4
    assert :ok = Command.validate_execution(object, context(:periodic, state: :retained))

    assert {:error, :operation_not_available_for_remote_objects} =
             Command.prepare_write(object, object, context(write_trigger(), state: :retained))

    assert {:ok, %Result{object: ^object, state: :retained, next_execution: nil}} =
             Command.execute(object, context(:periodic, state: :retained))
  end

  test "optional properties other than action text are added directly" do
    {:ok, described} = Command.add_property(command(), :description, "Zone command")
    assert described.description == "Zone command"
  end

  test "an in-process position past the entry list is rejected" do
    object = command([[action()]], %{present_value: 1, in_process: true})

    state = %{
      phase: :ready,
      action_code: 1,
      entries: [action()],
      position: 2,
      all_success: true,
      halt: false,
      delay: 0,
      deadline: nil,
      failures: []
    }

    assert {:error, :invalid_execution_state} =
             Command.execute(object, context(:continuation, state: state))
  end

  test "numeric present-value triggers work and intrinsic metadata does not block execution" do
    object = command([[]], %{present_value: 1})
    assert {:ok, busy} = Lifecycle.execute(object, context({:property_write, 85, nil, nil}))
    assert busy.object.in_process

    assert_raise ArgumentError, "Object does not support intrinsic reporting", fn ->
      Command.create(1, "Intrinsic", %{}, intrinsic_reporting: true)
    end

    intrinsic = %{object | _metadata: %{object._metadata | intrinsic_reporting: true}}

    assert {:ok, %Result{object: initialized}} =
             Lifecycle.execute(intrinsic, context(:initialization))

    assert initialized._metadata.intrinsic_reporting
  end

  test "non-property triggers after completion preserve failure state without replaying writes" do
    object = command([[action(target: oid(:binary_output, 99))]])
    host = host(object)
    assert :ok = Host.write(host, ref(object), 1)
    completed = record(host)

    for trigger <- [
          :periodic,
          :clock_change,
          :timer,
          {:property_read, :all_writes_successful, nil}
        ] do
      assert :ok = Host.execute(host, oid(:command, 1), trigger)
      assert record(host) == completed
    end

    assert length(target_writes(host)) == 1
  end

  test "callback exceptions remain programming errors" do
    object = command([[action(device: oid(:device, 42))]], %{present_value: 1})

    ctx =
      context(write_trigger(), write_property: fn _ref, _value, _priority -> raise "host bug" end)

    {:ok, started} = Lifecycle.execute(object, ctx)

    assert_raise RuntimeError, "host bug", fn ->
      step(started, write_property: ctx.write_property)
    end
  end

  defp oid(type, instance), do: %ObjectIdentifier{type: type, instance: instance}
  defp enc(type, value), do: Encoding.create!({type, value})

  defp action(options \\ []) do
    %ActionCommand{
      device_identifier: Keyword.get(options, :device),
      object_identifier: Keyword.get(options, :target, oid(:binary_output, 2)),
      property_identifier: Keyword.get(options, :property, :present_value),
      property_array_index: Keyword.get(options, :index),
      property_value: Keyword.get(options, :value, enc(:enumerated, 1)),
      priority: Keyword.get(options, :priority, 8),
      post_delay: Keyword.get(options, :post_delay),
      quit_on_failure: Keyword.get(options, :quit_on_failure, false),
      write_successful: Keyword.get(options, :write_successful, false)
    }
  end

  defp command(lists \\ [], properties \\ %{}) do
    {:ok, object} =
      Command.create(
        1,
        "Command",
        Map.merge(
          %{action: BACnetArray.from_list(Enum.map(lists, &%ActionList{actions: &1}))},
          properties
        )
      )

    object
  end

  defp context(trigger \\ :periodic, options \\ []),
    do: Context.new(trigger, Keyword.merge([now: @now, monotonic_time: 0], options))

  defp write_trigger(), do: {:property_write, :present_value, nil, nil}

  defp step(stored, options \\ []),
    do:
      Lifecycle.execute(
        stored.object,
        context(:continuation, Keyword.merge([state: stored.state], options))
      )

  defp flags(object, code \\ 1) do
    {:ok, list} = BACnetArray.get_item(object.action, code)
    Enum.map(list.actions, & &1.write_successful)
  end

  defp host(object, targets \\ [], options \\ []) do
    host = Host.new(Enum.map([object | targets], &{&1, []}), @now, 0, options)

    for target <- targets, is_struct(target, BinaryOutput) do
      :ok = Host.execute(host, BinaryOutput.get_object_identifier(target), :initialization)
    end

    :ok = Host.execute(host, Command.get_object_identifier(object), :initialization)
    host
  end

  defp record(host), do: Host.snapshot(host, oid(:command, 1))

  defp ref(object),
    do: %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: object.__struct__.get_object_identifier(object),
      property_identifier: :present_value,
      property_array_index: nil
    }

  defp target_writes(host),
    do:
      Enum.reject(Host.writes(host), fn {reference, _value, _priority} ->
        reference.object_identifier == oid(:command, 1)
      end)
end
