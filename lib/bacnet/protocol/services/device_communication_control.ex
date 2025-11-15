defmodule BACnet.Protocol.Services.DeviceCommunicationControl do
  @moduledoc """
  This module represents the BACnet Device Communication Control service.

  The Device Communication Control service is used to control the communication of a device.

  Service Description (ASHRAE 135):
  > The DeviceCommunicationControl service is used by a client BACnet-user to instruct a remote device to stop initiating and
  > optionally stop responding to all APDUs (except DeviceCommunicationControl or, if supported, ReinitializeDevice) on the
  > communication network or internetwork for a specified duration of time. This service is primarily used by a human operator
  > for diagnostic purposes. A password may be required from the client BACnet-user prior to executing the service. The time
  > duration may be set to "indefinite," meaning communication must be re-enabled by a DeviceCommunicationControl or, if
  > supported, ReinitializeDevice service, not by time.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs
  # time_duration = nil: Indefinite duration
  # Password max length 20

  @type t :: %__MODULE__{
          state: Constants.enable_disable(),
          time_duration: ApplicationTags.unsigned16() | nil,
          password: String.t() | nil
        }

  @fields [
    :state,
    :time_duration,
    :password
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :device_communication_control
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
  Converts the given Confirmed Service Request into a Device Communication Control Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {:ok, time_duration, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :unsigned_integer,
             true
           ),
         :ok <-
           if(time_duration == nil or ApplicationTags.valid_int?(time_duration, 16),
             do: :ok,
             else: {:error, :invalid_time_duration_value}
           ),
         {:ok, state, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :enumerated, false),
         {:ok, state_c} <-
           Constants.by_value_with_reason(
             :enable_disable,
             state,
             {:unknown_state, state}
           ),
         {:ok, password, _rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :character_string, true) do
      event = %__MODULE__{
        state: state_c,
        time_duration: time_duration,
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
  Get the Confirmed Service request for the given Device Communication Control Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with :ok <-
           if(
             service.time_duration == nil or
               ApplicationTags.valid_int?(service.time_duration, 16),
             do: :ok,
             else: {:error, :invalid_time_duration_value}
           ),
         {:ok, state_c} <-
           Constants.by_name_with_reason(
             :enable_disable,
             service.state,
             {:unknown_state, service.state}
           ),
         {:ok, state, _header} <-
           ApplicationTags.encode_value({:enumerated, state_c}),
         {:ok, time_duration} <-
           (if service.time_duration do
              with {:ok, time_duration, _header} <-
                     ApplicationTags.encode_value({:unsigned_integer, service.time_duration}) do
                {:ok, {:tagged, {0, time_duration, byte_size(time_duration)}}}
              end
            else
              {:ok, nil}
            end),
         {:ok, password} <-
           (if service.password do
              cond do
                is_binary(service.password) and byte_size(service.password) > 20 ->
                  {:error, :password_too_long}

                is_binary(service.password) and String.valid?(service.password) ->
                  with {:ok, password, _header} <-
                         ApplicationTags.encode_value({:character_string, service.password}) do
                    {:ok, {:tagged, {2, password, byte_size(password)}}}
                  end

                true ->
                  {:error, :invalid_password}
              end
            else
              {:ok, nil}
            end) do
      parameters = [
        time_duration,
        {:tagged, {1, state, byte_size(state)}},
        password
      ]

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
        parameters: Enum.reject(parameters, &is_nil/1)
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
