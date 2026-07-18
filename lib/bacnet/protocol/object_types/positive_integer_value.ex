defmodule BACnet.Protocol.ObjectTypes.PositiveIntegerValue do
  @moduledoc """
  The Positive Integer Value object publishes an unsigned integer (non-negative) as a
  named BACnet value. It is the unsigned sibling of
  `BACnet.Protocol.ObjectTypes.IntegerValue` and is typically
  used for counters, pulse totals, stage numbers, error counters, or any quantity
  that by nature cannot be negative.

  The value supports commandability via priority array. When `intrinsic_reporting: true`
  the UNSIGNED_OUT_OF_RANGE intrinsic algorithm is enabled.
  Otherwise it behaves like the other simple Value objects.

  ### Object Description (ASHRAE 135)

  > The Integer Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a named data value in a BACnet device.
  > A BACnet device can use a Positive Integer Value object to make any kind of unsigned
  > integer data value accessible to other BACnet devices.
  >
  > Positive Integer Value objects that support intrinsic reporting shall apply
  > the UNSIGNED_OUT_OF_RANGE event algorithm.

  ### Behaviour and Operation

  Positive Integer Value objects are the unsigned (non-negative) counterpart to
  Integer Value. They are used for counters, pulse totals, stage numbers, etc.
  that cannot be negative. The value is directly writable unless commandable via
  a priority array, in which case the priority mechanism supplies the effective
  present value.

  UNSIGNED_OUT_OF_RANGE intrinsic alarming is available when the object is created
  with `intrinsic_reporting: true`.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The positive integer value.
    **Dev must**: Direct write or priority commanding. min and max present value apply.

  - `priority_array`, `relinquish_default`:
    **Dev must**: Optional commandability.

  - `min/max_present_value`, `resolution`, `cov_increment`:
    **Dev must**: Validation, resolution and COV steps.

  - Intrinsic:
    **Dev must**: Re-eval on changes.

  - `status_flags`, `out_of_service`, `reliability`:
    **Dev must**: The `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are
    automatically updated by the object based on `event_state`/`reliability`/
    `out_of_service`; `overridden` is a local matter.
    Standard value rules apply for `out_of_service`, etc.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the UNSIGNED_OUT_OF_RANGE
  event algorithm and related properties become active.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable).

  ### Examples

  Creating a Positive Integer Value:

      iex> {:ok, piv} = BACnet.Protocol.ObjectTypes.PositiveIntegerValue.create(20, "Count", %{present_value: 0}); piv.object_name
      "Count"

  With intrinsic reporting:

      iex> {:ok, piv} = BACnet.Protocol.ObjectTypes.PositiveIntegerValue.create(21, "UCount", %{present_value: 0}, intrinsic_reporting: true); is_integer(piv.present_value)
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.UnsignedOutOfRange`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Positive Integer Value object.

  In addition to the common options, Positive Integer Value supports:
  - `intrinsic_reporting` - Enables UNSIGNED_OUT_OF_RANGE intrinsic reporting.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Positive Integer Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
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
      end,
      annotation: {:readonly_when, {:out_of_service, false}}
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

    # COV Reporting
    field(:cov_increment, non_neg_integer(), cov: true, default: 0)

    # Intrinsic Reporting
    field(:deadband, non_neg_integer(), intrinsic: true, default: 0)
    field(:high_limit, non_neg_integer(), intrinsic: true, default: 0)
    field(:low_limit, non_neg_integer(), intrinsic: true, default: 0)
  end
end
