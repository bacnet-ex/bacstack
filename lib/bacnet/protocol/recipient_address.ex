defmodule BACnet.Protocol.RecipientAddress do
  # TODO: Docs

  @type t :: %__MODULE__{
          network: non_neg_integer(),
          address: binary() | :broadcast
        }

  @fields [:network, :address]
  @enforce_keys @fields
  defstruct @fields
end
