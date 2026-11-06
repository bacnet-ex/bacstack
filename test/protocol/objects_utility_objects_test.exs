defmodule BACnet.Test.Protocol.ObjectsUtilityObjectsTest do
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility

  import BACnet.Test.Support.Protocol.ObjectsUtilityTestHelper

  use ExUnit.Case, async: false

  @moduletag :objects_utility
  @moduletag :objects_utility_objects
  @moduletag :bacnet_object
  @moduletag :bacnet_object_property

  # If we run no_cover tests, skip all generation (none are tagged :no_cover)
  # Also dont run generation or partial generation if test is excluded
  config = ExUnit.configuration()
  included = Keyword.fetch!(config, :include)
  excluded = Keyword.fetch!(config, :exclude)

  properties_tests =
    if :no_cover in included or Enum.any?(excluded, &(&1 in @moduletag)) do
      []
    else
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
    end

  for {obj_type, mod_type, test_list} <- properties_tests,
      not Enum.any?(excluded, &(&1 == String.to_atom("bacnet_object_#{obj_type}"))) do
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
        test "cast property to value #{description} [Encoding -> Elixir]" do
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
          test "cast value to property #{description} [Elixir -> Encoding]" do
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
end
