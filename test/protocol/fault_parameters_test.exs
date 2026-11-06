defmodule BACnet.Protocol.FaultParametersTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.FaultParameters
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.PropertyState

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest FaultParameters

  test "assert tag numbers of fault parameters" do
    assert 0 = FaultParameters.None.get_tag_number()
    assert 1 = FaultParameters.FaultCharacterString.get_tag_number()
    assert 2 = FaultParameters.FaultExtended.get_tag_number()
    assert 3 = FaultParameters.FaultLifeSafety.get_tag_number()
    assert 4 = FaultParameters.FaultState.get_tag_number()
    assert 5 = FaultParameters.FaultStatusFlags.get_tag_number()
  end

  test "decode fault character string 1" do
    tag = {:constructed, {1, {:constructed, {0, {:character_string, "hello"}, 0}}, 0}}

    assert {:ok,
            %FaultParameters.FaultCharacterString{
              fault_values: ["hello"]
            }} = FaultParameters.parse(tag)

    assert {:ok,
            %FaultParameters.FaultCharacterString{
              fault_values: ["hello"]
            }} = FaultParameters.FaultCharacterString.from_app_encoding([tag])
  end

  test "encode fault character string 1" do
    params = %FaultParameters.FaultCharacterString{
      fault_values: ["hello"]
    }

    assert {:ok, {:constructed, {1, [{:constructed, {0, [{:character_string, "hello"}], 0}}], 0}}} =
             FaultParameters.encode(params)

    assert {:ok, {:constructed, {1, [{:constructed, {0, [{:character_string, "hello"}], 0}}], 0}}} =
             FaultParameters.FaultCharacterString.to_app_encoding(params)
  end

  test "fault extended preserves vendor parameters at the vendor ID boundaries" do
    for {vendor_id, vendor_bytes, parameters} <- [
          {0, <<0>>, []},
          {65_535, <<255, 255>>, [unsigned_integer: 42, character_string: "vendor", null: nil]}
        ] do
      params = %FaultParameters.FaultExtended{
        vendor_id: vendor_id,
        extended_fault_type: 256,
        parameters: parameters
      }

      tag =
        {:constructed,
         {2,
          [
            tagged: {0, vendor_bytes, byte_size(vendor_bytes)},
            tagged: {1, <<1, 0>>, 2},
            constructed: {2, parameters, 0}
          ], 0}}

      assert {:ok, ^tag} = FaultParameters.encode(params)
      assert {:ok, ^tag} = FaultParameters.FaultExtended.to_app_encoding(params)
      assert {:ok, ^params} = FaultParameters.parse(tag)
      assert {:ok, ^params} = FaultParameters.FaultExtended.from_app_encoding([tag])
      assert FaultParameters.valid?(params)
      refute FaultParameters.valid?(%{params | vendor_id: 65_536})
    end
  end

  test "fault life safety preserves fault values and the mode reference" do
    params = %FaultParameters.FaultLifeSafety{
      mode: %DeviceObjectPropertyRef{
        object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
        property_identifier: :present_value,
        property_array_index: nil,
        device_identifier: nil
      },
      fault_values: [:fault, :fault_alarm]
    }

    tag =
      {:constructed,
       {3,
        [
          constructed: {0, [enumerated: 3, enumerated: 5], 0},
          constructed: {1, [tagged: {0, <<0, 0, 0, 1>>, 4}, tagged: {1, <<85>>, 1}], 0}
        ], 0}}

    assert {:ok, ^params} = FaultParameters.parse(tag)
    assert {:ok, ^params} = FaultParameters.FaultLifeSafety.from_app_encoding([tag])
    assert {:ok, ^tag} = FaultParameters.encode(params)
    assert {:ok, ^tag} = FaultParameters.FaultLifeSafety.to_app_encoding(params)
    assert FaultParameters.valid?(params)
    refute FaultParameters.valid?(%{params | fault_values: [:unknown]})
  end

  test "decode fault state" do
    tag = {:constructed, {4, {:constructed, {0, {:tagged, {0, <<1>>, 1}}, 0}}, 0}}

    assert {:ok,
            %FaultParameters.FaultState{
              fault_values: [
                %PropertyState{
                  type: :boolean_value,
                  value: true
                }
              ]
            }} = FaultParameters.parse(tag)

    assert {:ok,
            %FaultParameters.FaultState{
              fault_values: [
                %PropertyState{
                  type: :boolean_value,
                  value: true
                }
              ]
            }} = FaultParameters.FaultState.from_app_encoding([tag])
  end

  test "encode fault state" do
    params = %FaultParameters.FaultState{
      fault_values: [
        %PropertyState{
          type: :boolean_value,
          value: true
        }
      ]
    }

    assert {:ok, {:constructed, {4, [{:constructed, {0, [{:tagged, {0, <<1>>, 1}}], 0}}], 0}}} =
             FaultParameters.encode(params)

    assert {:ok, {:constructed, {4, [{:constructed, {0, [{:tagged, {0, <<1>>, 1}}], 0}}], 0}}} =
             FaultParameters.FaultState.to_app_encoding(params)

    # Sanity check
    assert {:ok, <<0x4E, 0x0E, 0x09, 0x01, 0x0F, 0x4F>>} =
             ApplicationTags.encode(
               {:constructed, {4, [{:constructed, {0, [{:tagged, {0, <<1>>, 1}}], 0}}], 0}}
             )
  end

  test "decode fault status flags" do
    tag =
      {:constructed,
       {5, {:constructed, {0, [tagged: {0, <<0, 0, 0, 250>>, 4}, tagged: {1, "U", 1}], 0}}, 0}}

    assert {:ok,
            %FaultParameters.FaultStatusFlags{
              status_flags: %DeviceObjectPropertyRef{
                device_identifier: nil,
                object_identifier: %ObjectIdentifier{type: :analog_input, instance: 250},
                property_identifier: :present_value,
                property_array_index: nil
              }
            }} = FaultParameters.parse(tag)

    assert {:ok,
            %FaultParameters.FaultStatusFlags{
              status_flags: %DeviceObjectPropertyRef{
                device_identifier: nil,
                object_identifier: %ObjectIdentifier{type: :analog_input, instance: 250},
                property_identifier: :present_value,
                property_array_index: nil
              }
            }} = FaultParameters.FaultStatusFlags.from_app_encoding([tag])
  end

  test "encode fault status flags" do
    params = %FaultParameters.FaultStatusFlags{
      status_flags: %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :analog_input, instance: 250},
        property_identifier: :present_value,
        property_array_index: nil
      }
    }

    assert {:ok,
            {:constructed,
             {5,
              [{:constructed, {0, [tagged: {0, <<0, 0, 0, 250>>, 4}, tagged: {1, "U", 1}], 0}}],
              0}}} = FaultParameters.encode(params)

    assert {:ok,
            {:constructed,
             {5,
              [{:constructed, {0, [tagged: {0, <<0, 0, 0, 250>>, 4}, tagged: {1, "U", 1}], 0}}],
              0}}} = FaultParameters.FaultStatusFlags.to_app_encoding(params)
  end

  # TODO: Fault Parameters 6+7 happy path

  # --- Failure / error paths ---

  test "from_app_encoding invalid encoding for all types" do
    for module <- [
          FaultParameters.None,
          FaultParameters.FaultCharacterString,
          FaultParameters.FaultExtended,
          FaultParameters.FaultLifeSafety,
          FaultParameters.FaultState,
          FaultParameters.FaultStatusFlags
        ] do
      assert {:error, :invalid_encoding} = module.from_app_encoding(:not_a_list)
      assert {:error, :invalid_encoding} = module.from_app_encoding([])
      assert {:error, :invalid_encoding} = module.from_app_encoding([:a, :b])
    end
  end

  @dopr %DeviceObjectPropertyRef{
    device_identifier: nil,
    object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
    property_identifier: :present_value,
    property_array_index: nil
  }

  @invalid_dopr %DeviceObjectPropertyRef{
    device_identifier: nil,
    object_identifier: %ObjectIdentifier{type: :analog_input, instance: -1},
    property_identifier: :present_value,
    property_array_index: nil
  }

  test "decode invalid tag" do
    assert {:error, :invalid_tag} = FaultParameters.parse(:hello)
    assert {:error, :invalid_tag} = FaultParameters.parse({:constructed, {99, [], 0}})
  end

  test "encode none" do
    params = %FaultParameters.None{}

    assert {:ok, {:constructed, {0, {:null, nil}, 0}}} =
             FaultParameters.encode(params)

    assert {:ok, {:constructed, {0, {:null, nil}, 0}}} =
             FaultParameters.None.to_app_encoding(params)
  end

  test "decode none" do
    tag = {:constructed, {0, {:null, nil}, 0}}

    assert {:ok, %FaultParameters.None{}} = FaultParameters.parse(tag)

    assert {:ok, %FaultParameters.None{}} =
             FaultParameters.None.from_app_encoding([tag])
  end

  test "decode none tagged empty" do
    tag = {:tagged, {0, "", 0}}

    assert {:ok, %FaultParameters.None{}} = FaultParameters.parse(tag)

    assert {:ok, %FaultParameters.None{}} =
             FaultParameters.None.from_app_encoding([tag])
  end

  test "decode none invalid structure" do
    assert {:error, :invalid_fault_values} =
             FaultParameters.parse({:constructed, {0, [{:boolean, true}], 0}})
  end

  test "encode fault character string invalid params" do
    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultCharacterString{
               fault_values: [123]
             })

    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultCharacterString{
               fault_values: :not_a_list
             })
  end

  test "decode fault character string invalid structure" do
    assert {:error, :invalid_fault_values} =
             FaultParameters.parse({:constructed, {1, [], 0}})
  end

  test "decode fault character string invalid values" do
    assert {:error, :invalid_fault_values} =
             FaultParameters.parse(
               {:constructed, {1, {:constructed, {0, {:unsigned_integer, 1}, 0}}, 0}}
             )
  end

  test "encode fault extended invalid params" do
    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultExtended{
               vendor_id: -1,
               extended_fault_type: 1,
               parameters: []
             })

    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultExtended{
               vendor_id: 65_536,
               extended_fault_type: 1,
               parameters: []
             })

    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultExtended{
               vendor_id: 0,
               extended_fault_type: -1,
               parameters: []
             })
  end

  test "decode fault extended invalid structure" do
    assert {:error, :invalid_fault_values} =
             FaultParameters.parse({:constructed, {2, [], 0}})
  end

  test "decode fault extended invalid data" do
    assert {:error, :invalid_data} =
             FaultParameters.parse(
               {:constructed,
                {2,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<1>>, 1},
                   constructed: {2, [], 0}
                 ], 0}}
             )
  end

  test "decode fault extended invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} =
             FaultParameters.parse(
               {:constructed,
                {2,
                 [
                   tagged: {0, <<1, 17, 112>>, 3},
                   tagged: {1, <<1>>, 1},
                   constructed: {2, [], 0}
                 ], 0}}
             )
  end

  test "decode fault extended invalid extended fault type data" do
    assert {:error, :invalid_data} =
             FaultParameters.parse(
               {:constructed,
                {2,
                 [
                   tagged: {0, <<0>>, 1},
                   tagged: {1, <<>>, 0},
                   constructed: {2, [], 0}
                 ], 0}}
             )
  end

  test "encode fault life safety invalid params" do
    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultLifeSafety{
               mode: :not_a_ref,
               fault_values: [:quiet]
             })

    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultLifeSafety{
               mode: @dopr,
               fault_values: [1]
             })

    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultLifeSafety{
               mode: @dopr,
               fault_values: :not_a_list
             })
  end

  test "encode fault life safety unknown fault value" do
    assert {:error, {:unknown_life_safety_fault_value, :hello_there}} =
             FaultParameters.encode(%FaultParameters.FaultLifeSafety{
               mode: @dopr,
               fault_values: [:hello_there]
             })
  end

  test "encode fault life safety device object property ref error" do
    assert {:error, :invalid_value} =
             FaultParameters.encode(%FaultParameters.FaultLifeSafety{
               mode: @invalid_dopr,
               fault_values: [:quiet]
             })
  end

  test "decode fault life safety invalid structure" do
    assert {:error, :invalid_fault_values} =
             FaultParameters.parse({:constructed, {3, [], 0}})
  end

  test "decode fault life safety unknown fault value" do
    assert {:error, {:unknown_life_safety_fault_value, 255}} =
             FaultParameters.parse(
               {:constructed,
                {3,
                 [
                   constructed: {0, [{:enumerated, 255}], 0},
                   constructed: {1, [tagged: {0, <<0, 0, 0, 1>>, 4}, tagged: {1, "U", 1}], 0}
                 ], 0}}
             )
  end

  test "decode fault life safety invalid enumerated" do
    assert {:error, :unknown_tag_encoding} =
             FaultParameters.parse(
               {:constructed,
                {3,
                 [
                   constructed: {0, [{:boolean, true}], 0},
                   constructed: {1, [tagged: {0, <<0, 0, 0, 1>>, 4}, tagged: {1, "U", 1}], 0}
                 ], 0}}
             )
  end

  test "decode fault life safety invalid mode ref" do
    assert {:error, :invalid_tags} =
             FaultParameters.parse(
               {:constructed,
                {3,
                 [
                   constructed: {0, [{:enumerated, 0}], 0},
                   constructed: {1, [], 0}
                 ], 0}}
             )
  end

  test "encode fault state invalid params" do
    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultState{
               fault_values: [true]
             })

    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultState{
               fault_values: :not_a_list
             })
  end

  test "encode fault state property state error" do
    assert {:error, {:error, :not_supported}} =
             FaultParameters.encode(%FaultParameters.FaultState{
               fault_values: [%PropertyState{type: :hello, value: :word}]
             })
  end

  test "decode fault state invalid structure" do
    assert {:error, :invalid_fault_values} =
             FaultParameters.parse({:constructed, {4, [], 0}})
  end

  test "decode fault state invalid fault values parameter" do
    assert {:error, :invalid_fault_values_parameter} =
             FaultParameters.parse(
               {:constructed, {4, {:constructed, {0, {:tagged, {0, <<>>, 0}}, 0}}, 0}}
             )
  end

  test "encode fault status flags invalid params" do
    assert {:error, :invalid_params} =
             FaultParameters.encode(%FaultParameters.FaultStatusFlags{
               status_flags: :not_a_ref
             })
  end

  test "encode fault status flags device object property ref error" do
    assert {:error, :invalid_value} =
             FaultParameters.encode(%FaultParameters.FaultStatusFlags{
               status_flags: @invalid_dopr
             })
  end

  test "decode fault status flags invalid structure" do
    assert {:error, :invalid_fault_values} =
             FaultParameters.parse({:constructed, {5, [], 0}})
  end

  test "decode fault status flags invalid ref" do
    assert {:error, :invalid_tags} =
             FaultParameters.parse({:constructed, {5, {:constructed, {0, [], 0}}, 0}})
  end

  test "valid? fault parameters" do
    assert true ==
             FaultParameters.valid?(%FaultParameters.FaultCharacterString{
               fault_values: ["hello"]
             })

    assert false ==
             FaultParameters.valid?(%FaultParameters.FaultCharacterString{
               fault_values: [123]
             })

    assert true == FaultParameters.valid?(%FaultParameters.None{})

    assert true ==
             FaultParameters.valid?(%FaultParameters.FaultState{
               fault_values: [%PropertyState{type: :boolean_value, value: true}]
             })

    assert false ==
             FaultParameters.valid?(%FaultParameters.FaultState{
               fault_values: [true]
             })
  end
end
