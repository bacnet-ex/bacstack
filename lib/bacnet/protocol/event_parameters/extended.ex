defmodule BACnet.Protocol.EventParameters.Extended do
  @moduledoc """
  Represents the BACnet event algorithm `Extended` parameters.

  The Extended event algorithm detects event conditions based on a proprietary event algorithm. The proprietary event
  algorithm uses parameters and conditions defined by the vendor. The algorithm is identified by a vendor-specific event type
  that is in the scope of the vendor's vendor identification code. The algorithm may, at the vendor's discretion, indicate a new
  event state, a transition to the same event state, or no transition to the Event-State-Detection. The indicated new event states
  may be NORMAL, and any OffNormal event state. FAULT event state may not be indicated by this algorithm. For the
  purpose of proprietary evaluation of unreliability conditions that may result in FAULT event state, a FAULT_EXTENDED
  fault algorithm shall be used.

  For more specific information about the event algorithm, consult ASHRAE 135 13.3.10.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.EventParameters

  use TypedStruct

  @typedoc """
  Representative type for the event parameter.
  """
  typedstruct do
    field :vendor_id, ApplicationTags.unsigned16(), enforce: true
    field :extended_event_type, non_neg_integer(), enforce: true
    field :parameters, ApplicationTags.encoding_list(), enforce: true
  end

  @doc false
  @spec get_tag_number() :: non_neg_integer()
  def get_tag_number(), do: 9

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
