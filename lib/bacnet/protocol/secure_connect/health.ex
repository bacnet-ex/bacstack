defmodule BACnet.Protocol.SecureConnect.Health do
  @moduledoc """
  A timestamped BACnet Network Port health or validation result.

  The result includes a BACnet error class and code. When a particular
  property caused a validation failure, the record can identify that
  property and provide optional details.

  The managed SC port uses this sequence for Current_Health and
  Command_Validation_Result.
  Its encoder and parser preserve the optional context tags defined by
  Addendum cc.
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError

  @typedoc """
  The timestamp, result, and optional property and details of a health observation.
  """
  @type t :: %__MODULE__{
          timestamp: BACnetDateTime.t(),
          result: BACnetError.t(),
          property: BACnet.Protocol.Constants.property_identifier() | nil,
          details: String.t() | nil
        }

  @fields [:timestamp, :result, :property, :details]
  @enforce_keys @fields
  defstruct @fields

  use BACnet.Protocol.SecureConnect.Sequence,
    fields: [
      timestamp: BACnetDateTime,
      result: BACnetError,
      property: {:optional, :property_identifier},
      details: {:optional, :character_string}
    ]
end
