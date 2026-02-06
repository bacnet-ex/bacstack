defmodule BACnet.Protocol.ObjectTypes.PulseConverter do
  @moduledoc """
  The Pulse Converter object type defines a standardized object that represents
  a process whereby ongoing measurements made of some quantity, such as
  electric power or water or natural gas usage, and represented by pulses or counts,
  might be monitored over some time interval for applications such as
  peak load management, where it is necessary to make periodic measurements
  but where a precise accounting of every input pulse or count is not required.
  The Pulse Converter object might represent a physical input. As an alternative,
  it might acquire the data from the Present_Value of an Accumulator object,
  representing an input in the same device as the Pulse Converter object.
  This linkage is illustrated by the dotted line in Figure 12-4. Every time the
  Present_Value property of the Accumulator object is incremented, the Count property
  of the Pulse Converter object is also incremented.
  The Present_Value property of the Pulse Converter object can be adjusted at any time
  by writing to the Adjust_Value property, which causes the Count property to be adjusted,
  and the Present_Value recomputed from Count. In the illustration in Figure 12-4,
  the Count property of the Pulse Converter was adjusted down to 0 when the Total_Count
  of the Accumulator object had the value 0070.

  Pulse Converter objects that support intrinsic reporting shall apply the OUT_OF_RANGE event algorithm.

  (ASHRAE 135 - Clause 12.23)
  """

  # TODO: Docs

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents an Pulse Converter object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :pulse_converter) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)
    field(:present_value, float(), required: true, readonly: true, default: 0.0)

    field(:input_reference, ObjectPropertyRef.t())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:scale_factor, float(), required: true, readonly: true, default: 1.0)
    field(:adjust_value, float(), required: true, default: 0.0)
    field(:count, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:update_time, BACnetDateTime.t(),
      required: true,
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:count_change_time, BACnetDateTime.t(),
      required: true,
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:count_before_change, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:profile_name, String.t())

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1)

    field(:cov_period, non_neg_integer(),
      cov: true,
      default: 0,
      implicit_relationship: :cov_increment
    )

    # Intrinsic Reporting
    field(:high_limit, float(), intrinsic: true, default: 0.0)
    field(:low_limit, float(), intrinsic: true, default: 0.0)
    field(:deadband, float(), intrinsic: true, default: 0.0)
  end
end
