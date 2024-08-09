defmodule BACnet.Protocol.Services.Ack.CreateObjectAck do
  # TODO: Docs

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants

  require Constants

  @type t :: %__MODULE__{
          object_identifier: BACnet.Protocol.ObjectIdentifier.t()
        }

  @fields [:object_identifier]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :create_object
                )

  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(%ComplexACK{service: @service_name, payload: [object_identifier: element]} = _ack) do
    struc = %__MODULE__{
      object_identifier: element
    }

    {:ok, struc}
  end

  def from_apdu(_ack) do
    {:error, :invalid_service_ack}
  end

  @spec to_apdu(t(), 0..255) :: {:ok, ComplexACK.t()} | {:error, term()}
  def to_apdu(ack, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = ack, invoke_id) when invoke_id in 0..255 do
    new_ack = %ComplexACK{
      invoke_id: invoke_id,
      sequence_number: nil,
      proposed_window_size: nil,
      service: @service_name,
      payload: [object_identifier: ack.object_identifier]
    }

    {:ok, new_ack}
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end
end
