defmodule BACnet.Protocol.NotificationClassPriorityTest do
  alias BACnet.Protocol.NotificationClassPriority

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest NotificationClassPriority

  test "decode nc priorities" do
    assert {:ok,
            {%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 6,
               to_normal: 7
             }, []}} =
             NotificationClassPriority.parse(
               unsigned_integer: 5,
               unsigned_integer: 6,
               unsigned_integer: 7
             )
  end

  test "decode invalid nc priorities missing pattern" do
    assert {:error, :invalid_tags} = NotificationClassPriority.parse(unsigned_integer: 5)
  end

  test "decode invalid nc priorities invalid to_offnormal" do
    assert {:error, :invalid_tags} =
             NotificationClassPriority.parse(
               unsigned_integer: 256,
               unsigned_integer: 255,
               unsigned_integer: 255
             )
  end

  test "decode invalid nc priorities invalid to_fault" do
    assert {:error, :invalid_tags} =
             NotificationClassPriority.parse(
               unsigned_integer: 255,
               unsigned_integer: 256,
               unsigned_integer: 255
             )
  end

  test "decode invalid nc priorities invalid to_normal" do
    assert {:error, :invalid_tags} =
             NotificationClassPriority.parse(
               unsigned_integer: 255,
               unsigned_integer: 255,
               unsigned_integer: 256
             )
  end

  test "encode nc priorities" do
    assert {:ok,
            [
              unsigned_integer: 5,
              unsigned_integer: 6,
              unsigned_integer: 7
            ]} =
             NotificationClassPriority.encode(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 6,
               to_normal: 7
             })
  end

  test "valid nc priorities" do
    assert true ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 6,
               to_normal: 7
             })

    assert true ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 0,
               to_fault: 6,
               to_normal: 7
             })

    assert true ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 0,
               to_normal: 7
             })

    assert true ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 6,
               to_normal: 0
             })

    assert true ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 255,
               to_fault: 6,
               to_normal: 7
             })

    assert true ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 255,
               to_normal: 7
             })

    assert true ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 6,
               to_normal: 255
             })
  end

  test "invalid nc priorities" do
    assert false ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: :hello,
               to_fault: 6,
               to_normal: 7
             })

    assert false ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: :hello,
               to_normal: 7
             })

    assert false ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 6,
               to_normal: :hello
             })

    assert false ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: -1,
               to_fault: 6,
               to_normal: 7
             })

    assert false ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: -1,
               to_normal: 7
             })

    assert false ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 6,
               to_normal: -1
             })

    assert false ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 256,
               to_fault: 6,
               to_normal: 7
             })

    assert false ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 256,
               to_normal: 7
             })

    assert false ==
             NotificationClassPriority.valid?(%NotificationClassPriority{
               to_offnormal: 5,
               to_fault: 6,
               to_normal: 256
             })
  end
end
