defmodule BACnet.Protocol.Services.Error.ConfirmedPrivateTransferError do
  # TODO: Docs

  alias BACnet.Protocol
  alias BACnet.Protocol.APDU.Error
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          error_class: Constants.error_class(),
          error_code: Constants.error_code() | non_neg_integer(),
          vendor_id: ApplicationTags.unsigned16(),
          service_number: non_neg_integer(),
          parameters: ApplicationTags.encoding_list() | nil
        }

  @fields [
    :invoke_id,
    :error_class,
    :error_code,
    :vendor_id,
    :service_number,
    :parameters
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :confirmed_private_transfer
                )

  @spec from_apdu(Error.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(error)

  def from_apdu(%Error{service: @service_name} = error) do
    with {:ok, vendor_id, rest} <-
           pattern_extract_tags(
             error.payload,
             {:tagged, {1, _t, _l}},
             :unsigned_integer,
             false
           ),
         :ok <-
           if(ApplicationTags.valid_int?(vendor_id, 16),
             do: :ok,
             else: {:error, :invalid_vendor_id_value}
           ),
         {:ok, service_number, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :unsigned_integer, false),
         params <-
           (case rest do
              [{:constructed, {3, params, 0}} | _tl] -> params
              _else -> nil
            end) do
      err = %__MODULE__{
        invoke_id: error.invoke_id,
        error_class: error.class,
        error_code: error.code,
        vendor_id: vendor_id,
        service_number: service_number,
        parameters: params
      }

      {:ok, err}
    end
  end

  def from_apdu(_error) do
    {:error, :invalid_service_error}
  end

  @spec to_apdu(t(), 0..255) :: {:ok, Error.t()} | {:error, term()}
  def to_apdu(error, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = error, invoke_id) when invoke_id in 0..255 do
    with :ok <-
           if(ApplicationTags.valid_int?(error.vendor_id, 16),
             do: :ok,
             else: {:error, :invalid_vendor_id_value}
           ),
         {:ok, vendor_id, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, error.vendor_id}),
         {:ok, service_number, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, error.service_number}) do
      new_error = %Error{
        invoke_id: invoke_id,
        service: @service_name,
        class: error.error_class,
        code: error.error_code,
        payload:
          Enum.reject(
            [
              {:tagged, {1, vendor_id, byte_size(vendor_id)}},
              {:tagged, {2, service_number, byte_size(service_number)}},
              if(error.parameters, do: {:constructed, {3, error.parameters, 0}})
            ],
            &is_nil/1
          )
      }

      {:ok, new_error}
    end
  end

  def to_apdu(_error, _invoke_id) do
    {:error, :invalid_parameter}
  end
end
