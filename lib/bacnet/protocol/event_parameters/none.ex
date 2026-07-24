defmodule BACnet.Protocol.EventParameters.None do
  @moduledoc """
  Represents the BACnet event algorithm `None` parameters.

  This event algorithm has no parameters, no conditions, and does not indicate
  any transitions of event state. The NONE algorithm is used when only fault detection
  is in use by an object.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.17.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.EventParameters

  @typedoc """
  Representative type for the event parameter.
  """
  @type t :: %__MODULE__{}

  defstruct []

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 20

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
