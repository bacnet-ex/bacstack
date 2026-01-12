defmodule BACnet.Protocol.ObjectTypes.BitstringValue do
  @moduledoc """
  The Bitstring Value object type defines a standardized object whose properties
  represent the externally visible characteristics of a named data value
  in a BACnet device. A BACnet device can use a Bitstring Value object to make
  any kind of bitstring data value accessible to other BACnet devices.
  The mechanisms by which the value is derived are not visible to the BACnet
  client.

  Bitstring Value objects that support intrinsic reporting shall apply
  the CHANGE_OF_BITSTRING event algorithm.

  (ASHRAE 135 - Clause 12.40)
  """

  # TODO: Docs

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Bitstring Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected,
  unless out of service is active. For the duration of out of service, updates to the present value
  using `update_property/3` are allowed. Once out of service is disabled, the present value is once
  again protected from updates, as the present value is updated through the relinquish_default and
  priority_array properties.
  """
  bac_object Constants.macro_assert_name(:object_type, :bitstring_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, tuple(),
      required: true,
      validator_fun: fn val ->
        is_tuple(val) and
          val
          |> Tuple.to_list()
          |> Enum.all?(&is_boolean/1)
      end
    )

    field(:priority_array, PriorityArray.t(tuple()), readonly: true)

    field(:relinquish_default, tuple(),
      validator_fun: fn val ->
        is_tuple(val) and
          val
          |> Tuple.to_list()
          |> Enum.all?(&is_boolean/1)
      end
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:bit_text, BACnetArray.t(String.t()),
      default: BACnetArray.new(),
      validator_fun: &(BACnetArray.size(&1) == tuple_size(&2[:present_value]))
    )

    field(:profile_name, String.t())

    # Intrinsic Reporting
    field(:alarm_values, [tuple()],
      intrinsic: true,
      default: [],
      validator_fun: fn list ->
        Enum.all?(list, fn val ->
          is_tuple(val) and
            val
            |> Tuple.to_list()
            |> Enum.all?(&is_boolean/1)
        end)
      end
    )

    field(:bit_mask, tuple(), intrinsic: true)
    field(:event_state, Constants.event_state(), intrinsic: true)
  end
end
