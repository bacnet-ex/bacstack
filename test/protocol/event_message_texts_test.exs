defmodule BACnet.Protocol.EventMessageTextsTest do
  alias BACnet.Protocol.EventMessageTexts

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest EventMessageTexts

  test "decode texts" do
    assert {:ok,
            {%EventMessageTexts{
               to_offnormal: "OffNormal",
               to_fault: "Fault",
               to_normal: "Normal"
             }, []}} =
             EventMessageTexts.parse(
               character_string: "OffNormal",
               character_string: "Fault",
               character_string: "Normal"
             )
  end

  test "decode invalid texts" do
    assert {:error, :invalid_tags} =
             EventMessageTexts.parse(
               character_string: "OffNormal",
               character_string: "Fault"
             )
  end

  test "encode texts" do
    assert {:ok,
            [
              character_string: "OffNormal",
              character_string: "Fault",
              character_string: "Normal"
            ]} =
             EventMessageTexts.encode(%EventMessageTexts{
               to_offnormal: "OffNormal",
               to_fault: "Fault",
               to_normal: "Normal"
             })
  end

  test "valid texts" do
    assert true ==
             EventMessageTexts.valid?(%EventMessageTexts{
               to_offnormal: "OffNormal",
               to_fault: "Fault",
               to_normal: "Normal"
             })
  end

  test "invalid texts" do
    assert false ==
             EventMessageTexts.valid?(%EventMessageTexts{
               to_offnormal: :hello,
               to_fault: "Fault",
               to_normal: "Normal"
             })

    assert false ==
             EventMessageTexts.valid?(%EventMessageTexts{
               to_offnormal: "OffNormal",
               to_fault: :hello,
               to_normal: "Normal"
             })

    assert false ==
             EventMessageTexts.valid?(%EventMessageTexts{
               to_offnormal: "OffNormal",
               to_fault: "Fault",
               to_normal: :hello
             })
  end
end
