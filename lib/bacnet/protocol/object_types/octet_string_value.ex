defmodule BACnet.Protocol.ObjectTypes.OctetStringValue do
  @moduledoc """
  The Octet String Value object holds an arbitrary sequence of bytes as a network-visible
  named value. It is the binary counterpart to
  `BACnet.Protocol.ObjectTypes.CharacterStringValue` and is intended for data
  that has no textual interpretation on the wire: X.509 certificates, cryptographic keys,
  firmware image chunks, proprietary configuration blobs, compressed trend data, etc.

  The value can be made commandable (priority array) so that a client can write a new
  blob. There is no intrinsic interpretation or validation performed by the stack; the
  meaning and format are entirely a local matter between the device and the clients
  that read or write the object.

  ### Object Description (ASHRAE 135)

  > The OctetString Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a named data value in a
  > BACnet device.
  > A BACnet device can use an OctetString Value object to make any kind of
  > OCTET STRING data value accessible to other BACnet devices.

  ### Behaviour and Operation

  Octet String Value objects hold arbitrary binary blobs. They are used for
  certificates, firmware fragments, opaque configuration, etc. The blob can be
  written directly by the application or clients unless the object is commandable
  (priority array present). In the commandable case the effective value comes from
  the priority array and direct writes to present_value are not permitted.

  The stack performs no interpretation or validation of the bytes; that is entirely
  between the producer and consumer of the value.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The octet string (binary) value.
    **Dev must**: Your app or clients write the binary blob (direct or via priority
    if commandable). Consumers read it.

  - `priority_array`, `relinquish_default`: For commandable blobs.

  - `status_flags`: The `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are
    automatically updated by the object; `overridden` is a local matter.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable).

  ### Examples

  Creating an Octet String Value:

      iex> {:ok, osv} = BACnet.Protocol.ObjectTypes.OctetStringValue.create(50, "Data", %{present_value: <<1, 2, 3>>}); osv.object_name
      "Data"

  ### See Also
  - `BACnet.Protocol.ObjectTypes.CharacterStringValue`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an OctetString Value object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Octet String Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :octet_string_value) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, binary(),
      required: true,
      annotation: {:readonly_when, {:out_of_service, false}}
    )

    field(:priority_array, PriorityArray.t(binary()), readonly: true)
    field(:relinquish_default, binary())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:event_state, Constants.event_state())
  end
end
