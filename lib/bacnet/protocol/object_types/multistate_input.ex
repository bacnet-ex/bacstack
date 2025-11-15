defmodule BACnet.Protocol.ObjectTypes.MultistateInput do
  @moduledoc """
  The Multi-state Input object type defines a standardized object whose Present_Value
  represents the result of an algorithmic process within the BACnet Device in which
  the object resides.

  The algorithmic process itself is a local matter and is not defined by the protocol.
  For example, the Present_Value or state of the Multi-state Input object may be the
  result of a logical combination of multiple binary inputs or the threshold of one or
  more analog inputs or the result of a mathematical computation.
  The Present_Value property is an integer number representing the state.
  The State_Text property associates a description with each state.

  Multi-state Input objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.
  For reliability-evaluation, the FAULT_STATE fault algorithm can be applied.

  (ASHRAE 135 - Clause 12.18)
  """

  # TODO: Docs

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Multistate Input object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.
  """
  bac_object Constants.macro_assert_name(:object_type, :multi_state_input) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, pos_integer(),
      required: true,
      default: 1,
      validator_fun: &(&1 <= (&2[:number_of_states] || -1))
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:fault_values, [non_neg_integer()],
      default: [],
      implicit_relationship: :reliability
    )

    field(:number_of_states, pos_integer(), required: true, readonly: true, default: 1)

    field(:state_text, BACnetArray.t(String.t(), pos_integer()),
      validator_fun: &(BACnetArray.size(&1) == (&2[:number_of_states] || -1))
    )

    field(:profile_name, String.t())

    # Intrinsic Reporting
    field(:alarm_values, [non_neg_integer()], intrinsic: true, default: [])
  end
end
