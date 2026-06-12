defmodule BACnet.Test.Protocol.ObjectTypes.BinaryValueTest do
  alias BACnet.Protocol.ObjectTypes.BinaryValue

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_binary_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "create/4 priority array overrides given present value" do
    assert {:ok, %BinaryValue{present_value: false}} =
             BinaryValue.create(1, "TEST", %{present_value: true, relinquish_default: false})
  end

  test "add_property/3 priority array overrides given present value" do
    {:ok, %BinaryValue{present_value: false} = obj} =
      BinaryValue.create(1, "TEST", %{present_value: false})

    assert {:ok, %BinaryValue{present_value: true}} =
             BinaryValue.add_property(obj, :relinquish_default, true)
  end
end
