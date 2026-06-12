defmodule BACnet.Protocol.ObjectTypes.StructuredView do
  @moduledoc """
  The Structured View object is a pure organisational container. It lets a device
  expose a hierarchical tree (or forest) of references to other objects so that a
  client can navigate the device content the same way a user would navigate a
  building ("Floor 3" -> "AHU-03" -> "Supply Temp"). Each view contains a
  `node_type`, a `node_subtype`, and a list of `subordinate_list` entries that point
  to child objects (which may themselves be other Structured Views).

  The structure is completely independent of the flat `object_list` in the Device
  object; it is an additional navigation aid. Views can represent physical hierarchy,
  functional systems, graphics pages, or any other grouping the implementer desires.

  ### Object Description (ASHRAE 135)

  > The Structured View object type defines a standardized object that provides
  > a container to hold references to subordinate objects, which may include other
  > Structured View objects, thereby allowing multilevel hierarchies to be created.

  ### Behaviour and Operation

  Structured View objects are passive organisational containers. They do not
  contain or duplicate data from the referenced objects; each entry in
  `subordinate_list` is a reference.

  The device or a configuration tool populates the tree.
  Clients use the view for navigation, graphics binding, or
  hierarchical browsing instead of (or in addition to) the flat `object_list` on
  the Device object. The view may reference objects that are not in the device's
  own object list (for proxy / remote views).

  No active behaviour, no commandability, no event generation.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). Read notes below + generated
  tables for details.

  The "live" aspect is entirely the tree maintenance you perform as your
  object population changes.
  See "You build and maintain the tree" and "Typical uses" below.

  A Structured View is a *navigation aid*, not a data container. It lets a client
  walk a tree (or DAG) that you have defined on top of your flat object
  population.

  **You build and maintain the tree**: At device startup, after a configuration
  change, or when a new object is created, your code must ensure that the
  `subordinate_list` (and the `node_type` / `node_subtype`) on the relevant
  Structured View objects are correct. Each subordinate entry is just a
  reference; the real data lives in the target object.

  **Typical uses**:
  - Physical hierarchy: Site -> Building -> Floor -> Room -> AHU -> Points
  - Functional systems: "Chilled Water System" -> all the pumps, valves,
    sensors that belong to it (even if they are scattered across several
    controllers)
  - Graphics pages: one view per graphic that lists exactly the points the
    page needs to bind
  - Proxy / remote views: a view on device A that contains references to
    objects that actually live on device B (the client follows the references
    with normal ReadProperty calls)

  **No automatic maintenance**: If you delete an object that is referenced from
  several views, you are responsible for cleaning up the `subordinate_list`
  entries. The Structured View object does not know about object deletion.

  **Writing the view**: Because the lists are normal properties, a sufficiently
  privileged client (or another tool) can completely reorganise your hierarchy
  at runtime.

  **Performance for clients**: A client that wants to draw a whole building can
  start at a root Structured View and recursively follow the subordinate
  references. Because each reference can be to a local or remote object, the
  client will issue the appropriate ReadProperty calls.

  Structured Views are the main mechanism a BACnet device has to impose
  structure on what would otherwise be a flat bag of objects.

  ### Examples

  Creating a Structured View:

      iex> {:ok, sv} = BACnet.Protocol.ObjectTypes.StructuredView.create(1700, "BuildingView", %{node_type: :device}); sv.object_name
      "BuildingView"

  <!--### See Also
  - *Nothing to see here*-->
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectRef

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Structured View object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Structured View object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :structured_view) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:node_type, Constants.node_type(), required: true)
    field(:node_subtype, String.t())
    field(:subordinate_list, [DeviceObjectRef.t()], required: true, default: [])
    field(:subordinate_annotations, [String.t()])
    field(:profile_name, String.t())
  end
end
