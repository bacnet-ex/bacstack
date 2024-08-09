defmodule BACnet.Protocol.ObjectTypes.StructuredView do
  @moduledoc """
  The Structured View object type defines a standardized object that provides
  a container to hold references to subordinate objects, which may include other
  Structured View objects, thereby allowing multilevel hierarchies to be created.

  The hierarchies are intended to convey a structure or organization such as a
  geographical distribution or application organization.
  Subordinate objects may reside in the same device as the Structured View object
  or in other devices on the network.

  (ASHRAE 135 - Clause 12.29)
  """

  # TODO: Docs

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectRef

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
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
