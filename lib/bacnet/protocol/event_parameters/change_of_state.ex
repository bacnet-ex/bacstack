defmodule BACnet.Protocol.EventParameters.ChangeOfState do
  @moduledoc """
  Represents the BACnet event algorithm `ChangeOfState` parameters.

  The ChangeOfState event algorithm detects whether the monitored value equals a value that is listed as an alarm
  value. The monitored value may be of any discrete or enumerated datatype, including Boolean.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.2.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.PropertyState

  use TypedStruct

  @typedoc """
  Representative type for the event parameter.
  """
  typedstruct do
    field :alarm_values, [PropertyState.t()], enforce: true
    field :time_delay, non_neg_integer(), enforce: true
    field :time_delay_normal, non_neg_integer()
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 1

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
