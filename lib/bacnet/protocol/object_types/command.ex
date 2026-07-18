defmodule BACnet.Protocol.ObjectTypes.Command do
  @moduledoc """
  The Command object provides a single-point "macro" mechanism: writing an integer
  action code (`present_value`) causes the object to execute a predefined list of
  write operations on other object properties, all as a single atomic action from
  the network's point of view. This is the standard way to implement "go to occupied
  mode", "night setback", "fire alarm response", or any other coordinated multi-point
  state change.

  Each action in `action` (a list of `BACnet.Protocol.ActionCommand`) specifies
  a target object/property, a value to write (which may be a priority or relinquish),
  and optional conditions.
  The `action_text` array gives human-readable names for each action code.

  ### Object Description (ASHRAE 135)

  > The Command object type defines a standardized object whose properties represent
  > the externally visible characteristics of a multi-action command procedure.

  ### Behaviour and Operation

  Command objects are active "macro" executors. Writing an integer (1..N) to the
  `present_value` (the action code) causes the object to iterate over the
  corresponding entry in the `action` array (a list of `BACnet.Protocol.ActionList`)
  and perform the specified writes to other objects' properties
  (possibly on remote devices) as a single logical operation.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value` (non_neg_integer): The action code (1-based index into action).
    **Dev must**: This is the trigger, not a normal value.

  - `action`, `action_text`: The "program" of the macro.

  - `all_writes_successful`: Indicates last execution status?
    **Dev must**: Set/clear based on your execution results.

  The Command object is the standard way to expose a "canned sequence of writes"
  as a single network-visible action. It is deliberately *not* a priority-array
  commandable in the usual sense; the act of writing a new action code *is* the
  trigger.

  **Execution is your responsibility**: When a client (or your own internal code)
  successfully does `update_property(cmd_obj, :present_value, action_code)` you
  must:
  1. Look up the corresponding ActionList in `action`.
  2. For each ActionCommand in that list, perform the write it describes:
     - target object + property (can be a remote DeviceObjectPropertyRef)
     - value (an Encoding or primitive)
     - optional priority (for commandable targets) or the special "relinquish"
       sentinel
  3. You may abort early on error if the `quit_on_failure` property is set on
     an action command.

  Because the writes can target remote devices you will be issuing real
  WriteProperty / WritePropertyMultiple service requests (or using your
  client's write helpers).

  **action_text**: A parallel array of human strings so that an operator workstation
  can present a nice menu: "1 - Go to Night Setback", "2 - Fire Mode", etc.
  You populate it at creation time (or allow it to be written later).

  **Atomicity considerations for developers**: The BACnet spec says the writes
  appear atomic to the network. In practice you will do a series of individual
  writes. If you want true rollback you need to remember the previous values of
  the targets (which may require reading them first at the right priorities) and
  be prepared to write the old values back on failure.

  **Writing the action list from the wire**: Because `action` (a `BACnetArray` of
  `ActionList`) and `action_text` are normal writable properties, a sufficiently
  privileged client can completely reprogram what action N does.

  Command objects are one of the few places where a single network write can
  cause a cascade of other writes - design your execution engine with care
  around priority, failure handling, and logging so that operators can debug
  "why did the lights and the AHU both change at 17:00?".

  ### Examples

  Creating a Command object:

      iex> {:ok, cmd} = BACnet.Protocol.ObjectTypes.Command.create(1300, "ZoneControl", %{}); cmd.object_name
      "ZoneControl"

  ### See Also
  - `BACnet.Protocol.ActionCommand`
  - `BACnet.Protocol.ActionList`
  """

  alias BACnet.Protocol.ActionList
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Command object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Command object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :command) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:present_value, non_neg_integer(), required: true, default: 0)

    field(:in_process, boolean(), required: true, default: false)
    field(:all_writes_successful, boolean(), required: true, readonly: true, default: false)

    field(:action, BACnetArray.t(ActionList.t()),
      required: true,
      readonly: true,
      default: BACnetArray.new()
    )

    field(:action_text, BACnetArray.t(String.t()),
      validator_fun: &(BACnetArray.size(&1) == BACnetArray.size(&2[:action]))
    )
  end
end
