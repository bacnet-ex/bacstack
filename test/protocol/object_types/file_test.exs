defmodule BACnet.Test.Protocol.ObjectTypes.FileTest do
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.File
  alias BACnet.Protocol.Services.Ack.AtomicReadFileAck
  alias BACnet.Protocol.Services.Ack.AtomicWriteFileAck
  alias BACnet.Protocol.Services.AtomicReadFile
  alias BACnet.Protocol.Services.AtomicWriteFile
  alias Elixir.File, as: DiskFile

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_file

  @modified_at BACnetDateTime.from_datetime(~U[2026-11-09 12:00:00.12Z])

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify property_writable?/2 is custom implemented for file_size" do
    {:ok, obj} = File.create(1, "TEST", %{file_access_method: :stream_access, read_only: false})
    assert true == File.property_writable?(obj, :file_size)
    {:ok, obj} = File.create(1, "TEST", %{file_access_method: :stream_access, read_only: true})
    assert false == File.property_writable?(obj, :file_size)
    {:ok, obj} = File.create(1, "TEST", %{file_access_method: :record_access, read_only: false})
    assert false == File.property_writable?(obj, :file_size)
    {:ok, obj} = File.create(1, "TEST", %{file_access_method: :record_access, read_only: true})
    assert false == File.property_writable?(obj, :file_size)
  end

  test "verify property_writable?/2 still works for other properties" do
    {:ok, obj1} = File.create(1, "TEST", %{file_access_method: :stream_access, read_only: false})

    assert false == File.property_writable?(obj1, :present_value)
    assert false == File.property_writable?(obj1, :description)

    {:ok, obj2} = File.create(1, "TEST", %{description: ""})
    assert true == File.property_writable?(obj2, :description)
  end

  test "read preparation caps the count using the actual stream length" do
    {:ok, file} = File.create(1, "Config", %{read_only: true, file_size: 100})

    read = %AtomicReadFile{
      object_identifier: File.get_object_identifier(file),
      stream_access: true,
      start_position: 2,
      requested_count: 10
    }

    assert {:ok, %AtomicReadFile{start_position: 2, requested_count: 3}, true} =
             File.prepare_file_read(file, read, 5)

    assert {:ok, %AtomicReadFile{requested_count: 1}, false} =
             File.prepare_file_read(file, %{read | requested_count: 1}, 5)

    assert {:ok, %AtomicReadFile{requested_count: 0}, false} =
             File.prepare_file_read(file, %{read | start_position: 5}, 5)

    for start_position <- [-1, 6] do
      assert {:error, {:services, :invalid_file_start_position}} =
               File.prepare_file_read(file, %{read | start_position: start_position}, 5)
    end
  end

  test "record positions and counts are independent of the octet size" do
    {:ok, file} =
      File.create(1, "Log", %{file_access_method: :record_access, file_size: 900, record_count: 3})

    id = File.get_object_identifier(file)

    read = %AtomicReadFile{
      object_identifier: id,
      stream_access: false,
      start_position: 1,
      requested_count: 10
    }

    append = %AtomicWriteFile{
      object_identifier: id,
      stream_access: false,
      start_position: -1,
      data: ["one", "two"]
    }

    assert {:ok, %AtomicReadFile{requested_count: 2}, true} =
             File.prepare_file_read(file, read, 3)

    assert {:ok, %AtomicWriteFile{start_position: 3, data: ["one", "two"]}} =
             File.prepare_file_write(file, append, 3)
  end

  test "write preparation enforces access and leaves explicit extension positions intact" do
    {:ok, file} = File.create(1, "Config")

    write = %AtomicWriteFile{
      object_identifier: File.get_object_identifier(file),
      stream_access: true,
      start_position: 10,
      data: <<7>>
    }

    assert {:ok, ^write} = File.prepare_file_write(file, write, 3)

    assert {:error, {:services, :invalid_file_start_position}} =
             File.prepare_file_write(file, %{write | start_position: -2}, 3)

    assert {:error, {:services, :invalid_file_access_method}} =
             File.prepare_file_write(file, %{write | stream_access: false}, 3)

    assert {:error, {:services, :inconsistent_object_type}} =
             File.prepare_file_write(
               file,
               %{write | object_identifier: %ObjectIdentifier{type: :device, instance: 1}},
               3
             )

    assert {:error, {:object, :unknown_object}} =
             File.prepare_file_write(
               file,
               %{write | object_identifier: %ObjectIdentifier{type: :file, instance: 2}},
               3
             )

    {:ok, read_only} = File.update_property(file, :read_only, true)

    assert {:error, {:services, :file_access_denied}} =
             File.prepare_file_write(read_only, write, 3)
  end

  test "storage changes publish octet size, selected record count and archive state together" do
    {:ok, file} =
      File.create(1, "Log", %{
        file_access_method: :record_access,
        file_size: 900,
        record_count: 3,
        archive: true
      })

    modified = BACnetDateTime.from_datetime(~U[2026-11-09 12:00:00.12Z])

    assert {:ok, %{file_size: 750, record_count: 2, modification_date: ^modified, archive: false}} =
             File.record_modification(file, %{file_size: 750, record_count: 2}, modified)

    assert {:ok, %{object_instance: 1, file_size: 0, record_count: 0, archive: false}} =
             File.record_modification(file, %{file_size: 0, record_count: 0}, modified)

    assert {:error, {:invalid_property_type, :record_count}} =
             File.record_modification(file, %{file_size: 750, record_count: nil}, modified)
  end

  test "date edits and same-timestamp storage changes invalidate the archive appropriately" do
    modified = BACnetDateTime.from_datetime(~U[2026-11-09 12:00:00Z])
    later = BACnetDateTime.from_datetime(~U[2026-11-09 13:00:00Z])
    {:ok, file} = File.create(1, "Config", %{archive: true, modification_date: modified})

    assert {:ok, ^file} = File.update_property(file, :modification_date, modified)

    assert {:ok, %{modification_date: ^later, archive: false}} =
             File.update_property(file, :modification_date, later)

    assert {:ok, %{modification_date: ^modified, archive: false} = updated} =
             File.record_modification(file, %{file_size: 0, record_count: nil}, modified)

    refute File.has_property?(updated, :record_count)
  end

  test "an unknown octet size reports the BACnet property read error" do
    {:ok, file} = File.create(1, "Config", %{file_size: :unknown})
    read = Context.new({:property_read, :file_size, nil})

    assert {:error, {:property, :unknown_file_size}} = Lifecycle.prepare_read(file, read)

    assert {:ok, %Result{object: ^file, next_execution: nil}} =
             Lifecycle.prepare_read(file, Context.new({:property_read, :archive, nil}))
  end

  test "disk reads use the configured path and the actual length" do
    dir = create_disk_dir()
    path = Path.join(dir, "storage.bin")
    name = Path.join(dir, "object-name.bin")
    DiskFile.write!(path, "abcde")
    DiskFile.write!(name, "unrelated")
    {:ok, file} = File.create(1, name, %{file_size: 50, read_only: true}, file_path: path)

    read = %AtomicReadFile{
      object_identifier: File.get_object_identifier(file),
      stream_access: true,
      start_position: 1,
      requested_count: 2
    }

    assert {:ok,
            %AtomicReadFileAck{data: "bc", eof: false, start_position: 1, stream_access: true}} =
             File.read_file(file, read)

    assert {:ok, %AtomicReadFileAck{data: "bcde", eof: true, record_count: nil}} =
             File.read_file(file, %{read | requested_count: 100})

    assert {:ok, %AtomicReadFileAck{data: "", eof: false}} =
             File.read_file(file, %{read | start_position: 5})

    assert {:error, {:services, :invalid_file_start_position}} =
             File.read_file(file, %{read | start_position: 6})

    assert {:error, {:unknown_property, :file_path}} = File.get_property(file, :file_path)

    assert {:error, {:unknown_property, :file_path}} =
             File.update_property(file, :file_path, name)

    {:ok, unbound} = File.create(1, name)
    assert {:error, :file_path_not_configured} = File.read_file(unbound, read)
  end

  test "disk writes overwrite, append, and extend without losing other bytes" do
    dir = create_disk_dir()
    path = Path.join(dir, "storage.bin")
    DiskFile.write!(path, "abcde")
    {:ok, file} = File.create(1, "Config", %{file_size: 100, archive: true}, file_path: path)

    write = %AtomicWriteFile{
      object_identifier: File.get_object_identifier(file),
      stream_access: true,
      start_position: 1,
      data: "XY"
    }

    assert {:ok, %{file_size: 5, archive: false, modification_date: @modified_at} = file,
            %AtomicWriteFileAck{start_position: 1, stream_access: true}} =
             File.write_file(file, write, @modified_at)

    assert DiskFile.read!(path) == "aXYde"

    assert {:ok, %{file_size: 7} = file, %AtomicWriteFileAck{start_position: 5}} =
             File.write_file(file, %{write | start_position: -1, data: "fg"}, @modified_at)

    assert DiskFile.read!(path) == "aXYdefg"

    assert {:ok, %{file_size: 10} = file, %AtomicWriteFileAck{start_position: 9}} =
             File.write_file(file, %{write | start_position: 9, data: "z"}, @modified_at)

    assert DiskFile.read!(path) == "aXYdefg\0\0z"

    assert {:ok, %{file_size: 12}, %AtomicWriteFileAck{start_position: 12}} =
             File.write_file(file, %{write | start_position: 12, data: ""}, @modified_at)

    assert DiskFile.read!(path) == "aXYdefg\0\0z\0\0"
  end

  test "failed preflight leaves disk data alone and a missing path is not created" do
    dir = create_disk_dir()
    path = Path.join(dir, "storage.bin")
    DiskFile.write!(path, "original")
    {:ok, file} = File.create(1, "Config", %{}, file_path: path)

    write = %AtomicWriteFile{
      object_identifier: File.get_object_identifier(file),
      stream_access: true,
      start_position: 0,
      data: "replacement"
    }

    {:ok, read_only} = File.update_property(file, :read_only, true)

    assert {:error, {:services, :file_access_denied}} =
             File.write_file(read_only, write, @modified_at)

    assert {:error, {:services, :invalid_datatype}} =
             File.write_file(file, %{write | data: ["record"]}, @modified_at)

    invalid_time = %{@modified_at | time: %{@modified_at.time | minute: 60}}

    assert {:error, {:invalid_property_type, :modification_date}} =
             File.write_file(file, write, invalid_time)

    assert DiskFile.read!(path) == "original"

    invalid_position = 1_000_000_000_000_000_000_000_000_000_000

    assert {:error, {:file_write_failed, _reason, %{file_size: 8, archive: false}}} =
             File.write_file(file, %{write | start_position: invalid_position}, @modified_at)

    assert DiskFile.read!(path) == "original"

    missing = Path.join(dir, "missing.bin")
    {:ok, file} = File.create(1, "Config", %{}, file_path: missing)
    assert {:error, {:file_io, :enoent}} = File.write_file(file, write, @modified_at)
    refute DiskFile.exists?(missing)
  end

  test "disk reads reject directories, record access and remote snapshots" do
    dir = create_disk_dir()
    {:ok, stream} = File.create(1, "Stream", %{}, file_path: dir)

    {:ok, records} =
      File.create(1, "Records", %{file_access_method: :record_access}, file_path: dir)

    remote = %{stream | _metadata: %{stream._metadata | remote_object: 42}}

    read = %AtomicReadFile{
      object_identifier: File.get_object_identifier(stream),
      stream_access: true,
      start_position: 0,
      requested_count: 1
    }

    assert {:error, {:file_io, :not_regular}} = File.read_file(stream, read)

    assert {:error, {:services, :invalid_file_access_method}} =
             File.read_file(records, %{read | stream_access: false})

    assert {:error, :operation_not_available_for_remote_objects} = File.read_file(remote, read)

    assert {:error, :operation_not_available_for_remote_objects} =
             File.record_modification(remote, %{file_size: 0, record_count: nil}, @modified_at)
  end

  @sysfs_file "/sys/devices/system/cpu/kernel_max"
  @tag skip:
         (case DiskFile.stat(@sysfs_file) do
            {:ok, %DiskFile.Stat{type: :regular}} -> false
            _other -> true
          end)
  test "disk reads reject short data when a file advertises a larger size than it returns" do
    # This sysfs attribute advertises a page-sized file and returns one line of text.
    size = byte_size(DiskFile.read!(@sysfs_file))
    assert DiskFile.stat!(@sysfs_file).size > size + 1
    {:ok, file} = File.create(1, "CPU limit", %{}, file_path: @sysfs_file)

    read = %AtomicReadFile{
      object_identifier: File.get_object_identifier(file),
      stream_access: true,
      start_position: 0,
      requested_count: size + 1
    }

    assert {:error, {:file_io, :short_read}} = File.read_file(file, read)

    assert {:error, {:file_io, :short_read}} =
             File.read_file(file, %{read | start_position: size + 1, requested_count: 1})
  end

  defp create_disk_dir() do
    identifier = System.unique_integer([:positive, :monotonic])
    dir = Path.join(System.tmp_dir!(), "bacstack-file-#{System.pid()}-#{identifier}")
    DiskFile.mkdir!(dir)
    on_exit(fn -> DiskFile.rm_rf!(dir) end)
    dir
  end
end
