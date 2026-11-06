defmodule BACnet.Test.Protocol.ObjectExecution.ContextTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.Calendar

  use ExUnit.Case, async: true

  @moduletag :object_test

  @context %Context{
    now: ~U[2026-11-06 12:00:00Z],
    monotonic_time: -1000,
    trigger: :periodic,
    state: nil,
    lookup_object: nil,
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

  test "lookup preserves local and remote object references and propagates host errors" do
    assert {:ok, calendar} = Calendar.create(1, "Calendar")

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

  test "missing callbacks report unsupported operations" do
    assert {:error, {:unsupported_operation, :lookup_object}} =
             Context.lookup_object(@context, @object_reference)

    assert {:error, {:unsupported_operation, :read_property}} =
             Context.read_property(@context, @property_reference)

    assert {:error, {:unsupported_operation, :write_property}} =
             Context.write_property(@context, @property_reference, true)
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
end
