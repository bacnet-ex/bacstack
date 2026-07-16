defmodule BACnet.Protocol.VmacEntryTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.VmacEntry

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest VmacEntry

  test "parse valid entry" do
    assert {:ok, vmac_tag} =
             ApplicationTags.create_tag_encoding(0, :octet_string, <<1, 2, 3, 4, 5, 6>>)

    assert {:ok, nmac_tag} =
             ApplicationTags.create_tag_encoding(1, :octet_string, <<0xAA, 0xBB>>)

    assert {:ok,
            {%VmacEntry{
               virtual_mac_address: <<1, 2, 3, 4, 5, 6>>,
               native_mac_address: <<0xAA, 0xBB>>
             }, []}} = VmacEntry.parse([vmac_tag, nmac_tag])
  end

  test "parse leaves remaining tags" do
    assert {:ok, vmac_tag} =
             ApplicationTags.create_tag_encoding(0, :octet_string, <<9>>)

    assert {:ok, nmac_tag} =
             ApplicationTags.create_tag_encoding(1, :octet_string, <<8, 7>>)

    extra = {:boolean, true}

    assert {:ok, {%VmacEntry{}, [^extra]}} =
             VmacEntry.parse([vmac_tag, nmac_tag, extra])
  end

  test "parse rejects incomplete or wrong tags" do
    assert {:error, :invalid_tags} = VmacEntry.parse([])
    assert {:error, :invalid_tags} = VmacEntry.parse([{:tagged, {0, <<1>>, 1}}])

    # wrong tag numbers
    assert {:error, :invalid_tags} =
             VmacEntry.parse([
               {:tagged, {2, <<1>>, 1}},
               {:tagged, {1, <<2>>, 1}}
             ])
  end

  test "parse rejects VMAC longer than 6" do
    long = <<1, 2, 3, 4, 5, 6, 7>>

    assert {:error, :invalid_tags} =
             VmacEntry.parse([
               {:tagged, {0, long, 7}},
               {:tagged, {1, <<0xFF>>, 1}}
             ])
  end

  test "encode valid entry" do
    entry = %VmacEntry{
      virtual_mac_address: <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06>>,
      native_mac_address: <<0xDE, 0xAD, 0xBE, 0xEF>>
    }

    assert {:ok, tags} = VmacEntry.encode(entry)

    assert [
             {:tagged, {0, <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06>>, 6}},
             {:tagged, {1, <<0xDE, 0xAD, 0xBE, 0xEF>>, 4}}
           ] = tags
  end

  test "encode short VMAC" do
    entry = %VmacEntry{
      virtual_mac_address: <<0xAA>>,
      native_mac_address: <<0x11, 0x22, 0x33>>
    }

    assert {:ok,
            [
              {:tagged, {0, <<0xAA>>, 1}},
              {:tagged, {1, <<0x11, 0x22, 0x33>>, 3}}
            ]} = VmacEntry.encode(entry)
  end

  test "encode rejects VMAC longer than 6 octets" do
    entry = %VmacEntry{
      virtual_mac_address: <<1, 2, 3, 4, 5, 6, 7>>,
      native_mac_address: <<0xFF>>
    }

    assert {:error, :virtual_mac_too_long} = VmacEntry.encode(entry)
  end

  test "valid? accepts proper entries" do
    assert VmacEntry.valid?(%VmacEntry{
             virtual_mac_address: <<1, 2, 3, 4, 5, 6>>,
             native_mac_address: <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
           })

    # VMAC may be shorter than 6
    assert VmacEntry.valid?(%VmacEntry{
             virtual_mac_address: <<1, 2, 3>>,
             native_mac_address: <<0x11, 0x22>>
           })

    # empty VMAC is allowed by ASN.1 size (0..6)
    assert VmacEntry.valid?(%VmacEntry{
             virtual_mac_address: <<>>,
             native_mac_address: <<0x01>>
           })
  end

  test "valid? rejects invalid entries" do
    # VMAC longer than 6 octets
    refute VmacEntry.valid?(%VmacEntry{
             virtual_mac_address: <<1, 2, 3, 4, 5, 6, 7>>,
             native_mac_address: <<0xAA>>
           })

    # empty native MAC
    refute VmacEntry.valid?(%VmacEntry{
             virtual_mac_address: <<1, 2>>,
             native_mac_address: <<>>
           })

    # non-binary
    refute VmacEntry.valid?(%VmacEntry{
             virtual_mac_address: "not-binary",
             native_mac_address: <<1>>
           })

    refute VmacEntry.valid?(%VmacEntry{
             virtual_mac_address: <<1>>,
             native_mac_address: :atom
           })
  end

  test "round-trip" do
    original = %VmacEntry{
      virtual_mac_address: <<0x12, 0x34, 0x56>>,
      native_mac_address: <<0xAB, 0xCD, 0xEF, 0x01, 0x23>>
    }

    assert {:ok, tags} = VmacEntry.encode(original)
    assert {:ok, {decoded, []}} = VmacEntry.parse(tags)
    assert decoded == original
  end

  test "round-trip max-size VMAC" do
    original = %VmacEntry{
      virtual_mac_address: <<0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA>>,
      native_mac_address: <<0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77>>
    }

    assert {:ok, tags} = VmacEntry.encode(original)
    assert {:ok, {decoded, []}} = VmacEntry.parse(tags)
    assert decoded == original
  end
end
