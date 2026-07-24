defmodule BACnet.Protocol.FaultParameters.FaultLifeSafety do
  @moduledoc """
  Represents the BACnet fault algorithm `FaultLifeSafety` parameters.

  The FAULT_LIFE_SAFETY fault algorithm detects whether the monitored value equals
  a value that is listed as a fault value.
  The monitored value is of type BACnetLifeSafetyState. If internal operational
  reliability is unreliable, then the internal reliability takes precedence over
  evaluation of the monitored value.

  In addition, this algorithm monitors a life safety mode value. If reliability is
  MULTI_STATE_FAULT, then new transitions to MULTI_STATE_FAULT are indicated upon
  change of the mode value.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.4.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.FaultParameters

  use TypedStruct

  @typedoc """
  Representative type for the fault parameter.
  """
  typedstruct do
    field :mode, DeviceObjectPropertyRef.t(), enforce: true
    field :fault_values, [Constants.life_safety_state()], enforce: true
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 3

  @doc false
  @spec from_app_encoding(ApplicationTags.encoding_list()) ::
          {:ok, t()} | {:error, term()}
  def from_app_encoding([tag]), do: FaultParameters.parse(tag)
  def from_app_encoding(_tags), do: {:error, :invalid_encoding}

  @doc false
  @spec to_app_encoding(t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def to_app_encoding(%__MODULE__{} = param), do: FaultParameters.encode(param)
end
