defmodule BACnet.Protocol.EventPrioritiesTest do
  alias BACnet.Protocol.EventPriorities

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest EventPriorities

  test "decode priorities and preserve remaining tags" do
    assert {:ok,
            {%EventPriorities{to_offnormal: 0, to_fault: 15, to_normal: 255}, [boolean: true]}} =
             EventPriorities.parse(
               unsigned_integer: 0,
               unsigned_integer: 15,
               unsigned_integer: 255,
               boolean: true
             )
  end

  test "decode invalid priority tags" do
    for tags <- [[], [unsigned_integer: 5], [unsigned_integer: 5, unsigned_integer: 6]] do
      assert {:error, :invalid_tags} = EventPriorities.parse(tags)
    end

    for position <- 0..2, invalid <- [-1, 256, 1.0, :hello, "15"] do
      tags =
        List.replace_at(
          [unsigned_integer: 5, unsigned_integer: 6, unsigned_integer: 7],
          position,
          {:unsigned_integer, invalid}
        )

      assert {:error, :invalid_tags} = EventPriorities.parse(tags)
    end

    assert {:error, :invalid_tags} =
             EventPriorities.parse(enumerated: 5, unsigned_integer: 6, unsigned_integer: 7)
  end

  test "encode priorities in transition order" do
    assert {:ok, [unsigned_integer: 0, unsigned_integer: 15, unsigned_integer: 255]} =
             EventPriorities.encode(%EventPriorities{
               to_offnormal: 0,
               to_fault: 15,
               to_normal: 255
             })
  end

  test "validate byte values for every transition" do
    priorities = %EventPriorities{to_offnormal: 5, to_fault: 6, to_normal: 7}

    for field <- [:to_offnormal, :to_fault, :to_normal] do
      for valid <- [0, 15, 255] do
        assert EventPriorities.valid?(Map.put(priorities, field, valid))
      end

      for invalid <- [-1, 256, 1.0, :hello, "15", nil] do
        refute EventPriorities.valid?(Map.put(priorities, field, invalid))
      end
    end
  end

  test "all transition keys are required" do
    fields = [to_offnormal: 5, to_fault: 6, to_normal: 7]

    for field <- Keyword.keys(fields) do
      assert_raise ArgumentError, fn ->
        struct!(EventPriorities, Keyword.delete(fields, field))
      end
    end
  end
end
