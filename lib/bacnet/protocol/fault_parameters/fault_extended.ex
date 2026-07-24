defmodule BACnet.Protocol.FaultParameters.FaultExtended do
  @moduledoc """
  Represents the BACnet fault algorithm `FaultExtended` parameters.

  The FAULT_EXTENDED fault algorithm detects fault conditions based on a
  proprietary fault algorithm. The proprietary fault algorithm uses parameters
  and conditions defined by the vendor. The algorithm is identified by a
  vendor-specific fault type that is in the scope of the vendor's
  vendor identification code. The algorithm may, at the vendor's discretion,
  indicate a new reliability, a transition to the same reliability, or
  no transition to the reliability-evaluation process.

  For more specific information about the fault algorithm, consult ASHRAE 135 13.4.3.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.FaultParameters

  use TypedStruct

  @typedoc """
  Representative type for the fault parameter.
  """
  typedstruct do
    field :vendor_id, ApplicationTags.unsigned16(), enforce: true
    field :extended_fault_type, non_neg_integer(), enforce: true
    field :parameters, ApplicationTags.encoding_list(), enforce: true
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 2

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
