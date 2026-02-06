defmodule BACnet.Protocol.LogStatusTest do
  alias BACnet.Protocol.LogStatus

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest LogStatus

  test "decode log status" do
    assert {:ok,
            {%LogStatus{
               log_disabled: true,
               buffer_purged: false,
               log_interrupted: false
             }, []}} = LogStatus.parse(bitstring: {true, false, false})
  end

  test "decode log status 2" do
    assert {:ok,
            {%LogStatus{
               log_disabled: false,
               buffer_purged: true,
               log_interrupted: false
             }, []}} = LogStatus.parse(bitstring: {false, true, false})
  end

  test "decode log status 3" do
    assert {:ok,
            {%LogStatus{
               log_disabled: false,
               buffer_purged: false,
               log_interrupted: true
             }, []}} = LogStatus.parse(bitstring: {false, false, true})
  end

  test "decode log status 4 (backwards compatibility)" do
    assert {:ok,
            {%LogStatus{
               log_disabled: true,
               buffer_purged: true,
               log_interrupted: false
             }, []}} = LogStatus.parse(bitstring: {true, true})
  end

  test "decode invalid log status" do
    assert {:error, :invalid_tags} = LogStatus.parse([])
  end

  test "encode log status" do
    assert {:ok, [bitstring: {true, false, false}]} =
             LogStatus.encode(%LogStatus{
               log_disabled: true,
               buffer_purged: false,
               log_interrupted: false
             })
  end

  test "encode log status 2" do
    assert {:ok, [bitstring: {false, true, false}]} =
             LogStatus.encode(%LogStatus{
               log_disabled: false,
               buffer_purged: true,
               log_interrupted: false
             })
  end

  test "encode log status 3" do
    assert {:ok, [bitstring: {false, false, true}]} =
             LogStatus.encode(%LogStatus{
               log_disabled: false,
               buffer_purged: false,
               log_interrupted: true
             })
  end

  test "from bitstring log status" do
    assert %LogStatus{
             log_disabled: true,
             buffer_purged: true,
             log_interrupted: true
           } = LogStatus.from_bitstring({true, true, true})
  end

  test "from bitstring log status (backwards compatibility)" do
    assert %LogStatus{
             log_disabled: true,
             buffer_purged: true,
             log_interrupted: false
           } = LogStatus.from_bitstring({true, true})
  end

  test "from bitstring log status wrong bitstring" do
    assert_raise FunctionClauseError, fn ->
      LogStatus.from_bitstring({true, true, true, true})
    end
  end

  test "to bitstring log status" do
    assert {:bitstring, {true, true, true}} =
             LogStatus.to_bitstring(%LogStatus{
               log_disabled: true,
               buffer_purged: true,
               log_interrupted: true
             })
  end

  test "valid log status" do
    assert true ==
             LogStatus.valid?(%LogStatus{
               log_disabled: true,
               buffer_purged: true,
               log_interrupted: true
             })

    assert true ==
             LogStatus.valid?(%LogStatus{
               log_disabled: false,
               buffer_purged: false,
               log_interrupted: false
             })
  end

  test "invalid log status" do
    assert false ==
             LogStatus.valid?(%LogStatus{
               log_disabled: :hello,
               buffer_purged: true,
               log_interrupted: true
             })

    assert false ==
             LogStatus.valid?(%LogStatus{
               log_disabled: true,
               buffer_purged: :hello,
               log_interrupted: true
             })

    assert false ==
             LogStatus.valid?(%LogStatus{
               log_disabled: true,
               buffer_purged: true,
               log_interrupted: :hello
             })
  end
end
