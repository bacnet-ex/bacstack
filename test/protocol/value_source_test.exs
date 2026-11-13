defmodule BACnet.Protocol.ValueSourceTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.RecipientAddress
  alias BACnet.Protocol.ValueSource

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ValueSource

  @local_ref %DeviceObjectRef{
    device_identifier: nil,
    object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24}
  }
  @remote_ref %DeviceObjectRef{
    device_identifier: %ObjectIdentifier{type: :device, instance: 21},
    object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24}
  }
  @local_tags [tagged: {1, <<0, 0, 0, 24>>, 4}]
  @remote_tags [tagged: {0, <<2, 0, 0, 21>>, 4}, tagged: {1, <<0, 0, 0, 24>>, 4}]
  @mac <<192, 168, 1, 2, 186, 192>>

  test "requires every struct field, including unused fields" do
    fields = [type: :none, object: nil, address: nil]

    for field <- [:type, :object, :address] do
      assert_raise ArgumentError, fn ->
        struct!(ValueSource, Keyword.delete(fields, field))
      end
    end

    assert %ValueSource{type: :none, object: nil, address: nil} = struct!(ValueSource, fields)
  end

  describe "encode/2" do
    test "encodes none as context NULL" do
      assert {:ok, [tagged: {0, <<>>, 0}]} =
               ValueSource.encode(%ValueSource{type: :none, object: nil, address: nil})
    end

    test "encodes a local object inside context 1" do
      assert {:ok, [constructed: {1, @local_tags, 0}]} =
               ValueSource.encode(%ValueSource{type: :object, object: @local_ref, address: nil})
    end

    test "encodes a remote object inside context 1 with explicit options" do
      assert {:ok, [constructed: {1, @remote_tags, 0}]} =
               ValueSource.encode(
                 %ValueSource{type: :object, object: @remote_ref, address: nil},
                 []
               )
    end

    test "encodes the originating Device object as an object source" do
      ref = %DeviceObjectRef{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :device, instance: 21}
      }

      assert {:ok, [constructed: {1, [tagged: {1, <<2, 0, 0, 21>>, 4}], 0}]} =
               ValueSource.encode(%ValueSource{type: :object, object: ref, address: nil})
    end

    test "encodes raw MAC octets inside context 2" do
      source = %ValueSource{
        type: :address,
        object: nil,
        address: %RecipientAddress{network: 1, address: @mac}
      }

      assert {:ok, [constructed: {2, [unsigned_integer: 1, octet_string: @mac], 0}]} =
               ValueSource.encode(source)
    end

    test "encodes broadcast and empty MAC addresses identically" do
      for address <- [:broadcast, <<>>], network <- [0, 65_535] do
        source = %ValueSource{
          type: :address,
          object: nil,
          address: %RecipientAddress{network: network, address: address}
        }

        assert {:ok, [constructed: {2, [unsigned_integer: ^network, octet_string: <<>>], 0}]} =
                 ValueSource.encode(source)
      end
    end

    test "rejects unsupported choices" do
      for type <- [nil, :unknown, false, 1, "object", %{}] do
        source = %ValueSource{
          type: type,
          object: @local_ref,
          address: %RecipientAddress{network: 1, address: @mac}
        }

        refute ValueSource.valid?(source)
        assert {:error, :invalid_value} = ValueSource.encode(source)
      end
    end

    test "rejects missing or mismatched selected fields" do
      for source <- [
            %ValueSource{type: :object, object: nil, address: nil},
            %ValueSource{type: :address, object: nil, address: nil},
            %ValueSource{
              type: :object,
              object: %RecipientAddress{network: 1, address: @mac},
              address: nil
            },
            %ValueSource{type: :address, object: nil, address: @local_ref},
            %ValueSource{
              type: :object,
              object: nil,
              address: %RecipientAddress{network: 1, address: @mac}
            },
            %ValueSource{type: :address, object: @local_ref, address: nil}
          ] do
        refute ValueSource.valid?(source)
        assert {:error, :invalid_value} = ValueSource.encode(source)
      end
    end

    test "encodes and validates only the field selected by type" do
      address = %RecipientAddress{network: 1, address: @mac}

      for {type, tags} <- [
            none: [tagged: {0, <<>>, 0}],
            object: [constructed: {1, @local_tags, 0}],
            address: [constructed: {2, [unsigned_integer: 1, octet_string: @mac], 0}]
          ] do
        source = %ValueSource{type: type, object: @local_ref, address: address}

        assert ValueSource.valid?(source)
        assert {:ok, ^tags} = ValueSource.encode(source)
      end
    end

    test "rejects invalid object and device identifiers" do
      for ref <- [
            %{@local_ref | object_identifier: nil},
            %{@local_ref | object_identifier: %ObjectIdentifier{type: :unknown, instance: 0}},
            %{
              @local_ref
              | object_identifier: %ObjectIdentifier{type: :analog_input, instance: -1}
            },
            %{
              @remote_ref
              | device_identifier: %ObjectIdentifier{type: :analog_input, instance: 21}
            },
            %{@remote_ref | device_identifier: :invalid}
          ] do
        assert {:error, :invalid_value} =
                 ValueSource.encode(%ValueSource{type: :object, object: ref, address: nil})
      end
    end

    test "rejects invalid address fields" do
      for {network, address} <- [
            {-1, @mac},
            {65_536, @mac},
            {1.0, @mac},
            {"1", @mac},
            {0, nil},
            {0, [1, 2, 3]},
            {0, <<1::size(1)>>}
          ] do
        source = %ValueSource{
          type: :address,
          object: nil,
          address: %RecipientAddress{network: network, address: address}
        }

        assert {:error, :invalid_value} = ValueSource.encode(source)
      end
    end
  end

  describe "parse/1" do
    test "parses none and preserves outer tags" do
      rest = [unsigned_integer: 42, null: nil]

      assert {:ok, {%ValueSource{type: :none, object: nil, address: nil}, ^rest}} =
               ValueSource.parse([{:tagged, {0, <<>>, 0}} | rest])
    end

    test "parses a local object from a list or a single nested tag" do
      for tags <- [@local_tags, hd(@local_tags)] do
        assert {:ok, {%ValueSource{type: :object, object: @local_ref, address: nil}, []}} =
                 ValueSource.parse(constructed: {1, tags, 0})
      end
    end

    test "parses a remote object and preserves outer tags" do
      rest = [tagged: {0, <<>>, 0}]

      assert {:ok, {%ValueSource{type: :object, object: @remote_ref, address: nil}, ^rest}} =
               ValueSource.parse([{:constructed, {1, @remote_tags, 0}} | rest])
    end

    test "parses a unicast address and preserves outer tags" do
      rest = [boolean: true]

      assert {:ok,
              {%ValueSource{
                 type: :address,
                 object: nil,
                 address: %RecipientAddress{network: 1, address: @mac}
               }, ^rest}} =
               ValueSource.parse([
                 {:constructed, {2, [unsigned_integer: 1, octet_string: @mac], 0}} | rest
               ])
    end

    test "normalizes a zero-length MAC address to broadcast at network boundaries" do
      for network <- [0, 65_535] do
        assert {:ok,
                {%ValueSource{
                   type: :address,
                   object: nil,
                   address: %RecipientAddress{network: ^network, address: :broadcast}
                 }, []}} =
                 ValueSource.parse(
                   constructed: {2, [unsigned_integer: network, octet_string: <<>>], 0}
                 )
      end
    end

    test "rejects absent, unknown, or incorrectly tagged choices" do
      for tags <- [
            [],
            [null: nil],
            [tagged: {3, <<>>, 0}],
            [constructed: {3, [], 0}],
            [constructed: {0, [], 0}],
            [tagged: {1, <<>>, 0}],
            [tagged: {2, <<>>, 0}],
            [constructed: {1, @local_tags, 1}],
            [constructed: {2, [unsigned_integer: 0, octet_string: <<>>], 1}],
            [tagged: {0, <<0>>, 1}],
            [tagged: {0, <<0>>, 0}],
            [tagged: {0, <<>>, 1}]
          ] do
        assert {:error, :invalid_tags} = ValueSource.parse(tags)
      end
    end

    test "rejects missing or unexpected object fields" do
      for tags <- [
            [],
            nil,
            [tagged: {0, <<2, 0, 0, 21>>, 4}],
            [unsigned_integer: 1],
            @local_tags ++ [null: nil],
            @remote_tags ++ @local_tags
          ] do
        assert {:error, :invalid_tags} = ValueSource.parse(constructed: {1, tags, 0})
      end
    end

    test "propagates malformed object identifier errors" do
      for {tags, reason} <- [
            {[tagged: {1, <<>>, 0}], :unknown_tag_encoding},
            {[tagged: {1, <<1, 2, 3>>, 3}], :invalid_data},
            {[tagged: {0, <<1, 2, 3, 4, 5>>, 5}] ++ @local_tags, :invalid_data}
          ] do
        assert {:error, ^reason} = ValueSource.parse(constructed: {1, tags, 0})
      end
    end

    test "requires exactly two address fields in the correct order and of the correct types" do
      for tags <- [
            [],
            nil,
            {:unsigned_integer, 0},
            [unsigned_integer: 0],
            [octet_string: @mac],
            [octet_string: @mac, unsigned_integer: 0],
            [signed_integer: 0, octet_string: @mac],
            [unsigned_integer: 0, character_string: "mac"],
            [unsigned_integer: 0, octet_string: @mac, null: nil],
            [tagged: {0, <<0>>, 1}, tagged: {1, @mac, 6}]
          ] do
        assert {:error, :invalid_tags} = ValueSource.parse(constructed: {2, tags, 0})
      end
    end

    test "rejects address values outside their types and network range" do
      for {network, address} <- [
            {-1, @mac},
            {65_536, @mac},
            {1.0, @mac},
            {:local, @mac},
            {0, :broadcast},
            {0, nil},
            {0, [1, 2]},
            {0, <<1::size(1)>>}
          ] do
        assert {:error, :invalid_tags} =
                 ValueSource.parse(
                   constructed: {2, [unsigned_integer: network, octet_string: address], 0}
                 )
      end
    end

    test "leaves semantic validation of a parsed device identifier to valid?/1" do
      tags = [tagged: {0, <<0, 0, 0, 21>>, 4}] ++ @local_tags
      assert {:ok, {source, []}} = ValueSource.parse(constructed: {1, tags, 0})
      refute ValueSource.valid?(source)
    end

    test "consumes only the first source in a sequence" do
      tags = [tagged: {0, <<>>, 0}, constructed: {1, @remote_tags, 0}]

      assert {:ok, {%ValueSource{type: :none, object: nil, address: nil}, rest}} =
               ValueSource.parse(tags)

      assert {:ok, {%ValueSource{type: :object, object: @remote_ref, address: nil}, []}} =
               ValueSource.parse(rest)
    end
  end

  describe "valid?/1" do
    test "accepts none, local references, remote references, and Device object sources" do
      assert ValueSource.valid?(%ValueSource{type: :none, object: nil, address: nil})

      for value <- [
            @local_ref,
            @remote_ref,
            %{@local_ref | object_identifier: %ObjectIdentifier{type: :device, instance: 21}},
            %{@local_ref | object_identifier: %ObjectIdentifier{type: 1023, instance: 4_194_303}}
          ] do
        assert ValueSource.valid?(%ValueSource{type: :object, object: value, address: nil})
      end
    end

    test "accepts all valid networks and raw binary MAC lengths" do
      for network <- [0, 1, 65_534, 65_535], address <- [<<>>, @mac, <<255>>, :broadcast] do
        assert ValueSource.valid?(%ValueSource{
                 type: :address,
                 object: nil,
                 address: %RecipientAddress{network: network, address: address}
               })
      end
    end

    test "rejects invalid object references and unsupported values" do
      for value <- [
            :none,
            false,
            %{},
            %{network: 0, address: @mac},
            %ObjectIdentifier{type: :device, instance: 21},
            %{@local_ref | object_identifier: nil},
            %{
              @local_ref
              | object_identifier: %ObjectIdentifier{type: :analog_input, instance: -1}
            },
            %{
              @local_ref
              | object_identifier: %ObjectIdentifier{type: :analog_input, instance: 4_194_304}
            },
            %{@remote_ref | device_identifier: :invalid},
            %{
              @remote_ref
              | device_identifier: %ObjectIdentifier{type: :analog_input, instance: 21}
            }
          ] do
        refute ValueSource.valid?(%ValueSource{type: :object, object: value, address: nil})
      end
    end

    test "rejects invalid address structures" do
      for address <- [
            %RecipientAddress{network: -1, address: @mac},
            %RecipientAddress{network: 65_536, address: @mac},
            %RecipientAddress{network: 0.0, address: @mac},
            %RecipientAddress{network: nil, address: @mac},
            %RecipientAddress{network: 0, address: nil},
            %RecipientAddress{network: 0, address: <<1::size(1)>>}
          ] do
        refute ValueSource.valid?(%ValueSource{type: :address, object: nil, address: address})
      end
    end
  end

  describe "wire encoding" do
    test "matches independent BACnet wire examples for every alternative" do
      examples = [
        {%ValueSource{type: :none, object: nil, address: nil}, <<0x08>>},
        {%ValueSource{type: :object, object: @local_ref, address: nil},
         <<0x1E, 0x1C, 0, 0, 0, 24, 0x1F>>},
        {%ValueSource{type: :object, object: @remote_ref, address: nil},
         <<0x1E, 0x0C, 2, 0, 0, 21, 0x1C, 0, 0, 0, 24, 0x1F>>},
        {%ValueSource{
           type: :address,
           object: nil,
           address: %RecipientAddress{network: 1, address: @mac}
         }, <<0x2E, 0x21, 1, 0x65, 6, @mac::binary, 0x2F>>},
        {%ValueSource{
           type: :address,
           object: nil,
           address: %RecipientAddress{network: 0, address: :broadcast}
         }, <<0x2E, 0x21, 0, 0x60, 0x2F>>},
        {%ValueSource{
           type: :address,
           object: nil,
           address: %RecipientAddress{network: 65_535, address: :broadcast}
         }, <<0x2E, 0x22, 255, 255, 0x60, 0x2F>>}
      ]

      for {source, wire} <- examples do
        assert {:ok, [tag]} = ValueSource.encode(source)
        assert {:ok, ^wire} = ApplicationTags.encode(tag)
        assert {:ok, decoded, <<>>} = ApplicationTags.decode(wire)
        assert {:ok, {^source, []}} = ValueSource.parse([decoded])
      end
    end

    test "normalizes an empty binary MAC after a wire round trip" do
      source = %ValueSource{
        type: :address,
        object: nil,
        address: %RecipientAddress{network: 0, address: <<>>}
      }

      assert {:ok, [tag]} = ValueSource.encode(source)
      assert {:ok, wire} = ApplicationTags.encode(tag)
      assert {:ok, decoded, <<>>} = ApplicationTags.decode(wire)

      assert {:ok,
              {%ValueSource{
                 type: :address,
                 object: nil,
                 address: %RecipientAddress{network: 0, address: :broadcast}
               }, []}} =
               ValueSource.parse([decoded])
    end
  end
end
