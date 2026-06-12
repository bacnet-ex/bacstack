defmodule BACnet.Protocol.ObjectTypes.File do
  @moduledoc """
  The File object is the BACnet abstraction for a data file stored inside (or
  accessible through) the device. It enables remote file transfer using the
  `BACnet.Protocol.Services.AtomicReadFile` and `BACnet.Protocol.Services.AtomicWriteFile`
  services. Clients first read the File object's properties to learn the file's
  size, access method (stream or record), and last modification time, then perform
  the actual transfer operations using the file's Object Identifier.

  The object does not interpret the file contents; that is a local matter (firmware
  image, configuration database, trend export, etc.). The `file_access_method`
  property declares whether the file is accessed as a stream of octets or as a
  sequence of records.

  ### Object Description (ASHRAE 135)

  > The File object type defines a standardized object that is used
  > to describe properties of data files that may be accessed using
  > File Services.

  ### Behaviour and Operation

  File objects are descriptors for data files accessible via the `AtomicReadFile`,
  `AtomicWriteFile` services. The local file system or virtual file handler is
  responsible for keeping `file_size`, `modification_date`, and `archive` in sync
  with the actual underlying storage.

  Clients first read the File object to learn the access method (`file_access_method`)
  and `file_size`, then issue file service requests using the object's identifier.
  The actual transfer of octets or records is performed by the file services
  implementation, not by the object itself. The object is a pure metadata container.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, via `update_property/3` (never direct mutation).
  Read notes below + generated tables for details.

  **Special / live properties and expected developer behaviour**

  - `file_size`: Current size in octets or records.
    **Dev must**: Your local application must keep this in sync with reality (after
    writes, appends, truncates). The override makes it writable only under certain
    conditions (e.g. not when `read_only`, or for growable files).

  - `file_access_method` (stream or record): How the file is accessed.
    **Dev must**: Set at creation based on your storage. The services use it to
    decide how to read.

  - `modification_date`: Last change time.
    **Dev must**: Update (via `update_property/3`) whenever your layer modifies the
    underlying file (write, append, etc.).

  - `read_only`, `archive`: Flags.
    **Dev must**: Your storage enforces `read_only` (refuse writes). `archive` is
    informational (for backup, etc.).

  The object is metadata only; the real work (byte streaming) is in the service
  handlers + your FS abstraction. See "You own the storage", "The services do the
  heavy lifting" and "Writing the metadata".

  The File object is purely a *handle + metadata* for something that the
  `AtomicReadFile` / `AtomicWriteFile` services will actually transfer.

  **You own the storage**: The object only publishes `file_size`, `file_access_method`
  (stream vs. record), `modification_date`, `archive`, `read_only`, etc. Your
  file system abstraction, respectively your application code,
  (flash, SD card, virtual config database, firmware image store, …) must keep
  those fields current.

  **The services do the heavy lifting**: When a client does `AtomicReadFile` or
  `AtomicWriteFile` using this object's ObjectIdentifier, your application code
  looks up the File object, checks `file_access_method`, `read_only`, current
  size, etc., and then streams the actual bytes to/from your storage layer.
  The object itself does not contain the data.

  **Typical uses**:
  - Firmware images (written by the vendor tool, read by the device on
    ReinitializeDevice or by a loader).
  - Configuration databases (the device writes them, a workstation can read
    them for backup or edit them and write them back).
  - Trend export files (the device periodically appends records to a file that
    a client can then read with the file services or via a Trend Log).

  **Access method**: `stream` vs. `record` affects how the file services interpret
  the offsets and how much data is transferred per PDU. Your storage layer
  must implement both (or at least the one advertised by the File object).

  The generated tables tell you exactly which fields are readonly,
  which have defaults, and which annotations affect encoding.

  File objects are the bridge between the "normal object world" (Read/Write
  Property) and the bulk data transfer world (the file services). A developer
  implementing them needs to keep the metadata on the object in sync with the
  real storage while letting the service layer do the actual octet/record
  movement.

  ### Examples

  Creating a File object:

      iex> {:ok, f} = BACnet.Protocol.ObjectTypes.File.create(1500, "ConfigFile", %{}); f.object_name
      "ConfigFile"

  ### See Also
  - `BACnet.Protocol.Services.AtomicReadFile`
  - `BACnet.Protocol.Services.AtomicWriteFile`
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a File object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a File object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :file) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:file_type, String.t(), required: true, default: "regular")
    field(:file_size, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:modification_date, BACnetDateTime.t(),
      required: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:archive, boolean(), required: true, default: false)
    field(:read_only, boolean(), required: true, default: false)

    field(:file_access_method, Constants.file_access_method(),
      required: true,
      readonly: true,
      default: :stream_access
    )

    field(:record_count, non_neg_integer(),
      validator_fun: fn _value, object ->
        object.file_access_method ==
          Constants.macro_assert_name(:file_access_method, :record_access)
      end
    )

    field(:profile_name, String.t())
  end

  # Override property_writable?/2, to be able to override :file_size behaviour
  # (writable if not read_only and stream_access)
  def property_writable?(%__MODULE__{} = object, property) when is_atom(property) do
    case property do
      :file_size ->
        not object.read_only and
          object.file_access_method ==
            Constants.macro_assert_name(:file_access_method, :stream_access)

      _term ->
        super(object, property)
    end
  end
end
