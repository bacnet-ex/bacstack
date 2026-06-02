defmodule BACnet.Protocol.Services.AtomicWriteFile do
  @moduledoc """
  This module represents the BACnet Atomic Write File service.

  The Atomic Write File service is used to atomically write to a file on a device.

  ### Service Description (ASHRAE 135)

  > The AtomicWriteFile Service is used by a client BACnet-user to perform an open-write-close operation of an OCTET
  > STRING into a specified position or a list of OCTET STRINGs into a specified group of records in a file. The file may be
  > accessed as records or as a stream of octets.

  ### Service Procedure (ASHRAE 135)

  > The responding BACnet-user shall first verify the validity of the 'File Identifier' parameter and return a 'Result(-)' response
  > with the appropriate error class and code if the File object is unknown, if there is currently another AtomicReadFile or
  > AtomicWriteFile service in progress, or if the File object is currently inaccessible for another reason. If the 'File Start
  > Position' parameter or the 'File Start Record' parameter exceeds the actual file size, then the file shall be extended to the size
  > indicated, but the contents of any intervening octets or records shall be a local matter. If either of these parameters has the
  > special value -1, then the write operation shall be treated as an append to the current end of file. Then the responding
  > BACnet-user shall write the number of octets specified by 'File Data' or the number of records specified by the 'Record Count'
  > to the file. If the write fails for any reason, then a 'Result(-)' response with the appropriate error class and code shall be
  > returned. If the write succeeds in its entirety, then a 'Result(+)' response shall be returned. The 'File Start Position' or 'File
  > Start Record' shall indicate the actual position or record at which data were written.

  ### Result(+) Response (ASHRAE 135)

  On success, the responding BACnet-user returns a 'Result(+)' primitive containing the actual 'File Start Position' or 'File Start Record'
  at which the data was written. This may differ from the requested position if the special value -1 (append) was used or if the file was extended.

  ### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that the service request has failed in its entirety. The reason for the failure shall be
  specified by the 'Error Type' parameter.

  The 'Error Class' and 'Error Code' to be returned for specific situations are as follows:

  | Situation | Error Class | Error Code |
  |-----------|-------------|------------|
  | The File object does not exist. | OBJECT | UNKNOWN_OBJECT |
  | 'File Start Record' is out of range. | SERVICES | INVALID_FILE_START_POSITION |
  | Incorrect File access method. | SERVICES | INVALID_FILE_ACCESS_METHOD |
  | Write to a read-only File. | SERVICES | FILE_ACCESS_DENIED |
  | A syntax error is encountered in the message after the file has been partially modified during the execution of this service. | SERVICES | INVALID_TAG |
  | The File object is full | OBJECT | FILE_FULL |
  | A non-File Object Identifier was provided | SERVICES | INCONSISTENT_OBJECT_TYPE |
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants

  require Constants

  @behaviour Protocol.Services.Behaviour

  @typedoc """
  Parameters for the Atomic Write File service.

  If `stream_access` is false, then access is record-based.
  """
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
  @spec confirmed?() :: true
  def confirmed?(), do: true

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

    @spec confirmed?(@for.t()) :: boolean()
    def confirmed?(%@for{} = _service), do: @for.confirmed?()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
