defmodule BACnet.Protocol.EventParameters.ChangeOfLifeSafety do
  @moduledoc """
  Represents the BACnet event algorithm `ChangeOfLifeSafety` parameters.

  The ChangeOfLifeSafety event algorithm detects whether the monitored value equals a value that is listed as an
  alarm value or life safety alarm value. Event state transitions are also indicated if the value of the mode parameter changed
  since the last transition indicated. In this case, any time delays are overridden and the transition is indicated immediately.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.8.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventParameters

  use TypedStruct

  @typedoc """
  Representative type for the event parameter.
  """
  typedstruct do
    field :mode, DeviceObjectPropertyRef.t(), enforce: true
    field :alarm_values, [Constants.life_safety_state()], enforce: true

    field :life_safety_alarm_values, [Constants.life_safety_state()], enforce: true

    field :time_delay, non_neg_integer(), enforce: true
    field :time_delay_normal, non_neg_integer()
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 8

  @doc false
  @spec from_app_encoding(ApplicationTags.encoding_list()) ::
          {:ok, t()} | {:error, term()}
  def from_app_encoding([tag]), do: EventParameters.parse(tag)
  def from_app_encoding(_tags), do: {:error, :invalid_encoding}

  @doc false
  @spec to_app_encoding(t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def to_app_encoding(%__MODULE__{} = param), do: EventParameters.encode(param)
end
