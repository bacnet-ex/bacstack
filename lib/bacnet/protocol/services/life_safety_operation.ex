defmodule BACnet.Protocol.Services.LifeSafetyOperation do
  @moduledoc """
  This module represents the BACnet Life Safety Operation service.

  The Life Safety Operation service is used to provide a mechanism for human operators to silence audible or visual appliances,
  reset notification appliances, or unsilence previously silenced appliances.

  Service Description (ASHRAE 135):
  > The LifeSafetyOperation service is intended for use in fire, life safety and security systems to provide a mechanism for
  > conveying specific instructions from a human operator to accomplish any of the following objectives:
  >   (a) silence audible or visual notification appliances,
  >   (b) reset latched notification appliances, or
  >   (c) unsilence previously silenced audible or visual notification appliances.
  > Ensuring that the LifeSafetyOperation request actually comes from a person with appropriate authority is a local matter.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          requesting_process_identifier: ApplicationTags.unsigned32(),
          requesting_source: String.t(),
          request: Constants.life_safety_operation(),
          object_identifier: Protocol.ObjectIdentifier.t() | nil
        }

  @fields [
    :requesting_process_identifier,
    :requesting_source,
    :request,
    :object_identifier
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :life_safety_operation
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
  Converts the given Confirmed Service Request into a Life Safety Operation Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {:ok, process_identifier, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :unsigned_integer,
             false
           ),
         :ok <-
           if(ApplicationTags.valid_int?(process_identifier, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         {:ok, source, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :character_string, false),
         {:ok, request, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :enumerated, false),
         {:ok, request_c} <-
           Constants.by_value_with_reason(
             :life_safety_operation,
             request,
             {:unknown_life_safety_operation, request}
           ),
         {:ok, object_identifier, _rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _t, _l}}, :object_identifier, true) do
      operation = %__MODULE__{
        requesting_process_identifier: process_identifier,
        requesting_source: source,
        request: request_c,
        object_identifier: object_identifier
      }

      {:ok, operation}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Life Safety Operation Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with :ok <-
           if(ApplicationTags.valid_int?(service.requesting_process_identifier, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         {:ok, process_id, _header} <-
           ApplicationTags.encode_value(
             {:unsigned_integer, service.requesting_process_identifier}
           ),
         {:ok, source, _header} <-
           ApplicationTags.encode_value({:character_string, service.requesting_source}),
         {:ok, request_c} <-
           Constants.by_name_with_reason(
             :life_safety_operation,
             service.request,
             {:unknown_life_safety_operation, service.request}
           ),
         {:ok, request, _header} <-
           ApplicationTags.encode_value({:enumerated, request_c}),
         {:ok, object_identifier} <-
           (case service.object_identifier do
              nil ->
                {:ok, []}

              _term ->
                with {:ok, bytes, _header} <-
                       ApplicationTags.encode_value(
                         {:object_identifier, service.object_identifier}
                       ) do
                  {:ok, [{:tagged, {3, bytes, byte_size(bytes)}}]}
                end
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
          {:tagged, {0, process_id, byte_size(process_id)}},
          {:tagged, {1, source, byte_size(source)}},
          {:tagged, {2, request, byte_size(request)}}
          | object_identifier
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
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
