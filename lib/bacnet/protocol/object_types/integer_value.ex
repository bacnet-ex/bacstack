defmodule BACnet.Protocol.ObjectTypes.IntegerValue do
  @moduledoc """
  The Integer Value object publishes a signed integer that lives inside the device.
  It is the signed counterpart to Positive Integer Value and is typically used
  for counters that may go negative, error codes, step numbers, or any other integer
  quantity that clients need to read or write.

  The value can be made fully commandable via a priority array so that multiple
  writers can arbitrate. When `intrinsic_reporting: true` is passed to `create/4`,
  the SIGNED_OUT_OF_RANGE algorithm is activated, allowing high/low limit alarming
  on the integer value.

  ### Object Description (ASHRAE 135)

  > The Integer Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a named data value in a BACnet device.
  > A BACnet device can use an Integer Value object to make any kind of signed integer data
  > value accessible to other BACnet devices.
  >
  > Integer Value objects that support intrinsic reporting shall apply the SIGNED_OUT_OF_RANGE event algorithm.

  ### Behaviour and Operation

  Integer Value objects expose a signed integer that lives in the device's memory.
  The value can be written directly by the local application or by BACnet clients
  unless a priority array is present (making the object commandable). In
  the commandable case the library derives `present_value` from the priority array
  and blocks direct writes to it.

  Typical uses include counters that may go negative, step numbers, error codes,
  or any other integer quantity. When intrinsic reporting is enabled the
  SIGNED_OUT_OF_RANGE algorithm provides high/low alarming with deadband.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The current integer value.
    **Dev must**: If no priority_array, local app or clients write it directly via
    `update_property/3`. If commandable (PA + `relinquish_default` present), only command
    via `set_priority/3` or updating the PA/relinquish.

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
    OUT_OF_RANGE.
    **Dev must**: After PV (or reliability) change, your event engine must re-evaluate
    SIGNED_OUT_OF_RANGE using these on the object, update `event_state` etc., and emit
    notifications as needed.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the SIGNED_OUT_OF_RANGE
  event algorithm and related properties become active.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable). When a priority array
  is present, the present value is protected and is only changed through the priority mechanism.

  ### Examples

  Creating a minimal Integer Value:

      iex> {:ok, iv} = BACnet.Protocol.ObjectTypes.IntegerValue.create(10, "Counter", %{}); iv.present_value
      0

  With intrinsic reporting enabled:

      iex> {:ok, iv} = BACnet.Protocol.ObjectTypes.IntegerValue.create(11, "Setpt", %{present_value: 100}, intrinsic_reporting: true); iv.object_name
      "Setpt"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.SignedOutOfRange`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Integer Value object.

  In addition to the common options, Integer Value supports:
  - `intrinsic_reporting` - Enables SIGNED_OUT_OF_RANGE intrinsic reporting.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Integer Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :integer_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, integer(),
      required: true,
      default: 0,
      annotation: {:readonly_when, {:out_of_service, false}}
    )

    field(:priority_array, PriorityArray.t(integer()), readonly: true)
    field(:relinquish_default, integer(), default: 0)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:resolution, integer(), readonly: true)
    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:max_present_value, integer())
    field(:min_present_value, integer())
    field(:profile_name, String.t())

    # COV Reporting
    field(:cov_increment, non_neg_integer(), cov: true, default: 0)

    # Intrinsic Reporting
    field(:deadband, non_neg_integer(), intrinsic: true, default: 0)
    field(:high_limit, integer(), intrinsic: true, default: 0)
    field(:low_limit, integer(), intrinsic: true, default: 0)
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

  @spec check_min_max_present_value(t(), Constants.property_identifier(), integer()) ::
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
