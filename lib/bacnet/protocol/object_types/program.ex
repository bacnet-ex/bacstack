defmodule BACnet.Protocol.ObjectTypes.Program do
  @moduledoc """
  The Program object gives BACnet clients a standardised window into a vendor-specific
  control program, script, or state machine running inside the device. It exposes the
  current `program_state` (idle, running, halted, etc.), a `program_change` command
  property that can be used to start, stop, restart, or unload the program, plus
  optional `reason_for_halt`, `program_location`, and `instance_of` (for identifying
  which program (image) is loaded).

  The object deliberately leaves the actual program logic and any additional
  parameters as vendor-specific. It is the standard way to monitor and control
  embedded control logic, custom sequences, or downloadable applications from a
  BACnet workstation.

  ### Object Description (ASHRAE 135)

  > The Program object type defines a standardized object whose properties represent
  > the externally visible characteristics of an application program.
  >
  > Program objects that support intrinsic reporting shall apply the NONE event algorithm.

  ### Behaviour and Operation

  Program objects give network visibility and limited control over a vendor-specific
  control program, script, state machine or downloadable application running inside
  the device.

  The local program runtime is responsible for updating `program_state`,
  `reason_for_halt`, `program_location`, etc. as the program executes. Clients can
  write to `program_change` to request start, stop, restart, unload, etc. The object
  implementation (or device server) translates the `program_change` request into
  the appropriate action on the underlying program.

  `program_change` is the control surface. Reliability can reflect problems with
  the program image or runtime.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, via `update_property/3` (never direct mutation).
  Read notes below + generated tables for details.

  **Special / live properties and expected developer behaviour**

  - `program_state`: idle, running, halted, loading, etc.
    **Dev must**: Your actual runtime (script, PLC, state machine) must keep this
    updated as it executes.

  - `program_change`: The control surface (ready, load, run, halt, restart, unload...).
    **Dev must**: On write/change, interpret and perform the action
    on your runtime. Then update `program_state` and set `program_change` to `ready`
    to reflect result.

  - `reason_for_halt`, `description_of_halt`: Details on why halted.
    **Dev must**: Your runtime sets these when entering halted state.

  - `program_location`, `instance_of`: Identification of what is loaded.
    **Dev must**: Set when loading.

  - `out_of_service`, `status_flags`, `reliability`:
    **Dev must**: Reliability for image corrupt, interpreter crash, missing resources.
    Your runtime updates these. `in_alarm`/`fault`/`out_of_service` bits of `status_flags`
    are auto-managed by the object. The `status_flags` property is automatically updated
    depending on the `program_state` (idle means not in service, `TRUE`).

  See the detailed "Your runtime owns the real program" and
  "program_change is the control surface" below.

  The Program object is a *window* into something that is deliberately
  vendor-specific. The BACnet-visible surface is small; everything interesting
  lives in the "black box" that the Program object points at.

  **Your runtime owns the real program**: The object only stores the standardised
  view (`program_state`, `program_change`, `reason_for_halt`, `program_location`,
  `instance_of`, `description_of_halt`, …). Your script / state machine / PLC logic / …
  is responsible for keeping those fields up to date as it runs.

  **program_change is the control surface**: When a client (or your own code)
  writes a `program_request` (ready, load, run, halt, restart, unload, …) into
  `program_change`, *you* must interpret it and actually do the work:
  - load a new image (perhaps from a File object)
  - start / stop / single-step the interpreter or task
  - unload / free resources
  After the action you write the resulting state back into `program_state` and
  update `program_change` to `ready`.

  **program_state is what the world sees**: idle, loading, running, waiting,
  halted, etc. Your runtime must keep it current; clients poll it or subscribe
  to COVs on it to know what the "app" is doing.

  **Reliability**: Use it for "the program image is corrupt", "the interpreter
  crashed", "a required external resource (another object, a file, a network
  connection) is missing", etc. `reason_for_halt` gives a more detailed code
  when the program is in the halted state.

  **Reinitialise / power up**: On device restart you set the Program
  object back to a known state based on your program's state.

  ### Examples

  Creating a Program object:

      iex> {:ok, p} = BACnet.Protocol.ObjectTypes.Program.create(1400, "MyApp", %{program_state: :idle}); p.object_name
      "MyApp"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.None`
  """

  alias BACnet.Protocol.Constants

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Program object.
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
    field(:out_of_service, boolean(), required: true, protected: true)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:profile_name, String.t())
  end

  defp inhibit_object_check(obj) do
    # out_of_service MUST be false if program state is idle
    {:ok, %{obj | out_of_service: obj.program_state == :idle}}
  end
end
