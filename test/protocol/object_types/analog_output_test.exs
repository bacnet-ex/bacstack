defmodule BACnet.Test.Protocol.ObjectTypes.AnalogOutputTest do
  alias BACnet.Protocol.ObjectTypes.AnalogOutput

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_analog_output

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "create/4 priority array overrides given present value" do
    assert {:ok, %AnalogOutput{present_value: 0.0}} =
             AnalogOutput.create(1, "TEST", %{present_value: 25.0})
  end

  test "verify get_property/2 with present_value respects command prioritization on out of service" do
    {:ok, %AnalogOutput{present_value: 25.0} = obj} =
      AnalogOutput.create(1, "TEST", %{relinquish_default: 25.0})

    assert {:ok, 25.0} = AnalogOutput.get_property(obj, :present_value)

    {:ok, obj} = AnalogOutput.update_property(obj, :out_of_service, true)

    assert {:ok, 25.0} = AnalogOutput.get_property(obj, :present_value)
    assert {:ok, %{present_value: 26.0} = obj} = AnalogOutput.set_priority(obj, 16, 26.0)
    assert {:ok, %{present_value: 6.0} = obj} = AnalogOutput.set_priority(obj, 1, 6.0)

    assert {:ok, %{present_value: 6.0}} =
             AnalogOutput.update_property(obj, :out_of_service, false)
  end

  test "verify update_property/3 for present_value ignores min/max if max not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{min_present_value: 50.0})

    assert {:ok, %AnalogOutput{present_value: -51.0}} =
             AnalogOutput.set_priority(obj, 16, -51.0)

    assert {:ok, %AnalogOutput{present_value: -32_767.0}} =
             AnalogOutput.set_priority(obj, 16, -32_767.0)
  end

  test "verify update_property/3 for present_value ignores min/max if min not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0})

    assert {:ok, %AnalogOutput{present_value: 51.0}} =
             AnalogOutput.set_priority(obj, 16, 51.0)

    assert {:ok, %AnalogOutput{present_value: 32_767.0}} =
             AnalogOutput.set_priority(obj, 16, 32_767.0)
  end

  test "verify update_property/3 for present_value working within configured min/max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0
      })

    assert {:ok, %AnalogOutput{present_value: -20.0}} =
             AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0}} =
             AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0}} =
             AnalogOutput.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0}} =
             AnalogOutput.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogOutput{present_value: -20.0} = obj} =
             AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0} = obj} =
             AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0} = obj} =
             AnalogOutput.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0} = obj} =
             AnalogOutput.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogOutput{present_value: +0.0}} =
             AnalogOutput.set_priority(obj, 16, 0.0)

    assert {:ok, %AnalogOutput{present_value: :NaN}} =
             AnalogOutput.set_priority(obj, 16, :NaN)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :inf)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :infn)
  end

  test "verify update_property/3 for present_value working within configured infinite min/max" do
    {:ok, %AnalogOutput{:present_value => +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: :inf,
        min_present_value: :infn
      })

    assert {:ok, %AnalogOutput{:present_value => 20.0}} =
             AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{:present_value => -20.0}} =
             AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{:present_value => :inf}} =
             AnalogOutput.set_priority(obj, 16, :inf)

    assert {:ok, %AnalogOutput{:present_value => :infn}} =
             AnalogOutput.set_priority(obj, 16, :infn)

    assert {:ok, %AnalogOutput{:present_value => :NaN}} =
             AnalogOutput.set_priority(obj, 16, :NaN)
  end

  test "verify update_property/3 for present_value fails on value lower than min" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, -51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, -32_767.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :infn)
  end

  test "verify update_property/3 for present_value fails on value higher than max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, 51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, 32_767.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :inf)
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

    assert {:ok, %AnalogOutput{present_value: :NaN}} =
             AnalogOutput.update_property(obj, :relinquish_default, :NaN)
  end

  test "verify update_property/3 for relinquish_default working within configured infinite min/max" do
    {:ok, %AnalogOutput{:present_value => +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: :inf,
        min_present_value: :infn
      })

    assert {:ok, %AnalogOutput{:present_value => 20.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 20.0)

    assert {:ok, %AnalogOutput{:present_value => -20.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -20.0)

    assert {:ok, %AnalogOutput{:present_value => :inf}} =
             AnalogOutput.update_property(obj, :relinquish_default, :inf)

    assert {:ok, %AnalogOutput{:present_value => :infn}} =
             AnalogOutput.update_property(obj, :relinquish_default, :infn)

    assert {:ok, %AnalogOutput{:present_value => :NaN}} =
             AnalogOutput.update_property(obj, :relinquish_default, :NaN)
  end

  test "verify update_property/3 for relinquish_default fails on value lower than min" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, -51.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, -32_767.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, :infn)
  end

  test "verify update_property/3 for relinquish_default fails on value higher than max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, 51.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, 32_767.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, :inf)
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

    assert {:ok, %AnalogOutput{present_value: :NaN}} = AnalogOutput.set_priority(obj, 16, :NaN)
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

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :infn)
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

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :inf)
  end

  test "verify get_output/2 on out of service" do
    {:ok, %AnalogOutput{present_value: 25.0} = obj} =
      AnalogOutput.create(1, "TEST", %{relinquish_default: 25.0})

    assert 25.0 == AnalogOutput.get_output(obj)
    assert {:ok, 25.0} = AnalogOutput.get_property(obj, :present_value)

    {:ok, obj} = AnalogOutput.update_property(obj, :out_of_service, true)
    assert 0.0 == AnalogOutput.get_output(obj)
    assert 100.0 == AnalogOutput.get_output(obj, 100.0)

    {:ok, obj} = AnalogOutput.update_property(obj, :relinquish_default, 50.0)
    assert {:ok, 50.0} = AnalogOutput.get_property(obj, :present_value)

    assert 0.0 == AnalogOutput.get_output(obj)
    assert 100.0 == AnalogOutput.get_output(obj, 100.0)

    {:ok, obj} = AnalogOutput.update_property(obj, :out_of_service, false)
    assert 50.0 == AnalogOutput.get_output(obj)

    {:ok, obj} = AnalogOutput.update_property(obj, :relinquish_default, 10.0)
    assert {:ok, 10.0} = AnalogOutput.get_property(obj, :present_value)
    assert 10.0 == AnalogOutput.get_output(obj)
  end
end
