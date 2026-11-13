defmodule BACnet.Protocol.ObjectTypes.File do
  @moduledoc """
  A File object exposes data that a BACnet client can transfer using
  `BACnet.Protocol.Services.AtomicReadFile` or
  `BACnet.Protocol.Services.AtomicWriteFile`. Read its metadata to learn
  the size, access method and modification time. Use its object identifier
  in the transfer request.

  The object does not interpret the file contents - that is a local matter (firmware
  image, configuration database, trend export, etc.). The `file_access_method`
  property declares whether the file is accessed as a stream of octets or as a
  sequence of records.

  ### Object Description (ASHRAE 135)

  > The File object type defines a standardized object that is used
  > to describe properties of data files that may be accessed using
  > File Services.

  ### Behaviour and Operation

  File_Size always describes the number of octets. Record_Count, when present
  on a record-access file, describes the number of records. Use `:unknown`
  for File_Size when the storage cannot report it. A File_Size read through
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` then returns
  `{:error, {:property, :unknown_file_size}}`.

  Use `prepare_file_read/3` and `prepare_file_write/3` to check a request
  against the File object and the actual length of the underlying data.
  The length is measured in octets for stream access and records for record
  access. The read helper bounds the requested count to the available data.
  The write helper resolves append requests and checks Read_Only.

  After a storage change, use `record_modification/3` to build the matching
  File metadata. It updates File_Size and any selected Record_Count, records
  Modification_Date, and clears Archive. An archiver can set Archive to true
  with `update_property/3` after it completes. Changing Modification_Date on a
  local object also clears Archive. At creation, supply a specific local
  `modification_date` when the device exposes Local_Date and Local_Time.
  The default is an unspecified date and time.

  ### Disk-backed stream access

  For a local stream-access file, pass `file_path: path` in `create/4` to bind
  the object to an existing regular file. The path comes from trusted local
  configuration and is stored as internal metadata. Requests select the object
  by Object_Identifier. Renaming the object leaves its storage binding intact.
  Supply the initial size and modification date from storage when registering
  the object.

  Use `read_file/2` and `write_file/3` to transfer octets using the configured
  file. The host needs to serialize access to the file until it has published
  any returned metadata. Record-access storage can use the request preparation
  and metadata helpers with its own record format.

  ### Storage and service integration

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  owns the storage and needs to serialize file service requests with property
  writes and internal modifications. When using a custom storage adapter,
  measure the data and apply the prepared request against the same snapshot.
  A write past the end needs to extend the file to the requested position.
  The intervening octets or records are a local storage decision.

  For a supported File_Size or Record_Count property write, the host needs to
  resize the underlying octets or records, respectively, and publish the new
  metadata with the storage change. A value of zero clears the data while
  retaining the File object. The host may restrict which sizes it accepts
  under ASHRAE 135-2016 Clauses 12.13.6 and 12.13.11. Use `update_property/3`
  to build property candidates and use `record_modification/3` with the actual
  storage measurements when applying the change. If storage changes before a
  failure, the host needs to reconcile the metadata with the resulting data.

  Common uses include firmware images, configuration databases, and trend
  exports. A storage adapter needs to support the access method advertised by
  the object.

  ### Examples

  Prepare a stream append to a three-octet file. After the storage write,
  record the resulting four-octet size and local modification time.

      iex> alias BACnet.Protocol.BACnetDateTime
      iex> alias BACnet.Protocol.ObjectTypes.File
      iex> alias BACnet.Protocol.Services.AtomicWriteFile
      iex> {:ok, file} = File.create(1500, "ConfigFile", %{file_size: 3, archive: true})
      iex> request = %AtomicWriteFile{
      ...>   object_identifier: File.get_object_identifier(file),
      ...>   stream_access: true,
      ...>   start_position: -1,
      ...>   data: <<42>>
      ...> }
      iex> {:ok, append} = File.prepare_file_write(file, request, 3)
      iex> append.start_position
      3
      iex> modified = BACnetDateTime.from_datetime(~U[2026-11-09 12:00:00Z])
      iex> measurements = %{file_size: 4, record_count: nil}
      iex> {:ok, file} = File.record_modification(file, measurements, modified)
      iex> {file.file_size, file.archive}
      {4, false}

  ### See Also
  - `BACnet.Protocol.Services.AtomicReadFile`
  - `BACnet.Protocol.Services.AtomicWriteFile`
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.Services.Ack.AtomicReadFileAck
  alias BACnet.Protocol.Services.Ack.AtomicWriteFileAck
  alias BACnet.Protocol.Services.AtomicReadFile
  alias BACnet.Protocol.Services.AtomicWriteFile
  alias Elixir.File, as: DiskFile

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a File object.

  `file_path` binds a local stream-access File to an existing regular file.
  Supply this path from trusted application configuration.
  """
  @type object_opts :: common_object_opts() | {:file_path, binary()}

  @typedoc """
  Storage measurements after a change. File size is always measured in octets.
  Supply a record count when the File object exposes Record_Count.
  """
  @type storage_measurements :: %{
          file_size: non_neg_integer() | :unknown,
          record_count: non_neg_integer() | nil
        }

  @typedoc """
  A BACnet error class and code reported during file access preparation.
  """
  @type file_access_error ::
          {:error, {class :: Constants.error_class(), code :: Constants.error_code()}}

  @typedoc """
  Errors reported before or while accessing a configured disk file.
  """
  @type disk_file_error ::
          file_access_error()
          | {:error, :file_path_not_configured | :operation_not_available_for_remote_objects}
          | {:error, {:file_io, reason :: atom()}}

  @typedoc """
  A disk write that may have changed the file before failing.

  `updated` is the metadata to publish for the resulting file. Its File_Size
  is `:unknown` if measuring the resulting length failed.
  """
  @type disk_write_error :: {:error, {:file_write_failed, reason :: atom(), updated :: t()}}

  @typedoc """
  Represents a File object. Treat struct fields as read-only. Use the property
  operations and `record_modification/3` to build updates.
  """
  bac_object Constants.macro_assert_name(:object_type, :file) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:file_type, String.t(), required: true, default: "regular")

    field(:file_size, non_neg_integer() | :unknown,
      required: true,
      readonly: true,
      default: 0,
      bac_type: {:type_list, [:unsigned_integer, {:literal, :unknown}]}
    )

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
  end

  @doc """
  Checks property writability. File_Size is writable for a stream-access file
  when Read_Only is false.
  """
  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
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

  @doc """
  Updates a File property. A change to a local Modification_Date clears Archive.
  """
  @spec update_property(t(), Constants.property_identifier(), term()) ::
          {:ok, t()} | property_update_error()
  def update_property(object, property, value)

  def update_property(
        %__MODULE__{_metadata: %{remote_object: nil}} = object,
        :modification_date,
        value
      )
      when value != object.modification_date do
    with {:ok, updated} <- super(object, :modification_date, value) do
      {:ok, %{updated | archive: false}}
    end
  end

  def update_property(%__MODULE__{} = object, property, value) when is_atom(property) do
    super(object, property, value)
  end

  @doc """
  Checks a local File_Size read for an unknown storage size.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | file_access_error()
  def validate_execution(object, context)

  def validate_execution(
        %__MODULE__{file_size: :unknown, _metadata: %{remote_object: nil}},
        %Context{trigger: {:property_read, :file_size, _index}}
      ),
      do: {:error, {:property, :unknown_file_size}}

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    super(object, context)
  end

  @doc """
  Checks an AtomicReadFile request and limits the requested count to the available data.

  Pass the actual storage length in the units of the request. The returned
  `eof` flag is true when the prepared range includes the last octet or record.
  The host needs to read that range from the same storage snapshot.
  """
  @doc group: "Functions Operational"
  @spec prepare_file_read(t(), AtomicReadFile.t(), non_neg_integer()) ::
          {:ok, read :: AtomicReadFile.t(), eof :: boolean()} | file_access_error()
  def prepare_file_read(%__MODULE__{} = object, %AtomicReadFile{} = request, length)
      when is_integer(length) and length >= 0 do
    with :ok <- validate_file_access(object, request.object_identifier, request.stream_access) do
      prepare_read_range(request, length)
    end
  end

  @doc """
  Checks an AtomicWriteFile request and resolves an append to its actual start position.

  Pass the current storage length in the units of the request. Writes at or
  beyond that length are allowed. The host needs to extend the storage as
  required and publish the corresponding metadata after a successful write.
  """
  @doc group: "Functions Operational"
  @spec prepare_file_write(t(), AtomicWriteFile.t(), non_neg_integer()) ::
          {:ok, AtomicWriteFile.t()} | file_access_error()
  def prepare_file_write(%__MODULE__{} = object, %AtomicWriteFile{} = request, length)
      when is_integer(length) and length >= 0 do
    with :ok <- validate_file_write(object, request) do
      {:ok, resolve_write_position(request, length)}
    end
  end

  @doc """
  Reads octets from the configured disk file and builds an AtomicReadFile acknowledgment.

  The host needs to serialize this operation with writes to the same file.
  The read uses the length measured from the open file.
  """
  @doc group: "Functions Operational"
  @spec read_file(t(), AtomicReadFile.t()) :: {:ok, AtomicReadFileAck.t()} | disk_file_error()
  def read_file(%__MODULE__{} = object, %AtomicReadFile{} = request) do
    with :ok <- validate_file_access(object, request.object_identifier, request.stream_access),
         {:ok, path} <- disk_path(object) do
      with_disk_file(path, [:read], fn device ->
        with {:ok, length} <- :file.position(device, :eof),
             {:ok, read, eof} <- prepare_read_range(request, length),
             {:ok, data} <- read_octets(device, read.start_position, read.requested_count) do
          {:ok,
           %AtomicReadFileAck{
             stream_access: true,
             start_position: read.start_position,
             record_count: nil,
             data: data,
             eof: eof
           }}
        end
      end)
    end
  end

  @doc """
  Writes octets to the configured disk file and returns updated metadata and
  an AtomicWriteFile acknowledgment. Pass the local modification date and time.

  Existing bytes outside the written range are preserved. The operating system
  supplies zero bytes for any gap before the write. The host needs to serialize
  access through publication of the returned metadata. A `t:disk_write_error/0`
  includes metadata to publish if a write failed after it may have changed the file.
  """
  @doc group: "Functions Operational"
  @spec write_file(t(), AtomicWriteFile.t(), BACnetDateTime.t()) ::
          {:ok, updated :: t(), ack :: AtomicWriteFileAck.t()}
          | disk_file_error()
          | disk_write_error()
          | property_update_error()
  def write_file(
        %__MODULE__{} = object,
        %AtomicWriteFile{} = request,
        %BACnetDateTime{} = modified_at
      ) do
    with :ok <- validate_file_write(object, request),
         {:ok, path} <- disk_path(object),
         true <- is_binary(request.data) do
      with_disk_file(path, [:read, :write], fn device ->
        with {:ok, length} <- :file.position(device, :eof) do
          write_disk_stream(
            object,
            resolve_write_position(request, length),
            device,
            length,
            modified_at
          )
        end
      end)
    else
      false -> {:error, {:services, :invalid_datatype}}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Builds new metadata for a local File after its storage changes.

  Pass the actual measurements and a specific local Modification_Date when
  the device exposes Local_Date and Local_Time. A successful storage change
  invalidates the archive even if its timestamp has the same BACnet precision
  as the previous one. The host needs to publish the new metadata and storage
  together.
  """
  @doc group: "Functions Operational"
  @spec record_modification(t(), storage_measurements(), BACnetDateTime.t()) ::
          {:ok, t()}
          | property_update_error()
          | {:error, :operation_not_available_for_remote_objects}
  def record_modification(object, measurements, modified_at)

  def record_modification(
        %__MODULE__{_metadata: %{remote_object: remote}},
        _measurements,
        _modified_at
      )
      when not is_nil(remote),
      do: {:error, :operation_not_available_for_remote_objects}

  def record_modification(%__MODULE__{} = object, measurements, %BACnetDateTime{} = modified_at) do
    with {:ok, object} <- update_property(object, :file_size, measurements.file_size),
         {:ok, object} <- update_record_count(object, measurements.record_count),
         {:ok, object} <- update_property(object, :modification_date, modified_at) do
      {:ok, %{object | archive: false}}
    end
  end

  @spec prepare_read_range(AtomicReadFile.t(), non_neg_integer()) ::
          {:ok, read :: AtomicReadFile.t(), eof :: boolean()} | file_access_error()
  defp prepare_read_range(request, length) do
    if request.start_position in 0..length do
      remaining = length - request.start_position
      count = min(request.requested_count, remaining)
      {:ok, %{request | requested_count: count}, count > 0 and count == remaining}
    else
      {:error, {:services, :invalid_file_start_position}}
    end
  end

  @spec validate_file_write(t(), AtomicWriteFile.t()) :: :ok | file_access_error()
  defp validate_file_write(object, request) do
    with :ok <- validate_file_access(object, request.object_identifier, request.stream_access) do
      cond do
        object.read_only -> {:error, {:services, :file_access_denied}}
        request.start_position < -1 -> {:error, {:services, :invalid_file_start_position}}
        true -> :ok
      end
    end
  end

  @spec resolve_write_position(AtomicWriteFile.t(), non_neg_integer()) :: AtomicWriteFile.t()
  defp resolve_write_position(request, length) do
    if request.start_position == -1, do: %{request | start_position: length}, else: request
  end

  @spec disk_path(t()) :: {:ok, binary()} | disk_file_error()
  defp disk_path(object)

  defp disk_path(%__MODULE__{_metadata: %{remote_object: remote}}) when not is_nil(remote),
    do: {:error, :operation_not_available_for_remote_objects}

  defp disk_path(%__MODULE__{file_access_method: :record_access}),
    do: {:error, {:services, :invalid_file_access_method}}

  defp disk_path(%__MODULE__{_metadata: %{other: %{file_path: path}}})
       when is_binary(path) and byte_size(path) > 0,
       do: {:ok, path}

  defp disk_path(%__MODULE__{}), do: {:error, :file_path_not_configured}

  @spec with_disk_file(binary(), [:read | :write], (:file.fd() -> result)) ::
          result | disk_file_error()
        when result: var
  defp with_disk_file(path, modes, operation) do
    with {:ok, %Elixir.File.Stat{type: :regular}} <- DiskFile.stat(path),
         {:ok, result} <- DiskFile.open(path, [:raw, :binary | modes], operation) do
      case result do
        {:error, reason} when is_atom(reason) -> {:error, {:file_io, reason}}
        other -> other
      end
    else
      {:ok, %Elixir.File.Stat{}} -> {:error, {:file_io, :not_regular}}
      {:error, reason} -> {:error, {:file_io, reason}}
    end
  end

  @spec read_octets(:file.fd(), non_neg_integer(), non_neg_integer()) ::
          {:ok, binary()} | {:error, atom()}
  defp read_octets(device, position, count)

  defp read_octets(_device, _position, 0), do: {:ok, <<>>}

  defp read_octets(device, position, count) do
    case :file.pread(device, position, count) do
      {:ok, data} when byte_size(data) == count -> {:ok, data}
      {:ok, _data} -> {:error, :short_read}
      :eof -> {:error, :short_read}
      {:error, _reason} = error -> error
    end
  end

  @spec write_disk_stream(
          t(),
          AtomicWriteFile.t(),
          :file.fd(),
          non_neg_integer(),
          BACnetDateTime.t()
        ) ::
          {:ok, updated :: t(), ack :: AtomicWriteFileAck.t()}
          | disk_write_error()
          | property_update_error()
          | {:error, :operation_not_available_for_remote_objects}
  defp write_disk_stream(object, write, device, length, modified_at) do
    expected_length = max(length, write.start_position + byte_size(write.data))

    with {:ok, updated} <-
           record_modification(
             object,
             %{file_size: expected_length, record_count: nil},
             modified_at
           ) do
      case write_octets(device, write.start_position, write.data, length) do
        :ok ->
          {:ok, updated,
           %AtomicWriteFileAck{stream_access: true, start_position: write.start_position}}

        {:error, reason} ->
          actual_length =
            case :file.position(device, :eof) do
              {:ok, size} -> size
              {:error, _reason} -> :unknown
            end

          {:ok, actual} =
            record_modification(
              object,
              %{file_size: actual_length, record_count: nil},
              modified_at
            )

          {:error, {:file_write_failed, reason, actual}}
      end
    end
  end

  @spec write_octets(:file.fd(), non_neg_integer(), binary(), non_neg_integer()) ::
          :ok | {:error, atom()}
  defp write_octets(device, position, data, length)

  defp write_octets(device, position, <<>>, length) when position > length do
    with {:ok, _position} <- :file.position(device, position) do
      :file.truncate(device)
    end
  end

  defp write_octets(device, position, data, _length), do: :file.pwrite(device, position, data)

  @spec validate_file_access(t(), ObjectIdentifier.t(), boolean()) :: :ok | file_access_error()
  defp validate_file_access(object, identifier, stream_access) do
    cond do
      identifier.type != :file ->
        {:error, {:services, :inconsistent_object_type}}

      identifier != get_object_identifier(object) ->
        {:error, {:object, :unknown_object}}

      stream_access != (object.file_access_method == :stream_access) ->
        {:error, {:services, :invalid_file_access_method}}

      true ->
        :ok
    end
  end

  @spec update_record_count(t(), non_neg_integer() | nil) :: {:ok, t()} | property_update_error()
  defp update_record_count(object, count) do
    if has_property?(object, :record_count) do
      update_property(object, :record_count, count)
    else
      {:ok, object}
    end
  end
end
