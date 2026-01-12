defmodule BACnet.Test.Protocol.ObjectTypes.BinaryValueTest do
  alias BACnet.Protocol.ObjectTypes.BinaryValue

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_binary_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify get_output/1 for normal priority" do
    {:ok, %BinaryValue{present_value: false} = obj} =
      BinaryValue.create(1, "TEST", %{polarity: :normal})

    assert false == BinaryValue.get_output(obj)

    {:ok, obj} = BinaryValue.update_property(obj, :present_value, true)
    assert true == BinaryValue.get_output(obj)

    {:ok, obj} = BinaryValue.update_property(obj, :present_value, false)
    assert false == BinaryValue.get_output(obj)
  end

  test "verify get_output/1 for reverse priority" do
    {:ok, %BinaryValue{present_value: false} = obj} =
      BinaryValue.create(1, "TEST", %{polarity: :reverse})

    assert true == BinaryValue.get_output(obj)

    {:ok, obj} = BinaryValue.update_property(obj, :present_value, true)
    assert false == BinaryValue.get_output(obj)

    {:ok, obj} = BinaryValue.update_property(obj, :present_value, false)
    assert true == BinaryValue.get_output(obj)
  end
end
