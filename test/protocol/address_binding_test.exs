defmodule BACnet.Protocol.AddressBindingTest do
  alias BACnet.Protocol.AddressBinding
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest AddressBinding

  test "decode address binding" do
    assert {:ok,
            {%AddressBinding{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               network: 1,
               address: "ABCDEFG"
             },
             []}} =
             AddressBinding.parse(
               object_identifier: %ObjectIdentifier{type: :device, instance: 1},
               unsigned_integer: 1,
               octet_string: "ABCDEFG"
             )
  end

  test "decode invalid address binding" do
    assert {:error, :invalid_tags} =
             AddressBinding.parse(
               object_identifier: %ObjectIdentifier{type: :device, instance: 1},
               unsigned_integer: 1
             )
  end

  test "decode address binding invalid network" do
    assert {:error, :invalid_network_value} =
             AddressBinding.parse(
               object_identifier: %ObjectIdentifier{type: :device, instance: 1},
               unsigned_integer: 65_536,
               octet_string: "ABCDEFG"
             )
  end

  test "encode address binding" do
    assert {:ok,
            [
              object_identifier: %ObjectIdentifier{type: :device, instance: 1},
              unsigned_integer: 1,
              octet_string: "ABCDEFG"
            ]} =
             AddressBinding.encode(%AddressBinding{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               network: 1,
               address: "ABCDEFG"
             })
  end

  test "encode address binding invalid device identifier" do
    assert_raise FunctionClauseError, fn ->
      AddressBinding.encode(%AddressBinding{
        device_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
        network: 1,
        address: "ABCDEFG"
      })
    end
  end

  test "encode address binding invalid device identifier 2" do
    assert_raise FunctionClauseError, fn ->
      AddressBinding.encode(%AddressBinding{
        device_identifier: :hello,
        network: 1,
        address: "ABCDEFG"
      })
    end
  end

  test "encode address binding invalid network" do
    assert_raise FunctionClauseError, fn ->
      AddressBinding.encode(%AddressBinding{
        device_identifier: %ObjectIdentifier{type: :device, instance: 1},
        network: nil,
        address: "ABCDEFG"
      })
    end

    assert {:error, :invalid_network_value} =
             AddressBinding.encode(%AddressBinding{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               network: -1,
               address: "ABCDEFG"
             })

    assert {:error, :invalid_network_value} =
             AddressBinding.encode(%AddressBinding{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               network: 65_536,
               address: "ABCDEFG"
             })
  end

  test "encode address binding invalid address" do
    assert_raise FunctionClauseError, fn ->
      AddressBinding.encode(%AddressBinding{
        device_identifier: %ObjectIdentifier{type: :device, instance: 1},
        network: 1,
        address: :hello
      })
    end
  end

  test "valid address binding" do
    assert true ==
             AddressBinding.valid?(%AddressBinding{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               network: 1,
               address: "ABCDEFG"
             })
  end

  test "invalid address binding" do
    assert false ==
             AddressBinding.valid?(%AddressBinding{
               device_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               network: 1,
               address: "ABCDEFG"
             })

    assert false ==
             AddressBinding.valid?(%AddressBinding{
               device_identifier: %ObjectIdentifier{type: :hello, instance: 1},
               network: 1,
               address: "ABCDEFG"
             })

    assert false ==
             AddressBinding.valid?(%AddressBinding{
               device_identifier: :hello,
               network: 1,
               address: "ABCDEFG"
             })

    assert false ==
             AddressBinding.valid?(%AddressBinding{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               network: -1,
               address: "ABCDEFG"
             })

    assert false ==
             AddressBinding.valid?(%AddressBinding{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               network: 1,
               address: :hello
             })
  end
end
