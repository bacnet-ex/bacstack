defmodule BACnet.Protocol.EventParameters.BufferReady do
  @moduledoc """
  Represents the BACnet event algorithm `BufferReady` parameters.

  The BufferReady event algorithm detects whether a defined number of records have been added to a log buffer since
  start of operation or the previous event, whichever is most recent.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.7.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.EventParameters

  use TypedStruct

  @typedoc """
  Representative type for the event parameter.
  """
  typedstruct do
    field :threshold, non_neg_integer(), enforce: true
    field :previous_count, ApplicationTags.unsigned32(), enforce: true
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 10

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
