defmodule BACnet.Protocol.ObjectTypes.Loop do
  @moduledoc """
  The Loop object type defines a standardized object whose properties represent
  the externally visible characteristics of any form of feedback control loop.
  Flexibility is achieved by providing three independent gain constants with
  no assumed values for units. The appropriate gain units are determined by
  the details of the control algorithm, which is a local matter.

  Loop objects that support intrinsic reporting shall apply the FLOATING_LIMIT event algorithm.

  (ASHRAE 135 - Clause 12.17)
  """

  # TODO: Docs

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.SetpointReference

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Loop object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :loop) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)
    field(:present_value, float(), required: true, readonly: true, default: 0.0)
    field(:priority_for_writing, 1..16, required: true, default: 16)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:action, Constants.action(), required: true, default: :direct)
    field(:bias, float())

    field(:max_output, float())
    field(:min_output, float())

    field(:manipulated_variable_reference, ObjectPropertyRef.t(),
      required: true,
      default: ObjectsMacro.get_default_object_ref()
    )

    field(:output_units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:controlled_variable_reference, ObjectPropertyRef.t(),
      required: true,
      default: ObjectsMacro.get_default_object_ref()
    )

    field(:controlled_variable_value, float(), required: true, default: 0.0)

    field(:controlled_variable_units, Constants.engineering_unit(),
      required: true,
      default: :no_units
    )

    field(:setpoint_reference, SetpointReference.t(),
      required: true,
      default: %SetpointReference{ref: nil}
    )

    field(:setpoint, float(), required: true, default: 0.0)

    field(:update_interval, non_neg_integer())
    field(:profile_name, String.t())

    field(:proportional_constant, float(), implicit_relationship: :proportional_constant_units)
    field(:proportional_constant_units, Constants.engineering_unit())
    field(:integral_constant, float(), implicit_relationship: :integral_constant_units)
    field(:integral_constant_units, Constants.engineering_unit())
    field(:derivative_constant, float(), implicit_relationship: :derivative_constant_units)
    field(:derivative_constant_units, Constants.engineering_unit())

    # COV reporting
    field(:cov_increment, float(), default: 0.1)

    # Intrinsic Reporting
    field(:deadband, float(), intrinsic: true, default: 0.0)
    field(:error_limit, float(), intrinsic: true, default: 0.0)
  end
end
