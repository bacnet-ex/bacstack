defmodule BACnet.Protocol.ActionListTest do
  alias BACnet.Protocol.ActionCommand
  alias BACnet.Protocol.ActionList
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier

  require Constants
  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ActionList

  test "decode action list" do
    value = Encoding.create!({:real, 5.0})

    assert {:ok,
            {%ActionList{
               actions: [
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: ^value,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: true,
                   write_successful: false
                 }
               ]
             }, []}} =
             ActionList.parse(
               constructed:
                 {0,
                  [
                    tagged: {1, <<0, 0, 0, 24>>, 4},
                    tagged:
                      {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
                    constructed: {4, {:real, 5.0}, 0},
                    tagged: {7, <<1>>, 1},
                    tagged: {8, <<0>>, 1}
                  ], 0}
             )
  end

  test "decode action list multi" do
    value = Encoding.create!({:real, 5.0})
    value2 = Encoding.create!({:real, 0.0})

    assert {:ok,
            {%ActionList{
               actions: [
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: ^value,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: true,
                   write_successful: false
                 },
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: ^value2,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 },
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: ^value,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: true,
                   write_successful: false
                 },
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: ^value2,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 }
               ]
             }, []}} =
             ActionList.parse(
               constructed:
                 {0,
                  [
                    tagged: {1, <<0, 0, 0, 24>>, 4},
                    tagged:
                      {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
                    constructed: {4, {:real, 5.0}, 0},
                    tagged: {7, <<1>>, 1},
                    tagged: {8, <<0>>, 1},
                    tagged: {1, <<0, 0, 0, 32>>, 4},
                    tagged: {2, <<Constants.macro_by_name(:property_identifier, :deadband)>>, 1},
                    constructed: {4, {:real, 0.0}, 0},
                    tagged: {7, <<0>>, 1},
                    tagged: {8, <<0>>, 1},
                    tagged: {1, <<0, 0, 0, 24>>, 4},
                    tagged:
                      {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
                    constructed: {4, {:real, 5.0}, 0},
                    tagged: {7, <<1>>, 1},
                    tagged: {8, <<0>>, 1},
                    tagged: {1, <<0, 0, 0, 32>>, 4},
                    tagged: {2, <<Constants.macro_by_name(:property_identifier, :deadband)>>, 1},
                    constructed: {4, {:real, 0.0}, 0},
                    tagged: {7, <<0>>, 1},
                    tagged: {8, <<0>>, 1}
                  ], 0}
             )
  end

  test "decode action list empty" do
    assert {:ok,
            {%ActionList{
               actions: []
             }, []}} = ActionList.parse(constructed: {0, [], 0})
  end

  test "decode invalid action list invalid tags" do
    assert {:error, :invalid_tags} = ActionList.parse([])
  end

  test "decode invalid action list incomplete tags" do
    assert {:error, :invalid_tags} =
             ActionList.parse(
               constructed:
                 {0,
                  [
                    tagged: {1, <<0, 0, 0, 24>>, 4}
                  ], 0}
             )
  end

  test "encode action list" do
    value = Encoding.create!({:real, 5.0})

    assert {:ok,
            [
              constructed:
                {0,
                 [
                   tagged: {1, <<0, 0, 0, 24>>, 4},
                   tagged:
                     {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
                   constructed: {4, {:real, 5.0}, 0},
                   tagged: {7, <<1>>, 1},
                   tagged: {8, <<0>>, 1}
                 ], 0}
            ]} =
             ActionList.encode(%ActionList{
               actions: [
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: value,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: true,
                   write_successful: false
                 }
               ]
             })
  end

  test "encode action list multi" do
    value = Encoding.create!({:real, 5.0})
    value2 = Encoding.create!({:real, 0.0})

    assert {:ok,
            [
              constructed:
                {0,
                 [
                   tagged: {1, <<0, 0, 0, 24>>, 4},
                   tagged:
                     {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
                   constructed: {4, {:real, 5.0}, 0},
                   tagged: {7, <<1>>, 1},
                   tagged: {8, <<0>>, 1},
                   tagged: {1, <<0, 0, 0, 32>>, 4},
                   tagged: {2, <<Constants.macro_by_name(:property_identifier, :deadband)>>, 1},
                   constructed: {4, {:real, +0.0}, 0},
                   tagged: {7, <<0>>, 1},
                   tagged: {8, <<0>>, 1},
                   tagged: {1, <<0, 0, 0, 24>>, 4},
                   tagged:
                     {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
                   constructed: {4, {:real, 5.0}, 0},
                   tagged: {7, <<1>>, 1},
                   tagged: {8, <<0>>, 1},
                   tagged: {1, <<0, 0, 0, 32>>, 4},
                   tagged: {2, <<Constants.macro_by_name(:property_identifier, :deadband)>>, 1},
                   constructed: {4, {:real, +0.0}, 0},
                   tagged: {7, <<0>>, 1},
                   tagged: {8, <<0>>, 1}
                 ], 0}
            ]} =
             ActionList.encode(%ActionList{
               actions: [
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: value,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: true,
                   write_successful: false
                 },
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: value2,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 },
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: value,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: true,
                   write_successful: false
                 },
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: value2,
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 }
               ]
             })
  end

  test "encode action list empty" do
    assert {:ok, [constructed: {0, [], 0}]} =
             ActionList.encode(%ActionList{
               actions: []
             })
  end

  test "encode invalid action list" do
    assert {:error, :invalid_value} =
             ActionList.encode(%ActionList{
               actions: [
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: 5.0,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 }
               ]
             })
  end

  test "valid action list" do
    assert true == ActionList.valid?(%ActionList{actions: []})

    assert true ==
             ActionList.valid?(%ActionList{
               actions: [
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 }
               ]
             })

    assert true ==
             ActionList.valid?(%ActionList{
               actions: [
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 },
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: true,
                   write_successful: false
                 },
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 }
               ]
             })
  end

  test "invalid action list" do
    assert false ==
             ActionList.valid?(%ActionList{
               actions: [
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: -1,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 }
               ]
             })

    assert false ==
             ActionList.valid?(%ActionList{
               actions: [
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: 1,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 },
                 %ActionCommand{
                   device_identifier: nil,
                   object_identifier: %ObjectIdentifier{type: :analog_input, instance: 32},
                   property_identifier: -1,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil,
                   post_delay: nil,
                   quit_on_failure: false,
                   write_successful: false
                 }
               ]
             })

    assert false == ActionList.valid?(%ActionList{actions: nil})
    assert false == ActionList.valid?(%ActionList{actions: [nil]})
  end
end
