defmodule BACnet.Protocol.LogMultipleRecord do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.LogStatus

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @typedoc """
  Representative type for log data - possible values it can take.
  """
  @type log_data ::
          ApplicationTags.Encoding.t()
          | BACnetError.t()
          | nil

  @type t :: %__MODULE__{
          timestamp: BACnetDateTime.t(),
          log_data: [log_data()] | LogStatus.t() | {:time_change, float()}
        }

  @fields [
    :timestamp,
    :log_data
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode a BACnet log multiple record into application tag-encoded.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = record, opts \\ []) do
    with {:ok, log_data} <- encode_log_data(record.log_data, opts) do
      params = [
        {:constructed, {0, [date: record.timestamp.date, time: record.timestamp.time], 0}},
        {:constructed, {1, log_data, 0}}
      ]

      {:ok, params}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parse a BACnet log multiple record from application tags encoding.
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
         {:ok, {:constructed, {1, log_data_raw, _l}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {1, _t, _l}}, nil, false),
         {:ok, log_data} <- parse_log_data(log_data_raw) do
      record = %__MODULE__{
        timestamp: %BACnetDateTime{
          date: date,
          time: time
        },
        log_data: log_data
      }

      {:ok, {record, rest}}
    else
      {:ok, _miss, _rest} -> {:error, :invalid_tags}
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given log multiple record is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_data: {:time_change, log_data}
        } = _t
      )
      when is_float(log_data) do
    BACnetDateTime.valid?(stamp)
  end

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_data: %LogStatus{} = log_data
        } = _t
      ) do
    BACnetDateTime.valid?(stamp) and LogStatus.valid?(log_data)
  end

  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = stamp,
          log_data: log_data
        } = _t
      )
      when is_list(log_data) do
    BACnetDateTime.valid?(stamp) and
      Enum.all?(log_data, fn
        %ApplicationTags.Encoding{type: type}
        when type in [
               :boolean,
               :real,
               :enumerated,
               :unsigned_integer,
               :signed_integer,
               :bitstring
             ] ->
          true

        %ApplicationTags.Encoding{encoding: :constructed} = enc ->
          Keyword.get(enc.extras, :tag_number) == 8

        %BACnetError{} ->
          true

        nil ->
          true

        _else ->
          false
      end)
  end

  def valid?(%__MODULE__{} = _t), do: false

  @spec parse_log_data(ApplicationTags.encoding_list()) :: {:ok, term()} | {:error, term()}
  defp parse_log_data(tags)

  defp parse_log_data({:tagged, {0, _tags, _len}} = tags) do
    with {:ok, {:bitstring, _bits} = bits} <- ApplicationTags.unfold_to_type(:bitstring, tags),
         {:ok, {log, _rest}} <- LogStatus.parse([bits]) do
      {:ok, log}
    else
      {:error, _err} = err -> err
    end
  end

  defp parse_log_data({:constructed, {1, tags, _len}}) do
    result =
      Enum.reduce_while(List.wrap(tags), {:ok, []}, fn
        tag, {:ok, acc} ->
          case parse_log_datum(tag) do
            {:ok, val} -> {:cont, {:ok, [val | acc]}}
            term -> {:halt, term}
          end
      end)

    case result do
      {:ok, value} -> {:ok, Enum.reverse(value)}
      term -> term
    end
  end

  defp parse_log_data({:tagged, {2, _tags, 4}} = tags) do
    with {:ok, {:real, change}} <- ApplicationTags.unfold_to_type(:real, tags) do
      {:ok, {:time_change, change}}
    else
      {:error, _err} = err -> err
    end
  end

  defp parse_log_data(_tags), do: {:error, :invalid_tags}

  @spec parse_log_datum(ApplicationTags.encoding()) ::
          {:ok, term()} | {:error, term()}
  defp parse_log_datum(tags)

  defp parse_log_datum({_type, {tagnum, _tags, _len}} = tags)
       when tagnum in [0, 1, 2, 3, 4, 5, 8] do
    cast =
      case tagnum do
        0 -> :boolean
        1 -> :real
        2 -> :enumerated
        3 -> :unsigned_integer
        4 -> :signed_integer
        5 -> :bitstring
        8 -> nil
      end

    ApplicationTags.Encoding.create(tags, cast_type: cast)
  end

  defp parse_log_datum({:tagged, {6, _tags, _len}}) do
    {:ok, nil}
  end

  defp parse_log_datum({:constructed, {7, tags, _len}}) do
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

  defp parse_log_datum(_tags), do: {:error, :invalid_tags}

  @spec encode_log_data([log_data()], Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  defp encode_log_data(data, opts)

  defp encode_log_data(%LogStatus{} = value, _opts) do
    ApplicationTags.create_tag_encoding(0, LogStatus.to_bitstring(value))
  end

  defp encode_log_data(data, opts) when is_list(data) do
    result =
      Enum.reduce_while(data, {:ok, []}, fn
        log, {:ok, acc} ->
          case encode_log_datum(log, opts) do
            {:ok, val} -> {:cont, {:ok, [val | acc]}}
            term -> {:halt, term}
          end
      end)

    case result do
      {:ok, value} ->
        new_list =
          value
          |> Enum.reverse()
          |> List.flatten()

        {:ok, {:constructed, {1, new_list, 0}}}

      term ->
        term
    end
  end

  defp encode_log_data({:time_change, change}, _opts) when is_float(change) do
    ApplicationTags.create_tag_encoding(2, {:real, change})
  end

  defp encode_log_data(_data, _opts), do: {:error, :invalid_log_data}

  @spec encode_log_datum(term(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding()} | {:error, term()}
  defp encode_log_datum(value, opts)

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
          :boolean -> 0
          :real -> 1
          :enumerated -> 2
          :unsigned_integer -> 3
          :signed_integer -> 4
          :bitstring -> 5
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
      {:ok, encoding} -> {:ok, {:constructed, {8, encoding, 0}}}
      term -> term
    end
  end

  defp encode_log_datum(nil, _opts) do
    {:ok, {:tagged, {6, <<>>, 0}}}
  end

  defp encode_log_datum(%BACnetError{} = value, _opts) do
    with {:ok, error} <- BACnetError.encode(value) do
      {:ok, {:constructed, {7, error, 0}}}
    end
  end

  defp encode_log_datum(_data, _opts), do: {:error, :invalid_log_data}
end
