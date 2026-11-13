defmodule BACnet.Protocol.ObjectTypes.StructuredView do
  @moduledoc """
  A Structured View organizes object references into a hierarchy that clients
  can browse, such as floor, air handler and supply temperature. The
  `node_type` and `node_subtype` describe the kind of node. The
  `subordinate_list` holds references to its children, which can themselves
  be Structured Views.

  The structure is completely independent of the flat `object_list` in the Device
  object - it is an additional navigation aid. Views can represent physical hierarchy,
  functional systems, graphics pages, or any other grouping the implementer desires.

  ### Object Description (ASHRAE 135)

  > The Structured View object type defines a standardized object that provides
  > a container to hold references to subordinate objects, which may include other
  > Structured View objects, thereby allowing multilevel hierarchies to be created.

  ### Behaviour and Operation

  Structured View objects are passive organisational containers. They do not
  contain or duplicate data from the referenced objects - each entry in
  `subordinate_list` is a reference.

  The device or a configuration tool populates the tree.
  Clients use the view for navigation, graphics binding, or
  hierarchical browsing instead of (or in addition to) the flat `object_list` on
  the Device object. The view may reference objects that are not in the device's
  own object list (for proxy / remote views).

  ### Subordinate list and annotations

  Subordinate_List and Subordinate_Annotations are `BACnet.Protocol.BACnetArray`
  properties. When annotations are present, each annotation describes the
  subordinate at the same one-based index. Provide arrays of equal size when
  creating a local object or adding annotations. Each array needs a value
  at every index.

  `update_property/3` resizes the other array when either array changes size,
  as required by ASHRAE 135-2012 Clauses 12.29.7 and 12.29.8. It keeps entries
  at retained positions and discards entries beyond the new end. Growing the
  annotation array adds empty strings. Growing the subordinate array adds
  uninitialized references with object instance 4194303. Use
  `configured_subordinates/1` to skip those references while retaining the
  original one-based BACnet array indices for annotation lookup.

  ### Lifecycle and host contract

  Initialize or validate a restored view with
  `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2`. It checks that both
  arrays have the same size when annotations are present. A view needs no
  runtime state, host I/O or wakeup. It has no commandability or event generation.
  Remote snapshots retain the property values received from the device.

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  needs to enforce write permissions and BACnet array indices. For an accepted
  element write, the host needs to replace the element with
  `BACnet.Protocol.BACnetArray.set_item/3` and submit the resulting array through
  `update_property/3`. Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`
  to check the candidate and retain the whole object on success so both arrays
  are visible together.

  ### Developer Implementation Notes

  The application decides which objects belong in each view and updates the
  references when the hierarchy changes. For example, if a deleted object
  should disappear from the hierarchy, update each view that references it.
  Resizing preserves annotations by array index. If the application moves
  references to different indices, it needs to move their annotations too.

  A BACnet client can edit the hierarchy when the host exposes the relevant
  properties as writable and accepts the writes. The host can use
  `property_writable?/2` when checking write access.

  A client browsing the hierarchy can start at a root view and follow its
  configured references. A reference without a device identifier points to
  an object on the same device as the view. A device-qualified reference can
  point to an object on another device.

  #### Typical uses

  - Physical hierarchies such as site, building, floor, room, and equipment.
  - Functional systems such as a chilled water system with pumps, valves, and
    sensors spread across several controllers.
  - Graphics pages that group the points needed for each display.
  - Proxy views that group references to objects on another device.

  ### Examples

  Create an empty Structured View.

      iex> alias BACnet.Protocol.BACnetArray
      iex> alias BACnet.Protocol.ObjectTypes.StructuredView
      iex> {:ok, view} = StructuredView.create(1700, "BuildingView", %{node_type: :device})
      iex> BACnetArray.get_item(view.subordinate_list, 0)
      {:ok, 0}

  Add a second annotation to reserve a subordinate slot. The new slot has
  instance `4194303`, so only the fan appears among configured subordinates.
  Shrinking Subordinate_List back to one entry removes the spare annotation.

      iex> alias BACnet.Protocol.{BACnetArray, DeviceObjectRef, ObjectIdentifier}
      iex> alias BACnet.Protocol.ObjectTypes.StructuredView
      iex> fan = %DeviceObjectRef{
      ...>   device_identifier: nil,
      ...>   object_identifier: %ObjectIdentifier{type: :binary_output, instance: 8}
      ...> }
      iex> references = BACnetArray.from_list([fan])
      iex> {:ok, view} = StructuredView.create(10, "Ventilation", %{
      ...>   node_type: :equipment,
      ...>   subordinate_list: references,
      ...>   subordinate_annotations: BACnetArray.from_list(["Supply fan"])
      ...> })
      iex> annotations = BACnetArray.from_list(["Supply fan", "Spare"])
      iex> {:ok, grown} = StructuredView.update_property(view, :subordinate_annotations, annotations)
      iex> BACnetArray.get_item(grown.subordinate_list, 0)
      {:ok, 2}
      iex> {:ok, spare} = BACnetArray.get_item(grown.subordinate_list, 2)
      iex> spare.object_identifier.instance
      4194303
      iex> {:ok, configured} = StructuredView.configured_subordinates(grown)
      iex> configured == [{1, fan}]
      true
      iex> {:ok, shortened} = StructuredView.update_property(grown, :subordinate_list, references)
      iex> BACnetArray.to_list(shortened.subordinate_annotations)
      ["Supply fan"]

  <!--### See Also
  - *Nothing to see here*-->
  """

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @uninitialized_instance Constants.macro_by_name(:asn1, :max_instance_and_property_id)
  @uninitialized_subordinate %DeviceObjectRef{
    device_identifier: nil,
    object_identifier: %ObjectIdentifier{
      type: :structured_view,
      instance: @uninitialized_instance
    }
  }

  @typedoc """
  Options accepted when creating or configuring a Structured View object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Structured View object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.
  """
  bac_object Constants.macro_assert_name(:object_type, :structured_view) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:node_type, Constants.node_type(), required: true)
    field(:node_subtype, String.t())

    field(:subordinate_list, BACnetArray.t(DeviceObjectRef.t()),
      required: true,
      default: BACnetArray.new(),
      validator_fun: &dense_array?/1
    )

    field(:subordinate_annotations, BACnetArray.t(String.t()), validator_fun: &dense_array?/1)
  end

  @doc """
  Returns configured subordinate references in order, with their one-based
  BACnet array indices. References with object instance 4194303 are skipped.
  Returns a property error if Subordinate_List is unavailable on a snapshot.
  """
  @doc group: "Functions Operational"
  @spec configured_subordinates(t()) ::
          {:ok, [{array_index :: pos_integer(), reference :: DeviceObjectRef.t()}]}
          | property_update_error()
  def configured_subordinates(%__MODULE__{} = object) do
    with {:ok, references} <- get_property(object, :subordinate_list) do
      configured =
        for {%DeviceObjectRef{object_identifier: %ObjectIdentifier{instance: instance}} = ref,
             index} <- Enum.with_index(BACnetArray.to_list(references), 1),
            instance != @uninitialized_instance do
          {index, ref}
        end

      {:ok, configured}
    end
  end

  @doc """
  Checks that the subordinate array and any selected annotations have matching
  sizes on a local view. Remote snapshots are accepted as received.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | property_update_error()
  def validate_execution(%__MODULE__{} = object, %Context{}) do
    validate_subordinate_arrays(object)
  end

  @spec inhibit_object_check(
          t(),
          t() | nil,
          ObjectOperations.property_operation(),
          ObjectOperations.property_operation_args()
        ) :: {:ok, t()} | property_update_error()
  defp inhibit_object_check(candidate, original, operation, args) do
    candidate =
      case {original, operation, args} do
        {%__MODULE__{_metadata: %{remote_object: nil}} = original, :update, %{property: property}}
        when property in [:subordinate_list, :subordinate_annotations] ->
          resize_related_property(candidate, property, Map.fetch!(original, property))

        _other ->
          candidate
      end

    with :ok <- validate_subordinate_arrays(candidate) do
      {:ok, candidate}
    end
  end

  @spec validate_subordinate_arrays(t()) :: :ok | property_update_error()
  defp validate_subordinate_arrays(object)

  defp validate_subordinate_arrays(%__MODULE__{_metadata: %{remote_object: remote}})
       when not is_nil(remote), do: :ok

  defp validate_subordinate_arrays(%__MODULE__{subordinate_annotations: nil}), do: :ok

  defp validate_subordinate_arrays(%__MODULE__{
         subordinate_list: %BACnetArray{size: size},
         subordinate_annotations: %BACnetArray{size: size}
       }),
       do: :ok

  defp validate_subordinate_arrays(%__MODULE__{}),
    do: {:error, {:invalid_configuration, :subordinate_annotations}}

  @spec resize_related_property(t(), Constants.property_identifier(), term()) :: t()
  defp resize_related_property(candidate, property, previous)

  defp resize_related_property(
         %__MODULE__{
           subordinate_list: %BACnetArray{size: size},
           subordinate_annotations: %BACnetArray{} = annotations
         } = candidate,
         :subordinate_list,
         %BACnetArray{size: old_size}
       )
       when size != old_size do
    %{candidate | subordinate_annotations: resize(annotations, size, "")}
  end

  defp resize_related_property(
         %__MODULE__{
           subordinate_list: %BACnetArray{} = references,
           subordinate_annotations: %BACnetArray{size: size}
         } = candidate,
         :subordinate_annotations,
         %BACnetArray{size: old_size}
       )
       when size != old_size do
    %{candidate | subordinate_list: resize(references, size, @uninitialized_subordinate)}
  end

  defp resize_related_property(candidate, _property, _previous), do: candidate

  @spec dense_array?(BACnetArray.t()) :: boolean()
  defp dense_array?(array) do
    length(BACnetArray.to_list(array)) == BACnetArray.size(array)
  end

  @spec resize(BACnetArray.t(item), non_neg_integer(), item) :: BACnetArray.t(item) when item: var
  defp resize(array, size, fill) do
    values = Enum.take(BACnetArray.to_list(array), size)
    added = List.duplicate(fill, max(size - BACnetArray.size(array), 0))
    BACnetArray.from_list(values ++ added, BACnetArray.fixed_size?(array))
  end
end
