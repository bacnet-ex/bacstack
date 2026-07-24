defmodule BACnet.Protocol.EventParameters.ChangeOfValue do
  @moduledoc """
  Represents the BACnet event algorithm `ChangeOfValue` parameters.

  The ChangeOfValue event algorithm, for monitored values of datatype REAL, detects whether the absolute value of
  the monitored value changes by an amount equal to or greater than a positive REAL increment.

  The ChangeOfValue event algorithm, for monitored values of datatype BIT STRING, detects whether the monitored
  value changes in any of the bits specified by a bitmask.

  For detection of change, the value of the monitored value when a transition to NORMAL is indicated shall be used in
  evaluation of the conditions until the next transition to NORMAL is indicated. The initialization of the value used in
  evaluation before the first transition to NORMAL is indicated is a local matter.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.3.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.EventParameters

  use TypedStruct

  @typedoc """
  Representative type for the event parameter.
  """
  typedstruct do
    field :increment, float()
    field :bitmask, tuple()
    field :time_delay, non_neg_integer(), enforce: true
    field :time_delay_normal, non_neg_integer()
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 2

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
