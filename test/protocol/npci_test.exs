defmodule BACnet.Protocol.NpciTest do
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget

  use ExUnit.Case, async: true

  @moduletag :npci
  @moduletag :npdu
  @moduletag :protocol_data_structures

  doctest NPCI

  test "NPCI version" do
    assert 0x01 == NPCI.get_version()
  end

  test "create new NPCI with defaults" do
    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new([])
  end

  test "create new NPCI with unknown terms" do
    assert_raise ArgumentError, fn ->
      NPCI.new([:hello_there])
    end
  end

  test "create new NPCI with unknown keys" do
    assert_raise ArgumentError, fn ->
      NPCI.new(hello: :there)
    end
  end

  test "create new NPCI with priority" do
    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(priority: :normal)

    assert %NPCI{
             priority: :urgent,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(priority: :urgent)

    assert %NPCI{
             priority: :critical_equipment_message,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(priority: :critical_equipment_message)

    assert %NPCI{
             priority: :life_safety_message,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(priority: :life_safety_message)
  end

  test "create new NPCI with invalid priority fails" do
    assert_raise ArgumentError, fn ->
      NPCI.new(priority: nil)
    end

    assert_raise ArgumentError, fn ->
      NPCI.new(priority: :hello_there)
    end

    assert_raise ArgumentError, fn ->
      NPCI.new(priority: 5.0)
    end
  end

  test "create new NPCI with expects reply" do
    assert %NPCI{
             priority: :normal,
             expects_reply: true,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(expects_reply: true)
  end

  test "create new NPCI with invalid expects reply" do
    assert_raise ArgumentError, fn ->
      NPCI.new(expects_reply: nil)
    end

    assert_raise ArgumentError, fn ->
      NPCI.new(expects_reply: :hello_there)
    end
  end

  test "create new NPCI with destination" do
    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(destination: nil)

    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: %NpciTarget{},
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(destination: %NpciTarget{net: 1, address: 255})
  end

  test "create new NPCI with invalid destination" do
    assert_raise ArgumentError, fn ->
      NPCI.new(destination: :hello_there)
    end
  end

  test "create new NPCI with invalid destination net" do
    assert_raise ArgumentError, fn ->
      NPCI.new(destination: %NpciTarget{net: 65_536, address: 255})
    end
  end

  test "create new NPCI with source" do
    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(source: nil)

    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: %NpciTarget{},
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(source: %NpciTarget{net: 1, address: 255})
  end

  test "create new NPCI with invalid source" do
    assert_raise ArgumentError, fn ->
      NPCI.new(source: :hello_there)
    end
  end

  test "create new NPCI with invalid source net" do
    assert_raise ArgumentError, fn ->
      NPCI.new(source: %NpciTarget{net: 65_535, address: 255})
    end
  end

  test "create new NPCI with hopcount" do
    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: false
           } = NPCI.new(hopcount: nil)

    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: 1,
             is_network_message: false
           } = NPCI.new(hopcount: 1)

    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: 64,
             is_network_message: false
           } = NPCI.new(hopcount: 64)

    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: 255,
             is_network_message: false
           } = NPCI.new(hopcount: 255)
  end

  test "create new NPCI with invalid hopcount" do
    assert_raise ArgumentError, fn ->
      NPCI.new(hopcount: :hello_there)
    end

    assert_raise ArgumentError, fn ->
      NPCI.new(hopcount: 0)
    end

    assert_raise ArgumentError, fn ->
      NPCI.new(hopcount: 256)
    end

    assert_raise ArgumentError, fn ->
      NPCI.new(hopcount: 65_535)
    end
  end

  test "create new NPCI with is_network_message" do
    assert %NPCI{
             priority: :normal,
             expects_reply: false,
             destination: nil,
             source: nil,
             hopcount: nil,
             is_network_message: true
           } = NPCI.new(is_network_message: true)
  end

  test "create new NPCI with invalid is_network_message" do
    assert_raise ArgumentError, fn ->
      NPCI.new(is_network_message: nil)
    end

    assert_raise ArgumentError, fn ->
      NPCI.new(is_network_message: :hello_there)
    end

    assert_raise ArgumentError, fn ->
      NPCI.new(is_network_message: 1)
    end
  end

  test "encode invalid priority" do
    assert_raise Constants.ConstantError, fn ->
      NPCI.encode(%NPCI{
        priority: :invalid_priority,
        expects_reply: false,
        destination: nil,
        source: nil,
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode invalid destination" do
    assert_raise ArgumentError, fn ->
      NPCI.encode(%NPCI{
        priority: :normal,
        expects_reply: false,
        destination: :hello,
        source: nil,
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode invalid source" do
    assert_raise ArgumentError, fn ->
      NPCI.encode(%NPCI{
        priority: :normal,
        expects_reply: false,
        destination: nil,
        source: :hello,
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode invalid source net 65535" do
    assert_raise ArgumentError, fn ->
      NPCI.encode(%NPCI{
        priority: :normal,
        expects_reply: false,
        destination: nil,
        source: %NpciTarget{net: 65_535, address: 1},
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode invalid source address nil" do
    assert_raise ArgumentError, fn ->
      NPCI.encode(%NPCI{
        priority: :normal,
        expects_reply: false,
        destination: nil,
        source: %NpciTarget{net: 65_534, address: nil},
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode invalid NPCI target address atom" do
    assert_raise ArgumentError, fn ->
      NPCI.encode(%NPCI{
        priority: :normal,
        expects_reply: false,
        destination: %NpciTarget{net: 1, address: :hello},
        source: nil,
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode invalid NPCI target address negative" do
    assert_raise ArgumentError, fn ->
      NPCI.encode(%NPCI{
        priority: :normal,
        expects_reply: false,
        destination: %NpciTarget{net: 1, address: -1},
        source: nil,
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode invalid NPCI target address too large" do
    assert_raise ArgumentError, fn ->
      NPCI.encode(%NPCI{
        priority: :normal,
        expects_reply: false,
        destination: %NpciTarget{net: 1, address: 72_057_594_037_927_936},
        source: nil,
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode invalid source net = nil" do
    assert_raise ArgumentError, fn ->
      NPCI.encode(%NPCI{
        priority: :normal,
        expects_reply: false,
        destination: nil,
        source: %NpciTarget{net: nil, address: 1},
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode invalid destination net = 0" do
    assert_raise ArgumentError, fn ->
      NPCI.encode(%NPCI{
        priority: :normal,
        expects_reply: false,
        destination: %NpciTarget{net: 0, address: 1},
        source: nil,
        hopcount: nil,
        is_network_message: false
      })
    end
  end

  test "encode APDU normal no reply" do
    assert [<<1, 0>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode APDU normal expects reply" do
    assert [<<1, 4>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode APDU urgent no reply" do
    assert [<<1, 1>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :urgent,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode APDU urgent expects reply" do
    assert [<<1, 5>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :urgent,
               expects_reply: true,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode APDU critical no reply" do
    assert [<<1, 2>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :critical_equipment_message,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode APDU critical expects reply" do
    assert [<<1, 6>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :critical_equipment_message,
               expects_reply: true,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode APDU life safety no reply" do
    assert [<<1, 3>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :life_safety_message,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode APDU life safety expects reply" do
    assert [<<1, 7>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :life_safety_message,
               expects_reply: true,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode NPCI normal no reply" do
    assert [<<1, 128>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: true
             })
  end

  test "encode NPCI normal expects reply" do
    assert [<<1, 132>>, "", "", ""] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: true
             })
  end

  test "encode APDU normal with destination" do
    assert [<<1, 36>>, <<0, 1, 1, 128>>, "", <<255>>] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: %NpciTarget{net: 1, address: 128},
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode APDU normal with destination only net" do
    assert [<<1, 36>>, <<0, 1, 0>>, "", <<255>>] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: %NpciTarget{net: 1, address: nil},
               source: nil,
               hopcount: nil,
               is_network_message: false
             })
  end

  test "encode APDU normal with destination and hopcount" do
    assert [<<1, 36>>, <<0, 1, 1, 128>>, "", <<8>>] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: %NpciTarget{net: 1, address: 128},
               source: nil,
               hopcount: 8,
               is_network_message: false
             })
  end

  test "encode APDU normal with destination and hopcount (min-limited)" do
    assert [<<1, 36>>, <<0, 1, 1, 128>>, "", <<1>>] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: %NpciTarget{net: 1, address: 128},
               source: nil,
               hopcount: 0,
               is_network_message: false
             })
  end

  test "encode APDU normal with destination and hopcount (max-limited)" do
    assert [<<1, 36>>, <<0, 1, 1, 128>>, "", <<255>>] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: %NpciTarget{net: 1, address: 128},
               source: nil,
               hopcount: 256,
               is_network_message: false
             })
  end

  test "encode APDU normal with source" do
    assert [<<1, 12>>, "", <<0, 1, 1, 128>>, ""] =
             NPCI.encode(%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: nil,
               source: %NpciTarget{net: 1, address: 128},
               hopcount: nil,
               is_network_message: false
             })
  end
end
