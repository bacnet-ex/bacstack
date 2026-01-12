defmodule BACnet.Test.Protocol.ObjectTypes.AnalogInputTest do
  alias BACnet.Protocol.ObjectTypes.AnalogInput

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_analog_input

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify update_property/3 for present_value ignores min/max if max not present" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{min_present_value: 50.0})

    assert {:ok, %AnalogInput{present_value: -51.0}} =
             AnalogInput.update_property(obj, :present_value, -51.0)

    assert {:ok, %AnalogInput{present_value: -32_767.0}} =
             AnalogInput.update_property(obj, :present_value, -32_767.0)
  end

  test "verify update_property/3 for present_value ignores min/max if min not present" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0})

    assert {:ok, %AnalogInput{present_value: 51.0}} =
             AnalogInput.update_property(obj, :present_value, 51.0)

    assert {:ok, %AnalogInput{present_value: 32_767.0}} =
             AnalogInput.update_property(obj, :present_value, 32_767.0)
  end

  test "verify update_property/3 for present_value working within configured min/max" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogInput{present_value: -20.0}} =
             AnalogInput.update_property(obj, :present_value, -20.0)

    assert {:ok, %AnalogInput{present_value: 20.0}} =
             AnalogInput.update_property(obj, :present_value, 20.0)

    assert {:ok, %AnalogInput{present_value: -50.0}} =
             AnalogInput.update_property(obj, :present_value, -50.0)

    assert {:ok, %AnalogInput{present_value: 50.0}} =
             AnalogInput.update_property(obj, :present_value, 50.0)

    assert {:ok, %AnalogInput{present_value: -20.0} = obj} =
             AnalogInput.update_property(obj, :present_value, -20.0)

    assert {:ok, %AnalogInput{present_value: 20.0} = obj} =
             AnalogInput.update_property(obj, :present_value, 20.0)

    assert {:ok, %AnalogInput{present_value: -50.0} = obj} =
             AnalogInput.update_property(obj, :present_value, -50.0)

    assert {:ok, %AnalogInput{present_value: 50.0} = obj} =
             AnalogInput.update_property(obj, :present_value, 50.0)

    assert {:ok, %AnalogInput{present_value: +0.0}} =
             AnalogInput.update_property(obj, :present_value, 0.0)
  end

  test "verify update_property/3 for present_value fails on value lower than min" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, -51.0)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, -32_767.0)
  end

  test "verify update_property/3 for present_value fails on value higher than max" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, 51.0)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, 32_767.0)
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogInput{cov_increment: -51.0}} =
             AnalogInput.update_property(obj, :cov_increment, -51.0)

    assert {:ok, %AnalogInput{cov_increment: 51.0}} =
             AnalogInput.update_property(obj, :cov_increment, 51.0)
  end
end
