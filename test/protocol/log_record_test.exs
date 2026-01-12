defmodule BACnet.Protocol.LogRecordTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.LogRecord
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest LogRecord

  test "decode invalid record missing pattern" do
    assert {:error, :invalid_tags} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {2, {:tagged, {0, <<4, 0>>, 2}}, 0}
             )
  end

  test "decode invalid record invalid date time" do
    assert {:error, :invalid_tags} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), date: BACnetTime.utc_now()], 0}
             )
  end

  test "decode invalid record invalid tagged encoding" do
    assert {:error, :unknown_tag_encoding} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<>>, 0}}, 0}
             )
  end

  test "decode record with status" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<5, 0>>, 2}}, 0}
             )
  end

  test "decode record with status as list" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, [{:tagged, {0, <<5, 0>>, 2}}], 0}
             )
  end

  test "decode record with status and status flags" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 overridden: false,
                 out_of_service: false
               }
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<5, 0>>, 2}}, 0},
               tagged: {2, <<4, 0>>, 2}
             )
  end

  test "decode invalid record with status invalid bitstring" do
    assert {:error, :invalid_tags} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<4, 0>>, 2}}, 0}
             )
  end

  test "decode record with encoding boolean" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 1],
                 type: :boolean,
                 value: false
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {1, <<0>>, 1}}, 0}
             )
  end

  test "decode record with encoding real" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 2],
                 type: :real,
                 value: 6.0
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {2, <<64, 192, 0, 0>>, 4}}, 0}
             )
  end

  test "decode record with encoding enumerated" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 3],
                 type: :enumerated,
                 value: 1
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {3, <<1>>, 1}}, 0}
             )
  end

  test "decode record with encoding unsigned integer" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 4],
                 type: :unsigned_integer,
                 value: 1
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {4, <<1>>, 1}}, 0}
             )
  end

  test "decode record with encoding signed integer" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 5],
                 type: :signed_integer,
                 value: -6
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {5, <<250>>, 1}}, 0}
             )
  end

  test "decode record with encoding bitstring" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 6],
                 type: :bitstring,
                 value: {false, false}
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {6, <<6, 0>>, 2}}, 0}
             )
  end

  test "decode record with encoding nil" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: nil,
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {7, <<0>>, 1}}, 0}
             )
  end

  test "decode record with error" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %BACnetError{
                 class: 512,
                 code: 512
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:constructed, {8, [enumerated: 512, enumerated: 512], 0}}, 0}
             )
  end

  test "decode record with encoding abstract" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %Encoding{
                 encoding: :constructed,
                 extras: [tag_number: 10],
                 type: :null,
                 value: nil
               },
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:constructed, {10, {:null, nil}, 0}}, 0}
             )
  end

  test "decode invalid record with event" do
    assert {:error, :invalid_tags} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {15, <<0>>, 1}}, 0}
             )
  end

  test "decode record with time change" do
    assert {:ok,
            {%LogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: {:time_change, +0.0},
               status_flags: nil
             }, []}} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {9, <<0, 0, 0, 0>>, 4}}, 0}
             )
  end

  test "decode invalid record with time change" do
    assert {:error, :invalid_data} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {9, <<0, 0>>, 2}}, 0}
             )
  end

  test "decode invalid record with time change invalid value" do
    assert {:error, :invalid_data} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {9, <<>>, 4}}, 0}
             )
  end

  test "decode invalid record with error" do
    assert {:error, :invalid_tags} =
             LogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:constructed, {8, [], 0}}, 0}
             )
  end

  test "encode record with status" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {0, <<5, 0>>, 2}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: nil
             })
  end

  test "encode record with status and status flags" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {0, <<5, 0>>, 2}}, 0},
              tagged: {2, <<4, 0>>, 2}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 overridden: false,
                 out_of_service: false
               }
             })
  end

  test "encode record with encoding boolean" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {1, <<0>>, 1}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 1],
                 type: :boolean,
                 value: false
               },
               status_flags: nil
             })
  end

  test "encode record with encoding real" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {2, <<64, 192, 0, 0>>, 4}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 2],
                 type: :real,
                 value: 6.0
               },
               status_flags: nil
             })
  end

  test "encode record with encoding enumerated" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {3, <<1>>, 1}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 3],
                 type: :enumerated,
                 value: 1
               },
               status_flags: nil
             })
  end

  test "encode record with encoding unsigned integer" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {4, <<1>>, 1}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 4],
                 type: :unsigned_integer,
                 value: 1
               },
               status_flags: nil
             })
  end

  test "encode record with encoding signed integer" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {5, <<250>>, 1}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 5],
                 type: :signed_integer,
                 value: -6
               },
               status_flags: nil
             })
  end

  test "encode record with encoding bitstring" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {6, <<6, 0>>, 2}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 6],
                 type: :bitstring,
                 value: {false, false}
               },
               status_flags: nil
             })
  end

  test "encode record with encoding nil" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {7, <<>>, 0}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: nil,
               status_flags: nil
             })
  end

  test "encode record with encoding nil special" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {7, <<>>, 0}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :null,
                 value: nil
               },
               status_flags: nil
             })
  end

  test "encode record with error" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:constructed, {8, [enumerated: 512, enumerated: 512], 0}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %BACnetError{
                 class: 512,
                 code: 512
               },
               status_flags: nil
             })
  end

  test "encode record with encoding abstract" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:constructed, {10, {:null, nil}, 0}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :constructed,
                 extras: [tag_number: 10],
                 type: :null,
                 value: nil
               },
               status_flags: nil
             })
  end

  test "encode record with time change" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {9, <<0, 0, 0, 0>>, 4}}, 0}
            ]} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: {:time_change, +0.0},
               status_flags: nil
             })
  end

  test "encode invalid record" do
    assert {:error, :invalid_log_datum} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: {:hello, :there},
               status_flags: nil
             })
  end

  test "encode invalid record with encoding" do
    assert {:error, :invalid_value} =
             LogRecord.encode(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :hello,
                 extras: [],
                 type: :double,
                 value: :hello
               },
               status_flags: nil
             })
  end

  test "valid record" do
    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: true,
                 log_interrupted: false
               },
               status_flags: %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 overridden: true,
                 out_of_service: false
               }
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: {:time_change, +0.0},
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: {:time_change, +0.0},
               status_flags: %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 overridden: true,
                 out_of_service: false
               }
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 1],
                 type: :boolean,
                 value: false
               },
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 2],
                 type: :real,
                 value: 6.0
               },
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 3],
                 type: :enumerated,
                 value: 1
               },
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 4],
                 type: :unsigned_integer,
                 value: 1
               },
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 5],
                 type: :signed_integer,
                 value: -6
               },
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 6],
                 type: :bitstring,
                 value: {false, false}
               },
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 6],
                 type: :bitstring,
                 value: {false, false}
               },
               status_flags: %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 overridden: true,
                 out_of_service: false
               }
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :constructed,
                 extras: [tag_number: 10],
                 type: :null,
                 value: nil
               },
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :constructed,
                 extras: [tag_number: 10],
                 type: :null,
                 value: nil
               },
               status_flags: %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 overridden: true,
                 out_of_service: false
               }
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: nil,
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: nil,
               status_flags: %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 overridden: true,
                 out_of_service: false
               }
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %BACnetError{
                 class: 512,
                 code: 512
               },
               status_flags: nil
             })

    assert true ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %BACnetError{
                 class: 512,
                 code: 512
               },
               status_flags: %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 overridden: true,
                 out_of_service: false
               }
             })
  end

  test "invalid record" do
    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: :hello,
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: :hello
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: :hello,
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: nil,
               status_flags: :hello
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: %BACnetDateTime{
                 date: :hello,
                 time: BACnetTime.utc_now()
               },
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: :hello,
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %LogStatus{
                 log_disabled: :hello,
                 buffer_purged: false,
                 log_interrupted: false
               },
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: :hello,
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: :hello,
               log_datum: {:time_change, +0.0},
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: {:time_change, +0.0},
               status_flags: :hello
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: %BACnetDateTime{
                 date: :hello,
                 time: BACnetTime.utc_now()
               },
               log_datum: {:time_change, +0.0},
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: {:time_change, 0},
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :double,
                 value: 6.9
               },
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :real,
                 value: 6.9
               },
               status_flags: :hello
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: %BACnetDateTime{date: :hello, time: :there},
               log_datum: %Encoding{
                 encoding: :constructed,
                 extras: [tag_number: 10],
                 type: :null,
                 value: nil
               },
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :constructed,
                 extras: [tag_number: 9],
                 type: :null,
                 value: nil
               },
               status_flags: nil
             })

    assert false ==
             LogRecord.valid?(%LogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %Encoding{
                 encoding: :constructed,
                 extras: [tag_number: 10],
                 type: :null,
                 value: nil
               },
               status_flags: :hello
             })
  end
end
