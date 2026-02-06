defmodule BACnet.Test.Protocol.APDU.UnconfirmedServiceRequestTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services
  alias BACnet.Stack.EncoderProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu

  doctest UnconfirmedServiceRequest

  test "EncoderProtocol expects reply" do
    assert false ==
             EncoderProtocol.expects_reply(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 unsigned_integer: 50,
                 enumerated: 3,
                 unsigned_integer: 42
               ]
             })
  end

  test "EncoderProtocol is request" do
    assert true ==
             EncoderProtocol.is_request(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 unsigned_integer: 50,
                 enumerated: 3,
                 unsigned_integer: 42
               ]
             })
  end

  test "EncoderProtocol is response" do
    assert false ==
             EncoderProtocol.is_response(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 unsigned_integer: 50,
                 enumerated: 3,
                 unsigned_integer: 42
               ]
             })
  end

  @tag :service
  test "APDU to service IAm" do
    assert {:ok, %Services.IAm{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 unsigned_integer: 50,
                 enumerated: 3,
                 unsigned_integer: 42
               ]
             })
  end

  @tag :service
  test "APDU to service IHave" do
    assert {:ok, %Services.IHave{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :i_have,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   type: :device,
                   instance: 8
                 },
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 },
                 character_string: "OATemp"
               ]
             })
  end

  @tag :service
  test "APDU to service TimeSynchronization" do
    assert {:ok, %Services.TimeSynchronization{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :time_synchronization,
               parameters: [
                 date: %BACnetDate{
                   year: 1992,
                   month: 11,
                   day: 17,
                   weekday: 2
                 },
                 time: %BACnetTime{
                   hour: 22,
                   minute: 45,
                   second: 30,
                   hundredth: 70
                 }
               ]
             })
  end

  @tag :service
  test "APDU to service UnconfirmedCovNotification" do
    assert {:ok, %Services.UnconfirmedCovNotification{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :unconfirmed_cov_notification,
               parameters: [
                 tagged: {0, "c", 1},
                 tagged: {1, <<2, 1, 79, 241>>, 4},
                 tagged: {2, <<0, 192, 0, 102>>, 4},
                 tagged: {3, <<30>>, 1},
                 constructed:
                   {4,
                    [
                      tagged: {0, "U", 1},
                      constructed: {2, {:enumerated, 0}, 0},
                      tagged: {0, "o", 1},
                      constructed: {2, {:bitstring, {4, {false, false, false, false}}}, 0}
                    ], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service UnconfirmedEventNotification" do
    assert {:ok, %Services.UnconfirmedEventNotification{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :unconfirmed_event_notification,
               parameters: [
                 tagged: {0, "{", 1},
                 tagged: {1, <<2, 15, 226, 104>>, 4},
                 tagged: {2, <<0, 45, 198, 208>>, 4},
                 constructed: {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0},
                 tagged: {4, <<1>>, 1},
                 tagged: {5, <<200>>, 1},
                 tagged: {6, <<6>>, 1},
                 tagged: {8, <<0>>, 1},
                 tagged: {9, <<1>>, 1},
                 tagged: {10, <<3>>, 1},
                 tagged: {11, <<0>>, 1},
                 constructed:
                   {12,
                    {:constructed,
                     {6,
                      [
                        tagged: {0, "U", 1},
                        constructed: {2, {:real, 1.0}, 0},
                        tagged: {3, "\a", 1}
                      ], 0}}, 0}
               ]
             })
  end

  @tag :service
  test "APDU to service UnconfirmedPrivateTransfer" do
    assert {:ok, %Services.UnconfirmedPrivateTransfer{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :unconfirmed_private_transfer,
               parameters: [
                 tagged: {0, <<25>>, 1},
                 tagged: {1, "\b", 1},
                 constructed: {2, [real: 72.4, octet_string: <<22, 73>>], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service UnconfirmedTextMessage" do
    assert {:ok, %Services.UnconfirmedTextMessage{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :unconfirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 tagged: {2, <<0>>, 1},
                 tagged:
                   {3,
                    <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114,
                      32, 80, 85, 77, 80, 51, 52, 55>>, 24}
               ]
             })
  end

  @tag :service
  test "APDU to service UtcTimeSynchronization" do
    assert {:ok, %Services.UtcTimeSynchronization{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :utc_time_synchronization,
               parameters: [
                 date: %BACnetDate{
                   year: 1992,
                   month: 11,
                   day: 17,
                   weekday: 2
                 },
                 time: %BACnetTime{
                   hour: 22,
                   minute: 45,
                   second: 30,
                   hundredth: 70
                 }
               ]
             })
  end

  @tag :service
  test "APDU to service WhoHas" do
    assert {:ok, %Services.WhoHas{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :who_has,
               parameters: [
                 tagged: {3, <<0, 79, 65, 84, 101, 109, 112>>, 7}
               ]
             })
  end

  @tag :service
  test "APDU to service WhoIs" do
    assert {:ok, %Services.WhoIs{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :who_is,
               parameters: []
             })
  end

  @tag :service
  test "APDU to service WriteGroup" do
    assert {:ok, %Services.WriteGroup{}} =
             UnconfirmedServiceRequest.to_service(%UnconfirmedServiceRequest{
               service: :write_group,
               parameters: [
                 tagged: {0, <<23>>, 1},
                 tagged: {1, "\b", 1},
                 constructed:
                   {2,
                    [
                      tagged: {0, <<1, 12>>, 2},
                      unsigned_integer: 1111,
                      tagged: {0, <<1, 13>>, 2},
                      unsigned_integer: 2222
                    ], 0}
               ]
             })
  end
end
