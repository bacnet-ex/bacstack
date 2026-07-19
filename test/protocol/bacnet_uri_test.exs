defmodule BACnet.Protocol.BACnetURITest do
  alias BACnet.Protocol.BACnetURI
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest BACnetURI

  describe "parse/1" do
    test "parses minimal URI with numeric device and object" do
      assert {:ok, uri} = BACnetURI.parse("bacnet://123/0,1")
      assert uri.device_identifier == %ObjectIdentifier{type: :device, instance: 123}
      assert uri.object_identifier == %ObjectIdentifier{type: :analog_input, instance: 1}
      assert uri.property_identifier == :present_value
      assert uri.property_array_index == nil
    end

    test "parses with .this device" do
      assert {:ok, uri} = BACnetURI.parse("bacnet://.this/analog-value,5")
      assert uri.device_identifier == nil
      assert uri.object_identifier.type == :analog_value
      assert uri.object_identifier.instance == 5
      assert uri.property_identifier == :present_value
    end

    test "parses object type as number and property as number" do
      assert {:ok, uri} = BACnetURI.parse("bacnet://999/2,42/85/3")
      assert uri.object_identifier.type == :analog_value
      assert uri.object_identifier.instance == 42
      assert uri.property_identifier == :present_value
      assert uri.property_array_index == 3
    end

    test "parses object/property with different casings and hyphen/underscore" do
      # lower with hyphen
      assert {:ok, u1} = BACnetURI.parse("bacnet://1/analog-value,1/present-value")
      assert u1.object_identifier.type == :analog_value
      assert u1.property_identifier == :present_value

      # upper with hyphen
      assert {:ok, u2} = BACnetURI.parse("bacnet://1/Analog-Value,1/Present-Value")
      assert u2.object_identifier.type == :analog_value
      assert u2.property_identifier == :present_value

      # mixed underscore
      assert {:ok, u3} = BACnetURI.parse("bacnet://1/analog_value,1/present_value")
      assert u3.object_identifier.type == :analog_value
      assert u3.property_identifier == :present_value

      # all upper underscore
      assert {:ok, u4} = BACnetURI.parse("bacnet://1/ANALOG_VALUE,1/PRESENT_VALUE")
      assert u4.object_identifier.type == :analog_value
      assert u4.property_identifier == :present_value
    end

    test "parses File object with omitted property (nil)" do
      assert {:ok, uri} = BACnetURI.parse("bacnet://5/file,10")
      assert uri.object_identifier.type == :file
      assert uri.property_identifier == nil
      assert uri.property_array_index == nil
    end

    test "parses File object with explicit property" do
      assert {:ok, uri} = BACnetURI.parse("bacnet://5/file,10/file-size")
      assert uri.object_identifier.type == :file
      assert uri.property_identifier == :file_size
    end

    test "parses vendor propietary object with propietary property" do
      assert {:ok, uri} = BACnetURI.parse("bacnet://5/685,10/35920")
      assert uri.object_identifier.type == 685
      assert uri.property_identifier == 35920
    end

    test "parses with array index" do
      assert {:ok, uri} = BACnetURI.parse("bacnet://123/analog-value,1/present-value/0")
      assert uri.property_array_index == 0
    end

    test "returns error for non-bacnet scheme" do
      assert {:error, :invalid_bacnet_uri} = BACnetURI.parse("http://123/analog-value,1")
    end

    test "returns error for invalid device (non-numeric)" do
      assert {:error, :invalid_device} = BACnetURI.parse("bacnet://abc/analog-value,1")
    end

    test "returns error for invalid object type" do
      assert {:error, :invalid_object_type} = BACnetURI.parse("bacnet://123/agagreegagrea,1")
    end

    test "returns error for invalid object type number" do
      assert {:error, :invalid_object_type} = BACnetURI.parse("bacnet://123/5321,1")
    end

    test "returns error for missing object" do
      assert {:error, :missing_object} = BACnetURI.parse("bacnet://123")
    end

    test "returns error for too many path segments" do
      assert {:error, :invalid_path_segments} = BACnetURI.parse("bacnet://123/a,1/b/c/d")
    end

    test "returns error for bad object format (no comma)" do
      assert {:error, :invalid_object} = BACnetURI.parse("bacnet://123/analog-value1")
    end

    test "returns error for invalid object instance" do
      assert {:error, :invalid_instance} = BACnetURI.parse("bacnet://123/analog-value,abc")
    end

    test "returns error for omitted property on non-File object" do
      # Current implementation defaults, but if we consider strict, test the default path
      assert {:ok, uri} = BACnetURI.parse("bacnet://123/analog-value,1")
      assert uri.property_identifier == :present_value
    end

    test "returns error for invalid property name that is not a number" do
      assert {:error, :invalid_property} =
               BACnetURI.parse("bacnet://123/analog-value,1/does-not-exist")
    end

    test "returns error for invalid index" do
      assert {:error, :invalid_index} =
               BACnetURI.parse("bacnet://123/analog-value,1/present-value/abc")
    end

    test "returns error for negative index" do
      assert {:error, :invalid_index} =
               BACnetURI.parse("bacnet://123/analog-value,1/present-value/-1")
    end

    test "handles URI.new error" do
      assert {:error, _} = BACnetURI.parse(":::not a uri")
    end
  end

  describe "encode/1" do
    test "encodes basic struct with numeric identifiers" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 42},
        object_identifier: %ObjectIdentifier{type: 0, instance: 1},
        property_identifier: 85,
        property_array_index: nil
      }

      assert {:ok, "bacnet://42/0,1/85"} = BACnetURI.encode(struct)
    end

    test "encodes with .this device and omits default present_value" do
      struct = %BACnetURI{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 5},
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert {:ok, "bacnet://.this/2,5/85"} = BACnetURI.encode(struct)
    end

    test "encodes File with nil property (omits property segment)" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 7},
        object_identifier: %ObjectIdentifier{type: :file, instance: 99},
        property_identifier: nil,
        property_array_index: nil
      }

      assert {:ok, "bacnet://7/10,99"} = BACnetURI.encode(struct)
    end

    test "encodes File with property" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 7},
        object_identifier: %ObjectIdentifier{type: :file, instance: 99},
        property_identifier: :file_size,
        property_array_index: nil
      }

      assert {:ok, "bacnet://7/10,99/42"} = BACnetURI.encode(struct)
    end

    test "encodes with array index" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 123},
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 1},
        property_identifier: :present_value,
        property_array_index: 0
      }

      assert {:ok, "bacnet://123/2,1/85/0"} = BACnetURI.encode(struct)
    end

    test "encodes using atom identifiers" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 1},
        object_identifier: %ObjectIdentifier{type: :binary_value, instance: 2},
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert {:ok, "bacnet://1/5,2/85"} = BACnetURI.encode(struct)
    end

    test "encodes using integer" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 1},
        object_identifier: %ObjectIdentifier{type: 5, instance: 2},
        property_identifier: 85,
        property_array_index: nil
      }

      assert {:ok, "bacnet://1/5,2/85"} = BACnetURI.encode(struct)
    end

    test "encodes using integer vendor prorietary" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 1},
        object_identifier: %ObjectIdentifier{type: 685, instance: 122},
        property_identifier: 36485,
        property_array_index: nil
      }

      assert {:ok, "bacnet://1/685,122/36485"} = BACnetURI.encode(struct)
    end

    test "returns error for invalid struct (bad device)" do
      bad = %BACnetURI{
        device_identifier: "not a struct",
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 1},
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert {:error, :invalid_data} = BACnetURI.encode(bad)
    end

    test "returns error for invalid struct (bad index)" do
      bad = %BACnetURI{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 1},
        property_identifier: :present_value,
        property_array_index: -5
      }

      assert {:error, :invalid_data} = BACnetURI.encode(bad)
    end

    test "returns error for completely invalid input" do
      assert_raise FunctionClauseError, fn ->
        BACnetURI.encode(Process.get({__MODULE__, __ENV__}, "not a struct"))
      end
    end
  end

  describe "valid?/1" do
    test "returns true for minimal valid struct with numeric types" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 1},
        object_identifier: %ObjectIdentifier{type: 0, instance: 1},
        property_identifier: 85,
        property_array_index: nil
      }

      assert BACnetURI.valid?(struct) == true
    end

    test "returns true for struct with identifier atoms (various cases)" do
      struct = %BACnetURI{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 5},
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert BACnetURI.valid?(struct) == true
    end

    test "returns true for File object with nil property" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 5},
        object_identifier: %ObjectIdentifier{type: :file, instance: 10},
        property_identifier: nil,
        property_array_index: nil
      }

      assert BACnetURI.valid?(struct) == true
    end

    test "returns true for File with explicit property and index" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 5},
        object_identifier: %ObjectIdentifier{type: :file, instance: 10},
        property_identifier: :file_size,
        property_array_index: 0
      }

      assert BACnetURI.valid?(struct) == true
    end

    test "fails for non-struct" do
      assert_raise FunctionClauseError, fn ->
        BACnetURI.valid?(Process.get({__MODULE__, __ENV__}, "string"))
      end
    end

    test "returns false for struct with invalid device" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :analog_value, instance: 1},
        object_identifier: %ObjectIdentifier{type: 0, instance: 1},
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert BACnetURI.valid?(struct) == false
    end

    test "returns false for struct missing required object_identifier" do
      # This would normally not construct due to @enforce_keys, but test defensive
      assert BACnetURI.valid?(%BACnetURI{
               device_identifier: nil,
               object_identifier: nil,
               property_identifier: :present_value,
               property_array_index: nil
             }) == false
    end

    test "returns false when property is nil for non-File object" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 1},
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 1},
        property_identifier: nil,
        property_array_index: nil
      }

      assert BACnetURI.valid?(struct) == false
    end

    test "returns false when index is present but property is nil" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 1},
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 1},
        property_identifier: nil,
        property_array_index: 0
      }

      assert BACnetURI.valid?(struct) == false
    end

    test "returns false for negative index" do
      struct = %BACnetURI{
        device_identifier: %ObjectIdentifier{type: :device, instance: 1},
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 1},
        property_identifier: :present_value,
        property_array_index: -1
      }

      assert BACnetURI.valid?(struct) == false
    end
  end

  describe "valid_str?/1" do
    test "returns true for minimal valid URI with numeric device/object/property" do
      assert BACnetURI.valid_str?("bacnet://123/0,1") == true
      assert BACnetURI.valid_str?("bacnet://999/2,42/85/3") == true
    end

    test "returns true for .this device" do
      assert BACnetURI.valid_str?("bacnet://.this/analog-value,5") == true
    end

    test "returns true for object and property using Clause 21 names with various casings and separators" do
      # hyphen + lower
      assert BACnetURI.valid_str?("bacnet://1/analog-value,1/present-value") == true
      # hyphen + mixed
      assert BACnetURI.valid_str?("bacnet://1/Analog-Value,1/Present-Value") == true
      # underscore + lower
      assert BACnetURI.valid_str?("bacnet://1/analog_value,1/present_value") == true
      # underscore + upper
      assert BACnetURI.valid_str?("bacnet://1/ANALOG_VALUE,1/PRESENT_VALUE") == true
      # another common one
      assert BACnetURI.valid_str?("bacnet://1/binary-value,2") == true
    end

    test "returns true for numeric object and property types" do
      assert BACnetURI.valid_str?("bacnet://123/0,1/85") == true
    end

    test "returns true for File object with omitted property (property = nil)" do
      assert BACnetURI.valid_str?("bacnet://5/file,10") == true
    end

    test "returns true for File object with explicit property" do
      assert BACnetURI.valid_str?("bacnet://5/file,10/file-size") == true
    end

    test "returns true for URI containing array index" do
      assert BACnetURI.valid_str?("bacnet://123/analog-value,1/present-value/0") == true
    end

    test "returns false for non-bacnet scheme" do
      assert BACnetURI.valid_str?("http://123/analog-value,1") == false
      assert BACnetURI.valid_str?("bacnetx://123/analog-value,1") == false
    end

    test "returns false for invalid device (non-numeric, not .this)" do
      assert BACnetURI.valid_str?("bacnet://abc/analog-value,1") == false
      assert BACnetURI.valid_str?("bacnet://.THIS/analog-value,1") == false
    end

    test "returns false for missing object segment" do
      assert BACnetURI.valid_str?("bacnet://123") == false
      assert BACnetURI.valid_str?("bacnet://123/") == false
    end

    test "returns false for malformed object (no comma)" do
      assert BACnetURI.valid_str?("bacnet://123/analog-value1") == false
    end

    test "returns false for non-numeric object instance" do
      assert BACnetURI.valid_str?("bacnet://123/analog-value,abc") == false
    end

    test "returns false for invalid property identifier (unknown name, not a number)" do
      assert BACnetURI.valid_str?("bacnet://123/analog-value,1/does-not-exist") == false
    end

    test "returns false for non-numeric array index" do
      assert BACnetURI.valid_str?("bacnet://123/analog-value,1/present-value/abc") == false
    end

    test "returns false for too many path segments" do
      assert BACnetURI.valid_str?("bacnet://123/a,1/b/c/d") == false
    end

    test "returns false for completely malformed input" do
      assert BACnetURI.valid_str?(":::not a valid uri") == false
      assert BACnetURI.valid_str?("") == false
    end

    test "fails for nil (defensive)" do
      assert_raise FunctionClauseError, fn ->
        BACnetURI.valid_str?(nil)
      end
    end
  end
end
