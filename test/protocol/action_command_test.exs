defmodule BACnet.Protocol.ActionCommandTest do
  alias BACnet.Protocol.ActionCommand
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier

  require Constants
  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ActionCommand

  test "decode action command" do
    value = Encoding.create!({:real, 5.0})

    assert {:ok,
            {%ActionCommand{
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
             []}} =
             ActionCommand.parse(
               tagged: {1, <<0, 0, 0, 24>>, 4},
               tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
               constructed: {4, {:real, 5.0}, 0},
               tagged: {7, <<1>>, 1},
               tagged: {8, <<0>>, 1}
             )
  end

  test "decode action command with numeric property identifier" do
    value = Encoding.create!({:real, 5.0})

    assert {:ok,
            {%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 526,
               property_array_index: nil,
               property_value: ^value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             },
             []}} =
             ActionCommand.parse(
               tagged: {1, <<0, 0, 0, 24>>, 4},
               tagged: {2, <<526::size(16)>>, 2},
               constructed: {4, {:real, 5.0}, 0},
               tagged: {7, <<1>>, 1},
               tagged: {8, <<0>>, 1}
             )
  end

  test "decode action command with array index" do
    value = Encoding.create!({:real, 5.0})

    assert {:ok,
            {%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: 5,
               property_value: ^value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             },
             []}} =
             ActionCommand.parse(
               tagged: {1, <<0, 0, 0, 24>>, 4},
               tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
               tagged: {3, <<5>>, 1},
               constructed: {4, {:real, 5.0}, 0},
               tagged: {7, <<1>>, 1},
               tagged: {8, <<0>>, 1}
             )
  end

  test "decode action command with priority" do
    value = Encoding.create!({:real, 5.0})

    assert {:ok,
            {%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: ^value,
               priority: 16,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             },
             []}} =
             ActionCommand.parse(
               tagged: {1, <<0, 0, 0, 24>>, 4},
               tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
               constructed: {4, {:real, 5.0}, 0},
               tagged: {5, <<16>>, 1},
               tagged: {7, <<1>>, 1},
               tagged: {8, <<0>>, 1}
             )
  end

  test "decode action command with post delay" do
    value = Encoding.create!({:real, 5.0})

    assert {:ok,
            {%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: ^value,
               priority: nil,
               post_delay: 120,
               quit_on_failure: true,
               write_successful: false
             },
             []}} =
             ActionCommand.parse(
               tagged: {1, <<0, 0, 0, 24>>, 4},
               tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
               constructed: {4, {:real, 5.0}, 0},
               tagged: {6, <<120>>, 1},
               tagged: {7, <<1>>, 1},
               tagged: {8, <<0>>, 1}
             )
  end

  test "decode action command with device identifier" do
    value = Encoding.create!({:real, 5.0})

    assert {:ok,
            {%ActionCommand{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: ^value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             },
             []}} =
             ActionCommand.parse(
               tagged: {0, <<8::size(10), 1::size(22)>>, 4},
               tagged: {1, <<0, 0, 0, 24>>, 4},
               tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
               constructed: {4, {:real, 5.0}, 0},
               tagged: {7, <<1>>, 1},
               tagged: {8, <<0>>, 1}
             )
  end

  test "decode action command with everything" do
    value = Encoding.create!({:real, 5.0})

    assert {:ok,
            {%ActionCommand{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: 5,
               property_value: ^value,
               priority: 16,
               post_delay: 120,
               quit_on_failure: true,
               write_successful: false
             },
             []}} =
             ActionCommand.parse(
               tagged: {0, <<8::size(10), 1::size(22)>>, 4},
               tagged: {1, <<0, 0, 0, 24>>, 4},
               tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
               tagged: {3, <<5>>, 1},
               constructed: {4, {:real, 5.0}, 0},
               tagged: {5, <<16>>, 1},
               tagged: {6, <<120>>, 1},
               tagged: {7, <<1>>, 1},
               tagged: {8, <<0>>, 1}
             )
  end

  test "decode invalid action command missing tags" do
    assert {:error, :invalid_tags} = ActionCommand.parse([])
  end

  test "decode invalid action command invalid tags" do
    assert {:error, :unknown_tag_encoding} = ActionCommand.parse(tagged: {1, <<>>, 0})
  end

  test "encode action command" do
    assert {:ok,
            [
              tagged: {1, <<0, 0, 0, 24>>, 4},
              tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
              constructed: {4, {:real, 5.0}, 0},
              tagged: {7, <<1>>, 1},
              tagged: {8, <<0>>, 1}
            ]} =
             ActionCommand.encode(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:real, 5.0}),
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })
  end

  test "encode action command with numeric property identifier" do
    assert {:ok,
            [
              tagged: {1, <<0, 0, 0, 24>>, 4},
              tagged: {2, <<526::size(16)>>, 2},
              constructed: {4, {:real, 5.0}, 0},
              tagged: {7, <<1>>, 1},
              tagged: {8, <<0>>, 1}
            ]} =
             ActionCommand.encode(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 526,
               property_array_index: nil,
               property_value: Encoding.create!({:real, 5.0}),
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })
  end

  test "encode action command with array index" do
    assert {:ok,
            [
              tagged: {1, <<0, 0, 0, 24>>, 4},
              tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
              tagged: {3, <<5>>, 1},
              constructed: {4, {:real, 5.0}, 0},
              tagged: {7, <<1>>, 1},
              tagged: {8, <<0>>, 1}
            ]} =
             ActionCommand.encode(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: 5,
               property_value: Encoding.create!({:real, 5.0}),
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })
  end

  test "encode action command with priority" do
    assert {:ok,
            [
              tagged: {1, <<0, 0, 0, 24>>, 4},
              tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
              constructed: {4, {:real, 5.0}, 0},
              tagged: {5, <<16>>, 1},
              tagged: {7, <<1>>, 1},
              tagged: {8, <<0>>, 1}
            ]} =
             ActionCommand.encode(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:real, 5.0}),
               priority: 16,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })
  end

  test "encode action command with post delay" do
    assert {:ok,
            [
              tagged: {1, <<0, 0, 0, 24>>, 4},
              tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
              constructed: {4, {:real, 5.0}, 0},
              tagged: {6, <<120>>, 1},
              tagged: {7, <<1>>, 1},
              tagged: {8, <<0>>, 1}
            ]} =
             ActionCommand.encode(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:real, 5.0}),
               priority: nil,
               post_delay: 120,
               quit_on_failure: true,
               write_successful: false
             })
  end

  test "encode action command with device identifier" do
    assert {:ok,
            [
              tagged: {0, <<8::size(10), 1::size(22)>>, 4},
              tagged: {1, <<0, 0, 0, 24>>, 4},
              tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
              constructed: {4, {:real, 5.0}, 0},
              tagged: {7, <<1>>, 1},
              tagged: {8, <<0>>, 1}
            ]} =
             ActionCommand.encode(%ActionCommand{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:real, 5.0}),
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })
  end

  test "encode action command with everything" do
    assert {:ok,
            [
              tagged: {0, <<8::size(10), 1::size(22)>>, 4},
              tagged: {1, <<0, 0, 0, 24>>, 4},
              tagged: {2, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
              tagged: {3, <<5>>, 1},
              constructed: {4, {:real, 5.0}, 0},
              tagged: {5, <<16>>, 1},
              tagged: {6, <<120>>, 1},
              tagged: {7, <<1>>, 1},
              tagged: {8, <<0>>, 1}
            ]} =
             ActionCommand.encode(%ActionCommand{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: 5,
               property_value: Encoding.create!({:real, 5.0}),
               priority: 16,
               post_delay: 120,
               quit_on_failure: true,
               write_successful: false
             })
  end

  test "encode invalid action command with" do
    assert {:error, :invalid_value} =
             ActionCommand.encode(%ActionCommand{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: 5.0,
               property_value: Encoding.create!({:real, 5.0}),
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })
  end

  test "valid action command" do
    value = Encoding.create!({:real, 5.0})

    assert true ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert true ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 526,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert true ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: 5,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert true ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: 16,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert true ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: 120,
               quit_on_failure: true,
               write_successful: false
             })

    assert true ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert true ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: %ObjectIdentifier{type: :device, instance: 1},
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: 5,
               property_value: value,
               priority: 16,
               post_delay: 120,
               quit_on_failure: true,
               write_successful: false
             })
  end

  test "invalid action command" do
    value = Encoding.create!({:real, 5.0})

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: %ObjectIdentifier{type: :hello, instance: 24},
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: :hello,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :hello, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: :hello,
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :hello,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: 5.0,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: -526,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: 0,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: 17,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: :hello,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: false,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: -1,
               quit_on_failure: true,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: nil,
               write_successful: false
             })

    assert false ==
             ActionCommand.valid?(%ActionCommand{
               device_identifier: nil,
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: value,
               priority: nil,
               post_delay: nil,
               quit_on_failure: true,
               write_successful: nil
             })
  end
end
