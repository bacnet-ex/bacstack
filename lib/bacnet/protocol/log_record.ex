defmodule BACnet.Protocol.LogRecord do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.StatusFlags

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @type t :: %__MODULE__{
          timestamp: BACnetDateTime.t(),
          log_datum:
            LogStatus.t()
            | ApplicationTags.Encoding.t()
            | BACnetError.t()
            | {:time_change, float()}
            | nil,
          status_flags: StatusFlags.t() | nil
        }

  @fields [
    :timestamp,
    :log_datum,
    :status_flags
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode a BACnet log record into application tag-encoded.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = record, opts \\ []) do
    with {:ok, log_datum} <- encode_log_datum(record.log_datum, opts),
         {:ok, status_flags, _header} <-
           (if record.status_flags do
              ApplicationTags.encode_value(StatusFlags.to_bitstring(record.status_flags), opts)
            else
              {:ok, nil, nil}
            end) do
      base = [
        {:constructed, {0, [date: record.timestamp.date, time: record.timestamp.time], 0}},
        {:constructed, {1, log_datum, 0}},
        {:tagged, {2, status_flags, byte_size(status_flags || <<>>)}}
      ]

      {:ok, Enum.filter(base, fn {_type, {_t, con, _l}} -> con end)}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parse a BACnet log record from application tags encoding.
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
         {:ok, log_datum} <- parse_log_datum(log_datum_raw),
         {:ok, status_flags_raw, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :bitstring, true),
         {:ok, {status_flags, _rest}} <-
           (if status_flags_raw do
              StatusFlags.parse([{:bitstring, status_flags_raw}])
            else
              {:ok, {nil, nil}}
            end) do
      record = %__MODULE__{
        timestamp: %BACnetDateTime{
          date: date,
          time: time
        },
        log_datum: log_datum,
        status_flags: status_flags
      }

      {:ok, {record, rest}}
    else
      {:ok, _tags, _rest} -> {:error, :invalid_tags}
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given log record is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_datum: %LogStatus{} = log,
          status_flags: status_flags
        } = _t
      ) do
    BACnetDateTime.valid?(stamp) and LogStatus.valid?(log) and
      (is_nil(status_flags) or
         (is_struct(status_flags, StatusFlags) and StatusFlags.valid?(status_flags)))
  end

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_datum: %BACnetError{} = log,
          status_flags: status_flags
        } = _t
      ) do
    BACnetDateTime.valid?(stamp) and BACnetError.valid?(log) and
      (is_nil(status_flags) or
         (is_struct(status_flags, StatusFlags) and StatusFlags.valid?(status_flags)))
  end

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_datum: {:time_change, value},
          status_flags: status_flags
        } = _t
      )
      when is_float(value) do
    BACnetDateTime.valid?(stamp) and
      (is_nil(status_flags) or
         (is_struct(status_flags, StatusFlags) and StatusFlags.valid?(status_flags)))
  end

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_datum: nil,
          status_flags: status_flags
        } = _t
      ) do
    BACnetDateTime.valid?(stamp) and
      (is_nil(status_flags) or
         (is_struct(status_flags, StatusFlags) and StatusFlags.valid?(status_flags)))
  end

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_datum: %ApplicationTags.Encoding{type: type},
          status_flags: status_flags
        } = _t
      )
      when type in [
             :boolean,
             :real,
             :enumerated,
             :unsigned_integer,
             :signed_integer,
             :bitstring
           ] do
    BACnetDateTime.valid?(stamp) and
      (is_nil(status_flags) or
         (is_struct(status_flags, StatusFlags) and StatusFlags.valid?(status_flags)))
  end

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_datum: %ApplicationTags.Encoding{encoding: :constructed} = enc,
          status_flags: status_flags
        } = _t
      ) do
    BACnetDateTime.valid?(stamp) and
      Keyword.get(enc.extras, :tag_number) == 10 and
      (is_nil(status_flags) or
         (is_struct(status_flags, StatusFlags) and StatusFlags.valid?(status_flags)))
  end

  def valid?(%__MODULE__{} = _t), do: false

  @spec parse_log_datum(ApplicationTags.encoding()) ::
          {:ok, term()} | {:error, term()}
  defp parse_log_datum(tags)

  defp parse_log_datum([head | _tl]) do
    parse_log_datum(head)
  end

  defp parse_log_datum({:tagged, {0, _tags, _len}} = tags) do
    with {:ok, {:bitstring, _bits} = bits} <- ApplicationTags.unfold_to_type(:bitstring, tags),
         {:ok, {log, _rest}} <- LogStatus.parse([bits]) do
      {:ok, log}
    else
      {:error, _err} = err -> err
    end
  end

  defp parse_log_datum({_type, {tagnum, _tags, _len}} = tags)
       when tagnum in [1, 2, 3, 4, 5, 6, 10] do
    cast =
      case tagnum do
        1 -> :boolean
        2 -> :real
        3 -> :enumerated
        4 -> :unsigned_integer
        5 -> :signed_integer
        6 -> :bitstring
        10 -> nil
      end

    ApplicationTags.Encoding.create(tags, cast_type: cast)
  end

  defp parse_log_datum({:tagged, {7, _tags, _len}}) do
    {:ok, nil}
  end

  defp parse_log_datum({:constructed, {8, tags, 0}}) do
    case tags do
      [
        enumerated: class,
        enumerated: code
      ] ->
        error = %BACnetError{
          class: Constants.by_value(:error_class, class, class),
          code: Constants.by_value(:error_code, code, code)
        }

        {:ok, error}

      _else ->
        {:error, :invalid_tags}
    end
  end

  defp parse_log_datum({:tagged, {9, _tags, _len}} = tags) do
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

  defp encode_log_datum(%ApplicationTags.Encoding{type: type, value: value}, opts)
       when type in [:boolean, :real, :enumerated, :unsigned_integer, :signed_integer, :bitstring] do
    enc_type =
      if type == :boolean do
        :unsigned_integer
      else
        type
      end

    with {:ok, encoding, _header} <- ApplicationTags.encode_value({enc_type, value}, opts) do
      tagnum =
        case type do
          :boolean -> 1
          :real -> 2
          :enumerated -> 3
          :unsigned_integer -> 4
          :signed_integer -> 5
          :bitstring -> 6
        end

      {:ok, {:tagged, {tagnum, encoding, byte_size(encoding)}}}
    end
  end

  defp encode_log_datum(
         %ApplicationTags.Encoding{encoding: :primitive, value: nil} = _value,
         opts
       ) do
    encode_log_datum(nil, opts)
  end

  defp encode_log_datum(%ApplicationTags.Encoding{} = value, _opts) do
    case ApplicationTags.Encoding.to_encoding(value) do
      {:ok, {:constructed, _val}} = val -> val
      {:ok, encoding} -> {:ok, {:constructed, {10, encoding, 0}}}
      term -> term
    end
  end

  defp encode_log_datum(nil, _opts) do
    {:ok, {:tagged, {7, <<>>, 0}}}
  end

  defp encode_log_datum(%BACnetError{} = value, _opts) do
    with {:ok, error} <- BACnetError.encode(value) do
      {:ok, {:constructed, {8, error, 0}}}
    end
  end

  defp encode_log_datum({:time_change, value}, _opts) do
    ApplicationTags.create_tag_encoding(9, :real, value)
  end

  defp encode_log_datum(_data, _opts), do: {:error, :invalid_log_datum}
end
