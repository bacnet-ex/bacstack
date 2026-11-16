defmodule BACnet.Protocol.SecureConnect.HubConnection do
  @moduledoc """
  Status of a node’s configured connection to a primary or failover hub.

  A connection record includes its state, the last connection and disconnection
  timestamps, and an optional error. An unspecified timestamp represents an event
  that has yet to occur.

  The SC Network Port uses separate properties for the primary and failover
  records. Their wire format is the same Addendum cc sequence.
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError

  @typedoc """
  A single hub connector status record, including its state and optional error.
  """
  @type t :: %__MODULE__{
          state: 0..3,
          connected_at: BACnetDateTime.t(),
          disconnected_at: BACnetDateTime.t(),
          error: BACnetError.t() | nil,
          details: String.t() | nil
        }

  @fields [:state, :connected_at, :disconnected_at, :error, :details]
  @enforce_keys @fields
  defstruct @fields

  use BACnet.Protocol.SecureConnect.Sequence,
    fields: [
      state: :enumerated,
      connected_at: BACnetDateTime,
      disconnected_at: BACnetDateTime,
      error: {:optional, BACnetError},
      details: {:optional, :character_string}
    ]
end
