defmodule BACnet.Protocol.ObjectTypes.Group do
  @moduledoc """
  The Group object lets a client treat a collection of properties (possibly from
  many different objects) as a single named entity. A ReadProperty or
  ReadPropertyMultiple directed at the Group's `present_value` returns a list of the
  current values of every member.

  Each group member is described by an `BACnet.Protocol.AccessSpecification`.
  The server must ensure that group members reside in the same device.
  Groups provide a convenient "view" or "macro point" for HMI, scheduling, or
  bulk operations without the client having to know the individual object identifiers.

  ### Object Description (ASHRAE 135)

  > The Group object type defines a standardized object whose properties
  > represent a collection of other objects and one or more of their properties.

  ### Behaviour and Operation

  Group objects provide a named, readable view over a set of properties belonging
  to other objects (all of which must reside in the same device).
  The `list_of_group_members` (`BACnet.Protocol.AccessSpecification` list) is
  configured by the application or a tool.

  When a client reads the Group's `present_value`, the server must collect the
  current values of all referenced properties and return them as a list.
  The group object itself does not store values;
  it is a pure indirection / convenience mechanism.

  The server must validate at runtime (or at configuration time) that no group
  member is itself a Group or `BACnet.Protocol.ObjectTypes.GlobalGroup`
  (to avoid recursion) and that all referenced objects/properties exist.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, via `update_property/3` (never direct mutation).
  Read notes below + generated tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The list of current values for all members
    (one `BACnet.Protocol.ReadAccessResult` per member in the group,
    with the property value or error).
    **Dev must**: This is a computed "live" snapshot. When a client reads the
    group's `present_value` (or the group is used in other contexts),
    your code must read all the member properties and build the list of results.
    The object does not auto-compute; you provide the current aggregated view
    on demand or via realtime updates if you cache.

  - `list_of_group_members`: The definition of what is in the group.
    **Dev must**: Set at creation/config. Server must validate no recursion and
    existence (as noted in behaviour). Changes may require updating `present_value`
    view.

  ### Examples

  Creating a Group:

      iex> {:ok, g} = BACnet.Protocol.ObjectTypes.Group.create(1600, "ZoneGroup", %{}); g.object_name
      "ZoneGroup"

  ### See Also
  - `BACnet.Protocol.AccessSpecification`
  - `BACnet.Protocol.ReadAccessResult`
  """

  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ReadAccessResult

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Group object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Group object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  The device server needs to verify that each group member resides in the same device.
  """
  bac_object Constants.macro_assert_name(:object_type, :group) do
    services(intrinsic: false)

    field(:description, String.t())

    field(:list_of_group_members, [AccessSpecification.t()],
      required: true,
      default: [],
      validator_fun: fn list ->
        Enum.all?(list, fn %AccessSpecification{} = member ->
          # May not be a Group or Global Group object and reference the present value property
          !((member.object_identifier.type == Constants.macro_assert_name(:object_type, :group) or
               member.object_identifier.type ==
                 Constants.macro_assert_name(:object_type, :global_group)) and
              Enum.any?(member.properties, fn
                :all ->
                  true

                :required ->
                  true

                %AccessSpecification.Property{} = property ->
                  property.property_identifier ==
                    Constants.macro_assert_name(:property_identifier, :present_value)

                _else ->
                  false
              end))
        end)
      end
    )

    field(:present_value, [ReadAccessResult.t()], required: true, readonly: true, default: [])
  end
end
