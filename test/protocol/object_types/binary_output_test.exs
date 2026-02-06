defmodule BACnet.Test.Protocol.ObjectTypes.BinaryOutputTest do
  alias BACnet.Protocol.ObjectTypes.BinaryOutput

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_binary_output

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify get_output/1 for normal priority" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :normal})

    assert false == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert true == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert false == BinaryOutput.get_output(obj)
  end

  test "verify get_output/1 for reverse priority" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :reverse})

    assert true == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert false == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert true == BinaryOutput.get_output(obj)
  end
end
