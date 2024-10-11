defmodule BACnet.Protocol.EventLogRecord do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.Services.Common
  alias BACnet.Protocol.Services.ConfirmedEventNotification

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          timestamp: BACnetDateTime.t(),
          log_datum:
            LogStatus.t()
            | ConfirmedEventNotification.t()
            | {:time_change, float()}
        }

  @fields [
    :timestamp,
    :log_datum
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode a BACnet log record into application tag-encoded.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = record, opts \\ []) do
    with {:ok, log_datum} <- encode_log_datum(record.log_datum, opts) do
      base = [
        {:constructed, {0, [date: record.timestamp.date, time: record.timestamp.time], 0}},
        {:constructed, {1, log_datum, 0}}
      ]

      {:ok, base}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parse a BACnet event log record from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok,
          {:constructed,
           {0,
            [
              date: date,
              time: time
            ], _l}},
          rest} <-
           pattern_extract_tags(tags, {:constructed, {0, _t, _l}}, nil, false),
         {:ok, {:constructed, {1, log_datum_raw, _l}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {1, _t, _l}}, nil, false),
         {:ok, log_datum} <- parse_log_datum(log_datum_raw) do
      record = %__MODULE__{
        timestamp: %BACnetDateTime{
          date: date,
          time: time
        },
        log_datum: log_datum
      }

      {:ok, {record, rest}}
    else
      {:ok, {:constructed, _term}, _rest} -> {:error, :invalid_tags}
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given event log record is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_datum: %LogStatus{} = datum
        } = _t
      ) do
    BACnetDateTime.valid?(stamp) and LogStatus.valid?(datum)
  end

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_datum: %ConfirmedEventNotification{}
        } = _t
      ) do
    BACnetDateTime.valid?(stamp)
  end

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_datum: {:time_change, value}
        } = _t
      )
      when is_float(value) do
    BACnetDateTime.valid?(stamp)
  end

  def valid?(%__MODULE__{} = _t), do: false

  @spec parse_log_datum(ApplicationTags.encoding()) ::
          {:ok, term()} | {:error, term()}
  defp parse_log_datum(tags)

  defp parse_log_datum({:tagged, {0, _tags, _len}} = tags) do
    with {:ok, {:bitstring, {_b0, _b1, _b2} = bits}} <-
           ApplicationTags.unfold_to_type(:bitstring, tags) do
      {:ok, LogStatus.from_bitstring(bits)}
    else
      {:ok, _val} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  defp parse_log_datum({:constructed, {1, tags, 0}}) do
    # Make up some data (they are not relevant)
    service = %ConfirmedServiceRequest{
      segmented_response_accepted: false,
      max_apdu: 1467,
      max_segments: :unspecified,
      invoke_id: 0,
      sequence_number: nil,
      proposed_window_size: nil,
      service:
        Constants.macro_assert_name(:confirmed_service_choice, :confirmed_event_notification),
      parameters: tags
    }

    ConfirmedEventNotification.from_apdu(service)
  end

  defp parse_log_datum({:tagged, {2, _tags, 4}} = tags) do
    with {:ok, {:real, real}} <- ApplicationTags.unfold_to_type(:real, tags) do
      {:ok, {:time_change, real}}
    else
      {:error, _err} = err -> err
    end
  end

  defp parse_log_datum(_tags), do: {:error, :invalid_tags}

  @spec encode_log_datum(term(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding()} | {:error, term()}
  defp encode_log_datum(value, opts)

  defp encode_log_datum(%LogStatus{} = value, _opts) do
    ApplicationTags.create_tag_encoding(0, LogStatus.to_bitstring(value))
  end

  defp encode_log_datum(%ConfirmedEventNotification{} = value, _opts) do
    with {:ok, %{parameters: params}} <- Common.encode_event_notification(value) do
      {:ok, {:constructed, {1, params, 0}}}
    else
      {:error, _err} = err -> err
    end
  end

  defp encode_log_datum({:time_change, value}, _opts) when is_float(value) do
    ApplicationTags.create_tag_encoding(2, :real, value)
  end
end
