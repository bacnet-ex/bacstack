defmodule BACnet.Protocol.FaultParameters.None do
  @moduledoc """
  Represents the BACnet fault algorithm `None` parameters.

  The NONE fault algorithm is a placeholder for the case where no fault algorithm is applied by the object.
  This fault algorithm has no parameters, no conditions, and does not indicate any transitions of reliability.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.1.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.FaultParameters

  @typedoc """
  Representative type for the fault parameter.
  """
  @type t :: %__MODULE__{}

  defstruct []

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 0

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
