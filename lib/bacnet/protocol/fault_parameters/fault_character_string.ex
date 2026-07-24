defmodule BACnet.Protocol.FaultParameters.FaultCharacterString do
  @moduledoc """
  Represents the BACnet fault algorithm `FaultCharacterString` parameters.

  The FAULT_CHRACTERSTRING fault algorithm detects whether the monitored value matches a
  character string that is listed as a fault value. Fault values are of type
  BACnetOptionalCharacterString and may also be NULL or an empty character string.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.2.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.FaultParameters

  use TypedStruct

  @typedoc """
  Representative type for the fault parameter.
  """
  typedstruct do
    field :fault_values, [String.t()], enforce: true
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 1

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
