defmodule BACnet.Test.Protocol.APDUEncodingTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.Constants.ConstantError
  alias BACnet.Stack.EncoderProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu

  test "encoding confirmed service request" do
    assert {:ok, <<2, 5, 35, 15, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 73, 10>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
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
             })
  end

  test "encoding confirmed service request 2" do
    assert {:ok, <<2, 99, 35, 15, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 73, 10>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: 64,
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
             })
  end

  test "encoding confirmed service request 3 (service as number)" do
    assert {:ok, <<2, 99, 35, 15, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 73, 10>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: 64,
               invoke_id: 35,
               sequence_number: nil,
               proposed_window_size: nil,
               service: 15,
               parameters: [
                 tagged: {0, <<0, 128, 0, 0>>, 4},
                 tagged: {1, "U", 1},
                 constructed: {3, {:real, 100.0}, 0},
                 tagged: {4, "\n", 1}
               ]
             })
  end

  @tag :encoder_protocol
  test "encoding confirmed service request 4" do
    assert <<2, 112, 35, 15, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 73, 10>> =
             EncoderProtocol.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: :more_than_64,
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
             })
  end

  @tag :encoder_protocol
  test "encoding confirmed service request segmented" do
    assert [
             <<14, 112, 35, 0, 16, 15, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 12, 0,
               0, 8, 72, 30, 9, 85>>,
             <<14, 112, 35, 1, 16, 15, 31, 12, 0, 0, 8, 73, 30, 9, 85, 31, 12, 0, 0, 8, 74, 30, 9,
               85, 31, 12, 0, 0>>,
             <<14, 112, 35, 2, 16, 15, 8, 75, 30, 9, 85, 31, 12, 0, 0, 8, 76, 30, 9, 85, 31, 12,
               0, 0, 8, 77, 30, 9>>,
             <<14, 112, 35, 3, 16, 15, 85, 31, 12, 0, 0, 8, 78, 30, 9, 85, 31, 12, 0, 0, 8, 79,
               30, 9, 85, 31, 12, 0>>,
             <<14, 112, 35, 4, 16, 15, 0, 8, 80, 30, 9, 85, 31, 12, 0, 0, 8, 81, 30, 9, 85, 31,
               12, 0, 0, 8, 82, 30>>,
             <<14, 112, 35, 5, 16, 15, 9, 85, 31, 12, 0, 0, 8, 83, 30, 9, 85, 31, 12, 0, 0, 8, 84,
               30, 9, 85, 31, 30>>,
             <<14, 112, 35, 6, 16, 15, 9, 85, 31, 12, 0, 0, 8, 54, 30, 9, 85, 31, 12, 0, 0, 8, 55,
               30, 9, 85, 31, 12>>,
             <<14, 112, 35, 7, 16, 15, 0, 0, 8, 56, 30, 9, 85, 31, 12, 0, 0, 8, 57, 30, 9, 85, 31,
               12, 0, 0, 8, 58>>,
             <<10, 112, 35, 8, 16, 15, 30, 9, 85, 31, 12, 0, 0, 8, 59, 30, 9, 85, 31>>
           ] =
             EncoderProtocol.encode_segmented(
               %APDU.ConfirmedServiceRequest{
                 segmented_response_accepted: true,
                 max_apdu: 50,
                 max_segments: :more_than_64,
                 invoke_id: 35,
                 sequence_number: 1,
                 proposed_window_size: 16,
                 service: :write_property,
                 parameters: [
                   tagged: {0, <<0, 128, 0, 0>>, 4},
                   tagged: {1, "U", 1},
                   constructed: {3, {:real, 100.0}, 0},
                   tagged: {0, <<0, 0, 8, 72>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 73>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 74>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 75>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 76>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 77>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 78>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 79>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 80>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 81>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 82>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 83>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 84>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 54>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 55>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 56>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 57>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 58>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 59>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0}
                 ]
               },
               22
             )
  end

  @tag :encoder_protocol
  test "encoding confirmed service request segmented 2" do
    assert [
             <<14, 113, 35, 0, 16, 15, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 12, 0,
               0, 8, 72, 30, 9, 85, 31, 12, 0, 0, 8, 73, 30, 9, 85, 31, 12, 0, 0, 8, 74, 30, 9,
               85, 31, 12, 0, 0, 8, 75, 30, 9, 85, 31, 12, 0, 0, 8, 76, 30, 9, 85, 31, 12, 0, 0,
               8, 77, 30, 9, 85, 31, 12, 0, 0, 8, 78, 30, 9, 85, 31, 12, 0, 0, 8, 79, 30, 9, 85,
               31, 12, 0, 0, 8, 80, 30, 9, 85, 31, 12, 0, 0, 8, 81>>,
             <<10, 113, 35, 1, 16, 15, 30, 9, 85, 31, 12, 0, 0, 8, 82, 30, 9, 85, 31, 12, 0, 0, 8,
               83, 30, 9, 85, 31, 12, 0, 0, 8, 84, 30, 9, 85, 31, 30, 9, 85, 31, 12, 0, 0, 8, 54,
               30, 9, 85, 31, 12, 0, 0, 8, 55, 30, 9, 85, 31, 12, 0, 0, 8, 56, 30, 9, 85, 31, 12,
               0, 0, 8, 57, 30, 9, 85, 31, 12, 0, 0, 8, 58, 30, 9, 85, 31, 12, 0, 0, 8, 59, 30, 9,
               85, 31>>
           ] =
             EncoderProtocol.encode_segmented(
               %APDU.ConfirmedServiceRequest{
                 segmented_response_accepted: true,
                 max_apdu: 128,
                 max_segments: :more_than_64,
                 invoke_id: 35,
                 sequence_number: 1,
                 proposed_window_size: 16,
                 service: :write_property,
                 parameters: [
                   tagged: {0, <<0, 128, 0, 0>>, 4},
                   tagged: {1, "U", 1},
                   constructed: {3, {:real, 100.0}, 0},
                   tagged: {0, <<0, 0, 8, 72>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 73>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 74>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 75>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 76>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 77>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 78>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 79>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 80>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 81>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 82>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 83>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 84>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 54>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 55>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 56>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 57>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 58>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 59>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0}
                 ]
               },
               100
             )
  end

  @tag :encoder_protocol
  test "encoding confirmed service request segmented no payload (ignores segmentation)" do
    assert [<<2, 112, 35, 15>>] =
             EncoderProtocol.encode_segmented(
               %APDU.ConfirmedServiceRequest{
                 segmented_response_accepted: true,
                 max_apdu: 50,
                 max_segments: :more_than_64,
                 invoke_id: 35,
                 sequence_number: 1,
                 proposed_window_size: 16,
                 service: :write_property,
                 parameters: []
               },
               50
             )
  end

  test "encoding invalid confirmed service request" do
    assert {
             :error,
             %RuntimeError{
               message:
                 "Unable to encode parameters in confirmed service request encode, error: :invalid_value"
             }
           } =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 35,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: [{:signed_integer, false}]
             })
  end

  test "encoding invalid confirmed service request 2" do
    assert {:error,
            %ArgumentError{message: "Invoke ID must be between 0 and 255 inclusive, got: 256"}} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 256,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: [{:signed_integer, false}]
             })
  end

  test "encoding invalid confirmed service request 3" do
    assert {:error,
            %ArgumentError{
              message: "Sequence number must be nil or between 0 and 255 inclusive, got: 256"
            }} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 35,
               sequence_number: 256,
               proposed_window_size: 1,
               service: :write_property,
               parameters: []
             })
  end

  test "encoding invalid confirmed service request 4" do
    assert {:error,
            %ArgumentError{
              message: "Proposed window size must be nil or between 0 and 255 inclusive, got: 256"
            }} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 35,
               sequence_number: 1,
               proposed_window_size: 256,
               service: :write_property,
               parameters: []
             })
  end

  test "encoding invalid confirmed service request 5" do
    assert {:error,
            %ArgumentError{
              message:
                "Sequence number and proposed window size must both be nil or an integer (same data type)"
            }} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 35,
               sequence_number: nil,
               proposed_window_size: 1,
               service: :write_property,
               parameters: []
             })

    assert {:error,
            %ArgumentError{
              message:
                "Sequence number and proposed window size must both be nil or an integer (same data type)"
            }} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 35,
               sequence_number: 1,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })
  end

  test "encoding invalid confirmed service request 6" do
    assert {:error, %{__exception__: true}} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 555,
               max_segments: :unspecified,
               invoke_id: 35,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })
  end

  @tag :encoder_protocol
  test "encoding invalid confirmed service request 7 (encoder protocol)" do
    assert_raise RuntimeError, fn ->
      EncoderProtocol.encode(%APDU.ConfirmedServiceRequest{
        segmented_response_accepted: true,
        max_apdu: 480,
        max_segments: :unspecified,
        invoke_id: 35,
        sequence_number: nil,
        proposed_window_size: nil,
        service: :write_property,
        parameters: [{:signed_integer, false}]
      })
    end
  end

  test "encoding confirmed service request with invalid constructed encoding" do
    assert {:error,
            %RuntimeError{
              message:
                "Unable to encode parameters in confirmed service request encode, error: :invalid_value"
            }} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 35,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: [{:constructed, {0, nil, 0}}]
             })
  end

  @tag :encoder_protocol
  test "encoder protocol supports segmentation for confirmed service request" do
    assert true ===
             EncoderProtocol.supports_segmentation(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 35,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })
  end

  test "encoding confirmed service request all possible max APDU" do
    assert {:ok, <<2, 0, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: :unspecified,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 1, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 128,
               max_segments: :unspecified,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 2, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 206,
               max_segments: :unspecified,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 3, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 4, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1024,
               max_segments: :unspecified,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 5, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: :unspecified,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })
  end

  test "encoding confirmed service request all possible max segments" do
    assert {:ok, <<2, 0, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: :unspecified,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 16, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: 2,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 32, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: 4,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 48, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: 8,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 64, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: 16,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 80, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: 32,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 96, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: 64,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })

    assert {:ok, <<2, 112, 0, 15>>} =
             APDU.ConfirmedServiceRequest.encode(%APDU.ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 50,
               max_segments: :more_than_64,
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })
  end

  test "encoding unconfirmed service request" do
    assert {:ok, <<16, 7, 61, 8, 0, 102, 105, 108, 101, 49, 48, 54>>} =
             APDU.UnconfirmedServiceRequest.encode(%APDU.UnconfirmedServiceRequest{
               parameters: [tagged: {3, "\0file106", 8}],
               service: :who_has
             })
  end

  test "encoding unconfirmed service request 2 (service as number)" do
    assert {:ok, <<16, 7, 61, 8, 0, 102, 105, 108, 101, 49, 48, 54>>} =
             APDU.UnconfirmedServiceRequest.encode(%APDU.UnconfirmedServiceRequest{
               parameters: [tagged: {3, "\0file106", 8}],
               service: 7
             })
  end

  @tag :encoder_protocol
  test "encoding unconfirmed service request 3 (encoder protocol)" do
    assert <<16, 7, 61, 8, 0, 102, 105, 108, 101, 49, 48, 54>> =
             EncoderProtocol.encode(%APDU.UnconfirmedServiceRequest{
               parameters: [tagged: {3, "\0file106", 8}],
               service: :who_has
             })
  end

  test "encoding invalid unconfirmed service request" do
    assert {:error, %ConstantError{}} =
             APDU.UnconfirmedServiceRequest.encode(%APDU.UnconfirmedServiceRequest{
               parameters: [],
               service: :write_property
             })
  end

  @tag :encoder_protocol
  test "encoding invalid unconfirmed service request 2 (encoder protocol)" do
    assert_raise RuntimeError, fn ->
      EncoderProtocol.encode(%APDU.UnconfirmedServiceRequest{
        parameters: [{:unsigned_integer, nil}],
        service: :i_am
      })
    end
  end

  test "encoding unconfirmed service request with invalid constructed encoding" do
    assert {:error,
            %RuntimeError{
              message:
                "Unable to encode parameters in unconfirmed service request encode, error: :invalid_value"
            }} =
             APDU.UnconfirmedServiceRequest.encode(%APDU.UnconfirmedServiceRequest{
               parameters: [{:constructed, {0, nil, 0}}],
               service: :i_am
             })
  end

  @tag :encoder_protocol
  test "encoder protocol supports no segmentation for unconfirmed service request" do
    assert false ===
             EncoderProtocol.supports_segmentation(%APDU.UnconfirmedServiceRequest{
               parameters: [],
               service: :i_am
             })
  end

  @tag :encoder_protocol
  test "encoder protocol encode segmented errors for unconfirmed service request" do
    assert_raise RuntimeError, ~r"APDU can not be segmented"i, fn ->
      EncoderProtocol.encode_segmented(
        %APDU.UnconfirmedServiceRequest{
          parameters: [],
          service: :i_am
        },
        50
      )
    end
  end

  test "encoding simple ACK" do
    assert {:ok, <<32, 70, 15>>} =
             APDU.SimpleACK.encode(%APDU.SimpleACK{
               service: :write_property,
               invoke_id: 70
             })
  end

  test "encoding simple ACK 2 (service as number)" do
    assert {:ok, <<32, 70, 15>>} =
             APDU.SimpleACK.encode(%APDU.SimpleACK{
               service: 15,
               invoke_id: 70
             })
  end

  @tag :encoder_protocol
  test "encoding simple ACK 3 (encoder protocol)" do
    assert <<32, 70, 15>> =
             EncoderProtocol.encode(%APDU.SimpleACK{
               service: :write_property,
               invoke_id: 70
             })
  end

  test "encoding invalid simple ACK" do
    assert {:error, %ConstantError{}} =
             APDU.SimpleACK.encode(%APDU.SimpleACK{
               service: :i_am,
               invoke_id: 70
             })
  end

  test "encoding invalid simple ACK 2" do
    assert {:error,
            %ArgumentError{message: "Invoke ID must be between 0 and 255 inclusive, got: 256"}} =
             APDU.SimpleACK.encode(%APDU.SimpleACK{
               service: :write_property,
               invoke_id: 256
             })
  end

  @tag :encoder_protocol
  test "encoder protocol supports no segmentation for simple ACK" do
    assert false ===
             EncoderProtocol.supports_segmentation(%APDU.SimpleACK{
               service: :write_property,
               invoke_id: 70
             })
  end

  @tag :encoder_protocol
  test "encoder protocol encode segmented errors for simple ACK" do
    assert_raise RuntimeError, ~r"APDU can not be segmented"i, fn ->
      EncoderProtocol.encode_segmented(
        %APDU.SimpleACK{
          service: :write_property,
          invoke_id: 70
        },
        50
      )
    end
  end

  test "encoding complex ACK" do
    assert {:ok, <<48, 70, 7, 10, 1, 184>>} =
             APDU.ComplexACK.encode(%APDU.ComplexACK{
               invoke_id: 70,
               service: :atomic_write_file,
               payload: [tagged: {0, <<1, 184>>, 2}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  test "encoding complex ACK 2" do
    assert {:ok, <<48, 255, 12>>} =
             APDU.ComplexACK.encode(%APDU.ComplexACK{
               invoke_id: 255,
               service: :read_property,
               payload: [],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  test "encoding complex ACK 3 (service as number)" do
    assert {:ok, <<48, 255, 12>>} =
             APDU.ComplexACK.encode(%APDU.ComplexACK{
               invoke_id: 255,
               service: 12,
               payload: [],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  @tag :encoder_protocol
  test "encoding complex ACK 4 (encoder protocol)" do
    assert <<48, 70, 7, 10, 1, 184>> =
             EncoderProtocol.encode(%APDU.ComplexACK{
               invoke_id: 70,
               service: :atomic_write_file,
               payload: [tagged: {0, <<1, 184>>, 2}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  @tag :encoder_protocol
  test "encoding complex ACK segmented" do
    assert [
             <<60, 255, 0, 16, 12, 12, 0, 128, 0, 0, 25, 85, 62, 68, 66, 200, 0, 0, 63, 12, 0, 0,
               8, 72, 30, 9, 85>>,
             <<60, 255, 1, 16, 12, 31, 12, 0, 0, 8, 73, 30, 9, 85, 31, 12, 0, 0, 8, 74, 30, 9, 85,
               31, 12, 0, 0>>,
             <<60, 255, 2, 16, 12, 8, 75, 30, 9, 85, 31, 12, 0, 0, 8, 76, 30, 9, 85, 31, 12, 0, 0,
               8, 77, 30, 9>>,
             <<60, 255, 3, 16, 12, 85, 31, 12, 0, 0, 8, 78, 30, 9, 85, 31, 12, 0, 0, 8, 79, 30, 9,
               85, 31, 12, 0>>,
             <<56, 255, 4, 16, 12, 0, 8, 80>>
           ] =
             EncoderProtocol.encode_segmented(
               %APDU.ComplexACK{
                 invoke_id: 255,
                 service: :read_property,
                 payload: [
                   tagged: {0, <<0, 128, 0, 0>>, 4},
                   tagged: {1, "U", 1},
                   constructed: {3, {:real, 100.0}, 0},
                   tagged: {0, <<0, 0, 8, 72>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 73>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 74>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 75>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 76>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 77>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 78>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 79>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 80>>, 4}
                 ],
                 proposed_window_size: 16,
                 sequence_number: 2
               },
               22
             )
  end

  @tag :encoder_protocol
  test "encoding complex ACK segmented 2" do
    assert [
             <<60, 255, 0, 16, 12, 12, 0, 128, 0>>,
             <<60, 255, 1, 16, 12, 0, 25, 85, 62>>,
             <<60, 255, 2, 16, 12, 68, 66, 200, 0>>,
             <<60, 255, 3, 16, 12, 0, 63, 12, 0>>,
             <<60, 255, 4, 16, 12, 0, 8, 72, 30>>,
             <<60, 255, 5, 16, 12, 9, 85, 31, 12>>,
             <<60, 255, 6, 16, 12, 0, 0, 8, 73>>,
             <<60, 255, 7, 16, 12, 30, 9, 85, 31>>,
             <<60, 255, 8, 16, 12, 12, 0, 0, 8>>,
             <<60, 255, 9, 16, 12, 74, 30, 9, 85>>,
             <<60, 255, 10, 16, 12, 31, 12, 0, 0>>,
             <<60, 255, 11, 16, 12, 8, 75, 30, 9>>,
             <<60, 255, 12, 16, 12, 85, 31, 12, 0>>,
             <<60, 255, 13, 16, 12, 0, 8, 76, 30>>,
             <<60, 255, 14, 16, 12, 9, 85, 31, 12>>,
             <<60, 255, 15, 16, 12, 0, 0, 8, 77>>,
             <<60, 255, 16, 16, 12, 30, 9, 85, 31>>,
             <<60, 255, 17, 16, 12, 12, 0, 0, 8>>,
             <<60, 255, 18, 16, 12, 78, 30, 9, 85>>,
             <<60, 255, 19, 16, 12, 31, 12, 0, 0>>,
             <<60, 255, 20, 16, 12, 8, 79, 30, 9>>,
             <<60, 255, 21, 16, 12, 85, 31, 12, 0>>,
             <<56, 255, 22, 16, 12, 0, 8, 80>>
           ] =
             EncoderProtocol.encode_segmented(
               %APDU.ComplexACK{
                 invoke_id: 255,
                 service: :read_property,
                 payload: [
                   tagged: {0, <<0, 128, 0, 0>>, 4},
                   tagged: {1, "U", 1},
                   constructed: {3, {:real, 100.0}, 0},
                   tagged: {0, <<0, 0, 8, 72>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 73>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 74>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 75>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 76>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 77>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 78>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 79>>, 4},
                   constructed: {1, {:tagged, {0, "U", 1}}, 0},
                   tagged: {0, <<0, 0, 8, 80>>, 4}
                 ],
                 proposed_window_size: 16,
                 sequence_number: 2
               },
               4
             )
  end

  @tag :encoder_protocol
  test "encoding complex ACK segmented no payload (ignores segmentation)" do
    assert [<<48, 255, 12>>] =
             EncoderProtocol.encode_segmented(
               %APDU.ComplexACK{
                 invoke_id: 255,
                 service: :read_property,
                 payload: [],
                 proposed_window_size: 16,
                 sequence_number: 2
               },
               50
             )
  end

  test "encoding invalid complex ACK" do
    assert {:error, %ConstantError{}} =
             APDU.ComplexACK.encode(%APDU.ComplexACK{
               invoke_id: 70,
               service: :i_am,
               payload: [],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  test "encoding invalid complex ACK 2" do
    assert {:error,
            %ArgumentError{message: "Invoke ID must be between 0 and 255 inclusive, got: 256"}} =
             APDU.ComplexACK.encode(%APDU.ComplexACK{
               invoke_id: 256,
               service: :read_property,
               payload: [],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  @tag :encoder_protocol
  test "encoding invalid complex ACK 3 (encoder protocol)" do
    assert_raise RuntimeError, fn ->
      EncoderProtocol.encode(%APDU.ComplexACK{
        invoke_id: 255,
        service: :read_property,
        payload: [{:unsigned_integer, nil}],
        proposed_window_size: nil,
        sequence_number: nil
      })
    end
  end

  test "encoding complex ACK with invalid constructed encoding" do
    assert {:error,
            %RuntimeError{
              message: "Unable to encode service ack in complex ack encode, error: :invalid_value"
            }} =
             APDU.ComplexACK.encode(%APDU.ComplexACK{
               invoke_id: 255,
               service: :read_property,
               payload: [{:constructed, {0, nil, 0}}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  @tag :encoder_protocol
  test "encoder protocol supports segmentation for complex ACK" do
    assert true ===
             EncoderProtocol.supports_segmentation(%APDU.ComplexACK{
               invoke_id: 70,
               service: :atomic_write_file,
               payload: [tagged: {0, <<1, 184>>, 2}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  test "encoding segment ACK" do
    assert {:ok, <<65, 70, 2, 16>>} =
             APDU.SegmentACK.encode(%APDU.SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 70,
               sequence_number: 2,
               actual_window_size: 16
             })
  end

  @tag :encoder_protocol
  test "encoding segment ACK 2 (encoder protocol)" do
    assert <<66, 70, 1, 36>> =
             EncoderProtocol.encode(%APDU.SegmentACK{
               negative_ack: true,
               sent_by_server: false,
               invoke_id: 70,
               sequence_number: 1,
               actual_window_size: 36
             })
  end

  test "encoding invalid segment ACK" do
    assert {:error,
            %ArgumentError{message: "Invoke ID must be between 0 and 255 inclusive, got: 256"}} =
             APDU.SegmentACK.encode(%APDU.SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 256,
               sequence_number: 2,
               actual_window_size: 16
             })
  end

  test "encoding invalid segment ACK 2" do
    assert {:error,
            %ArgumentError{
              message: "Sequence number must be between 0 and 255 inclusive, got: 256"
            }} =
             APDU.SegmentACK.encode(%APDU.SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 255,
               sequence_number: 256,
               actual_window_size: 16
             })
  end

  test "encoding invalid segment ACK 3" do
    assert {:error,
            %ArgumentError{
              message: "Actual window size must be between 0 and 255 inclusive, got: 256"
            }} =
             APDU.SegmentACK.encode(%APDU.SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 26,
               sequence_number: 2,
               actual_window_size: 256
             })
  end

  @tag :encoder_protocol
  test "encoding invalid complex ACK 4 (encoder protocol)" do
    assert_raise ArgumentError, fn ->
      EncoderProtocol.encode(%APDU.SegmentACK{
        negative_ack: false,
        sent_by_server: true,
        invoke_id: 26,
        sequence_number: 2,
        actual_window_size: 256
      })
    end
  end

  @tag :encoder_protocol
  test "encoder protocol supports no segmentation for segment ACK" do
    assert false ===
             EncoderProtocol.supports_segmentation(%APDU.SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 70,
               sequence_number: 2,
               actual_window_size: 16
             })
  end

  @tag :encoder_protocol
  test "encoder protocol encode segmented errors for segment ACK" do
    assert_raise RuntimeError, ~r"APDU can not be segmented"i, fn ->
      EncoderProtocol.encode_segmented(
        %APDU.SegmentACK{
          negative_ack: false,
          sent_by_server: true,
          invoke_id: 70,
          sequence_number: 2,
          actual_window_size: 16
        },
        50
      )
    end
  end

  test "encoding abort" do
    assert {:ok, <<113, 70, 8>>} =
             APDU.Abort.encode(%APDU.Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: :application_exceeded_reply_time
             })
  end

  test "encoding abort 2" do
    assert {:ok, <<112, 70, 8>>} =
             APDU.Abort.encode(%APDU.Abort{
               sent_by_server: false,
               invoke_id: 70,
               reason: :application_exceeded_reply_time
             })
  end

  test "encoding abort 3" do
    assert {:ok, <<113, 255, 1>>} =
             APDU.Abort.encode(%APDU.Abort{
               sent_by_server: true,
               invoke_id: 255,
               reason: :buffer_overflow
             })
  end

  @tag :encoder_protocol
  test "encoding abort 4 (encoder protocol)" do
    assert <<113, 70, 8>> =
             EncoderProtocol.encode(%APDU.Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: :application_exceeded_reply_time
             })
  end

  @tag :encoder_protocol
  test "encoding abort 5 (encoder protocol)" do
    assert <<113, 70, 8>> =
             EncoderProtocol.encode(%APDU.Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: 8
             })
  end

  test "encoding invalid abort" do
    assert {:error, %ConstantError{}} =
             APDU.Abort.encode(%APDU.Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: :something_else
             })
  end

  test "encoding invalid abort 2" do
    assert {:error,
            %ArgumentError{message: "Invoke ID must be between 0 and 255 inclusive, got: 256"}} =
             APDU.Abort.encode(%APDU.Abort{
               sent_by_server: true,
               invoke_id: 256,
               reason: :other
             })
  end

  @tag :encoder_protocol
  test "encoding invalid abort 3 (encoder protocol)" do
    assert_raise ArgumentError, fn ->
      EncoderProtocol.encode(%APDU.Abort{
        sent_by_server: true,
        invoke_id: 256,
        reason: :other
      })
    end
  end

  @tag :encoder_protocol
  test "encoder protocol supports no segmentation for abort" do
    assert false ===
             EncoderProtocol.supports_segmentation(%APDU.Abort{
               sent_by_server: true,
               invoke_id: 255,
               reason: :other
             })
  end

  @tag :encoder_protocol
  test "encoder protocol encode segmented errors for abort" do
    assert_raise RuntimeError, ~r"APDU can not be segmented"i, fn ->
      EncoderProtocol.encode_segmented(
        %APDU.Abort{
          sent_by_server: true,
          invoke_id: 255,
          reason: :other
        },
        50
      )
    end
  end

  test "encoding error" do
    assert {:ok, <<80, 2, 18, 14, 145, 5, 145, 26, 15, 26, 1, 76, 41, 0, 62, 98, 11, 22, 63>>} =
             APDU.Error.encode(%APDU.Error{
               class: :services,
               code: :password_failure,
               invoke_id: 2,
               payload: [
                 tagged: {1, <<1, 76>>, 2},
                 tagged: {2, <<0>>, 1},
                 constructed: {3, {:octet_string, <<11, 22>>}, 0}
               ],
               service: :confirmed_private_transfer
             })
  end

  test "encoding error 2" do
    assert {:ok, <<80, 2, 18, 145, 5, 145, 0>>} =
             APDU.Error.encode(%APDU.Error{
               class: :services,
               code: :other,
               invoke_id: 2,
               payload: [],
               service: :confirmed_private_transfer
             })
  end

  test "encoding error 3 (with payload)" do
    assert {:ok, <<80, 2, 18, 14, 145, 5, 145, 0, 15, 25, 15>>} =
             APDU.Error.encode(%APDU.Error{
               class: :services,
               code: :other,
               invoke_id: 2,
               payload: [tagged: {1, <<15>>, 1}],
               service: :confirmed_private_transfer
             })
  end

  test "encoding error 4 (service as number)" do
    assert {:ok, <<80, 2, 18, 145, 5, 145, 0>>} =
             APDU.Error.encode(%APDU.Error{
               class: :services,
               code: :other,
               invoke_id: 2,
               payload: [],
               service: 18
             })
  end

  test "encoding error 5 (class as number)" do
    assert {:ok, <<80, 2, 18, 145, 5, 145, 0>>} =
             APDU.Error.encode(%APDU.Error{
               class: 5,
               code: :other,
               invoke_id: 2,
               payload: [],
               service: :confirmed_private_transfer
             })
  end

  test "encoding error 6 (code as number)" do
    assert {:ok, <<80, 2, 18, 145, 5, 145, 0>>} =
             APDU.Error.encode(%APDU.Error{
               class: :services,
               code: 0,
               invoke_id: 2,
               payload: [],
               service: :confirmed_private_transfer
             })
  end

  @tag :encoder_protocol
  test "encoding error 7 (encoder protocol)" do
    assert <<80, 2, 18, 145, 5, 145, 0>> =
             EncoderProtocol.encode(%APDU.Error{
               class: :services,
               code: :other,
               invoke_id: 2,
               payload: [],
               service: :confirmed_private_transfer
             })
  end

  test "encoding invalid error" do
    assert {:error, %ConstantError{}} =
             APDU.Error.encode(%APDU.Error{
               class: :something_else,
               code: :other,
               invoke_id: 2,
               payload: [],
               service: :confirmed_private_transfer
             })
  end

  test "encoding invalid error 2" do
    assert {:error, %ConstantError{}} =
             APDU.Error.encode(%APDU.Error{
               class: :services,
               code: :something_else,
               invoke_id: 2,
               payload: [],
               service: :confirmed_private_transfer
             })
  end

  test "encoding invalid error 3" do
    assert {:error, %ConstantError{}} =
             APDU.Error.encode(%APDU.Error{
               class: :services,
               code: :other,
               invoke_id: 2,
               payload: [],
               service: :something_else
             })
  end

  test "encoding invalid error 4" do
    assert {:error,
            %ArgumentError{message: "Invoke ID must be between 0 and 255 inclusive, got: 256"}} =
             APDU.Error.encode(%APDU.Error{
               class: :services,
               code: :other,
               invoke_id: 256,
               payload: [],
               service: :confirmed_private_transfer
             })
  end

  @tag :encoder_protocol
  test "encoding invalid error 5 (encoder protocol)" do
    assert_raise ArgumentError, fn ->
      EncoderProtocol.encode(%APDU.Error{
        class: :services,
        code: :other,
        invoke_id: 256,
        payload: [],
        service: :confirmed_private_transfer
      })
    end
  end

  test "encoding error with invalid constructed encoding" do
    assert {:error,
            %RuntimeError{
              message: "Unable to encode payload in error encode, error: :invalid_value"
            }} =
             APDU.Error.encode(%APDU.Error{
               class: :services,
               code: :other,
               invoke_id: 0,
               payload: [{:constructed, {0, nil, 0}}],
               service: :confirmed_private_transfer
             })
  end

  @tag :encoder_protocol
  test "encoder protocol supports no segmentation for error" do
    assert false ===
             EncoderProtocol.supports_segmentation(%APDU.Error{
               class: :services,
               code: :other,
               invoke_id: 255,
               payload: [],
               service: :confirmed_private_transfer
             })
  end

  @tag :encoder_protocol
  test "encoder protocol encode segmented errors for error" do
    assert_raise RuntimeError, ~r"APDU can not be segmented"i, fn ->
      EncoderProtocol.encode_segmented(
        %APDU.Error{
          class: :services,
          code: :other,
          invoke_id: 255,
          payload: [],
          service: :confirmed_private_transfer
        },
        50
      )
    end
  end

  test "encoding reject" do
    assert {:ok, <<96, 70, 1>>} =
             APDU.Reject.encode(%APDU.Reject{
               invoke_id: 70,
               reason: :buffer_overflow
             })
  end

  test "encoding reject 2 (reason as number)" do
    assert {:ok, <<96, 70, 1>>} =
             APDU.Reject.encode(%APDU.Reject{
               invoke_id: 70,
               reason: 1
             })
  end

  @tag :encoder_protocol
  test "encoding reject 3 (encoder protocol)" do
    assert <<96, 71, 0>> =
             EncoderProtocol.encode(%APDU.Reject{
               invoke_id: 71,
               reason: :other
             })
  end

  test "encoding invalid reject" do
    assert {:error, %ConstantError{}} =
             APDU.Reject.encode(%APDU.Reject{
               invoke_id: 70,
               reason: :something_else
             })
  end

  test "encoding invalid reject 2" do
    assert {:error,
            %ArgumentError{message: "Invoke ID must be between 0 and 255 inclusive, got: 256"}} =
             APDU.Reject.encode(%APDU.Reject{
               invoke_id: 256,
               reason: :other
             })
  end

  @tag :encoder_protocol
  test "encoding invalid reject 3 (encoder protocol)" do
    assert_raise ArgumentError, fn ->
      EncoderProtocol.encode(%APDU.Reject{
        invoke_id: 256,
        reason: :other
      })
    end
  end

  @tag :encoder_protocol
  test "encoder protocol supports no segmentation for reject" do
    assert false ===
             EncoderProtocol.supports_segmentation(%APDU.Reject{
               invoke_id: 71,
               reason: :other
             })
  end

  @tag :encoder_protocol
  test "encoder protocol encode segmented errors for reject" do
    assert_raise RuntimeError, ~r"APDU can not be segmented"i, fn ->
      EncoderProtocol.encode_segmented(
        %APDU.Reject{
          invoke_id: 71,
          reason: :other
        },
        50
      )
    end
  end
end
