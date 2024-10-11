defmodule BACnet.Protocol.ObjectTypes.Group do
  @moduledoc """
  The Group object type defines a standardized object whose properties
  represent a collection of other objects and one or more of their properties.
  A group object is used to simplify the exchange of information between
  BACnet Devices by providing a shorthand way to specify all members of the
  group at once. A group may be formed using any combination of object types.

  (ASHRAE 135 - Clause 12.14)
  """

  # TODO: Docs

  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ReadAccessResult

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Group object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  The device server needs to verify that each group member resides in the same device.
  """
  bac_object Constants.macro_assert_name(:object_type, :group) do
    services(intrinsic: false)

    field(:description, String.t())

    field(:list_of_group_members, [AccessSpecification.t()],
      required: true,
      default: [],
      validator_fun: fn list ->
        Enum.all?(list, fn %AccessSpecification{} = member ->
          # May not be a Group or Global Group object and reference the present value property
          !((member.object_identifier.type == Constants.macro_assert_name(:object_type, :group) or
               member.object_identifier.type ==
                 Constants.macro_assert_name(:object_type, :global_group)) and
              Enum.any?(member.properties, fn
                :all ->
                  true

                :required ->
                  true

                %AccessSpecification.Property{} = property ->
                  property.property_identifier ==
                    Constants.macro_assert_name(:property_identifier, :present_value)

                _else ->
                  false
              end))
        end)
      end
    )

    field(:present_value, [ReadAccessResult.t()], required: true, readonly: true, default: [])
    field(:profile_name, String.t())
  end
end
