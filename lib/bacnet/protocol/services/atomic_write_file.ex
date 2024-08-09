defmodule BACnet.Protocol.Services.AtomicWriteFile do
  @moduledoc """
  This module represents the BACnet Atomic Write File service.

  The Atomic Write File service is used to atomically write to a file on a device.

  Service Description (ASHRAE 135):
  > The AtomicWriteFile Service is used by a client BACnet-user to perform an open-write-close operation of an OCTET
  > STRING into a specified position or a list of OCTET STRINGs into a specified group of records in a file. The file may be
  > accessed as records or as a stream of octets.
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
          data: (stream_based :: binary()) | (record_based :: [binary()])
        }

  @fields [
    :object_identifier,
    :stream_access,
    :start_position,
    :data
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :atomic_write_file
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
  Converts the given Confirmed Service Request into an Atomic Write File Service.
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
           {0,
            [
              signed_integer: start,
              octet_string: data
            ], 0}}
          | _tail
        ] ->
          {:ok, {object, true, start, data}}

        [
          {:object_identifier, %Protocol.ObjectIdentifier{type: :file} = object},
          {:constructed,
           {1,
            [
              {:signed_integer, start},
              {:unsigned_integer, _count}
              | rest
            ], 0}}
          | _tl
        ] ->
          data =
            Enum.map(rest, fn {:octet_string, data} ->
              data
            end)

          {:ok, {object, false, start, data}}

        _else ->
          {:error, :invalid_request_parameters}
      end

    case result do
      {:ok, {file, stream, start, data}} ->
        write = %__MODULE__{
          object_identifier: file,
          stream_access: stream,
          start_position: start,
          data: data
        }

        {:ok, write}

      term ->
        term
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Atomic Write File Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    parameters =
      if service.stream_access do
        [
          {:object_identifier, service.object_identifier},
          {:constructed,
           {0,
            [
              signed_integer: service.start_position,
              octet_string: service.data
            ], 0}}
        ]
      else
        data =
          Enum.map(service.data, fn bytes ->
            {:octet_string, bytes}
          end)

        [
          {:object_identifier, service.object_identifier},
          {:constructed,
           {1,
            [
              {:signed_integer, service.start_position},
              {:unsigned_integer, length(service.data)}
              | data
            ], 0}}
        ]
      end

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
