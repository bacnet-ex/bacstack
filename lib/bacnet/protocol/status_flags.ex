defmodule BACnet.Protocol.StatusFlags do
  @moduledoc """
  BACnet Status Flags is a four-bit bit string (application tag 8) that provides a
  compact summary of an object's health and operating mode. It is the `status_flags`
  property on virtually every standard object type and appears in almost every
  event-related structure.

  Bit ordering (MSB first, per Clause 20.2.10):

  | Bit | Name            | Meaning when TRUE                                       |
  |-----|-----------------|:--------------------------------------------------------|
  | 0   | IN_ALARM        | `event_state` != NORMAL                                 |
  | 1   | FAULT           | `reliability` indicates a fault                         |
  | 2   | OVERRIDDEN      | Local override (operator interface, physical switch, …) |
  | 3   | OUT_OF_SERVICE  | `out_of_service` property is TRUE                       |

  The meanings are deliberately consistent across object types so that generic
  workstations can interpret the flags without knowing the concrete object type.

  ### BACnet Specification References

  - **Encoding** (20.2.10): Primitive bit string. First contents octet = number of
    unused bits (0 for a 4-bit value). Bits are placed with the first defined
    Boolean in bit 7 of the first subsequent octet.
  - **ASN.1** (Clause 21): `BACnetStatusFlags ::= BIT STRING { in-alarm (0), fault (1), overridden (2), out-of-service (3) }`
  - **Mandatory property**: Every object type defined in Clause 12 that has an
    `event_state` or `reliability` property also has a `status_flags` property
    whose value is a `BACnetStatusFlags`.
  - **Event usage**: Carried inside `BACnetNotificationParameters` (Change-of-State,
    Change-of-Reliability, …) and in GetAlarmSummary / GetEventInformation ACKs.

  This module stores the four Booleans in a struct for ergonomic access while the
  wire form is produced by the `to_bitstring/1` helper used during encoding.

  ### Examples (Doc Test)

  #### Creating flags

  ```elixir
  iex> flags = %StatusFlags{in_alarm: false, fault: false, overridden: true, out_of_service: false}
  iex> flags.overridden
  true
  ```

  #### Round-tripping through encoding

  ```elixir
  iex> flags = %StatusFlags{in_alarm: true, fault: false, overridden: false, out_of_service: false}
  iex> {:ok, [encoded]} = StatusFlags.encode(flags)
  iex> StatusFlags.from_bitstring(elem(encoded, 1))
  %StatusFlags{in_alarm: true, fault: false, overridden: false, out_of_service: false}
  ```

  ### See Also
  - `BACnet.Protocol.Constants` (for related `reliability` and `event_state` values)
  - `BACnet.Protocol.EventTransitionBits`
  - `BACnet.Protocol.NotificationParameters`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Represents the four Boolean flags of a BACnet Status Flags bit string
  (see table in the module documentation for bit positions and semantics).
  """
  @type t :: %__MODULE__{
          in_alarm: boolean(),
          fault: boolean(),
          overridden: boolean(),
          out_of_service: boolean()
        }

  @fields [
    :in_alarm,
    :fault,
    :overridden,
    :out_of_service
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet status flags into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = flags, _opts \\ []) do
    {:ok, [to_bitstring(flags)]}
  end

  @doc """
  Creates from an application tag bitstring a status flag.
  """
  @spec from_bitstring(tuple()) :: t()
  def from_bitstring(bitstring) when is_tuple(bitstring) and tuple_size(bitstring) == 4 do
    %__MODULE__{
      in_alarm: elem(bitstring, 0),
      fault: elem(bitstring, 1),
      overridden: elem(bitstring, 2),
      out_of_service: elem(bitstring, 3)
    }
  end

  @doc """
  Parses a BACnet status flags from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:bitstring, {_b1, _b2, _b3, _b4} = bs} | rest] -> {:ok, {from_bitstring(bs), rest}}
      _else -> {:error, :invalid_tags}
    end
  end

  @doc """
  Creates an application tag bitstring from a status flag.
  """
  @spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
  def to_bitstring(%__MODULE__{} = t) do
    {:bitstring, {t.in_alarm, t.fault, t.overridden, t.out_of_service}}
  end

  @doc """
  Validates whether the given status flags is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          in_alarm: alarm,
          fault: fault,
          overridden: overridden,
          out_of_service: out
        } = _t
      )
      when is_boolean(alarm) and is_boolean(fault) and is_boolean(overridden) and is_boolean(out),
      do: true

  def valid?(%__MODULE__{} = _t), do: false
end
