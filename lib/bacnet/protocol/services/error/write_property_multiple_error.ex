defmodule BACnet.Protocol.Services.Error.WritePropertyMultipleError do
  @moduledoc """
  The Write Property Multiple Error is returned when a Write Property Multiple
  service request fails.

  It identifies the first object and property that could not be written
  (via an Object Property Reference) along with the reason for the failure.
  This allows the client to know exactly where in a large bulk write operation
  the failure occurred without having to guess.
  """

  alias BACnet.Protocol.APDU.Error
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectPropertyRef

  require Constants

  @typedoc """
  Error response for a failed Write Property Multiple service.

  Identifies the exact object/property reference (first failure) and the error class/code so the client
  can pinpoint which write in a bulk operation failed.
  """
  @type t :: %__MODULE__{
          error_class: Constants.error_class() | non_neg_integer(),
          error_code: Constants.error_code() | non_neg_integer(),
          first_failed_write_attempt: ObjectPropertyRef.t()
        }

  @fields [:error_class, :error_code, :first_failed_write_attempt]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :write_property_multiple
                )

  @doc """
  Converts a received Error APDU into a WritePropertyMultipleError struct.
  """
  @spec from_apdu(Error.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(error)

  def from_apdu(
        %Error{service: @service_name, payload: [{:constructed, {1, payload, _len}} | _tl]} =
          error
      ) do
    with {:ok, {ref, _rest}} <- ObjectPropertyRef.parse(payload) do
      err = %__MODULE__{
        error_class: error.class,
        error_code: error.code,
        first_failed_write_attempt: ref
      }

      {:ok, err}
    end
  end

  def from_apdu(_error) do
    {:error, :invalid_service_error}
  end

  @doc """
  Constructs an Error APDU from a WritePropertyMultipleError struct.
  """
  @spec to_apdu(t(), 0..255) :: {:ok, Error.t()} | {:error, term()}
  def to_apdu(error, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = error, invoke_id) when invoke_id in 0..255 do
    with {:ok, ref} <-
           BACnet.Protocol.ObjectPropertyRef.encode(error.first_failed_write_attempt) do
      new_error = %Error{
        invoke_id: invoke_id,
        service: @service_name,
        class: error.error_class,
        code: error.error_code,
        payload: [{:constructed, {1, ref, 0}}]
      }

      {:ok, new_error}
    end
  end

  def to_apdu(_error, _invoke_id) do
    {:error, :invalid_parameter}
  end
end
