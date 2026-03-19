defmodule BACnet.BeamTypesTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants

  alias BACnet.Test.Support.Protocol.BeamTypesSupport

  require Constants

  use ExUnit.Case, async: true

  @moduletag :beam_types

  # doctest BeamTypes

  test "check type nil" do
    assert BeamTypes.check_type(nil, nil)
    refute BeamTypes.check_type(nil, true)
    refute BeamTypes.check_type(nil, false)
    refute BeamTypes.check_type(nil, "")
    refute BeamTypes.check_type(nil, 0)
    refute BeamTypes.check_type(nil, -1)
    refute BeamTypes.check_type(nil, 1.5)
    refute BeamTypes.check_type(nil, :NaN)
    refute BeamTypes.check_type(nil, :inf)
    refute BeamTypes.check_type(nil, :infn)
    refute BeamTypes.check_type(nil, {true, false})
    refute BeamTypes.check_type(nil, BACnetArray.new())
    refute BeamTypes.check_type(nil, BACnetArray.new(7))
    refute BeamTypes.check_type(nil, Constants.macro_assert_name(:asn1, :max_object))
    refute BeamTypes.check_type(nil, [])
    refute BeamTypes.check_type(nil, Date.utc_today())
  end

  test "check type any" do
    assert BeamTypes.check_type(:any, nil)
    assert BeamTypes.check_type(:any, true)
    assert BeamTypes.check_type(:any, false)
    assert BeamTypes.check_type(:any, "")
    assert BeamTypes.check_type(:any, 0)
    assert BeamTypes.check_type(:any, -1)
    assert BeamTypes.check_type(:any, 1.5)
    assert BeamTypes.check_type(:any, :NaN)
    assert BeamTypes.check_type(:any, :inf)
    assert BeamTypes.check_type(:any, :infn)
    assert BeamTypes.check_type(:any, {true, false})
    assert BeamTypes.check_type(:any, BACnetArray.new())
    assert BeamTypes.check_type(:any, BACnetArray.new(7))
    assert BeamTypes.check_type(:any, Constants.macro_assert_name(:asn1, :max_object))
    assert BeamTypes.check_type(:any, [])
    assert BeamTypes.check_type(:any, Date.utc_today())
  end

  test "check type boolean" do
    refute BeamTypes.check_type(:boolean, nil)
    assert BeamTypes.check_type(:boolean, true)
    assert BeamTypes.check_type(:boolean, false)
    refute BeamTypes.check_type(:boolean, "")
    refute BeamTypes.check_type(:boolean, 0)
    refute BeamTypes.check_type(:boolean, -1)
    refute BeamTypes.check_type(:boolean, 1.5)
    refute BeamTypes.check_type(:boolean, :NaN)
    refute BeamTypes.check_type(:boolean, :inf)
    refute BeamTypes.check_type(:boolean, :infn)
    refute BeamTypes.check_type(:boolean, {true, false})
    refute BeamTypes.check_type(:boolean, BACnetArray.new())
    refute BeamTypes.check_type(:boolean, BACnetArray.new(7))
    refute BeamTypes.check_type(:boolean, Constants.macro_assert_name(:asn1, :max_object))
    refute BeamTypes.check_type(:boolean, [])
    refute BeamTypes.check_type(:boolean, Date.utc_today())
  end

  test "check type string" do
    refute BeamTypes.check_type(:string, nil)
    refute BeamTypes.check_type(:string, true)
    refute BeamTypes.check_type(:string, false)
    assert BeamTypes.check_type(:string, "")
    assert BeamTypes.check_type(:string, "❤")
    refute BeamTypes.check_type(:string, <<245>>)
    refute BeamTypes.check_type(:string, 0)
    refute BeamTypes.check_type(:string, -1)
    refute BeamTypes.check_type(:string, 1.5)
    refute BeamTypes.check_type(:string, :NaN)
    refute BeamTypes.check_type(:string, :inf)
    refute BeamTypes.check_type(:string, :infn)
    refute BeamTypes.check_type(:string, {true, false})
    refute BeamTypes.check_type(:string, BACnetArray.new())
    refute BeamTypes.check_type(:string, BACnetArray.new(7))
    refute BeamTypes.check_type(:string, Constants.macro_assert_name(:asn1, :max_object))
    refute BeamTypes.check_type(:string, [])
    refute BeamTypes.check_type(:string, Date.utc_today())
  end

  test "check type octet string" do
    refute BeamTypes.check_type(:octet_string, nil)
    refute BeamTypes.check_type(:octet_string, true)
    refute BeamTypes.check_type(:octet_string, false)
    assert BeamTypes.check_type(:octet_string, "")
    assert BeamTypes.check_type(:octet_string, "❤")
    assert BeamTypes.check_type(:octet_string, <<245>>)
    refute BeamTypes.check_type(:octet_string, 0)
    refute BeamTypes.check_type(:octet_string, -1)
    refute BeamTypes.check_type(:octet_string, 1.5)
    refute BeamTypes.check_type(:octet_string, :NaN)
    refute BeamTypes.check_type(:octet_string, :inf)
    refute BeamTypes.check_type(:octet_string, :infn)
    refute BeamTypes.check_type(:octet_string, {true, false})
    refute BeamTypes.check_type(:octet_string, BACnetArray.new())
    refute BeamTypes.check_type(:octet_string, BACnetArray.new(7))
    refute BeamTypes.check_type(:octet_string, Constants.macro_assert_name(:asn1, :max_object))
    refute BeamTypes.check_type(:octet_string, [])
    refute BeamTypes.check_type(:octet_string, Date.utc_today())
  end

  test "check type signed integer" do
    refute BeamTypes.check_type(:signed_integer, nil)
    refute BeamTypes.check_type(:signed_integer, true)
    refute BeamTypes.check_type(:signed_integer, false)
    refute BeamTypes.check_type(:signed_integer, "")
    refute BeamTypes.check_type(:signed_integer, "❤")
    refute BeamTypes.check_type(:signed_integer, <<245>>)
    assert BeamTypes.check_type(:signed_integer, 0)
    assert BeamTypes.check_type(:signed_integer, -1)
    assert BeamTypes.check_type(:signed_integer, 1)
    refute BeamTypes.check_type(:signed_integer, 1.5)
    refute BeamTypes.check_type(:signed_integer, :NaN)
    refute BeamTypes.check_type(:signed_integer, :inf)
    refute BeamTypes.check_type(:signed_integer, :infn)
    refute BeamTypes.check_type(:signed_integer, {true, false})
    refute BeamTypes.check_type(:signed_integer, BACnetArray.new())
    refute BeamTypes.check_type(:signed_integer, BACnetArray.new(7))
    refute BeamTypes.check_type(:signed_integer, Constants.macro_assert_name(:asn1, :max_object))
    refute BeamTypes.check_type(:signed_integer, [])
    refute BeamTypes.check_type(:signed_integer, Date.utc_today())
  end

  test "check type unsigned integer" do
    refute BeamTypes.check_type(:unsigned_integer, nil)
    refute BeamTypes.check_type(:unsigned_integer, true)
    refute BeamTypes.check_type(:unsigned_integer, false)
    refute BeamTypes.check_type(:unsigned_integer, "")
    refute BeamTypes.check_type(:unsigned_integer, "❤")
    refute BeamTypes.check_type(:unsigned_integer, <<245>>)
    assert BeamTypes.check_type(:unsigned_integer, 0)
    refute BeamTypes.check_type(:unsigned_integer, -1)
    assert BeamTypes.check_type(:unsigned_integer, 1)
    refute BeamTypes.check_type(:unsigned_integer, 1.5)
    refute BeamTypes.check_type(:unsigned_integer, :NaN)
    refute BeamTypes.check_type(:unsigned_integer, :inf)
    refute BeamTypes.check_type(:unsigned_integer, :infn)
    refute BeamTypes.check_type(:unsigned_integer, {true, false})
    refute BeamTypes.check_type(:unsigned_integer, BACnetArray.new())
    refute BeamTypes.check_type(:unsigned_integer, BACnetArray.new(7))
    refute BeamTypes.check_type(:unsigned_integer, Constants.assert_name!(:asn1, :max_object))
    refute BeamTypes.check_type(:unsigned_integer, [])
    refute BeamTypes.check_type(:unsigned_integer, Date.utc_today())
  end

  test "check type real" do
    refute BeamTypes.check_type(:real, nil)
    refute BeamTypes.check_type(:real, true)
    refute BeamTypes.check_type(:real, false)
    refute BeamTypes.check_type(:real, "")
    refute BeamTypes.check_type(:real, "❤")
    refute BeamTypes.check_type(:real, <<245>>)
    refute BeamTypes.check_type(:real, 0)
    refute BeamTypes.check_type(:real, -1)
    assert BeamTypes.check_type(:real, 1.5)
    assert BeamTypes.check_type(:real, :NaN)
    assert BeamTypes.check_type(:real, :inf)
    assert BeamTypes.check_type(:real, :infn)
    refute BeamTypes.check_type(:real, {true, false})
    refute BeamTypes.check_type(:real, BACnetArray.new())
    refute BeamTypes.check_type(:real, BACnetArray.new(7))
    refute BeamTypes.check_type(:real, Constants.assert_name!(:asn1, :max_object))
    refute BeamTypes.check_type(:real, [])
    refute BeamTypes.check_type(:real, Date.utc_today())
  end

  test "check type double" do
    refute BeamTypes.check_type(:double, nil)
    refute BeamTypes.check_type(:double, true)
    refute BeamTypes.check_type(:double, false)
    refute BeamTypes.check_type(:double, "")
    refute BeamTypes.check_type(:double, "❤")
    refute BeamTypes.check_type(:double, <<245>>)
    refute BeamTypes.check_type(:double, 0)
    refute BeamTypes.check_type(:double, -1)
    assert BeamTypes.check_type(:double, 1.5)
    assert BeamTypes.check_type(:double, :NaN)
    assert BeamTypes.check_type(:double, :inf)
    assert BeamTypes.check_type(:double, :infn)
    refute BeamTypes.check_type(:double, {true, false})
    refute BeamTypes.check_type(:double, BACnetArray.new())
    refute BeamTypes.check_type(:double, BACnetArray.new(7))
    refute BeamTypes.check_type(:double, Constants.assert_name!(:asn1, :max_object))
    refute BeamTypes.check_type(:double, [])
    refute BeamTypes.check_type(:double, Date.utc_today())
  end

  test "check type bitstring" do
    refute BeamTypes.check_type(:bitstring, nil)
    refute BeamTypes.check_type(:bitstring, true)
    refute BeamTypes.check_type(:bitstring, false)
    refute BeamTypes.check_type(:bitstring, "")
    refute BeamTypes.check_type(:bitstring, "❤")
    refute BeamTypes.check_type(:bitstring, <<245>>)
    refute BeamTypes.check_type(:bitstring, 0)
    refute BeamTypes.check_type(:bitstring, -1)
    refute BeamTypes.check_type(:bitstring, 1.5)
    refute BeamTypes.check_type(:bitstring, :NaN)
    refute BeamTypes.check_type(:bitstring, :inf)
    refute BeamTypes.check_type(:bitstring, :infn)
    assert BeamTypes.check_type(:bitstring, {true, false})
    refute BeamTypes.check_type(:bitstring, {true, nil})
    refute BeamTypes.check_type(:bitstring, {1, false})
    refute BeamTypes.check_type(:bitstring, BACnetArray.new())
    refute BeamTypes.check_type(:bitstring, BACnetArray.new(7))
    refute BeamTypes.check_type(:bitstring, Constants.assert_name!(:asn1, :max_object))
    refute BeamTypes.check_type(:bitstring, [])
    refute BeamTypes.check_type(:bitstring, Date.utc_today())
  end

  test "check type array non-fixed" do
    refute BeamTypes.check_type({:array, :boolean}, nil)
    refute BeamTypes.check_type({:array, :boolean}, true)
    refute BeamTypes.check_type({:array, :boolean}, false)
    refute BeamTypes.check_type({:array, :boolean}, "")
    refute BeamTypes.check_type({:array, :boolean}, "❤")
    refute BeamTypes.check_type({:array, :boolean}, <<245>>)
    refute BeamTypes.check_type({:array, :boolean}, 0)
    refute BeamTypes.check_type({:array, :boolean}, -1)
    refute BeamTypes.check_type({:array, :boolean}, 1.5)
    refute BeamTypes.check_type({:array, :boolean}, :NaN)
    refute BeamTypes.check_type({:array, :boolean}, :inf)
    refute BeamTypes.check_type({:array, :boolean}, :infn)
    refute BeamTypes.check_type({:array, :boolean}, {true, false})

    assert BeamTypes.check_type({:array, :any}, BACnetArray.new())
    assert BeamTypes.check_type({:array, :any}, BACnetArray.from_list([1, false]))
    assert BeamTypes.check_type({:array, :any}, BACnetArray.from_list([1, false], true))

    assert BeamTypes.check_type({:array, :boolean}, BACnetArray.new())
    assert BeamTypes.check_type({:array, :boolean}, BACnetArray.from_list([true, false]))
    refute BeamTypes.check_type({:array, :boolean}, BACnetArray.from_list([true, nil]))
    refute BeamTypes.check_type({:array, :boolean}, BACnetArray.from_list([1, false]))

    refute BeamTypes.check_type({:array, :boolean}, BACnetArray.new(7))
    assert BeamTypes.check_type({:array, :boolean}, BACnetArray.new(7, false))
    assert BeamTypes.check_type({:array, :boolean}, BACnetArray.from_list([true, false], true))
    refute BeamTypes.check_type({:array, :boolean}, BACnetArray.from_list([1, false], true))

    refute BeamTypes.check_type({:array, :boolean}, Constants.assert_name!(:asn1, :max_object))
    refute BeamTypes.check_type({:array, :boolean}, [])
    refute BeamTypes.check_type({:array, :boolean}, Date.utc_today())
  end

  test "check type array fixed" do
    refute BeamTypes.check_type({:array, :boolean}, nil)
    refute BeamTypes.check_type({:array, :boolean}, true)
    refute BeamTypes.check_type({:array, :boolean}, false)
    refute BeamTypes.check_type({:array, :boolean}, "")
    refute BeamTypes.check_type({:array, :boolean}, "❤")
    refute BeamTypes.check_type({:array, :boolean}, <<245>>)
    refute BeamTypes.check_type({:array, :boolean}, 0)
    refute BeamTypes.check_type({:array, :boolean}, -1)
    refute BeamTypes.check_type({:array, :boolean}, 1.5)
    refute BeamTypes.check_type({:array, :boolean}, :NaN)
    refute BeamTypes.check_type({:array, :boolean}, :inf)
    refute BeamTypes.check_type({:array, :boolean}, :infn)
    refute BeamTypes.check_type({:array, :boolean}, {true, false})

    refute BeamTypes.check_type({:array, :any, 7}, BACnetArray.new())
    refute BeamTypes.check_type({:array, :any, 7}, BACnetArray.from_list([1, false]))
    refute BeamTypes.check_type({:array, :any, 7}, BACnetArray.from_list([1, false], true))

    refute BeamTypes.check_type({:array, :boolean, 7}, BACnetArray.new())
    refute BeamTypes.check_type({:array, :boolean, 7}, BACnetArray.from_list([true, false]))
    refute BeamTypes.check_type({:array, :boolean, 7}, BACnetArray.from_list([true, nil]))
    refute BeamTypes.check_type({:array, :boolean, 7}, BACnetArray.from_list([1, false]))

    refute BeamTypes.check_type({:array, :boolean, 7}, BACnetArray.new(6))
    assert BeamTypes.check_type({:array, :boolean, 7}, BACnetArray.new(7, false))

    assert BeamTypes.check_type(
             {:array, :boolean, 7},
             BACnetArray.from_list([true, false, true, false, false, true, false], true)
           )

    refute BeamTypes.check_type(
             {:array, :boolean, 7},
             BACnetArray.from_list([true, false, true, false, false, true, 1], true)
           )

    refute BeamTypes.check_type(
             {:array, :boolean, 7},
             BACnetArray.from_list([true, false, nil, false, false, true, false], true)
           )

    refute BeamTypes.check_type({:array, :boolean, 7}, BACnetArray.from_list([true, false], true))
    refute BeamTypes.check_type({:array, :boolean, 7}, BACnetArray.from_list([1, false], true))

    refute BeamTypes.check_type({:array, :boolean}, Constants.assert_name!(:asn1, :max_object))
    refute BeamTypes.check_type({:array, :boolean}, [])
    refute BeamTypes.check_type({:array, :boolean}, Date.utc_today())

    assert is_boolean(BeamTypes.check_type({:array, :any}, BACnetArray.new()))

    assert_raise ArgumentError, fn ->
      BeamTypes.check_type({:array, :any, 0}, BACnetArray.new())
    end
  end

  test "check type constant" do
    refute BeamTypes.check_type({:constant, :asn1}, nil)
    refute BeamTypes.check_type({:constant, :asn1}, true)
    refute BeamTypes.check_type({:constant, :asn1}, false)
    refute BeamTypes.check_type({:constant, :asn1}, "")
    refute BeamTypes.check_type({:constant, :asn1}, "❤")
    refute BeamTypes.check_type({:constant, :asn1}, <<245>>)
    refute BeamTypes.check_type({:constant, :asn1}, 0)
    refute BeamTypes.check_type({:constant, :asn1}, -1)
    refute BeamTypes.check_type({:constant, :asn1}, 1)
    refute BeamTypes.check_type({:constant, :asn1}, 1.5)
    refute BeamTypes.check_type({:constant, :asn1}, :NaN)
    refute BeamTypes.check_type({:constant, :asn1}, :inf)
    refute BeamTypes.check_type({:constant, :asn1}, :infn)
    refute BeamTypes.check_type({:constant, :asn1}, {true, false})
    refute BeamTypes.check_type({:constant, :asn1}, BACnetArray.new())
    refute BeamTypes.check_type({:constant, :asn1}, BACnetArray.new(7))
    assert BeamTypes.check_type({:constant, :asn1}, Constants.assert_name!(:asn1, :max_object))
    refute BeamTypes.check_type({:constant, :asn1}, :nano)
    refute BeamTypes.check_type({:constant, :asn1}, [])
    refute BeamTypes.check_type({:constant, :asn1}, Date.utc_today())

    assert_raise ArgumentError, fn ->
      BeamTypes.check_type({:constant, 1}, Constants.assert_name!(:asn1, :max_object))
    end
  end

  test "check type in list" do
    assert BeamTypes.check_type({:in_list, [nil, :string]}, nil)
    refute BeamTypes.check_type({:in_list, [:boolean, :string]}, nil)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, true)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, false)
    assert BeamTypes.check_type({:in_list, [nil, ""]}, "")
    refute BeamTypes.check_type({:in_list, [nil, :string]}, "❤")
    refute BeamTypes.check_type({:in_list, [nil, :string]}, <<245>>)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, 0)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, -1)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, 1)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, 1.5)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, :NaN)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, :inf)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, :infn)
    refute BeamTypes.check_type({:in_list, [nil, :string]}, {true, false})
    refute BeamTypes.check_type({:in_list, [nil, :string]}, BACnetArray.new())
    refute BeamTypes.check_type({:in_list, [nil, :string]}, BACnetArray.new(7))

    refute BeamTypes.check_type(
             {:in_list, [nil, :string]},
             Constants.assert_name!(:asn1, :max_object)
           )

    refute BeamTypes.check_type({:in_list, [nil, :string]}, [])
    refute BeamTypes.check_type({:in_list, [nil, :string]}, Date.utc_today())

    assert_raise ArgumentError, fn ->
      BeamTypes.check_type({:in_list, 1}, nil)
    end
  end

  test "check type in range" do
    refute BeamTypes.check_type({:in_range, 3, 7}, nil)
    refute BeamTypes.check_type({:in_range, 3, 7}, true)
    refute BeamTypes.check_type({:in_range, 3, 7}, false)
    refute BeamTypes.check_type({:in_range, 3, 7}, "")
    refute BeamTypes.check_type({:in_range, 3, 7}, "❤")
    refute BeamTypes.check_type({:in_range, 3, 7}, <<245>>)
    refute BeamTypes.check_type({:in_range, 3, 7}, 0)
    assert BeamTypes.check_type({:in_range, 3, 7}, 3)
    assert BeamTypes.check_type({:in_range, 3, 7}, 4)
    assert BeamTypes.check_type({:in_range, 3, 7}, 6)
    assert BeamTypes.check_type({:in_range, 3, 7}, 7)
    refute BeamTypes.check_type({:in_range, 3, 7}, 8)
    refute BeamTypes.check_type({:in_range, 3, 7}, -1)
    refute BeamTypes.check_type({:in_range, 3, 7}, 1.5)
    refute BeamTypes.check_type({:in_range, 3, 7}, :NaN)
    refute BeamTypes.check_type({:in_range, 3, 7}, :inf)
    refute BeamTypes.check_type({:in_range, 3, 7}, :infn)
    refute BeamTypes.check_type({:in_range, 3, 7}, {true, false})
    refute BeamTypes.check_type({:in_range, 3, 7}, BACnetArray.new())
    refute BeamTypes.check_type({:in_range, 3, 7}, BACnetArray.new(7))
    refute BeamTypes.check_type({:in_range, 3, 7}, Constants.assert_name!(:asn1, :max_object))
    refute BeamTypes.check_type({:in_range, 3, 7}, [])
    refute BeamTypes.check_type({:in_range, 3, 7}, Date.utc_today())

    assert_raise ArgumentError, fn ->
      BeamTypes.check_type({:in_range, nil, 5}, nil)
    end

    assert_raise ArgumentError, fn ->
      BeamTypes.check_type({:in_range, 1, nil}, nil)
    end
  end

  test "check type list" do
    refute BeamTypes.check_type({:list, :signed_integer}, nil)
    refute BeamTypes.check_type({:list, :signed_integer}, true)
    refute BeamTypes.check_type({:list, :signed_integer}, false)
    refute BeamTypes.check_type({:list, :signed_integer}, "")
    refute BeamTypes.check_type({:list, :signed_integer}, "❤")
    refute BeamTypes.check_type({:list, :signed_integer}, <<245>>)
    refute BeamTypes.check_type({:list, :signed_integer}, 0)
    refute BeamTypes.check_type({:list, :signed_integer}, 8)
    refute BeamTypes.check_type({:list, :signed_integer}, -1)
    refute BeamTypes.check_type({:list, :signed_integer}, 1.5)
    refute BeamTypes.check_type({:list, :signed_integer}, :NaN)
    refute BeamTypes.check_type({:list, :signed_integer}, :inf)
    refute BeamTypes.check_type({:list, :signed_integer}, :infn)
    refute BeamTypes.check_type({:list, :signed_integer}, {true, false})
    refute BeamTypes.check_type({:list, :signed_integer}, BACnetArray.new())
    refute BeamTypes.check_type({:list, :signed_integer}, BACnetArray.new(7))

    refute BeamTypes.check_type(
             {:list, :signed_integer},
             Constants.assert_name!(:asn1, :max_object)
           )

    assert BeamTypes.check_type({:list, :signed_integer}, [])
    assert BeamTypes.check_type({:list, :signed_integer}, [1, 5, -1])
    refute BeamTypes.check_type({:list, :signed_integer}, [1, 1.0, 5])
    refute BeamTypes.check_type({:list, :signed_integer}, Date.utc_today())
  end

  test "check type literal" do
    refute BeamTypes.check_type({:literal, 5}, nil)
    refute BeamTypes.check_type({:literal, 5}, 1)
    assert BeamTypes.check_type({:literal, 5}, 5)
    refute BeamTypes.check_type({:literal, 5}, 5.0)
  end

  test "check type tuple" do
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, nil)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, true)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, false)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, "")
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, "❤")
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, <<245>>)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, 0)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, 8)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, -1)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, 1.5)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, :NaN)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, :inf)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, :infn)
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, {true})
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, {true, 3, -1})
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, {nil, 5})
    assert BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, {false, 5})
    assert BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, {true, 0})
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, {true, -1})
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, {true, false})
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, BACnetArray.new())
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, BACnetArray.new(7))

    refute BeamTypes.check_type(
             {:tuple, [:boolean, :unsigned_integer]},
             Constants.assert_name!(:asn1, :max_object)
           )

    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, [])
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, [1, 5, -1])
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, [1, 1.0, 5])
    refute BeamTypes.check_type({:tuple, [:boolean, :unsigned_integer]}, Date.utc_today())

    assert_raise ArgumentError, fn ->
      BeamTypes.check_type({:tuple, :boolean}, {true})
    end
  end

  test "check type struct without valid?" do
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, nil)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, true)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, false)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, "")
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, "❤")
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, <<245>>)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, 0)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, -1)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, 1.5)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, :NaN)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, :inf)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, :infn)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, {true, false})
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, {true, nil})
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, {1, false})
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, BACnetArray.new())
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, BACnetArray.new(7))

    refute BeamTypes.check_type(
             {:struct, BeamTypesSupport.StructNoValidator},
             Constants.assert_name!(:asn1, :max_object)
           )

    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, [])
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructNoValidator}, Date.utc_today())

    assert BeamTypes.check_type(
             {:struct, BeamTypesSupport.StructNoValidator},
             %BeamTypesSupport.StructNoValidator{}
           )

    refute BeamTypes.check_type(
             {:struct, BeamTypesSupport.StructNoValidator},
             %BeamTypesSupport.StructValidator{}
           )
  end

  test "check type struct with valid?" do
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, nil)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, true)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, false)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, "")
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, "❤")
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, <<245>>)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, 0)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, -1)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, 1.5)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, :NaN)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, :inf)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, :infn)
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, {true, false})
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, {true, nil})
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, {1, false})
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, BACnetArray.new())
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, BACnetArray.new(7))

    refute BeamTypes.check_type(
             {:struct, BeamTypesSupport.StructValidator},
             Constants.assert_name!(:asn1, :max_object)
           )

    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, [])
    refute BeamTypes.check_type({:struct, BeamTypesSupport.StructValidator}, Date.utc_today())

    refute BeamTypes.check_type(
             {:struct, BeamTypesSupport.StructValidator},
             %BeamTypesSupport.StructNoValidator{}
           )

    refute BeamTypes.check_type(
             {:struct, BeamTypesSupport.StructValidator},
             %BeamTypesSupport.StructValidator{}
           )

    assert BeamTypes.check_type(
             {:struct, BeamTypesSupport.StructValidator},
             %BeamTypesSupport.StructValidator{hello: true}
           )

    refute BeamTypes.check_type(
             {:struct, BeamTypesSupport.StructValidator},
             %BeamTypesSupport.StructValidator{hello: nil}
           )
  end

  test "check type in type list" do
    assert BeamTypes.check_type({:type_list, [nil, :string]}, nil)
    refute BeamTypes.check_type({:type_list, [:boolean, :string]}, nil)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, true)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, false)
    assert BeamTypes.check_type({:type_list, [nil, :octet_string]}, "")
    assert BeamTypes.check_type({:type_list, [nil, :string]}, "❤")
    assert BeamTypes.check_type({:type_list, [nil, :octet_string]}, <<245>>)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, 0)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, -1)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, 1)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, 1.5)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, :NaN)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, :inf)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, :infn)
    refute BeamTypes.check_type({:type_list, [nil, :string]}, {true, false})
    refute BeamTypes.check_type({:type_list, [nil, :string]}, BACnetArray.new())
    refute BeamTypes.check_type({:type_list, [nil, :string]}, BACnetArray.new(7))

    refute BeamTypes.check_type(
             {:type_list, [nil, :string]},
             Constants.assert_name!(:asn1, :max_object)
           )

    refute BeamTypes.check_type({:type_list, [nil, :string]}, [])
    refute BeamTypes.check_type({:type_list, [nil, :string]}, Date.utc_today())

    assert_raise ArgumentError, fn ->
      BeamTypes.check_type({:type_list, 1}, nil)
    end
  end

  test "check type validator with function" do
    fun = &(&1 >= -5)

    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, nil)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, true)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, false)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, "")
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, "❤")
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, <<245>>)
    assert BeamTypes.check_type({:with_validator, :signed_integer, fun}, 0)
    assert BeamTypes.check_type({:with_validator, :signed_integer, fun}, -1)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, -6)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, 1.5)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, :NaN)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, :inf)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, :infn)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, {true, false})
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, {true, nil})
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, {1, false})
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, BACnetArray.new())
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, BACnetArray.new(7))

    refute BeamTypes.check_type(
             {:with_validator, :signed_integer, fun},
             Constants.assert_name!(:asn1, :max_object)
           )

    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, [])
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, Date.utc_today())

    assert_raise ArgumentError, fn ->
      fun = &(&1 >= &2)
      BeamTypes.check_type({:with_validator, :signed_integer, fun}, 1)
    end
  end

  test "check type validator with function AST" do
    fun =
      quote do
        &(&1 >= -5)
      end

    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, nil)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, true)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, false)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, "")
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, "❤")
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, <<245>>)
    assert BeamTypes.check_type({:with_validator, :signed_integer, fun}, 0)
    assert BeamTypes.check_type({:with_validator, :signed_integer, fun}, -1)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, -6)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, 1.5)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, :NaN)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, :inf)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, :infn)
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, {true, false})
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, {true, nil})
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, {1, false})
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, BACnetArray.new())
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, BACnetArray.new(7))

    refute BeamTypes.check_type(
             {:with_validator, :signed_integer, fun},
             Constants.assert_name!(:asn1, :max_object)
           )

    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, [])
    refute BeamTypes.check_type({:with_validator, :signed_integer, fun}, Date.utc_today())

    assert_raise ArgumentError, fn ->
      fun =
        quote do
          &(&1 >= &2)
        end

      BeamTypes.check_type({:with_validator, :signed_integer, fun}, 1)
    end
  end

  test "check type but unknown type" do
    assert_raise ArgumentError, fn ->
      BeamTypes.check_type(:hello_world, nil)
    end
  end

  test "generate valid clause with empty rules" do
    ast =
      quote do
        true
      end

    assert ast == BeamTypes.generate_valid_clause(BeamTypesSupport.StructTypesEmpty, __ENV__)
  end

  test "generate valid clause with rules" do
    ast =
      quote do
        unquote(BACnet.BeamTypes).check_type(:octet_string, t.hello)
      end
      |> then(fn {type, opts, rest} ->
        {type, Keyword.replace(opts, :context, BACnet.BeamTypes), rest}
      end)

    assert ast == BeamTypes.generate_valid_clause(BeamTypesSupport.StructTypes, __ENV__)
  end

  test "generate valid clause with multiple rules" do
    ast =
      quote do
        unquote(BACnet.BeamTypes).check_type(:octet_string, t.hello) and
          unquote(BACnet.BeamTypes).check_type(:signed_integer, t.sum)
      end
      |> then(fn {type, opts, rest} ->
        {type, Keyword.replace(opts, :context, BACnet.BeamTypes), rest}
      end)

    ast2 =
      quote do
        unquote(BACnet.BeamTypes).check_type(:signed_integer, t.sum) and
          unquote(BACnet.BeamTypes).check_type(:octet_string, t.hello)
      end
      |> then(fn {type, opts, rest} ->
        {type, Keyword.replace(opts, :context, BACnet.BeamTypes), rest}
      end)

    clause = BeamTypes.generate_valid_clause(BeamTypesSupport.StructTypes2, __ENV__)

    # Map elements order might not be so fortunate to us,
    # so we need to cover both orders (sum first and hello first)
    assert ast == clause or ast2 == clause
  end

  test "resolve type" do
    assert nil == BeamTypes.resolve_type(quote(do: nil), __ENV__)

    assert :boolean == BeamTypes.resolve_type(quote(do: boolean()), __ENV__)
    assert :boolean == BeamTypes.resolve_type(quote(do: true), __ENV__)
    assert :boolean == BeamTypes.resolve_type(quote(do: false), __ENV__)
    assert :boolean != BeamTypes.resolve_type(quote(do: nil), __ENV__)

    assert :string == BeamTypes.resolve_type(quote(do: String.t()), __ENV__)
    assert :octet_string == BeamTypes.resolve_type(quote(do: binary()), __ENV__)

    assert :signed_integer == BeamTypes.resolve_type(quote(do: integer()), __ENV__)
    assert :unsigned_integer == BeamTypes.resolve_type(quote(do: non_neg_integer()), __ENV__)

    assert :real == BeamTypes.resolve_type(quote(do: float()), __ENV__)

    assert :real ==
             BeamTypes.resolve_type(
               quote(do: BACnet.Protocol.ApplicationTags.ieee_float()),
               __ENV__
             )

    assert :bitstring == BeamTypes.resolve_type(quote(do: tuple()), __ENV__)

    assert {:array, :boolean} ==
             BeamTypes.resolve_type(quote(do: BACnet.Protocol.BACnetArray.t(boolean())), __ENV__)

    assert {:array, :boolean, 7} ==
             BeamTypes.resolve_type(
               quote(do: BACnet.Protocol.BACnetArray.t(boolean(), 7)),
               __ENV__
             )

    assert {:constant, :asn1} ==
             BeamTypes.resolve_type(quote(do: BACnet.Protocol.Constants.asn1()), __ENV__)

    assert {:in_list, [1, 2]} == BeamTypes.resolve_type(quote(do: 1..2//1), __ENV__)
    assert {:in_range, 1, 2} == BeamTypes.resolve_type(quote(do: 1..2), __ENV__)

    assert {:list, :boolean} == BeamTypes.resolve_type(quote(do: [boolean()]), __ENV__)

    assert {:struct, Date} == BeamTypes.resolve_type(quote(do: Date.t()), __ENV__)

    assert {:type_list, [:octet_string, nil]} ==
             BeamTypes.resolve_type(quote(do: binary() | nil), __ENV__)

    assert {:with_validator, :unsigned_integer, _fun} =
             BeamTypes.resolve_type(quote(do: pos_integer()), __ENV__)
  end

  test "resolve type array requires subtype" do
    assert_raise CompileError, ~r"BACnetArray must have a subtype", fn ->
      BeamTypes.resolve_type(quote(do: BACnet.Protocol.BACnetArray.t()), __ENV__)
    end
  end

  test "resolve type array too many args" do
    assert_raise CompileError, ~r"BACnetArray must have one or two parameters", fn ->
      BeamTypes.resolve_type(quote(do: BACnet.Protocol.BACnetArray.t(a, b, c)), __ENV__)
    end
  end

  test "resolve struct types with empty rules (ignore underlined keys)" do
    assert %{} ==
             BeamTypes.resolve_struct_type(BeamTypesSupport.StructTypesEmpty, :t, __ENV__,
               ignore_underlined_keys: true
             )
  end

  test "resolve struct types with rules" do
    assert %{_hello: :any} ==
             BeamTypes.resolve_struct_type(BeamTypesSupport.StructTypesEmpty, :t, __ENV__)

    assert %{hello: :octet_string, sum: :signed_integer} ==
             BeamTypes.resolve_struct_type(BeamTypesSupport.StructTypes2, :t, __ENV__)
  end

  test "resolve struct types annotated" do
    assert %{world: :list} ==
             BeamTypes.resolve_struct_type(BeamTypesSupport.StructTypesAnnotated, :t, __ENV__)
  end

  test "resolve struct types user type" do
    assert %{world: :list} ==
             BeamTypes.resolve_struct_type(BeamTypesSupport.StructTypesUserType, :t, __ENV__)
  end

  test "resolve struct types literal number" do
    assert %{world: {:literal, 5}} ==
             BeamTypes.resolve_struct_type(BeamTypesSupport.StructTypesLiteralNumber, :t, __ENV__)
  end

  test "resolve struct types lookup through BEAM file" do
    assert %{} = BeamTypes.resolve_struct_type(Doctor.Config, :t, __ENV__)
  end

  test "resolve struct types literal number list" do
    assert %{world: {:list, {:literal, 5}}} ==
             BeamTypes.resolve_struct_type(
               BeamTypesSupport.StructTypesLiteralNumberList,
               :t,
               __ENV__
             )
  end

  test "resolve struct types type not found" do
    assert_raise CompileError,
                 ~r"beam_types_test\.exs:\d+: Unable to resolve type \"String.t2\"",
                 fn ->
                   BeamTypes.resolve_struct_type(String, :t2, __ENV__)
                 end
  end

  test "resolve struct types no bytecode found" do
    assert_raise CompileError,
                 ~r"beam_types_test\.exs:\d+: Missing bytecode for module BACnet.BeamTypesTest, unable to lookup types",
                 fn ->
                   BeamTypes.resolve_struct_type(__MODULE__, :t, __ENV__)
                 end
  end

  test "resolve struct types requires map" do
    assert_raise CompileError,
                 ~r"beam_types_test\.exs:\d+: Type String\.t does not export the type as struct",
                 fn ->
                   BeamTypes.resolve_struct_type(String, :t, __ENV__)
                 end
  end

  test "resolve struct types map key unsupported" do
    assert_raise CompileError, ~r"beam_types_test\.exs:\d+: Type map is not supported", fn ->
      BeamTypes.resolve_struct_type(BeamTypesSupport.StructTypesWithMap, :t, __ENV__)
    end
  end

  test "resolve struct types map key unsupported in BEAM" do
    assert_raise CompileError,
                 ~r"beam_types_test\.exs:\d+: Only structs are allowed as typespec, plain maps are not supported",
                 fn ->
                   BeamTypes.resolve_struct_type(Req.Request, :t, __ENV__)
                 end
  end
end
