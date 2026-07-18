defmodule BACnet.Protocol.ObjectTypes.LargeAnalogValue do
  @moduledoc """
  The Large Analog Value object stores a double-precision (IEEE 754) floating point value.
  It is the high-precision sibling of Analog Value and is intended for
  scientific-grade measurements, accumulated energy totals, very small or very large
  physical quantities, or any calculation that would lose accuracy with single-precision.

  The value can be commandable via priority array and supports COV reporting.
  Intrinsic reporting with the DOUBLE_OUT_OF_RANGE algorithm (high/low limits +
  deadband) is available when `intrinsic_reporting: true` is supplied at creation.
  The object otherwise behaves like other Value objects.

  ### Object Description (ASHRAE 135)

  > The Large Analog Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a named data value in a BACnet device.
  > A BACnet device can use a Large Analog Value object to make any kind of
  > double-precision data value accessible to other BACnet devices.
  >
  > Large Analog Value objects that support intrinsic reporting shall apply
  > the DOUBLE_OUT_OF_RANGE event algorithm.

  ### Behaviour and Operation

  Large Analog Value objects expose a double-precision floating-point value. They
  behave exactly like Analog Value objects but use higher precision (useful for
  accumulated totals, scientific values, etc.). The value is writable directly
  unless commandable via a priority array, in which case the priority mechanism
  controls the effective present value and direct writes are not permitted.

  Intrinsic DOUBLE_OUT_OF_RANGE alarming is available when enabled at creation.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The current analog value (setpoint, calc result, etc.).
    **Dev must**: If no priority_array, local app or clients write it directly via
    `update_property/3`. If commandable (PA + `relinquish_default` present), only command
    via `set_priority/3` or updating the PA/relinquish.
    Your "consumer" (loop, logic, HMI) reads the effective value after updates.
    The library syncs PV from PA on relevant updates.

  - `priority_array`, `relinquish_default`: Optional for making it commandable
    (unlike outputs, not required at creation).
    **Dev must**: Add later via `add_property/3` if desired. Once added, protection and
    derivation logic activates. Your commanding sources use the priority APIs.

  - `status_flags`, `out_of_service`, `reliability` (implicit inhibit):
    **Dev must**: Reliability usually reflects source health
    (bad calc, missing input to formula, etc.). The `in_alarm`, `fault` and `out_of_service`
    bits are automatically kept in sync by the object; `overridden` is a local matter.

  - `min_present_value`, `max_present_value`, `resolution`, `units`: Config/limits.
    **Dev must**: Set accurately for your use case.

  - Intrinsic (`high/low_limit`, `deadband` + full event set when enabled): For
    DOUBLE_OUT_OF_RANGE.
    **Dev must**: After PV (or reliability) change, your event engine must re-evaluate
    DOUBLE_OUT_OF_RANGE using these on the object, update `event_state` etc., and emit
    notifications as needed.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the DOUBLE_OUT_OF_RANGE
  event algorithm and related properties become active.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array`. Large Analog Value (like Integer Value)
  provides a `set_priority/3` helper that errors when no priority array is configured.

  ### Examples

  Creating a Large Analog Value:

      iex> {:ok, lav} = BACnet.Protocol.ObjectTypes.LargeAnalogValue.create(30, "Precise", %{present_value: 3.14159}); lav.object_name
      "Precise"

  With intrinsic reporting:

      iex> {:ok, lav} = BACnet.Protocol.ObjectTypes.LargeAnalogValue.create(31, "HighRes", %{present_value: 3.14159}, intrinsic_reporting: true); is_float(lav.present_value)
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.DoubleOutOfRange`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Large Analog Value object.

  In addition to the common options, Large Analog Value supports:
  - `intrinsic_reporting` - Enables DOUBLE_OUT_OF_RANGE intrinsic reporting.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Large Analog Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :large_analog_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, float(),
      required: true,
      default: 0.0,
      bac_type: :double,
      annotation: {:readonly_when, {:out_of_service, false}}
    )

    field(:priority_array, PriorityArray.t(float()), readonly: true)
    field(:relinquish_default, float(), default: 0.0, bac_type: :double)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:resolution, float(), readonly: true, bac_type: :double)
    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:max_present_value, float(), bac_type: :double)
    field(:min_present_value, float(), bac_type: :double)

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1, bac_type: :double)

    # Intrinsic Reporting
    field(:event_state, Constants.event_state(), intrinsic: true)
    field(:deadband, float(), intrinsic: true, default: 0.0, bac_type: :double)
    field(:high_limit, float(), intrinsic: true, default: 0.0, bac_type: :double)
    field(:low_limit, float(), intrinsic: true, default: 0.0, bac_type: :double)
  end

  # Override set_priority/3, to check present_value for max_/min_present_value
  def set_priority(%__MODULE__{priority_array: nil} = _object, _priority, _value) do
    {:error, {:unknown_property, :priority_array}}
  end

  def set_priority(
        %__MODULE__{priority_array: %PriorityArray{} = _pa} = object,
        priority,
        value
      )
      when priority in 1..16 do
    with :ok <-
           if(value == nil,
             do: :ok,
             else: check_min_max_present_value(object, :priority_array, value)
           ),
         do: super(object, priority, value)
  end

  # Override update_property/3, to check present_value and relinquish_default for max_/min_present_value
  def update_property(%__MODULE__{} = object, :present_value, value) do
    with :ok <- check_min_max_present_value(object, :present_value, value),
         do: super(object, :present_value, value)
  end

  def update_property(%__MODULE__{} = object, :relinquish_default, value) do
    with :ok <- check_min_max_present_value(object, :relinquish_default, value),
         do: super(object, :relinquish_default, value)
  end

  def update_property(%__MODULE__{} = object, property, value) when is_atom(property) do
    super(object, property, value)
  end

  @spec check_min_max_present_value(t(), Constants.property_identifier(), float()) ::
          :ok | property_update_error()
  defp check_min_max_present_value(object, property, value) do
    if check_property_exists(object, :max_present_value) == :ok and
         check_property_exists(object, :min_present_value) == :ok do
      with true <- value <= object.max_present_value,
           true <- value >= object.min_present_value do
        :ok
      else
        false -> {:error, {:property_out_of_range, property}}
      end
    else
      :ok
    end
  end
end
