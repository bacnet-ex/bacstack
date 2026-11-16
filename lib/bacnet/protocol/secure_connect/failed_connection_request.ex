defmodule BACnet.Protocol.SecureConnect.FailedConnectionRequest do
  @moduledoc """
  An unsuccessful connection attempt received by a BACnet/SC hub.

  The record includes the remote TCP address, the time of the failure, and
  the reported BACnet error. The VMAC and Device UUID are optional because
  the connection can end before the peer supplies them.

  The hub exposes recent records through the Network Port’s failed
  connection requests property using the sequence defined by Addendum cc.
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.HostNPort

  @typedoc """
  An inbound failure with its timestamp, remote address, and known peer identity.
  """
  @type t :: %__MODULE__{
          timestamp: BACnetDateTime.t(),
          address: HostNPort.t(),
          vmac: binary() | nil,
          uuid: binary() | nil,
          error: BACnetError.t(),
          details: String.t() | nil
        }

  @fields [:timestamp, :address, :vmac, :uuid, :error, :details]
  @enforce_keys @fields
  defstruct @fields

  use BACnet.Protocol.SecureConnect.Sequence,
    fields: [
      timestamp: BACnetDateTime,
      address: HostNPort,
      vmac: {:optional, :octet_string},
      uuid: {:optional, :octet_string},
      error: BACnetError,
      details: {:optional, :character_string}
    ]
end
