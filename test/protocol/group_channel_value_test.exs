defmodule BACnet.Protocol.GroupChannelValueTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.GroupChannelValue

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest GroupChannelValue

  test "decode value" do
    assert {:ok,
            {%GroupChannelValue{
               channel: 268,
               overriding_priority: nil,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             },
             []}} =
             GroupChannelValue.parse(
               tagged: {0, <<1, 12>>, 2},
               unsigned_integer: 1111
             )
  end

  test "decode value with priority" do
    assert {:ok,
            {%GroupChannelValue{
               channel: 268,
               overriding_priority: 15,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             },
             []}} =
             GroupChannelValue.parse(
               tagged: {0, <<1, 12>>, 2},
               tagged: {1, <<15>>, 1},
               unsigned_integer: 1111
             )
  end

  test "decode value lightning (raw)" do
    assert {:ok,
            {%GroupChannelValue{
               channel: 268,
               overriding_priority: nil,
               value: [
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :real,
                   value: 1.0
                 }
               ]
             },
             []}} =
             GroupChannelValue.parse(
               tagged: {0, <<1, 12>>, 2},
               constructed: {0, [real: 1.0], 0}
             )
  end

  test "decode value invalid channel" do
    assert {:error, :invalid_channel_value} =
             GroupChannelValue.parse(
               tagged: {0, <<1, 12, 255, 255>>, 4},
               unsigned_integer: 1111
             )
  end

  test "decode invalid value invalid priority" do
    assert {:error, :unknown_tag_encoding} =
             GroupChannelValue.parse(
               tagged: {0, <<1, 12>>, 2},
               tagged: {1, <<>>, 0}
             )
  end

  test "decode invalid value invalid value" do
    assert {:error, :invalid_tags} =
             GroupChannelValue.parse(
               tagged: {0, <<1, 12>>, 2},
               tagged: {2, <<>>, 0}
             )
  end

  test "decode invalid value missing pattern" do
    assert {:error, :invalid_tags} = GroupChannelValue.parse(tagged: {0, <<1, 12>>, 2})
  end

  test "encode value" do
    assert {:ok,
            [
              tagged: {0, <<1, 12>>, 2},
              unsigned_integer: 1111
            ]} =
             GroupChannelValue.encode(%GroupChannelValue{
               channel: 268,
               overriding_priority: nil,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })
  end

  test "encode value with priority" do
    assert {:ok,
            [
              tagged: {0, <<1, 12>>, 2},
              tagged: {1, <<15>>, 1},
              unsigned_integer: 1111
            ]} =
             GroupChannelValue.encode(%GroupChannelValue{
               channel: 268,
               overriding_priority: 15,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })
  end

  test "encode value lightning (raw)" do
    assert {:ok,
            [
              tagged: {0, <<1, 12>>, 2},
              constructed: {0, [real: 1.0], 0}
            ]} =
             GroupChannelValue.encode(%GroupChannelValue{
               channel: 268,
               overriding_priority: nil,
               value: [
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :real,
                   value: 1.0
                 }
               ]
             })
  end

  test "encode value invalid channel" do
    assert {:error, :invalid_channel_value} =
             GroupChannelValue.encode(%GroupChannelValue{
               channel: 65_536,
               overriding_priority: nil,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })
  end

  test "encode invalid value" do
    assert {:error, :invalid_value} =
             GroupChannelValue.encode(%GroupChannelValue{
               channel: 256,
               overriding_priority: nil,
               value: [
                 %Encoding{
                   encoding: :hello,
                   extras: [],
                   type: :unsigned_integer,
                   value: 111
                 }
               ]
             })
  end

  test "encode invalid value nested" do
    assert {:error, :invalid_value} =
             GroupChannelValue.encode(%GroupChannelValue{
               channel: 268,
               overriding_priority: nil,
               value: [
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :unsigned_integer,
                   value: 1111
                 },
                 %Encoding{
                   encoding: :hello,
                   extras: [],
                   type: :unsigned_integer,
                   value: 1111
                 }
               ]
             })
  end

  test "valid value" do
    assert true ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 0,
               overriding_priority: nil,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })

    assert true ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 268,
               overriding_priority: 1,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })

    assert true ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 65_535,
               overriding_priority: 16,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })

    assert true ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 65_535,
               overriding_priority: nil,
               value: [
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :unsigned_integer,
                   value: 1111
                 }
               ]
             })
  end

  test "invalid value" do
    assert false ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: :hello,
               overriding_priority: nil,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })

    assert false ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: -1,
               overriding_priority: nil,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })

    assert false ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 65_536,
               overriding_priority: 1,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })

    assert false ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 1,
               overriding_priority: :hello,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })

    assert false ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 65,
               overriding_priority: -1,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })

    assert false ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 65_535,
               overriding_priority: 17,
               value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :unsigned_integer,
                 value: 1111
               }
             })

    assert false ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 65_535,
               overriding_priority: nil,
               value: :hello
             })

    assert false ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 65_535,
               overriding_priority: nil,
               value: [:hello]
             })

    assert false ==
             GroupChannelValue.valid?(%GroupChannelValue{
               channel: 65_535,
               overriding_priority: nil,
               value: [
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :unsigned_integer,
                   value: 1111
                 },
                 6.0
               ]
             })
  end
end
