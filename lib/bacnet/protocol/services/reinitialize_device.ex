defmodule BACnet.Protocol.Services.ReinitializeDevice do
  @moduledoc """
  This module represents the BACnet Reinitialize Device service.

  The Device Communication Control service is used to instruct a device to reboot or reset to a predefined state,
  or to control backup or restore services.

  Service Description (ASHRAE 135):
  > The ReinitializeDevice service is used by a client BACnet-user to instruct a remote device to reboot itself (cold start), reset
  > itself to some predefined initial state (warm start), or to control the backup or restore procedure. Resetting or rebooting a
  > device is primarily initiated by a human operator for diagnostic purposes. Use of this service during the backup or restore
  > procedure is usually initiated on behalf of the user by the device controlling the backup or restore. Due to the sensitive
  > nature of this service, a password may be required by the responding BACnet-user prior to executing the service.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs
  # Password max length 20

  @type t :: %__MODULE__{
          reinitialized_state: Constants.reinitialized_state(),
          password: String.t() | nil
        }

  @fields [
    :reinitialized_state,
    :password
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :reinitialize_device
                )

  @doc """
  Get the service name atom.
  """
  @spec get_name() :: atom()
  def get_name(), do: @service_name

  @doc """
  Whether the service is of type confirmed or unconfirmed.
  """
  @spec is_confirmed() :: true
  def is_confirmed(), do: true

  @doc """
  Converts the given Confirmed Service Request into a Reinitialize Device Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {:ok, state, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :enumerated,
             false
           ),
         {:ok, state_c} <-
           Constants.by_value_with_reason(
             :reinitialized_state,
             state,
             {:unknown_reinitialized_state, state}
           ),
         {:ok, password, _rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :character_string, true) do
      event = %__MODULE__{
        reinitialized_state: state_c,
        password: password
      }

      {:ok, event}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Reinitialize Device Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, state_c} <-
           Constants.by_name_with_reason(
             :reinitialized_state,
             service.reinitialized_state,
             {:unknown_reinitialized_state, service.reinitialized_state}
           ),
         {:ok, state, _header} <-
           ApplicationTags.encode_value({:enumerated, state_c}),
         {:ok, password} <-
           (if service.password do
              if byte_size(service.password) > 20 do
                {:error, :password_too_long}
              else
                with {:ok, password, _header} <-
                       ApplicationTags.encode_value({:character_string, service.password}) do
                  {:ok, [{:tagged, {1, password, byte_size(password)}}]}
                end
              end
            else
              {:ok, []}
            end) do
      req = %Protocol.APDU.ConfirmedServiceRequest{
        segmented_response_accepted: request_data[:segmented_response_accepted] || true,
        max_segments: request_data[:max_segments] || :more_than_64,
        max_apdu:
          request_data[:max_apdu] ||
            Constants.macro_by_name(:max_apdu_length_accepted_value, :octets_1476),
        invoke_id: request_data[:invoke_id] || 0,
        sequence_number: nil,
        proposed_window_size: nil,
        service: @service_name,
        parameters: [
          {:tagged, {0, state, byte_size(state)}}
          | password
        ]
      }

      {:ok, req}
    end
  end

  defimpl Protocol.Services.Protocol do
    alias BACnet.Protocol
    alias BACnet.Protocol.Constants
    require Constants

    @spec get_name(@for.t()) :: atom()
    def get_name(%@for{} = _service), do: @for.get_name()

    @spec is_confirmed(@for.t()) :: boolean()
    def is_confirmed(%@for{} = _service), do: @for.is_confirmed()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
