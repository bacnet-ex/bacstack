defmodule BACnet.Protocol.ObjectTypes.MultistateOutput do
  @moduledoc """
  The Multi-state Output object type defines a standardized object whose properties
  represent the desired state of one or more physical outputs or processes within
  the BACnet Device in which the object resides.

  The actual functions associated with a specific state are a local matter and not
  specified by the protocol. For example, a particular state may represent the
  active/inactive condition of several physical outputs or perhaps the value of an
  analog output. The Present_Value property is an unsigned integer number representing
  the state. The State_Text property associates a description with each state.

  Multi-state Output objects that support intrinsic reporting shall apply the COMMAND_FAILURE event algorithm.

  (ASHRAE 135 - Clause 12.19)
  """

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Multistate Output object.
  """
  @type object_opts ::
          {:auto_write_feedback, boolean()}
          | {:intrinsic_reporting, boolean()}
          | common_object_opts()

  @typedoc """
  Represents an Multistate Output object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.

  To get the physical state, call `get_output/2` and the function gets the present value in respect
  to the out of service state.
  """
  bac_object Constants.macro_assert_name(:object_type, :multi_state_output) do
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

    field(:priority_array, PriorityArray.t(pos_integer()), required: true, readonly: true)

    field(:relinquish_default, pos_integer(),
      required: true,
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
    field(:feedback_value, pos_integer(), intrinsic: true, default: 1)
  end

  @doc """
  Get the logical state of the object from the present value property.

  If the object is out of service, then the `decoupled_output_state` is returned.
  The specification specifies that when the object is out of service, then the physical output
  is decoupled from the BACnet present value. The actual physical output state can then either
  hold its last value, go to a safe state or behaves according to local logic (-> defined as local matter).
  The default value is `1` - the safe state of physical outputs in typical environments.
  """
  @spec get_output(t(), pos_integer()) :: boolean()
  def get_output(%__MODULE__{} = object, decoupled_output_state \\ 1)
      when is_integer(decoupled_output_state) and decoupled_output_state >= 1 do
    if object.out_of_service do
      decoupled_output_state
    else
      object.present_value
    end
  end
end
