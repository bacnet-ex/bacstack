defmodule BACnet.Stack.SegmentationEndpoint do
  @moduledoc """
  Identifies a remote endpoint for segmented transfers on a particular transport portal.

  Both segmentation components use this identity together with the local transaction role
  (`:requester` or `:responder`) and invoke ID. The transport
  module and portal distinguish local links; `address` identifies the transport peer and
  `npci` contains the complete routed network/address pair, when present.

  Construct the endpoint with the same transport send options used to create the sequence.
  For incoming traffic, pass the NPCI source as the `:destination` option. For a forwarded
  BACnet/IP NPDU, use its originating IP/port as the peer address, as replies go to that peer.
  Device object instance numbers are not part of this routing identity.

  Roles belong to sequence keys, so the same endpoint can participate in both roles concurrently.
  """

  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.IncompleteAPDU
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Stack.TransportBehaviour

  @typedoc """
  Represents a segmentation endpoint, used to identify segmented transfers.
  """
  @type t :: %__MODULE__{
          transport_module: module(),
          portal: TransportBehaviour.portal(),
          address: term(),
          npci: NpciTarget.t() | nil
        }

  @enforce_keys [:transport_module, :portal, :address, :npci]
  defstruct @enforce_keys

  @typedoc """
  The local device's role in a confirmed transaction.
  """
  @type role :: :requester | :responder

  @typedoc """
  Identity of a segmented transfer, including its local transaction role.
  """
  @type sequence_key :: {t(), role(), byte()}

  @doc """
  Builds an endpoint using the effective NPCI destination from the transport send options.

  An explicit `:npci` overrides `:destination`, including an explicit NPCI without a
  destination or `npci: false`. With no NPCI override, `:destination` supplies the target.
  """
  @spec new(module(), TransportBehaviour.portal(), term(), Keyword.t()) :: t()
  def new(transport_module, portal, address, opts \\ []) do
    target =
      case Keyword.get(opts, :npci) do
        %NPCI{destination: target} -> target
        nil -> Keyword.get(opts, :destination)
        false -> nil
      end

    %__MODULE__{
      transport_module: transport_module,
      portal: portal,
      address: address,
      npci: target
    }
  end

  @doc false
  @spec sequence_key(map(), t() | term(), byte(), role() | nil) :: sequence_key() | nil
  def sequence_key(sequences, endpoint, invoke_id, role \\ nil)

  def sequence_key(_sequences, %__MODULE__{} = endpoint, invoke_id, role)
      when role in [:requester, :responder],
      do: {endpoint, role, invoke_id}

  # Compatibility calls must identify one endpoint and role; never choose arbitrarily
  def sequence_key(sequences, peer, invoke_id, role) do
    case Enum.take(
           Stream.filter(Map.keys(sequences), fn
             {%__MODULE__{address: address} = endpoint, key_role, ^invoke_id} ->
               (peer == endpoint or peer == address) and (is_nil(role) or role == key_role)

             _other ->
               false
           end),
           2
         ) do
      [key] -> key
      _other -> nil
    end
  end

  @doc """
  Determines the local transaction role for a received APDU or reassembly fragment.

  Returns `:requester` when the local device initiated the confirmed transaction,
  or `:responder` when the peer initiated it.

  | Received data                                            | Flag                    | Local role   |
  |----------------------------------------------------------|-------------------------|--------------|
  | `IncompleteAPDU` containing a confirmed-request fragment | `server: true`          | `:responder` |
  | `IncompleteAPDU` containing a ComplexACK fragment        | `server: false`         | `:requester` |
  | Abort or SegmentACK from the remote server               | `sent_by_server: true`  | `:requester` |
  | Abort or SegmentACK from the remote client               | `sent_by_server: false` | `:responder` |
  | Error, Reject, or SimpleACK                              | No server flag          | `:requester` |

  `IncompleteAPDU.server` describes the local receiving role. In contrast,
  `sent_by_server` on Abort and SegmentACK describes the remote sender's role,
  so the local role is the opposite. Error, Reject, and SimpleACK are always
  responses to a locally initiated request.
  """
  @spec incoming_role(
          IncompleteAPDU.t()
          | APDU.Abort.t()
          | APDU.SegmentACK.t()
          | APDU.Error.t()
          | APDU.Reject.t()
          | APDU.SimpleACK.t()
        ) :: role()
  def incoming_role(%IncompleteAPDU{server: true}), do: :responder
  def incoming_role(%IncompleteAPDU{server: false}), do: :requester

  def incoming_role(%type{sent_by_server: true}) when type in [APDU.Abort, APDU.SegmentACK],
    do: :requester

  def incoming_role(%type{sent_by_server: false}) when type in [APDU.Abort, APDU.SegmentACK],
    do: :responder

  def incoming_role(%type{}) when type in [APDU.Error, APDU.Reject, APDU.SimpleACK],
    do: :requester
end
