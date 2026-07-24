defmodule BACnet.Protocol.EventParameters.OutOfRange do
  @moduledoc """
  Represents the BACnet event algorithm `OutOfRange` parameters.

  The OutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high limit and a
  low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no higher limit or no lower limit.
  In order to reduce jitter of the resulting event state, a deadband is applied when the value is in the process of returning to the
  normal range.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.6.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.EventParameters

  use TypedStruct

  @typedoc """
  Representative type for the event parameter.
  """
  typedstruct do
    field :low_limit, float(), enforce: true
    field :high_limit, float(), enforce: true
    field :deadband, float(), enforce: true
    field :time_delay, non_neg_integer(), enforce: true
    field :time_delay_normal, non_neg_integer()
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 5

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
