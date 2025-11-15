defmodule BACnet.Protocol.Services.Error.CreateObjectError do
  # TODO: Docs

  alias BACnet.Protocol.APDU.Error
  alias BACnet.Protocol.Constants

  require Constants

  # first_failed_element_number = 0 => request invalid not due to "Initial Value" parameters
  @type t :: %__MODULE__{
          error_class: Constants.error_class() | non_neg_integer(),
          error_code: Constants.error_code() | non_neg_integer(),
          first_failed_element_number: non_neg_integer()
        }

  @fields [:error_class, :error_code, :first_failed_element_number]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :create_object
                )

  @spec from_apdu(Error.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(error)

  def from_apdu(%Error{service: @service_name, payload: [unsigned_integer: element]} = error) do
    err = %__MODULE__{
      error_class: error.class,
      error_code: error.code,
      first_failed_element_number: element
    }

    {:ok, err}
  end

  def from_apdu(_error) do
    {:error, :invalid_service_error}
  end

  @spec to_apdu(t(), 0..255) :: {:ok, Error.t()} | {:error, term()}
  def to_apdu(error, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = error, invoke_id) when invoke_id in 0..255 do
    new_error = %Error{
      invoke_id: invoke_id,
      service: @service_name,
      class: error.error_class,
      code: error.error_code,
      payload: [unsigned_element: error.first_failed_element_number]
    }

    {:ok, new_error}
  end

  def to_apdu(_error, _invoke_id) do
    {:error, :invalid_parameter}
  end
end
