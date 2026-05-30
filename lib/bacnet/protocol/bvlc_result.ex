defmodule BACnet.Protocol.BvlcResult do
  @moduledoc """
  Represents the result of a BVLC operation (BVLC function 0x00, BVLC-Result) in BACnet/IP
  (ASHRAE 135 Annex J.2.1). The single-byte result code indicates success or the reason for failure.

  A `BACnet.Protocol.BvlcResult` is returned by a BBMD (or other BVLC responder) to acknowledge
  management requests that require a reply: Write-Broadcast-Distribution-Table,
  Register-Foreign-Device, Delete-Foreign-Device-Table-Entry, and the various
  Read-*-Table operations (the Read operations return an Ack PDU on success and
  a Result/NAK on failure).

  ## BACnet Specification References

  - Annex J.2.1 defines the purpose of BVLC-Result.
  - J.2.1.1 gives the exact format (BVLC Type 0x81, Function 0x00, Length 0x0006,
    2-octet Result Code) and the normative list of result codes.

  ## Result Codes

  | Atom (in `:bvlc_result_format`)                  | Value (hex) | Meaning (from J.2.1.1)                              |
  |--------------------------------------------------|-------------|-----------------------------------------------------|
  | `:successful_completion`                         | 0x0000      | The requested BVLC operation completed successfully |
  | `:write_broadcast_distribution_table_nak`        | 0x0010      | Write-Broadcast-Distribution-Table failed           |
  | `:read_broadcast_distribution_table_nak`         | 0x0020      | Read-Broadcast-Distribution-Table failed            |
  | `:register_foreign_device_nak`                   | 0x0030      | Register-Foreign-Device failed (e.g. no room)       |
  | `:read_foreign_device_table_nak`                 | 0x0040      | Read-Foreign-Device-Table failed                    |
  | `:delete_foreign_device_table_entry_nak`         | 0x0050      | Delete-Foreign-Device-Table-Entry failed            |
  | `:distribute_broadcast_to_network_nak`           | 0x0060      | Distribute-Broadcast-To-Network failed              |

  Only the codes above are modelled. Unknown codes received on the wire produce
  `{:error, {:unknown_result_code, value}}` in `BACnet.Protocol.decode_bvll/3`.

  ## Construction & Usage

  The struct is deliberately minimal (one field) because the wire representation
  is only two octets. Typical construction for tests or when generating a
  response:

      iex> alias BACnet.Protocol.{BvlcResult, Constants}
      iex> require Constants
      iex> res = %BvlcResult{
      ...>   result_code: Constants.macro_assert_name(:bvlc_result_format, :successful_completion)
      ...> }
      iex> res.result_code
      :successful_completion

  In normal operation you rarely construct `BACnet.Protocol.BvlcResult` values yourself; they
  arrive via `BACnet.Protocol.decode_bvll/3` when a remote device replies to a
  management request you (or the BBMD) sent. `BACnet.Stack.BBMD` interprets the
  code to decide whether a BDT/FDT update or foreign registration succeeded.

  ## See Also

  - `BACnet.Protocol` - the `decode_bvll/3` entry point that materialises `BACnet.Protocol.BvlcResult` values
  - `BACnet.Protocol.BvlcFunction` - the management requests that produce these results
  - `BACnet.Stack.BBMD` - main consumer that acts on success/NAK codes
  - `BACnet.Stack.ForeignDevice` - also receives results for its registration and table-read requests
  """

  @typedoc """
  Represents the result of a BVLC operation (function code 0x00).

  The `result_code` is taken from the `:bvlc_result_format` constants and
  directly mirrors the values defined in ASHRAE 135 Annex J.2.1.1.
  """
  @type t :: %__MODULE__{
          result_code: BACnet.Protocol.Constants.bvlc_result_format()
        }

  @fields [:result_code]
  @enforce_keys @fields
  defstruct @fields
end
