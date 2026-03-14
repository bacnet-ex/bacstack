defmodule BACnet.Test.Protocol.ObjectTypes.DeviceTest do
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.ObjectTypes.Device

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_device

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "Property local_date has on_read_function and works" do
    annotations = Device.get_annotation(:local_date)
    assert Keyword.keyword?(annotations)

    fun = Keyword.fetch!(annotations, :on_read_function)
    assert is_function(fun, 1)

    assert {:ok, %Device{} = dev} =
             Device.create(1, "Dev", %{
               local_date: BACnetDate.from_date(Date.add(Date.utc_today(), -1))
             })

    assert {:ok, %Device{} = dev2} = fun.(dev)

    # Dev2 date must be newer
    assert BACnetDate.compare(dev.local_date, dev2.local_date) == :lt
  end

  test "Property local_time has on_read_function and works" do
    annotations = Device.get_annotation(:local_time)
    assert Keyword.keyword?(annotations)

    fun = Keyword.fetch!(annotations, :on_read_function)
    assert is_function(fun, 1)

    assert {:ok, %Device{} = dev} =
             Device.create(1, "Dev", %{
               local_time: BACnetTime.from_time(Time.add(Time.utc_now(), -1))
             })

    assert {:ok, %Device{} = dev2} = fun.(dev)

    # Dev2 time must be newer
    assert BACnetTime.compare(dev.local_time, dev2.local_time) == :lt
  end
end
