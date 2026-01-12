defmodule BACnet.Protocol.ObjectTypes.MultistateValue do
  @moduledoc """
  The Multi-state Value object type defines a standardized object whose properties
  represent the externally visible characteristics of a multi-state value.
  A "multi-state value" is a control system parameter residing in the memory of the
  BACnet Device. The actual functions associated with a specific state are a
  local matter and not specified by the protocol. For example, a particular state may
  represent the active/inactive condition of several physical inputs and outputs or
  perhaps the value of an analog input or output.
  The Present_Value property is an unsigned integer number representing the state.
  The State_Text property associates a description with each state.

  Multi-state Value objects that support intrinsic reporting shall apply the CHANGE_OF_ STATE event algorithm.
  For reliability-evaluation, the FAULT_STATE fault algorithm can be applied.

  (ASHRAE 135 - Clause 12.20)
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
  Represents an Multistate Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected,
  unless out of service is active. For the duration of out of service, updates to the present value
  using `update_property/3` are allowed. Once out of service is disabled, the present value is once
  again protected from updates, as the present value is updated through the relinquish_default and
  priority_array properties.
  """
  bac_object Constants.macro_assert_name(:object_type, :multi_state_value) do
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

    field(:priority_array, PriorityArray.t(pos_integer()), readonly: true)

    field(:relinquish_default, pos_integer(),
      validator_fun: &(&1 <= (&2[:number_of_states] || -1)),
      default: 1
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
