defmodule BACnet.Protocol.Services.AtomicReadFile do
  @moduledoc """
  This module represents the BACnet Atomic Read File service.

  The Atomic Read File service is used to atomically read from a file on a device.

  Service Description (ASHRAE 135):
  > The AtomicReadFile Service is used by a client BACnet-user to perform an open-read-close operation on the contents of the
  > specified file. The file may be accessed as records or as a stream of octets.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants

  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs
  # stream_access = false: Record-based access

  @type t :: %__MODULE__{
          object_identifier: Protocol.ObjectIdentifier.t(),
          stream_access: boolean(),
          start_position: integer(),
          requested_count: non_neg_integer()
        }

  @fields [
    :object_identifier,
    :stream_access,
    :start_position,
    :requested_count
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :atomic_read_file
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
  Converts the given Confirmed Service Request into an Atomic Read File Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    result =
      case request.parameters do
        [
          {:object_identifier, %Protocol.ObjectIdentifier{type: :file} = object},
          {:constructed,
           {tag_num,
            [
              signed_integer: start,
              unsigned_integer: count
            ], 0}}
          | _tail
        ]
        when tag_num in [0, 1] ->
          {:ok, {object, tag_num == 0, start, count}}

        _else ->
          {:error, :invalid_request_parameters}
      end

    case result do
      {:ok, {file, stream, start, count}} ->
        read = %__MODULE__{
          object_identifier: file,
          stream_access: stream,
          start_position: start,
          requested_count: count
        }

        {:ok, read}

      term ->
        term
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Atomic Read File Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    parameters = [
      {:object_identifier, service.object_identifier},
      {:constructed,
       {if(service.stream_access, do: 0, else: 1),
        [
          signed_integer: service.start_position,
          unsigned_integer: service.requested_count
        ], 0}}
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
      parameters: parameters
    }

    {:ok, req}
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
