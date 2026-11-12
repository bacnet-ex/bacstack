defmodule BACnet.Test.Protocol.ObjectTypes.StructuredViewTest do
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.StructuredView

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_structured_view

  @local %DeviceObjectRef{
    device_identifier: nil,
    object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}
  }
  @remote %DeviceObjectRef{
    device_identifier: %ObjectIdentifier{type: :device, instance: 200},
    object_identifier: %ObjectIdentifier{type: :structured_view, instance: 2}
  }
  @uninitialized %DeviceObjectRef{
    device_identifier: nil,
    object_identifier: %ObjectIdentifier{type: :structured_view, instance: 4_194_303}
  }
  @invalid_annotations {:error, {:invalid_configuration, :subordinate_annotations}}

  test "optional annotations must fit the configured array when created or added" do
    assert @invalid_annotations =
             create(%{subordinate_annotations: BACnetArray.from_list(["Fan"])})

    {:ok, view} = create(%{subordinate_list: BACnetArray.from_list([@local])})

    assert @invalid_annotations =
             StructuredView.add_property(view, :subordinate_annotations, BACnetArray.new())

    {:ok, expanded} =
      StructuredView.update_property(
        view,
        :subordinate_list,
        BACnetArray.from_list([@local, @remote])
      )

    refute StructuredView.has_property?(expanded, :subordinate_annotations)

    annotations = BACnetArray.from_list(["Fan", "Other floor"])

    assert {:ok, %{subordinate_annotations: ^annotations}} =
             StructuredView.add_property(expanded, :subordinate_annotations, annotations)
  end

  test "resizing Subordinate_List retains, extends and truncates annotations by index" do
    view = view_with_fan()
    references = BACnetArray.from_list([@local, @remote])
    annotations = BACnetArray.from_list(["Fan", ""])

    assert {:ok, %{subordinate_annotations: ^annotations} = grown} =
             StructuredView.update_property(view, :subordinate_list, references)

    {:ok, references} = BACnetArray.set_item(references, 2, @local)

    assert {:ok, %{subordinate_annotations: ^annotations} = replaced} =
             StructuredView.update_property(grown, :subordinate_list, references)

    assert {:ok, %{subordinate_annotations: %BACnetArray{size: 0}}} =
             StructuredView.update_property(replaced, :subordinate_list, BACnetArray.new())

    assert {:error, {:invalid_property_type, :subordinate_list}} =
             StructuredView.update_property(
               view,
               :subordinate_list,
               BACnetArray.from_list([@local, :invalid])
             )
  end

  test "resizing annotations fills reference slots and enumeration keeps BACnet indices" do
    view = view_with_fan()
    annotations = BACnetArray.from_list(["Fan", "", "Other"])

    {:ok, grown} = StructuredView.update_property(view, :subordinate_annotations, annotations)
    assert {:ok, 3} = BACnetArray.get_item(grown.subordinate_list, 0)
    assert {:ok, @local} = BACnetArray.get_item(grown.subordinate_list, 1)
    assert {:ok, @uninitialized} = BACnetArray.get_item(grown.subordinate_list, 2)
    assert {:ok, @uninitialized} = BACnetArray.get_item(grown.subordinate_list, 3)

    {:ok, references} = BACnetArray.set_item(grown.subordinate_list, 3, @remote)
    {:ok, updated} = StructuredView.update_property(grown, :subordinate_list, references)

    assert {:ok, [{1, @local}, {3, @remote}]} = StructuredView.configured_subordinates(updated)

    assert {:ok, %{subordinate_list: refs}} =
             StructuredView.update_property(
               updated,
               :subordinate_annotations,
               view.subordinate_annotations
             )

    assert refs == view.subordinate_list
  end

  test "subordinate arrays require a value at every index" do
    assert {:error, {:value_failed_property_validation, :subordinate_list}} =
             create(%{subordinate_list: BACnetArray.from_indexed_list([{2, @local}])})

    assert {:error, {:value_failed_property_validation, :subordinate_annotations}} =
             StructuredView.update_property(
               view_with_fan(),
               :subordinate_annotations,
               BACnetArray.from_indexed_list([{2, "Spare"}])
             )
  end

  test "an invalid resize leaves both arrays available for the next valid update" do
    view = view_with_fan()
    invalid = BACnetArray.from_list(["Fan", 42])

    assert {:error, {:invalid_property_type, :subordinate_annotations}} =
             StructuredView.update_property(view, :subordinate_annotations, invalid)

    assert {:ok, original_references} = StructuredView.get_property(view, :subordinate_list)
    assert BACnetArray.to_list(original_references) == [@local]

    assert {:ok, original_annotations} =
             StructuredView.get_property(view, :subordinate_annotations)

    assert BACnetArray.to_list(original_annotations) == ["Fan"]

    valid = BACnetArray.from_list(["Fan", "Spare"])

    assert {:ok, %{subordinate_list: references, subordinate_annotations: ^valid}} =
             StructuredView.update_property(view, :subordinate_annotations, valid)

    assert BACnetArray.to_list(references) == [@local, @uninitialized]
  end

  test "whole subordinate properties round-trip through the array codec" do
    id = StructuredView.get_object_identifier(view_with_fan())

    for {property, values} <- [
          subordinate_list: [@local, @uninitialized, @remote],
          subordinate_annotations: ["Fan", "", "Other floor"]
        ] do
      array = BACnetArray.from_list(values)
      assert {:ok, encodings} = ObjectsUtility.cast_value_to_property(id, property, array)
      assert {:ok, ^array} = ObjectsUtility.cast_property_to_value(id, property, encodings)
    end
  end

  test "the lifecycle checks restored and candidate arrays without scheduling execution" do
    view = view_with_fan()

    assert {:ok, %Result{object: ^view, state: nil, next_execution: nil}} =
             Lifecycle.execute(view, Context.new(:initialization))

    write = Context.new({:property_write, :subordinate_annotations, nil, nil})
    invalid = %{view | subordinate_annotations: BACnetArray.new()}

    assert @invalid_annotations = Lifecycle.execute(invalid, Context.new(:initialization))
    assert @invalid_annotations = Lifecycle.prepare_write(view, invalid, write)

    {:ok, candidate} =
      StructuredView.update_property(
        view,
        :subordinate_annotations,
        BACnetArray.from_list(["Fan", "Reserve"])
      )

    assert {:ok, ^candidate} = Lifecycle.prepare_write(view, candidate, write)

    assert {:ok, %Result{object: ^candidate, next_execution: nil}} =
             Lifecycle.execute(candidate, write)

    assert {:ok, %Result{object: ^candidate, next_execution: nil}} =
             Lifecycle.prepare_read(
               candidate,
               Context.new({:property_read, :subordinate_list, nil})
             )
  end

  test "remote snapshots retain received properties without resizing them" do
    {:ok, snapshot} =
      StructuredView.create(
        10,
        "Remote view",
        %{
          node_type: :floor,
          subordinate_list: BACnetArray.new(),
          subordinate_annotations: BACnetArray.from_list(["Fan"])
        },
        remote_object: 200
      )

    assert {:ok, []} = StructuredView.configured_subordinates(snapshot)

    annotations = BACnetArray.from_list(["Fan", "Pump"])

    assert {:ok,
            %{subordinate_list: %BACnetArray{size: 0}, subordinate_annotations: ^annotations}} =
             StructuredView.update_property(snapshot, :subordinate_annotations, annotations)

    assert {:ok, %Result{object: ^snapshot, next_execution: nil}} =
             Lifecycle.execute(snapshot, Context.new(:initialization))

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(
               snapshot,
               snapshot,
               Context.new({:application_write, :subordinate_annotations, nil, nil})
             )
  end

  defp create(properties) do
    StructuredView.create(10, "Floor", Map.put(properties, :node_type, :floor))
  end

  defp view_with_fan() do
    {:ok, view} =
      create(%{
        subordinate_list: BACnetArray.from_list([@local]),
        subordinate_annotations: BACnetArray.from_list(["Fan"])
      })

    view
  end
end
