defmodule BACnet.Protocol.ObjectTypes.Averaging do
  @moduledoc """
  The Averaging object type defines a standardized object whose properties represent
  the externally visible characteristics of a value that is sampled periodically over
  a specified time interval. The Averaging object records the minimum, maximum and
  average value over the interval, and makes these values visible as properties of
  the Averaging object. The sampled value may be the value of any BOOLEAN, INTEGER,
  Unsigned, Enumerated or REAL property value of any object within the BACnet
  Device in which the object resides. Optionally, the object property to be sampled
  may exist in a different BACnet Device.

  The Averaging object shall use a "sliding window" technique that maintains a buffer
  of N samples distributed over the specified interval. Every (time interval/N) seconds
  a new sample is recorded displacing the oldest sample from the buffer. At this time,
  the minimum, maximum and average are recalculated. The buffer shall maintain an
  indication for each sample that permits the average calculation and minimum/maximum
  algorithm to determine the number of valid samples in the buffer.

  (ASHRAE 135 - Clause 12.5)
  """

  # TODO: Docs

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents an Averaging object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :averaging) do
    services(intrinsic: false)

    field(:description, String.t())

    field(:min_value, ApplicationTags.ieee_float(),
      required: true,
      readonly: true,
      default: :inf
    )

    field(:min_value_timestamp, BACnetDateTime.t(),
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:average_value, ApplicationTags.ieee_float(),
      required: true,
      readonly: true,
      default: :NaN
    )

    field(:variance_value, ApplicationTags.ieee_float(),
      readonly: true,
      default: :NaN
    )

    field(:max_value, ApplicationTags.ieee_float(),
      required: true,
      readonly: true,
      default: :infn
    )

    field(:max_value_timestamp, BACnetDateTime.t(),
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:attempted_samples, non_neg_integer(), required: true, default: 0)
    field(:valid_samples, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:object_property_reference, DeviceObjectPropertyRef.t(),
      required: true,
      default: ObjectsMacro.get_default_dev_object_ref()
    )

    field(:window_interval, non_neg_integer(), required: true)
    field(:window_samples, non_neg_integer(), required: true, default: 0)

    field(:profile_name, String.t())
  end
end
