defmodule BACnet.Protocol.EventTransitionBits do
  @moduledoc """
  Event Transition Bits is a three-bit bit string used throughout the BACnet event
  and alarm model. Each bit corresponds to one of the three possible state
  transitions an object can make:

  | Bit | Transition     | Meaning (when TRUE)                       |
  |-----|----------------|:------------------------------------------|
  | 0   | TO_OFFNORMAL   | Transition into an off-normal event state |
  | 1   | TO_FAULT       | Transition into a fault event state       |
  | 2   | TO_NORMAL      | Transition back to the normal state       |

  **Primary uses**:
  - `Event_Enable` property - which transitions should generate notifications
  - `Acked_Transitions` - which transitions still require operator acknowledgment
  - Various alarm/event summary services and notification parameters

  The bit positions and semantics are identical for intrinsic reporting,
  algorithmic reporting, and all the summary/notification services.

  ### BACnet Specification References

  - **ASN.1** (Clause 21):
    `BACnetEventTransitionBits ::= BIT STRING { to-offnormal (0), to-fault (1), to-normal (2) }`
  - **Object properties** (Clause 12): `event_enable`, `acked_transitions`,
    `event_time_stamps`, etc.
  - **Services**: GetAlarmSummary, GetEventInformation, Confirmed/UnconfirmedEventNotification.

  ### Examples (Doc Test)

  ```elixir
  iex> bits = %EventTransitionBits{to_offnormal: true, to_fault: true, to_normal: false}
  iex> bits.to_offnormal
  true
  ```

  ### See Also
  - `BACnet.Protocol.NotificationParameters`
  - `BACnet.Protocol.StatusFlags`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Represents a bit string indicating which event state transitions are of interest
  (to-offnormal, to-fault, to-normal).
  """
  @type t :: %__MODULE__{
          to_offnormal: boolean(),
          to_fault: boolean(),
          to_normal: boolean()
        }

  @fields [:to_offnormal, :to_fault, :to_normal]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet event transition bits into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = flags, _opts \\ []) do
    {:ok, [to_bitstring(flags)]}
  end

  @doc """
  Creates from an application tag bitstring an event transition bits.
  """
  @spec from_bitstring(tuple()) :: t()
  def from_bitstring(bitstring) when is_tuple(bitstring) and tuple_size(bitstring) == 3 do
    %__MODULE__{
      to_offnormal: elem(bitstring, 0),
      to_fault: elem(bitstring, 1),
      to_normal: elem(bitstring, 2)
    }
  end

  @doc """
  Parses a BACnet event transition bits from application tags encoding.
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
  Creates an application tag bitstring from an event transition bits.
  """
  @spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
  def to_bitstring(%__MODULE__{} = t) do
    {:bitstring, {t.to_offnormal, t.to_fault, t.to_normal}}
  end

  @doc """
  Validates whether the given event transition bits is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          to_offnormal: to_offnormal,
          to_fault: to_fault,
          to_normal: to_normal
        } = _t
      )
      when is_boolean(to_offnormal) and is_boolean(to_fault) and is_boolean(to_normal),
      do: true

  def valid?(%__MODULE__{} = _t), do: false
end
