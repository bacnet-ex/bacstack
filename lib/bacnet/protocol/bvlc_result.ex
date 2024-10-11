defmodule BACnet.Protocol.BvlcResult do
  # TODO: Docs

  @type t :: %__MODULE__{
          result_code: BACnet.Protocol.Constants.bvlc_result_format()
        }

  @fields [:result_code]
  @enforce_keys @fields
  defstruct @fields
end
