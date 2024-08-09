defmodule BACnet.Protocol.BvlcFunction do
  # TODO: Docs
  # Register-Foreign-Device data is the TTL

  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ForeignDeviceTableEntry

  require Constants

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
