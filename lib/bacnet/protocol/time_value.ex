defmodule BACnet.Protocol.TimeValue do
  @moduledoc """
  A Time Value is the atomic (time, value) pair used inside `BACnet.Protocol.DailySchedule`
  entries. It says: "at (or after) this time, the scheduled property should
  take on this value".

  The `value` is stored as a raw `ApplicationTags.Encoding` so it can carry
  any datatype the target property accepts (real, enumerated, boolean, etc.).

  ### BACnet Specification References
  - **ASN.1** (Clause 21): `BACnetTimeValue ::= SEQUENCE { time Time, value ABSTRACT-SYNTAX.&Type }`
  - Used in `BACnet.Protocol.DailySchedule.daySchedule` and therefore in both normal weekly
    schedules and special-event overrides (Schedule object, Clause 12.24).

  ### Examples (Doc Test)

  ```elixir
  iex> tv = %TimeValue{time: %BACnetTime{hour: 8, minute: 0, second: 0, hundredth: 0}, value: {:real, 22.5}}
  iex> tv.value
  {:real, 22.5}
  ```

  ### See Also
  - `BACnet.Protocol.BACnetTime`
  - `BACnet.Protocol.DailySchedule`
  - `BACnet.Protocol.SpecialEvent`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetTime

  @typedoc """
  (time, value) pair for schedules. `value` is generic ApplicationTags encoding.
  """
  @type t :: %__MODULE__{
          time: BACnetTime.t(),
          value: ApplicationTags.Encoding.t()
        }

  @fields [
    :time,
    :value
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet time value into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = time_value, _opts \\ []) do
    with {:ok, value} <- ApplicationTags.Encoding.to_encoding(time_value.value) do
      params = [
        {:time, time_value.time},
        value
      ]

      {:ok, params}
    end
  end

  @doc """
  Parses a BACnet time value from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:time, time},
        value
        | rest
      ] ->
        with {:ok, value} <- ApplicationTags.Encoding.create(value) do
          tv = %__MODULE__{
            time: time,
            value: value
          }

          {:ok, {tv, rest}}
        end

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given time value is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          time: %BACnetTime{} = time,
          value: %ApplicationTags.Encoding{encoding: :primitive}
        } = _t
      ) do
    BACnetTime.valid?(time)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
