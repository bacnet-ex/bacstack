defmodule BACnet.Protocol.ObjectsContract do
  @moduledoc """
  Compile-time facts for one BACnet object type.

  `BACnet.Protocol.ObjectsMacro` builds one contract per object module.
  `BACnet.Protocol.ObjectOperations` reads it when creating and updating objects.
  Validator functions and annotation functions are filled in by the object module,
  because they close over functions defined in that module.
  """

  alias BACnet.Protocol.Constants

  @typedoc """
  Property validator pair.

  The first function is the `bac_type` validator (`{:with_validator, type, fun}`).
  The second is the field's `validator_fun`. Either may be `nil`.
  """
  @type property_validator :: {function() | nil, function() | nil}

  @typedoc """
  Facts `BACnet.Protocol.ObjectOperations` needs for one object type.

  Capability flags are true when the struct defines that field. They are not
  the same as "the property is currently present on an instance".
  """
  @type t :: %__MODULE__{
          object_module: module(),
          object_type: Constants.object_type(),
          properties: [atom()],
          required: [atom()],
          optional: [atom()],
          protected: [atom()],
          readonly: [atom()],
          intrinsic: [atom()],
          cov: [atom()],
          type_map: %{optional(atom()) => term()},
          revision_map: %{optional(atom()) => non_neg_integer()},
          implicit_relationships: %{optional(atom()) => atom()},
          default_properties: %{optional(atom()) => term()},
          default_properties_all: %{optional(atom()) => term()},
          default_intrinsic: %{optional(atom()) => term()},
          remote_defaults: %{optional(atom()) => term()},
          init_funs: %{optional(atom()) => (-> term())},
          validators: %{optional(atom()) => property_validator()},
          annotations: [{atom(), keyword()}],
          supports_intrinsic: boolean(),
          default_cov_increment: term() | nil,
          has_priority_array: boolean(),
          has_present_value: boolean(),
          has_feedback_value: boolean(),
          has_event_state: boolean(),
          has_status_flags: boolean(),
          has_reliability: boolean(),
          has_out_of_service: boolean(),
          has_relinquish_default: boolean(),
          has_min_max_present_value: boolean(),
          has_physical_input: boolean()
        }

  defstruct [
    :object_module,
    :object_type,
    :properties,
    :required,
    :optional,
    :protected,
    :readonly,
    :intrinsic,
    :cov,
    :type_map,
    :revision_map,
    :implicit_relationships,
    :default_properties,
    :default_properties_all,
    :default_intrinsic,
    :remote_defaults,
    :init_funs,
    :validators,
    :annotations,
    :supports_intrinsic,
    :default_cov_increment,
    :has_priority_array,
    :has_present_value,
    :has_feedback_value,
    :has_event_state,
    :has_status_flags,
    :has_reliability,
    :has_out_of_service,
    :has_relinquish_default,
    :has_min_max_present_value,
    :has_physical_input
  ]
end
