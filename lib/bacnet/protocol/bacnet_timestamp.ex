defmodule BACnet.Protocol.BACnetTimestamp do
  @moduledoc """
  A BACnet Timestamp is a CHOICE type that can represent three different notions
  of "when something happened". The most common form is a full BACnet Date and
  Time. For trend logs that produce very high-frequency samples, a simple
  sequence number is often used instead because it consumes far less space and
  avoids the cost of maintaining a real-time clock with sub-second precision.
  The third form (Time only) is used when only the time of day is significant.

  Timestamps appear in Event Timestamps, in Trend Log records, in the Time Of
  Device Restart property, in logging notifications, and in many of the
  "last changed" properties throughout the object model. Because the three
  alternative encodings have very different sizes and precision characteristics,
  the choice of which form to use is often an important implementation decision
  that affects both memory usage and the ability of receiving systems to
  correlate events across devices.

  The type is defined so that a recipient can always determine which of the
  three alternatives is present without any additional context, which makes
  it safe to forward or store timestamps in generic log buffers and history
  archives.

  ### BACnet Specification References

  - **ASN.1** (Clause 21):
    ```
    BACnetTimeStamp ::= CHOICE {
        time            [0] Time,
        sequence-number [1] Unsigned (0..65535),
        dateTime        [2] BACnetDateTime
    }
    ```
  - **Encoding** (20.2.18): When context-tagged the choice is indicated by the
    context tag number (0 = time-only, 1 = sequence number, 2 = date+time).
    The contained value uses its normal application or constructed encoding.
  - **Usage drivers**: Trend Log (high-frequency samples favour sequence numbers),
    Event Timestamps property (all three forms allowed), `time_of_device_restart`.

  ### Examples

  #### Sequence number timestamp (common in Trend Logs)

  ```elixir
  iex> ts = %BACnetTimestamp{type: :sequence_number, sequence_number: 42837, time: nil, datetime: nil}
  iex> ts.sequence_number
  42837
  ```

  #### Full DateTime timestamp

  ```elixir
  iex> ts = %BACnetTimestamp{
  ...>   type: :datetime,
  ...>   sequence_number: nil,
  ...>   time: nil,
  ...>   datetime: %BACnetDateTime{
  ...>     date: %BACnetDate{year: 2025, month: 4, day: 1, weekday: 2},
  ...>     time: %BACnetTime{hour: 9, minute: 15, second: 0, hundredth: 0}
  ...>   }
  ...> }
  iex> ts.type
  :datetime
  ```

  #### Time-only timestamp

  ```elixir
  iex> ts = %BACnetTimestamp{type: :time, time: %BACnetTime{hour: 17, minute: 0, second: 0, hundredth: 0}, sequence_number: nil, datetime: nil}
  iex> ts.type
  :time
  ```

  ### See Also
  - `BACnet.Protocol.BACnetDate`
  - `BACnet.Protocol.BACnetDateTime`
  - `BACnet.Protocol.BACnetTime`
  - `BACnet.Protocol.EventTimestamps`
  - `BACnet.Protocol.LogRecord`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime

  @typedoc """
  A CHOICE timestamp (see ASN.1 `BACnetTimeStamp` production in Clause 21).

  - `type: :time`            → context tag 0, `time` field present
  - `type: :sequence_number` → context tag 1, `sequence_number` (0..65535)
  - `type: :datetime`        → context tag 2, `datetime` field present

  The discriminant `type` tells the encoder which context tag to emit.
  """
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
    case BACnetDateTime.parse(ts) do
      {:ok, {dt, _rest}} ->
        result = %__MODULE__{
          type: :datetime,
          datetime: dt,
          sequence_number: nil,
          time: nil
        }

        {:ok, result}

      _term ->
        {:error, :invalid_tags}
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
