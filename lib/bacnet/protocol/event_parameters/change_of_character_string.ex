defmodule BACnet.Protocol.EventParameters.ChangeOfCharacterString do
  @moduledoc """
  Represents the BACnet event algorithm `ChangeOfCharacterString` parameters.

  The ChangeOfCharacterString event algorithm detects whether the monitored value matches a character string
  that is listed as an alarm value. Alarm values are of type BACnetOptionalCharacterString, and may also be NULL or an
  empty character string.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.16.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.EventParameters

  use TypedStruct

  @typedoc """
  Representative type for the event parameter.
  """
  typedstruct do
    field :alarm_values, [String.t() | nil], enforce: true
    field :time_delay, non_neg_integer(), enforce: true
    field :time_delay_normal, non_neg_integer()
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 17

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
