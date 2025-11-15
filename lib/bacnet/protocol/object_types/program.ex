defmodule BACnet.Protocol.ObjectTypes.Program do
  @moduledoc """
  The Program object type defines a standardized object whose properties represent
  the externally visible characteristics of an application program. In this context,
  an application program is an abstract representation of a process within a BACnet
  Device, which is executing a particular body of instructions that act upon a particular
  collection of data structures. The logic that is embodied in these instructions and
  the form and content of these data structures are local matters. The Program object
  provides a network-visible view of selected parameters of an application program
  in the form of properties of the Program object. Some of these properties are
  specified in the standard and exhibit a consistent behavior across different
  BACnet Devices. The operating state of the process that executes the application
  program may be viewed and controlled through these standardized properties,
  which are required for all Program objects. In addition to these standardized
  properties, a Program object may also provide vendor-specific properties.
  These vendor-specific properties may serve as inputs to the program, outputs from
  the program, or both. However, these vendor-specific properties may not be present at all.

  If any vendor-specific properties are present, the standard does not define what they
  are or how they work, as this is specific to the particular application program and vendor.

  Program objects may optionally support intrinsic reporting to facilitate the reporting
  of fault conditions. Program objects that support intrinsic reporting shall apply
  the NONE event algorithm.

  (ASHRAE 135 - Clause 12.22)
  """

  # TODO: Docs

  alias BACnet.Protocol.Constants

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Program object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :program) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:program_state, Constants.program_state(), required: true, readonly: true)
    field(:program_change, Constants.program_request(), required: true, default: :ready)

    field(:reason_for_halt, Constants.program_error(),
      readonly: true,
      implicit_relationship: :description_of_halt
    )

    field(:description_of_halt, String.t(), readonly: true)

    field(:instance_of, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:profile_name, String.t())
  end
end
