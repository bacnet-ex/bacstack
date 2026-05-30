defmodule BACnet.Protocol.BvlcFunction do
  @moduledoc """
  A BVLC Function is the payload of a BACnet Virtual Link Layer (BVLL) message
  used on BACnet/IP networks (ASHRAE 135 Annex J). Each function code corresponds
  to a different operation: Register-Foreign-Device, Read-Broadcast-Distribution-Table,
  Write-Broadcast-Distribution-Table, and several others used for BBMD and
  Foreign Device management.

  This module models the seven management BVLC functions that carry structured
  payloads (as opposed to the five simple NPDU-carrier functions that are
  represented as atoms in `t:BACnet.Protocol.bvlc/0`). It is the central "CHOICE"
  type for BVLC in the library: the `function` field (an atom from the
  `:bvlc_result_purpose` constants) acts as the discriminant and determines the
  shape of the `data` field.

  ## BACnet Specification References

  - Annex J.2 defines the BACnet Virtual Link Layer (BVLL) and the BVLC Function
    field (1 octet) together with the overall message format (Type 0x81, Length,
    Function, Data).
  - J.2.2-J.2.9 give the exact purpose and octet layout for each management
    function handled here (Write-BDT 0x01, Read-BDT 0x02, Read-BDT-Ack 0x03,
    Register-Foreign-Device 0x05, Read-FDT 0x06, Read-FDT-Ack 0x07,
    Delete-FDT-Entry 0x08).
  - J.2.1 and J.2.1.1 define the companion BVLC-Result (0x00) and its result codes
    (see `BACnet.Protocol.BvlcResult` and the `:bvlc_result_format` constants).
  - J.4.3-J.4.5 and J.5 describe how a BBMD uses these functions to maintain the
    Broadcast Distribution Table (BDT) and Foreign Device Table (FDT) and to
    forward broadcasts.

  ## Supported BVLC Functions and Data Shapes

  Only the functions listed below are decoded/encoded by this module. All other
  function codes (including the five NPDU carriers and Secure-BVLL 0x0C) are
  handled elsewhere or return `{:error, :unsupported_bvlc_function}`.

  | Function Atom                                 | Code | `data` Shape                                                                          | Spec Reference |
  |-----------------------------------------------|------|---------------------------------------------------------------------------------------|----------------|
  | `:bvlc_write_broadcast_distribution_table`    | 0x01 | `[BroadcastDistributionTableEntry.t()]`                                               | J.2.2          |
  | `:bvlc_read_broadcast_distribution_table`     | 0x02 | `nil`                                                                                 | J.2.3          |
  | `:bvlc_read_broadcast_distribution_table_ack` | 0x03 | `[BroadcastDistributionTableEntry.t()]`                                               | J.2.4          |
  | `:bvlc_register_foreign_device`               | 0x05 | `non_neg_integer()` (TTL in seconds, 1..65535)                                        | J.2.6          |
  | `:bvlc_read_foreign_device_table`             | 0x06 | `nil`                                                                                 | J.2.7          |
  | `:bvlc_read_foreign_device_table_ack`         | 0x07 | `[ForeignDeviceTableEntry.t()]`                                                       | J.2.8          |
  | `:bvlc_delete_foreign_device_table_entry`     | 0x08 | `ForeignDeviceTableEntry.t()` (with `time_to_live` and `remaining_time` set to `nil`) | J.2.9          |

  ## Construction & Gotchas

      iex> alias BACnet.Protocol.{BvlcFunction, Constants, ForeignDeviceTableEntry}
      iex> require Constants
      iex> ttl = 3600
      iex> fun = %BvlcFunction{
      ...>   function: Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
      ...>   data: ttl
      ...> }
      iex> fun.data
      3600

  Special cases you must know:

  - Read requests (0x02, 0x06) and their "no data" paths always use `data: nil`.
  - Delete-Foreign-Device-Table-Entry (0x08) re-uses the `BACnet.Protocol.ForeignDeviceTableEntry`
    struct but **must** have both `time_to_live` and `remaining_time` set to `nil`.
    The encoder produces the short 6-octet form required by J.2.9.1. See
    `BACnet.Protocol.ForeignDeviceTableEntry` for the exact encoding rules.
  - Secure-BVLL (0x0C) and the five simple NPDU functions (0x00 result, 0x04
    forwarded, 0x09 distribute, 0x0A/0x0B original) are **never** represented as
    a `BACnet.Protocol.BvlcFunction` struct. They appear as `BACnet.Protocol.BvlcResult`, `BACnet.Protocol.BvlcForwardedNPDU` or
    atoms inside `t:BACnet.Protocol.bvlc/0`.
  - The library does not implement Secure-BVLL (Clause 24) or IPv6 BVLL (Type
    0x82). Attempting to decode those codes returns `{:error, :unsupported_bvlc_function}`.

  ### Examples

  Register-Foreign-Device (TTL = 3600 s):

      iex> alias BACnet.Protocol.{BvlcFunction, Constants}
      iex> require Constants
      iex> fun = %BvlcFunction{
      ...>   function: Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
      ...>   data: 3600
      ...> }
      iex> BvlcFunction.encode(fun)
      {:ok, {5, <<14, 16>>}}

  Write-Broadcast-Distribution-Table with a single entry (two-hop mask):

      iex> alias BACnet.Protocol.{BvlcFunction, Constants, BroadcastDistributionTableEntry}
      iex> require Constants
      iex> entry = %BroadcastDistributionTableEntry{
      ...>   ip: {192, 168, 1, 10},
      ...>   port: 0xBAC0,
      ...>   mask: {255, 255, 255, 255}
      ...> }
      iex> fun = %BvlcFunction{
      ...>   function: Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_write_broadcast_distribution_table),
      ...>   data: [entry]
      ...> }
      iex> BvlcFunction.encode(fun)
      {:ok, {1, <<192, 168, 1, 10, 186, 192, 255, 255, 255, 255>>}}

  Delete-Foreign-Device-Table-Entry (note the `nil` fields producing the short 6-octet form):

      iex> alias BACnet.Protocol.{BvlcFunction, Constants, ForeignDeviceTableEntry}
      iex> require Constants
      iex> del = %ForeignDeviceTableEntry{
      ...>   ip: {10, 0, 0, 5},
      ...>   port: 0xBAC0,
      ...>   time_to_live: nil,
      ...>   remaining_time: nil
      ...> }
      iex> fun = %BvlcFunction{
      ...>   function: Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_delete_foreign_device_table_entry),
      ...>   data: del
      ...> }
      iex> BvlcFunction.encode(fun)
      {:ok, {8, <<10, 0, 0, 5, 186, 192>>}}

  ## Usage Contexts

  `BACnet.Protocol.BvlcFunction` values are produced by `BACnet.Protocol.decode_bvll/3` when the
  incoming BVLC function code is one of the seven management values. They are
  primarily consumed by `BACnet.Stack.BBMD` (which answers Read-BDT/Read-FDT,
  accepts Write-BDT and Register-Foreign-Device, and emits the corresponding Ack
  or Result messages) and by `BACnet.Stack.ForeignDevice` (which emits Register,
  Read-BDT, Read-FDT and Distribute-Broadcast requests).

  The encode side is used when a client or BBMD needs to emit a management
  request or response over a `BACnet.Stack.Transport.IPv4Transport`.

  ## See Also

  - `BACnet.Protocol` - top-level `bvlc()` union type and `decode_bvll/3` dispatcher
  - `BACnet.Protocol.BroadcastDistributionTableEntry` - rows stored in BDT payloads
  - `BACnet.Protocol.BvlcForwardedNPDU` - the Forwarded-NPDU carrier (0x04)
  - `BACnet.Protocol.BvlcResult` - companion result/NAK message (function 0x00)
  - `BACnet.Protocol.ForeignDeviceTableEntry` - rows stored in FDT payloads (and the special nil form used for Delete)
  - `BACnet.Stack.BBMD` - primary consumer that maintains BDT/FDT using these functions
  - `BACnet.Stack.ForeignDevice` - client-side registration and table reading
  """

  # Register-Foreign-Device data is the TTL

  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ForeignDeviceTableEntry

  require Constants

  @typedoc """
  Represents a BACnet Virtual Link Control (BVLC) function used in BACnet/IP.

  The `function` field is the discriminant. Its value determines the required
  shape of `data` (see the moduledoc table). Use the
  `BACnet.Protocol.Constants.macro_assert_name/2` helpers when constructing
  values for maximum safety and readability.
  """
  @type t :: %__MODULE__{
          function: Constants.bvlc_result_purpose(),
          data:
            [BroadcastDistributionTableEntry.t()]
            | [ForeignDeviceTableEntry.t()]
            | (delete_foreign_device_table_entry :: ForeignDeviceTableEntry.t())
            | (read_broadcast_distribution_table :: nil)
            | (read_foreign_device_table :: nil)
            | (register_foreign_device :: non_neg_integer())
        }

  @fields [:function, :data]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Decodes BACnet Virtual Link Control Functions into a struct.

  Supported are the following BVLC functions:
  - Delete-Foreign-Device-Table-Entry
  - Read-Broadcast-Distribution-Table
  - Read-Broadcast-Distribution-Table-Ack
  - Read-Foreign-Device-Table
  - Read-Foreign-Device-Table-Ack
  - Register-Foreign-Device
  - Write-Broadcast-Distribution-Table
  """
  @spec decode(non_neg_integer(), binary()) :: {:ok, t()} | {:error, term()}
  def decode(bvlc_function, data)

  def decode(
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_write_broadcast_distribution_table),
        data
      )
      when is_binary(data) do
    with {:ok, bdt} <-
           Enum.reduce_while(1..65_535//1, {data, []}, fn
             _entry, {<<>>, acc} ->
               {:halt, {:ok, Enum.reverse(acc)}}

             _entry, {data, acc} ->
               case BroadcastDistributionTableEntry.decode(data) do
                 {:ok, {bdt, rest}} -> {:cont, {rest, [bdt | acc]}}
                 term -> {:halt, term}
               end
           end) do
      fun = %__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_write_broadcast_distribution_table
          ),
        data: bdt
      }

      {:ok, fun}
    end
  end

  def decode(
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_read_broadcast_distribution_table),
        <<>>
      ) do
    fun = %__MODULE__{
      function:
        Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_read_broadcast_distribution_table),
      data: nil
    }

    {:ok, fun}
  end

  def decode(
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_read_broadcast_distribution_table),
        data
      )
      when is_binary(data) do
    {:error, :invalid_data}
  end

  def decode(
        Constants.macro_by_name(
          :bvlc_result_purpose,
          :bvlc_read_broadcast_distribution_table_ack
        ),
        data
      )
      when is_binary(data) do
    with {:ok, bdt} <-
           Enum.reduce_while(1..65_535//1, {data, []}, fn
             _entry, {<<>>, acc} ->
               {:halt, {:ok, Enum.reverse(acc)}}

             _entry, {data, acc} ->
               case BroadcastDistributionTableEntry.decode(data) do
                 {:ok, {bdt, rest}} -> {:cont, {rest, [bdt | acc]}}
                 term -> {:halt, term}
               end
           end) do
      fun = %__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_broadcast_distribution_table_ack
          ),
        data: bdt
      }

      {:ok, fun}
    end
  end

  def decode(
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
        <<ttl::size(16)>>
      ) do
    fun = %__MODULE__{
      function: Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
      data: ttl
    }

    {:ok, fun}
  end

  def decode(Constants.macro_by_name(:bvlc_result_purpose, :bvlc_register_foreign_device), data)
      when is_binary(data) do
    {:error, :invalid_data}
  end

  def decode(
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_read_foreign_device_table),
        <<>>
      ) do
    fun = %__MODULE__{
      function:
        Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_read_foreign_device_table),
      data: nil
    }

    {:ok, fun}
  end

  def decode(
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_read_foreign_device_table),
        data
      )
      when is_binary(data) do
    {:error, :invalid_data}
  end

  def decode(
        Constants.macro_by_name(
          :bvlc_result_purpose,
          :bvlc_read_foreign_device_table_ack
        ),
        data
      )
      when is_binary(data) do
    with {:ok, fdt} <-
           Enum.reduce_while(1..65_535//1, {data, []}, fn
             _entry, {<<>>, acc} ->
               {:halt, {:ok, Enum.reverse(acc)}}

             _entry, {data, acc} ->
               case ForeignDeviceTableEntry.decode(data) do
                 {:ok, {fdt, rest}} -> {:cont, {rest, [fdt | acc]}}
                 term -> {:halt, term}
               end
           end) do
      fun = %__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_foreign_device_table_ack
          ),
        data: fdt
      }

      {:ok, fun}
    end
  end

  def decode(
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_delete_foreign_device_table_entry),
        <<ip_a, ip_b, ip_c, ip_d, ip_port::size(16)>>
      ) do
    fun = %__MODULE__{
      function:
        Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_delete_foreign_device_table_entry),
      data: %ForeignDeviceTableEntry{
        ip: {ip_a, ip_b, ip_c, ip_d},
        port: ip_port,
        time_to_live: nil,
        remaining_time: nil
      }
    }

    {:ok, fun}
  end

  def decode(
        Constants.macro_by_name(:bvlc_result_purpose, :bvlc_delete_foreign_device_table_entry),
        data
      )
      when is_binary(data) do
    {:error, :invalid_data}
  end

  def decode(bvlc_function, data) when is_integer(bvlc_function) and is_binary(data) do
    {:error, :unsupported_bvlc_function}
  end

  @doc """
  Encodes BACnet Virtual Link Control Functions into binary data.

  Supported are the following BVLC functions:
  - Delete-Foreign-Device-Table-Entry
  - Read-Broadcast-Distribution-Table
  - Read-Broadcast-Distribution-Table-Ack
  - Read-Foreign-Device-Table
  - Read-Foreign-Device-Table-Ack
  - Register-Foreign-Device
  - Write-Broadcast-Distribution-Table
  """
  @spec encode(t()) ::
          {:ok, {bvlc_function :: non_neg_integer(), data :: binary()}} | {:error, term()}
  def encode(bvlc)

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_write_broadcast_distribution_table
          ),
        data: bdt
      })
      when is_list(bdt) do
    with {:ok, bdtl} <-
           Enum.reduce_while(bdt, {:ok, <<>>}, fn
             bd, {:ok, acc} ->
               case BroadcastDistributionTableEntry.encode(bd) do
                 {:ok, bin} -> {:cont, {:ok, <<acc::binary, bin::binary>>}}
                 term -> {:halt, term}
               end
           end) do
      {:ok,
       {Constants.macro_by_name(:bvlc_result_purpose, :bvlc_write_broadcast_distribution_table),
        bdtl}}
    end
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_write_broadcast_distribution_table
          )
      }) do
    {:error, :invalid_data}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_broadcast_distribution_table
          ),
        data: nil
      }) do
    {:ok,
     {Constants.macro_by_name(:bvlc_result_purpose, :bvlc_read_broadcast_distribution_table),
      <<>>}}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_broadcast_distribution_table
          )
      }) do
    {:error, :invalid_data}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_broadcast_distribution_table_ack
          ),
        data: bdt
      })
      when is_list(bdt) do
    with {:ok, bdtl} <-
           Enum.reduce_while(bdt, {:ok, <<>>}, fn
             bd, {:ok, acc} ->
               case BroadcastDistributionTableEntry.encode(bd) do
                 {:ok, bin} -> {:cont, {:ok, <<acc::binary, bin::binary>>}}
                 term -> {:halt, term}
               end
           end) do
      {:ok,
       {Constants.macro_by_name(
          :bvlc_result_purpose,
          :bvlc_read_broadcast_distribution_table_ack
        ), bdtl}}
    end
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_broadcast_distribution_table_ack
          )
      }) do
    {:error, :invalid_data}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_register_foreign_device
          ),
        data: ttl
      })
      when is_integer(ttl) do
    {:ok,
     {Constants.macro_by_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
      <<ttl::size(16)>>}}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_register_foreign_device
          )
      }) do
    {:error, :invalid_data}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_foreign_device_table
          ),
        data: nil
      }) do
    {:ok, {Constants.macro_by_name(:bvlc_result_purpose, :bvlc_read_foreign_device_table), <<>>}}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_foreign_device_table
          )
      }) do
    {:error, :invalid_data}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_foreign_device_table_ack
          ),
        data: fdt
      })
      when is_list(fdt) do
    with {:ok, fdtl} <-
           Enum.reduce_while(fdt, {:ok, <<>>}, fn
             fd, {:ok, acc} ->
               case ForeignDeviceTableEntry.encode(fd) do
                 {:ok, bin} -> {:cont, {:ok, <<acc::binary, bin::binary>>}}
                 term -> {:halt, term}
               end
           end) do
      {:ok,
       {Constants.macro_by_name(:bvlc_result_purpose, :bvlc_read_foreign_device_table_ack), fdtl}}
    end
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_foreign_device_table_ack
          )
      }) do
    {:error, :invalid_data}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_delete_foreign_device_table_entry
          ),
        data: %ForeignDeviceTableEntry{ip: {ip_a, ip_b, ip_c, ip_d}, port: port}
      })
      when is_integer(port) do
    {:ok,
     {Constants.macro_by_name(:bvlc_result_purpose, :bvlc_delete_foreign_device_table_entry),
      <<ip_a, ip_b, ip_c, ip_d, port::size(16)>>}}
  end

  def encode(%__MODULE__{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_delete_foreign_device_table_entry
          )
      }) do
    {:error, :invalid_data}
  end

  def encode(%__MODULE__{}), do: {:error, :unsupported_bvlc_function}
end
