defmodule BACnet.Protocol.Services.Ack.AtomicWriteFileAck do
  # TODO: Docs

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  require Constants

  @type t :: %__MODULE__{
          stream_access: boolean(),
          start_position: integer()
        }

  @fields [:stream_access, :start_position]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :atomic_write_file
                )

  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(
        %ComplexACK{
          service: @service_name,
          payload: [
            tagged: {tag, start_pos, _len}
          ]
        } = _ack
      )
      when tag in [0, 1] do
    with {:ok, {:signed_integer, start_position}} <-
           ApplicationTags.unfold_to_type(:signed_integer, start_pos) do
      struc = %__MODULE__{
        stream_access: tag == 0,
        start_position: start_position
      }

      {:ok, struc}
    end
  end

  def from_apdu(_ack) do
    {:error, :invalid_service_ack}
  end

  @spec to_apdu(t(), 0..255) :: {:ok, ComplexACK.t()} | {:error, term()}
  def to_apdu(ack, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = ack, invoke_id)
      when invoke_id in 0..255 do
    with {:ok, start_pos, _header} <-
           ApplicationTags.encode_value({:signed_integer, ack.start_position}) do
      new_ack = %ComplexACK{
        invoke_id: invoke_id,
        sequence_number: nil,
        proposed_window_size: nil,
        service: @service_name,
        payload: [
          tagged: {if(ack.stream_access, do: 0, else: 1), start_pos, byte_size(start_pos)}
        ]
      }

      {:ok, new_ack}
    end
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end
end
