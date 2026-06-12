defmodule BACnet.Protocol.ObjectTypes.PulseConverter do
  @moduledoc """
  The Pulse Converter object turns a raw pulse train (from a physical input)
  into engineering-unit rate or total values over a configurable time window.
  It is especially useful for demand metering (kW, gpm, etc.) where you
  want a smoothed rate without having to count every pulse yourself.

  The object references a pulse source via `input_reference` (i.e. pointing at
  an a Binary Input that produces pulses) and maintains a `present_value`
  (scaled engineering units), an `adjust_value` for manual correction,
  a raw `count`, and timing properties (`update_time`, `count_change_time`).
  The converter never generates pulses itself;
  it only observes an external source.

  ### Object Description (ASHRAE 135)

  > The Pulse Converter object type defines a standardized object that represents
  > a process whereby ongoing measurements made of some quantity, such as
  > electric power or water or natural gas usage, and represented by pulses or counts,
  > might be monitored over some time interval.
  >
  > Pulse Converter objects that support intrinsic reporting shall apply
  > the OUT_OF_RANGE event algorithm.

  ### Behaviour and Operation

  Pulse Converter objects turn a raw pulse or count source into a rate or integrated
  engineering value over a time window. The local application or a periodic task
  must feed pulses into the object (via the referenced `input_reference` pointing at
  Binary Input).

  The object then computes `present_value` (scaled by `scale_factor` and adjusted
  by `adjust_value`) and maintains timing properties. Clients read the derived
  rate/total; they do not write pulses.

  `out_of_service` can pause the conversion while a test value is forced into
  `present_value`. The `reliability` property and corresponding `FAULT` state
  are also to be decoupled.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The converted engineering value (rate or total)
    = (count or input pulses) * scale_factor + adjust_value.
    **Dev must**: Maintain `count` by observing the `input_reference` if present,
    and update `present_value` after your conversion math. This is the live
    derived input.

  - `count`, `count_change_time`, `count_before_change`: Raw pulse count tracking
    (similar to Accumulator's change tracking).
    **Dev must**: When pulses arrive (from hardware or by reading the `input_reference`
    object), update count, and on manual adjustment via `adjust_value`
    or resets, populate the before/change times. These enable detecting adjustments.

  - `input_reference` (ObjectPropertyRef): Points to source of pulses (typically a BinaryInput).
    **Dev must**: If set, your periodic task or change listener must read the source
    (local or remote ReadProperty) and use it to modify `count` and `present_value`.
    If the object is remote, handle communication errors via `reliability`.

  - `adjust_value`: Manual offset/correction.
    **Dev must**: Allow writes; your conversion should include it.

  - `scale_factor`: Conversion factor.
    **Dev must**: Set at creation from meter characteristics; usually static.

  - `cov_increment`, `cov_period`: For COV on the converted value.
    **Dev must**: Normal PV updates will trigger COV logic using these.

  - `out_of_service`, `status_flags`, `reliability`:
    **Dev must**: While `out_of_service` is `true`, allow forcing `present_value` for test;
    suspend normal `input_reference` polling and `count` updates.
    Maintain reliability from source health, if `out_of_service` is `false`.
    The `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are auto-managed by
    the object (`overridden` is local matter).

  - `high_limit`, `low_limit`, `deadband`: For out of range on the converted value.
    **Dev must**: After PV/count changes, re-eval the algorithm and drive notifications.

  ### Examples

  Creating a Pulse Converter:

      iex> {:ok, pc} = BACnet.Protocol.ObjectTypes.PulseConverter.create(400, "UsageRate", %{}); pc.object_name
      "UsageRate"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.OutOfRange`
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Pulse Converter object.
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
