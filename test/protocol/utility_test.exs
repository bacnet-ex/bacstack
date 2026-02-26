defmodule BACnet.Protocol.UtilityTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.Utility

  test "verify float_validator_fun" do
    assert Utility.float_validator_fun(:NaN, %{})
    assert Utility.float_validator_fun(:inf, %{})
    assert Utility.float_validator_fun(:infn, %{})
    assert Utility.float_validator_fun(3.14, %{})

    assert Utility.float_validator_fun(3.0, %{min_present_value: 2.0, max_present_value: 4.0})
    refute Utility.float_validator_fun(1.0, %{min_present_value: 2.0, max_present_value: 4.0})
    refute Utility.float_validator_fun(5.0, %{min_present_value: 2.0, max_present_value: 4.0})

    refute Utility.float_validator_fun(3.0, %{min_present_value: :inf, max_present_value: 4.0})
    assert Utility.float_validator_fun(3.0, %{min_present_value: :infn, max_present_value: 4.0})
    assert Utility.float_validator_fun(3.0, %{min_present_value: :NaN, max_present_value: 4.0})

    assert Utility.float_validator_fun(3.0, %{min_present_value: 2.0, max_present_value: :inf})
    refute Utility.float_validator_fun(3.0, %{min_present_value: 2.0, max_present_value: :infn})
    assert Utility.float_validator_fun(3.0, %{min_present_value: 2.0, max_present_value: :NaN})

    assert Utility.float_validator_fun(3.0, %{min_present_value: :infn, max_present_value: :inf})
  end
end
