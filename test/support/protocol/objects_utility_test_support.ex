defmodule BACnet.Test.Support.Protocol.ObjectsUtilityTestHelper do
  @moduledoc false

  alias BACnet.BeamTypes
  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.AddressBinding
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventMessageTexts
  alias BACnet.Protocol.EventTimestamps
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.NotificationClassPriority
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.ReadAccessResult.ReadResult
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.SetpointReference
  alias BACnet.Protocol.ObjectTypes.TrendLog
  alias BACnet.Protocol.ObjectTypes.TrendLogMultiple

  @type_mapping %{
    {:struct, BACnetDate} => BACnetDate.utc_today(),
    {:struct, BACnetDateTime} => BACnetDateTime.utc_now(),
    {:struct, BACnetTime} => BACnetTime.utc_now(),
    {:struct, DeviceObjectRef} =>
      struct(DeviceObjectRef, Map.from_struct(ObjectsMacro.get_default_dev_object_ref())),
    {:struct, DeviceObjectPropertyRef} => ObjectsMacro.get_default_dev_object_ref(),
    {:struct, EventMessageTexts} => ObjectsMacro.get_default_event_message_texts(),
    {:struct, EventTimestamps} => %EventTimestamps{
      to_offnormal: ObjectsMacro.get_default_bacnet_timestamp(),
      to_fault: ObjectsMacro.get_default_bacnet_timestamp(),
      to_normal: ObjectsMacro.get_default_bacnet_timestamp()
    },
    {:struct, EventTransitionBits} => ObjectsMacro.get_default_event_transbits(),
    {:struct, LimitEnable} => %LimitEnable{
      low_limit_enable: true,
      high_limit_enable: false
    },
    {:struct, NotificationClassPriority} => %NotificationClassPriority{
      to_offnormal: Enum.random(0..255),
      to_fault: Enum.random(0..255),
      to_normal: Enum.random(0..255)
    },
    {:struct, ObjectPropertyRef} => ObjectsMacro.get_default_object_ref(),
    bitstring: {true, true, false, true},
    boolean: true,
    enumerated: 1,
    signed_integer: 5,
    unsigned_integer: 7,
    real: 5.0,
    double: 3.141,
    string: "Hello World",
    character_string: "Hello World",
    octet_string: <<0, 2, 5>>
  }

  @type_transform %{
    {:struct, BACnetDate} => :date,
    {:struct, BACnetTime} => :time,
    string: :character_string
  }

  @env __ENV__

  # Test tuple format for generate_object_tests:
  # {description, code_call, pattern_match, appendum_code}

  @spec generate_object_tests(
          Constants.object_type(),
          module()
        ) :: list()
  def generate_object_tests(obj_type, mod) do
    {create_tests, object} = repeated_generate_object_test_creation(obj_type, mod)

    pa_tests =
      if function_exported?(mod, :get_priority_value, 1) do
        [
          generate_object_test_for(obj_type, mod, object, :get_priority_value, 1),
          generate_object_test_for(obj_type, mod, object, :has_priority_array?, 1),
          generate_object_test_for(obj_type, mod, object, :set_priority, 3)
        ]
      else
        []
      end

    functions_to_call = [
      create_tests,

      # Generated functions based on availability of the priority_array property
      pa_tests,

      # Other generated functions are not covered (by default) since they are always the same
      # for the object type - the functionality is covered by the ObjectTypes.Macro testsuite
      # However if there are good reasons, we may cover them manually in the correct testsuite
      # for the object type we want to cover
      []
    ]

    List.flatten(functions_to_call)
  end

  @spec generate_properties(module()) :: map()
  defp generate_properties(mod) do
    :object_identifier
    |> generate_spec_for_struct_type({:struct, mod}, nil)
    |> elem(0)
    |> Map.from_struct()
    |> Map.drop([:object_instance, :object_name])
    # Post-processing
    |> then(fn
      # Segmentation requires some additional properties on the Device object (drop it here)
      %{segmentation_supported: _val} = obj ->
        %{obj | segmentation_supported: :no_segmentation}

      # Amend Multistate objects and make sure the PV and RQ properties aren't higher than the number of states
      # We overwrite the present_value because if PV is actually lower than RQ the test will fail,
      # and that is because PV is overwritten during object creation with the correct value (which is RQ + PA, but PA is "empty")
      %{number_of_states: ns, relinquish_default: rq} = obj when not is_nil(rq) ->
        %{
          obj
          | present_value: min(ns, rq),
            relinquish_default: min(ns, rq)
        }

      # Amend Multistate objects and make sure the PV property isn't higher than the number of states
      %{number_of_states: ns} = obj ->
        %{obj | present_value: min(ns, obj.present_value)}

      # Amend TrendLog* objects and make sure buffer_size is at least 1
      %{buffer_size: 0} = obj ->
        %{obj | buffer_size: 1}

      obj ->
        obj
    end)
  end

  @spec repeated_generate_object_test_creation(Constants.object_type(), module()) ::
          {list(), struct()}
  defp repeated_generate_object_test_creation(obj_type, mod) do
    generate_object_test_creation(obj_type, mod)
  catch
    :retry -> repeated_generate_object_test_creation(obj_type, mod)
  end

  @spec generate_object_test_creation(Constants.object_type(), module()) ::
          {list(), struct()}
  defp generate_object_test_creation(obj_type, mod) do
    # Generate new object struct (it's not propertly created), only take required properties
    # and create the object properly afterwards
    properties =
      mod
      |> generate_properties()
      |> Map.take(mod.get_required_properties())

    {:ok, %{__struct__: ^mod} = obj} =
      case mod.create(1, "TEST_OBJECT", properties) do
        {:ok, _val} = val ->
          val

        # Try again
        # Group or trendlog object is a general cause when it happens
        {:error, {:value_failed_property_validation, property}}
        when property in [:list_of_group_members, :log_buffer] ->
          throw(:retry)

        {:error, err} ->
          # IO.inspect(err, label: "Error while creating object of type #{obj_type}")
          # IO.inspect(properties, label: "Properties for object of type #{obj_type}")
          raise "create/4 failed for object #{obj_type}: #{inspect(err)}"
      end

    code_call =
      quote location: :keep do
        unquote(mod).create(1, "TEST_OBJECT", unquote(Macro.escape(properties)))
      end

    pattern_match =
      quote location: :keep do
        {:ok, %unquote(mod){}}
      end

    appendum_code =
      Enum.reduce(properties, quote(do: nil), fn {property, value}, acc ->
        quote location: :keep do
          unquote(acc)

          assert %{unquote(property) => unquote(Macro.escape(value))} = unquote(Macro.escape(obj))
        end
      end)

    {[{"function test create/4 successful", code_call, pattern_match, appendum_code}], obj}
  end

  @spec generate_object_test_for(Constants.object_type(), module(), struct, atom(), arity()) ::
          list()
  defp generate_object_test_for(obj_type, mod, object, function, arity)

  # defp generate_object_test_for(_obj_type, mod, object, :add_property, 3) do
  #   value = "hello_there"

  #   code_call =
  #     quote location: :keep do
  #       unquote(mod).add_property(
  #         unquote(Macro.escape(object)),
  #         :profile_name,
  #         unquote(value)
  #       )
  #     end

  #   pattern_match =
  #     quote location: :keep do
  #       {:ok,
  #        %unquote(mod){_metadata: %{properties_list: prop_list}, profile_name: unquote(value)} =
  #          object}
  #     end

  #   appendum_code =
  #     quote location: :keep do
  #       assert true == ObjectsUtility.has_property?(object, :profile_name)
  #     end

  #   [{"function test add_property/3 successful", code_call, pattern_match, appendum_code}]
  # end

  defp generate_object_test_for(_obj_type, mod, object, :get_priority_value, 1) do
    # When adding relinquish_default, priority_array will be added with the default value
    # We can't add priority_array, because relinquish_default doesn't have a default value (in some cases)
    # and thus will always result in {:error, {:missing_optional_property, :relinquish_default}}
    pa_object1 =
      if mod.has_property?(object, :relinquish_default) do
        object
      else
        {:ok, pa_object1} = mod.add_property(object, :relinquish_default, object.present_value)
        pa_object1
      end

    code_call1 =
      quote location: :keep do
        unquote(mod).get_priority_value(unquote(Macro.escape(pa_object1)))
      end

    pattern_match1 =
      quote location: :keep do
        nil
      end

    pa_value16 = Map.fetch!(generate_properties(mod), :relinquish_default)

    pa_value16 =
      if Map.has_key?(object, :number_of_states) do
        min(object.number_of_states, pa_value16)
      else
        pa_value16
      end

    {{:ok, pa_object2}, _mod} =
      {mod.update_property(pa_object1, :priority_array, %PriorityArray{priority_16: pa_value16}),
       mod}

    code_call2 =
      quote location: :keep do
        unquote(mod).get_priority_value(unquote(Macro.escape(pa_object2)))
      end

    pattern_match2 =
      quote location: :keep do
        {16, unquote(Macro.escape(pa_value16))}
      end

    pa_value5 = Map.fetch!(generate_properties(mod), :relinquish_default)

    pa_value5 =
      if Map.has_key?(object, :number_of_states) do
        min(object.number_of_states, pa_value5)
      else
        pa_value5
      end

    {{:ok, pa_object3}, _mod} =
      {mod.update_property(pa_object1, :priority_array, %PriorityArray{
         priority_5: pa_value5,
         priority_16: pa_value16
       }), mod}

    code_call3 =
      quote location: :keep do
        unquote(mod).get_priority_value(unquote(Macro.escape(pa_object3)))
      end

    pattern_match3 =
      quote location: :keep do
        {5, unquote(Macro.escape(pa_value5))}
      end

    appendum_code =
      quote do
        nil
      end

    [
      {"function test get_priority_value/1 no priority", code_call1, pattern_match1,
       appendum_code},
      {"function test get_priority_value/1 priority 16", code_call2, pattern_match2,
       appendum_code},
      {"function test get_priority_value/1 priority 5+16", code_call3, pattern_match3,
       appendum_code}
    ]
  end

  defp generate_object_test_for(_obj_type, mod, object, :has_priority_array?, 1) do
    # For some objects priority_array is required, for some it is optional, so check
    # the presence of the function to check only objects with optional priority_array
    if function_exported?(mod, :has_priority_array?, 1) do
      # When adding relinquish_default, priority_array will be added with the default value
      # We can't add priority_array, because relinquish_default doesn't have a default value
      # and thus will always result in {:error, {:missing_optional_property, :relinquish_default}}
      pa_object1 =
        if mod.has_property?(object, :relinquish_default) do
          object
        else
          {:ok, pa_object} = mod.add_property(object, :relinquish_default, object.present_value)
          pa_object
        end

      code_call1 =
        quote location: :keep do
          unquote(mod).has_priority_array?(unquote(Macro.escape(pa_object1)))
        end

      pattern_match1 =
        quote location: :keep do
          true
        end

      pa_object2 =
        if mod.has_property?(object, :priority_array) do
          {:ok, pa_object} = mod.remove_property(object, :priority_array, object)
          pa_object
        else
          object
        end

      code_call2 =
        quote location: :keep do
          unquote(mod).has_priority_array?(unquote(Macro.escape(pa_object2)))
        end

      pattern_match2 =
        quote location: :keep do
          false
        end

      appendum_code =
        quote do
          nil
        end

      [
        {"function test has_priority_array?/1 does have PA", code_call1, pattern_match1,
         appendum_code},
        {"function test has_priority_array/1 does not have PA", code_call2, pattern_match2,
         appendum_code}
      ]
    else
      []
    end
  end

  defp generate_object_test_for(_obj_type, mod, object, :set_priority, 3) do
    # Make sure number_of_states is high enough for Multistate objects
    object =
      if Map.has_key?(object, :number_of_states) do
        %{object | number_of_states: 32_767}
      else
        object
      end

    # Make sure out_of_service is false
    object =
      if Map.has_key?(object, :out_of_service) do
        %{object | out_of_service: false}
      else
        object
      end

    # When adding relinquish_default, priority_array will be added with the default value
    # We can't add priority_array, because relinquish_default doesn't have a default value
    # and thus will always result in {:error, {:missing_optional_property, :relinquish_default}}
    pa_object1 =
      if mod.has_property?(object, :relinquish_default) do
        object
      else
        {:ok, pa_object1} = mod.add_property(object, :relinquish_default, object.present_value)
        pa_object1
      end

    pa_value16 = Map.fetch!(generate_properties(mod), :relinquish_default)

    code_call1 =
      quote location: :keep do
        unquote(mod).set_priority(
          unquote(Macro.escape(pa_object1)),
          16,
          unquote(Macro.escape(pa_value16))
        )
      end

    pattern_match1 =
      quote location: :keep do
        {:ok,
         %unquote(mod){
           present_value: unquote(Macro.escape(pa_value16)),
           priority_array: %PriorityArray{priority_16: unquote(Macro.escape(pa_value16))}
         }}
      end

    pa_value5 = Map.fetch!(generate_properties(mod), :relinquish_default)

    code_call2 =
      quote location: :keep do
        unquote(mod).set_priority(
          unquote(Macro.escape(pa_object1)),
          5,
          unquote(Macro.escape(pa_value5))
        )
      end

    pattern_match2 =
      quote location: :keep do
        {:ok,
         %unquote(mod){
           present_value: unquote(Macro.escape(pa_value5)),
           priority_array: %PriorityArray{priority_5: unquote(Macro.escape(pa_value5))}
         }}
      end

    code_call3 =
      quote location: :keep do
        unquote(mod).set_priority(
          unquote(Macro.escape(pa_object1)),
          5,
          nil
        )
      end

    pattern_match3 =
      quote location: :keep do
        {:ok,
         %unquote(mod){
           present_value: unquote(Macro.escape(object.present_value)),
           priority_array: %PriorityArray{priority_5: nil}
         }}
      end

    pa_object2 =
      if function_exported?(mod, :has_priority_array?, 1) and
           mod.has_property?(object, :priority_array) do
        {:ok, pa_object} = mod.remove_property(object, :priority_array)
        pa_object
      else
        object
      end

    code_call4 =
      quote location: :keep do
        unquote(mod).set_priority(
          unquote(Macro.escape(pa_object2)),
          1,
          unquote(Macro.escape(pa_value5))
        )
      end

    pattern_match4 =
      quote location: :keep do
        {:error, {:unknown_property, :priority_array}}
      end

    appendum_code =
      quote do
        nil
      end

    [
      {"function test set_priority/3 priority 16", code_call1, pattern_match1, appendum_code},
      {"function test set_priority/3 priority 5", code_call2, pattern_match2, appendum_code},
      {"function test set_priority/3 priority 5 to nil", code_call3, pattern_match3,
       appendum_code}
      # This test is optional and only for modules with optional priority_array
      | if(function_exported?(mod, :has_priority_array?, 1),
          do: [
            {"function test set_priority/3 fails when no priority array", code_call4,
             pattern_match4, appendum_code}
          ],
          else: []
        )
    ]
  end

  # Test tuple format for generate_cast_tests:
  # {description, object_type, prop_identifier, raw_value, parsed_value, pattern_match, opts}

  @spec generate_cast_tests(
          Constants.object_type(),
          module(),
          map(),
          {Constants.property_identifier(), BeamTypes.typechecker_types()}
        ) :: [
          {description :: String.t(), object_type :: atom(), prop_identifier :: atom(),
           raw_value :: Encoding.t() | [Encoding.t()], parsed_value :: term(),
           pattern_match :: term(), opts :: Keyword.t()}
        ]
  def generate_cast_tests(obj_type, mod, property_types_map, map_var)

  def generate_cast_tests(obj_type, _mod, _property_types_map, {property, {:array, type}})
      when is_atom(type) do
    encoding_type = @type_transform[type] || type
    range = get_generator_for_type(property, type)

    value =
      1..8//1
      |> Enum.random()
      |> then(&List.duplicate(nil, &1))
      |> Enum.map(fn _val ->
        range.()
      end)

    wrong_type = {:real, 5.0}
    {_key, wrong_value} = wrong_type
    wrong_raw_value = [Encoding.create!(wrong_type)]

    [
      {"#{obj_type} #{property} successful cast (a_t_atom)", obj_type, property,
       Enum.map(value, &Encoding.create!({encoding_type, &1})), BACnetArray.from_list(value),
       {:ok, BACnetArray.from_list(value)}, []},
      {"#{obj_type} #{property} wrong type (a_t_atom)", obj_type, property, wrong_raw_value,
       wrong_value,
       {:error, {:invalid_property_value, {property, BACnetArray.from_list([wrong_value])}}}, []}
    ]
  end

  def generate_cast_tests(obj_type, _mod, _property_types_map, {property, {:array, type, size}})
      when is_atom(type) do
    encoding_type = @type_transform[type] || type
    range = get_generator_for_type(property, type)

    value =
      size
      |> then(&List.duplicate(nil, &1))
      |> Enum.map(fn _val ->
        range.()
      end)

    wrong_type = {:real, 5.0}
    {_key, wrong_value} = wrong_type
    wrong_raw_value = [Encoding.create!(wrong_type)]

    [
      {"#{obj_type} #{property} successful cast (a_ts_atom)", obj_type, property,
       Enum.map(value, &Encoding.create!({encoding_type, &1})), BACnetArray.from_list(value),
       {:ok, BACnetArray.from_list(value)}, []},
      {"#{obj_type} #{property} wrong type (a_ts_atom)", obj_type, property, wrong_raw_value,
       BACnetArray.from_list([wrong_value]),
       {:error, {:invalid_property_value, {property, BACnetArray.from_list([wrong_value])}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:constant, const_name}}
      ) do
    raw_value = 1
    value = Constants.by_value!(const_name, raw_value)

    wrong_type = {:real, 5.0}
    {_key, wrong_value} = wrong_type
    wrong_raw_value = Encoding.create!(wrong_type)

    [
      {"#{obj_type} #{property} successful cast (const)", obj_type, property,
       Encoding.create!({:enumerated, raw_value}), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (const)", obj_type, property, wrong_raw_value,
       wrong_value, {:error, {:invalid_property_value, {property, wrong_value}}}, []}
    ]
  end

  def generate_cast_tests(obj_type, _mod, _property_types_map, {property, {:in_range, min, max}}) do
    value = Enum.random(min..max//1)

    wrong_type = {:real, 5.0}
    {_key, wrong_value} = wrong_type
    wrong_raw_value = Encoding.create!(wrong_type)

    [
      {"#{obj_type} #{property} successful cast (inr)", obj_type, property,
       Encoding.create!({:unsigned_integer, value}), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (inr)", obj_type, property, wrong_raw_value,
       wrong_value, {:error, {:invalid_property_value, {property, wrong_value}}}, []}
    ]
  end

  def generate_cast_tests(obj_type, _mod, _property_types_map, {property, {:list, type}})
      when is_atom(type) do
    encoding_type = @type_transform[type] || type
    range = get_generator_for_type(property, type)

    value =
      1..8//1
      |> Enum.random()
      |> then(&List.duplicate(nil, &1))
      |> Enum.map(fn _val ->
        range.()
      end)

    wrong_type = {:real, 5.0}
    {_key, wrong_value} = wrong_type
    wrong_raw_value = [Encoding.create!(wrong_type)]

    [
      {"#{obj_type} #{property} successful cast (l_atom)", obj_type, property,
       Enum.map(value, &Encoding.create!({encoding_type, &1})), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (l_atom)", obj_type, property, wrong_raw_value,
       wrong_value, {:error, {:invalid_property_value, {property, [wrong_value]}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:struct, BACnetDateTime}}
      ) do
    value = BACnetDateTime.utc_now()
    {:ok, raw_value} = BACnetDateTime.encode(value)

    [
      {"#{obj_type} #{property} successful cast (s_bdt)", obj_type, property,
       Enum.map(raw_value, &Encoding.create!/1), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_bdt)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:struct, DeviceObjectRef}}
      ) do
    value = struct(DeviceObjectRef, ObjectsMacro.get_default_dev_object_ref())
    {:ok, raw_value} = DeviceObjectRef.encode(value)

    [
      {"#{obj_type} #{property} successful cast (s_dor)", obj_type, property,
       Enum.map(raw_value, &Encoding.create!/1), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_dor)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:struct, DeviceObjectPropertyRef}}
      ) do
    value = ObjectsMacro.get_default_dev_object_ref()
    {:ok, raw_value} = DeviceObjectPropertyRef.encode(value)

    [
      {"#{obj_type} #{property} successful cast (s_dopr)", obj_type, property,
       Enum.map(raw_value, &Encoding.create!/1), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_dopr)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:struct, EventMessageTexts}}
      ) do
    value = ObjectsMacro.get_default_event_message_texts()
    {:ok, raw_value} = EventMessageTexts.encode(value)

    [
      {"#{obj_type} #{property} successful cast (s_emt)", obj_type, property,
       Enum.map(raw_value, &Encoding.create!/1), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_emt)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:struct, EventTimestamps}}
      ) do
    value = %EventTimestamps{
      to_offnormal: ObjectsMacro.get_default_bacnet_timestamp(),
      to_fault: ObjectsMacro.get_default_bacnet_timestamp(),
      to_normal: ObjectsMacro.get_default_bacnet_timestamp()
    }

    {:ok, raw_value} = EventTimestamps.encode(value)

    [
      {"#{obj_type} #{property} successful cast (s_ets)", obj_type, property,
       Enum.map(raw_value, &Encoding.create!/1), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_ets)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:struct, EventTransitionBits}}
      ) do
    value = ObjectsMacro.get_default_event_transbits()
    raw_value = EventTransitionBits.to_bitstring(value)

    [
      {"#{obj_type} #{property} successful cast (s_etb)", obj_type, property,
       Encoding.create!(raw_value), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_etb)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(obj_type, _mod, _property_types_map, {property, {:struct, LimitEnable}}) do
    value = %LimitEnable{
      low_limit_enable: true,
      high_limit_enable: false
    }

    raw_value = LimitEnable.to_bitstring(value)

    [
      {"#{obj_type} #{property} successful cast (s_le)", obj_type, property,
       Encoding.create!(raw_value), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_le)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:struct, NotificationClassPriority}}
      ) do
    value = %NotificationClassPriority{
      to_offnormal: Enum.random(0..255),
      to_fault: Enum.random(0..255),
      to_normal: Enum.random(0..255)
    }

    {:ok, raw_value} = NotificationClassPriority.encode(value)

    [
      {"#{obj_type} #{property} successful cast (s_ncp)", obj_type, property,
       Enum.map(raw_value, &Encoding.create!/1), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_ncp)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:struct, ObjectPropertyRef}}
      ) do
    value = ObjectsMacro.get_default_object_ref()
    {:ok, raw_value} = ObjectPropertyRef.encode(value)

    [
      {"#{obj_type} #{property} successful cast (s_opr)", obj_type, property,
       Enum.map(raw_value, &Encoding.create!/1), value, {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_opr)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        property_types_map,
        {property, {:struct, PriorityArray}}
      ) do
    pv_prop_type = property_types_map[:present_value]

    case is_atom(pv_prop_type) && Map.fetch(@type_mapping, pv_prop_type) do
      {:ok, partial_raw_value} ->
        pv_encoding_type = @type_transform[pv_prop_type] || pv_prop_type

        partial_wrong_type =
          Enum.find(@type_mapping, fn
            {:string, _value} -> nil
            {^pv_prop_type, _value} -> nil
            {_type, _value} -> true
          end)

        {_key, partial_wrong_value} = partial_wrong_type
        partial_wrong_raw_value = Encoding.create!(partial_wrong_type)

        value = %PriorityArray{priority_1: partial_raw_value}
        raw_nil_value = Encoding.create!({:null, nil})

        multi_value = %PriorityArray{
          priority_1: partial_raw_value,
          priority_4: partial_raw_value
        }

        [
          {"#{obj_type} #{property} successful cast (s_pa)", obj_type, property,
           [Encoding.create!({pv_encoding_type, partial_raw_value})], value, {:ok, value}, []},
          {"#{obj_type} #{property} successful cast multi (s_pa)", obj_type, property,
           [
             Encoding.create!({pv_encoding_type, partial_raw_value}),
             raw_nil_value,
             raw_nil_value,
             Encoding.create!({pv_encoding_type, partial_raw_value})
           ], multi_value, {:ok, multi_value}, []},
          {"#{obj_type} #{property} wrong type (s_pa)", obj_type, property,
           [partial_wrong_raw_value], partial_wrong_raw_value,
           {:error, {:invalid_property_value, {property, [partial_wrong_raw_value]}}}, []},
          {"#{obj_type} #{property} successful partial cast (s_pa)", obj_type, property,
           Encoding.create!({pv_encoding_type, partial_raw_value}), partial_raw_value,
           {:ok, partial_raw_value}, [allow_partial: true]},
          {"#{obj_type} #{property} wrong partial type (s_pa)", obj_type, property,
           partial_wrong_raw_value, partial_wrong_value,
           {:error, {:invalid_property_value, {property, partial_wrong_value}}},
           [allow_partial: true]}
        ]

      _else ->
        []
    end
  end

  def generate_cast_tests(
        obj_type,
        _mod,
        _property_types_map,
        {property, {:struct, SetpointReference}}
      ) do
    value = %SetpointReference{ref: ObjectsMacro.get_default_object_ref()}
    {:ok, raw_value} = SetpointReference.encode(value)

    value2 = %SetpointReference{ref: nil}
    {:ok, raw_value2} = SetpointReference.encode(value2)

    [
      {"#{obj_type} #{property} successful cast (s_spr)", obj_type, property,
       Enum.map(raw_value, &Encoding.create!/1), value, {:ok, value}, []},
      # {"#{obj_type} #{property} wrong type (s_spr)", obj_type, property,
      #  Encoding.create!({:boolean, false}), false,
      #  {:error, {:invalid_property_value, {property, Encoding.create!({:boolean, false})}}}, []},
      {"#{obj_type} #{property} successful cast of nil ref (s_spr)", obj_type, property,
       Enum.map(raw_value2, &Encoding.create!/1), value2, {:ok, value2}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        mod,
        _property_types_map,
        {property, {:struct, Encoding} = spec}
      ) do
    {value, _raw_app_tags_value, raw_value} = generate_spec_for_struct_type(property, spec, mod)

    [
      {"#{obj_type} #{property} successful cast (s_enc)", obj_type, property, raw_value, value,
       {:ok, value}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        mod,
        _property_types_map,
        {property, {:struct, _struct_mod} = spec}
      )
      when not :erlang.is_map_key(spec, @type_transform) do
    {value, _raw_app_tags_value, raw_value} = generate_spec_for_struct_type(property, spec, mod)

    [
      {"#{obj_type} #{property} successful cast (s_sf)", obj_type, property, raw_value, value,
       {:ok, value}, []},
      {"#{obj_type} #{property} wrong type (s_sf)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        mod,
        _property_types_map,
        {property, {:list, {:struct, Encoding} = spec}}
      ) do
    {value, _raw_app_tags_value, raw_value} = generate_spec_for_struct_type(property, spec, mod)

    [
      {"#{obj_type} #{property} successful cast (l_s_enc)", obj_type, property, [raw_value],
       value, {:ok, [value]}, []}
    ]
  end

  def generate_cast_tests(
        obj_type,
        mod,
        _property_types_map,
        {property, {:list, {:struct, _struct_mod} = spec}}
      )
      when not :erlang.is_map_key(spec, @type_transform) do
    {value, _raw_app_tags_value, raw_value} = generate_spec_for_struct_type(property, spec, mod)

    [
      {"#{obj_type} #{property} successful cast (s_ots_ss)", obj_type, property,
       List.wrap(raw_value), List.wrap(value), {:ok, List.wrap(value)}, []},
      {"#{obj_type} #{property} wrong type (s_ots_ss)", obj_type, property,
       Encoding.create!({:boolean, false}), false,
       {:error, {:invalid_tags, {property, Encoding.create!({:boolean, false})}}}, []}
    ]
  end

  # Special handling for boolean present_value properties - they are in fact encoded as :enumerated
  def generate_cast_tests(
        obj_type,
        mod,
        _property_types_map,
        {property, :boolean}
      )
      when mod in [ObjectTypes.BinaryInput, ObjectTypes.BinaryOutput, ObjectTypes.BinaryValue] and
             property in [:alarm_value, :feedback_value, :present_value, :relinquish_default] do
    wrong_type =
      Enum.find(@type_mapping, fn
        {:boolean, _value} -> nil
        {:enumerated, _value} -> nil
        {:string, _value} -> nil
        {_type, _value} -> true
      end)

    {_key, wrong_value} = wrong_type
    wrong_raw_value = Encoding.create!(wrong_type)

    [
      {"#{obj_type} #{property} successful cast (fb)", obj_type, property,
       Encoding.create!({:enumerated, 0}), false, {:ok, false}, []},
      {"#{obj_type} #{property} successful cast 2 (fb)", obj_type, property,
       Encoding.create!({:enumerated, 1}), true, {:ok, true}, []},
      {"#{obj_type} #{property} wrong type (fb)", obj_type, property, wrong_raw_value,
       wrong_value, {:error, {:invalid_property_value, {property, wrong_value}}}, []}
    ]
  end

  # Fallback
  def generate_cast_tests(obj_type, _mod, _property_types_map, {property, prop_type}) do
    case Map.fetch(@type_mapping, prop_type) do
      {:ok, value} ->
        encoding_type = @type_transform[prop_type] || prop_type

        wrong_type =
          Enum.find(@type_mapping, fn
            {:string, _value} -> nil
            {^prop_type, _value} -> nil
            {_type, _value} -> true
          end)

        {_key, wrong_value} = wrong_type
        wrong_raw_value = Encoding.create!(wrong_type)

        # For structs, they will use {:error, :invalid_tags}, which gets transformed to the Encoding
        {wrong_type_pattern, wrong_struct_value} =
          if match?({:struct, _mod}, prop_type) do
            {{:error, {:invalid_tags, {property, wrong_raw_value}}}, wrong_raw_value}
          else
            {{:error, {:invalid_property_value, {property, wrong_value}}}, wrong_value}
          end

        [
          {"#{obj_type} #{property} successful cast (fb)", obj_type, property,
           Encoding.create!({encoding_type, value}), value, {:ok, value}, []},
          {"#{obj_type} #{property} wrong type (fb)", obj_type, property, wrong_raw_value,
           wrong_struct_value, wrong_type_pattern, []}
        ]

      :error ->
        # IO.puts("\r\nMissing type_mapping for property #{property} and type #{inspect(prop_type)}")
        []
    end
  end

  @spec generate_spec_for_struct_type(
          Constants.property_identifier(),
          {:struct, module()},
          term()
        ) ::
          {struct(), term(), Encoding.t() | [Encoding.t()]}
  def generate_spec_for_struct_type(property, typespec, cause \\ nil)

  # Special treatment for the log_data and log_datum property
  # as the Encoding struct with nil gets turned into
  # a plain nil, so we need to change the base type
  def generate_spec_for_struct_type(:log_datum, {:struct, Encoding} = _spec, _cause) do
    raw_value = {:tagged, {5, <<1>>, 1}}
    struct_value = Encoding.create!(raw_value, cast_type: :signed_integer)

    {struct_value, raw_value, struct_value}
  end

  def generate_spec_for_struct_type(:log_data, {:struct, Encoding} = _spec, _cause) do
    raw_value = {:tagged, {4, <<1>>, 1}}
    struct_value = Encoding.create!(raw_value, cast_type: :signed_integer)

    {struct_value, raw_value, struct_value}
  end

  def generate_spec_for_struct_type(_property, {:struct, Encoding} = _spec, _cause) do
    raw_value = {:null, nil}
    struct_value = Encoding.create!(raw_value)

    {struct_value, raw_value, struct_value}
  end

  def generate_spec_for_struct_type(_property, {:struct, _mod} = spec, _cause)
      when :erlang.is_map_key(spec, @type_transform) do
    value = Map.fetch!(@type_mapping, spec)
    encoding_type = Map.get(@type_transform, spec)

    {value, {encoding_type, value}, Encoding.create!({encoding_type, value})}
  end

  def generate_spec_for_struct_type(property, {:struct, mod} = spec, cause)
      when not :erlang.is_map_key(spec, @type_transform) do
    Code.ensure_loaded!(mod)

    if function_exported?(mod, :from_bitstring, 1) do
      raw_value =
        mod.__struct__()
        |> Map.from_struct()
        |> map_size()
        |> then(&List.duplicate(nil, &1))
        |> Enum.map(fn _len ->
          Enum.random(0..1) == 1
        end)
        |> List.to_tuple()

      struct_value = mod.from_bitstring(raw_value)
      enc_value = Encoding.create!({:bitstring, raw_value})

      {struct_value, raw_value, enc_value}
    else
      struct_value =
        case Map.fetch(@type_mapping, spec) do
          {:ok, value} ->
            value

          :error ->
            value =
              mod
              |> BeamTypes.resolve_struct_type(:t, @env, ignore_underlined_keys: true)
              |> Enum.map(fn
                {key, {:struct, _mod} = type} ->
                  {value, _raw, _enc} = generate_spec_for_struct_type(key, type, spec)
                  {key, value}

                {key, type} ->
                  {key,
                   Map.get_lazy(@type_mapping, type, fn ->
                     get_generator_for_type(key, type).()
                   end)}
              end)
              |> then(&struct(mod, &1))
              |> then(&amend_struct_spec_for_cause(&1, cause))

            if Map.has_key?(value, :type) and not match?(%ObjectIdentifier{}, value) do
              key = value.type

              value
              |> Map.from_struct()
              |> Map.keys()
              |> Enum.filter(fn
                :type -> false
                ^key -> false
                _else -> true
              end)
              |> Map.new(&{&1, nil})
              |> then(&Map.merge(value, &1))
            else
              value
            end
        end

      if function_exported?(mod, :encode, 1) do
        case mod.encode(struct_value) do
          {:ok, raw_value} ->
            enc_value = Enum.map(raw_value, &Encoding.create!/1)
            {struct_value, raw_value, enc_value}

          _else ->
            generate_spec_for_struct_type(property, spec, cause)
        end
      else
        {struct_value, nil, nil}
      end
    end
  end

  defp get_generator_for_type(property, type)

  defp get_generator_for_type(property, {:array, type}) do
    gen = get_generator_for_type(property, type)

    fn ->
      1..8//1
      |> Enum.random()
      |> then(&List.duplicate(nil, &1))
      |> Enum.map(fn _len ->
        gen.()
      end)
      |> BACnetArray.from_list()
    end
  end

  defp get_generator_for_type(property, {:array, type, size}) do
    gen = get_generator_for_type(property, type)

    fn ->
      size
      |> then(&List.duplicate(nil, &1))
      |> Enum.map(fn _len ->
        gen.()
      end)
      |> BACnetArray.from_list(true)
    end
  end

  for {{:struct, _mod} = spec, value} <- @type_mapping do
    defp get_generator_for_type(_property, unquote(spec)) do
      fn -> unquote(Macro.escape(value)) end
    end
  end

  defp get_generator_for_type(property, {:struct, _mod} = type) do
    fn ->
      {value, _raw, _encoded} = generate_spec_for_struct_type(property, type)
      value
    end
  end

  defp get_generator_for_type(_property, {:constant, const_name}) do
    fn -> generate_constant(const_name) end
  end

  defp get_generator_for_type(_property, {:in_range, min, max}) do
    fn -> Enum.random(min..max//1) end
  end

  defp get_generator_for_type(_property, {:literal, literal}) do
    fn -> literal end
  end

  defp get_generator_for_type(property, {:list, subtype}) do
    gen = get_generator_for_type(property, subtype)

    fn ->
      1..8//1
      |> Enum.random()
      |> then(&List.duplicate(nil, &1))
      |> Enum.map(fn _len ->
        gen.()
      end)
    end
  end

  # Special type
  defp get_generator_for_type(property, {:tuple, subtypes}) do
    generators = Enum.map(subtypes, &get_generator_for_type(property, &1))

    fn ->
      generators
      |> Enum.map(fn gen -> gen.() end)
      |> List.to_tuple()
    end
  end

  defp get_generator_for_type(property, {:type_list, subtype}) do
    # Prefer a {:constant, _} type over anything else
    const = Enum.find(subtype, &match?({:constant, _name}, &1))

    if const do
      get_generator_for_type(property, const)
    else
      gen =
        subtype
        |> Enum.map(fn
          {:literal, nil} ->
            nil

          type ->
            get_generator_for_type(property, type)
        end)
        |> Enum.reject(&is_nil/1)
        |> then(fn
          [] -> if Enum.any?(subtype, &(&1 == {:literal, nil})), do: [fn -> nil end], else: []
          term -> term
        end)

      if gen == [] do
        raise "Generator is empty for type list of #{inspect(subtype)}"
      end

      range = 1..length(gen)//1

      fn ->
        range
        |> Enum.random()
        |> then(&Enum.at(gen, &1 - 1))
        |> then(& &1.())
      end
    end
  end

  defp get_generator_for_type(_property, :any) do
    fn -> nil end
  end

  defp get_generator_for_type(_property, :boolean) do
    fn ->
      Enum.random(0..1//1) == 1
    end
  end

  defp get_generator_for_type(_property, :bitstring) do
    fn ->
      1..32//1
      |> Enum.random()
      |> then(&List.duplicate(nil, &1))
      |> Enum.map(fn _len ->
        Enum.random(0..1//1) == 1
      end)
      |> List.to_tuple()
    end
  end

  defp get_generator_for_type(_property, :real) do
    fn -> Enum.random(-255..255//1) * 1.0 end
  end

  defp get_generator_for_type(_property, :double) do
    fn -> Enum.random(-255..255//1) * 1.0 end
  end

  defp get_generator_for_type(_property, :signed_integer) do
    fn -> Enum.random(-255..255//1) end
  end

  defp get_generator_for_type(_property, :unsigned_integer) do
    fn -> Enum.random(0..255//1) end
  end

  defp get_generator_for_type(property, :octet_string) do
    # Delegate to :string generator, because we want printable chars
    get_generator_for_type(property, :string)
  end

  @string_range List.flatten(Enum.map([?A..?Z, ?a..?z, ?0..?9], &Enum.to_list/1))

  defp get_generator_for_type(_property, :string) do
    fn ->
      1..32//1
      |> Enum.random()
      |> then(&List.duplicate(nil, &1))
      |> Enum.map(fn _len ->
        Enum.random(@string_range)
      end)
      |> List.to_string()
    end
  end

  defp get_generator_for_type(property, {:with_validator, type, validator} = spec) do
    generator = get_generator_for_type(property, type)

    # Validator is a quoted term, so we gotta eval it first to get the function
    {validator_fun, _bind} = Code.eval_quoted(validator)

    fn ->
      value = generator.()

      # Validate the value is good, otherwise try again
      if validator_fun.(value) do
        value
      else
        get_generator_for_type(property, spec).()
      end
    end
  end

  @ascii_table List.flatten(Enum.map([?0..?9, ?A..?Z], &Enum.to_list(&1)))

  defp generate_ascii_string(length) do
    @ascii_table
    |> Enum.take_random(length)
    |> List.to_string()
  end

  defp generate_constant(const_name) do
    Constants.by_value!(const_name, Enum.random(0..32//1))
  rescue
    _exc -> generate_constant(const_name)
  end

  @spec amend_struct_spec_for_cause(struct(), term()) :: struct()
  defp amend_struct_spec_for_cause(struct, cause)

  defp amend_struct_spec_for_cause(%AccessSpecification{properties: props} = struct, _cause) do
    # Sometimes we get a Property struct with a special identifier as property identifier,
    # however this should be simply an atom instead
    new_props =
      Enum.map(props, fn
        %AccessSpecification.Property{property_identifier: id}
        when id in [:all, :required, :optional] ->
          id

        term ->
          term
      end)

    %{struct | properties: new_props}
  end

  defp amend_struct_spec_for_cause(%AddressBinding{} = struct, _cause) do
    %{struct | address: generate_ascii_string(12)}
  end

  defp amend_struct_spec_for_cause(%ObjectIdentifier{} = struct, {:struct, AddressBinding}) do
    %{struct | type: :device}
  end

  # Since PropertyState is kind of special and the relationship between
  # type and value is unknown, we simply hardcode the type and value for now
  defp amend_struct_spec_for_cause(%PropertyState{} = struct, _cause) do
    %{struct | type: :boolean_value, value: Enum.random(0..1//1) == 1}
  end

  defp amend_struct_spec_for_cause(
         %ReadResult{property_value: value, error: %BACnetError{}} = struct,
         _cause
       )
       when not is_nil(value) do
    if Enum.random(0..1) == 1 do
      %{struct | property_value: nil}
    else
      %{struct | error: nil}
    end
  end

  # Make sure structs with device_identifier properties have type device
  defp amend_struct_spec_for_cause(
         %{device_identifier: %ObjectIdentifier{} = id} = struct,
         _cause
       ) do
    %{struct | device_identifier: %{id | type: :device}}
  end

  # Make sure Recipient struct with type device have object identifier type device
  defp amend_struct_spec_for_cause(%Recipient{type: :device, device: device} = struct, _cause) do
    %{struct | device: %{device | type: :device}}
  end

  defp amend_struct_spec_for_cause(
         %TrendLog{logging_type: :polled, log_interval: 0} = struct,
         _cause
       ) do
    %{struct | logging_type: :cov}
  end

  defp amend_struct_spec_for_cause(
         %TrendLog{logging_type: :cov, log_interval: log} = struct,
         _cause
       )
       when log > 0 do
    %{struct | logging_type: :polled}
  end

  defp amend_struct_spec_for_cause(
         %TrendLogMultiple{logging_type: :polled, log_interval: 0} = struct,
         _cause
       ) do
    %{struct | logging_type: :cov}
  end

  defp amend_struct_spec_for_cause(
         %TrendLogMultiple{logging_type: :cov, log_interval: log} = struct,
         _cause
       )
       when log > 0 do
    %{struct | logging_type: :polled}
  end

  defp amend_struct_spec_for_cause(struct, _cause) do
    struct
  end
end
