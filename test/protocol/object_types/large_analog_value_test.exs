defmodule BACnet.Test.Protocol.ObjectTypes.LargeAnalogValueTest do
  alias BACnet.Protocol.ObjectTypes.LargeAnalogValue

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_large_analog_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  for property <- [:present_value, :relinquish_default] do
    test "verify update_property/3 for #{property} ignores min/max if max not present" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{unquote(property) => 0.0, min_present_value: 50.0})

      assert {:ok, %LargeAnalogValue{unquote(property) => -51.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), -51.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => -32_767.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), -32_767.0)
    end

    test "verify update_property/3 for #{property} ignores min/max if min not present" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{unquote(property) => 0.0, max_present_value: 50.0})

      assert {:ok, %LargeAnalogValue{unquote(property) => 51.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 51.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 32_767.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 32_767.0)
    end

    test "verify update_property/3 for #{property} working within configured min/max" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:ok, %LargeAnalogValue{unquote(property) => -20.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 20.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => -50.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), -50.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 50.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 50.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => -20.0} = obj} =
               LargeAnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 20.0} = obj} =
               LargeAnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => -50.0} = obj} =
               LargeAnalogValue.update_property(obj, unquote(property), -50.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 50.0} = obj} =
               LargeAnalogValue.update_property(obj, unquote(property), 50.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => +0.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 0.0)
    end

    test "verify update_property/3 for #{property} fails on value lower than min" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:error, {:property_out_of_range, unquote(property)}} =
               LargeAnalogValue.update_property(obj, unquote(property), -51.0)

      assert {:error, {:property_out_of_range, unquote(property)}} =
               LargeAnalogValue.update_property(obj, unquote(property), -32_767.0)
    end

    test "verify update_property/3 for #{property} fails on value higher than max" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:error, {:property_out_of_range, unquote(property)}} =
               LargeAnalogValue.update_property(obj, unquote(property), 51.0)

      assert {:error, {:property_out_of_range, unquote(property)}} =
               LargeAnalogValue.update_property(obj, unquote(property), 32_767.0)
    end
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %LargeAnalogValue{cov_increment: -51.0}} =
             LargeAnalogValue.update_property(obj, :cov_increment, -51.0)

    assert {:ok, %LargeAnalogValue{cov_increment: 51.0}} =
             LargeAnalogValue.update_property(obj, :cov_increment, 51.0)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{min_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %LargeAnalogValue{present_value: -51.0}} =
             LargeAnalogValue.set_priority(obj, 16, -51.0)

    assert {:ok, %LargeAnalogValue{present_value: -32_767.0}} =
             LargeAnalogValue.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{max_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %LargeAnalogValue{present_value: 51.0}} =
             LargeAnalogValue.set_priority(obj, 16, 51.0)

    assert {:ok, %LargeAnalogValue{present_value: 32_767.0}} =
             LargeAnalogValue.set_priority(obj, 16, 32_767.0)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:ok, %LargeAnalogValue{present_value: -20.0}} =
             LargeAnalogValue.set_priority(obj, 16, -20.0)

    assert {:ok, %LargeAnalogValue{present_value: 20.0}} =
             LargeAnalogValue.set_priority(obj, 16, 20.0)

    assert {:ok, %LargeAnalogValue{present_value: -50.0}} =
             LargeAnalogValue.set_priority(obj, 16, -50.0)

    assert {:ok, %LargeAnalogValue{present_value: 50.0}} =
             LargeAnalogValue.set_priority(obj, 16, 50.0)

    assert {:ok, %LargeAnalogValue{present_value: -20.0} = obj} =
             LargeAnalogValue.set_priority(obj, 16, -20.0)

    assert {:ok, %LargeAnalogValue{present_value: 20.0} = obj} =
             LargeAnalogValue.set_priority(obj, 16, 20.0)

    assert {:ok, %LargeAnalogValue{present_value: -50.0} = obj} =
             LargeAnalogValue.set_priority(obj, 16, -50.0)

    assert {:ok, %LargeAnalogValue{present_value: 50.0} = obj} =
             LargeAnalogValue.set_priority(obj, 16, 50.0)

    assert {:ok, %LargeAnalogValue{present_value: +0.0}} =
             LargeAnalogValue.set_priority(obj, 16, 0.0)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:property_out_of_range, :priority_array}} =
             LargeAnalogValue.set_priority(obj, 16, -51.0)

    assert {:error, {:property_out_of_range, :priority_array}} =
             LargeAnalogValue.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:property_out_of_range, :priority_array}} =
             LargeAnalogValue.set_priority(obj, 16, 51.0)

    assert {:error, {:property_out_of_range, :priority_array}} =
             LargeAnalogValue.set_priority(obj, 16, 32_767.0)
  end
end
