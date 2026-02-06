defmodule BACnet.Test.Protocol.Services.WriteGroupTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.GroupChannelValue
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.WriteGroup

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest WriteGroup

  test "get name" do
    assert :write_group == WriteGroup.get_name()
  end

  test "is confirmed" do
    assert false == WriteGroup.is_confirmed()
  end

  test "decoding WriteGroup" do
    assert {:ok,
            %WriteGroup{
              group_number: 23,
              write_priority: 8,
              changelist: [
                %GroupChannelValue{
                  channel: 268,
                  overriding_priority: nil,
                  value: %Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :unsigned_integer,
                    value: 1111
                  }
                },
                %GroupChannelValue{
                  channel: 269,
                  overriding_priority: nil,
                  value: %Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :unsigned_integer,
                    value: 2222
                  }
                }
              ],
              inhibit_delay: nil
            }} =
             WriteGroup.from_apdu(%UnconfirmedServiceRequest{
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

  test "decoding WriteGroup 2" do
    assert {:ok,
            %WriteGroup{
              group_number: 23,
              write_priority: 8,
              changelist: [
                %GroupChannelValue{
                  channel: 12,
                  overriding_priority: nil,
                  value: %Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :real,
                    value: 67.0
                  }
                },
                %GroupChannelValue{
                  channel: 13,
                  overriding_priority: nil,
                  value: %Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :real,
                    value: 72.0
                  }
                }
              ],
              inhibit_delay: true
            }} =
             WriteGroup.from_apdu(%UnconfirmedServiceRequest{
               service: :write_group,
               parameters: [
                 tagged: {0, <<23>>, 1},
                 tagged: {1, "\b", 1},
                 constructed:
                   {2,
                    [
                      tagged: {0, "\f", 1},
                      real: 67.0,
                      tagged: {0, "\r", 1},
                      real: 72.0
                    ], 0},
                 tagged: {3, <<1>>, 1}
               ]
             })
  end

  test "decoding WriteGroup 3" do
    assert {:ok,
            %WriteGroup{
              group_number: 23,
              write_priority: 8,
              changelist: [
                %GroupChannelValue{
                  channel: 12,
                  overriding_priority: nil,
                  value: %Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :unsigned_integer,
                    value: 1111
                  }
                },
                %GroupChannelValue{
                  channel: 13,
                  overriding_priority: 10,
                  value: %Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :character_string,
                    value: "ABC"
                  }
                }
              ],
              inhibit_delay: nil
            }} =
             WriteGroup.from_apdu(%UnconfirmedServiceRequest{
               service: :write_group,
               parameters: [
                 tagged: {0, <<23>>, 1},
                 tagged: {1, "\b", 1},
                 constructed:
                   {2,
                    [
                      tagged: {0, "\f", 1},
                      unsigned_integer: 1111,
                      tagged: {0, "\r", 1},
                      tagged: {1, "\n", 1},
                      character_string: "ABC"
                    ], 0}
               ]
             })
  end

  test "decoding WriteGroup invalid changelist" do
    assert {:error, :unknown_tag_encoding} =
             WriteGroup.from_apdu(%UnconfirmedServiceRequest{
               service: :write_group,
               parameters: [
                 tagged: {0, <<23>>, 1},
                 tagged: {1, "\b", 1},
                 constructed:
                   {2,
                    [
                      tagged: {0, "\f", 1},
                      unsigned_integer: 1111,
                      tagged: {0, "\r", 1},
                      tagged: {1, <<>>, 0},
                      character_string: "ABC"
                    ], 0}
               ]
             })
  end

  test "decoding WriteGroup invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             WriteGroup.from_apdu(%UnconfirmedServiceRequest{
               service: :write_group,
               parameters: [
                 tagged: {0, <<23>>, 1},
                 tagged: {1, "\b", 1}
               ]
             })
  end

  test "decoding WriteGroup invalid group number" do
    assert {:error, :invalid_group_number_value} =
             WriteGroup.from_apdu(%UnconfirmedServiceRequest{
               service: :write_group,
               parameters: [
                 tagged: {0, <<235, 255, 255, 255, 255>>, 5},
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

  test "decoding WriteGroup invalid APDU" do
    assert {:error, :invalid_request} =
             WriteGroup.from_apdu(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: [
                 tagged: {0, <<23>>, 1},
                 tagged: {1, "\b", 1}
               ]
             })
  end

  test "encoding WriteGroup" do
    assert {:ok,
            %UnconfirmedServiceRequest{
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
            }} =
             WriteGroup.to_apdu(
               %WriteGroup{
                 group_number: 23,
                 write_priority: 8,
                 changelist: [
                   %GroupChannelValue{
                     channel: 268,
                     overriding_priority: nil,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :unsigned_integer,
                       value: 1111
                     }
                   },
                   %GroupChannelValue{
                     channel: 269,
                     overriding_priority: nil,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :unsigned_integer,
                       value: 2222
                     }
                   }
                 ],
                 inhibit_delay: nil
               },
               []
             )
  end

  test "encoding WriteGroup 2" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :write_group,
              parameters: [
                tagged: {0, <<23>>, 1},
                tagged: {1, "\b", 1},
                constructed:
                  {2,
                   [
                     tagged: {0, "\f", 1},
                     real: 67.0,
                     tagged: {0, "\r", 1},
                     real: 72.0
                   ], 0},
                tagged: {3, <<1>>, 1}
              ]
            }} =
             WriteGroup.to_apdu(
               %WriteGroup{
                 group_number: 23,
                 write_priority: 8,
                 changelist: [
                   %GroupChannelValue{
                     channel: 12,
                     overriding_priority: nil,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :real,
                       value: 67.0
                     }
                   },
                   %GroupChannelValue{
                     channel: 13,
                     overriding_priority: nil,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :real,
                       value: 72.0
                     }
                   }
                 ],
                 inhibit_delay: true
               },
               []
             )
  end

  test "encoding WriteGroup 3" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :write_group,
              parameters: [
                tagged: {0, <<23>>, 1},
                tagged: {1, "\b", 1},
                constructed:
                  {2,
                   [
                     tagged: {0, "\f", 1},
                     unsigned_integer: 1111,
                     tagged: {0, "\r", 1},
                     tagged: {1, "\n", 1},
                     character_string: "ABC"
                   ], 0}
              ]
            }} =
             WriteGroup.to_apdu(
               %WriteGroup{
                 group_number: 23,
                 write_priority: 8,
                 changelist: [
                   %GroupChannelValue{
                     channel: 12,
                     overriding_priority: nil,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :unsigned_integer,
                       value: 1111
                     }
                   },
                   %GroupChannelValue{
                     channel: 13,
                     overriding_priority: 10,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :character_string,
                       value: "ABC"
                     }
                   }
                 ],
                 inhibit_delay: nil
               },
               []
             )
  end

  test "encoding WriteGroup invalid changelist" do
    assert {:error, :invalid_value} =
             WriteGroup.to_apdu(
               %WriteGroup{
                 group_number: 23,
                 write_priority: 8,
                 changelist: [
                   %GroupChannelValue{
                     channel: 125,
                     overriding_priority: nil,
                     value: %Encoding{
                       encoding: :hello,
                       extras: [],
                       type: :unsigned_integer,
                       value: 1111
                     }
                   }
                 ],
                 inhibit_delay: nil
               },
               []
             )
  end

  test "encoding WriteGroup invalid group number" do
    assert {:error, :invalid_group_number_value} =
             WriteGroup.to_apdu(
               %WriteGroup{
                 group_number: 23_532_245_532_430_895,
                 write_priority: 8,
                 changelist: [
                   %GroupChannelValue{
                     channel: 268,
                     overriding_priority: nil,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :unsigned_integer,
                       value: 1111
                     }
                   },
                   %GroupChannelValue{
                     channel: 269,
                     overriding_priority: nil,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :unsigned_integer,
                       value: 2222
                     }
                   }
                 ],
                 inhibit_delay: nil
               },
               []
             )
  end

  test "protocol implementation get name" do
    assert :write_group ==
             ServicesProtocol.get_name(%WriteGroup{
               group_number: 23,
               write_priority: 8,
               changelist: [],
               inhibit_delay: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert false ==
             ServicesProtocol.is_confirmed(%WriteGroup{
               group_number: 23,
               write_priority: 8,
               changelist: [],
               inhibit_delay: nil
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :write_group,
              parameters: [
                tagged: {0, <<23>>, 1},
                tagged: {1, "\b", 1},
                constructed:
                  {2,
                   [
                     tagged: {0, "\f", 1},
                     unsigned_integer: 1111,
                     tagged: {0, "\r", 1},
                     tagged: {1, "\n", 1},
                     character_string: "ABC"
                   ], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %WriteGroup{
                 group_number: 23,
                 write_priority: 8,
                 changelist: [
                   %GroupChannelValue{
                     channel: 12,
                     overriding_priority: nil,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :unsigned_integer,
                       value: 1111
                     }
                   },
                   %GroupChannelValue{
                     channel: 13,
                     overriding_priority: 10,
                     value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :character_string,
                       value: "ABC"
                     }
                   }
                 ],
                 inhibit_delay: nil
               },
               []
             )
  end
end
