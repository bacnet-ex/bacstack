defmodule BACnet.Protocol.RecipientTest do
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.RecipientAddress

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest Recipient

  test "decode recipient device" do
    assert {:ok,
            {%Recipient{
               type: :device,
               address: nil,
               device: %ObjectIdentifier{type: :device, instance: 100}
             }, []}} = Recipient.parse(tagged: {0, <<2, 0, 0, 100>>, 4})
  end

  test "decode recipient invalid device" do
    assert {:error, :invalid_data} = Recipient.parse(tagged: {0, <<1, 2, 0, 0, 100>>, 5})
  end

  test "decode recipient address" do
    assert {:ok,
            {%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 1,
                 address: "FABDCDAEBAC0"
               },
               device: nil
             },
             []}} =
             Recipient.parse(
               constructed: {1, [unsigned_integer: 1, octet_string: "FABDCDAEBAC0"], 0}
             )
  end

  test "decode recipient address broadcast" do
    assert {:ok,
            {%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 1,
                 address: :broadcast
               },
               device: nil
             },
             []}} =
             Recipient.parse(constructed: {1, [unsigned_integer: 1, octet_string: ""], 0})
  end

  test "decode recipient invalid address" do
    assert {:error, :invalid_tags} = Recipient.parse(constructed: {1, [], 0})
  end

  test "decode recipient invalid" do
    assert {:error, :invalid_tags} = Recipient.parse(tagged: {3, <<>>, 0})
  end

  test "encode recipient device" do
    assert {:ok, [tagged: {0, <<2, 0, 0, 100>>, 4}]} =
             Recipient.encode(%Recipient{
               type: :device,
               address: nil,
               device: %ObjectIdentifier{type: :device, instance: 100}
             })
  end

  test "encode recipient device invalid" do
    assert {:error, :invalid_value} =
             Recipient.encode(%Recipient{
               type: :device,
               address: nil,
               device: %ObjectIdentifier{type: :device, instance: -2}
             })
  end

  test "encode recipient address" do
    assert {:ok,
            [
              constructed: {1, [unsigned_integer: 1, octet_string: "FABDCDAEBAC0"], 0}
            ]} =
             Recipient.encode(%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 1,
                 address: "FABDCDAEBAC0"
               },
               device: nil
             })
  end

  test "encode recipient address broadcast" do
    assert {:ok, [constructed: {1, [unsigned_integer: 1, octet_string: ""], 0}]} =
             Recipient.encode(%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 1,
                 address: :broadcast
               },
               device: nil
             })
  end

  test "valid recipient" do
    assert true ==
             Recipient.valid?(%Recipient{
               type: :device,
               address: nil,
               device: %ObjectIdentifier{type: :device, instance: 2}
             })

    assert true ==
             Recipient.valid?(%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 1,
                 address: "FABDCDAEBAC0"
               },
               device: nil
             })

    assert true ==
             Recipient.valid?(%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 65_534,
                 address: "FABDCDAEBAC0"
               },
               device: nil
             })

    assert true ==
             Recipient.valid?(%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 1,
                 address: :broadcast
               },
               device: nil
             })

    assert true ==
             Recipient.valid?(%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 0,
                 address: :broadcast
               },
               device: nil
             })

    assert true ==
             Recipient.valid?(%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 65_535,
                 address: :broadcast
               },
               device: nil
             })
  end

  test "invalid recipient" do
    assert false ==
             Recipient.valid?(%Recipient{
               type: :hello_there,
               address: nil,
               device: nil
             })

    assert false ==
             Recipient.valid?(%Recipient{
               type: :device,
               address: nil,
               device: nil
             })

    assert false ==
             Recipient.valid?(%Recipient{
               type: :device,
               address: nil,
               device: :hello_there
             })

    assert false ==
             Recipient.valid?(%Recipient{
               type: :device,
               address: nil,
               device: %ObjectIdentifier{type: :device, instance: -2}
             })

    assert false ==
             Recipient.valid?(%Recipient{
               type: :address,
               address: :hello_there,
               device: nil
             })

    assert false ==
             Recipient.valid?(%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: 65_535,
                 address: :hello_there
               },
               device: nil
             })

    # assert false == Recipient.valid?(%Recipient{
    #            type: :address,
    #            address: %RecipientAddress{
    #              network: 0,
    #              address: "Aa904eB"
    #            },
    #            device: nil
    #          })
    assert false ==
             Recipient.valid?(%Recipient{
               type: :address,
               address: %RecipientAddress{
                 network: -1,
                 address: :broadcast
               },
               device: nil
             })
  end
end
