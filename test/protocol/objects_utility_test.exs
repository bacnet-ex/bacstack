defmodule BACnet.Test.Protocol.ObjectsUtilityTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.BinaryInput
  alias BACnet.Protocol.ObjectsUtility

  import BACnet.Test.Support.Protocol.ObjectsUtilityTestHelper

  use ExUnit.Case, async: false

  @moduletag :object_utility
  @moduletag :bacnet_object

  doctest ObjectsUtility

  properties_tests =
    ObjectsUtility.get_object_type_mappings()
    |> Task.async_stream(
      fn {obj_type, mod} ->
        property_types_map = mod.get_properties_type_map()

        test_list =
          property_types_map
          |> Enum.map(&generate_cast_tests(obj_type, mod, property_types_map, &1))
          |> List.flatten()

        mod_atom =
          mod
          |> Atom.to_string()
          |> String.split(".")
          |> List.last()
          |> String.to_atom()

        {obj_type, mod_atom, test_list}
      end,
      ordered: false,
      timeout: 10_000
    )
    |> Enum.map(fn {:ok, res} -> res end)

  for {obj_type, mod_type, test_list} <- properties_tests do
    mod_name =
      Module.concat([__MODULE__, String.to_atom(Macro.camelize("#{mod_type}")), :Properties])

    defmodule mod_name do
      use ExUnit.Case, async: true

      @moduletag :object_utility
      @moduletag :bacnet_object
      @moduletag :bacnet_object_property
      @moduletag String.to_atom("bacnet_object_#{obj_type}")

      for {description, object_type, prop_identifier, raw_value, parsed_value, pattern_match,
           cast_opts} <- test_list do
        @tag String.to_atom("bacnet_property_#{prop_identifier}")
        @tag String.to_atom("bacnet_property_from_raw_#{prop_identifier}")
        test "cast property to value #{description}" do
          assert unquote(Macro.escape(pattern_match)) =
                   ObjectsUtility.cast_property_to_value(
                     %ObjectIdentifier{type: unquote(object_type), instance: 1},
                     unquote(prop_identifier),
                     unquote(Macro.escape(raw_value)),
                     unquote(cast_opts)
                   )

          # rescue
          #     e in [FunctionClauseError] ->
          #       IO.inspect([description: unquote(description), object_type: unquote(object_type), prop_identifier: unquote(prop_identifier), raw_value: unquote(Macro.escape(raw_value))])
          #       reraise(e, __STACKTRACE__)
        end

        _ = parsed_value

        unless !!Keyword.get(cast_opts, :allow_partial) or
                 (String.contains?(description, "priority_array") and
                    length(raw_value) < 16) do
          pattern_match2 =
            case pattern_match do
              # {:ok, [_value]} when not is_list(raw_value) -> {:ok, raw_value}
              # {:ok, value} when not is_list(value) and is_list(raw_value) -> {:ok, List.first(raw_value)}
              {:ok, _value} ->
                {:ok, raw_value}

              {:error, {:invalid_tags, {property, _value}}} ->
                {:error, {:invalid_property_value, {property, parsed_value}}}

              {:error, {reason, {property, _value}}} ->
                {:error, {reason, {property, parsed_value}}}

              {:error, reason} ->
                {:error, reason}
            end

          @tag String.to_atom("bacnet_property_#{prop_identifier}")
          @tag String.to_atom("bacnet_property_to_raw_#{prop_identifier}")
          test "cast value to property #{description}" do
            value =
              ObjectsUtility.cast_value_to_property(
                %ObjectIdentifier{type: unquote(object_type), instance: 1},
                unquote(prop_identifier),
                unquote(Macro.escape(parsed_value)),
                unquote(cast_opts)
              )

            # Rewrite the value if the value is a singular item list but the raw value is not in a list,
            # this is due to the fact that all mod.encode funs will return a list even for single items,
            # but the test generator may not generate a wrapping list for single items
            raw_value_list = is_list(unquote(Macro.escape(raw_value)))

            actual_value =
              case value do
                # not is_nil is only to remove warnings
                {:ok, [new_value]} when not is_nil(new_value) and not raw_value_list ->
                  {:ok, new_value}

                term ->
                  term
              end

            assert unquote(Macro.escape(pattern_match2)) = actual_value
          end
        end
      end
    end
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

    # Due to map keys ordering being unguaranteed, the properties list is UNSORTED, thus we need to sort it for assertion
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
          :event_state,
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
          :out_of_service,
          :protocol_object_types_supported,
          :protocol_revision,
          :protocol_services_supported,
          :protocol_version,
          :restart_notification_recipients,
          :restore_completion_time,
          :restore_preparation_time,
          :segmentation_supported,
          :serial_number,
          :status_flags,
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
        items: {:array, 0, 10, :undefined, 10},
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
          {:array, 11, 100, :undefined,
           {{%BACnet.Protocol.ObjectIdentifier{type: :analog_value, instance: 0},
             %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 1_201_610},
             %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 1},
             %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 2},
             %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 3},
             %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 4},
             %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 5},
             %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 6},
             %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 7},
             %BACnet.Protocol.ObjectIdentifier{type: :file, instance: 8}},
            {%BACnet.Protocol.ObjectIdentifier{type: :network_port, instance: 1}, :undefined,
             :undefined, :undefined, :undefined, :undefined, :undefined, :undefined, :undefined,
             :undefined}, 10, 10, 10, 10, 10, 10, 10, 10, 10}},
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
        items: {:array, 0, 10, :undefined, 10},
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
