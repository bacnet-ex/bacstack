defmodule BACnet.Protocol.EventParameters.ChangeOfStatusFlags do
  @moduledoc """
  Represents the BACnet event algorithm `ChangeOfStatusFlags` parameters.

  The ChangeOfStatusFlags event algorithm detects whether a significant flag of the monitored value of type
  BACnetStatusFlags has the value TRUE.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.11.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.StatusFlags

  use TypedStruct

  @typedoc """
  Representative type for the event parameter.
  """
  typedstruct do
    field :selected_flags, StatusFlags.t(), enforce: true
    field :time_delay, non_neg_integer(), enforce: true
    field :time_delay_normal, non_neg_integer()
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 18

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
