defmodule BACnet.Protocol.ObjectTypes.CharacterStringValue do
  @moduledoc """
  The Character String Value object stores an arbitrary-length UTF-8 (or BACnet
  character set) string as a network-visible named value. Typical uses include
  operator messages, equipment labels, alarm descriptions, configuration parameters
  expressed as text, or any other human-readable information that needs to be
  exchanged or modified over BACnet.

  The value can be made commandable via a priority array.
  When `intrinsic_reporting: true` is supplied at creation,
  the CHANGE_OF_CHARACTERSTRING event algorithm (plus optional FAULT_CHARACTERSTRING)
  is enabled so that specific string contents or transitions can raise alarms.

  ### Object Description (ASHRAE 135)

  > The CharacterString Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a named data value in a BACnet device.
  >
  > CharacterString Value objects that support intrinsic reporting shall apply the
  > CHANGE_OF_CHARACTERSTRING event algorithm.

  ### Behaviour and Operation

  Character String Value objects store free-form text. The string is a normal
  writable property unless the object has been made commandable via a priority array
  (in which case `present_value` is derived from the priority mechanism and direct
  writes are not permitted).

  The local application or a configuration client typically writes labels, messages,
  or configuration text into the object. When intrinsic reporting is enabled the
  CHANGE_OF_CHARACTERSTRING algorithm can raise alarms when the string matches (or
  stops matching) configured values.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The current string value.

  - `priority_array`, `relinquish_default`: For commandable strings.
    **Dev must**: Command via priority APIs.

  - `status_flags`: The `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are
    automatically updated by the object; `overridden` is a local matter.

  - `alarm_values` (list of strings for intrinsic): Values that are alarming.
    **Dev must**: For CHANGE_OF_CHARACTER_STRING alarming.

  - Intrinsic event + optional fault (character string fault).
    **Dev must**: On PV change, re-eval ChangeOfCharacterString (and fault if
    enabled) using params on object; update event state and notify.

  Value objects like this are simple named variables for strings; your
  application code reads and writes them as needed.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the CHANGE_OF_CHARACTERSTRING
  (and optionally FAULT_CHARACTERSTRING) algorithms become active.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable).

  ### Examples

  Creating a Character String Value:

      iex> {:ok, csv} = BACnet.Protocol.ObjectTypes.CharacterStringValue.create(40, "Message", %{present_value: "Hello"}); csv.object_name
      "Message"

  With intrinsic reporting:

      iex> {:ok, csv} = BACnet.Protocol.ObjectTypes.CharacterStringValue.create(41, "StatusMsg", %{present_value: "OK"}, intrinsic_reporting: true); csv.object_name
      "StatusMsg"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfCharacterString`
  - `BACnet.Protocol.FaultAlgorithms.FaultCharacterString` (optional)
  """

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a CharacterString Value object.

  In addition to the common options, CharacterString Value supports:
  - `intrinsic_reporting` - Enables CHANGE_OF_CHARACTERSTRING (and FAULT_CHARACTERSTRING) intrinsic reporting.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Character String Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :character_string_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, String.t(), required: true)
    field(:priority_array, PriorityArray.t(String.t()), readonly: true)
    field(:relinquish_default, String.t())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit,
      # If fault_values is present, reliability must be present too (but not the other way around)
      annotation: [required_when: {:property, :fault_values}]
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:fault_values, BACnetArray.t(String.t() | nil), default: BACnetArray.new())

    # Intrinsic Reporting
    field(:alarm_values, BACnetArray.t(String.t() | nil),
      default: BACnetArray.new(),
      intrinsic: true
    )

    field(:event_state, Constants.event_state(), intrinsic: true)
  end
end
