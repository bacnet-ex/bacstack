defmodule BACnet.Protocol.BvlcFunctionTest do
  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.BvlcFunction
  alias BACnet.Protocol.ForeignDeviceTableEntry

  use ExUnit.Case, async: true

  @moduletag :bvlc
  @moduletag :protocol_data_structures

  doctest BvlcFunction

  test "decode write broadcast distribution table" do
    assert {:ok,
            %BvlcFunction{
              function: :bvlc_write_broadcast_distribution_table,
              data: [
                %BroadcastDistributionTableEntry{
                  ip: {192, 168, 1, 100},
                  port: 47808,
                  mask: {255, 255, 255, 255}
                },
                %BroadcastDistributionTableEntry{
                  ip: {192, 168, 2, 200},
                  port: 47808,
                  mask: {255, 255, 255, 255}
                }
              ]
            }} =
             BvlcFunction.decode(
               0x01,
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xA8, 0x02,
                 0xC8, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF>>
             )

    assert {:ok, %BvlcFunction{function: :bvlc_write_broadcast_distribution_table, data: []}} =
             BvlcFunction.decode(0x01, <<>>)
  end

  test "decode write broadcast distribution table invalid data" do
    assert {:error, :invalid_data} =
             BvlcFunction.decode(
               0x01,
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF>>
             )

    assert {:error, :invalid_data} =
             BvlcFunction.decode(
               0x01,
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xA8, 0x02,
                 0xC8, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF>>
             )
  end

  test "decode read broadcast distribution table" do
    assert {:ok, %BvlcFunction{function: :bvlc_read_broadcast_distribution_table, data: nil}} =
             BvlcFunction.decode(0x02, <<>>)
  end

  test "decode read broadcast distribution table invalid data" do
    assert {:error, :invalid_data} = BvlcFunction.decode(0x02, <<0xC0>>)
  end

  test "decode read broadcast distribution table ack" do
    assert {:ok,
            %BvlcFunction{
              function: :bvlc_read_broadcast_distribution_table_ack,
              data: [
                %BroadcastDistributionTableEntry{
                  ip: {192, 168, 1, 100},
                  port: 47808,
                  mask: {255, 255, 255, 255}
                },
                %BroadcastDistributionTableEntry{
                  ip: {192, 168, 2, 200},
                  port: 47808,
                  mask: {255, 255, 255, 255}
                }
              ]
            }} =
             BvlcFunction.decode(
               0x03,
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xA8, 0x02,
                 0xC8, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF>>
             )

    assert {:ok, %BvlcFunction{function: :bvlc_read_broadcast_distribution_table_ack, data: []}} =
             BvlcFunction.decode(0x03, <<>>)
  end

  test "decode read broadcast distribution table ack invalid data" do
    assert {:error, :invalid_data} =
             BvlcFunction.decode(
               0x03,
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF>>
             )

    assert {:error, :invalid_data} =
             BvlcFunction.decode(
               0x03,
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xA8, 0x02,
                 0xC8, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF>>
             )
  end

  test "decode register foreign device" do
    assert {:ok, %BvlcFunction{function: :bvlc_register_foreign_device, data: 1296}} =
             BvlcFunction.decode(0x05, <<0x05, 0x10>>)
  end

  test "decode register foreign device invalid data" do
    assert {:error, :invalid_data} = BvlcFunction.decode(0x05, <<0xC0>>)
    assert {:error, :invalid_data} = BvlcFunction.decode(0x05, <<0xC0, 0, 0>>)
  end

  test "decode read foreign device table" do
    assert {:ok, %BvlcFunction{function: :bvlc_read_foreign_device_table, data: nil}} =
             BvlcFunction.decode(0x06, <<>>)
  end

  test "decode read foreign device table invalid data" do
    assert {:error, :invalid_data} = BvlcFunction.decode(0x06, <<0xC0>>)
  end

  test "decode read foreign device table ack" do
    assert {:ok,
            %BvlcFunction{
              function: :bvlc_read_foreign_device_table_ack,
              data: [
                %ForeignDeviceTableEntry{
                  ip: {192, 168, 1, 100},
                  port: 47808,
                  time_to_live: 49320,
                  remaining_time: 712
                },
                %ForeignDeviceTableEntry{
                  ip: {192, 168, 2, 100},
                  port: 47808,
                  time_to_live: 51880,
                  remaining_time: 4808
                }
              ]
            }} =
             BvlcFunction.decode(
               0x07,
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xC0, 0xA8, 0x02, 0xC8, 0xC0, 0xA8, 0x02,
                 0x64, 0xBA, 0xC0, 0xCA, 0xA8, 0x12, 0xC8>>
             )
  end

  test "decode read foreign device table ack invalid data" do
    assert {:error, :invalid_data} = BvlcFunction.decode(0x07, <<0xC0>>)
  end

  test "decode delete foreign device table entry" do
    assert {:ok,
            %BvlcFunction{
              function: :bvlc_delete_foreign_device_table_entry,
              data: %ForeignDeviceTableEntry{
                ip: {192, 168, 1, 100},
                port: 47808,
                time_to_live: nil,
                remaining_time: nil
              }
            }} =
             BvlcFunction.decode(
               0x08,
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0>>
             )
  end

  test "decode delete foreign device table entry invalid data" do
    assert {:error, :invalid_data} = BvlcFunction.decode(0x08, <<0xC0>>)
  end

  test "decode unsupported bvlc function" do
    assert {:error, :unsupported_bvlc_function} =
             BvlcFunction.decode(0x0C, <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0>>)
  end

  test "encode write broadcast distribution table" do
    assert {:ok,
            {0x01,
             <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xA8, 0x02, 0xC8,
               0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF>>}} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_write_broadcast_distribution_table,
               data: [
                 %BroadcastDistributionTableEntry{
                   ip: {192, 168, 1, 100},
                   port: 47808,
                   mask: {255, 255, 255, 255}
                 },
                 %BroadcastDistributionTableEntry{
                   ip: {192, 168, 2, 200},
                   port: 47808,
                   mask: {255, 255, 255, 255}
                 }
               ]
             })

    assert {:ok, {0x01, <<>>}} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_write_broadcast_distribution_table,
               data: []
             })
  end

  test "encode write broadcast distribution table invalid entry" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_write_broadcast_distribution_table,
               data: [
                 %BroadcastDistributionTableEntry{
                   ip: {192, 168, 1, 100},
                   port: nil,
                   mask: {255, 255, 255, 255}
                 }
               ]
             })
  end

  test "encode write broadcast distribution table invalid data" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_write_broadcast_distribution_table,
               data: :hello_there
             })
  end

  test "encode read broadcast distribution table" do
    assert {:ok, {0x02, <<>>}} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_broadcast_distribution_table,
               data: nil
             })
  end

  test "encode read broadcast distribution table invalid data" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_broadcast_distribution_table,
               data: :hello_there
             })
  end

  test "encode read broadcast distribution table ack" do
    assert {:ok,
            {
              0x03,
              <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xA8, 0x02,
                0xC8, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF>>
            }} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_broadcast_distribution_table_ack,
               data: [
                 %BroadcastDistributionTableEntry{
                   ip: {192, 168, 1, 100},
                   port: 47808,
                   mask: {255, 255, 255, 255}
                 },
                 %BroadcastDistributionTableEntry{
                   ip: {192, 168, 2, 200},
                   port: 47808,
                   mask: {255, 255, 255, 255}
                 }
               ]
             })

    assert {:ok, {0x03, <<>>}} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_broadcast_distribution_table_ack,
               data: []
             })
  end

  test "encode read broadcast distribution table ack invalid entry" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_broadcast_distribution_table_ack,
               data: [
                 %BroadcastDistributionTableEntry{
                   ip: {192, 168, 1, 100},
                   port: nil,
                   mask: {255, 255, 255, 255}
                 }
               ]
             })
  end

  test "encode read broadcast distribution table ack invalid data" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_broadcast_distribution_table_ack,
               data: :hello_there
             })
  end

  test "encode register foreign device" do
    assert {:ok, {0x05, <<0x05, 0x10>>}} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_register_foreign_device,
               data: 1296
             })
  end

  test "encode register foreign device invalid data" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_register_foreign_device,
               data: nil
             })
  end

  test "encode read foreign device table" do
    assert {:ok, {0x06, <<>>}} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_foreign_device_table,
               data: nil
             })
  end

  test "encode read foreign device table invalid data" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_foreign_device_table,
               data: :hello_there
             })
  end

  test "encode read foreign device table ack" do
    assert {:ok,
            {0x07,
             <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xC0, 0xA8, 0x02, 0xC8, 0xC0, 0xA8, 0x02, 0x64,
               0xBA, 0xC0, 0xCA, 0xA8, 0x12, 0xC8>>}} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_foreign_device_table_ack,
               data: [
                 %ForeignDeviceTableEntry{
                   ip: {192, 168, 1, 100},
                   port: 47808,
                   time_to_live: 49320,
                   remaining_time: 712
                 },
                 %ForeignDeviceTableEntry{
                   ip: {192, 168, 2, 100},
                   port: 47808,
                   time_to_live: 51880,
                   remaining_time: 4808
                 }
               ]
             })

    assert {:ok, {0x07, <<>>}} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_foreign_device_table_ack,
               data: []
             })
  end

  test "encode read foreign device table ack invalid entry" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_foreign_device_table_ack,
               data: [
                 %ForeignDeviceTableEntry{
                   ip: {192, 168, 1, 100},
                   port: 47808,
                   time_to_live: 49320,
                   remaining_time: nil
                 }
               ]
             })
  end

  test "encode read foreign device table ack invalid data" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_read_foreign_device_table_ack,
               data: :hello_there
             })
  end

  test "encode delete foreign device table entry" do
    assert {:ok, {0x08, <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0>>}} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_delete_foreign_device_table_entry,
               data: %ForeignDeviceTableEntry{
                 ip: {192, 168, 1, 100},
                 port: 47808,
                 time_to_live: nil,
                 remaining_time: nil
               }
             })
  end

  test "encode delete foreign device table entry invalid data" do
    assert {:error, :invalid_data} =
             BvlcFunction.encode(%BvlcFunction{
               function: :bvlc_delete_foreign_device_table_entry,
               data: :hello_there
             })
  end

  test "encode unsupported bvlc function" do
    assert {:error, :unsupported_bvlc_function} =
             BvlcFunction.encode(%BvlcFunction{function: :bvll_secure_wrapper, data: nil})
  end
end
