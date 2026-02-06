defmodule BACnet.Test.Protocol.ConstantsTest do
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.Constants.ConstantError

  require Constants
  use ExUnit.Case, async: true

  @moduletag :constants

  doctest Constants

  test "assert assert_name/2 works" do
    assert {:ok, :max_object} = Constants.assert_name(:asn1, :max_object)
  end

  test "assert assert_name/2 errors" do
    assert :error = Constants.assert_name(:asn1, :max_object_non)
    assert :error = Constants.assert_name(:asn2, :max_object)
  end

  test "assert assert_name!/2 works" do
    assert :max_object = Constants.assert_name!(:asn1, :max_object)
  end

  test "assert assert_name!/2 raises" do
    assert_raise ConstantError, fn -> Constants.assert_name!(:asn1, :max_object_non) end
    assert_raise ConstantError, fn -> Constants.assert_name!(:asn2, :max_object) end
  end

  test "assert by_name/2 works" do
    assert {:ok, 0x3FF} = Constants.by_name(:asn1, :max_object)
  end

  test "assert by_name/2 errors" do
    assert :error = Constants.by_name(:asn1, :max_object_non)
  end

  test "assert by_name!/2 works" do
    assert 0x3FF = Constants.by_name!(:asn1, :max_object)
  end

  test "assert by_name!/2 raises" do
    assert_raise ConstantError, fn -> Constants.by_name!(:asn1, :max_object_non) end
  end

  test "assert by_name_atom/2 works" do
    assert 0x3FF = Constants.by_name_atom(:asn1, :max_object)
  end

  test "assert by_name_atom/2 works with non-atom" do
    assert 0 = Constants.by_name_atom(:asn1, 0)
  end

  test "assert by_name_atom/2 raises on unknown" do
    assert_raise ConstantError, fn -> Constants.by_name_atom(:asn1, :max_object_non) end
  end

  test "assert by_name/3 works" do
    assert 0x3FF = Constants.by_name(:asn1, :max_object, 155)
  end

  test "assert by_name/3 returns default" do
    assert 155 = Constants.by_name(:asn1, :max_object_non, 155)
  end

  test "assert by_name_with_reason/3 works" do
    assert {:ok, 0x3FF} = Constants.by_name_with_reason(:asn1, :max_object, :unknown_constant)
  end

  test "assert by_name_with_reason/3 errors" do
    assert {:error, :unknown_constant} =
             Constants.by_name_with_reason(:asn1, :max_object_non, :unknown_constant)

    assert {:error, 155} = Constants.by_name_with_reason(:asn1, :max_object_non, 155)
  end

  test "assert by_value/2 works" do
    assert {:ok, :max_object} = Constants.by_value(:asn1, 0x3FF)
  end

  test "assert by_value/2 errors" do
    assert :error = Constants.by_value(:asn1, :hello)
  end

  test "assert by_value!/2 works" do
    assert :max_object = Constants.by_value!(:asn1, 0x3FF)
  end

  test "assert by_value!/2 raises" do
    assert_raise ConstantError, fn -> Constants.by_value!(:asn1, :hello) end
  end

  test "assert by_value/3 works" do
    assert :max_object = Constants.by_value(:asn1, 0x3FF, 155)
  end

  test "assert by_value/3 returns default" do
    assert 155 = Constants.by_value(:asn1, :hello, 155)
  end

  test "assert by_value_with_reason/3 works" do
    assert {:ok, :max_object} = Constants.by_value_with_reason(:asn1, 0x3FF, :unknown_constant)
  end

  test "assert by_value_with_reason/3 errors" do
    assert {:error, :unknown_constant} =
             Constants.by_value_with_reason(:asn1, :hello, :unknown_constant)

    assert {:error, 155} = Constants.by_value_with_reason(:asn1, :hello, 155)
  end

  test "assert has_by_name/2 works" do
    assert true == Constants.has_by_name(:asn1, :max_object)
  end

  test "assert has_by_name/2 errors" do
    assert false == Constants.has_by_name(:asn1, :max_object_non)
  end

  test "assert has_by_value/2 works" do
    assert true == Constants.has_by_value(:asn1, 0x3FF)
  end

  test "assert has_by_value/2 errors" do
    assert false == Constants.has_by_value(:asn1, :hello)
  end

  test "assert macro_assert_name/2 returns correct value" do
    # We can not verify whether the function gets replaced or not with a constant value
    assert :max_object == Constants.macro_assert_name(:asn1, :max_object)
  end

  test "assert macro_by_name/2 returns correct value" do
    # We can not verify whether the function gets replaced or not with a constant value
    assert 0x3FF == Constants.macro_by_name(:asn1, :max_object)
  end

  test "assert macro_by_value/2 returns correct value" do
    # We can not verify whether the function gets replaced or not with a constant value
    assert :max_object == Constants.macro_by_value(:asn1, 0x3FF)
  end

  test "assert macro_list_all/1 returns list of defined constants" do
    assert Enum.sort([
             {:array_all, 4_294_967_295},
             {:instance_bits, 22},
             {:max_application_tag, 16},
             {:max_bitstring_bytes, 15},
             {:max_instance_and_property_id, 4_194_303},
             {:max_object, 1023},
             {:max_object_type, 1024}
           ]) == Enum.sort(Constants.macro_list_all(:asn1))
  end

  test "assert macro_list_names/1 returns list of defined constants" do
    assert Enum.sort([
             :array_all,
             :instance_bits,
             :max_application_tag,
             :max_bitstring_bytes,
             :max_instance_and_property_id,
             :max_object,
             :max_object_type
           ]) == Enum.sort(Constants.macro_list_names(:asn1))
  end
end
