defmodule BACnet.Protocol.FaultParameters.FaultState do
  @moduledoc """
  Represents the BACnet fault algorithm `FaultState` parameters.

  The FAULT_STATE fault algorithm detects whether the monitored value
  equals a value that is listed as a fault value. The monitored value
  may be of any discrete or enumerated datatype, including Boolean.
  If internal operational reliability is unreliable, then the
  internal reliability takes precedence over evaluation of the monitored value.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.5.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.FaultParameters
  alias BACnet.Protocol.PropertyState

  use TypedStruct

  @typedoc """
  Representative type for the fault parameter.
  """
  typedstruct do
    field :fault_values, [PropertyState.t()], enforce: true
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 4

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
