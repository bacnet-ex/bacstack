defmodule BACnet.Protocol.Services.Ack.CreateObjectAck do
  @moduledoc """
  The Create Object Acknowledgment is returned by a server after successfully
  creating a new object in response to a Create Object service request.

  The acknowledgment contains only the Object Identifier of the newly created
  object. This identifier may have been chosen by the server (when the client
  requested a specific object type without specifying an instance) or it may
  match the identifier the client requested.

  This is one of the simpler acknowledgments because the only useful information
  returned is the identity of the object that was just brought into existence.
  """

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants

  require Constants

  @typedoc """
  The response to a successful Create Object request, containing the identifier of the new object.
  """
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

  @doc """
  Converts a received `BACnet.Protocol.APDU.ComplexACK` APDU into a struct.
  """
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

  @doc """
  Constructs a `BACnet.Protocol.APDU.ComplexACK` APDU from a
  `BACnet.Protocol.Services.Ack.CreateObjectAck` struct.

  Used by a server to confirm successful creation of a new object.
  """
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
