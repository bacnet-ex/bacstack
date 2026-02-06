defmodule BACnet.Protocol.StatusFlags do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Represents the BACnet Status Flags.

  The `IN_ALARM` flag is set, if the Event State is not normal.

  The `FAULT` flag is set, if the reliability has detected a fault.

  The `OVERRIDDEN` flag is set, if the output has been overridden by some sort
  of BACnet device local mechanism.

  The `OUT_OF_SERVICE` flag is set, if the Out Of Service property is set.
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
