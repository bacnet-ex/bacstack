defmodule BACnet.Protocol.ObjectTypes.Accumulator do
  @moduledoc """
  The Accumulator object type defines a standardized object whose properties
  represent the externally visible characteristics of a device that indicates
  measurements made by counting pulses.

  This object maintains precise measurement of input count values, accumulated over time.
  The accumulation of pulses represents the measured quantity in unsigned integer units.
  This object is also concerned with the accurate representation of values presented
  on meter read-outs. This includes the ability to initially set the Present_Value
  property to the value currently displayed by the meter (as when the meter is installed),
  and to duplicate the means by which it is advanced, including simulating a
  modulo-N divider prescaling the actual meter display value, as shown in Figure 12-1.

  Typical applications of such devices are in peak load management and in accounting
  and billing management systems. This object is not intended to meet all such applications.

  Its purpose is to provide information about the quantity being measured,
  such as electric power, water, or natural gas usage, according to criteria
  specific to the application.

  Accumulator objects that support intrinsic reporting shall apply the UNSIGNED_RANGE event algorithm.

  (ASHRAE 135 - Clause 12.1)
  """

  # TODO: Docs

  alias BACnet.Protocol.AccumulatorRecord
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.Prescale

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents an Accumulator object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  The `max_present_value` property defaults to `2^32-1` and can be manually
  set to a higher value, if desired and/or needed.
  """
  bac_object Constants.macro_assert_name(:object_type, :accumulator) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)
    field(:present_value, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:scale, Constants.accumulator_scale(), required: true)
    field(:prescale, Prescale.t(), required: true)
    field(:max_present_value, non_neg_integer(), required: true, default: 4_294_967_295)

    field(:value_change_time, BACnetDateTime.t(),
      readonly: true,
      init_fun: &ObjectsMacro.get_default_bacnet_datetime/0
    )

    field(:value_before_change, non_neg_integer(),
      readonly: true,
      default: 0,
      implicit_relationship: :value_change_time
    )

    field(:value_set, non_neg_integer())

    field(:logging_record, AccumulatorRecord.t(), readonly: true)
    field(:logging_object, ObjectIdentifier.t())

    field(:profile_name, String.t())

    # Intrinsic Reporting
    field(:high_limit, non_neg_integer(), intrinsic: true, default: 0)
    field(:low_limit, non_neg_integer(), intrinsic: true, default: 0)

    field(:pulse_rate, non_neg_integer(),
      intrinsic: true,
      implicit_relationship: :limit_monitoring_interval
    )

    field(:limit_monitoring_interval, non_neg_integer(), intrinsic: true, default: 1)
  end
end
