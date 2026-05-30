defmodule BACnet.Protocol.ResultFlags do
  @moduledoc """
  BACnet Result Flags is a three-bit bit string returned by range-reading services
  (ReadRange, GetEventInformation, etc.) to describe the window of data that was
  actually returned.

  Bit meanings (MSB first):

  | Bit | Name       | Meaning when TRUE                                                |
  |-----|------------|:-----------------------------------------------------------------|
  | 0   | FIRST_ITEM | Response contains the first (oldest) item of the requested range |
  | 1   | LAST_ITEM  | Response contains the last (newest) item of the requested range  |
  | 2   | MORE_ITEMS | More items matched but could not fit in this PDU / segment       |

  The flags allow a client to know whether it has the beginning, the end, or is
  looking at a slice in the middle of a potentially large collection (trend-log
  buffer, alarm summary, event log, etc.).

  ### BACnet Specification References

  - **ASN.1** (Clause 21): `BACnetResultFlags ::= BIT STRING { first-item (0), last-item (1), more-items (2) }`
  - **Primary services**: ReadRange-ACK (15.8), GetEventInformation-ACK (13.11),
    and several alarm/event summary acknowledgments.

  ### Examples (Doc Test)

  ```elixir
  iex> flags = %ResultFlags{first_item: true, last_item: false, more_items: true}
  iex> flags.more_items
  true
  ```

  ### See Also
  - `BACnet.Protocol.ReadRange`
  """

  alias BACnet.Protocol.ApplicationTags

  # TODO: Throw argument error in encode if not valid

  @typedoc """
  Three Boolean flags describing a partial result set (see module docs for bit positions).
  """
  @type t :: %__MODULE__{
          first_item: boolean(),
          last_item: boolean(),
          more_items: boolean()
        }

  @fields [
    :first_item,
    :last_item,
    :more_items
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet result flags into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = flags, _opts \\ []) do
    {:ok, [to_bitstring(flags)]}
  end

  @doc """
  Creates from an application tag bitstring a result flags.
  """
  @spec from_bitstring(tuple()) :: t()
  def from_bitstring(bitstring) when is_tuple(bitstring) and tuple_size(bitstring) == 3 do
    %__MODULE__{
      first_item: elem(bitstring, 0),
      last_item: elem(bitstring, 1),
      more_items: elem(bitstring, 2)
    }
  end

  @doc """
  Parses a BACnet result flags from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:bitstring, {_b1, _b2, _b3} = bs} | rest] -> {:ok, {from_bitstring(bs), rest}}
      _else -> {:error, :invalid_tags}
    end
  end

  @doc """
  Creates an application tag bitstring from a result flags.
  """
  @spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
  def to_bitstring(%__MODULE__{} = t) do
    {:bitstring, {t.first_item, t.last_item, t.more_items}}
  end

  @doc """
  Validates whether the given result flags is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          first_item: first_item,
          last_item: last_item,
          more_items: more_items
        } = _t
      )
      when is_boolean(first_item) and is_boolean(last_item) and is_boolean(more_items),
      do: true

  def valid?(%__MODULE__{} = _t), do: false
end
