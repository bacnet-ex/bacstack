defmodule BACnet.Test.Protocol.ObjectsUtilityTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.AnalogOutput
  alias BACnet.Protocol.ObjectTypes.BinaryInput
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Protocol.ReadAccessResult
  alias BACnet.Protocol.ReadAccessResult.ReadResult
  alias BACnet.Protocol.Services.Ack.ReadPropertyAck
  alias BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck

  use ExUnit.Case, async: false

  @moduletag :objects_utility

  doctest ObjectsUtility

  # Model vendor-specific property types and codecs without changing built-in objects.
  defmodule VendorObject do
    @moduledoc false
    defstruct _metadata: %{properties_list: [:description]}, description: "vendor object"
    def get_properties_type_map(), do: Process.get({__MODULE__, :types}, %{})
    def get_annotation(_property), do: Process.get({__MODULE__, :annotations}, [])
  end

  defmodule MissingCodec do
    @moduledoc false
    defstruct [:value]
  end

  defmodule StreamingValue do
    @moduledoc false
    defstruct [:value]

    @spec from_app_encoding(BACnet.Protocol.ApplicationTags.encoding_list()) ::
            {:ok, {%__MODULE__{value: term()}, BACnet.Protocol.ApplicationTags.encoding_list()}}
            | {:error, :invalid_value}
    def from_app_encoding(tags)

    def from_app_encoding([{:unsigned_integer, value} | rest]),
      do: {:ok, {%__MODULE__{value: value}, rest}}

    def from_app_encoding(_tags), do: {:error, :invalid_value}
  end

  defmodule ParsedValue do
    @moduledoc false
    defstruct [:value]

    @spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
            {:ok, {%__MODULE__{value: term()}, BACnet.Protocol.ApplicationTags.encoding_list()}}
            | {:error, :invalid_value}
    def parse(tags)

    def parse([{:unsigned_integer, value} | rest]),
      do: {:ok, {%__MODULE__{value: value}, rest}}

    def parse(_tags), do: {:error, :invalid_value}
  end

  defmodule BrokenCodec do
    @moduledoc false
    defstruct [:value]
    @spec valid?(term()) :: boolean()
    def valid?(value)

    def valid?(%{value: :invalid}), do: raise("validation failed")
    def valid?(_value), do: true
    def to_app_encoding(_value), do: raise("encoding failed")
  end

  @object_id %ObjectIdentifier{type: :binary_input, instance: 7}
  @vendor_id %ObjectIdentifier{type: :coverage_vendor, instance: 1}

  test "cast property to value with any type" do
    {:module, stub, _bytecode, _more} =
      defmodule BacObjectMinimalTestStubForCastPropertyToValue do
        use BACnet.Protocol.ObjectsMacro

        @type object_opts :: nil

        bac_object :network_port do
          services(intrinsic: false)

          field(:description, String.t())
          field(:device_type, term())
        end
      end

    old = ObjectsUtility.get_object_type_mappings()[:network_port]
    ObjectsUtility.put_object_type_mapping(:network_port, stub)

    try do
      assert {:ok, %Encoding{value: :ok}} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :network_port, instance: 1},
                 :device_type,
                 %Encoding{encoding: :primitive, extras: [], type: nil, value: :ok},
                 []
               )
    after
      if old,
        do: ObjectsUtility.put_object_type_mapping(:network_port, old),
        else: ObjectsUtility.delete_object_type_mapping(:network_port)
    end
  end

  test "cast property to value with list any type" do
    {:module, stub, _bytecode, _more} =
      defmodule BacObjectMinimalTestStubForCastPropertyToValueList do
        use BACnet.Protocol.ObjectsMacro

        @type object_opts :: nil

        bac_object :network_port do
          services(intrinsic: false)

          field(:description, String.t())
          field(:device_type, [term()])
        end
      end

    old = ObjectsUtility.get_object_type_mappings()[:network_port]
    ObjectsUtility.put_object_type_mapping(:network_port, stub)

    try do
      assert {:ok, [:ok, :else]} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :network_port, instance: 1},
                 :device_type,
                 [:ok, :else],
                 []
               )
    after
      if old,
        do: ObjectsUtility.put_object_type_mapping(:network_port, old),
        else: ObjectsUtility.delete_object_type_mapping(:network_port)
    end
  end

  test "cast property to value with list any type valid input" do
    {:module, stub, _bytecode, _more} =
      defmodule BacObjectMinimalTestStubForCastPropertyToValueListInvalid do
        use BACnet.Protocol.ObjectsMacro

        @type object_opts :: nil

        bac_object :network_port do
          services(intrinsic: false)

          field(:description, String.t())
          field(:device_type, [term()])
        end
      end

    old = ObjectsUtility.get_object_type_mappings()[:network_port]
    ObjectsUtility.put_object_type_mapping(:network_port, stub)

    try do
      assert {:ok, [%Encoding{}]} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :network_port, instance: 1},
                 :device_type,
                 %Encoding{encoding: :primitive, extras: [], type: nil, value: :ok},
                 []
               )
    after
      if old,
        do: ObjectsUtility.put_object_type_mapping(:network_port, old),
        else: ObjectsUtility.delete_object_type_mapping(:network_port)
    end
  end

  test "cast property to value constants with known succeeds as atom" do
    assert {:ok, :no_fault_detected} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :reliability,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 0}
             )
  end

  test "cast property to value constants with unknown fails" do
    assert {:error, {:invalid_property_value, {:reliability, 65_536}}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :reliability,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536}
             )
  end

  test "cast property to value struct with invalid fails" do
    assert {:error, {:invalid_tags, {:tags, %Encoding{}}}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :tags,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536}
             )
  end

  test "cast property to value constants with allow_numeric_constants and known succeeds as atom" do
    assert {:ok, :no_fault_detected} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :reliability,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 0},
               allow_numeric_constants: true
             )
  end

  test "cast property to value constants with allow_numeric_constants and unknown succeeds as integer" do
    assert {:ok, 65_536} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :reliability,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536},
               allow_numeric_constants: true
             )
  end

  test "cast property to value accepts allow_unknown_properties as false and rejects" do
    assert {:error, {:unknown_property, :fault_high_limit}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :fault_high_limit,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536},
               allow_unknown_properties: false
             )
  end

  test "cast property to value accepts allow_unknown_properties as true" do
    assert {:ok, 65_536} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :fault_high_limit,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536},
               allow_unknown_properties: true
             )
  end

  test "cast property to value accepts allow_unknown_properties as no_unpack" do
    assert {:ok, %Encoding{value: 65_536}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :fault_high_limit,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536},
               allow_unknown_properties: :no_unpack
             )
  end

  test "cast property to value accepts numeric identfier and casts it to atom" do
    assert {:error, {:invalid_property_value, {:present_value, 65_536}}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               85,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536},
               allow_unknown_properties: true
             )
  end

  test "cast property to value rejects unknown numeric identfier if not allowed" do
    assert {:error, {:unknown_property, 123_432_585}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               123_432_585,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536}
             )
  end

  test "cast property to value accepts unknown numeric identfier if allowed" do
    assert {:ok, 65_536} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               123_432_585,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536},
               allow_unknown_properties: true
             )
  end

  test "cast property to value struct simple error atom transforms" do
    assert {:error, {:invalid_tags, {:status_flags, %Encoding{}}}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :status_flags,
               %Encoding{encoding: :primitive, extras: [], type: :enumerated, value: 65_536}
             )
  end

  test "cast property to value struct simple error atom transforms 2" do
    assert {:error, {:invalid_tags, {:tags, _value}}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :binary_input, instance: 1},
               :tags,
               [
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :character_string,
                   value: "test"
                 },
                 %Encoding{
                   encoding: :constructed,
                   extras: [tag_number: 1],
                   type: nil,
                   value: {:tagged, {0, <<>>, 0}}
                 }
               ]
             )
  end

  test "cast value to property struct simple error atom transforms" do
    assert {:error, {:invalid_property_value, {:ip_address, <<0>>}}} =
             ObjectsUtility.cast_value_to_property(
               %ObjectIdentifier{type: :network_port, instance: 1},
               :ip_address,
               <<0>>,
               []
             )
  end

  test "cast property to value array single element succeeds" do
    assert {:ok, %BACnetArray{size: 1}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :bitstring_value, instance: 1},
               :bit_text,
               %Encoding{encoding: :primitive, extras: [], type: :character_string, value: "Low"}
             )
  end

  test "cast property to value fixed size 1-array single element succeeds" do
    {:module, stub, _bytecode, _more} =
      defmodule BacObjectMinimalTestStubForCastPropertyToValueSingleArrayElement do
        use BACnet.Protocol.ObjectsMacro

        @type object_opts :: nil

        bac_object :network_port do
          services(intrinsic: false)

          field(:description, String.t())
          field(:device_type, term())
          field(:bit_text, BACnetArray.t(String.t(), 1))
        end
      end

    old = ObjectsUtility.get_object_type_mappings()[:network_port]
    ObjectsUtility.put_object_type_mapping(:network_port, stub)

    try do
      assert {:ok, %BACnetArray{size: 1}} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :network_port, instance: 1},
                 :bit_text,
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :character_string,
                   value: "Hello"
                 },
                 []
               )
    after
      if old,
        do: ObjectsUtility.put_object_type_mapping(:network_port, old),
        else: ObjectsUtility.delete_object_type_mapping(:network_port)
    end
  end

  test "cast property to value fixed size non 1-array single element fails" do
    {:module, stub, _bytecode, _more} =
      defmodule BacObjectMinimalTestStubForCastPropertyToValueSingleArrayElementFails do
        use BACnet.Protocol.ObjectsMacro

        @type object_opts :: nil

        bac_object :network_port do
          services(intrinsic: false)

          field(:description, String.t())
          field(:device_type, term())
          field(:bit_text, BACnetArray.t(String.t(), 2))
        end
      end

    old = ObjectsUtility.get_object_type_mappings()[:network_port]
    ObjectsUtility.put_object_type_mapping(:network_port, stub)

    try do
      assert {:error, {:invalid_property_value, {:bit_text, "Hello"}}} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :network_port, instance: 1},
                 :bit_text,
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :character_string,
                   value: "Hello"
                 },
                 []
               )
    after
      if old,
        do: ObjectsUtility.put_object_type_mapping(:network_port, old),
        else: ObjectsUtility.delete_object_type_mapping(:network_port)
    end
  end

  test "validate float range with empty object succeeds" do
    assert ObjectsUtility.validate_float_range(:NaN, %{})
    assert ObjectsUtility.validate_float_range(:inf, %{})
    assert ObjectsUtility.validate_float_range(:infn, %{})
    assert ObjectsUtility.validate_float_range(3.14, %{})
  end

  test "validate float range with missing min present value succeeds" do
    assert ObjectsUtility.validate_float_range(:NaN, %{max_present_value: 1})
    assert ObjectsUtility.validate_float_range(:inf, %{max_present_value: 1})
    assert ObjectsUtility.validate_float_range(:infn, %{max_present_value: 1})
    assert ObjectsUtility.validate_float_range(3.14, %{max_present_value: 1})
  end

  test "validate float range with missing max present value succeeds" do
    assert ObjectsUtility.validate_float_range(:NaN, %{max_present_value: 10})
    assert ObjectsUtility.validate_float_range(:inf, %{max_present_value: 10})
    assert ObjectsUtility.validate_float_range(:infn, %{max_present_value: 10})
    assert ObjectsUtility.validate_float_range(3.14, %{max_present_value: 10})
  end

  test "validate float range with min/max present value floats" do
    assert ObjectsUtility.validate_float_range(3.0, %{
             min_present_value: 2.0,
             max_present_value: 4.0
           })

    refute ObjectsUtility.validate_float_range(1.0, %{
             min_present_value: 2.0,
             max_present_value: 4.0
           })

    refute ObjectsUtility.validate_float_range(5.0, %{
             min_present_value: 2.0,
             max_present_value: 4.0
           })
  end

  test "validate float range with min present value special atoms" do
    refute ObjectsUtility.validate_float_range(3.0, %{
             min_present_value: :inf,
             max_present_value: 4.0
           })

    refute ObjectsUtility.validate_float_range(:inf, %{
             min_present_value: :inf,
             max_present_value: 4.0
           })

    assert ObjectsUtility.validate_float_range(:NaN, %{
             min_present_value: :inf,
             max_present_value: 4.0
           })

    assert ObjectsUtility.validate_float_range(3.0, %{
             min_present_value: :infn,
             max_present_value: 4.0
           })

    assert ObjectsUtility.validate_float_range(:infn, %{
             min_present_value: :infn,
             max_present_value: 4.0
           })

    assert ObjectsUtility.validate_float_range(:NaN, %{
             min_present_value: :infn,
             max_present_value: 4.0
           })

    assert ObjectsUtility.validate_float_range(3.0, %{
             min_present_value: :NaN,
             max_present_value: 4.0
           })

    assert ObjectsUtility.validate_float_range(:inf, %{
             min_present_value: :NaN,
             max_present_value: 4.0
           })

    assert ObjectsUtility.validate_float_range(:infn, %{
             min_present_value: :NaN,
             max_present_value: 4.0
           })

    assert ObjectsUtility.validate_float_range(:NaN, %{
             min_present_value: :NaN,
             max_present_value: 4.0
           })
  end

  test "validate float range with max present value special atoms" do
    assert ObjectsUtility.validate_float_range(3.0, %{
             min_present_value: 2.0,
             max_present_value: :inf
           })

    refute ObjectsUtility.validate_float_range(3.0, %{
             min_present_value: 2.0,
             max_present_value: :infn
           })

    refute ObjectsUtility.validate_float_range(:infn, %{
             min_present_value: 2.0,
             max_present_value: :infn
           })

    assert ObjectsUtility.validate_float_range(:NaN, %{
             min_present_value: 2.0,
             max_present_value: :infn
           })

    assert ObjectsUtility.validate_float_range(3.0, %{
             min_present_value: 2.0,
             max_present_value: :NaN
           })

    assert ObjectsUtility.validate_float_range(:inf, %{
             min_present_value: 2.0,
             max_present_value: :NaN
           })

    assert ObjectsUtility.validate_float_range(:infn, %{
             min_present_value: 2.0,
             max_present_value: :NaN
           })

    assert ObjectsUtility.validate_float_range(:NaN, %{
             min_present_value: 2.0,
             max_present_value: :NaN
           })
  end

  test "validate float range with min/max present value special atoms" do
    assert ObjectsUtility.validate_float_range(3.0, %{
             min_present_value: :infn,
             max_present_value: :inf
           })

    assert ObjectsUtility.validate_float_range(:inf, %{
             min_present_value: :infn,
             max_present_value: :inf
           })

    assert ObjectsUtility.validate_float_range(:infn, %{
             min_present_value: :infn,
             max_present_value: :inf
           })

    assert ObjectsUtility.validate_float_range(:NaN, %{
             min_present_value: :infn,
             max_present_value: :inf
           })
  end

  test "get object type mappings" do
    # Assert we always start with a fresh state
    :persistent_term.erase({ObjectsUtility, :object_type_mappings})

    mappings = ObjectsUtility.get_object_type_mappings()

    assert %{} = mappings
    assert map_size(mappings) > 0
    assert %{binary_input: BinaryInput} = mappings
  end

  test "put object type mapping" do
    # Assert we always start with a fresh state
    :persistent_term.erase({ObjectsUtility, :object_type_mappings})

    refute match?(%{global: Global}, ObjectsUtility.get_object_type_mappings())

    ObjectsUtility.put_object_type_mapping(:global, Global)
    assert %{global: Global} = ObjectsUtility.get_object_type_mappings()
  end

  test "put many object type mapping" do
    # Assert we always start with a fresh state
    :persistent_term.erase({ObjectsUtility, :object_type_mappings})

    refute match?(%{global: Global, hello: Hello}, ObjectsUtility.get_object_type_mappings())

    ObjectsUtility.put_many_object_type_mapping(global: Global, hello: Hello)
    assert %{global: Global, hello: Hello} = ObjectsUtility.get_object_type_mappings()
  end

  test "put many object type mapping invalid term" do
    # Assert we always start with a fresh state
    :persistent_term.erase({ObjectsUtility, :object_type_mappings})

    assert_raise ArgumentError, fn ->
      ObjectsUtility.put_many_object_type_mapping([:global])
    end

    assert_raise ArgumentError, fn ->
      ObjectsUtility.put_many_object_type_mapping(global: 5.0)
    end

    assert_raise ArgumentError, fn ->
      ObjectsUtility.put_many_object_type_mapping([{1.0, Global}])
    end

    assert_raise ArgumentError, fn ->
      ObjectsUtility.put_many_object_type_mapping([{:global, Global}, :global])
    end

    assert_raise ArgumentError, fn ->
      ObjectsUtility.put_many_object_type_mapping([{:global, Global}, {1.0, Global}])
    end
  end

  test "delete object type mapping" do
    # Assert we always start with a fresh state
    :persistent_term.erase({ObjectsUtility, :object_type_mappings})

    ObjectsUtility.put_object_type_mapping(:global, Global)

    ObjectsUtility.delete_object_type_mapping(:global)
    refute match?(%{global: Global}, ObjectsUtility.get_object_type_mappings())
  end

  test "read property multiple ack of device all property to device object" do
    ack = get_read_property_multiple_ack_stub()
    dev_expected = get_device_object_for_read_property_multiple_ack_stub()

    assert {:ok, %{} = properties} =
             ObjectsUtility.cast_read_properties_ack(
               %BACnet.Protocol.ObjectIdentifier{
                 type: :device,
                 instance: 1_201_610
               },
               [ack],
               ignore_unknown_properties: true
             )

    assert %{object_name: "Device_0030de5255ca"} = properties

    assert %{
             object_identifier: %BACnet.Protocol.ObjectIdentifier{
               type: :device,
               instance: 1_201_610
             }
           } = properties

    assert {:ok, %BACnet.Protocol.ObjectTypes.Device{} = dev} =
             ObjectsUtility.cast_properties_to_object(
               %BACnet.Protocol.ObjectIdentifier{
                 type: :device,
                 instance: 1_201_610
               },
               properties,
               ignore_unknown_properties: true
             )

    # Due to map keys ordering being unguaranteed, the properties list is UNSORTED,
    # thus we need to sort it for assertion
    assert dev_expected == %{
             dev
             | _metadata: %{
                 dev._metadata
                 | properties_list: Enum.sort(dev._metadata.properties_list),
                   other: %{}
               }
           }
  end

  test "read property multiple ack of device all property to device object with unknown properties" do
    ack = get_read_property_multiple_ack_stub()

    assert {:ok, %{other: 0} = _properties} =
             ObjectsUtility.cast_read_properties_ack(
               %BACnet.Protocol.ObjectIdentifier{
                 type: :device,
                 instance: 1_201_610
               },
               [ack],
               allow_unknown_properties: true
             )
  end

  test "read property multiple ack of device all property to device object with unknown properties no unpack" do
    ack = get_read_property_multiple_ack_stub()

    assert {:ok, %{other: %Encoding{type: :enumerated, value: 0}} = _properties} =
             ObjectsUtility.cast_read_properties_ack(
               %BACnet.Protocol.ObjectIdentifier{
                 type: :device,
                 instance: 1_201_610
               },
               [ack],
               allow_unknown_properties: :no_unpack
             )
  end

  describe "property operations and casting" do
    setup do
      mappings = ObjectsUtility.get_object_type_mappings()
      ObjectsUtility.put_object_type_mapping(:coverage_vendor, VendorObject)
      on_exit(fn -> :persistent_term.put({ObjectsUtility, :object_type_mappings}, mappings) end)
      :ok
    end

    test "property operations delegate to the object's implementation" do
      {:ok, object} = BinaryInput.create(7, "input", %{polarity: :normal})
      refute ObjectsUtility.property_writable?(object, :description)
      assert {:ok, object} = ObjectsUtility.add_property(object, :description, "sensor")
      assert ObjectsUtility.property_writable?(object, :description)
      refute ObjectsUtility.property_writable?(object, :object_name)
      assert {:ok, object} = ObjectsUtility.update_property(object, :description, "updated")
      assert {:ok, "updated"} = ObjectsUtility.get_property(object, :description)
      assert {:ok, object} = ObjectsUtility.remove_property(object, :description)
      refute ObjectsUtility.has_property?(object, :description)
      assert ObjectsUtility.get_properties(object) == object._metadata.properties_list
      refute ObjectsUtility.has_priority_array?(object)
      refute ObjectsUtility.intrinsic_reporting?(object)
      assert ObjectsUtility.get_remote_device_id(object) == nil
      assert ObjectsUtility.property_writable?(%VendorObject{}, :description)

      assert {:error, {:unknown_property, :description}} =
               ObjectsUtility.get_property(object, :description)
    end

    test "priority operations use the highest priority and relinquish default" do
      {:ok, object} = AnalogOutput.create(7, "output", %{relinquish_default: 1.0})
      assert {:ok, object} = ObjectsUtility.set_priority(object, 16, 2.0)
      assert {:ok, object} = ObjectsUtility.set_priority(object, 8, 3.0)
      assert {8, 3.0} = ObjectsUtility.get_priority_value(object)
      assert object.present_value == 3.0
      assert ObjectsUtility.has_priority_array?(object)
      assert {:ok, object} = ObjectsUtility.set_priority(object, 8, nil)
      assert {16, 2.0} = ObjectsUtility.get_priority_value(object)
      assert ObjectsUtility.get_priority_value(%{}) == nil

      assert {:error, {:unknown_property, :priority_array}} =
               ObjectsUtility.set_priority(%{priority_array: nil}, 1, 1.0)
    end

    test "remote object conversion retains the device ID and visible properties" do
      assert {:ok, object} =
               ObjectsUtility.cast_properties_to_object(
                 @object_id,
                 %{
                   object_name: "remote",
                   polarity: :normal,
                   present_value: false,
                   event_state: :normal,
                   status_flags:
                     BACnet.Protocol.StatusFlags.from_bitstring({false, false, false, false}),
                   out_of_service: false
                 },
                 remote_device_id: 42
               )

      assert {:ok, 42} = ObjectsUtility.get_remote_device_id(object)

      assert :error =
               ObjectsUtility.get_remote_device_id(%{
                 object
                 | _metadata: %{object._metadata | remote_object: true}
               })

      map = ObjectsUtility.to_map(object)
      assert map.object_identifier == @object_id
      assert map.object_name == "remote"
      refute Map.has_key?(map, :_metadata)
      refute Map.has_key?(map, :object_instance)
      refute Map.has_key?(map, :description)
      assert ObjectsUtility.to_list(object) == Enum.sort(Map.to_list(map))
      assert_raise ArgumentError, fn -> ObjectsUtility.get_object_type(%MissingCodec{}) end
    end

    test "float rounding and truncation include priority arrays and preserve other fields" do
      {:ok, object} = AnalogOutput.create(1, "output", %{relinquish_default: -1.239})
      {:ok, object} = ObjectsUtility.set_priority(object, 8, 12.349)

      for precision <- [2, 0.01] do
        rounded = ObjectsUtility.truncate_float_properties(object, precision)
        assert rounded.present_value == 12.35
        assert rounded.priority_array.priority_8 == 12.35
        assert rounded.relinquish_default == -1.24
        assert rounded._metadata == object._metadata
        assert rounded.object_name == "output"

        truncated = ObjectsUtility.truncate_float_properties(object, precision, :truncate)
        assert truncated.present_value == 12.34
        assert truncated.priority_array.priority_8 == 12.34
        assert truncated.relinquish_default == -1.23
      end

      for precision <- [0, 0.0, -0.0, 1.0, 5.0] do
        assert %{present_value: 12.0, relinquish_default: -1.0} =
                 ObjectsUtility.truncate_float_properties(object, precision)
      end
    end

    test "casting rejects unsupported object types and incomplete object modules" do
      object_id = %ObjectIdentifier{type: :unsupported_coverage_type, instance: 1}
      value = Encoding.create!({:boolean, true})

      assert {:error, :unsupported_object_type} =
               ObjectsUtility.cast_property_to_value(object_id, :present_value, value)

      assert {:error, :unsupported_object_type} =
               ObjectsUtility.cast_value_to_property(object_id, :present_value, true)

      assert {:error, :unsupported_object_type} =
               ObjectsUtility.cast_properties_to_object(object_id, %{}, [])

      assert {:error, :unsupported_object_type} =
               ObjectsUtility.cast_read_properties_ack(object_id, [])

      ObjectsUtility.put_object_type_mapping(:coverage_vendor, MissingCodec)

      assert {:error, :invalid_object_module} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, true)

      assert {:error, :invalid_object_module} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, value)

      assert {:error, {:missing_property, :object_name}} =
               ObjectsUtility.cast_properties_to_object(@object_id, %{}, [])

      assert {:error, {:unknown_property, :unknown_property}} =
               ObjectsUtility.cast_value_to_property(@object_id, :unknown_property, true)
    end

    test "casting validates keyword lists and boolean options" do
      value = Encoding.create!({:boolean, true})

      for property <- [:present_value, 85] do
        assert_raise ArgumentError, ~r/expected a keyword list/, fn ->
          ObjectsUtility.cast_property_to_value(@object_id, property, value, [:invalid])
        end
      end

      assert_raise ArgumentError, ~r/expected a keyword list/, fn ->
        ObjectsUtility.cast_value_to_property(@object_id, :present_value, true, [:invalid])
      end

      assert_raise ArgumentError, ~r/expected a keyword list/, fn ->
        ObjectsUtility.cast_read_properties_ack(@object_id, [], [:invalid])
      end

      assert_raise ArgumentError, ~r/expected a keyword list/, fn ->
        ObjectsUtility.cast_properties_to_object(@object_id, %{}, [:invalid])
      end

      assert_raise ArgumentError, ~r/opts\[:object_opts\]/, fn ->
        ObjectsUtility.cast_properties_to_object(@object_id, %{}, object_opts: [:invalid])
      end

      assert_raise ArgumentError, ~r/allow_partial.*boolean/, fn ->
        ObjectsUtility.cast_value_to_property(@object_id, :present_value, true, allow_partial: 1)
      end
    end

    test "single property responses merge values and skip the object type" do
      acks = [
        read_ack(:present_value, {:enumerated, 1}),
        read_ack(:object_type, {:enumerated, 3})
      ]

      assert {:ok, %{present_value: true}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, acks)

      assert {:ok, %{}} = ObjectsUtility.cast_read_properties_ack(@object_id, [])

      assert {:error, :invalid_ack} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [:invalid])
    end

    test "single property responses enforce object identifiers and array index policy" do
      ack = read_ack(:present_value, {:enumerated, 1})
      mismatched = %{ack | object_identifier: %{@object_id | instance: 8}}

      assert {:error, :object_identifier_mismatch} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [mismatched])

      assert {:ok, %{}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [mismatched],
                 ignore_object_identifier_mismatch: true
               )

      indexed = %{ack | property_array_index: 1}

      assert {:error, :property_array_index_not_supported} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [indexed])

      assert {:ok, %{}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [indexed],
                 ignore_array_indexes: true
               )
    end

    test "single property responses propagate invalid values or skip them when requested" do
      ack = read_ack(:present_value, {:character_string, "invalid"})

      assert {:error, {:invalid_property_value, {:present_value, "invalid"}}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [ack])

      assert {:ok, %{}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [ack],
                 ignore_invalid_properties: true
               )
    end

    test "single property responses can skip unknown properties" do
      ack = read_ack(:unknown_property, {:unsigned_integer, 42})

      assert {:error, {:unknown_property, :unknown_property}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [ack])

      assert {:ok, %{}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [ack],
                 ignore_unknown_properties: true
               )

      assert {:ok, %{unknown_property: 42}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [ack],
                 allow_unknown_properties: true
               )
    end

    test "multiple property responses handle unknown numeric identifiers and errors" do
      result = read_result(65_000, {:unsigned_integer, 42})
      ack = multiple_ack([result])

      assert {:error, {:unknown_property, 65_000}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [ack])

      assert {:ok, %{}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [ack],
                 ignore_unknown_properties: true
               )

      assert {:ok, %{65_000 => 42}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [ack],
                 allow_unknown_properties: true
               )

      assert {:ok, %{65_000 => %Encoding{value: 42}}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [ack],
                 allow_unknown_properties: :no_unpack
               )

      ignored = [
        %{result | error: %BACnetError{class: :property, code: :unknown_property}},
        %{result | property_value: nil},
        read_result(:object_type, {:enumerated, 3})
      ]

      assert {:ok, %{}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [multiple_ack(ignored)])
    end

    test "multiple property responses enforce object identifiers and array index policy" do
      ack = multiple_ack([read_result(:present_value, {:enumerated, 1})])
      [result] = ack.results
      mismatched = %{ack | results: [%{result | object_identifier: %{@object_id | instance: 8}}]}

      assert {:error, :object_identifier_mismatch} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [mismatched])

      assert {:ok, %{present_value: true}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [mismatched],
                 ignore_object_identifier_mismatch: true
               )

      indexed =
        multiple_ack([%{read_result(:present_value, {:enumerated, 1}) | property_array_index: 1}])

      assert {:error, :property_array_index_not_supported_1} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [indexed])

      assert {:ok, %{present_value: true}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [indexed],
                 ignore_array_indexes: true
               )

      invalid = multiple_ack([read_result(:present_value, {:character_string, "invalid"})])

      assert {:ok, %{}} =
               ObjectsUtility.cast_read_properties_ack(@object_id, [invalid],
                 ignore_invalid_properties: true
               )
    end

    test "custom codecs transform scalar values, lists, and arrays in order" do
      decoder = fn %Encoding{value: value} -> value + 1 end
      encoder = fn value -> {:unsigned_integer, value - 1} end
      inputs = Enum.map([1, 2], &Encoding.create!({:unsigned_integer, &1}))

      for type <- [
            {:list, :unsigned_integer},
            {:array, :unsigned_integer},
            {:array, :unsigned_integer, 2}
          ] do
        configure_type(type, decoder: decoder, encoder: encoder)

        expected =
          case type do
            {:list, _subtype} -> [2, 3]
            {:array, _subtype} -> BACnetArray.from_list([2, 3])
            {:array, _subtype, _size} -> BACnetArray.from_list([2, 3], true)
          end

        assert {:ok, ^expected} =
                 ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, inputs)

        assert {:ok, ^inputs} =
                 ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, expected)
      end

      configure_type(:unsigned_integer, decoder: decoder, encoder: encoder)

      assert {:ok, 2} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, hd(inputs))

      assert {:ok, %Encoding{value: 1}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, 2)
    end

    test "custom codec failures and exceptions are returned to the caller" do
      value = Encoding.create!({:unsigned_integer, 1})

      configure_type({:list, :unsigned_integer},
        decoder: fn _value -> {:error, :invalid_value} end,
        encoder: fn _value -> {:error, :vendor_failure} end
      )

      assert {:error, {:invalid_property_value, {:present_value, [^value]}}} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, [value])

      assert {:error, {:vendor_failure, {:present_value, [1]}}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, [1])

      configure_type(:unsigned_integer,
        decoder: fn _value -> raise "decode failed" end,
        encoder: fn _value -> raise "encode failed" end
      )

      assert {:error, {:exception_during_decoding, %RuntimeError{}, [_frame | _rest]}} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, value)

      assert {:error, {:exception_during_encoding, %RuntimeError{}, [_frame | _rest]}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, 1)
    end

    test "custom encoders accept Encoding structs and reject invalid raw tags" do
      value = Encoding.create!({:unsigned_integer, 1})

      for result <- [[value], [[value]], [[:invalid]], [:invalid]] do
        configure_type(:any, encoder: fn _value -> {:ok, result} end)

        expected =
          if result in [[value], [[value]]], do: {:ok, [value]}, else: {:error, :invalid_encoding}

        assert ^expected = ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, 1)
      end
    end

    test "partial array and list values use the element type in both directions" do
      value = Encoding.create!({:unsigned_integer, 42})

      for type <- [
            {:array, :unsigned_integer},
            {:array, :unsigned_integer, 2},
            {:list, :unsigned_integer}
          ] do
        configure_type(type)

        assert {:ok, 42} =
                 ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, value,
                   allow_partial: true
                 )

        assert {:ok, ^value} =
                 ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, 42,
                   allow_partial: true
                 )

        assert {:error, {:invalid_property_value, {:present_value, 42}}} =
                 ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, 42)
      end
    end

    test "array and list encoding errors preserve the property and invalid value" do
      for {type, value} <- [
            {{:array, :unsigned_integer}, BACnetArray.from_list([1, -1])},
            {{:list, :unsigned_integer}, [1, -1]}
          ] do
        configure_type(type)

        assert {:error, {:invalid_property_value, {:present_value, -1}}} =
                 ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, value)
      end
    end

    test "manual struct codecs decode variable and fixed arrays without losing order" do
      inputs = Enum.map([1, 2], &Encoding.create!({:unsigned_integer, &1}))

      for mod <- [StreamingValue, ParsedValue], fixed <- [false, true] do
        type = if fixed, do: {:array, {:struct, mod}, 2}, else: {:array, {:struct, mod}}
        configure_type(type)
        expected = BACnetArray.from_list([struct(mod, value: 1), struct(mod, value: 2)], fixed)

        assert {:ok, ^expected} =
                 ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, inputs)

        configure_type({:array, {:struct, mod}, 3})

        assert {:error, {:bacnet_array_size_mismatch, {:present_value, ^inputs}}} =
                 ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, inputs)
      end

      configure_type({:struct, ParsedValue})

      assert {:ok, %ParsedValue{value: 1}} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, [hd(inputs)])
    end

    test "missing struct codecs and malformed values return errors" do
      configure_type({:struct, MissingCodec})
      value = Encoding.create!({:unsigned_integer, 1})

      assert {:error, {:missing_parse_fun, MissingCodec}} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, value)

      assert {:error, {:missing_encode_fun, MissingCodec}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, %MissingCodec{})

      configure_type({:list, {:struct, MissingCodec}})

      assert {:error, {:missing_parse_fun, MissingCodec}} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, [value])

      for mod <- [StreamingValue, ParsedValue] do
        configure_type({:array, {:struct, mod}})
        invalid = [Encoding.create!({:character_string, "invalid"})]

        assert {:error, {:invalid_property_value, {:present_value, ^invalid}}} =
                 ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, invalid)
      end
    end

    test "struct application codecs accept a list and unknown constructed values stay encoded" do
      configure_type({:struct, EventParameters.None})
      value = Encoding.create!({:constructed, {20, {:null, nil}, 0}})

      assert {:ok, %EventParameters.None{}} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, [value])

      assert {:ok, ^value} =
               ObjectsUtility.cast_property_to_value(@object_id, 65_000, value,
                 allow_unknown_properties: true
               )
    end

    test "numeric constants and floating point conversions preserve their encodings" do
      configure_type({:constant, :polarity})

      assert {:ok, %Encoding{type: :enumerated, value: 42}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, 42)

      assert {:error, {:invalid_property_value, {:present_value, :invalid}}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, :invalid)

      for type <- [:real, :double], value <- [:NaN, :inf, :infn, 42] do
        configure_type(type)
        expected = if is_integer(value), do: 42.0, else: value

        assert {:ok, %Encoding{type: ^type, value: ^expected}} =
                 ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, value)
      end

      configure_type({:in_range, -5, 5})

      assert {:ok, %Encoding{type: :signed_integer, value: -2}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, -2)

      configure_type({:type_list, [:unsigned_integer, {:literal, nil}]})

      assert {:ok, %Encoding{type: :null, value: nil}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, nil)
    end

    test "object guards distinguish local, remote, intrinsic and commandable objects" do
      {check, _bindings} =
        Code.eval_quoted(
          quote do
            require ObjectsUtility

            fn object ->
              {
                ObjectsUtility.is_object(object),
                ObjectsUtility.is_object_loose(object),
                ObjectsUtility.is_object_commandable(object),
                ObjectsUtility.is_object_commandable_loose(object),
                ObjectsUtility.is_object_intrinsic(object),
                ObjectsUtility.is_object_local(object),
                ObjectsUtility.is_object_remote(object)
              }
            end
          end
        )

      {:ok, object} = BinaryInput.create(7, "input", %{polarity: :normal})
      assert check.(object) == {true, true, false, false, false, true, false}
      {:ok, object} = AnalogOutput.create(7, "output", %{})
      assert check.(object) == {true, true, true, true, false, true, false}

      remote = %{
        object
        | _metadata: %{object._metadata | remote_object: 42, intrinsic_reporting: true}
      }

      assert check.(remote) == {true, true, true, true, true, false, true}
    end

    test "single and multiple responses can ignore missing property parsers" do
      configure_type({:struct, MissingCodec})
      single = %{read_ack(:present_value, {:unsigned_integer, 1}) | object_identifier: @vendor_id}

      multiple = %ReadPropertyMultipleAck{
        results: [
          %ReadAccessResult{
            object_identifier: @vendor_id,
            results: [read_result(:present_value, {:unsigned_integer, 1})]
          }
        ]
      }

      for ack <- [single, multiple] do
        assert {:error, {:missing_parse_fun, MissingCodec}} =
                 ObjectsUtility.cast_read_properties_ack(@vendor_id, [ack])

        assert {:ok, %{}} =
                 ObjectsUtility.cast_read_properties_ack(@vendor_id, [ack],
                   ignore_invalid_properties: true
                 )
      end
    end

    test "unexpected codec exceptions become errors and failed union alternatives fall through" do
      configure_type({:struct, BrokenCodec})

      assert {:error, {:invalid_property_value, {:present_value, %BrokenCodec{}}}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, %BrokenCodec{
                 value: :invalid
               })

      assert {:error, {:exception_during_casting, %RuntimeError{}, [_frame | _rest]}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, %BrokenCodec{})

      configure_type(:any, encode_as: {:struct, BrokenCodec})

      assert {:error, {:exception_during_casting, %RuntimeError{}, [_frame | _rest]}} =
               ObjectsUtility.cast_value_to_property(@vendor_id, :present_value, %BrokenCodec{})

      configure_type(:unsigned_integer)

      assert {:error, {:exception_during_casting, %FunctionClauseError{}, [_frame | _rest]}} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, [nil])

      configure_type({:type_list, [{:struct, MissingCodec}, :unsigned_integer]})

      assert {:ok, 42} =
               ObjectsUtility.cast_property_to_value(
                 @vendor_id,
                 :present_value,
                 Encoding.create!({:unsigned_integer, 42})
               )

      configure_type(:unsigned_integer, decoder: fn %Encoding{value: value} -> {:ok, value} end)

      assert {:ok, 42} =
               ObjectsUtility.cast_property_to_value(
                 @vendor_id,
                 :present_value,
                 Encoding.create!({:unsigned_integer, 42})
               )
    end

    test "grouped struct arrays decode elements and reject malformed members or wrong sizes" do
      values = [
        [Encoding.create!({:unsigned_integer, 1})],
        [Encoding.create!({:unsigned_integer, 2})]
      ]

      for type <- [{:array, {:struct, ParsedValue}}, {:array, {:struct, ParsedValue}, 2}] do
        configure_type(type)

        expected =
          BACnetArray.from_list(
            [%ParsedValue{value: 1}, %ParsedValue{value: 2}],
            tuple_size(type) == 3
          )

        assert {:ok, ^expected} =
                 ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, values)

        invalid = [hd(values), [Encoding.create!({:character_string, "invalid"})]]

        assert {:error, {:invalid_property_value, {:present_value, ^invalid}}} =
                 ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, invalid)
      end

      configure_type({:array, {:struct, ParsedValue}, 3})

      assert {:error, {:bacnet_array_size_mismatch, {:present_value, ^values}}} =
               ObjectsUtility.cast_property_to_value(@vendor_id, :present_value, values)
    end

    test "date priority arrays encode empty slots as NULL" do
      object_id = %ObjectIdentifier{type: :date_value, instance: 1}
      date = BACnetDate.from_date(~D[2026-11-09])
      priorities = %PriorityArray{priority_8: date}
      empty = Encoding.create!({:null, nil})
      command = Encoding.create!({:date, date})
      expected = List.duplicate(empty, 7) ++ [command] ++ List.duplicate(empty, 8)

      assert {:ok, ^expected} =
               ObjectsUtility.cast_value_to_property(object_id, :priority_array, priorities)
    end

    test "binary priority arrays encode true and false as enumerated values" do
      object_id = %ObjectIdentifier{type: :binary_output, instance: 1}
      priorities = %PriorityArray{priority_1: true, priority_16: false}
      active = Encoding.create!({:enumerated, 1})
      inactive = Encoding.create!({:enumerated, 0})
      empty = Encoding.create!({:null, nil})
      expected = [active] ++ List.duplicate(empty, 14) ++ [inactive]

      assert {:ok, ^expected} =
               ObjectsUtility.cast_value_to_property(object_id, :priority_array, priorities)
    end

    test "priority array casts reject a full response containing an invalid element" do
      value = Encoding.create!({:enumerated, 1})

      assert {:error, {:invalid_property_value, {:priority_array, ^value}}} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :binary_output, instance: 1},
                 :priority_array,
                 value
               )

      values = List.duplicate(value, 15) ++ [:invalid]

      assert {:error, {:invalid_property_value, {:priority_array, ^values}}} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :binary_output, instance: 1},
                 :priority_array,
                 values
               )

      assert {:error, {:invalid_property_value, {:priority_array, :invalid}}} =
               ObjectsUtility.cast_value_to_property(
                 %ObjectIdentifier{type: :analog_output, instance: 1},
                 :priority_array,
                 %PriorityArray{priority_1: :invalid}
               )
    end
  end

  describe "DateTime priority array wire format" do
    test "encodes a DateTime command in one constructed slot" do
      object_id = %ObjectIdentifier{type: :datetime_value, instance: 1}
      datetime = BACnetDateTime.from_datetime(~U[2026-11-09 07:30:15.25Z])

      priorities = %PriorityArray{
        priority_1: nil,
        priority_2: nil,
        priority_3: nil,
        priority_4: nil,
        priority_5: nil,
        priority_6: nil,
        priority_7: nil,
        priority_8: datetime,
        priority_9: nil,
        priority_10: nil,
        priority_11: nil,
        priority_12: nil,
        priority_13: nil,
        priority_14: nil,
        priority_15: nil,
        priority_16: nil
      }

      empty = Encoding.create!({:null, nil})
      {:ok, tags} = BACnetDateTime.encode(datetime)
      command = Encoding.create!({:constructed, {1, tags, 0}})

      encodings = [
        empty,
        empty,
        empty,
        empty,
        empty,
        empty,
        empty,
        command,
        empty,
        empty,
        empty,
        empty,
        empty,
        empty,
        empty,
        empty
      ]

      assert {:ok, ^encodings} =
               ObjectsUtility.cast_value_to_property(object_id, :priority_array, priorities)
    end

    test "decodes a constructed DateTime command without shifting its priority" do
      object_id = %ObjectIdentifier{type: :datetime_value, instance: 1}
      datetime = BACnetDateTime.from_datetime(~U[2026-11-09 07:30:15.25Z])
      empty = Encoding.create!({:null, nil})
      {:ok, tags} = BACnetDateTime.encode(datetime)
      command = Encoding.create!({:constructed, {1, tags, 0}})

      encodings = [
        empty,
        empty,
        empty,
        empty,
        empty,
        empty,
        empty,
        command,
        empty,
        empty,
        empty,
        empty,
        empty,
        empty,
        empty,
        empty
      ]

      priorities = %PriorityArray{
        priority_1: nil,
        priority_2: nil,
        priority_3: nil,
        priority_4: nil,
        priority_5: nil,
        priority_6: nil,
        priority_7: nil,
        priority_8: datetime,
        priority_9: nil,
        priority_10: nil,
        priority_11: nil,
        priority_12: nil,
        priority_13: nil,
        priority_14: nil,
        priority_15: nil,
        priority_16: nil
      }

      assert {:ok, ^priorities} =
               ObjectsUtility.cast_property_to_value(object_id, :priority_array, encodings)
    end

    test "indexed DateTime slots round-trip as tag [1] in both DateTime object types" do
      datetime = BACnetDateTime.from_datetime(~U[2026-11-09 07:30:15.25Z])
      {:ok, tags} = BACnetDateTime.encode(datetime)
      bare_encodings = Enum.map(tags, &Encoding.create!/1)

      for type <- [:datetime_value, :datetime_pattern_value] do
        object_id = %ObjectIdentifier{type: type, instance: 1}

        assert {:ok, ^bare_encodings} =
                 ObjectsUtility.cast_value_to_property(object_id, :present_value, datetime)

        assert {:ok, %Encoding{} = command} =
                 ObjectsUtility.cast_value_to_property(object_id, :priority_array, datetime,
                   allow_partial: true
                 )

        assert {:ok, <<0x1E, 0xA4, 126, 11, 9, 1, 0xB4, 7, 30, 15, 25, 0x1F>> = wire} =
                 ApplicationTags.encode(Encoding.to_encoding!(command))

        assert {:ok, decoded, <<>>} = ApplicationTags.decode(wire)

        assert {:ok, ^datetime} =
                 ObjectsUtility.cast_property_to_value(
                   object_id,
                   :priority_array,
                   Encoding.create!(decoded),
                   allow_partial: true
                 )
      end
    end

    test "indexed DateTime slots preserve NULL" do
      object_id = %ObjectIdentifier{type: :datetime_value, instance: 1}
      empty = Encoding.create!({:null, nil})

      assert {:ok, ^empty} =
               ObjectsUtility.cast_value_to_property(object_id, :priority_array, nil,
                 allow_partial: true
               )

      assert {:ok, nil} =
               ObjectsUtility.cast_property_to_value(object_id, :priority_array, empty,
                 allow_partial: true
               )
    end

    test "indexed DateTime slots reject the wrong tag and malformed payloads" do
      object_id = %ObjectIdentifier{type: :datetime_value, instance: 1}
      datetime = BACnetDateTime.from_datetime(~U[2026-11-09 07:30:15.25Z])
      {:ok, [date, time]} = BACnetDateTime.encode(datetime)

      for {tag, tags} <- [
            {0, [date, time]},
            {1, [date]},
            {1, [time, date]},
            {1, [date, time, {:null, nil}]}
          ] do
        malformed = Encoding.create!({:constructed, {tag, tags, 0}})

        assert {:error, {:invalid_property_value, {:priority_array, ^malformed}}} =
                 ObjectsUtility.cast_property_to_value(object_id, :priority_array, malformed,
                   allow_partial: true
                 )
      end
    end
  end

  defp configure_type(type, annotations \\ []) do
    Process.put({VendorObject, :types}, %{present_value: type})
    Process.put({VendorObject, :annotations}, annotations)
  end

  defp read_ack(property, raw_value) do
    %ReadPropertyAck{
      object_identifier: @object_id,
      property_identifier: property,
      property_array_index: nil,
      property_value: Encoding.create!(raw_value)
    }
  end

  defp read_result(property, raw_value) do
    %ReadResult{
      property_identifier: property,
      property_array_index: nil,
      property_value: Encoding.create!(raw_value),
      error: nil
    }
  end

  defp multiple_ack(results) do
    %ReadPropertyMultipleAck{
      results: [%ReadAccessResult{object_identifier: @object_id, results: results}]
    }
  end

  defp get_read_property_multiple_ack_stub() do
    %BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck{
      results: [
        %BACnet.Protocol.ReadAccessResult{
          object_identifier: %BACnet.Protocol.ObjectIdentifier{
            type: :device,
            instance: 1_201_610
          },
          results: [
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :other,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :enumerated,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :serial_number,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :character_string,
                value: "37SUN31564010260372744+0000000000085073 "
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :reliability_evaluation_inhibit,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :boolean,
                value: false
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :event_detection_enable,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :boolean,
                value: true
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :event_message_texts_config,
              property_array_index: nil,
              property_value: [
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :character_string,
                  value: "ToOffNormal"
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :character_string,
                  value: "ToFault"
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :character_string,
                  value: "ToNormal"
                }
              ],
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :event_message_texts,
              property_array_index: nil,
              property_value: [
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :character_string,
                  value: ""
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :character_string,
                  value: ""
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :character_string,
                  value: ""
                }
              ],
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :restore_preparation_time,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 60
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :restore_completion_time,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 180
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :backup_preparation_time,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 60
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :backup_and_restore_state,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :enumerated,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :structured_object_list,
              property_array_index: nil,
              property_value: [],
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :time_of_device_restart,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :constructed,
                extras: [tag_number: 2],
                type: nil,
                value: [
                  date: %BACnet.Protocol.BACnetDate{
                    year: 2023,
                    month: 4,
                    day: 7,
                    weekday: 5
                  },
                  time: %BACnet.Protocol.BACnetTime{
                    hour: 16,
                    minute: 54,
                    second: 59,
                    hundredth: 0
                  }
                ]
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :restart_notification_recipients,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :constructed,
                extras: [tag_number: 1],
                type: nil,
                value: [unsigned_integer: 0, octet_string: ""]
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :last_restart_reason,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :enumerated,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :max_segments_accepted,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 4
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :last_restore_time,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :constructed,
                extras: [tag_number: 2],
                type: nil,
                value: [
                  date: %BACnet.Protocol.BACnetDate{
                    year: :unspecified,
                    month: :unspecified,
                    day: :unspecified,
                    weekday: :unspecified
                  },
                  time: %BACnet.Protocol.BACnetTime{
                    hour: :unspecified,
                    minute: :unspecified,
                    second: :unspecified,
                    hundredth: :unspecified
                  }
                ]
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :database_revision,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :configuration_files,
              property_array_index: nil,
              property_value: [],
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :backup_failure_timeout,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 300
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :active_cov_subscriptions,
              property_array_index: nil,
              property_value: [],
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :protocol_revision,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 22
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :event_timestamps,
              property_array_index: nil,
              property_value: [
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :constructed,
                  extras: [tag_number: 2],
                  type: nil,
                  value: [
                    date: %BACnet.Protocol.BACnetDate{
                      year: :unspecified,
                      month: :unspecified,
                      day: :unspecified,
                      weekday: :unspecified
                    },
                    time: %BACnet.Protocol.BACnetTime{
                      hour: :unspecified,
                      minute: :unspecified,
                      second: :unspecified,
                      hundredth: :unspecified
                    }
                  ]
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :constructed,
                  extras: [tag_number: 2],
                  type: nil,
                  value: [
                    date: %BACnet.Protocol.BACnetDate{
                      year: :unspecified,
                      month: :unspecified,
                      day: :unspecified,
                      weekday: :unspecified
                    },
                    time: %BACnet.Protocol.BACnetTime{
                      hour: :unspecified,
                      minute: :unspecified,
                      second: :unspecified,
                      hundredth: :unspecified
                    }
                  ]
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :constructed,
                  extras: [tag_number: 2],
                  type: nil,
                  value: [
                    date: %BACnet.Protocol.BACnetDate{
                      year: :unspecified,
                      month: :unspecified,
                      day: :unspecified,
                      weekday: :unspecified
                    },
                    time: %BACnet.Protocol.BACnetTime{
                      hour: :unspecified,
                      minute: :unspecified,
                      second: :unspecified,
                      hundredth: :unspecified
                    }
                  ]
                }
              ],
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :vendor_name,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :character_string,
                value: "WAGO Kontakttechnik GmbH & Co. KG"
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :vendor_identifier,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 222
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :utc_offset,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :signed_integer,
                value: -60
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :system_status,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :enumerated,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :status_flags,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :bitstring,
                value: {false, false, false, false}
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :segmentation_supported,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :enumerated,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :reliability,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :enumerated,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :protocol_version,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 1
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :protocol_services_supported,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :bitstring,
                value:
                  {true, true, false, true, true, true, true, true, true, true, true, true, true,
                   false, true, true, true, true, false, false, true, false, false, false, false,
                   false, true, true, true, false, false, false, true, true, true, true, true,
                   false, true, true, false, false, false, false, false, false, false, false,
                   false}
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :protocol_object_types_supported,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :bitstring,
                value:
                  {true, true, true, true, true, true, true, true, true, true, true, true, true,
                   true, true, true, true, true, true, true, true, false, false, true, true, true,
                   false, true, false, true, false, false, false, false, false, false, false,
                   false, false, true, false, false, false, false, false, true, true, false,
                   false, false, false, false, false, false, false, false, true, false, false,
                   false, false, false, false}
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :object_type,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :enumerated,
                value: 8
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :object_name,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :character_string,
                value: "Device_0030de5255ca"
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :object_list,
              property_array_index: nil,
              property_value: [
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{
                    type: :analog_value,
                    instance: 0
                  }
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{
                    type: :device,
                    instance: 1_201_610
                  }
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 1}
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 2}
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 3}
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 4}
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 5}
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 6}
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 7}
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 8}
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{
                    type: :network_port,
                    instance: 1
                  }
                }
              ],
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :object_identifier,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :object_identifier,
                value: %BACnet.Protocol.ObjectIdentifier{
                  type: :device,
                  instance: 1_201_610
                }
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :number_of_apdu_retries,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 3
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :notify_type,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :enumerated,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :model_name,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :character_string,
                value: "750-8212"
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :max_apdu_length_accepted,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 1476
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :location,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :character_string,
                value: ""
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :local_time,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :time,
                value: %BACnet.Protocol.BACnetTime{
                  hour: 20,
                  minute: 58,
                  second: 18,
                  hundredth: 0
                }
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :local_date,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :date,
                value: %BACnet.Protocol.BACnetDate{
                  year: 2023,
                  month: 4,
                  day: 7,
                  weekday: 5
                }
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :firmware_revision,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :character_string,
                value: "1.6.2 / 04.01.10(23)"
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :event_state,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :enumerated,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :event_enable,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :bitstring,
                value: {true, true, true}
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :device_address_binding,
              property_array_index: nil,
              property_value: [
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :object_identifier,
                  value: %BACnet.Protocol.ObjectIdentifier{
                    type: :device,
                    instance: 1_201_610
                  }
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :unsigned_integer,
                  value: 0
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :octet_string,
                  value: <<192, 168, 1, 79, 186, 192>>
                }
              ],
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :description,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :character_string,
                value: ""
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :daylight_savings_status,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :boolean,
                value: true
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :notification_class,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 0
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :application_software_version,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :character_string,
                value: ""
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :apdu_timeout,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 6000
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :apdu_segment_timeout,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :unsigned_integer,
                value: 2000
              },
              error: nil
            },
            %BACnet.Protocol.ReadAccessResult.ReadResult{
              property_identifier: :acked_transitions,
              property_array_index: nil,
              property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                encoding: :primitive,
                extras: [],
                type: :bitstring,
                value: {true, true, true}
              },
              error: nil
            }
          ]
        }
      ]
    }
  end

  test "encode schedule BACnetArray weekly_schedule property correctly" do
    weekly_schedule =
      BACnet.Protocol.BACnetArray.from_list(
        [
          %BACnet.Protocol.DailySchedule{
            schedule: [
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 6, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 1
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 18, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              }
            ]
          },
          %BACnet.Protocol.DailySchedule{
            schedule: [
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 6, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 1
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 18, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              }
            ]
          },
          %BACnet.Protocol.DailySchedule{
            schedule: [
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 6, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 1
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 18, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              }
            ]
          },
          %BACnet.Protocol.DailySchedule{
            schedule: [
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 6, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 1
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 18, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              }
            ]
          },
          %BACnet.Protocol.DailySchedule{
            schedule: [
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 6, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 1
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 18, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              }
            ]
          },
          %BACnet.Protocol.DailySchedule{
            schedule: [
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 6, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 1
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 18, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              }
            ]
          },
          %BACnet.Protocol.DailySchedule{
            schedule: [
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 6, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 1
                }
              },
              %BACnet.Protocol.TimeValue{
                time: %BACnet.Protocol.BACnetTime{hour: 18, minute: 0, second: 0, hundredth: 0},
                value: %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :enumerated,
                  value: 0
                }
              }
            ]
          }
        ],
        true
      )

    slot = %BACnet.Protocol.ApplicationTags.Encoding{
      encoding: :constructed,
      extras: [tag_number: 0],
      type: nil,
      value: [
        time: %BACnet.Protocol.BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 0},
        enumerated: 0,
        time: %BACnet.Protocol.BACnetTime{hour: 6, minute: 0, second: 0, hundredth: 0},
        enumerated: 1,
        time: %BACnet.Protocol.BACnetTime{hour: 18, minute: 0, second: 0, hundredth: 0},
        enumerated: 0
      ]
    }

    expected = [slot, slot, slot, slot, slot, slot, slot]

    assert {:ok, ^expected} =
             ObjectsUtility.cast_value_to_property(
               %BACnet.Protocol.ObjectIdentifier{type: :schedule, instance: 0},
               :weekly_schedule,
               weekly_schedule
             )
  end

  defp get_device_object_for_read_property_multiple_ack_stub() do
    %BACnet.Protocol.ObjectTypes.Device{
      _metadata: %{
        intrinsic_reporting: false,
        other: %{},
        physical_input: nil,
        properties_list: [
          :active_cov_subscriptions,
          :apdu_segment_timeout,
          :apdu_timeout,
          :application_software_version,
          :backup_and_restore_state,
          :backup_failure_timeout,
          :backup_preparation_time,
          :configuration_files,
          :database_revision,
          :daylight_savings_status,
          :description,
          :device_address_binding,
          :firmware_revision,
          :last_restart_reason,
          :last_restore_time,
          :local_date,
          :local_time,
          :location,
          :max_apdu_length_accepted,
          :max_segments_accepted,
          :model_name,
          :number_of_apdu_retries,
          :object_instance,
          :object_list,
          :object_name,
          :protocol_object_types_supported,
          :protocol_revision,
          :protocol_services_supported,
          :protocol_version,
          :restart_notification_recipients,
          :restore_completion_time,
          :restore_preparation_time,
          :segmentation_supported,
          :serial_number,
          :structured_object_list,
          :system_status,
          :time_of_device_restart,
          :utc_offset,
          :vendor_identifier,
          :vendor_name
        ],
        remote_object: 1_201_610,
        revision: 14
      },
      segmentation_supported: :segmented_both,
      active_cov_subscriptions: [],
      protocol_revision: 22,
      apdu_segment_timeout: 2000,
      backup_failure_timeout: 300,
      max_segments_accepted: 4,
      serial_number: "37SUN31564010260372744+0000000000085073 ",
      restore_completion_time: 180,
      restore_preparation_time: 60,
      configuration_files: %BACnet.Protocol.BACnetArray{
        fixed_size: nil,
        items: :array.new(),
        size: 0
      },
      backup_preparation_time: 60,
      local_date: %BACnet.Protocol.BACnetDate{
        year: 2023,
        month: 4,
        day: 7,
        weekday: 5
      },
      object_instance: 1_201_610,
      object_name: "Device_0030de5255ca",
      object_list: %BACnet.Protocol.BACnetArray{
        fixed_size: nil,
        items:
          :array.from_list([
            %BACnet.Protocol.ObjectIdentifier{type: :analog_value, instance: 0},
            %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 1_201_610},
            %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 1},
            %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 2},
            %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 3},
            %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 4},
            %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 5},
            %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 6},
            %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 7},
            %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 8},
            %BACnet.Protocol.ObjectIdentifier{type: :network_port, instance: 1}
          ]),
        size: 11
      },
      firmware_revision: "1.6.2 / 04.01.10(23)",
      description: "",
      protocol_object_types_supported: %BACnet.Protocol.Device.ObjectTypesSupported{
        lift: false,
        escalator: false,
        elevator_group: false,
        network_port: true,
        binary_lighting_output: false,
        lighting_output: false,
        channel: false,
        alert_enrollment: false,
        notification_forwarder: false,
        time_value: false,
        time_pattern_value: false,
        positive_integer_value: false,
        octet_string_value: false,
        large_analog_value: true,
        integer_value: true,
        datetime_value: false,
        datetime_pattern_value: false,
        date_value: false,
        date_pattern_value: false,
        character_string_value: false,
        bitstring_value: true,
        network_security: false,
        credential_data_input: false,
        access_zone: false,
        access_user: false,
        access_rights: false,
        access_point: false,
        access_credential: false,
        timer: false,
        access_door: false,
        structured_view: true,
        load_control: false,
        trend_log_multiple: true,
        global_group: false,
        event_log: true,
        pulse_converter: true,
        accumulator: true,
        life_safety_zone: false,
        life_safety_point: false,
        trend_log: true,
        multi_state_value: true,
        averaging: true,
        schedule: true,
        program: true,
        notification_class: true,
        multi_state_output: true,
        multi_state_input: true,
        loop: true,
        group: true,
        file: true,
        event_enrollment: true,
        device: true,
        command: true,
        calendar: true,
        binary_value: true,
        binary_output: true,
        binary_input: true,
        analog_value: true,
        analog_output: true,
        analog_input: true
      },
      max_apdu_length_accepted: 1476,
      local_time: %BACnet.Protocol.BACnetTime{
        hour: 20,
        minute: 58,
        second: 18,
        hundredth: 0
      },
      device_address_binding: [
        %BACnet.Protocol.AddressBinding{
          device_identifier: %BACnet.Protocol.ObjectIdentifier{
            type: :device,
            instance: 1_201_610
          },
          network: 0,
          address: <<192, 168, 1, 79, 186, 192>>
        }
      ],
      vendor_identifier: 222,
      number_of_apdu_retries: 3,
      model_name: "750-8212",
      location: "",
      protocol_services_supported: %BACnet.Protocol.Device.ServicesSupported{
        unconfirmed_cov_notification_multiple: false,
        confirmed_cov_notification_multiple: false,
        subscribe_cov_property_multiple: false,
        write_group: false,
        get_event_information: true,
        subscribe_cov_property: true,
        life_safety_operation: false,
        utc_time_synchronization: true,
        read_range: true,
        who_is: true,
        who_has: true,
        time_synchronization: true,
        unconfirmed_text_message: false,
        unconfirmed_private_transfer: false,
        unconfirmed_event_notification: false,
        unconfirmed_cov_notification: true,
        i_have: true,
        i_am: true,
        request_key: false,
        authenticate: false,
        vt_data: false,
        vt_close: false,
        vt_open: false,
        reinitialize_device: true,
        confirmed_text_message: false,
        confirmed_private_transfer: false,
        device_communication_control: true,
        write_property_multiple: true,
        write_property: true,
        read_property_multiple: true,
        read_property_conditional: false,
        read_property: true,
        delete_object: true,
        create_object: true,
        remove_list_element: true,
        add_list_element: true,
        atomic_write_file: true,
        atomic_read_file: true,
        subscribe_cov: true,
        get_enrollment_summary: true,
        get_alarm_summary: true,
        confirmed_event_notification: false,
        confirmed_cov_notification: true,
        acknowledge_alarm: true
      },
      daylight_savings_status: true,
      utc_offset: -60,
      time_of_device_restart: %BACnet.Protocol.BACnetTimestamp{
        type: :datetime,
        time: nil,
        sequence_number: nil,
        datetime: %BACnet.Protocol.BACnetDateTime{
          date: %BACnet.Protocol.BACnetDate{
            year: 2023,
            month: 4,
            day: 7,
            weekday: 5
          },
          time: %BACnet.Protocol.BACnetTime{
            hour: 16,
            minute: 54,
            second: 59,
            hundredth: 0
          }
        }
      },
      structured_object_list: %BACnet.Protocol.BACnetArray{
        fixed_size: nil,
        items: :array.new(),
        size: 0
      },
      system_status: :operational,
      vendor_name: "WAGO Kontakttechnik GmbH & Co. KG",
      last_restore_time: %BACnet.Protocol.BACnetTimestamp{
        type: :datetime,
        time: nil,
        sequence_number: nil,
        datetime: %BACnet.Protocol.BACnetDateTime{
          date: %BACnet.Protocol.BACnetDate{
            year: :unspecified,
            month: :unspecified,
            day: :unspecified,
            weekday: :unspecified
          },
          time: %BACnet.Protocol.BACnetTime{
            hour: :unspecified,
            minute: :unspecified,
            second: :unspecified,
            hundredth: :unspecified
          }
        }
      },
      restart_notification_recipients: [
        %BACnet.Protocol.Recipient{
          type: :address,
          address: %BACnet.Protocol.RecipientAddress{network: 0, address: :broadcast},
          device: nil
        }
      ],
      last_restart_reason: :unknown,
      apdu_timeout: 6000,
      protocol_version: 1,
      application_software_version: "",
      database_revision: 0,
      backup_and_restore_state: :idle
    }
  end
end
