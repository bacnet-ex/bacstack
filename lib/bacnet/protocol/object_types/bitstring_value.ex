defmodule BACnet.Protocol.ObjectTypes.BitstringValue do
  @moduledoc """
  The Bitstring Value object exposes an arbitrary-length bit string (a set of Boolean
  flags packed into an octet string) as a single named BACnet value. It is useful when
  you need to publish a compact status word, a collection of related alarm bits, mode
  bits, or any other group of Boolean states that naturally belong together.

  The bit string can be commandable (priority array) so clients can write individual
  bits or the whole string. COV and intrinsic reporting are supported; with
  `intrinsic_reporting: true` the CHANGE_OF_BITSTRING event algorithm (and optional
  FAULT_STATUS_FLAGS) become active, allowing alarms on specific bit transitions or
  fault conditions.

  ### Object Description (ASHRAE 135)

  > The Bitstring Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a named data value
  > in a BACnet device.
  >
  > Bitstring Value objects that support intrinsic reporting shall apply
  > the CHANGE_OF_BITSTRING event algorithm.

  ### Behaviour and Operation

  Bitstring Value objects hold a tuple of boolean flags (a bitstring).
  The local application maintains the bit string (or it can be written by
  clients when not commandable).

  The object may be made commandable by supplying a priority array at creation or
  later; in that case `present_value` (the bitstring) is derived from the priority
  mechanism.

  When intrinsic reporting is enabled the CHANGE_OF_BITSTRING algorithm (plus
  optional FAULT_STATUS_FLAGS) can generate events on changes to specific bits or
  on fault conditions encoded in the bits. COV is supported for the whole value.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The bit string value.
    **Dev must**: App/clients set the bits (direct or priority commandable).

  - `priority_array`, `relinquish_default`: Command sources.
    **Dev must**: Write via the high level APIs; the macro syncs PV from highest
    priority or default.

  - `bit_mask`: Used for the event algorithm.

  - `status_flags`: The `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are
    automatically updated by the object; `overridden` is a local matter. Standard.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the CHANGE_OF_BITSTRING
  event algorithm and related properties become active.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable).

  ### Examples

  Creating a Bitstring Value:

      iex> {:ok, bv} = BACnet.Protocol.ObjectTypes.BitstringValue.create(60, "Flags", %{present_value: {true, false}}); bv.object_name
      "Flags"

  With intrinsic reporting:

      iex> {:ok, bv} = BACnet.Protocol.ObjectTypes.BitstringValue.create(61, "Bits", %{present_value: {true, false}}, intrinsic_reporting: true); bv.object_name
      "Bits"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfBitstring`
  - `BACnet.Protocol.FaultAlgorithms.FaultStatusFlags` (optional)
  """

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Bitstring Value object.

  In addition to the common options, Bitstring Value supports:
  - `intrinsic_reporting` - Enables CHANGE_OF_BITSTRING intrinsic reporting.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Bitstring Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :bitstring_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, tuple(),
      required: true,
      validator_fun: fn val ->
        is_tuple(val) and
          val
          |> Tuple.to_list()
          |> Enum.all?(&is_boolean/1)
      end
    )

    field(:priority_array, PriorityArray.t(tuple()), readonly: true)

    field(:relinquish_default, tuple(),
      validator_fun: fn val ->
        is_tuple(val) and
          val
          |> Tuple.to_list()
          |> Enum.all?(&is_boolean/1)
      end
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:bit_text, BACnetArray.t(String.t()),
      default: BACnetArray.new(),
      validator_fun: &(BACnetArray.size(&1) == tuple_size(&2[:present_value]))
    )

    field(:profile_name, String.t())

    # Intrinsic Reporting
    field(:alarm_values, [tuple()],
      intrinsic: true,
      default: [],
      validator_fun: fn list ->
        Enum.all?(list, fn val ->
          is_tuple(val) and
            val
            |> Tuple.to_list()
            |> Enum.all?(&is_boolean/1)
        end)
      end
    )

    field(:bit_mask, tuple(), intrinsic: true)
    field(:event_state, Constants.event_state(), intrinsic: true)
  end
end
