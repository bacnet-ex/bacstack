defmodule BACnet.Protocol.LogMultipleRecordTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.LogMultipleRecord
  alias BACnet.Protocol.LogStatus

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest LogMultipleRecord

  test "decode invalid record missing pattern" do
    assert {:error, :invalid_tags} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {2, {:tagged, {0, <<4, 0>>, 2}}, 0}
             )
  end

  test "decode invalid record invalid date time" do
    assert {:error, :invalid_tags} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), date: BACnetTime.utc_now()], 0}
             )
  end

  test "decode invalid record invalid tagged encoding" do
    assert {:error, :unknown_tag_encoding} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<>>, 0}}, 0}
             )
  end

  test "decode record with status" do
    assert {:ok,
            {%LogMultipleRecord{
               timestamp: %BACnetDateTime{},
               log_data: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             },
             []}} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<5, 0>>, 2}}, 0}
             )
  end

  test "decode invalid record with status invalid bitstring" do
    assert {:error, :invalid_tags} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<4, 0>>, 2}}, 0}
             )
  end

  test "decode record with encoding" do
    data = [
      %Encoding{encoding: :tagged, extras: [tag_number: 0], type: :boolean, value: false},
      %Encoding{encoding: :tagged, extras: [tag_number: 1], type: :real, value: 6.0},
      %Encoding{encoding: :tagged, extras: [tag_number: 2], type: :enumerated, value: 1},
      %Encoding{encoding: :tagged, extras: [tag_number: 3], type: :unsigned_integer, value: 1},
      %Encoding{encoding: :tagged, extras: [tag_number: 4], type: :signed_integer, value: -6},
      %Encoding{
        encoding: :tagged,
        extras: [tag_number: 5],
        type: :bitstring,
        value: {false, false}
      },
      %Encoding{encoding: :constructed, extras: [tag_number: 8], type: :null, value: nil},
      nil,
      %BACnetError{
        class: 512,
        code: 512
      }
    ]

    assert {:ok,
            {%LogMultipleRecord{
               timestamp: %BACnetDateTime{},
               log_data: ^data
             },
             []}} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed:
                 {1,
                  {:constructed,
                   {1,
                    [
                      tagged: {0, <<0>>, 1},
                      tagged: {1, <<64, 192, 0, 0>>, 4},
                      tagged: {2, <<1>>, 1},
                      tagged: {3, <<1>>, 1},
                      tagged: {4, <<250>>, 1},
                      tagged: {5, <<6, 0>>, 2},
                      constructed: {8, {:null, nil}, 0},
                      tagged: {6, <<0>>, 1},
                      constructed: {7, [enumerated: 512, enumerated: 512], 0}
                    ], 0}}, 0}
             )
  end

  test "decode invalid record with event" do
    assert {:error, :invalid_tags} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:constructed, {1, [tagged: {10, <<0>>, 1}], 0}}, 0}
             )
  end

  test "decode record with time change" do
    assert {:ok,
            {%LogMultipleRecord{
               timestamp: %BACnetDateTime{},
               log_data: {:time_change, +0.0}
             },
             []}} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {2, <<0, 0, 0, 0>>, 4}}, 0}
             )
  end

  test "decode invalid record with time change" do
    assert {:error, :invalid_tags} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {2, <<0, 0>>, 2}}, 0}
             )
  end

  test "decode invalid record with time change invalid value" do
    assert {:error, :invalid_data} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {2, <<>>, 4}}, 0}
             )
  end

  test "decode invalid record with error" do
    assert {:error, :invalid_tags} =
             LogMultipleRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:constructed, {1, [{:constructed, {7, [], 0}}], 0}}, 0}
             )
  end

  test "encode record with status" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {0, <<5, 0>>, 2}}, 0}
            ]} =
             LogMultipleRecord.encode(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })
  end

  test "encode record with encoding" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed:
                {1,
                 {:constructed,
                  {1,
                   [
                     tagged: {0, <<0>>, 1},
                     tagged: {1, <<64, 192, 0, 0>>, 4},
                     tagged: {2, <<1>>, 1},
                     tagged: {3, <<1>>, 1},
                     tagged: {4, <<250>>, 1},
                     tagged: {5, <<6, 0>>, 2},
                     constructed: {8, {:null, nil}, 0},
                     tagged: {6, <<>>, 0},
                     constructed: {7, [enumerated: 512, enumerated: 512], 0}
                   ], 0}}, 0}
            ]} =
             LogMultipleRecord.encode(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: [
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 0],
                   type: :boolean,
                   value: false
                 },
                 %Encoding{encoding: :tagged, extras: [tag_number: 1], type: :real, value: 6.0},
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 2],
                   type: :enumerated,
                   value: 1
                 },
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 3],
                   type: :unsigned_integer,
                   value: 1
                 },
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 4],
                   type: :signed_integer,
                   value: -6
                 },
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 5],
                   type: :bitstring,
                   value: {false, false}
                 },
                 %Encoding{
                   encoding: :constructed,
                   extras: [tag_number: 8],
                   type: :null,
                   value: nil
                 },
                 nil,
                 %BACnetError{
                   class: 512,
                   code: 512
                 }
               ]
             })
  end

  test "encode record with time change" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {2, <<0, 0, 0, 0>>, 4}}, 0}
            ]} =
             LogMultipleRecord.encode(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: {:time_change, +0.0}
             })
  end

  test "encode invalid record" do
    assert {:error, :invalid_log_data} =
             LogMultipleRecord.encode(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: {:hello, :there}
             })
  end

  test "encode invalid record with list" do
    assert {:error, :invalid_log_data} =
             LogMultipleRecord.encode(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: [
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :null,
                   value: nil
                 },
                 {:hello, :there}
               ]
             })
  end

  test "encode invalid record with encoding" do
    assert {:error, :invalid_value} =
             LogMultipleRecord.encode(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: [
                 %Encoding{
                   encoding: :hello,
                   extras: [],
                   type: :double,
                   value: :hello
                 }
               ]
             })
  end

  test "valid record" do
    assert true ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })

    assert true ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: {:time_change, +0.0}
             })

    assert true ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: [
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 0],
                   type: :boolean,
                   value: false
                 },
                 %Encoding{encoding: :tagged, extras: [tag_number: 1], type: :real, value: 6.0},
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 2],
                   type: :enumerated,
                   value: 1
                 },
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 3],
                   type: :unsigned_integer,
                   value: 1
                 },
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 4],
                   type: :signed_integer,
                   value: -6
                 },
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 5],
                   type: :bitstring,
                   value: {false, false}
                 },
                 %Encoding{
                   encoding: :constructed,
                   extras: [tag_number: 8],
                   type: :null,
                   value: nil
                 },
                 nil,
                 %BACnetError{
                   class: 512,
                   code: 512
                 }
               ]
             })
  end

  test "invalid record" do
    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: :hello
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: :hello,
               log_data: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: %BACnetDateTime{
                 date: :hello,
                 time: BACnetTime.utc_now()
               },
               log_data: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: :hello
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: %LogStatus{
                 log_disabled: :hello,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: :hello
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: :hello,
               log_data: {:time_change, +0.0}
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: %BACnetDateTime{
                 date: :hello,
                 time: BACnetTime.utc_now()
               },
               log_data: {:time_change, +0.0}
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: {:time_change, 0}
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: [:hello]
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: [{:time_change, +0.0}, :hello]
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: [
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :double,
                   value: 6.9
                 }
               ]
             })

    assert false ==
             LogMultipleRecord.valid?(%LogMultipleRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_data: [
                 %Encoding{
                   encoding: :constructed,
                   extras: [tag_number: 9],
                   type: :null,
                   value: nil
                 }
               ]
             })
  end
end
