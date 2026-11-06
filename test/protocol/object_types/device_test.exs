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

  test "vendor IDs resolve to names while explicit vendor names are preserved" do
    vendors = Device.get_vendor_ids()
    assert is_map(vendors)
    {vendor_id, vendor_name} = Enum.min_by(vendors, &elem(&1, 0))
    assert is_binary(vendor_name)

    assert {:ok, %Device{vendor_name: ^vendor_name}} =
             Device.create(1, "device", %{
               vendor_identifier: vendor_id,
               segmentation_supported: :no_segmentation
             })

    assert {:ok, %Device{vendor_name: "custom"}} =
             Device.create(1, "device", %{
               vendor_identifier: vendor_id,
               vendor_name: "custom",
               segmentation_supported: :no_segmentation
             })
  end

  test "unvalidated remote vendor identifiers fall back to an empty vendor name" do
    {:ok, local} =
      Device.create(1, "local", %{
        vendor_identifier: 1,
        segmentation_supported: :no_segmentation,
        description: "old"
      })

    properties =
      local
      |> Map.from_struct()
      |> Map.take(Device.get_required_properties() ++ [:description])
      |> Map.drop([:object_instance, :object_name])
      |> Map.put(:vendor_identifier, :invalid)
      |> Map.put(:vendor_name, "")

    assert {:ok, remote} =
             Device.create(2, "remote", properties,
               remote_object: 42,
               skip_property_validation_remote_object: true
             )

    assert {:ok, %Device{vendor_name: "", description: "new"}} =
             Device.update_property(remote, :description, "new")
  end

  test "Property local_date has on_read_function and works" do
    annotations = Device.get_annotation(:local_date)
    assert Keyword.keyword?(annotations)

    fun = Keyword.fetch!(annotations, :on_read_function)
    assert is_function(fun, 1)

    assert {:ok, %Device{} = dev} =
             Device.create(1, "Dev", %{
               local_date: BACnetDate.from_date(Date.add(Date.utc_today(), -1)),
               segmentation_supported: :no_segmentation,
               vendor_identifier: 999
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
               local_time: BACnetTime.from_time(Time.add(Time.utc_now(), -1)),
               segmentation_supported: :no_segmentation,
               vendor_identifier: 999
             })

    assert {:ok, %Device{} = dev2} = fun.(dev)

    # Dev2 time must be newer
    assert BACnetTime.compare(dev.local_time, dev2.local_time) == :lt
  end
end
