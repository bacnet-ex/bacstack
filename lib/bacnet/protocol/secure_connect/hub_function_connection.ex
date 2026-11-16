defmodule BACnet.Protocol.SecureConnect.HubFunctionConnection do
  @moduledoc """
  A peer session accepted by a BACnet/SC hub.

  The record identifies the peer by its TCP address, VMAC, and Device UUID.
  It also carries connection timestamps and, when available, the error that
  ended a session.

  The SC Network Port reports these records in its hub function connection
  status list using the sequence defined by Addendum cc.
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.HostNPort

  @typedoc """
  The address, identity, connection state, and timestamps of one accepted peer.
  """
  @type t :: %__MODULE__{
          state: 0..2,
          connected_at: BACnetDateTime.t(),
          disconnected_at: BACnetDateTime.t(),
          address: HostNPort.t(),
          vmac: binary(),
          uuid: binary(),
          error: BACnetError.t() | nil,
          details: String.t() | nil
        }

  @fields [:state, :connected_at, :disconnected_at, :address, :vmac, :uuid, :error, :details]
  @enforce_keys @fields
  defstruct @fields

  use BACnet.Protocol.SecureConnect.Sequence,
    fields: [
      state: :enumerated,
      connected_at: BACnetDateTime,
      disconnected_at: BACnetDateTime,
      address: HostNPort,
      vmac: :octet_string,
      uuid: :octet_string,
      error: {:optional, BACnetError},
      details: {:optional, :character_string}
    ]
end
