defmodule BACnet.Protocol.BACnetTimestamp do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime

  @type t :: %__MODULE__{
          type: :time | :sequence_number | :datetime,
          time: BACnetTime.t() | nil,
          sequence_number: non_neg_integer() | nil,
          datetime: BACnetDateTime.t() | nil
        }

  @fields [
    :type,
    :time,
    :sequence_number,
    :datetime
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes the given BACnet timestamp into an application tag.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(timestamp, opts \\ [])

  def encode(%__MODULE__{type: :time} = timestamp, opts) do
    with {:ok, value, _header} <- ApplicationTags.encode_value({:time, timestamp.time}, opts) do
      {:ok, [{:tagged, {0, value, byte_size(value)}}]}
    end
  end

  def encode(%__MODULE__{type: :sequence_number} = timestamp, opts) do
    with {:ok, value, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, timestamp.sequence_number}, opts) do
      {:ok, [{:tagged, {1, value, byte_size(value)}}]}
    end
  end

  def encode(%__MODULE__{type: :datetime, datetime: %BACnetDateTime{} = dt} = _timestamp, _opts) do
    {:ok, [{:constructed, {2, [date: dt.date, time: dt.time], 0}}]}
  end

  @doc """
  Decodes the given application tags encoding into a BACnet timestamp.

  Example:

      iex> BACnetTimestamp.parse([{:tagged, {0, <<2, 12, 49, 0>>, 4}}])
      {:ok,
      {%BACnetTimestamp{
        datetime: nil,
        sequence_number: nil,
        time: %BACnetTime{
          hour: 2,
          hundredth: 0,
          minute: 12,
          second: 49
        },
        type: :time
      }, []}}
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term}
  def parse(tags) when is_list(tags) do
    with [head | rest] <- tags,
         {:ok, result} <- do_parse(head) do
      {:ok, {result, rest}}
    else
      [] -> {:error, :invalid_tags}
      {:error, :invalid_data} -> {:error, :invalid_tags}
      {:error, :unknown_tag_encoding} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @spec do_parse(ApplicationTags.encoding()) :: {:ok, t()} | {:error, term}
  defp do_parse({:tagged, {0, _value, 4}} = value) do
    case ApplicationTags.unfold_to_type(:time, value) do
      {:ok, {:time, time}} ->
        result = %__MODULE__{
          type: :time,
          time: time,
          sequence_number: nil,
          datetime: nil
        }

        {:ok, result}

      {:error, _term} = term ->
        term
    end
  end

  defp do_parse({:tagged, {1, _value, _len}} = value) do
    case ApplicationTags.unfold_to_type(:unsigned_integer, value) do
      {:ok, {:unsigned_integer, seqnum}} ->
        result = %__MODULE__{
          type: :sequence_number,
          sequence_number: seqnum,
          datetime: nil,
          time: nil
        }

        {:ok, result}

      {:error, _term} = term ->
        term
    end
  end

  defp do_parse({:constructed, {2, ts, _len}}) when is_list(ts) do
    with {:ok, {dt, _rest}} <- BACnetDateTime.parse(ts) do
      result = %__MODULE__{
        type: :datetime,
        datetime: dt,
        sequence_number: nil,
        time: nil
      }

      {:ok, result}
    else
      _term -> {:error, :invalid_tags}
    end
  end

  defp do_parse(_arg), do: {:error, :invalid_tags}

  @doc """
  Validates whether the given BACnet timestamp is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          type: :time,
          time: %BACnetTime{} = time
        } = _t
      ) do
    BACnetTime.valid?(time)
  end

  def valid?(
        %__MODULE__{
          type: :sequence_number,
          sequence_number: num
        } = _t
      )
      when is_integer(num) and num >= 0,
      do: true

  def valid?(
        %__MODULE__{
          type: :datetime,
          datetime: %BACnetDateTime{} = dt
        } = _t
      ) do
    BACnetDateTime.valid?(dt)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
