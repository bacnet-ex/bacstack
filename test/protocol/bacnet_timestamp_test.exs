defmodule BACnet.Protocol.BACnetTimestampTest do
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest BACnetTimestamp

  test "decode timestamp with time" do
    assert {:ok,
            {%BACnetTimestamp{
               datetime: nil,
               sequence_number: nil,
               time: %BACnetTime{
                 hour: 2,
                 hundredth: 0,
                 minute: 12,
                 second: 49
               },
               type: :time
             }, []}} = BACnetTimestamp.parse(tagged: {0, <<2, 12, 49, 0>>, 4})
  end

  test "decode timestamp with sequence number" do
    assert {:ok,
            {%BACnetTimestamp{
               datetime: nil,
               sequence_number: 5,
               time: nil,
               type: :sequence_number
             }, []}} = BACnetTimestamp.parse(tagged: {1, <<5>>, 1})
  end

  test "decode timestamp with date time" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:ok,
            {%BACnetTimestamp{
               datetime: %BACnetDateTime{date: ^date, time: ^time},
               sequence_number: nil,
               time: nil,
               type: :datetime
             }, []}} = BACnetTimestamp.parse(constructed: {2, [date: date, time: time], 0})
  end

  test "decode invalid timestamp" do
    assert {:error, :invalid_tags} = BACnetTimestamp.parse([])
    assert {:error, :invalid_tags} = BACnetTimestamp.parse(tagged: {2555, <<>>, 0})
  end

  test "decode invalid timestamp with time" do
    assert {:error, :invalid_tags} = BACnetTimestamp.parse(tagged: {0, <<>>, 4})
  end

  test "decode invalid timestamp with sequence number" do
    assert {:error, :invalid_tags} = BACnetTimestamp.parse(tagged: {1, <<>>, 0})
  end

  test "decode invalid timestamp with date time" do
    assert {:error, :invalid_tags} = BACnetTimestamp.parse(constructed: {2, [], 0})
  end

  test "encode timestamp with time" do
    assert {:ok, [tagged: {0, <<2, 12, 49, 0>>, 4}]} =
             BACnetTimestamp.encode(%BACnetTimestamp{
               datetime: nil,
               sequence_number: nil,
               time: %BACnetTime{
                 hour: 2,
                 hundredth: 0,
                 minute: 12,
                 second: 49
               },
               type: :time
             })
  end

  test "encode timestamp with sequence number" do
    assert {:ok, [tagged: {1, <<5>>, 1}]} =
             BACnetTimestamp.encode(%BACnetTimestamp{
               datetime: nil,
               sequence_number: 5,
               time: nil,
               type: :sequence_number
             })
  end

  test "encode timestamp with date time" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:ok, [constructed: {2, [date: ^date, time: ^time], 0}]} =
             BACnetTimestamp.encode(%BACnetTimestamp{
               datetime: %BACnetDateTime{date: date, time: time},
               sequence_number: nil,
               time: nil,
               type: :datetime
             })
  end

  test "valid timestamp" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert true ==
             BACnetTimestamp.valid?(%BACnetTimestamp{
               datetime: nil,
               sequence_number: nil,
               time: %BACnetTime{
                 hour: 2,
                 hundredth: 0,
                 minute: 12,
                 second: 49
               },
               type: :time
             })

    assert true ==
             BACnetTimestamp.valid?(%BACnetTimestamp{
               datetime: nil,
               sequence_number: 5,
               time: nil,
               type: :sequence_number
             })

    assert true ==
             BACnetTimestamp.valid?(%BACnetTimestamp{
               datetime: %BACnetDateTime{date: date, time: time},
               sequence_number: nil,
               time: nil,
               type: :datetime
             })
  end

  test "invalid timestamp" do
    assert false ==
             BACnetTimestamp.valid?(%BACnetTimestamp{
               datetime: nil,
               sequence_number: nil,
               time: :hello,
               type: :time
             })

    assert false ==
             BACnetTimestamp.valid?(%BACnetTimestamp{
               datetime: nil,
               sequence_number: :hello,
               time: nil,
               type: :sequence_number
             })

    assert false ==
             BACnetTimestamp.valid?(%BACnetTimestamp{
               datetime: :hello,
               sequence_number: nil,
               time: nil,
               type: :datetime
             })

    assert false ==
             BACnetTimestamp.valid?(%BACnetTimestamp{
               datetime: nil,
               sequence_number: nil,
               time: %BACnetTime{
                 hour: 2555,
                 hundredth: 0,
                 minute: 12,
                 second: 49
               },
               type: :time
             })

    assert false ==
             BACnetTimestamp.valid?(%BACnetTimestamp{
               datetime: nil,
               sequence_number: -5,
               time: nil,
               type: :sequence_number
             })

    assert false ==
             BACnetTimestamp.valid?(%BACnetTimestamp{
               datetime: %BACnetDateTime{date: :hello, time: :there},
               sequence_number: nil,
               time: nil,
               type: :datetime
             })
  end
end
