defmodule BACnet.Protocol.RecipientAddress do
  @moduledoc """
  A Recipient Address is the low-level network addressing information used when
  a BACnet device needs to send an event notification or COV notification to a
  specific location rather than to a known Device object identifier.

  The network field contains either 0 (meaning "the local network") or a positive
  16-bit network number for a remote network. The address field is either a
  binary MAC address (whose length and format depend on the underlying data link
  layer) or the special atom `:broadcast`, which instructs the stack to send the
  notification as a broadcast on the indicated network.

  This type is deliberately kept separate from the higher-level Recipient type
  so that the same addressing primitive can be reused inside Destination records,
  inside the various event parameter structures, and in the Write Group service.
  It is one of the few places in the protocol where raw data-link addresses
  surface into the application layer.

  ### Examples (Doc Test)

  ```elixir
  iex> addr = %RecipientAddress{network: 0, mac: :broadcast}
  iex> addr.network
  0
  ```
  """

  @typedoc """
  Represents a low-level BACnet recipient address, consisting of a network
  number and a data-link layer address (or the special `:broadcast` value).
  """
  @type t :: %__MODULE__{
          network: non_neg_integer(),
          address: binary() | :broadcast
        }

  @fields [:network, :address]
  @enforce_keys @fields
  defstruct @fields
end
