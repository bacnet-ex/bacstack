defmodule BACnet.Protocol.ObjectTypes.Command do
  @moduledoc """
  The Command object type defines a standardized object whose properties represent
  the externally visible characteristics of a multi-action command procedure.
  A Command object is used to write a set of values to a group of object properties,
  based on the "action code" that is written to the Present_Value of the Command object.
  Whenever the Present_Value property of the Command object is written to,
  it triggers the Command object to take a set of actions that change the values of
  a set of other objects' properties.

  The Command object would typically be used to represent a complex context involving
  multiple variables. The Command object is particularly useful for representing contexts
  that have multiple states. For example, a particular zone of a building might have
  three states: UNOCCUPIED, WARMUP, and OCCUPIED. To establish the operating context
  for each state, numerous objects' properties may need to be changed to a collection
  of known values. For example, when unoccupied, the temperature setpoint might be 18°C
  and the lights might be off. When occupied, the setpoint might be 22°C and the lights
  turned on, etc.

  The Command object defines the relationship between a given state and those values
  that shall be written to a collection of different objects' properties to realize that state.
  Normally, a Command object is passive. Its In_Process property is FALSE, indicating
  that the Command object is waiting for its Present_Value property to be written with a value.
  When Present_Value is written, the Command object shall begin a sequence of actions.
  The In_Process property shall be set to TRUE, indicating that the Command object has begun
  processing one of a set of action sequences that is selected based on the particular value
  written to the Present_Value property. If an attempt is made to write to the Present_Value
  property through WriteProperty services while In_Process is TRUE, then a Result(-) shall be
  returned with 'error class' = OBJECT and 'error code' = BUSY, rejecting the write.

  The new value of the Present_Value property determines which sequence of actions the Command
  object shall take. These actions are specified in an array of action lists indexed by this value.
  The Action property contains these lists. A given list may be empty, in which case no action
  takes place, except that In_Process is returned to FALSE and All_Writes_Successful is set to TRUE.
  If the list is not empty, then for each action in the list the Command object shall write a
  particular value to a particular property of a particular object in a particular BACnet Device.
  Note, however, that the capability to write to remote devices is not required.
  Note also that the Command object does not guarantee that every write will be successful,
  and no attempt is made by the Command object to "roll back" successfully written properties
  to their previous values in the event that one or more writes fail. If any of the writes fail,
  then the All_Writes_Successful property is set to FALSE and the Write_Successful flag for that
  BACnetActionCommand is set to FALSE. If the Quit_On_Failure flag is TRUE for the failed
  BACnetActionCommand, then all subsequent BACnetActionCommands in the list shall have their
  Write_Successful flag set to FALSE. If an individual write succeeds, then the Write_Successful flag
  for that BACnetActionCommand shall be set to TRUE. If all the writes are successful,
  then the All_Writes_Successful property is set to TRUE. Once all the writes have been processed
  to completion by the Command object, the In_Process property is set back to FALSE and the
  Command object becomes passive again, waiting for another command.

  It is important to note that the particular value that is written to the Present_Value property
  is not what triggers the action, but the act of writing itself. Thus if the Present_Value property
  has the value 5 and it is again written with the value 5, then the 5th list of actions will be
  performed again. Writing zero to the Present_Value causes no action to be taken and is the same as
  invoking an empty list of actions. The Command object is a powerful concept with many beneficial applications.
  However, there are unique aspects of the Command object that can cause confusing or destructive side effects
  if the Command object is improperly configured. Since the Command object can manipulate other
  objects' properties, it is possible that a Command object could be configured to command itself.
  In such a case, the In_Process property acts as an interlock and protects the Command object
  from selfoscillation.
  However, it is also possible for a Command object to command another Command object that commands the first
  Command object and so on. The possibility exists for Command objects that command GROUP objects.
  In these cases of "circular referencing," it is possible for confusing side effects to occur.
  When references occur to objects in other BACnet Devices, there is an increased possibility of time delays,
  which could cause oscillatory behavior between Command objects that are improperly configured
  in such a circular manner. Caution should be exercised when configuring Command objects
  that reference objects outside the BACnet device that contains them.

  (ASHRAE 135 - Clause 12.10)
  """

  # TODO: Docs

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.ActionList
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
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

    field(:profile_name, String.t())
  end
end
