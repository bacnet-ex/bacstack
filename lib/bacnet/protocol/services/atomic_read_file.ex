defmodule BACnet.Protocol.Services.AtomicReadFile do
  @moduledoc """
  This module represents the BACnet Atomic Read File service.

  The Atomic Read File service is used to atomically read from a file on a device.

  ### Service Description (ASHRAE 135)

  > The AtomicReadFile Service is used by a client BACnet-user to perform an open-read-close operation on the contents of the
  > specified file. The file may be accessed as records or as a stream of octets.

  ### Service Procedure (ASHRAE 135)

  > The responding BACnet-user shall first verify the validity of the 'File Identifier' parameter and return a 'Result(-)' response
  > with the appropriate error class and code if the File object is unknown, if there is currently another AtomicReadFile or
  > AtomicWriteFile service in progress, or if the File object is currently inaccessible for another reason. If the 'File Start
  > Position' parameter or the 'File Start Record' parameter is either less than 0 or exceeds the actual file size, then the appropriate
  > error is returned in a 'Result(-)' response. If not, then the responding BACnet-user shall read the number of octets specified by
  > 'Requested Octet Count' or the number of records specified by 'Requested Record Count'. If the number of remaining octets
  > or records is less than the requested amount, then the length of the 'File Data' returned or 'Returned Record Count' shall
  > indicate the actual number read. If the returned response contains the last octet or record of the file, then the 'End Of File'
  > parameter shall be TRUE, otherwise FALSE.

  ### Result(+) Response (ASHRAE 135)

  On success, the responding BACnet-user returns a 'Result(+)' primitive containing:

  - 'End Of File' - TRUE if this response contains the last octet/record of the file, FALSE otherwise.
  - 'File Data' or 'Returned Record Count' + record data - Depending on whether stream or record access was requested.

  The amount of data returned may be less than requested if the end of file is reached.

  ### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that the service request has failed in its entirety. The reason for the failure shall be
  specified by the 'Error Type' parameter.

  The 'Error Class' and 'Error Code' to be returned for specific situations are as follows:

  | Situation | Error Class | Error Code |
  |-----------|-------------|------------|
  | The File object does not exist. | OBJECT | UNKNOWN_OBJECT |
  | 'File Start Record' is out of range. | SERVICES | INVALID_FILE_START_POSITION |
  | Incorrect File access method. | SERVICES | INVALID_FILE_ACCESS_METHOD |
  | A non-File Object Identifier was provided. | SERVICES | INCONSISTENT_OBJECT_TYPE |
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants

  require Constants

  @behaviour Protocol.Services.Behaviour

  @typedoc """
  Parameters for the Atomic Read File service (stream or record access).

  If `stream_access` is false, then access is record-based.
  """
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
  @spec confirmed?() :: true
  def confirmed?(), do: true

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

    @spec confirmed?(@for.t()) :: boolean()
    def confirmed?(%@for{} = _service), do: @for.confirmed?()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
