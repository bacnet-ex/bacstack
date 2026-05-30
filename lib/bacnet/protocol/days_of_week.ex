defmodule BACnet.Protocol.DaysOfWeek do
  @moduledoc """
  DaysOfWeek is a 7-bit bit string (application tag 8) where each bit represents
  one day of the week. It is one of the most frequently used building blocks for
  recurring schedules and exception handling in BACnet.

  Bit layout (MSB first, per 20.2.10 encoding rules):

  | Bit | Day       | Field in struct    |
  |-----|-----------|--------------------|
  | 0   | Monday    | `monday`           |
  | 1   | Tuesday   | `tuesday`          |
  | 2   | Wednesday | `wednesday`        |
  | 3   | Thursday  | `thursday`         |
  | 4   | Friday    | `friday`           |
  | 5   | Saturday  | `saturday`         |
  | 6   | Sunday    | `sunday`           |

  A bit set to `true` means the day is included in the set.

  ### BACnet Specification References
  - **ASN.1** (Clause 21): `BACnetDaysOfWeek ::= BIT STRING { monday (0), tuesday (1), wednesday (2), thursday (3), friday (4), saturday (5), sunday (6) }`
  - **Primary uses**:
    - `weekly_schedule` in Schedule objects (one `DailySchedule` per day of week)
    - `exception_schedule` (combined with `WeekNDay` or `DateRange`)
    - `valid_days` in `BACnet.Protocol.Destination` (who receives notifications on which days)
    - Many calendar and special-event constructs

  ### Examples (Doc Test)

  ```elixir
  iex> weekdays = %DaysOfWeek{
  ...>   monday: true,
  ...>   tuesday: true,
  ...>   wednesday: true,
  ...>   thursday: true,
  ...>   friday: true,
  ...>   saturday: false,
  ...>   sunday: false
  ...> }
  iex> weekdays.friday
  true
  ```

  ### See Also
  - `BACnet.Protocol.CalendarEntry`
  - `BACnet.Protocol.DailySchedule`
  - `BACnet.Protocol.DateRange`
  - `BACnet.Protocol.Destination`
  - `BACnet.Protocol.WeekNDay`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Represents a BACnet days of week.
  """
  @type t :: %__MODULE__{
          monday: boolean(),
          tuesday: boolean(),
          wednesday: boolean(),
          thursday: boolean(),
          friday: boolean(),
          saturday: boolean(),
          sunday: boolean()
        }

  @fields [
    :monday,
    :tuesday,
    :wednesday,
    :thursday,
    :friday,
    :saturday,
    :sunday
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet days of week into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = flags, _opts \\ []) do
    {:ok, [to_bitstring(flags)]}
  end

  @doc """
  Creates from an application tag bitstring a days of week.
  """
  @spec from_bitstring(tuple()) :: t()
  def from_bitstring(bitstring) when is_tuple(bitstring) and tuple_size(bitstring) == 7 do
    %__MODULE__{
      monday: elem(bitstring, 0),
      tuesday: elem(bitstring, 1),
      wednesday: elem(bitstring, 2),
      thursday: elem(bitstring, 3),
      friday: elem(bitstring, 4),
      saturday: elem(bitstring, 5),
      sunday: elem(bitstring, 6)
    }
  end

  @doc """
  Parses a BACnet days of week from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:bitstring, {_b1, _b2, _b3, _b4, _b5, _b6, _b7} = bs} | rest] ->
        {:ok, {from_bitstring(bs), rest}}

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Creates an application tag bitstring from a days of week.
  """
  @spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
  def to_bitstring(%__MODULE__{} = t) do
    {:bitstring, {t.monday, t.tuesday, t.wednesday, t.thursday, t.friday, t.saturday, t.sunday}}
  end

  @doc """
  Validates whether the given days of week is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          monday: monday,
          tuesday: tuesday,
          wednesday: wednesday,
          thursday: thursday,
          friday: friday,
          saturday: saturday,
          sunday: sunday
        } = _t
      )
      when is_boolean(monday) and is_boolean(tuesday) and is_boolean(wednesday) and
             is_boolean(thursday) and is_boolean(friday) and is_boolean(saturday) and
             is_boolean(sunday),
      do: true

  def valid?(%__MODULE__{} = _t), do: false
end
