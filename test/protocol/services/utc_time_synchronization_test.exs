defmodule BACnet.Test.Protocol.Services.UtcTimeSynchronizationTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.UtcTimeSynchronization

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest UtcTimeSynchronization

  test "get name" do
    assert :utc_time_synchronization == UtcTimeSynchronization.get_name()
  end

  test "is confirmed" do
    assert false == UtcTimeSynchronization.is_confirmed()
  end

  test "decoding UtcTimeSynchronization" do
    assert {:ok,
            %UtcTimeSynchronization{
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
            }} =
             UtcTimeSynchronization.from_apdu(%UnconfirmedServiceRequest{
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

  test "decoding UtcTimeSynchronization invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             UtcTimeSynchronization.from_apdu(%UnconfirmedServiceRequest{
               service: :utc_time_synchronization,
               parameters: []
             })
  end

  test "decoding UtcTimeSynchronization invalid APDU" do
    assert {:error, :invalid_request} =
             UtcTimeSynchronization.from_apdu(%UnconfirmedServiceRequest{
               service: :time_synchronization,
               parameters: [
                 date: %BACnetDate{
                   year: 1992,
                   month: 11,
                   day: 17,
                   weekday: 2
                 }
               ]
             })
  end

  test "encoding UtcTimeSynchronization" do
    assert {:ok,
            %UnconfirmedServiceRequest{
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
            }} =
             UtcTimeSynchronization.to_apdu(
               %UtcTimeSynchronization{
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
               },
               []
             )
  end

  test "protocol implementation get name" do
    assert :utc_time_synchronization ==
             ServicesProtocol.get_name(%UtcTimeSynchronization{
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
             })
  end

  test "protocol implementation is confirmed" do
    assert false ==
             ServicesProtocol.is_confirmed(%UtcTimeSynchronization{
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
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %UnconfirmedServiceRequest{
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
            }} =
             ServicesProtocol.to_apdu(
               %UtcTimeSynchronization{
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
               },
               []
             )
  end
end
