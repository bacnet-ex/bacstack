defmodule BACnet.Protocol.FaultParameters.FaultStatusFlags do
  @moduledoc """
  Represents the BACnet fault algorithm `FaultStatusFlags` parameters.

  The FAULT_STATUS_FLAGS fault algorithm detects whether the monitored
  status flags are indicating a fault condition.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.6.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.FaultParameters

  use TypedStruct

  @typedoc """
  Representative type for the fault parameter.
  """
  typedstruct do
    field :status_flags, DeviceObjectPropertyRef.t(), enforce: true
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 5

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
