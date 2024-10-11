defmodule BACnet.Protocol.ObjectTypes.PositiveIntegerValue do
  @moduledoc """
  The Integer Value object type defines a standardized object whose properties represent
  the externally visible characteristics of a named data value in a BACnet device.
  A BACnet device can use a Positive Integer Value object to make any kind of unsigned
  integer data value accessible to other BACnet devices.
  The mechanisms by which the value is derived are not visible to the BACnet client.

  Positive Integer Value objects that support intrinsic reporting shall apply
  the UNSIGNED_OUT_OF_RANGE event algorithm.

  (ASHRAE 135 - Clause 12.44)
  """

  # TODO: Docs

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Positive Integer Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected,
  unless out of service is active. For the duration of out of service, updates to the present value
  using `update_property/3` are allowed. Once out of service is disabled, the present value is once
  again protected from updates, as the present value is updated through the relinquish_default and
  priority_array properties.
  """
  bac_object Constants.macro_assert_name(:object_type, :positive_integer_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, non_neg_integer(),
      required: true,
      default: 0,
      validator_fun: fn
        value, %{min_present_value: min, max_present_value: max}
        when not is_nil(min) and not is_nil(max) ->
          min <= value and value <= max

        _value, _obj ->
          true
      end
    )

    field(:priority_array, PriorityArray.t(non_neg_integer()), readonly: true)

    field(:relinquish_default, non_neg_integer(),
      default: 0,
      validator_fun: fn
        value, %{min_present_value: min, max_present_value: max}
        when not is_nil(min) and not is_nil(max) ->
          min <= value and value <= max

        _value, _obj ->
          true
      end
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:resolution, non_neg_integer(), readonly: true)
    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:max_present_value, non_neg_integer())
    field(:min_present_value, non_neg_integer())
    field(:profile_name, String.t())

    # COV Reporting
    field(:cov_increment, non_neg_integer(), cov: true, default: 0)

    # Intrinsic Reporting
    field(:deadband, non_neg_integer(), intrinsic: true, default: 0)
    field(:high_limit, non_neg_integer(), intrinsic: true, default: 0)
    field(:low_limit, non_neg_integer(), intrinsic: true, default: 0)
  end
end
