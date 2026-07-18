defmodule BACnet.Protocol.ObjectTypes.Averaging do
  @moduledoc """
  The Averaging object computes minimum, maximum, and average (plus variance if
  supported) of a monitored property over a sliding time or sample window. It is
  intended for statistical monitoring, load profiling, or simple trending without
  requiring an external historian. The object references any numeric, boolean or
  enumerated property (local or on another device via `object_property_reference`)
  and samples it at the rate given by `window_interval` / `window_samples`.

  At any moment the current `minimum_value`, `maximum_value`, `average_value` (and
  `variance_value` when available) can be read. The window can be started, stopped or
  cleared via the `valid_samples` / `window_samples` mechanics. The object is
  read-only from the network perspective; it does not affect the sampled property.

  ### Object Description (ASHRAE 135)

  > The Averaging object type defines a standardized object whose properties represent
  > the externally visible characteristics of a value that is sampled periodically over
  > a specified time interval.

  ### Behaviour and Operation

  Averaging objects are passive statistical samplers. The local application (or an
  internal timer/task in the device server) is responsible for periodically sampling
  the property referenced by `object_property_reference` (which may be on a remote
  device) and feeding the samples into the object. The object then maintains the
  running `min_value`, `max_value`, `average_value` (and optionally `variance_value`)
  over the window defined by `window_interval` (seconds) or `window_samples` (count).

  The computed values and timestamps are exposed as readonly properties. The object
  never writes back to the sampled property. Network clients can only read the results;
  there is no commandability or priority array. `out_of_service` can be used to pause
  sampling.

  The object is useful for simple on-device trending or for providing derived
  statistics (peak, average load, etc.) without requiring a full Trend Log.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `min_value`, `average_value`, `max_value`, `variance_value`:
    The computed statistics over the window.
    **Dev must**: Your sampling task (timer or on-change from the source) must
    periodically read the `object_property_reference` (local or remote), feed the
    value into your window logic, compute the 4 aggregates, and update them via
    `update_property`. The object just stores; you drive the math and
    "aging" of the window (based on `window_interval` or `window_samples`).

  - `min_value_timestamp`, `max_value_timestamp`: When the min/max were
    observed.
    **Dev must**: Record the time (device time) of the samples that produced the
    current min/max when you update them.

  - `attempted_samples`, `valid_samples`: Counts for the current window.
    **Dev must**: Increment attempted on every sample attempt; valid only for good
    ones. Reset/recompute as window slides.

  - `object_property_reference` (DeviceObjectPropertyRef): The property being averaged.
    **Dev must**: If it points remote, your sampler must issue ReadProperty (or COV
    sub) to fetch current value + status. Update reliability, if reads fail.

  - `window_interval`, `window_samples`: Define the averaging window.
    **Dev must**: Your sampler uses these to decide when to drop old samples and
    recompute. Changes to these (writable) require you to adjust your window state.

  - `out_of_service`, `status_flags`, `reliability`:
    **Dev must**: `out_of_service`: stop feeding samples (last values stay visible). Reliability
    can reflect problems reading the referenced property. The `in_alarm`/`fault`/
    `out_of_service` bits of `status_flags` are auto-managed by the object
    (`overridden` local matter).

  No intrinsic by default. See the "Sampling responsibility is 100% yours",
  "Window mechanics", "Defaults and NaN/inf", "out_of_service" sections below.

  Averaging is a pure observer / derived-value object. It never affects the
  property it watches.

  **Sampling responsibility is 100% yours**: You must run a task (periodic timer,
  change subscriber on the source object, etc.) that:
  1. Reads the current value of the referenced property (the reference can be
     local or a DeviceObjectPropertyRef pointing at another device - you will
     need to do a ReadProperty over the network in the latter case).
  2. Calls something equivalent to `update_property(avg_obj, :min_value, new_min)`.
     The object will simply store what you give it.

  **Window mechanics**: The two main ways to define the window are:
  - `window_interval` (seconds) + `window_samples` - classic sliding time window.
  - You can also drive it purely by sample count.
  Your sampler decides when to "age out" old samples and recompute min/max/avg/
  variance. The object just holds the current aggregates and the timestamps of
  the min and max observations.

  **Defaults and NaN/inf**: The fields deliberately default to `:inf`, `:NaN` etc.
  so that until you have fed at least one sample the values are obviously
  "not yet valid". Your code should check `valid_samples > 0` before trusting
  the numbers.

  **out_of_service**: When true you should stop feeding samples. The last
  computed aggregates stay visible for diagnostics. You can still update the
  fields manually, if you want to inject test statistics.

  **No intrinsic alarming by default**: If you want alarms on "average too high",
  you normally create a separate `BACnet.Protocol.ObjectTypes.EventEnrollment`
  object that watches the `average_value` property of this object,
  or you implement your own limit checks on top of the averages you just read.

  **Remote references**: When `object_property_reference` points at a remote
  device you are responsible for the ReadProperty (or ReadPropertyMultiple) call
  on a schedule that makes sense for the window interval. Failures to read the
  remote property should probably be reflected in the reliability of the
  Averaging object.

  **Performance note for developers**: If you have many Averaging objects all
  sampling the same source, implement a fan-out: one reader task updates a
  canonical source object (or a cache), then a single "distributor" pushes the
  value into all the Averaging objects that reference it. This avoids N remote
  reads per sample period.

  All the min/max/avg/variance fields plus the two timestamps and the two
  counters (`attempted_samples`, `valid_samples`) are the complete state you
  need to persist.

  Because everything is readonly from the network point of view, a client can
  only ever read the current statistics; it cannot influence the sampling
  process except by writing `out_of_service` or by changing the
  `object_property_reference`.

  The macro tables at the bottom of the moduledoc show the exact types
  (including the special `ApplicationTags.ieee_float()` handling for NaN/inf)
  and which fields are purely computed by your sampler.

  ### Examples

  Creating an Averaging object:

      iex> {:ok, avg} = BACnet.Protocol.ObjectTypes.Averaging.create(300, "AvgTemp", %{window_interval: 3600}); avg.object_name
      "AvgTemp"

  ### See Also
  - `BACnet.Protocol.ObjectTypes.EventEnrollment`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Averaging object.
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
  end
end
