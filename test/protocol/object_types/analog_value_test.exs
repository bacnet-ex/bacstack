defmodule BACnet.Test.Protocol.ObjectTypes.AnalogValueTest do
  alias BACnet.Protocol.ObjectTypes.AnalogValue

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_analog_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  for property <- [:present_value, :relinquish_default] do
    test "verify update_property/3 for #{property} ignores min/max if max not present" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{unquote(property) => 0.0, min_present_value: 50.0})

      assert {:ok, %AnalogValue{unquote(property) => -51.0}} =
               AnalogValue.update_property(obj, unquote(property), -51.0)

      assert {:ok, %AnalogValue{unquote(property) => -32_767.0}} =
               AnalogValue.update_property(obj, unquote(property), -32_767.0)
    end

    test "verify update_property/3 for #{property} ignores min/max if min not present" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{unquote(property) => 0.0, max_present_value: 50.0})

      assert {:ok, %AnalogValue{unquote(property) => 51.0}} =
               AnalogValue.update_property(obj, unquote(property), 51.0)

      assert {:ok, %AnalogValue{unquote(property) => 32_767.0}} =
               AnalogValue.update_property(obj, unquote(property), 32_767.0)
    end

    test "verify update_property/3 for #{property} working within configured min/max" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:ok, %AnalogValue{unquote(property) => -20.0}} =
               AnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %AnalogValue{unquote(property) => 20.0}} =
               AnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %AnalogValue{unquote(property) => -50.0}} =
               AnalogValue.update_property(obj, unquote(property), -50.0)

      assert {:ok, %AnalogValue{unquote(property) => 50.0}} =
               AnalogValue.update_property(obj, unquote(property), 50.0)

      assert {:ok, %AnalogValue{unquote(property) => -20.0} = obj} =
               AnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %AnalogValue{unquote(property) => 20.0} = obj} =
               AnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %AnalogValue{unquote(property) => -50.0} = obj} =
               AnalogValue.update_property(obj, unquote(property), -50.0)

      assert {:ok, %AnalogValue{unquote(property) => 50.0} = obj} =
               AnalogValue.update_property(obj, unquote(property), 50.0)

      assert {:ok, %AnalogValue{unquote(property) => +0.0}} =
               AnalogValue.update_property(obj, unquote(property), 0.0)
    end

    test "verify update_property/3 for #{property} working within configured infinite min/max" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: :inf,
          min_present_value: :infn
        })

      assert {:ok, %AnalogValue{unquote(property) => 20.0}} =
               AnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %AnalogValue{unquote(property) => -20.0}} =
               AnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %AnalogValue{unquote(property) => :inf}} =
               AnalogValue.update_property(obj, unquote(property), :inf)

      assert {:ok, %AnalogValue{unquote(property) => :infn}} =
               AnalogValue.update_property(obj, unquote(property), :infn)

      assert {:ok, %AnalogValue{unquote(property) => :NaN}} =
               AnalogValue.update_property(obj, unquote(property), :NaN)
    end

    test "verify update_property/3 for #{property} fails on value lower than min" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), -51.0)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), -32_767.0)
    end

    test "verify update_property/3 for #{property} fails on value higher than max" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), 51.0)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), 32_767.0)
    end
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogValue{cov_increment: -51.0}} =
             AnalogValue.update_property(obj, :cov_increment, -51.0)

    assert {:ok, %AnalogValue{cov_increment: 51.0}} =
             AnalogValue.update_property(obj, :cov_increment, 51.0)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{min_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %AnalogValue{present_value: -51.0}} = AnalogValue.set_priority(obj, 16, -51.0)

    assert {:ok, %AnalogValue{present_value: -32_767.0}} =
             AnalogValue.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{max_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %AnalogValue{present_value: 51.0}} = AnalogValue.set_priority(obj, 16, 51.0)

    assert {:ok, %AnalogValue{present_value: 32_767.0}} =
             AnalogValue.set_priority(obj, 16, 32_767.0)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:ok, %AnalogValue{present_value: -20.0}} = AnalogValue.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogValue{present_value: 20.0}} = AnalogValue.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogValue{present_value: -50.0}} = AnalogValue.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogValue{present_value: 50.0}} = AnalogValue.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogValue{present_value: -20.0} = obj} =
             AnalogValue.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogValue{present_value: 20.0} = obj} =
             AnalogValue.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogValue{present_value: -50.0} = obj} =
             AnalogValue.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogValue{present_value: 50.0} = obj} =
             AnalogValue.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogValue{present_value: +0.0}} = AnalogValue.set_priority(obj, 16, 0.0)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, -51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, 51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, 32_767.0)
  end
end
