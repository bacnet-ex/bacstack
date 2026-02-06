defmodule BACnet.Test.Protocol.ObjectTypes.AnalogOutputTest do
  alias BACnet.Protocol.ObjectTypes.AnalogOutput

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_analog_output

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify update_property/3 for present_value ignores min/max if max not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{min_present_value: 50.0, out_of_service: true})

    assert {:ok, %AnalogOutput{present_value: -51.0}} =
             AnalogOutput.update_property(obj, :present_value, -51.0)

    assert {:ok, %AnalogOutput{present_value: -32_767.0}} =
             AnalogOutput.update_property(obj, :present_value, -32_767.0)
  end

  test "verify update_property/3 for present_value ignores min/max if min not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, out_of_service: true})

    assert {:ok, %AnalogOutput{present_value: 51.0}} =
             AnalogOutput.update_property(obj, :present_value, 51.0)

    assert {:ok, %AnalogOutput{present_value: 32_767.0}} =
             AnalogOutput.update_property(obj, :present_value, 32_767.0)
  end

  test "verify update_property/3 for present_value working within configured min/max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        out_of_service: true
      })

    assert {:ok, %AnalogOutput{present_value: -20.0}} =
             AnalogOutput.update_property(obj, :present_value, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0}} =
             AnalogOutput.update_property(obj, :present_value, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0}} =
             AnalogOutput.update_property(obj, :present_value, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0}} =
             AnalogOutput.update_property(obj, :present_value, 50.0)

    assert {:ok, %AnalogOutput{present_value: -20.0} = obj} =
             AnalogOutput.update_property(obj, :present_value, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0} = obj} =
             AnalogOutput.update_property(obj, :present_value, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0} = obj} =
             AnalogOutput.update_property(obj, :present_value, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0} = obj} =
             AnalogOutput.update_property(obj, :present_value, 50.0)

    assert {:ok, %AnalogOutput{present_value: +0.0}} =
             AnalogOutput.update_property(obj, :present_value, 0.0)
  end

  test "verify update_property/3 for present_value fails on value lower than min" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        out_of_service: true
      })

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogOutput.update_property(obj, :present_value, -51.0)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogOutput.update_property(obj, :present_value, -32_767.0)
  end

  test "verify update_property/3 for present_value fails on value higher than max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        out_of_service: true
      })

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogOutput.update_property(obj, :present_value, 51.0)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogOutput.update_property(obj, :present_value, 32_767.0)
  end

  test "verify update_property/3 for relinquish_default ignores min/max if max not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{min_present_value: 50.0})

    assert {:ok, %AnalogOutput{present_value: -51.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -51.0)

    assert {:ok, %AnalogOutput{present_value: -32_767.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -32_767.0)
  end

  test "verify update_property/3 for relinquish_default ignores min/max if min not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0})

    assert {:ok, %AnalogOutput{present_value: 51.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 51.0)

    assert {:ok, %AnalogOutput{present_value: 32_767.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 32_767.0)
  end

  test "verify update_property/3 for relinquish_default working within configured min/max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogOutput{present_value: -20.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 50.0)

    assert {:ok, %AnalogOutput{present_value: -20.0} = obj} =
             AnalogOutput.update_property(obj, :relinquish_default, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0} = obj} =
             AnalogOutput.update_property(obj, :relinquish_default, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0} = obj} =
             AnalogOutput.update_property(obj, :relinquish_default, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0} = obj} =
             AnalogOutput.update_property(obj, :relinquish_default, 50.0)

    assert {:ok, %AnalogOutput{present_value: +0.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 0.0)
  end

  test "verify update_property/3 for relinquish_default fails on value lower than min" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, -51.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, -32_767.0)
  end

  test "verify update_property/3 for relinquish_default fails on value higher than max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, 51.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, 32_767.0)
  end

  test "verify update_property/3 only checks present_value/relinquish_default for min/max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogOutput{cov_increment: -51.0}} =
             AnalogOutput.update_property(obj, :cov_increment, -51.0)

    assert {:ok, %AnalogOutput{cov_increment: 51.0}} =
             AnalogOutput.update_property(obj, :cov_increment, 51.0)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{min_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %AnalogOutput{present_value: -51.0}} = AnalogOutput.set_priority(obj, 16, -51.0)

    assert {:ok, %AnalogOutput{present_value: -32_767.0}} =
             AnalogOutput.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %AnalogOutput{present_value: 51.0}} = AnalogOutput.set_priority(obj, 16, 51.0)

    assert {:ok, %AnalogOutput{present_value: 32_767.0}} =
             AnalogOutput.set_priority(obj, 16, 32_767.0)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:ok, %AnalogOutput{present_value: -20.0}} = AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0}} = AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0}} = AnalogOutput.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0}} = AnalogOutput.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogOutput{present_value: -20.0} = obj} =
             AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0} = obj} =
             AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0} = obj} =
             AnalogOutput.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0} = obj} =
             AnalogOutput.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogOutput{present_value: +0.0}} = AnalogOutput.set_priority(obj, 16, 0.0)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, -51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, 51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, 32_767.0)
  end
end
