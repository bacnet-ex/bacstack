defmodule BACnet.Protocol.Services.Ack.AtomicReadFileAck do
  # TODO: Docs

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants

  require Constants

  # stream_access = false => record access = record_count non-nil
  @type t :: %__MODULE__{
          stream_access: boolean(),
          start_position: integer(),
          record_count: non_neg_integer() | nil,
          data: (stream_based :: binary()) | (record_based :: [binary()]),
          eof: boolean()
        }

  @fields [:eof, :stream_access, :start_position, :record_count, :data]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :atomic_read_file
                )

  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(
        %ComplexACK{
          service: @service_name,
          payload: [
            boolean: eof,
            constructed:
              {0,
               [
                 signed_integer: start_pos,
                 octet_string: data
               ], 0}
          ]
        } = _ack
      ) do
    struc = %__MODULE__{
      stream_access: true,
      start_position: start_pos,
      record_count: nil,
      data: data,
      eof: eof
    }

    {:ok, struc}
  end

  def from_apdu(
        %ComplexACK{
          service: @service_name,
          payload: [
            boolean: eof,
            constructed:
              {1,
               [
                 {:signed_integer, start_pos},
                 {:unsigned_integer, record_count}
                 | data
               ], 0}
          ]
        } = _ack
      ) do
    with {:ok, data} <-
           Enum.reduce_while(data, {:ok, []}, fn
             {:octet_string, data}, {:ok, acc} -> {:cont, {:ok, [data | acc]}}
             _term, _acc -> {:halt, {:error, :invalid_data}}
           end) do
      struc = %__MODULE__{
        stream_access: false,
        start_position: start_pos,
        record_count: record_count,
        data: Enum.reverse(data),
        eof: eof
      }

      {:ok, struc}
    end
  end

  def from_apdu(_ack) do
    {:error, :invalid_service_ack}
  end

  @spec to_apdu(t(), 0..255) :: {:ok, ComplexACK.t()} | {:error, term()}
  def to_apdu(ack, invoke_id \\ 0)

  def to_apdu(%__MODULE__{stream_access: true, data: data} = ack, invoke_id)
      when invoke_id in 0..255 and is_binary(data) do
    new_ack = %ComplexACK{
      invoke_id: invoke_id,
      sequence_number: nil,
      proposed_window_size: nil,
      service: @service_name,
      payload: [
        boolean: ack.eof,
        constructed:
          {0,
           [
             signed_integer: ack.start_position,
             octet_string: ack.data
           ], 0}
      ]
    }

    {:ok, new_ack}
  end

  def to_apdu(%__MODULE__{stream_access: false, record_count: rec_count} = ack, invoke_id)
      when invoke_id in 0..255 and is_integer(rec_count) and rec_count >= 0 and is_list(ack.data) do
    data =
      Enum.map(ack.data, fn
        data -> {:octet_string, data}
      end)

    new_ack = %ComplexACK{
      invoke_id: invoke_id,
      sequence_number: nil,
      proposed_window_size: nil,
      service: @service_name,
      payload: [
        boolean: ack.eof,
        constructed:
          {1,
           [
             {:signed_integer, ack.start_position},
             {:unsigned_integer, ack.record_count}
             | data
           ], 0}
      ]
    }

    {:ok, new_ack}
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end
end
