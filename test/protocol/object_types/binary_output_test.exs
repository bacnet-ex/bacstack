defmodule BACnet.Test.Protocol.ObjectTypes.BinaryOutputTest do
  alias BACnet.Protocol.ObjectTypes.BinaryOutput

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_binary_output

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "create/4 priority array overrides given present value" do
    assert {:ok, %BinaryOutput{present_value: false}} =
             BinaryOutput.create(1, "TEST", %{present_value: true})
  end

  test "verify get_property/2 with present_value respects command prioritization on out of service" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{relinquish_default: false})

    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, true)

    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)
    assert {:ok, %{present_value: true} = obj} = BinaryOutput.set_priority(obj, 16, true)
    assert {:ok, %{present_value: false} = obj} = BinaryOutput.set_priority(obj, 1, false)

    assert {:ok, %{present_value: false}} =
             BinaryOutput.update_property(obj, :out_of_service, false)
  end

  test "verify get_output/1 for normal polarity" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :normal})

    assert false == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert true == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert false == BinaryOutput.get_output(obj)
  end

  test "verify get_output/1 for reverse polarity" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :reverse})

    assert true == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert false == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert true == BinaryOutput.get_output(obj)
  end

  test "verify get_output/2 for normal polarity on out of service" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :normal})

    assert false == BinaryOutput.get_output(obj)
    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, true)
    assert false == BinaryOutput.get_output(obj)
    assert true == BinaryOutput.get_output(obj, true)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert {:ok, true} = BinaryOutput.get_property(obj, :present_value)

    assert false == BinaryOutput.get_output(obj)
    assert true == BinaryOutput.get_output(obj, true)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, false)
    assert true == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)
    assert false == BinaryOutput.get_output(obj)
  end

  test "verify get_output/2 for reverse polarity on out of service" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :reverse})

    assert true == BinaryOutput.get_output(obj)
    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, true)
    assert false == BinaryOutput.get_output(obj)
    assert true == BinaryOutput.get_output(obj, true)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert {:ok, true} = BinaryOutput.get_property(obj, :present_value)

    assert false == BinaryOutput.get_output(obj)
    assert true == BinaryOutput.get_output(obj, true)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, false)
    assert false == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)
    assert true == BinaryOutput.get_output(obj)
  end
end
