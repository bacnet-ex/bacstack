defmodule BACnet.Protocol.TimeValueTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.TimeValue

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest TimeValue

  test "decode time value" do
    time = BACnetTime.utc_now()
    raw_value = {:enumerated, 1}
    value = Encoding.create!(raw_value)

    assert {:ok, {%TimeValue{time: ^time, value: ^value}, []}} =
             TimeValue.parse([{:time, time}, raw_value])
  end

  test "decode time value invalid missing value" do
    assert {:error, :invalid_tags} = TimeValue.parse(time: BACnetTime.utc_now())
  end

  test "encode time value" do
    time = BACnetTime.utc_now()
    raw_value = {:enumerated, 1}
    value = Encoding.create!(raw_value)

    assert {:ok, [{:time, ^time}, ^raw_value]} =
             TimeValue.encode(%TimeValue{time: time, value: value})
  end

  test "encode time value error" do
    time = BACnetTime.utc_now()
    raw_value = {:enumerated, 1}
    value = Encoding.create!(raw_value)

    assert {:error, :invalid_value} =
             TimeValue.encode(%TimeValue{time: time, value: %{value | encoding: :hello}})
  end

  test "valid time value" do
    time = BACnetTime.utc_now()

    assert true ==
             TimeValue.valid?(%TimeValue{time: time, value: Encoding.create!({:enumerated, 1})})

    assert true == TimeValue.valid?(%TimeValue{time: time, value: Encoding.create!({:real, 1.4})})

    assert true ==
             TimeValue.valid?(%TimeValue{time: time, value: Encoding.create!({:boolean, false})})
  end

  test "invalid time value" do
    time = BACnetTime.utc_now()

    assert false ==
             TimeValue.valid?(%TimeValue{
               time: Time.utc_now(),
               value: Encoding.create!({:enumerated, 1})
             })

    assert false ==
             TimeValue.valid?(%TimeValue{
               time: :hello_there,
               value: Encoding.create!({:real, 1.4})
             })

    assert false == TimeValue.valid?(%TimeValue{time: time, value: nil})
    assert false == TimeValue.valid?(%TimeValue{time: time, value: :hello_there})

    assert false ==
             TimeValue.valid?(%TimeValue{
               time: time,
               value: %{Encoding.create!({:boolean, false}) | encoding: :tagged}
             })

    assert false ==
             TimeValue.valid?(%TimeValue{
               time: time,
               value: %{Encoding.create!({:boolean, false}) | encoding: :constructed}
             })
  end
end
