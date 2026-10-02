defmodule BACnet.Protocol.DestinationTest do
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.DaysOfWeek
  alias BACnet.Protocol.Destination
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.RecipientAddress

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest Destination

  test "decode destination" do
    assert {:ok,
            {%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             }, []}} =
             Destination.parse(
               bitstring: {true, true, true, true, true, true, true},
               time: %BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
               time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               },
               tagged: {0, <<2, 0, 0, 100>>, 4},
               unsigned_integer: 0,
               boolean: true,
               bitstring: {true, true, true}
             )
  end

  test "decode destination with recipient address" do
    assert {:ok,
            {%Destination{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{
                   network: 1,
                   address: <<192, 16>>
                 },
                 device: nil
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             }, []}} =
             Destination.parse(
               bitstring: {true, true, true, true, true, true, true},
               time: %BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
               time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               },
               constructed: {1, [unsigned_integer: 1, octet_string: <<192, 16>>], 0},
               unsigned_integer: 0,
               boolean: true,
               bitstring: {true, true, true}
             )
  end

  test "decode invalid destination" do
    assert {:error, :invalid_tags} = Destination.parse(octet_string: <<>>)
  end

  test "decode destination invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             Destination.parse(
               bitstring: {true, true, true, true, true, true, true},
               time: %BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
               time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               },
               tagged: {0, <<2, 0, 0, 100>>, 4},
               unsigned_integer: 65_535_534_124_423,
               boolean: true,
               bitstring: {true, true, true}
             )
  end

  test "encode destination" do
    assert {:ok,
            [
              bitstring: {true, true, true, true, true, true, true},
              time: %BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
              time: %BACnetTime{
                hour: 23,
                minute: 59,
                second: 59,
                hundredth: 99
              },
              tagged: {0, <<2, 0, 0, 100>>, 4},
              unsigned_integer: 0,
              boolean: true,
              bitstring: {true, true, true}
            ]} =
             Destination.encode(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })
  end

  test "encode destination with recipient address" do
    assert {:ok,
            [
              bitstring: {true, true, true, true, true, true, true},
              time: %BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
              time: %BACnetTime{
                hour: 23,
                minute: 59,
                second: 59,
                hundredth: 99
              },
              constructed: {1, [unsigned_integer: 1, octet_string: <<192, 16>>], 0},
              unsigned_integer: 0,
              boolean: true,
              bitstring: {true, true, true}
            ]} =
             Destination.encode(%Destination{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{
                   network: 1,
                   address: <<192, 16>>
                 },
                 device: nil
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })
  end

  test "encode destination invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             Destination.encode(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 65_124_432_195_759,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert {:error, :invalid_process_identifier_value} =
             Destination.encode(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: -1,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })
  end

  test "valid destination" do
    assert true ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert true ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{
                   network: 1,
                   address: <<192, 16>>
                 },
                 device: nil
               },
               process_identifier: 523_523,
               issue_confirmed_notifications: false,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })
  end

  test "invalid destination" do
    assert false ==
             Destination.valid?(%Destination{
               recipient: :hello,
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: :hello
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: :hello,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: :hello,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: :hello,
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: :hello
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: :hello,
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: :hello,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: :hello,
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: :unspecified,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: 23,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: :hello
             })

    assert false ==
             Destination.valid?(%Destination{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               process_identifier: 0,
               issue_confirmed_notifications: true,
               transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               valid_days: %DaysOfWeek{
                 monday: true,
                 tuesday: true,
                 wednesday: true,
                 thursday: true,
                 friday: true,
                 saturday: true,
                 sunday: true
               },
               from_time: %BACnetTime{
                 hour: 0,
                 minute: 0,
                 second: 0,
                 hundredth: 0
               },
               to_time: %BACnetTime{
                 hour: :unspecified,
                 minute: 59,
                 second: 59,
                 hundredth: 99
               }
             })
  end
end
