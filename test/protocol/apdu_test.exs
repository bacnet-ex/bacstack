defmodule BACnet.Test.Protocol.APDUTest do
  alias BACnet.Protocol.APDU

  use ExUnit.Case, async: true

  @moduletag :apdu

  doctest APDU

  test "decoding BACnet APDU Confirmed-Service-Request" do
    assert {:ok, %APDU.ConfirmedServiceRequest{}} =
             APDU.decode(
               <<2, 3, 35, 15, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 73, 10>>
             )
  end

  test "decoding BACnet APDU Unconfirmed-Service-Request" do
    assert {:ok, %APDU.UnconfirmedServiceRequest{}} =
             APDU.decode(<<16, 7, 61, 8, 0, 102, 105, 108, 101, 49, 48, 54>>)
  end

  test "decoding BACnet APDU Simple-ACK" do
    assert {:ok, %APDU.SimpleACK{}} =
             APDU.decode(<<32, 70, 15>>)
  end

  test "decoding BACnet APDU Complex-ACK" do
    assert {:ok, %APDU.ComplexACK{}} =
             APDU.decode(<<48, 70, 7, 10, 1, 184>>)
  end

  test "decoding BACnet APDU Segment-ACK" do
    assert {:ok, %APDU.SegmentACK{}} =
             APDU.decode(<<65, 70, 2, 16>>)
  end

  test "decoding BACnet APDU Abort" do
    assert {:ok, %APDU.Abort{}} =
             APDU.decode(<<113, 70, 8>>)
  end

  test "decoding BACnet APDU Error" do
    assert {:ok, %APDU.Error{}} =
             APDU.decode(
               <<80, 2, 18, 14, 145, 5, 145, 26, 15, 26, 1, 76, 41, 0, 62, 98, 11, 22, 63>>
             )
  end

  test "decoding BACnet APDU Reject" do
    assert {:ok, %APDU.Reject{}} =
             APDU.decode(<<96, 70, 1>>)
  end

  test "decoding BACnet APDU failure" do
    assert {:error, :invalid_apdu_type} = APDU.decode(<<255>>)
  end

  test "decoding BACnet APDU insufficient data" do
    assert {:error, :insufficient_apdu_data} = APDU.decode(<<>>)
  end

  test "get raw APDU invoke ID fails on empty binary" do
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<>>)
  end

  test "get raw APDU invoke ID fails on unknown APDU type" do
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<255, 70, 55, 52, 33>>)
  end

  test "get raw APDU invoke ID from Confirmed Service Request" do
    assert {:ok, 35} =
             APDU.get_invoke_id_from_raw_apdu(
               <<2, 3, 35, 15, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 73, 10>>
             )
  end

  test "get raw APDU invoke ID from segmented Confirmed Service Request" do
    assert {:ok, 1} =
             APDU.get_invoke_id_from_raw_apdu(
               <<10, 117, 1, 0, 8, 12, 145, 0, 117, 11, 0, 104, 101, 108, 108, 111, 32, 119, 111,
                 114, 108, 100, 101, 6, 0, 0, 42, 0, 12, 0>>
             )
  end

  test "get raw APDU invoke ID fails due to invalid Confirmed Service Request" do
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<2, 3>>)
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<10, 117>>)
  end

  test "get raw APDU invoke ID fails for Unconfirmed Service Request" do
    assert {:error, :invalid_apdu} =
             APDU.get_invoke_id_from_raw_apdu(<<16, 7, 61, 8, 0, 102, 105, 108, 101, 49, 48, 54>>)
  end

  test "get raw APDU invoke ID from Complex ACK" do
    assert {:ok, 70} = APDU.get_invoke_id_from_raw_apdu(<<48, 70, 7, 10, 1, 184>>)
  end

  test "get raw APDU invoke ID from segmented Complex ACK" do
    assert {:ok, 70} =
             APDU.get_invoke_id_from_raw_apdu(
               <<56, 70, 0, 8, 12, 145, 0, 117, 11, 0, 104, 101, 108, 108, 111, 32, 119, 111, 114,
                 108, 100, 101, 6, 0, 0, 42, 0, 12, 0>>
             )
  end

  test "get raw APDU invoke ID fails due to invalid Complex ACK" do
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<48>>)
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<56>>)
  end

  test "get raw APDU invoke ID from Simple ACK" do
    assert {:ok, 70} = APDU.get_invoke_id_from_raw_apdu(<<32, 70, 15>>)
  end

  test "get raw APDU invoke ID fails due to invalid Simple ACK" do
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<32>>)
  end

  test "get raw APDU invoke ID from Segment ACK" do
    assert {:ok, 70} = APDU.get_invoke_id_from_raw_apdu(<<65, 70, 2, 16>>)
  end

  test "get raw APDU invoke ID fails due to invalid Segment ACK" do
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<65>>)
  end

  test "get raw APDU invoke ID from Abort" do
    assert {:ok, 70} = APDU.get_invoke_id_from_raw_apdu(<<113, 70, 8>>)
  end

  test "get raw APDU invoke ID fails due to invalid Abort" do
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<113>>)
  end

  test "get raw APDU invoke ID from Error" do
    assert {:ok, 2} =
             APDU.get_invoke_id_from_raw_apdu(
               <<80, 2, 18, 14, 145, 5, 145, 26, 15, 26, 1, 76, 41, 0, 62, 98, 11, 22, 63>>
             )
  end

  test "get raw APDU invoke ID fails due to invalid Error" do
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<80>>)
  end

  test "get raw APDU invoke ID from Reject" do
    assert {:ok, 70} = APDU.get_invoke_id_from_raw_apdu(<<96, 70, 1>>)
  end

  test "get raw APDU invoke ID fails due to invalid Reject" do
    assert {:error, :invalid_apdu} = APDU.get_invoke_id_from_raw_apdu(<<96>>)
  end
end
