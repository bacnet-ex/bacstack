defmodule BACnet.Test.Protocol.APDUDecodingTest do
  alias BACnet.Protocol.APDU

  use ExUnit.Case, async: true

  @moduletag :apdu

  test "decoding confirmed service request" do
    # Confirmed-Service-Request
    # max segments = unspecified
    # max apdu accepted = up to 480 octets (arcnet frame)
    # invoke id = 35
    # no segmentation
    # service = write property
    # params = Object Identifier (AV-0), Property Identifier (Present Value), Value (real 100.0), Priority (10)

    assert {:ok,
            %APDU.ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 480,
              max_segments: :unspecified,
              invoke_id: 35,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :write_property,
              parameters: [
                tagged: {0, <<0, 128, 0, 0>>, 4},
                tagged: {1, "U", 1},
                constructed: {3, {:real, 100.0}, 0},
                tagged: {4, "\n", 1}
              ]
            }} =
             APDU.decode_confirmed_request(
               <<2, 3, 35, 15, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 73, 10>>
             )
  end

  test "decoding segmented confirmed service request" do
    # Segmented Confirmed-Service-Request
    # invoke id = 1
    # segmentation (sequence num = 0, window size = 8, no more follows)

    assert {
             :incomplete,
             %BACnet.Protocol.IncompleteAPDU{
               header: <<2, 1, 12>>,
               server: true,
               invoke_id: 1,
               sequence_number: 0,
               window_size: 8,
               more_follows: false,
               data:
                 <<145, 0, 117, 11, 0, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100, 101,
                   6, 0, 0, 42, 0, 12, 0>>
             }
           } =
             APDU.decode_confirmed_request(
               <<10, 117, 1, 0, 8, 12, 145, 0, 117, 11, 0, 104, 101, 108, 108, 111, 32, 119, 111,
                 114, 108, 100, 101, 6, 0, 0, 42, 0, 12, 0>>
             )
  end

  test "decoding invalid segmented confirmed service request" do
    assert {:error, :invalid_apdu_data} = APDU.decode_confirmed_request(<<10, 117>>)
  end

  test "decoding invalid segmented confirmed service request with empty APDU data" do
    assert {:error, :invalid_apdu_confirmed_request_data} =
             APDU.decode_confirmed_request(<<10>>)
  end

  test "decoding confirmed service request with empty APDU data" do
    assert {:error, :invalid_apdu_confirmed_request_data} = APDU.decode_confirmed_request(<<0>>)
  end

  test "decoding confirmed service request with wrong APDU data" do
    assert {:error, :invalid_apdu_data} = APDU.decode_confirmed_request(<<0, 0, 4>>)
  end

  test "decoding confirmed service request all possible max APDU" do
    assert {:ok, %APDU.ConfirmedServiceRequest{max_apdu: 50}} =
             APDU.decode_confirmed_request(<<2, 0, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_apdu: 128}} =
             APDU.decode_confirmed_request(<<2, 1, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_apdu: 206}} =
             APDU.decode_confirmed_request(<<2, 2, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_apdu: 480}} =
             APDU.decode_confirmed_request(<<2, 3, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_apdu: 1024}} =
             APDU.decode_confirmed_request(<<2, 4, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_apdu: 1476}} =
             APDU.decode_confirmed_request(<<2, 5, 0, 15>>)
  end

  test "decoding confirmed service request all possible max segments" do
    assert {:ok, %APDU.ConfirmedServiceRequest{max_segments: :unspecified}} =
             APDU.decode_confirmed_request(<<2, 0, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_segments: :unspecified}} =
             APDU.decode_confirmed_request(<<2, 5, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_segments: 2}} =
             APDU.decode_confirmed_request(<<2, 16, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_segments: 4}} =
             APDU.decode_confirmed_request(<<2, 32, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_segments: 8}} =
             APDU.decode_confirmed_request(<<2, 48, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_segments: 16}} =
             APDU.decode_confirmed_request(<<2, 64, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_segments: 32}} =
             APDU.decode_confirmed_request(<<2, 80, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_segments: 64}} =
             APDU.decode_confirmed_request(<<2, 96, 0, 15>>)

    assert {:ok, %APDU.ConfirmedServiceRequest{max_segments: :more_than_64}} =
             APDU.decode_confirmed_request(<<2, 112, 0, 15>>)
  end

  test "decoding unconfirmed service request" do
    # Unconfirmed-Service-Request
    # service = who has
    # params = Object Name (file 106) (with character string encoding = \0)

    assert {:ok,
            %APDU.UnconfirmedServiceRequest{
              parameters: [tagged: {3, "\0file106", 8}],
              service: :who_has
            }} =
             APDU.decode_unconfirmed_request(<<16, 7, 61, 8, 0, 102, 105, 108, 101, 49, 48, 54>>)
  end

  test "decoding unconfirmed service request with empty APDU data" do
    assert {:error, :invalid_apdu_unconfirmed_request_data} =
             APDU.decode_unconfirmed_request(<<1::size(4), 0::size(4)>>)
  end

  test "decoding unconfirmed service request with wrong APDU data" do
    assert {:error, :insufficient_tag_value_data} =
             APDU.decode_unconfirmed_request(<<1::size(4), 0::size(4), 0, 4>>)
  end

  test "decoding simple ACK" do
    # Simple-ACK
    # invoke id = 70
    # service = write property

    assert {:ok,
            %APDU.SimpleACK{
              service: :write_property,
              invoke_id: 70
            }} =
             APDU.decode_simple_ack(<<32, 70, 15>>)
  end

  test "decoding simple ACK with wrong APDU data" do
    assert {:error, :invalid_apdu_simple_ack_data} =
             APDU.decode_simple_ack(<<2::size(4), 0::size(4), 0>>)
  end

  test "decoding complex ACK" do
    # Complex-ACK
    # invoke id = 70
    # no segmentation
    # service = atomic write file
    # params = file start position (440)

    assert {:ok,
            %APDU.ComplexACK{
              invoke_id: 70,
              service: :atomic_write_file,
              payload: [tagged: {0, <<1, 184>>, 2}],
              proposed_window_size: nil,
              sequence_number: nil
            }} =
             APDU.decode_complex_ack(<<48, 70, 7, 10, 1, 184>>)
  end

  test "decoding segmented complex ACK" do
    # Complex-ACK
    # invoke id = 70
    # segmentation (sequence num = 0, window size = 8, no more follows)

    assert {
             :incomplete,
             %BACnet.Protocol.IncompleteAPDU{
               invoke_id: 70,
               sequence_number: 0,
               data:
                 <<145, 0, 117, 11, 0, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100, 101,
                   6, 0, 0, 42, 0, 12, 0>>,
               header: <<48, 70, 12>>,
               more_follows: false,
               server: false,
               window_size: 8
             }
           } =
             APDU.decode_complex_ack(
               <<56, 70, 0, 8, 12, 145, 0, 117, 11, 0, 104, 101, 108, 108, 111, 32, 119, 111, 114,
                 108, 100, 101, 6, 0, 0, 42, 0, 12, 0>>
             )
  end

  test "decoding invalid segmented complex ACK" do
    assert {:error, :invalid_apdu_data} = APDU.decode_complex_ack(<<56, 70>>)
  end

  test "decoding complex with empty APDU data" do
    assert {:error, :invalid_apdu_data} = APDU.decode_complex_ack(<<3::size(4), 0::size(4), 0>>)
  end

  test "decoding segment ACK" do
    # Segment-ACK
    # negative ACK = false
    # sent by server = true
    # invoke id = 70
    # sequence number = 2
    # actual window size = 16

    assert {:ok,
            %APDU.SegmentACK{
              negative_ack: false,
              sent_by_server: true,
              invoke_id: 70,
              sequence_number: 2,
              actual_window_size: 16
            }} =
             APDU.decode_segment_ack(<<65, 70, 2, 16>>)
  end

  test "decoding segment ACK with wrong APDU data" do
    assert {:error, :invalid_apdu_segment_ack_data} =
             APDU.decode_segment_ack(<<4::size(4), 0::size(4), 0>>)
  end

  test "decoding abort" do
    # Abort
    # sent by server = true
    # invoke id = 70
    # reason = application exceeded reply time

    assert {:ok,
            %APDU.Abort{
              sent_by_server: true,
              invoke_id: 70,
              reason: :application_exceeded_reply_time
            }} =
             APDU.decode_abort(<<113, 70, 8>>)
  end

  test "decoding abort with wrong APDU data" do
    assert {:error, :invalid_apdu_abort_data} = APDU.decode_abort(<<7::size(4), 0::size(4), 0>>)
  end

  test "decoding error" do
    # Error
    # service = confirmed private transfer
    # invoke id = 2
    # class = services
    # code = password failure
    # payload = vendor id (332), service number (0), error params

    assert {:ok,
            %APDU.Error{
              class: :services,
              code: :password_failure,
              invoke_id: 2,
              payload: [
                tagged: {1, <<1, 76>>, 2},
                tagged: {2, <<0>>, 1},
                constructed: {3, {:octet_string, <<11, 22>>}, 0}
              ],
              service: :confirmed_private_transfer
            }} =
             APDU.decode_error(
               <<80, 2, 18, 14, 145, 5, 145, 26, 15, 26, 1, 76, 41, 0, 62, 98, 11, 22, 63>>
             )
  end

  test "decoding error with unknown service/class/code" do
    # Error
    # invoke id = 2

    assert {:ok,
            %APDU.Error{
              class: 254,
              code: 253,
              invoke_id: 2,
              payload: [],
              service: 255
            }} =
             APDU.decode_error(<<80, 2, 255, 14, 145, 254, 145, 253, 15>>)
  end

  test "decoding error with invalid constructed encoding" do
    # Error
    # invoke id = 2

    assert {:error, :unknown_tag_encoding} =
             APDU.decode_error(<<80, 2, 18, 14, 0, 15>>)
  end

  test "decoding error with wrong APDU data" do
    assert {:error, :invalid_apdu_error_data} = APDU.decode_error(<<5::size(4), 0::size(4), 0>>)
  end

  test "decoding error without error data" do
    assert {:error, :unknown_tag_encoding} = APDU.decode_error(<<5::size(4), 0::size(4), 0, 4>>)
  end

  test "decoding reject" do
    # Reject
    # invoke id = 70
    # reason = buffer overflow

    assert {:ok,
            %APDU.Reject{
              invoke_id: 70,
              reason: :buffer_overflow
            }} =
             APDU.decode_reject(<<96, 70, 1>>)
  end

  test "decoding reject with wrong APDU data" do
    assert {:error, :invalid_apdu_reject_data} = APDU.decode_reject(<<6::size(4), 0::size(4), 0>>)
  end
end
