defmodule BACnet.Test.Protocol.ObjectsProtocolTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsBehaviour
  alias BACnet.Protocol.ObjectsProtocol
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.BinaryOutput

  use ExUnit.Case, async: true

  @moduletag :object_test

  defmodule ExecutableObject do
    use BACnet.Protocol.ObjectsMacro

    @type object_opts :: common_object_opts()

    bac_object :binary_input do
      field(:present_value, boolean(), required: true, default: false)
    end

    @impl ObjectsBehaviour
    def execute(object, %Context{options: options} = context) do
      if Keyword.get(options, :skip, false) do
        super(object, context)
      else
        with {:ok, value} <- Context.read_property(context, Keyword.fetch!(options, :source)),
             {:ok, updated} <- update_property(object, :present_value, value),
             :ok <-
               Context.write_property(
                 context,
                 Keyword.fetch!(options, :target),
                 value,
                 Keyword.get(options, :priority)
               ) do
          state = %{
            executions: if(is_nil(context.state), do: 1, else: context.state.executions + 1),
            wall_time: context.now,
            monotonic_time: context.monotonic_time,
            trigger: context.trigger
          }

          {:ok, %Result{object: updated, state: state}}
        end
      end
    end
  end

  @now ~U[2026-11-06 12:00:00Z]

  @source %DeviceObjectPropertyRef{
    object_identifier: %ObjectIdentifier{type: :binary_input, instance: 1},
    property_identifier: :present_value,
    property_array_index: nil,
    device_identifier: nil
  }

  @target %{@source | object_identifier: %ObjectIdentifier{type: :binary_output, instance: 2}}

  test "every built-in object exports execute/2 and implements the protocol with a no-op default" do
    context = %Context{
      now: @now,
      monotonic_time: -1000,
      state: %{preserve: make_ref()},
      lookup_object: fn _ref -> flunk("no-op must not look up objects") end,
      read_property: fn _ref -> flunk("no-op must not read properties") end,
      write_property: fn _ref, _value, _priority -> flunk("no-op must not write properties") end
    }

    for module <- Map.values(ObjectsUtility.get_object_type_mappings()) do
      object = struct(module)
      expected = %Result{object: object, state: context.state}

      assert ObjectsBehaviour in module.__info__(:attributes)[:behaviour]
      assert function_exported?(module, :execute, 2)
      assert ObjectsProtocol.impl_for(object) != nil
      assert {:ok, ^expected} = module.execute(object, context)
      assert {:ok, ^expected} = ObjectsProtocol.execute(object, context)

      assert {:ok, %Result{object: ^object, state: nil}} =
               ObjectsProtocol.execute(object, %{context | state: nil})
    end
  end

  test "an object owns execution using host I/O and caller-retained state across clock changes" do
    assert {:ok, object} = ExecutableObject.create(1, "Executable object")
    assert {:ok, output} = BinaryOutput.create(2, "Target output")
    Process.put(:execution_target, output)
    Process.put(:execution_source, true)

    context = %Context{
      now: @now,
      monotonic_time: -1000,
      options: [source: @source, target: @target, priority: 8],
      read_property: fn reference ->
        assert reference == @source
        {:ok, Process.get(:execution_source)}
      end,
      write_property: fn reference, value, priority ->
        assert reference == @target

        with {:ok, updated} <-
               BinaryOutput.set_priority(Process.get(:execution_target), priority, value) do
          Process.put(:execution_target, updated)
          :ok
        end
      end
    }

    assert {:ok, %Result{object: updated, state: state}} =
             ExecutableObject.execute(object, context)

    assert updated.present_value == true

    assert state == %{
             executions: 1,
             wall_time: @now,
             monotonic_time: -1000,
             trigger: :periodic
           }

    assert Process.get(:execution_target).present_value == true
    assert object.present_value == false

    # Wall time can move backwards while elapsed time continues forwards.
    Process.put(:execution_source, false)

    next_context = %{
      context
      | now: DateTime.add(@now, -3600, :second),
        monotonic_time: -500,
        state: state,
        trigger: :clock_change
    }

    assert {:ok, %Result{object: next_object, state: next_state}} =
             ObjectsProtocol.execute(updated, next_context)

    assert next_object.present_value == false
    assert Process.get(:execution_target).present_value == false

    assert next_state == %{
             executions: 2,
             wall_time: next_context.now,
             monotonic_time: -500,
             trigger: :clock_change
           }

    # A separate instance begins with its own initial state.
    assert {:ok, other} = ExecutableObject.create(3, "Another executable object")
    assert {:ok, %Result{state: %{executions: 1}}} = ObjectsProtocol.execute(other, context)
    assert updated.present_value == true
  end

  test "repeated same-value write triggers are available to the object implementation" do
    assert {:ok, object} = ExecutableObject.create(1, "Executable object")

    context = %Context{
      now: @now,
      monotonic_time: 0,
      trigger: {:property_write, :present_value, nil, 8},
      options: [source: @source, target: @target],
      read_property: fn _reference -> {:ok, false} end,
      write_property: fn _ref, _value, _priority -> :ok end
    }

    assert {:ok, %Result{object: ^object, state: state}} =
             ObjectsProtocol.execute(object, context)

    assert state.trigger == {:property_write, :present_value, nil, 8}
    assert state.executions == 1

    assert {:ok, %Result{object: ^object, state: next_state}} =
             ObjectsProtocol.execute(object, %{context | state: state})

    assert next_state.trigger == state.trigger
    assert next_state.executions == 2
  end

  test "overrides can call the unchanged-object default through super" do
    assert {:ok, object} = ExecutableObject.create(1, "Executable object")
    context = %Context{now: @now, monotonic_time: 0, state: :preserved, options: [skip: true]}
    result = %Result{object: object, state: :preserved}

    assert {:ok, ^result} = ExecutableObject.execute(object, context)
    assert {:ok, ^result} = ObjectsProtocol.execute(object, context)
  end

  test "protocol dispatch preserves validation and host operation errors from an override" do
    assert {:ok, object} = ExecutableObject.create(1, "Executable object")

    context = %Context{
      now: @now,
      monotonic_time: 0,
      options: [source: @source, target: @target],
      read_property: fn _reference -> {:ok, :invalid} end,
      write_property: fn _ref, _value, _priority -> flunk("invalid value must not be written") end
    }

    assert {:error, {:invalid_property_type, :present_value}} =
             ObjectsProtocol.execute(object, context)

    assert {:error, :read_failed} =
             ObjectsProtocol.execute(object, %{
               context
               | read_property: fn _reference -> {:error, :read_failed} end
             })

    assert {:error, :write_failed} =
             ObjectsProtocol.execute(object, %{
               context
               | read_property: fn _reference -> {:ok, true} end,
                 write_property: fn _ref, _value, _priority -> {:error, :write_failed} end
             })

    assert {:error, {:unsupported_operation, :read_property}} =
             ObjectsProtocol.execute(object, %{context | read_property: nil})
  end

  test "a built-in object requires the common context even when it has no execution logic" do
    assert_raise FunctionClauseError, fn ->
      BinaryOutput.execute(struct(BinaryOutput), [])
    end
  end

  test "unsupported values do not silently execute as BACnet objects" do
    assert ObjectsProtocol.impl_for(~D[2026-11-06]) == nil

    assert_raise Protocol.UndefinedError, fn ->
      ObjectsProtocol.execute(~D[2026-11-06], %Context{now: @now, monotonic_time: 0})
    end
  end
end
