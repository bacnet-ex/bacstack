defmodule BACnet.Protocol.AccumulatorRecordTest do
  alias BACnet.Protocol.AccumulatorRecord
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.Constants

  require Constants
  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest AccumulatorRecord

  test "decode accumulator record" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:ok,
            {%AccumulatorRecord{
               accumulated_value: 522,
               present_value: 15,
               status: :starting,
               timestamp: %BACnetDateTime{date: ^date, time: ^time}
             }, []}} =
             AccumulatorRecord.parse(
               constructed: {0, [date: date, time: time], 0},
               tagged: {1, <<15>>, 1},
               tagged: {2, <<522::size(16)>>, 2},
               tagged: {3, <<Constants.macro_by_name(:accumulator_status, :starting)>>, 1}
             )
  end

  test "decode invalid accumulator record missing tags" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:error, :invalid_tags} =
             AccumulatorRecord.parse(
               constructed: {0, [date: date, time: time], 0},
               tagged: {1, <<15>>, 1},
               tagged: {2, <<522::size(16)>>, 2}
             )
  end

  test "decode invalid accumulator record invalid tags" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:error, :unknown_tag_encoding} =
             AccumulatorRecord.parse(
               constructed: {0, [date: date, time: time], 0},
               tagged: {1, <<>>, 0},
               tagged: {2, <<522::size(16)>>, 2},
               tagged: {3, <<Constants.macro_by_name(:accumulator_status, :starting)>>, 1}
             )
  end

  test "decode invalid accumulator record unknown status" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:error, {:unknown_status, 255}} =
             AccumulatorRecord.parse(
               constructed: {0, [date: date, time: time], 0},
               tagged: {1, <<15>>, 1},
               tagged: {2, <<522::size(16)>>, 2},
               tagged: {3, <<255>>, 1}
             )
  end

  test "encode accumulator record" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:ok,
            [
              constructed: {0, [date: ^date, time: ^time], 0},
              tagged: {1, <<15>>, 1},
              tagged: {2, <<522::size(16)>>, 2},
              tagged: {3, <<Constants.macro_by_name(:accumulator_status, :starting)>>, 1}
            ]} =
             AccumulatorRecord.encode(%AccumulatorRecord{
               accumulated_value: 522,
               present_value: 15,
               status: :starting,
               timestamp: %BACnetDateTime{date: date, time: time}
             })
  end

  test "encode invalid accumulator record" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:error, :invalid_value} =
             AccumulatorRecord.encode(%AccumulatorRecord{
               accumulated_value: 522.0,
               present_value: 15,
               status: :starting,
               timestamp: %BACnetDateTime{date: date, time: time}
             })
  end

  test "encode invalid accumulator record unknown status" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:error, {:unknown_status, :hello_world}} =
             AccumulatorRecord.encode(%AccumulatorRecord{
               accumulated_value: 522,
               present_value: 15,
               status: :hello_world,
               timestamp: %BACnetDateTime{date: date, time: time}
             })
  end

  test "valid accumulator record" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert true ==
             AccumulatorRecord.valid?(%AccumulatorRecord{
               accumulated_value: 522,
               present_value: 15,
               status: :starting,
               timestamp: %BACnetDateTime{date: date, time: time}
             })

    assert true ==
             AccumulatorRecord.valid?(%AccumulatorRecord{
               accumulated_value: 522,
               present_value: 15,
               status: :abnormal,
               timestamp: %BACnetDateTime{date: date, time: time}
             })
  end

  test "invalid accumulator record" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert false ==
             AccumulatorRecord.valid?(%AccumulatorRecord{
               accumulated_value: 522.0,
               present_value: 15,
               status: :starting,
               timestamp: %BACnetDateTime{date: date, time: time}
             })

    assert false ==
             AccumulatorRecord.valid?(%AccumulatorRecord{
               accumulated_value: 522,
               present_value: 15.0,
               status: :abnormal,
               timestamp: %BACnetDateTime{date: date, time: time}
             })

    assert false ==
             AccumulatorRecord.valid?(%AccumulatorRecord{
               accumulated_value: 522,
               present_value: 15,
               status: :hello,
               timestamp: %BACnetDateTime{date: date, time: time}
             })

    assert false ==
             AccumulatorRecord.valid?(%AccumulatorRecord{
               accumulated_value: 522,
               present_value: 15,
               status: :abnormal,
               timestamp: :hello
             })

    assert false ==
             AccumulatorRecord.valid?(%AccumulatorRecord{
               accumulated_value: 522,
               present_value: 15,
               status: :abnormal,
               timestamp: %BACnetDateTime{date: :hello, time: :there}
             })
  end
end
