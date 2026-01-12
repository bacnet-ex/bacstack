defmodule BACnet.Test.Protocol.ObjectTypes.BinaryInputTest do
  alias BACnet.Protocol.ObjectTypes.BinaryInput

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_binary_input

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify set_input/2 for normal priority and out_of_service = false" do
    {:ok, %BinaryInput{present_value: false} = obj} =
      BinaryInput.create(1, "TEST", %{polarity: :normal})

    assert {:ok, %BinaryInput{present_value: true}} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, false)
    assert {:ok, %BinaryInput{present_value: true}} = BinaryInput.set_input(obj, true)

    assert {:ok, %BinaryInput{present_value: true} = obj} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: false} = obj} = BinaryInput.set_input(obj, false)
    assert {:ok, %BinaryInput{present_value: true}} = BinaryInput.set_input(obj, true)
  end

  test "verify set_input/2 for reversed priority and out_of_service = false" do
    # Starts with false, regardless of polarity
    {:ok, %BinaryInput{present_value: false} = obj} =
      BinaryInput.create(1, "TEST", %{polarity: :reverse})

    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: true}} = BinaryInput.set_input(obj, false)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)

    assert {:ok, %BinaryInput{present_value: false} = obj} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: true} = obj} = BinaryInput.set_input(obj, false)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)
  end

  test "verify set_input/2 for normal priority and out_of_service = true" do
    {:ok, %BinaryInput{present_value: false} = obj} =
      BinaryInput.create(1, "TEST", %{out_of_service: true, polarity: :normal})

    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, false)
  end

  test "verify set_input/2 for reverse priority and out_of_service = true" do
    {:ok, %BinaryInput{present_value: false} = obj} =
      BinaryInput.create(1, "TEST", %{out_of_service: true, polarity: :reverse})

    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, false)
  end
end
