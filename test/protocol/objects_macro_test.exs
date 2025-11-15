defmodule BACnet.Test.Protocol.ObjectsMacroTest do
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventMessageTexts
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.PriorityArray

  require Constants

  use ExUnit.Case, async: true
  use ObjectsMacro

  @moduletag :object_test
  @moduletag :object_macro_test

  doctest ObjectsMacro

  # TODO: Add more create/4 tests (to verify working all features and also error conditions)

  test "get default BACnet DateTime" do
    assert %BACnetDateTime{
             date: %BACnetDate{
               year: :unspecified,
               month: :unspecified,
               day: :unspecified,
               weekday: :unspecified
             },
             time: %BACnetTime{
               hour: :unspecified,
               minute: :unspecified,
               second: :unspecified,
               hundredth: :unspecified
             }
           } = ObjectsMacro.get_default_bacnet_datetime()
  end

  test "get default BACnet timestamp" do
    assert %BACnetTimestamp{
             type: :datetime,
             time: nil,
             sequence_number: nil,
             datetime: %BACnetDateTime{
               date: %BACnetDate{
                 year: :unspecified,
                 month: :unspecified,
                 day: :unspecified,
                 weekday: :unspecified
               },
               time: %BACnetTime{
                 hour: :unspecified,
                 minute: :unspecified,
                 second: :unspecified,
                 hundredth: :unspecified
               }
             }
           } = ObjectsMacro.get_default_bacnet_timestamp()
  end

  test "get default event message texts" do
    assert %EventMessageTexts{
             to_offnormal: "To-OffNormal",
             to_fault: "To-Fault",
             to_normal: "To-Normal"
           } = ObjectsMacro.get_default_event_message_texts()
  end

  test "get default event transition bits" do
    assert %EventTransitionBits{
             to_offnormal: default_value,
             to_fault: default_value,
             to_normal: default_value
           } = ObjectsMacro.get_default_event_transbits()
  end

  test "get default device object property reference" do
    assert %DeviceObjectPropertyRef{
             object_identifier: %ObjectIdentifier{
               type: Constants.macro_assert_name(:object_type, :binary_input),
               instance: Constants.macro_by_name(:asn1, :max_instance_and_property_id)
             },
             property_identifier: Constants.macro_by_name(:asn1, :max_instance_and_property_id),
             property_array_index: nil,
             device_identifier: nil
           } = ObjectsMacro.get_default_dev_object_ref()
  end

  test "get default object property reference" do
    assert %ObjectPropertyRef{
             object_identifier: %ObjectIdentifier{
               type: Constants.macro_assert_name(:object_type, :binary_input),
               instance: Constants.macro_by_name(:asn1, :max_instance_and_property_id)
             },
             property_identifier: Constants.macro_by_name(:asn1, :max_instance_and_property_id),
             property_array_index: nil
           } = ObjectsMacro.get_default_object_ref()
  end

  test "bac_object requires valid object type" do
    assert_raise ArgumentError, ~r/invalid object type/i, fn ->
      defmodule BacObjectMinimalInvalidObjectTypeStub do
        use ObjectsMacro

        bac_object :hello_there do
        end
      end
    end
  end

  test "bac-object raises for unknown property" do
    assert_raise ArgumentError, ~r/unknown property name/i, fn ->
      defmodule BacObjectMinimalInvalidObjectTypeStub do
        use ObjectsMacro

        bac_object :binary_input do
          field(:hello_there, boolean())
        end
      end
    end
  end

  test "bac_object single field no services is allowed" do
    value =
      defmodule BacObjectMinimalSingleFieldTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, boolean())
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object cov property" do
    value =
      defmodule BacObjectMinimalSingleFieldCovTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, boolean(), cov: true)
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object default value constant value boolean" do
    value =
      defmodule BacObjectMinimalDefaultValueConstantValueTestStub do
        use ObjectsMacro

        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, boolean(), required: true, default: true)
        end
      end

    alias BacObjectMinimalDefaultValueConstantValueTestStub, as: TestStub

    assert {:module, _modname, _bytecode, _more} = value
    assert {:ok, %{profile_name: true}} = TestStub.create(1, "TEST")
  end

  test "bac_object default value constant value map" do
    value =
      defmodule BacObjectMinimalDefaultValueConstantValueMapTestStub do
        use ObjectsMacro

        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, URI.t(), required: true, default: %URI{})
        end
      end

    alias BacObjectMinimalDefaultValueConstantValueMapTestStub, as: TestStub

    assert {:module, _modname, _bytecode, _more} = value
    assert {:ok, %{profile_name: %URI{}}} = TestStub.create(1, "TEST")
  end

  test "bac_object default value constant value string concat" do
    value =
      defmodule BacObjectMinimalDefaultValueConstantValueStrinConcatTestStub do
        use ObjectsMacro

        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, String.t(), required: true, default: "bac" <> "stack")
        end
      end

    alias BacObjectMinimalDefaultValueConstantValueStrinConcatTestStub, as: TestStub

    assert {:module, _modname, _bytecode, _more} = value
    assert {:ok, %{profile_name: "bacstack"}} = TestStub.create(1, "TEST")
  end

  test "bac_object default value constant value tuple" do
    value =
      defmodule BacObjectMinimalDefaultValueConstantValueTupleTestStub do
        use ObjectsMacro

        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, tuple(), required: true, default: {true, false})
        end
      end

    alias BacObjectMinimalDefaultValueConstantValueTupleTestStub, as: TestStub

    assert {:module, _modname, _bytecode, _more} = value
    assert {:ok, %{profile_name: {true, false}}} = TestStub.create(1, "TEST")
  end

  test "bac_object raises for invalid default value" do
    assert_raise ArgumentError,
                 ~r/invalid default value for field profile_name,\s*expected type \":boolean\"/i,
                 fn ->
                   defmodule BacObjectMinimalSingleFieldDefaultValueNilTestStub do
                     use ObjectsMacro

                     @type object_opts :: nil

                     bac_object :binary_input do
                       field(:profile_name, boolean(), default: quote(do: nil))
                     end
                   end
                 end
  end

  test "bac_object default value function call" do
    value =
      defmodule BacObjectMinimalDefaultValueFunctionCallTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, boolean(), default: Kernel.is_boolean(true))
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object default value function capture" do
    defmodule BacObjectMinimalDefaultValueFunctionCaptureTestStub.Test do
      def init(), do: false
    end

    value =
      defmodule BacObjectMinimalDefaultValueFunctionCaptureTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, boolean(), default: &__MODULE__.Test.init/0)
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object default value function capture invalid arity" do
    assert_raise ArgumentError,
                 ~r/function captures with arity > 0 are not supported/i,
                 fn ->
                   defmodule BacObjectMinimalDefaultValueInvalidFunctionCaptureArityTestStub.Test do
                     def init(_a), do: false
                   end

                   defmodule BacObjectMinimalDefaultValueInvalidFunctionCaptureArityTestStub do
                     use ObjectsMacro

                     @compile {:autoload, false}
                     @type object_opts :: nil

                     bac_object :binary_input do
                       field(:profile_name, boolean(), default: &__MODULE__.Test.init/1)
                     end
                   end
                 end
  end

  test "bac_object default value function capture invalid arity 2" do
    assert_raise ArgumentError,
                 ~r/function captures with arity > 0 are not supported/i,
                 fn ->
                   defmodule BacObjectMinimalDefaultValueInvalidFunctionCaptureArity2TestStub.Test do
                     def init(_a), do: false
                   end

                   defmodule BacObjectMinimalDefaultValueInvalidFunctionCaptureArity2TestStub do
                     use ObjectsMacro

                     @compile {:autoload, false}
                     @type object_opts :: nil

                     bac_object :binary_input do
                       field(:profile_name, boolean(), default: &is_boolean(&1))
                     end
                   end
                 end
  end

  test "bac_object default value function definition" do
    value =
      defmodule BacObjectMinimalDefaultValueFunctionDefinitionTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, boolean(), default: fn -> true end)
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object default value function definition invalid arity" do
    assert_raise ArgumentError,
                 ~r/functions with arity > 0 are not supported/i,
                 fn ->
                   defmodule BacObjectMinimalDefaultValueInvalidFunctionDefinitionArityTestStub do
                     use ObjectsMacro

                     @compile {:autoload, false}
                     @type object_opts :: nil

                     bac_object :binary_input do
                       field(:profile_name, boolean(), default: fn _a -> true end)
                     end
                   end
                 end
  end

  test "bac_object default value invalid variable" do
    assert_raise ArgumentError,
                 ~r/variables can not be given to the default value/i,
                 fn ->
                   defmodule BacObjectMinimalDefaultValueInvalidVariableTestStub do
                     use ObjectsMacro

                     @compile {:autoload, false}
                     @type object_opts :: nil

                     bac_object :binary_input do
                       field(:profile_name, boolean(), default: my_var)
                     end
                   end
                 end
  end

  test "bac_object with default intrinsic properties" do
    value =
      defmodule BacObjectMinimalDefaultIntrinsicPropertiesTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :binary_input do
          field(:profile_name, boolean(), intrinsic: true, default: true)
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object with default cov_increment property" do
    value =
      defmodule BacObjectMinimalDefaultCovIncrementTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :analog_input do
          field(:cov_increment, float(), default: 1.0)
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object with init_fun" do
    value =
      defmodule BacObjectMinimalDefaultInitFunTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        def init(), do: 1.0

        bac_object :analog_input do
          field(:present_value, float(), init_fun: &__MODULE__.init/0)
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object with invalid init_fun arity" do
    assert_raise ArgumentError,
                 ~r/Invalid init_fun for field present_value given,\s*.*?arity > 0.*/i,
                 fn ->
                   defmodule BacObjectMinimalInvalidInitFunArityTestStub do
                     use ObjectsMacro

                     @compile {:autoload, false}
                     @type object_opts :: nil

                     bac_object :analog_input do
                       field(:present_value, float(), init_fun: &IO.puts/1)
                     end
                   end
                 end
  end

  test "bac_object with invalid init_fun expects remote fun call" do
    assert_raise ArgumentError,
                 ~r/invalid init_fun for field present_value given,\s*expected a remote function capture/i,
                 fn ->
                   defmodule BacObjectMinimalInvalidRemoteInitFunTestStub do
                     use ObjectsMacro

                     @type object_opts :: nil

                     bac_object :analog_input do
                       field(:present_value, float(), init_fun: fn -> 1.0 end)
                     end
                   end
                 end
  end

  test "bac_object with bac_type specified as atom" do
    value =
      defmodule BacObjectMinimalBacTypeAtomTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :analog_input do
          field(:present_value, float(), bac_type: :double)
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object with bac_type specified as validator" do
    value =
      defmodule BacObjectMinimalBacTypeTupleTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :analog_input do
          field(:present_value, float(),
            bac_type: {:with_validator, :double, fn t -> t >= 0.0 end}
          )
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object with invalid bac_type specified" do
    assert_raise ArgumentError,
                 ~r/invalid bac_type for field present_value/i,
                 fn ->
                   defmodule BacObjectMinimalInvalidBacTypeTestStub do
                     use ObjectsMacro

                     @type object_opts :: nil

                     bac_object :analog_input do
                       field(:present_value, float(), bac_type: &IO.puts/1)
                     end
                   end
                 end
  end

  test "bac_object with implicit_relationship specified" do
    value =
      defmodule BacObjectMinimalImplicitRelationshipTestStub do
        use ObjectsMacro

        @type object_opts :: nil

        bac_object :analog_input do
          field(:present_value, float(), default: 0.0)
          field(:polarity, boolean(), default: false, implicit_relationship: :present_value)
        end
      end

    alias BacObjectMinimalImplicitRelationshipTestStub, as: TestStub

    assert {:module, _modname, _bytecode, _more} = value
    assert {:ok, %{present_value: nil, polarity: nil}} = TestStub.create(1, "TEST", %{})

    assert {:ok, %{present_value: 1.0, polarity: false}} =
             TestStub.create(1, "TEST", %{present_value: 1.0})

    assert {:ok, %{present_value: +0.0, polarity: true}} =
             TestStub.create(1, "TEST", %{polarity: true})
  end

  test "bac_object with invalid implicit_relationship specified" do
    assert_raise ArgumentError,
                 ~r/invalid implicit relationship value for field present_value/i,
                 fn ->
                   defmodule BacObjectMinimalInvalidImplicitRelationshipTestStub do
                     use ObjectsMacro

                     @type object_opts :: nil

                     bac_object :analog_input do
                       field(:present_value, float(), implicit_relationship: :present_value)
                     end
                   end
                 end
  end

  test "bac_object with validator_fun as capture remote" do
    value =
      defmodule BacObjectMinimalValidatorCaptureRemoteTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :analog_input do
          field(:present_value, float(), validator_fun: &is_nil/1)
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object with validator_fun as capture function" do
    value =
      defmodule BacObjectMinimalValidatorCaptureFunctionTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :analog_input do
          field(:present_value, float(), validator_fun: &(not is_nil(&1)))
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object with validator_fun as remote call" do
    value =
      defmodule BacObjectMinimalValidatorRemoteCallTestStub do
        use ObjectsMacro

        @compile {:autoload, false}
        @type object_opts :: nil

        bac_object :analog_input do
          field(:present_value, float(), validator_fun: &IO.puts/1)
        end
      end

    assert {:module, _modname, _bytecode, _more} = value
  end

  test "bac_object with invalid validator_fun specified" do
    assert_raise ArgumentError,
                 ~r/invalid validator_fun for field present_value/i,
                 fn ->
                   defmodule BacObjectMinimalInvalidValidatorFunTestStub do
                     use ObjectsMacro

                     @type object_opts :: nil

                     bac_object :analog_input do
                       field(:present_value, float(), validator_fun: :hello_there)
                     end
                   end
                 end
  end

  test "verify docs for minimal docs stub" do
    {:docs_v1, _ver, :elixir, "text/markdown", %{"en" => moduledoc}, _any, docs} =
      Code.fetch_docs(
        BACnet.Test.Support.Protocol.ObjectsMacroTestSupport.BacObjectMinimalDocsStub
      )

    # Verify moduledoc (it contains some substrings from our generated part - verifying more would be too cumbersome)
    assert true ==
             String.contains?(moduledoc, "The following part has been automatically generated")

    assert true == String.contains?(moduledoc, "`binary_input`")

    # Verify generated functions are present
    for {name, arity, doc} <- [
          {:add_property, 3, quote(do: %{"en" => _docs})},
          {:create, 4, quote(do: %{"en" => _docs})},
          {:fetch, 2, quote(do: :hidden)},
          {:get_all_properties, 0, quote(do: %{"en" => _docs})},
          {:get_annotation, 1, quote(do: %{"en" => _docs})},
          {:get_annotations, 0, quote(do: %{"en" => _docs})},
          {:get_cov_properties, 0, quote(do: %{"en" => _docs})},
          {:get_intrinsic_properties, 0, quote(do: %{"en" => _docs})},
          {:get_object_identifier, 1, quote(do: %{"en" => _docs})},
          {:get_optional_properties, 0, quote(do: %{"en" => _docs})},
          {:get_properties, 1, quote(do: %{"en" => _docs})},
          {:get_properties_type_map, 0, quote(do: %{"en" => _docs})},
          {:get_property, 2, quote(do: %{"en" => _docs})},
          {:get_protected_properties, 0, quote(do: %{"en" => _docs})},
          {:get_readonly_properties, 0, quote(do: %{"en" => _docs})},
          {:get_required_properties, 0, quote(do: %{"en" => _docs})},
          {:has_property?, 2, quote(do: %{"en" => _docs})},
          {:intrinsic_reporting?, 1, quote(do: %{"en" => _docs})},
          {:property_writable?, 2, quote(do: %{"en" => _docs})},
          {:remove_property, 2, quote(do: %{"en" => _docs})},
          {:supports_intrinsic, 0, quote(do: %{"en" => _docs})},
          {:update_property, 3, quote(do: %{"en" => _docs})}
        ] do
      value =
        Enum.find(docs, fn
          {{:function, ^name, ^arity}, _ver, _head, _doc, _any} -> true
          _else -> false
        end)

      # Since we can't unfortunately pattern match directly on the variable "doc",
      # this is a workaround
      generated_assert =
        quote do
          assert {{:function, unquote(name), unquote(arity)}, _ver, _head, unquote(doc), _any} =
                   unquote(Macro.escape(value))
        end

      Code.eval_quoted(generated_assert)
    end

    # Verify generated types are present
    for {name, arity, doc} <- [
          {:common_object_opts, 0, quote(do: %{"en" => _docs})},
          {:internal_metadata, 0, quote(do: :hidden)},
          {:object_opts, 0, quote(do: :none)},
          {:property_name, 0, quote(do: %{"en" => _docs})},
          {:property_update_error, 0, quote(do: %{"en" => _docs})},
          # Docs for type :t must be self-provided
          # (and can be directly above the function/macro invokation)
          {:t, 0, quote(do: :none)}
        ] do
      value =
        Enum.find(docs, fn
          {{:type, ^name, ^arity}, _ver, _head, _doc, _any} -> true
          _else -> false
        end)

      # Since we can't unfortunately pattern match directly on the variable "doc",
      # this is a workaround
      generated_assert =
        quote do
          assert {{:type, unquote(name), unquote(arity)}, _ver, _head, unquote(doc), _any} =
                   unquote(Macro.escape(value))
        end

      Code.eval_quoted(generated_assert)
    end
  end

  test "verify docs for minimal docs stub with already present moduledoc" do
    {:docs_v1, _ver, :elixir, "text/markdown", %{"en" => moduledoc}, _any, _docs} =
      Code.fetch_docs(
        BACnet.Test.Support.Protocol.ObjectsMacroTestSupport.BacObjectMinimalDocsStub2
      )

    # Verify moduledoc (it contains some substrings from our generated part - verifying more would be too cumbersome)
    assert true == String.contains?(moduledoc, "Hello there")
    assert true == String.contains?(moduledoc, "---------------")

    assert true ==
             String.contains?(moduledoc, "The following part has been automatically generated")

    assert true == String.contains?(moduledoc, "`binary_input`")
  end

  # Minimal stub module for many tests
  {:module, mod_name_minimal_stub, bytecode_minimal_stub, _more} =
    defmodule BacObjectMinimalStub do
      use ObjectsMacro

      @type object_opts :: nil

      bac_object :binary_input do
        services(intrinsic: true)

        # Keep present_value first for coverage for pv_type_raw Enum.find_value/3
        field(:present_value, boolean(), required: true, default: false)
        field(:description, String.t())
        field(:device_type, String.t())
        field(:out_of_service, boolean(), required: true)
      end
    end

  # test "verify some functions are overridable" do
  #   # Public functions
  #   assert true == Module.overridable?(unquote(mod_name_minimal_stub), {:create, 2})
  #   assert true == Module.overridable?(unquote(mod_name_minimal_stub), {:create, 3})
  #   assert true == Module.overridable?(unquote(mod_name_minimal_stub), {:create, 4})
  #   assert true == Module.overridable?(unquote(mod_name_minimal_stub), {:add_property, 3})
  #   assert true == Module.overridable?(unquote(mod_name_minimal_stub), {:remove_property, 2})
  #   assert true == Module.overridable?(unquote(mod_name_minimal_stub), {:update_property, 3})
  #   assert true == Module.overridable?(unquote(mod_name_minimal_stub), {:property_writable?, 2})

  #   # Internal functions (defp)
  #   assert true == Module.overridable?(unquote(mod_name_minimal_stub), {:add_defaults, 2})

  #   assert true ==
  #            Module.overridable?(
  #              unquote(mod_name_minimal_stub),
  #              {:check_implicit_relationships, 2}
  #            )
  # end

  test "verify get_intrinsic_properties/0 of defined bacnet object" do
    # Verify intrinsic properties
    assert [
             :acked_transitions,
             :event_algorithm_inhibit,
             :event_algorithm_inhibit_ref,
             :event_detection_enable,
             :event_enable,
             :event_message_texts,
             :event_message_texts_config,
             :event_timestamps,
             :limit_enable,
             :notification_class,
             :notify_type,
             :time_delay,
             :time_delay_normal
           ] = Enum.sort(unquote(mod_name_minimal_stub).get_intrinsic_properties())
  end

  test "verify get_optional_properties/0 of defined bacnet object" do
    # Verify optional properties
    assert [
             :acked_transitions,
             :description,
             :device_type,
             :event_algorithm_inhibit,
             :event_algorithm_inhibit_ref,
             :event_detection_enable,
             :event_enable,
             :event_message_texts,
             :event_message_texts_config,
             :event_timestamps,
             :limit_enable,
             :notification_class,
             :notify_type,
             :time_delay,
             :time_delay_normal
           ] = Enum.sort(unquote(mod_name_minimal_stub).get_optional_properties())
  end

  test "verify get_protected_properties/0 of defined bacnet object" do
    # Verify protected properties
    assert [
             :_metadata,
             :_unknown_properties,
             :_writable_properties,
             :object_identifier,
             :object_type
           ] = Enum.sort(unquote(mod_name_minimal_stub).get_protected_properties())
  end

  test "verify get_properties_type_map/0 of defined bacnet object" do
    # Verify properties type map contains the basic properties + the defined new properties
    assert %{
             acked_transitions: {:struct, BACnet.Protocol.EventTransitionBits},
             description: :string,
             device_type: :string,
             event_algorithm_inhibit: :boolean,
             event_algorithm_inhibit_ref: {:struct, BACnet.Protocol.ObjectPropertyRef},
             event_detection_enable: :boolean,
             event_enable: {:struct, BACnet.Protocol.EventTransitionBits},
             event_message_texts: {:struct, BACnet.Protocol.EventMessageTexts},
             event_message_texts_config: {:struct, BACnet.Protocol.EventMessageTexts},
             event_state: {:constant, :event_state},
             event_timestamps: {:struct, BACnet.Protocol.EventTimestamps},
             limit_enable: {:struct, BACnet.Protocol.LimitEnable},
             notification_class: :unsigned_integer,
             notify_type: {:constant, :notify_type},
             object_instance: :unsigned_integer,
             object_name: :string,
             out_of_service: :boolean,
             present_value: :boolean,
             priority_array: {:struct, BACnet.Protocol.PriorityArray},
             profile_name: :string,
             reliability: {:constant, :reliability},
             reliability_evaluation_inhibit: :boolean,
             status_flags: {:struct, BACnet.Protocol.StatusFlags},
             time_delay: :unsigned_integer,
             time_delay_normal: :unsigned_integer,
             units: {:constant, :engineering_unit},
             update_interval: :unsigned_integer
           } = unquote(mod_name_minimal_stub).get_properties_type_map()
  end

  test "verify create/4 of defined bacnet object ignores nil values" do
    assert {:ok, %{present_value: false}} =
             unquote(mod_name_minimal_stub).create(1, "TEST", %{present_value: nil})

    # Even if the property is unknown, it gets discarded without complaining
    assert {:ok, %{present_value: false}} =
             unquote(mod_name_minimal_stub).create(1, "TEST", %{present: nil})
  end

  test "verify create/4 of defined bacnet object fails for invalid object instance number" do
    assert_raise FunctionClauseError, fn ->
      unquote(mod_name_minimal_stub).create(-1, "nil")
    end

    assert_raise FunctionClauseError, fn ->
      unquote(mod_name_minimal_stub).create(4_194_303, "nil")
    end
  end

  test "verify create/4 of defined bacnet object fails for empty object name" do
    assert {:error, {:invalid_non_printable_object_name, :object_name}} =
             unquote(mod_name_minimal_stub).create(1, "")
  end

  test "verify create/4 of defined bacnet object fails for non-printable object name" do
    assert {:error, {:invalid_non_printable_object_name, :object_name}} =
             unquote(mod_name_minimal_stub).create(1, <<0, 5, 90, 2>>)
  end

  test "verify create/4 of defined bacnet object fails for non-intrinsic and intrinsic property" do
    assert {:error, {:intrinsic_property_not_available, :notification_class}} =
             unquote(mod_name_minimal_stub).create(1, "TEST", %{notification_class: 0})
  end

  test "verify create/4 of defined bacnet object fails for unknown properties" do
    assert {:error, {:unknown_property, :present}} =
             unquote(mod_name_minimal_stub).create(1, "TEST", %{present: false})
  end

  test "verify create/4 of defined bacnet object fails unknown atomic properties with allowed" do
    assert {:error, {:unknown_property, :present}} =
             unquote(mod_name_minimal_stub).create(1, "TEST", %{present: false},
               allow_unknown_properties: true
             )
  end

  test "verify create/4 of defined bacnet object accepts unknown atomic properties with allowed if remote" do
    assert {:ok, obj} =
             unquote(mod_name_minimal_stub).create(1, "TEST", %{present: false},
               allow_unknown_properties: true,
               remote_object: 1555
             )

    refute Map.has_key?(obj, :present)
    assert Map.has_key?(obj._unknown_properties, :present)
  end

  test "verify create/4 of defined bacnet object accepts unknown numeric properties with allowed" do
    assert {:ok, obj} =
             unquote(mod_name_minimal_stub).create(1, "TEST", %{5 => false},
               allow_unknown_properties: true
             )

    refute Map.has_key?(obj, 5)
    assert Map.has_key?(obj._unknown_properties, 5)
  end

  test "verify create/4 of defined bacnet object does not fail unknown properties if ignored" do
    assert {:ok, obj} =
             unquote(mod_name_minimal_stub).create(1, "TEST", %{present: false},
               ignore_unknown_properties: true
             )

    refute Map.has_key?(obj, :present)
    refute Map.has_key?(obj._unknown_properties, :present)
  end

  # Minimal stub module with annotations for tests below
  {:module, mod_name_annotations_stub, _bytecode, _more} =
    defmodule BacObjectAnnotationsStub do
      @compile :debug_info

      use ObjectsMacro

      @type object_opts :: nil

      bac_object :binary_input do
        services(intrinsic: true)

        field(:description, String.t())
        field(:device_type, String.t(), annotation: [required_when: :bacnet_22])

        field(:out_of_service, boolean(),
          required: true,
          annotation: [test: true],
          annotation: [test2: false]
        )

        field(:present_value, boolean(), required: true, default: false)
      end
    end

  test "verify get_annotations/0 of defined bacnet object" do
    # Verify annotations
    assert [
             {:acked_transitions, []},
             {:description, []},
             {:device_type, [required_when: :bacnet_22]},
             {:event_algorithm_inhibit, []},
             {:event_algorithm_inhibit_ref, []},
             {:event_detection_enable, []},
             {:event_enable, []},
             {:event_message_texts, []},
             {:event_message_texts_config, []},
             {:event_timestamps, []},
             {:limit_enable, []},
             {:notification_class, []},
             {:notify_type, []},
             {:object_instance, []},
             {:object_name, []},
             {:out_of_service, [{:test, true}, {:test2, false}]},
             {:present_value, []},
             {:time_delay, []},
             {:time_delay_normal, []}
           ] = Enum.sort_by(unquote(mod_name_annotations_stub).get_annotations(), &elem(&1, 0))
  end

  test "verify get_annotation/0 of defined bacnet object" do
    assert [] = unquote(mod_name_annotations_stub).get_annotation(:description)

    assert [required_when: :bacnet_22] =
             unquote(mod_name_annotations_stub).get_annotation(:device_type)

    assert [test: true, test2: false] =
             unquote(mod_name_annotations_stub).get_annotation(:out_of_service)
  end

  # Our test object for the following tests below
  {:ok, test_obj} = mod_name_minimal_stub.create(1, "TEST")
  {:ok, test_obj_intrin} = mod_name_minimal_stub.create(1, "TEST", %{}, intrinsic_reporting: true)
  {:ok, test_obj_optional} = mod_name_minimal_stub.create(1, "TEST", %{device_type: "hello"})

  test "verify get_properties/1 of defined bacnet object" do
    # Verify properties (all properties that are part of the instanced object)
    assert [
             :event_state,
             :object_instance,
             :object_name,
             :out_of_service,
             :present_value,
             :status_flags
           ] =
             Enum.sort(
               unquote(mod_name_minimal_stub).get_properties(unquote(Macro.escape(test_obj)))
             )

    assert [
             :acked_transitions,
             :event_algorithm_inhibit,
             :event_algorithm_inhibit_ref,
             :event_detection_enable,
             :event_enable,
             :event_message_texts,
             :event_message_texts_config,
             :event_state,
             :event_timestamps,
             :limit_enable,
             :notification_class,
             :notify_type,
             :object_instance,
             :object_name,
             :out_of_service,
             :present_value,
             :status_flags,
             :time_delay,
             :time_delay_normal
           ] =
             Enum.sort(
               unquote(mod_name_minimal_stub).get_properties(
                 unquote(Macro.escape(test_obj_intrin))
               )
             )
  end

  test "verify get_object_identifier/1 of defined bacnet object" do
    assert %ObjectIdentifier{type: :binary_input, instance: 1} =
             unquote(mod_name_minimal_stub).get_object_identifier(unquote(Macro.escape(test_obj)))
  end

  test "verify get_property/1 of defined bacnet object" do
    assert {:ok, "TEST"} =
             unquote(mod_name_minimal_stub).get_property(
               unquote(Macro.escape(test_obj)),
               :object_name
             )
  end

  test "verify get_property/1 of defined bacnet object fails for unknown property" do
    assert {:error, {:unknown_property, :object_type}} =
             unquote(mod_name_minimal_stub).get_property(
               unquote(Macro.escape(test_obj)),
               :object_type
             )
  end

  test "verify has_property?/1 of defined bacnet object" do
    test_obj = unquote(Macro.escape(test_obj))

    assert true ==
             unquote(mod_name_minimal_stub).has_property?(test_obj, :out_of_service)

    assert false ==
             unquote(mod_name_minimal_stub).has_property?(test_obj, :object_type)
  end

  test "verify intrinsic_reporting?/1 of defined bacnet object" do
    assert false ==
             unquote(mod_name_minimal_stub).intrinsic_reporting?(unquote(Macro.escape(test_obj)))

    assert true ==
             unquote(mod_name_minimal_stub).intrinsic_reporting?(
               unquote(Macro.escape(test_obj_intrin))
             )
  end

  test "verify property_writable?/1 of defined bacnet object" do
    test_obj = unquote(Macro.escape(test_obj))

    assert true ==
             unquote(mod_name_minimal_stub).property_writable?(test_obj, :out_of_service)

    assert false ==
             unquote(mod_name_minimal_stub).property_writable?(test_obj, :object_name)

    assert false ==
             unquote(mod_name_minimal_stub).property_writable?(test_obj, :object_instance)
  end

  test "verify add_property/1 of defined bacnet object" do
    test_obj = unquote(Macro.escape(test_obj))

    assert %{device_type: nil} = test_obj

    assert {:ok, %{device_type: "hello"} = new_test_obj} =
             unquote(mod_name_minimal_stub).add_property(
               test_obj,
               :device_type,
               "hello"
             )

    assert true == unquote(mod_name_minimal_stub).has_property?(new_test_obj, :device_type)
  end

  test "verify add_property/1 of defined bacnet object fails for unknown property" do
    assert {:error, {:unknown_property, :profile_name}} =
             unquote(mod_name_minimal_stub).add_property(
               unquote(Macro.escape(test_obj)),
               :profile_name,
               "hello"
             )
  end

  test "verify remove_property/1 of defined bacnet object" do
    test_obj = unquote(Macro.escape(test_obj_optional))

    assert %{device_type: "hello"} = test_obj

    assert {:ok, %{device_type: nil} = new_test_obj2} =
             unquote(mod_name_minimal_stub).remove_property(
               test_obj,
               :device_type
             )

    assert false == unquote(mod_name_minimal_stub).has_property?(new_test_obj2, :device_type)
  end

  test "verify remove_property/1 is idempotent of defined bacnet object" do
    test_obj = unquote(Macro.escape(test_obj_optional))

    assert %{device_type: nil} = unquote(Macro.escape(test_obj))

    assert false ==
             unquote(mod_name_minimal_stub).has_property?(
               unquote(Macro.escape(test_obj)),
               :device_type
             )

    assert {:ok, %{device_type: nil}} =
             unquote(mod_name_minimal_stub).remove_property(
               test_obj,
               :device_type
             )
  end

  test "verify update_property/3 of defined bacnet object updates the value" do
    assert {:ok, %{device_type: "hello_there"}} =
             unquote(mod_name_minimal_stub).update_property(
               unquote(Macro.escape(test_obj_optional)),
               :device_type,
               "hello_there"
             )

    assert {:ok, %{out_of_service: true}} =
             unquote(mod_name_minimal_stub).update_property(
               unquote(Macro.escape(test_obj_optional)),
               :out_of_service,
               true
             )
  end

  test "verify update_property/3 of defined bacnet object for unknown property" do
    assert {:error, {:unknown_property, :present}} =
             unquote(mod_name_minimal_stub).update_property(
               unquote(Macro.escape(test_obj_optional)),
               :present,
               true
             )
  end

  test "verify update_property/3 fails for intrinsic property = nil" do
    # nil values get ignored in create/4
    assert {:ok, test_obj} =
             unquote(mod_name_minimal_stub).create(1, "TEST", %{notification_class: nil},
               intrinsic_reporting: true
             )

    assert {:error, {:intrinsic_property_is_nil, :notification_class}} =
             unquote(mod_name_minimal_stub).update_property(test_obj, :notification_class, nil)
  end

  test "verify update_property/3 of defined bacnet object fails for invalid datatype" do
    assert {:error, {:invalid_property_type, :device_type}} =
             unquote(mod_name_minimal_stub).update_property(
               unquote(Macro.escape(test_obj_optional)),
               :device_type,
               5.0
             )

    assert {:error, {:invalid_property_type, :out_of_service}} =
             unquote(mod_name_minimal_stub).update_property(
               unquote(Macro.escape(test_obj_optional)),
               :out_of_service,
               0
             )
  end

  # Our stub with a validator function property for the tests below
  {:module, mod_name_validator_stub, _bytecode, _more} =
    defmodule BacObjectMinimalWithValidatorFunStub do
      use ObjectsMacro

      @type object_opts :: nil

      bac_object :binary_input do
        services(intrinsic: true)

        field(:description, String.t())

        field(:device_type, String.t(),
          validator_fun: fn str -> String.contains?(str, "hello") end
        )

        field(:out_of_service, boolean(), required: true)
        field(:present_value, boolean(), required: true, default: false)
      end
    end

  test "verify update_property/3 with validator fun" do
    {:ok, test_obj} = unquote(mod_name_validator_stub).create(1, "TEST", %{device_type: "hello"})

    assert {:ok, %{device_type: "hello there"}} =
             unquote(mod_name_validator_stub).update_property(
               test_obj,
               :device_type,
               "hello there"
             )
  end

  test "verify update_property/3 fails for validator fun" do
    {:ok, test_obj} = unquote(mod_name_validator_stub).create(1, "TEST", %{device_type: "hello"})

    assert {:error, {:value_failed_property_validation, :device_type}} =
             unquote(mod_name_validator_stub).update_property(test_obj, :device_type, "hell")
  end

  # Our stub with a priority_array property for the tests below
  {:module, mod_name_pa_stub, _bytecode, _more} =
    defmodule BacObjectMinimalWithPriorityArrayStub do
      use ObjectsMacro

      @type object_opts :: nil

      bac_object :binary_input do
        services(intrinsic: true)

        field(:description, String.t())
        field(:out_of_service, boolean(), required: true)
        field(:present_value, boolean(), required: true, default: false)

        field(:priority_array, PriorityArray.t())
        field(:relinquish_default, boolean(), default: false)
      end
    end

  test "verify conditional priority_array dependant functions are available" do
    assert true == function_exported?(unquote(mod_name_pa_stub), :get_priority_value, 1)
    assert true == function_exported?(unquote(mod_name_pa_stub), :set_priority, 3)
  end

  # test "verify set_priority/3 is overridable" do
  #   assert true == Module.overridable?(unquote(mod_name_pa_stub), {:set_priority, 3})
  # end

  test "verify update_property/3 writing to present_value fails due to priority_array" do
    assert {:ok, %{present_value: false} = test_obj} =
             unquote(mod_name_pa_stub).create(1, "TEST", %{priority_array: %PriorityArray{}})

    assert {:error, {:protected_property, :present_value}} =
             unquote(mod_name_pa_stub).update_property(test_obj, :present_value, true)
  end

  test "verify update_property/3 writing to present_value works when out_of_service" do
    assert {:ok, %{present_value: false} = test_obj} =
             unquote(mod_name_pa_stub).create(1, "TEST", %{
               out_of_service: true,
               priority_array: %PriorityArray{}
             })

    assert {:ok, %{present_value: true}} =
             unquote(mod_name_pa_stub).update_property(test_obj, :present_value, true)
  end

  test "verify update_property/3 of defined bacnet object priority array checks property value and updates present value" do
    assert {:ok, %{present_value: false, priority_array: %PriorityArray{}} = test_obj} =
             unquote(mod_name_pa_stub).create(1, "TEST", %{priority_array: %PriorityArray{}})

    assert {:ok, %{present_value: true}} =
             unquote(mod_name_pa_stub).update_property(test_obj, :priority_array, %PriorityArray{
               priority_16: true
             })
  end

  test "verify update_property/3 of defined bacnet object priority array checks property value and fails on mismatch" do
    assert {:ok, %{present_value: false, priority_array: %PriorityArray{}} = test_obj} =
             unquote(mod_name_pa_stub).create(1, "TEST", %{priority_array: %PriorityArray{}})

    assert {:error, {:invalid_property_type, :priority_array}} =
             unquote(mod_name_pa_stub).update_property(test_obj, :priority_array, %PriorityArray{
               priority_16: 5.0
             })
  end

  test "verify update_property/3 of defined bacnet object priority array writes to present_value fails" do
    assert {:ok, %{present_value: false, priority_array: %PriorityArray{}} = test_obj} =
             unquote(mod_name_pa_stub).create(1, "TEST", %{priority_array: %PriorityArray{}})

    assert {:error, {:protected_property, :present_value}} =
             unquote(mod_name_pa_stub).update_property(test_obj, :present_value, true)
  end

  # Our stub with a protected property for the tests below
  {:module, mod_name_protected_stub, _bytecode, _more} =
    defmodule BacObjectMinimalWithProtectedPresentValueStub do
      use ObjectsMacro

      @type object_opts :: nil

      bac_object :binary_input do
        services(intrinsic: true)

        field(:description, String.t())
        field(:out_of_service, boolean(), required: true)
        field(:present_value, boolean(), required: true, protected: true, default: false)
      end
    end

  test "verify create/3 of defined bacnet object with protected present_value fails" do
    assert {:error, {:protected_property, :present_value}} =
             unquote(mod_name_protected_stub).create(1, "TEST", %{present_value: true})
  end

  test "verify update_property/3 of defined bacnet object writes to protected present_value fails" do
    assert {:ok, %{present_value: false} = test_obj} =
             unquote(mod_name_protected_stub).create(1, "TEST")

    assert {:error, {:protected_property, :present_value}} =
             unquote(mod_name_protected_stub).update_property(test_obj, :present_value, true)
  end

  # Our stub with a feedback_value property for the tests below
  {:module, mod_name_protected_stub, _bytecode, _more} =
    defmodule BacObjectMinimalWithFeedbackValueStub do
      use ObjectsMacro

      @type object_opts :: nil

      bac_object :binary_input do
        services(intrinsic: true)

        field(:description, String.t())
        field(:out_of_service, boolean(), required: true)
        field(:present_value, boolean(), required: true, default: false)
        field(:feedback_value, boolean(), required: true, default: false)

        field(:priority_array, PriorityArray.t())
        field(:relinquish_default, boolean(), default: false)
      end
    end

  test "verify set_priority/3 fails when no priority array" do
    assert {:ok, %{present_value: false} = test_obj1} =
             unquote(mod_name_protected_stub).create(1, "T", %{})

    assert {:error, {:unknown_property, :priority_array}} =
             unquote(mod_name_protected_stub).set_priority(test_obj1, 16, true)
  end

  test "verify set_priority/3 works when out_of_service = false" do
    assert {:ok, %{present_value: false} = test_obj1} =
             unquote(mod_name_protected_stub).create(1, "T", %{priority_array: %PriorityArray{}})

    assert {:ok,
            %{present_value: true, priority_array: %PriorityArray{priority_16: true}} = test_obj1} =
             unquote(mod_name_protected_stub).set_priority(test_obj1, 16, true)

    assert {:ok,
            %{
              present_value: false,
              priority_array: %PriorityArray{priority_1: false, priority_16: true}
            }} = unquote(mod_name_protected_stub).set_priority(test_obj1, 1, false)
  end

  test "verify set_priority/3 works when out_of_service = true" do
    assert {:ok, %{present_value: false} = test_obj2} =
             unquote(mod_name_protected_stub).create(1, "T", %{
               priority_array: %PriorityArray{},
               out_of_service: true
             })

    assert {:ok,
            %{present_value: false, priority_array: %PriorityArray{priority_16: true}} = test_obj2} =
             unquote(mod_name_protected_stub).set_priority(test_obj2, 16, true)

    assert {:ok,
            %{
              present_value: false,
              priority_array: %PriorityArray{priority_1: true, priority_16: true}
            }} = unquote(mod_name_protected_stub).set_priority(test_obj2, 1, true)
  end

  test "verify set_priority/3 works and updates feedback_value if requested" do
    assert {:ok, %{feedback_value: false, present_value: false} = test_obj1} =
             unquote(mod_name_protected_stub).create(1, "T", %{priority_array: %PriorityArray{}},
               auto_write_feedback: false
             )

    assert {:ok, %{feedback_value: false, present_value: true}} =
             unquote(mod_name_protected_stub).set_priority(test_obj1, 16, true)
  end

  test "verify set_priority/3 works and updates not feedback_value if not requested" do
    assert {:ok, %{feedback_value: false, present_value: false} = test_obj2} =
             unquote(mod_name_protected_stub).create(1, "T", %{priority_array: %PriorityArray{}},
               auto_write_feedback: true
             )

    assert {:ok, %{feedback_value: true, present_value: true}} =
             unquote(mod_name_protected_stub).set_priority(test_obj2, 16, true)
  end

  test "verify set_priority/3 works and updates not feedback_value if requested but out_of_service" do
    assert {:ok, %{feedback_value: false, present_value: false} = test_obj3} =
             unquote(mod_name_protected_stub).create(
               1,
               "T",
               %{priority_array: %PriorityArray{}, out_of_service: true},
               auto_write_feedback: true
             )

    assert {:ok, %{feedback_value: false, present_value: false}} =
             unquote(mod_name_protected_stub).set_priority(test_obj3, 16, true)
  end

  test "verify update_property/3 updates not feedback_value when not requested" do
    assert {:ok, %{feedback_value: false, present_value: false} = test_obj1} =
             unquote(mod_name_protected_stub).create(1, "T", %{}, auto_write_feedback: false)

    assert {:ok, %{feedback_value: false, present_value: true}} =
             unquote(mod_name_protected_stub).update_property(test_obj1, :present_value, true)
  end

  test "verify update_property/3 updates feedback_value when requested" do
    assert {:ok, %{feedback_value: false, present_value: false} = test_obj2} =
             unquote(mod_name_protected_stub).create(1, "T", %{}, auto_write_feedback: true)

    assert {:ok, %{feedback_value: true, present_value: true}} =
             unquote(mod_name_protected_stub).update_property(test_obj2, :present_value, true)
  end

  test "verify update_property/3 with priority_array updates present_value when unsetting out_of_service" do
    assert {:ok, %{present_value: false} = test_obj1} =
             unquote(mod_name_protected_stub).create(1, "T", %{
               out_of_service: true,
               priority_array: %PriorityArray{}
             })

    assert {:ok, %{present_value: false} = test_obj1} =
             unquote(mod_name_protected_stub).set_priority(test_obj1, 16, true)

    assert {:ok, %{present_value: true}} =
             unquote(mod_name_protected_stub).update_property(test_obj1, :out_of_service, false)
  end

  # Our stub with optionally required properties using required_when for the tests below
  {:module, mod_name_opt_required_stub, _bytecode, _more} =
    defmodule BacObjectMinimalWithOptionallyRequiredPropertiesStub do
      use ObjectsMacro

      @type object_opts :: nil

      bac_object :binary_input do
        services(intrinsic: false)

        field(:description, String.t())
        field(:present_value, boolean(), required: true, default: false)

        field(:bias, boolean())
        field(:profile_name, String.t(), annotation: [required_when: {:property, :bias}])

        field(:window_interval, integer())
        field(:action, boolean(), annotation: [required_when: {:property, :window_interval, 1}])

        field(:window_samples, integer())

        field(:change_of_state_count, non_neg_integer(),
          annotation: [required_when: {:property, :window_samples, :>, 1}]
        )

        field(:change_of_state_time, non_neg_integer(),
          default: 0,
          annotation: [required_when: {:property, :window_samples, :<, 0}]
        )

        field(:location, boolean(), annotation: [required_when: {:opts, :physical_input}])
        field(:device_type, boolean(), annotation: [required_when: {:opts, :abc}])

        field(:max_master, boolean(), annotation: [required_when: {:opts, :remote_object, 1}])
        field(:deadband, boolean(), annotation: [required_when: {:opts, :def, 1}])

        field(:program_state, boolean(),
          annotation: [required_when: {:opts, :remote_object, :<, 0}]
        )

        field(:file_type, boolean(), annotation: [required_when: {:opts, :ghi, :>, 2}])

        field(:file_size, boolean(),
          default: false,
          annotation: [required_when: {:opts, :ghi, :<, 0}]
        )
      end
    end

  test "verify create/4 optionally required_when property {:property, property}" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{bias: nil, profile_name: nil}} = mod_name.create(1, "TEST", %{})

    assert {:ok, %{bias: nil, profile_name: ""}} = mod_name.create(1, "TEST", %{profile_name: ""})

    assert {:error, {:missing_required_property, :profile_name}} =
             mod_name.create(1, "TEST", %{bias: false})

    assert {:ok, %{bias: false, profile_name: ""}} =
             mod_name.create(1, "TEST", %{bias: false, profile_name: ""})
  end

  test "verify create/4 optionally required_when property {:property, property, value}" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{window_interval: nil, action: nil}} = mod_name.create(1, "TEST", %{})

    assert {:ok, %{window_interval: nil, action: false}} =
             mod_name.create(1, "TEST", %{action: false})

    assert {:ok, %{window_interval: 0, action: nil}} =
             mod_name.create(1, "TEST", %{window_interval: 0})

    assert {:ok, %{window_interval: 2, action: nil}} =
             mod_name.create(1, "TEST", %{window_interval: 2})

    assert {:error, {:missing_required_property, :action}} =
             mod_name.create(1, "TEST", %{window_interval: 1})

    assert {:ok, %{window_interval: 1, action: false}} =
             mod_name.create(1, "TEST", %{window_interval: 1, action: false})
  end

  test "verify create/4 optionally required_when property {:property, property, op, value}" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{window_samples: nil, change_of_state_count: nil}} =
             mod_name.create(1, "TEST", %{})

    assert {:ok, %{window_samples: nil, change_of_state_count: 5}} =
             mod_name.create(1, "TEST", %{change_of_state_count: 5})

    assert {:ok, %{window_samples: 0, change_of_state_count: nil}} =
             mod_name.create(1, "TEST", %{window_samples: 0})

    assert {:ok, %{window_samples: 1, change_of_state_count: nil}} =
             mod_name.create(1, "TEST", %{window_samples: 1})

    assert {:error, {:missing_required_property, :change_of_state_count}} =
             mod_name.create(1, "TEST", %{window_samples: 2})

    assert {:ok, %{window_samples: 2, change_of_state_count: 50}} =
             mod_name.create(1, "TEST", %{window_samples: 2, change_of_state_count: 50})
  end

  test "verify create/4 optionally required_when property {:property, property, op, value} with default value" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{window_samples: nil, change_of_state_time: nil}} =
             mod_name.create(1, "TEST", %{})

    assert {:ok, %{window_samples: nil, change_of_state_time: 5}} =
             mod_name.create(1, "TEST", %{change_of_state_time: 5})

    assert {:ok, %{window_samples: 0, change_of_state_time: nil}} =
             mod_name.create(1, "TEST", %{window_samples: 0})

    # No error, as change_of_state_time has default value
    assert {:ok, %{window_samples: -1, change_of_state_time: 0}} =
             mod_name.create(1, "TEST", %{window_samples: -1})

    assert {:ok, %{window_samples: -1, change_of_state_time: 50}} =
             mod_name.create(1, "TEST", %{window_samples: -1, change_of_state_time: 50})
  end

  test "verify create/4 optionally required_when property {:opts, property} with option" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{location: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{location: nil}} = mod_name.create(1, "TEST", %{}, physical_input: false)

    assert {:ok, %{location: true}} = mod_name.create(1, "TEST", %{location: true})

    assert {:error, {:missing_required_property, :location}} =
             mod_name.create(1, "TEST", %{}, physical_input: true)

    assert {:ok, %{location: true}} =
             mod_name.create(1, "TEST", %{location: true}, physical_input: true)
  end

  test "verify create/4 optionally required_when property {:opts, property} with other" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{device_type: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{device_type: nil}} = mod_name.create(1, "TEST", %{}, abc: false)

    assert {:ok, %{device_type: true}} = mod_name.create(1, "TEST", %{device_type: true})

    assert {:error, {:missing_required_property, :device_type}} =
             mod_name.create(1, "TEST", %{}, abc: true)

    assert {:ok, %{device_type: true}} =
             mod_name.create(1, "TEST", %{device_type: true}, abc: true)
  end

  test "verify create/4 optionally required_when property {:opts, property, value} with option" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{max_master: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{max_master: nil}} = mod_name.create(1, "TEST", %{}, remote_object: 0)

    assert {:ok, %{max_master: true}} = mod_name.create(1, "TEST", %{max_master: true})

    assert {:error, {:missing_required_property, :max_master}} =
             mod_name.create(1, "TEST", %{}, remote_object: 1)

    assert {:ok, %{max_master: false}} =
             mod_name.create(1, "TEST", %{max_master: false}, remote_object: 1)
  end

  test "verify create/4 optionally required_when property {:opts, property, value} with other" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{deadband: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{deadband: nil}} = mod_name.create(1, "TEST", %{}, def: 0)

    assert {:ok, %{deadband: true}} = mod_name.create(1, "TEST", %{deadband: true})

    assert {:error, {:missing_required_property, :deadband}} =
             mod_name.create(1, "TEST", %{}, def: 1)

    assert {:ok, %{deadband: false}} = mod_name.create(1, "TEST", %{deadband: false}, def: 1)
  end

  test "verify create/4 optionally required_when property {:opts, property, op, value} with option" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{program_state: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{program_state: nil}} = mod_name.create(1, "TEST", %{}, remote_object: 0)

    assert {:ok, %{program_state: true}} = mod_name.create(1, "TEST", %{program_state: true})

    assert {:error, {:missing_required_property, :program_state}} =
             mod_name.create(1, "TEST", %{}, remote_object: -1)

    assert {:ok, %{program_state: false}} =
             mod_name.create(1, "TEST", %{program_state: false}, remote_object: -1)
  end

  test "verify create/4 optionally required_when property {:opts, property, op, value} with other" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{file_type: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{file_type: nil}} = mod_name.create(1, "TEST", %{}, ghi: 0)

    assert {:ok, %{file_type: true}} = mod_name.create(1, "TEST", %{file_type: true})

    assert {:error, {:missing_required_property, :file_type}} =
             mod_name.create(1, "TEST", %{}, ghi: 3)

    assert {:ok, %{file_type: false}} = mod_name.create(1, "TEST", %{file_type: false}, ghi: 3)
  end

  test "verify create/4 optionally required_when property {:opts, property, op, value} with other and default value" do
    mod_name = unquote(mod_name_opt_required_stub)

    assert {:ok, %{file_size: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{file_size: nil}} = mod_name.create(1, "TEST", %{}, ghi: 0)

    assert {:ok, %{file_size: true}} = mod_name.create(1, "TEST", %{file_size: true})

    # No error, as file_size has a default value
    assert {:ok, %{file_size: false}} = mod_name.create(1, "TEST", %{}, ghi: -1)

    assert {:ok, %{file_size: true}} = mod_name.create(1, "TEST", %{file_size: true}, ghi: -1)
  end

  # Our stub with optionally required properties using only_when for the tests below
  {:module, mod_name_opt_only_stub, _bytecode, _more} =
    defmodule BacObjectMinimalWithOptionallyRequiredOnlyPropertiesStub do
      use ObjectsMacro

      @type object_opts :: nil

      bac_object :binary_input do
        services(intrinsic: false)

        field(:description, String.t())
        field(:present_value, boolean(), required: true, default: false)

        field(:bias, boolean())
        field(:profile_name, String.t(), annotation: [only_when: {:property, :bias}])

        field(:window_interval, integer())
        field(:action, boolean(), annotation: [only_when: {:property, :window_interval, 1}])

        field(:window_samples, integer())

        field(:change_of_state_count, non_neg_integer(),
          annotation: [only_when: {:property, :window_samples, :>, 1}]
        )

        field(:change_of_state_time, non_neg_integer(),
          default: 0,
          annotation: [only_when: {:property, :window_samples, :<, 0}]
        )

        field(:location, boolean(), annotation: [only_when: {:opts, :physical_input}])
        field(:device_type, boolean(), annotation: [only_when: {:opts, :abc}])

        field(:max_master, boolean(), annotation: [only_when: {:opts, :remote_object, 1}])
        field(:deadband, boolean(), annotation: [only_when: {:opts, :def, 1}])

        field(:program_state, boolean(), annotation: [only_when: {:opts, :remote_object, :<, 0}])
        field(:file_type, boolean(), annotation: [only_when: {:opts, :ghi, :>, 2}])

        field(:file_size, boolean(),
          default: false,
          annotation: [only_when: {:opts, :ghi, :<, 0}]
        )
      end
    end

  test "verify create/4 optionally only_when property {:property, property}" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{bias: nil, profile_name: nil}} = mod_name.create(1, "TEST", %{})

    assert {:error, {:property_not_allowed, :profile_name}} =
             mod_name.create(1, "TEST", %{profile_name: ""})

    assert {:error, {:missing_required_property, :profile_name}} =
             mod_name.create(1, "TEST", %{bias: false})

    assert {:ok, %{bias: false, profile_name: ""}} =
             mod_name.create(1, "TEST", %{bias: false, profile_name: ""})
  end

  test "verify create/4 optionally only_when property {:property, property, value}" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{window_interval: nil, action: nil}} = mod_name.create(1, "TEST", %{})

    assert {:error, {:property_not_allowed, :action}} =
             mod_name.create(1, "TEST", %{action: false})

    assert {:ok, %{window_interval: 0, action: nil}} =
             mod_name.create(1, "TEST", %{window_interval: 0})

    assert {:ok, %{window_interval: 2, action: nil}} =
             mod_name.create(1, "TEST", %{window_interval: 2})

    assert {:error, {:missing_required_property, :action}} =
             mod_name.create(1, "TEST", %{window_interval: 1})

    assert {:ok, %{window_interval: 1, action: false}} =
             mod_name.create(1, "TEST", %{window_interval: 1, action: false})
  end

  test "verify create/4 optionally only_when property {:property, property, op, value}" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{window_samples: nil, change_of_state_count: nil}} =
             mod_name.create(1, "TEST", %{})

    assert {:error, {:property_not_allowed, :change_of_state_count}} =
             mod_name.create(1, "TEST", %{change_of_state_count: 5})

    assert {:ok, %{window_samples: 0, change_of_state_count: nil}} =
             mod_name.create(1, "TEST", %{window_samples: 0})

    assert {:ok, %{window_samples: 1, change_of_state_count: nil}} =
             mod_name.create(1, "TEST", %{window_samples: 1})

    assert {:error, {:missing_required_property, :change_of_state_count}} =
             mod_name.create(1, "TEST", %{window_samples: 2})

    assert {:ok, %{window_samples: 2, change_of_state_count: 50}} =
             mod_name.create(1, "TEST", %{window_samples: 2, change_of_state_count: 50})
  end

  test "verify create/4 optionally only_when property {:property, property, op, value} with default value" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{window_samples: nil, change_of_state_time: nil}} =
             mod_name.create(1, "TEST", %{})

    assert {:error, {:property_not_allowed, :change_of_state_time}} =
             mod_name.create(1, "TEST", %{change_of_state_time: 5})

    assert {:ok, %{window_samples: 0, change_of_state_time: nil}} =
             mod_name.create(1, "TEST", %{window_samples: 0})

    # No error, as change_of_state_time has default value
    assert {:ok, %{window_samples: -1, change_of_state_time: 0}} =
             mod_name.create(1, "TEST", %{window_samples: -1})

    assert {:ok, %{window_samples: -1, change_of_state_time: 50}} =
             mod_name.create(1, "TEST", %{window_samples: -1, change_of_state_time: 50})
  end

  test "verify create/4 optionally only_when property {:opts, property} with option" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{location: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{location: nil}} = mod_name.create(1, "TEST", %{}, physical_input: false)

    assert {:error, {:property_not_allowed, :location}} =
             mod_name.create(1, "TEST", %{location: true})

    assert {:error, {:missing_required_property, :location}} =
             mod_name.create(1, "TEST", %{}, physical_input: true)

    assert {:ok, %{location: true}} =
             mod_name.create(1, "TEST", %{location: true}, physical_input: true)
  end

  test "verify create/4 optionally only_when property {:opts, property} with other" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{device_type: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{device_type: nil}} = mod_name.create(1, "TEST", %{}, abc: false)

    assert {:error, {:property_not_allowed, :device_type}} =
             mod_name.create(1, "TEST", %{device_type: true})

    assert {:error, {:missing_required_property, :device_type}} =
             mod_name.create(1, "TEST", %{}, abc: true)

    assert {:ok, %{device_type: true}} =
             mod_name.create(1, "TEST", %{device_type: true}, abc: true)
  end

  test "verify create/4 optionally only_when property {:opts, property, value} with option" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{max_master: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{max_master: nil}} = mod_name.create(1, "TEST", %{}, remote_object: 0)

    assert {:error, {:property_not_allowed, :max_master}} =
             mod_name.create(1, "TEST", %{max_master: true})

    assert {:error, {:missing_required_property, :max_master}} =
             mod_name.create(1, "TEST", %{}, remote_object: 1)

    assert {:ok, %{max_master: false}} =
             mod_name.create(1, "TEST", %{max_master: false}, remote_object: 1)
  end

  test "verify create/4 optionally only_when property {:opts, property, value} with other" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{deadband: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{deadband: nil}} = mod_name.create(1, "TEST", %{}, def: 0)

    assert {:error, {:property_not_allowed, :deadband}} =
             mod_name.create(1, "TEST", %{deadband: true})

    assert {:error, {:missing_required_property, :deadband}} =
             mod_name.create(1, "TEST", %{}, def: 1)

    assert {:ok, %{deadband: false}} = mod_name.create(1, "TEST", %{deadband: false}, def: 1)
  end

  test "verify create/4 optionally only_when property {:opts, property, op, value} with option" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{program_state: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{program_state: nil}} = mod_name.create(1, "TEST", %{}, remote_object: 0)

    assert {:error, {:property_not_allowed, :program_state}} =
             mod_name.create(1, "TEST", %{program_state: true})

    assert {:error, {:missing_required_property, :program_state}} =
             mod_name.create(1, "TEST", %{}, remote_object: -1)

    assert {:ok, %{program_state: false}} =
             mod_name.create(1, "TEST", %{program_state: false}, remote_object: -1)
  end

  test "verify create/4 optionally only_when property {:opts, property, op, value} with other" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{file_type: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{file_type: nil}} = mod_name.create(1, "TEST", %{}, ghi: 0)

    assert {:error, {:property_not_allowed, :file_type}} =
             mod_name.create(1, "TEST", %{file_type: true})

    assert {:error, {:missing_required_property, :file_type}} =
             mod_name.create(1, "TEST", %{}, ghi: 3)

    assert {:ok, %{file_type: false}} = mod_name.create(1, "TEST", %{file_type: false}, ghi: 3)
  end

  test "verify create/4 optionally only_when property {:opts, property, op, value} with other and default value" do
    mod_name = unquote(mod_name_opt_only_stub)

    assert {:ok, %{file_size: nil}} = mod_name.create(1, "TEST")
    assert {:ok, %{file_size: nil}} = mod_name.create(1, "TEST", %{}, ghi: 0)

    assert {:error, {:property_not_allowed, :file_size}} =
             mod_name.create(1, "TEST", %{file_size: true})

    # No error, as file_size has a default value
    assert {:ok, %{file_size: false}} = mod_name.create(1, "TEST", %{}, ghi: -1)

    assert {:ok, %{file_size: true}} = mod_name.create(1, "TEST", %{file_size: true}, ghi: -1)
  end

  test "bac_object with fields extensibility" do
    try do
      Application.put_env(:bacstack, :objects_additional_properties,
        analog_input:
          quote do
            field(:access_doors, boolean(), encode_as: :enumerated)
          end
      )

      defmodule BacObjectMinimalExtensibilityFieldsTestStub do
        use ObjectsMacro

        @type object_opts :: nil

        bac_object :analog_input do
          field(:present_value, float(), default: 0.0)
          field(:polarity, boolean(), default: false, implicit_relationship: :present_value)
        end
      end
    after
      Application.delete_env(:bacstack, :objects_additional_properties)
    else
      {:module, module, _bytecode, _more} ->
        assert :access_doors in module.get_all_properties()
    end
  end
end
