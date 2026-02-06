defmodule BACnet.Test.Protocol.ObjectTypes.PositiveIntegerValueTest do
  alias BACnet.Protocol.ObjectTypes.PositiveIntegerValue
  alias BACnet.Protocol.PriorityArray

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_positive_integer_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 for priority_array fails on value lower than min" do
    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.create(1, "TEST", %{
               priority_array: %PriorityArray{priority_16: 1},
               max_present_value: 50,
               min_present_value: 5
             })
  end

  test "verify create/4 for priority_array fails on value higher than max" do
    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.create(1, "TEST", %{
               priority_array: %PriorityArray{priority_16: 55},
               max_present_value: 50,
               min_present_value: 5
             })
  end

  for property <- [:present_value, :relinquish_default] do
    test "verify create/4 for #{property} fails on value lower than min" do
      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.create(1, "TEST", %{
                 unquote(property) => 1,
                 max_present_value: 50,
                 min_present_value: 5
               })
    end

    test "verify create/4 for #{property} fails on value higher than max" do
      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.create(1, "TEST", %{
                 unquote(property) => 55,
                 max_present_value: 50,
                 min_present_value: 5
               })
    end

    test "verify update_property/3 for #{property} ignores min/max if max not present" do
      {:ok, %PositiveIntegerValue{unquote(property) => 0} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{unquote(property) => 0, min_present_value: 5})

      assert {:ok, %PositiveIntegerValue{unquote(property) => 1}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 1)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 32_767}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 32_767)
    end

    test "verify update_property/3 for #{property} ignores min/max if min not present" do
      {:ok, %PositiveIntegerValue{unquote(property) => 0} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{unquote(property) => 0, max_present_value: 50})

      assert {:ok, %PositiveIntegerValue{unquote(property) => 51}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 51)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 32_767}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 32_767)
    end

    test "verify update_property/3 for #{property} working within configured min/max" do
      {:ok, %PositiveIntegerValue{unquote(property) => 5} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{
          unquote(property) => 5,
          max_present_value: 50,
          min_present_value: 5
        })

      assert {:ok, %PositiveIntegerValue{unquote(property) => 20}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 20}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 50}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 50}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 20} = obj} =
               PositiveIntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 20} = obj} =
               PositiveIntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 50} = obj} =
               PositiveIntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 50} = obj} =
               PositiveIntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 5}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 5)
    end

    test "verify update_property/3 for #{property} fails on value lower than min" do
      {:ok, %PositiveIntegerValue{unquote(property) => 5} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{
          unquote(property) => 5,
          max_present_value: 50,
          min_present_value: 5
        })

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 4)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 0)
    end

    test "verify update_property/3 for #{property} fails on value higher than max" do
      {:ok, %PositiveIntegerValue{unquote(property) => 5} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{
          unquote(property) => 5,
          max_present_value: 50,
          min_present_value: 5
        })

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 51)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 32_767)
    end
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %PositiveIntegerValue{present_value: 0} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{max_present_value: 50, min_present_value: 0})

    assert {:ok, %PositiveIntegerValue{cov_increment: 0}} =
             PositiveIntegerValue.update_property(obj, :cov_increment, 0)

    assert {:ok, %PositiveIntegerValue{cov_increment: 51}} =
             PositiveIntegerValue.update_property(obj, :cov_increment, 51)

    assert {:error, {:invalid_property_type, :cov_increment}} =
             PositiveIntegerValue.update_property(obj, :cov_increment, -1)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{min_present_value: 50, relinquish_default: 5})

    assert {:ok, %PositiveIntegerValue{present_value: 51}} =
             PositiveIntegerValue.set_priority(obj, 16, 51)

    assert {:ok, %PositiveIntegerValue{present_value: 32_767}} =
             PositiveIntegerValue.set_priority(obj, 16, 32_767)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{max_present_value: 50, relinquish_default: 5})

    assert {:ok, %PositiveIntegerValue{present_value: 51}} =
             PositiveIntegerValue.set_priority(obj, 16, 51)

    assert {:ok, %PositiveIntegerValue{present_value: 32_767}} =
             PositiveIntegerValue.set_priority(obj, 16, 32_767)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: 5,
        relinquish_default: 5
      })

    assert {:ok, %PositiveIntegerValue{present_value: 20}} =
             PositiveIntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %PositiveIntegerValue{present_value: 20}} =
             PositiveIntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %PositiveIntegerValue{present_value: 50}} =
             PositiveIntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %PositiveIntegerValue{present_value: 50}} =
             PositiveIntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %PositiveIntegerValue{present_value: 20} = obj} =
             PositiveIntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %PositiveIntegerValue{present_value: 20} = obj} =
             PositiveIntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %PositiveIntegerValue{present_value: 50} = obj} =
             PositiveIntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %PositiveIntegerValue{present_value: 50} = obj} =
             PositiveIntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %PositiveIntegerValue{present_value: 5}} =
             PositiveIntegerValue.set_priority(obj, 16, 5)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: 5,
        relinquish_default: 5
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.set_priority(obj, 16, 4)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: 5,
        relinquish_default: 5
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.set_priority(obj, 16, 51)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.set_priority(obj, 16, 32_767)
  end
end
