defmodule BACnet.Test.Protocol.ObjectTypes.FileTest do
  alias BACnet.Protocol.ObjectTypes.File

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_file

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
end
