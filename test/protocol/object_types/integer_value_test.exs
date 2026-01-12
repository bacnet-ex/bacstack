defmodule BACnet.Test.Protocol.ObjectTypes.IntegerValueTest do
  alias BACnet.Protocol.ObjectTypes.IntegerValue

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_integer_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  for property <- [:present_value, :relinquish_default] do
    test "verify update_property/3 for #{property} ignores min/max if max not present" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{unquote(property) => 0, min_present_value: 50})

      assert {:ok, %IntegerValue{unquote(property) => -51}} =
               IntegerValue.update_property(obj, unquote(property), -51)

      assert {:ok, %IntegerValue{unquote(property) => -32_767}} =
               IntegerValue.update_property(obj, unquote(property), -32_767)
    end

    test "verify update_property/3 for #{property} ignores min/max if min not present" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{unquote(property) => 0, max_present_value: 50})

      assert {:ok, %IntegerValue{unquote(property) => 51}} =
               IntegerValue.update_property(obj, unquote(property), 51)

      assert {:ok, %IntegerValue{unquote(property) => 32_767}} =
               IntegerValue.update_property(obj, unquote(property), 32_767)
    end

    test "verify update_property/3 for #{property} working within configured min/max" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{
          unquote(property) => 0,
          max_present_value: 50,
          min_present_value: -50
        })

      assert {:ok, %IntegerValue{unquote(property) => -20}} =
               IntegerValue.update_property(obj, unquote(property), -20)

      assert {:ok, %IntegerValue{unquote(property) => 20}} =
               IntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %IntegerValue{unquote(property) => -50}} =
               IntegerValue.update_property(obj, unquote(property), -50)

      assert {:ok, %IntegerValue{unquote(property) => 50}} =
               IntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %IntegerValue{unquote(property) => -20} = obj} =
               IntegerValue.update_property(obj, unquote(property), -20)

      assert {:ok, %IntegerValue{unquote(property) => 20} = obj} =
               IntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %IntegerValue{unquote(property) => -50} = obj} =
               IntegerValue.update_property(obj, unquote(property), -50)

      assert {:ok, %IntegerValue{unquote(property) => 50} = obj} =
               IntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %IntegerValue{unquote(property) => 0}} =
               IntegerValue.update_property(obj, unquote(property), 0)
    end

    test "verify update_property/3 for #{property} fails on value lower than min" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{
          unquote(property) => 0,
          max_present_value: 50,
          min_present_value: -50
        })

      assert {:error, {:property_out_of_range, unquote(property)}} =
               IntegerValue.update_property(obj, unquote(property), -51)

      assert {:error, {:property_out_of_range, unquote(property)}} =
               IntegerValue.update_property(obj, unquote(property), -32_767)
    end

    test "verify update_property/3 for #{property} fails on value higher than max" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{
          unquote(property) => 0,
          max_present_value: 50,
          min_present_value: -50
        })

      assert {:error, {:property_out_of_range, unquote(property)}} =
               IntegerValue.update_property(obj, unquote(property), 51)

      assert {:error, {:property_out_of_range, unquote(property)}} =
               IntegerValue.update_property(obj, unquote(property), 32_767)
    end
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{max_present_value: 50, min_present_value: -50})

    assert {:ok, %IntegerValue{cov_increment: 0}} =
             IntegerValue.update_property(obj, :cov_increment, 0)

    assert {:ok, %IntegerValue{cov_increment: 51}} =
             IntegerValue.update_property(obj, :cov_increment, 51)

    assert {:error, {:invalid_property_type, :cov_increment}} =
             IntegerValue.update_property(obj, :cov_increment, -1)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{min_present_value: 50, relinquish_default: 0})

    assert {:ok, %IntegerValue{present_value: -51}} = IntegerValue.set_priority(obj, 16, -51)

    assert {:ok, %IntegerValue{present_value: -32_767}} =
             IntegerValue.set_priority(obj, 16, -32_767)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{max_present_value: 50, relinquish_default: 0})

    assert {:ok, %IntegerValue{present_value: 51}} = IntegerValue.set_priority(obj, 16, 51)

    assert {:ok, %IntegerValue{present_value: 32_767}} =
             IntegerValue.set_priority(obj, 16, 32_767)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: -50,
        relinquish_default: 0
      })

    assert {:ok, %IntegerValue{present_value: -20}} = IntegerValue.set_priority(obj, 16, -20)

    assert {:ok, %IntegerValue{present_value: 20}} = IntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %IntegerValue{present_value: -50}} = IntegerValue.set_priority(obj, 16, -50)

    assert {:ok, %IntegerValue{present_value: 50}} = IntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %IntegerValue{present_value: -20} = obj} =
             IntegerValue.set_priority(obj, 16, -20)

    assert {:ok, %IntegerValue{present_value: 20} = obj} = IntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %IntegerValue{present_value: -50} = obj} =
             IntegerValue.set_priority(obj, 16, -50)

    assert {:ok, %IntegerValue{present_value: 50} = obj} = IntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %IntegerValue{present_value: 0}} = IntegerValue.set_priority(obj, 16, 0)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: -50,
        relinquish_default: 0
      })

    assert {:error, {:property_out_of_range, :priority_array}} =
             IntegerValue.set_priority(obj, 16, -51)

    assert {:error, {:property_out_of_range, :priority_array}} =
             IntegerValue.set_priority(obj, 16, -32_767)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: -50,
        relinquish_default: 0
      })

    assert {:error, {:property_out_of_range, :priority_array}} =
             IntegerValue.set_priority(obj, 16, 51)

    assert {:error, {:property_out_of_range, :priority_array}} =
             IntegerValue.set_priority(obj, 16, 32_767)
  end
end
