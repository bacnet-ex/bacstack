defmodule BACnet.Protocol.AccumulatorRecord do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @type t :: %__MODULE__{
          timestamp: BACnetDateTime.t(),
          present_value: non_neg_integer(),
          accumulated_value: non_neg_integer(),
          status: Constants.accumulator_status()
        }

  @fields [
    :timestamp,
    :present_value,
    :accumulated_value,
    :status
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes an accumulator record struct into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{timestamp: %BACnetDateTime{}} = record, opts \\ []) do
    with {:ok, present_value, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, record.present_value}, opts),
         {:ok, acc_value, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, record.accumulated_value}, opts),
         {:ok, status_c} <-
           Constants.by_name_with_reason(
             :accumulator_status,
             record.status,
             {:unknown_status, record.status}
           ),
         {:ok, status, _header} <- ApplicationTags.encode_value({:enumerated, status_c}, opts) do
      {:ok,
       [
         constructed: {0, [date: record.timestamp.date, time: record.timestamp.time], 0},
         tagged: {1, present_value, byte_size(present_value)},
         tagged: {2, acc_value, byte_size(acc_value)},
         tagged: {3, status, byte_size(status)}
       ]}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parses a BACnet accumulator record into a struct.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok,
          {:constructed,
           {0,
            [
              date: date,
              time: time
            ], _l}}, rest} <-
           pattern_extract_tags(tags, {:constructed, {0, _t, _l}}, nil, false),
         {:ok, present_value, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :unsigned_integer, false),
         {:ok, acc_value, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :unsigned_integer, false),
         {:ok, acc_status, rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _t, _l}}, :enumerated, false),
         {:ok, acc_status_c} <-
           Constants.by_value_with_reason(
             :accumulator_status,
             acc_status,
             {:unknown_status, acc_status}
           ) do
      acc = %__MODULE__{
        timestamp: %BACnetDateTime{
          date: date,
          time: time
        },
        present_value: present_value,
        accumulated_value: acc_value,
        status: acc_status_c
      }

      {:ok, {acc, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given accumulator record is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          timestamp: %BACnetDateTime{} = ts,
          present_value: pv,
          accumulated_value: av,
          status: status
        } = _t
      )
      when is_integer(pv) and pv >= 0 and is_integer(av) and av >= 0 do
    BACnetDateTime.valid?(ts) and Constants.has_by_name(:accumulator_status, status)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
