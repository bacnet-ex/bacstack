defmodule BACnet.Protocol.ObjectOperationsTest.Sample do
  @moduledoc false
  defstruct [
    :object_instance,
    :object_name,
    :present_value,
    :description,
    :out_of_service,
    :status_flags,
    :event_state,
    :reliability,
    :priority_array,
    :relinquish_default,
    :feedback_value,
    :note,
    :gadget,
    :cov_increment,
    :min_present_value,
    :max_present_value,
    :event_enable,
    :_metadata,
    :_unknown_properties
  ]
end

defmodule BACnet.Test.Protocol.ObjectOperationsTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.ObjectOperationsTest.Sample
  alias BACnet.Protocol.ObjectsContract
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Protocol.StatusFlags

  require Constants

  @normal Constants.macro_assert_name(:event_state, :normal)
  @fault Constants.macro_assert_name(:event_state, :fault)
  @no_fault Constants.macro_assert_name(:reliability, :no_fault_detected)

  defp flags(overrides \\ []) do
    struct(
      %StatusFlags{in_alarm: false, fault: false, overridden: false, out_of_service: false},
      overrides
    )
  end

  defp contract(overrides \\ []) do
    base = %ObjectsContract{
      object_module: Sample,
      object_type: :analog_value,
      properties: [
        :object_instance,
        :object_name,
        :present_value,
        :description,
        :out_of_service,
        :status_flags,
        :event_state,
        :reliability,
        :priority_array,
        :relinquish_default,
        :feedback_value,
        :note,
        :gadget,
        :cov_increment,
        :min_present_value,
        :max_present_value,
        :event_enable
      ],
      required: [:object_instance, :object_name, :present_value],
      optional: [:description, :note, :gadget],
      protected: [:object_instance],
      readonly: [:object_name],
      intrinsic: [:event_enable],
      cov: [],
      type_map: %{
        object_instance: :unsigned_integer,
        object_name: :string,
        present_value: :boolean,
        description: :string,
        out_of_service: :boolean,
        status_flags: {:struct, StatusFlags},
        event_state: {:constant, :event_state},
        reliability: {:constant, :reliability},
        priority_array: {:struct, PriorityArray},
        relinquish_default: :boolean,
        feedback_value: :boolean,
        note: :string,
        gadget: :string,
        cov_increment: :real,
        min_present_value: :boolean,
        max_present_value: :boolean,
        event_enable: :boolean
      },
      revision_map: %{},
      implicit_relationships: %{},
      default_properties: %{present_value: false},
      default_properties_all: %{
        present_value: false,
        gadget: "gadget",
        event_enable: true,
        cov_increment: 1.5
      },
      default_intrinsic: %{event_enable: true},
      remote_defaults: %{},
      init_funs: %{},
      validators: %{},
      annotations: [],
      supports_intrinsic: true,
      default_cov_increment: nil,
      has_priority_array: false,
      has_present_value: true,
      has_feedback_value: false,
      has_event_state: false,
      has_status_flags: false,
      has_reliability: false,
      has_out_of_service: false,
      has_relinquish_default: true,
      has_min_max_present_value: false,
      has_physical_input: false
    }

    struct(base, overrides)
  end

  defp hooks(contract, overrides \\ %{}) do
    Map.merge(
      %{
        add_defaults: fn props, metadata ->
          ObjectOperations.add_defaults(contract, props, metadata)
        end,
        check_implicit_relationships: fn object, operation ->
          ObjectOperations.check_implicit_relationships(contract, object, operation)
        end,
        inhibit_object_check: fn object -> {:ok, object} end
      },
      overrides
    )
  end

  defp create(contract, properties \\ %{}, opts \\ [], hook_overrides \\ %{}) do
    ObjectOperations.create(
      contract,
      1,
      "Object",
      properties,
      opts,
      hooks(contract, hook_overrides)
    )
  end

  test "create rejects a missing required property and a bad object name" do
    assert {:error, {:missing_required_property, :present_value}} =
             create(contract(default_properties: %{}), %{})

    assert {:error, {:invalid_non_printable_object_name, :object_name}} =
             ObjectOperations.create(contract(), 1, "", %{}, [], hooks(contract()))
  end

  test "create rejects, ignores, or stores unknown properties" do
    assert {:error, {:unknown_property, :nope}} = create(contract(), %{nope: 1})

    assert {:ok, object} =
             create(contract(), %{5 => false}, allow_unknown_properties: true)

    assert object._unknown_properties[5] == false

    assert {:error, {:unknown_property, :nope}} =
             create(contract(), %{nope: 1}, allow_unknown_properties: true)

    assert {:ok, remote} =
             create(contract(), %{nope: 1, present_value: true},
               allow_unknown_properties: true,
               remote_object: 4
             )

    assert remote._unknown_properties[:nope] == 1

    assert {:ok, ignored} = create(contract(), %{nope: 1}, ignore_unknown_properties: true)
    assert ignored._unknown_properties == %{}
  end

  test "create runs validators and allows numeric constants" do
    contract =
      contract(
        validators: %{
          present_value: {nil, fn value, _object -> value == true end}
        }
      )

    assert {:error, {:value_failed_property_validation, :present_value}} =
             create(contract, %{present_value: false})

    contract =
      contract(
        required: [:object_instance, :object_name, :present_value, :event_state],
        default_properties: %{present_value: false}
      )

    assert {:error, {:invalid_property_type, :event_state}} =
             create(contract, %{event_state: 3})

    assert {:ok, object} =
             create(contract, %{event_state: 3}, allow_numeric_constants: true)

    assert object.event_state == 3
  end

  test "required_when and only_when gate properties" do
    required =
      contract(annotations: [note: [required_when: {:opts, :needs_note}]])

    assert {:error, {:missing_required_property, :note}} =
             create(required, %{}, needs_note: true)

    assert {:ok, %{note: nil}} = create(required, %{})

    only = contract(annotations: [note: [only_when: {:property, :description}]])

    assert {:error, {:property_not_allowed, :note}} =
             create(only, %{note: "x"})

    assert {:error, {:missing_required_property, :note}} =
             create(only, %{description: "d"})

    assert {:ok, object} = create(only, %{description: "d", note: "x"})
    assert object.note == "x"

    optional =
      contract(annotations: [note: [only_when: fn _props, _meta -> :optional end]])

    assert {:ok, %{note: nil}} = create(optional, %{})
  end

  test "revision skip, remote defaults, init_fun, and intrinsic defaults" do
    revised =
      contract(
        required: [:object_instance, :object_name, :note],
        default_properties: %{present_value: false},
        revision_map: %{note: 99}
      )

    assert {:ok, object} = create(revised, %{})
    refute :note in object._metadata.properties_list

    remote_contract = contract(remote_defaults: %{description: "remote"})

    assert {:ok, remote} = create(remote_contract, %{present_value: true}, remote_object: 9)
    assert remote.description == "remote"
    refute remote._metadata.intrinsic_reporting

    local =
      contract(
        init_funs: %{note: fn -> "started" end},
        default_cov_increment: 1.5
      )

    assert {:ok, object} =
             create(local, %{status_flags: flags(), out_of_service: false},
               intrinsic_reporting: true
             )

    assert object.note == "started"
    assert object.cov_increment == 1.5
    assert object.event_enable == true
  end

  test "remote create skips the inhibit hook and does not apply init_fun" do
    contract = contract(init_funs: %{note: fn -> "started" end})

    assert {:ok, remote} =
             create(contract, %{present_value: true}, [remote_object: 3], %{
               inhibit_object_check: fn _object -> raise "inhibit" end
             })

    assert remote.note == nil
    assert remote._metadata.remote_object == 3
  end

  test "implicit relationships add and remove the partner property" do
    contract = contract(implicit_relationships: %{note: :gadget})

    assert {:ok, object} = create(contract, %{note: "n"})
    assert object.gadget == "gadget"
    assert :gadget in object._metadata.properties_list

    assert {:ok, removed} =
             ObjectOperations.remove_property(contract, object, :note, hooks(contract))

    refute :note in removed._metadata.properties_list
    refute :gadget in removed._metadata.properties_list

    missing =
      contract(
        implicit_relationships: %{note: :gadget},
        default_properties_all: %{present_value: false}
      )

    assert {:error, {:missing_optional_property, :gadget}} =
             create(missing, %{note: "n"})
  end

  test "inhibit and add_defaults hooks are honored" do
    assert {:ok, object} =
             create(contract(), %{}, [], %{
               inhibit_object_check: fn object -> {:ok, %{object | description: "patched"}} end
             })

    assert object.description == "patched"

    assert {:error, {:missing_required_property, :weekly}} =
             create(contract(), %{}, [], %{
               add_defaults: fn _props, _metadata ->
                 {:error, {:missing_required_property, :weekly}}
               end
             })

    assert_raise RuntimeError,
                 "Invalid return value from add_defaults/2, we got an ok-tuple",
                 fn ->
                   create(contract(), %{}, [], %{
                     add_defaults: fn _props, _metadata -> {:ok, %{}} end
                   })
                 end
  end

  test "update enforces protected, intrinsic, commandable, and status propagation" do
    propagated =
      contract(
        has_priority_array: true,
        has_event_state: true,
        has_status_flags: true,
        has_reliability: true,
        has_out_of_service: true
      )

    assert {:ok, object} =
             create(propagated, %{
               present_value: false,
               out_of_service: false,
               status_flags: flags(),
               event_state: @normal,
               reliability: @no_fault,
               priority_array: %PriorityArray{priority_16: true},
               relinquish_default: false
             })

    assert object.present_value == true
    assert object.status_flags.out_of_service == false
    assert object.status_flags.in_alarm == false
    assert object.status_flags.fault == false

    assert {:error, {:protected_property, :object_instance}} =
             ObjectOperations.update_property(
               propagated,
               object,
               :object_instance,
               2,
               hooks(propagated)
             )

    assert {:error, {:protected_property, :present_value}} =
             ObjectOperations.update_property(
               propagated,
               object,
               :present_value,
               false,
               hooks(propagated)
             )

    assert {:ok, alarmed} =
             ObjectOperations.update_property(
               propagated,
               object,
               :event_state,
               @fault,
               hooks(propagated)
             )

    assert alarmed.status_flags.in_alarm == true

    intrinsic = %{
      object
      | event_enable: true,
        _metadata: %{
          object._metadata
          | intrinsic_reporting: true,
            properties_list: [:event_enable | object._metadata.properties_list]
        }
    }

    assert {:error, {:intrinsic_property_is_nil, :event_enable}} =
             ObjectOperations.update_property(
               propagated,
               intrinsic,
               :event_enable,
               nil,
               hooks(propagated)
             )
  end

  test "set_priority updates present value and feedback and remaps errors" do
    priority = contract(has_priority_array: true, has_feedback_value: true)

    assert {:ok, object} =
             create(
               priority,
               %{
                 priority_array: %PriorityArray{},
                 relinquish_default: false,
                 status_flags: flags(),
                 out_of_service: false
               },
               auto_write_feedback: true
             )

    assert {:ok, updated} =
             ObjectOperations.set_priority(priority, object, 8, true)

    assert updated.present_value == true
    assert updated.feedback_value == true
    assert updated.priority_array.priority_8 == true

    assert {:ok, cleared} = ObjectOperations.set_priority(priority, updated, 8, nil)
    assert cleared.present_value == false

    assert {:error, {:invalid_property_type, :priority_array}} =
             ObjectOperations.set_priority(priority, object, 8, "bad")

    empty = %{object | priority_array: nil}

    assert {:error, {:unknown_property, :priority_array}} =
             ObjectOperations.set_priority(priority, empty, 1, true)
  end

  test "add_defaults fills relinquish_default from the minimum" do
    ranged = contract(has_min_max_present_value: true)
    metadata = ObjectOperations.create_metadata_from_opts(ranged, [])

    props =
      ObjectOperations.add_defaults(
        ranged,
        %{
          priority_array: %PriorityArray{},
          min_present_value: true,
          max_present_value: true
        },
        metadata
      )

    assert props.relinquish_default == true
  end

  test "property_writable? uses the readonly list and priority array" do
    assert {:ok, object} =
             create(contract(), %{
               description: "d",
               out_of_service: false,
               priority_array: %PriorityArray{}
             })

    assert ObjectOperations.property_writable?(object, :description, [:object_name])
    refute ObjectOperations.property_writable?(object, :object_name, [:object_name])
    refute ObjectOperations.property_writable?(object, :present_value, [])

    service = %{object | out_of_service: true}
    assert ObjectOperations.property_writable?(service, :present_value, [])
  end

  test "inspect prints properties list keys" do
    assert {:ok, object} = create(contract(), %{description: "d"})

    rendered =
      object
      |> ObjectOperations.inspect_object(%Inspect.Opts{limit: 50})
      |> Inspect.Algebra.format(80)
      |> IO.iodata_to_binary()

    assert rendered =~ "ObjectOperationsTest.Sample"
    assert rendered =~ "description"
    assert rendered =~ "present_value"
    refute rendered =~ "note:"
  end

  test "check_property_exists reports membership" do
    assert {:ok, object} = create(contract(), %{})
    assert :ok == ObjectOperations.check_property_exists(object, :present_value)

    assert {:error, {:unknown_property, :note}} ==
             ObjectOperations.check_property_exists(object, :note)
  end

  test "add_property accepts a new property and rejects duplicates, intrinsic, and remote" do
    assert {:ok, object} = create(contract(), %{})

    assert {:ok, added} =
             ObjectOperations.add_property(
               contract(),
               object,
               :description,
               "d",
               hooks(contract())
             )

    assert added.description == "d"
    assert :description in added._metadata.properties_list

    assert {:error, {:property_already_exists, :description}} =
             ObjectOperations.add_property(
               contract(),
               added,
               :description,
               "again",
               hooks(contract())
             )

    assert {:error, {:unknown_property, :nope}} =
             ObjectOperations.add_property(contract(), object, :nope, 1, hooks(contract()))

    assert {:error, {:intrinsic_property_not_allowed, :event_enable}} =
             ObjectOperations.add_property(
               contract(),
               object,
               :event_enable,
               true,
               hooks(contract())
             )

    assert {:error, {:invalid_property_type, :description}} =
             ObjectOperations.add_property(contract(), object, :description, 1, hooks(contract()))

    assert {:error, {:missing_optional_property, :gadget}} =
             ObjectOperations.add_property(
               contract(
                 implicit_relationships: %{description: :gadget},
                 default_properties_all: %{}
               ),
               object,
               :description,
               "d",
               hooks(
                 contract(
                   implicit_relationships: %{description: :gadget},
                   default_properties_all: %{}
                 )
               )
             )

    remote = %{object | _metadata: %{object._metadata | remote_object: 4}}

    assert {:error, :operation_not_available_for_remote_objects} =
             ObjectOperations.add_property(
               contract(),
               remote,
               :description,
               "d",
               hooks(contract())
             )
  end

  test "remove_property drops optional and numeric properties and rejects required ones" do
    assert {:ok, object} = create(contract(), %{description: "d"})

    assert {:ok, same} =
             ObjectOperations.remove_property(contract(), object, :note, hooks(contract()))

    assert same == object

    assert {:ok, removed} =
             ObjectOperations.remove_property(contract(), object, :description, hooks(contract()))

    assert removed.description == nil
    refute :description in removed._metadata.properties_list

    assert {:error, {:property_not_allowed, :present_value}} =
             ObjectOperations.remove_property(
               contract(),
               object,
               :present_value,
               hooks(contract())
             )

    with_unknown = %{object | _unknown_properties: %{7 => :raw}}

    assert {:ok, cleared} =
             ObjectOperations.remove_property(contract(), with_unknown, 7, hooks(contract()))

    assert cleared._unknown_properties == %{}

    remote = %{object | _metadata: %{object._metadata | remote_object: true}}

    assert {:error, :operation_not_available_for_remote_objects} =
             ObjectOperations.remove_property(contract(), remote, :description, hooks(contract()))

    assert {:error, :hook_failed} =
             ObjectOperations.remove_property(
               contract(),
               object,
               :description,
               hooks(contract(), %{
                 check_implicit_relationships: fn _object, :remove -> {:error, :hook_failed} end
               })
             )
  end

  test "get_property reads struct fields and unknown numeric keys" do
    assert {:ok, object} = create(contract(), %{})
    assert {:ok, false} = ObjectOperations.get_property(object, :present_value)
    assert {:error, {:unknown_property, :note}} = ObjectOperations.get_property(object, :note)

    listed = %{
      object
      | _metadata: %{
          object._metadata
          | properties_list: [:not_a_field | object._metadata.properties_list]
        }
    }

    assert {:error, {:unknown_property_identifier, :not_a_field}} =
             ObjectOperations.get_property(listed, :not_a_field)

    stored = %{object | _unknown_properties: %{5 => :raw}}
    assert {:ok, :raw} = ObjectOperations.get_property(stored, 5)
    assert {:error, {:unknown_property_identifier, 9}} = ObjectOperations.get_property(stored, 9)
  end

  test "create ignores nil properties and rejects protected input" do
    assert {:ok, object} = create(contract(), %{note: nil, description: "kept"})
    assert object.description == "kept"
    refute :note in object._metadata.properties_list

    assert {:error, {:protected_property, :object_instance}} =
             create(contract(), %{object_instance: 2})
  end

  test "priority array element validation and unknown property types" do
    priority = contract(has_priority_array: true)

    assert {:ok, object} =
             create(priority, %{priority_array: %PriorityArray{}, relinquish_default: false})

    assert {:error, {:invalid_property_type, :priority_array}} =
             ObjectOperations.update_property(
               priority,
               object,
               :priority_array,
               %PriorityArray{priority_1: "bad"},
               hooks(priority)
             )

    assert {:error, {:unknown_type_for_property, :nope}} =
             ObjectOperations.check_property_value(contract(), object, :nope, 1, false, false)

    bare =
      contract(
        type_map: Map.delete(contract().type_map, :present_value),
        has_priority_array: true
      )

    assert {:error, {:unknown_type_for_property, :priority_array}} =
             ObjectOperations.set_priority(bare, object, 1, true)
  end

  test "validators, skipped remote validation, and physical input metadata" do
    failing = contract(validators: %{description: {fn _value -> false end, nil}})
    assert {:ok, object} = create(contract(), %{description: "d"})

    assert {:error, {:value_failed_property_validation, :description}} =
             ObjectOperations.update_property(failing, object, :description, "d", hooks(failing))

    zero_arity = contract(validators: %{description: {fn -> false end, fn _value -> true end}})

    assert {:error, {:value_failed_property_validation, :description}} =
             ObjectOperations.update_property(
               zero_arity,
               object,
               :description,
               "d",
               hooks(zero_arity)
             )

    passing =
      contract(validators: %{description: {fn -> true end, fn _value, _object -> true end}})

    assert {:ok, _object} =
             ObjectOperations.update_property(passing, object, :description, "d", hooks(passing))

    empty_validators = contract(validators: %{description: {nil, nil}})

    assert {:ok, _object} =
             ObjectOperations.update_property(
               empty_validators,
               object,
               :description,
               "d",
               hooks(empty_validators)
             )

    remote_skip =
      contract(validators: %{description: {nil, fn _value, _object -> false end}})

    assert {:ok, _object} =
             create(remote_skip, %{description: "d", present_value: true},
               remote_object: 2,
               skip_property_validation_remote_object: :value
             )

    metadata =
      ObjectOperations.create_metadata_from_opts(contract(has_physical_input: true),
        physical_input: "yes"
      )

    assert metadata.physical_input == true

    assert_raise ArgumentError, "Object does not support intrinsic reporting", fn ->
      create(contract(supports_intrinsic: false), %{}, intrinsic_reporting: true)
    end
  end

  test "required_when and only_when annotation shapes" do
    assert {:ok, _object} =
             create(
               contract(annotations: [note: [required_when: {:property, :description, "other"}]]),
               %{
                 description: "d"
               }
             )

    assert {:ok, matched} =
             create(
               contract(
                 annotations: [note: [required_when: {:property, :description, "d"}]],
                 default_properties_all: %{present_value: false, note: "filled"}
               ),
               %{description: "d"}
             )

    assert matched.note == "filled"

    assert {:ok, filled} =
             create(
               contract(
                 annotations: [note: [required_when: {:property, :description, :==, "d"}]],
                 default_properties_all: %{present_value: false, note: "filled"}
               ),
               %{description: "d"}
             )

    assert filled.note == "filled"

    assert {:ok, present} =
             create(
               contract(annotations: [note: [required_when: {:opts, :needs_note, "yes"}]]),
               %{description: "d", note: "already"},
               needs_note: "yes"
             )

    assert present.note == "already"

    assert {:ok, _object} =
             create(contract(annotations: [note: [required_when: {:opts, :level, :>, 5}]]), %{})

    assert {:error, {:missing_required_property, :note}} =
             create(
               contract(annotations: [note: [required_when: fn _props -> :optional end]]),
               %{}
             )

    assert {:ok, _object} =
             create(contract(annotations: [note: [required_when: fn _props -> :nope end]]), %{})

    assert {:ok, _object} =
             create(
               contract(annotations: [note: [required_when: fn _props, _meta -> :nope end]]),
               %{}
             )

    assert {:ok, _object} = create(contract(annotations: [note: [required_when: :nope]]), %{})

    assert {:ok, scheduled} =
             create(
               contract(
                 annotations: [note: [only_when: {:property, :description}]],
                 default_properties_all: %{present_value: false, note: "from-default"}
               ),
               %{description: "d"}
             )

    assert scheduled.note == "from-default"
  end

  test "property_writable? covers commandable and event inhibit rules" do
    assert {:ok, object} = create(contract(), %{})
    assert ObjectOperations.property_writable?(object, :present_value, [])

    max_id = Constants.macro_by_name(:asn1, :max_instance_and_property_id)

    inhibit =
      object
      |> Map.put(:event_detection_enable, true)
      |> Map.put(:event_algorithm_inhibit_ref, %{object_identifier: %{instance: max_id}})
      |> then(fn obj ->
        %{
          obj
          | _metadata: %{
              obj._metadata
              | properties_list: [:event_algorithm_inhibit | obj._metadata.properties_list]
            }
        }
      end)

    assert ObjectOperations.property_writable?(inhibit, :event_algorithm_inhibit, [])

    other_instance =
      Map.put(inhibit, :event_algorithm_inhibit_ref, %{object_identifier: %{instance: 1}})

    refute ObjectOperations.property_writable?(other_instance, :event_algorithm_inhibit, [])

    no_ref = Map.put(inhibit, :event_algorithm_inhibit_ref, nil)
    assert ObjectOperations.property_writable?(no_ref, :event_algorithm_inhibit, [])

    disabled = Map.put(no_ref, :event_detection_enable, false)
    refute ObjectOperations.property_writable?(disabled, :event_algorithm_inhibit, [])
  end

  test "remove honors required_when and remote updates skip the intrinsic check" do
    gated = contract(annotations: [note: [required_when: {:property, :description}]])
    assert {:ok, object} = create(gated, %{description: "d", note: "n"})

    assert {:error, {:property_not_allowed, :note}} =
             ObjectOperations.remove_property(gated, object, :note, hooks(gated))

    assert {:ok, _object} =
             create(contract(annotations: [note: [required_when: {:opts, :level, :>, 5}]]), %{},
               level: 1
             )

    assert {:ok, local} = create(contract(), %{})
    remote = %{local | _metadata: %{local._metadata | remote_object: 8}}

    assert {:ok, updated} =
             ObjectOperations.update_property(
               contract(),
               remote,
               :present_value,
               true,
               hooks(contract())
             )

    assert updated.present_value == true
  end

  test "propagation leaves feedback unchanged without auto_write_feedback" do
    feedback = contract(has_feedback_value: true)
    assert {:ok, object} = create(feedback, %{description: "d"})

    assert {:ok, updated} =
             ObjectOperations.update_property(
               feedback,
               object,
               :description,
               "e",
               hooks(feedback)
             )

    assert updated.description == "e"
    assert updated.feedback_value == nil
  end

  test "add_defaults leaves relinquish_default unset without a minimum" do
    ranged = contract(has_min_max_present_value: true)
    metadata = ObjectOperations.create_metadata_from_opts(ranged, [])

    props =
      ObjectOperations.add_defaults(ranged, %{priority_array: %PriorityArray{}}, metadata)

    refute Map.has_key?(props, :relinquish_default)
  end

  test "set_priority leaves feedback alone when the object has no feedback property" do
    priority = contract(has_priority_array: true, has_feedback_value: false)

    assert {:ok, object} =
             create(priority, %{priority_array: %PriorityArray{}, relinquish_default: false})

    assert {:ok, updated} = ObjectOperations.set_priority(priority, object, 3, true)
    assert updated.present_value == true
    assert updated.feedback_value == nil
  end
end
