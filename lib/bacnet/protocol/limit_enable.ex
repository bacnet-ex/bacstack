defmodule BACnet.Protocol.LimitEnable do
  @moduledoc """
  BACnet Limit Enable conveys several flags that describe the enabled limit detection algorithms.

  * The LOW_LIMIT_ENABLE flag indicates whether the low limit detection algorithm is enabled.
  * The HIGH_LIMIT_ENABLE flag indicates whether the high limit detection algorithm is enabled.
  """

  alias BACnet.Protocol.ApplicationTags

  # TODO: Throw argument error in encode if not valid

  @typedoc """
  Represents BACnet limit enable flags.
  """
  @type t :: %__MODULE__{
          low_limit_enable: boolean(),
          high_limit_enable: boolean()
        }

  @fields [
    :low_limit_enable,
    :high_limit_enable
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet limit enable into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = flags, _opts \\ []) do
    {:ok, [to_bitstring(flags)]}
  end

  @doc """
  Creates from an application tag bitstring a limit enable.
  """
  @spec from_bitstring(tuple()) :: t()
  def from_bitstring(bitstring) when is_tuple(bitstring) and tuple_size(bitstring) == 2 do
    %__MODULE__{
      low_limit_enable: elem(bitstring, 0),
      high_limit_enable: elem(bitstring, 1)
    }
  end

  @doc """
  Parses a BACnet limit enable from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:bitstring, {_b1, _b2} = bs} | rest] -> {:ok, {from_bitstring(bs), rest}}
      _else -> {:error, :invalid_tags}
    end
  end

  @doc """
  Creates an application tag bitstring from a limit enable.
  """
  @spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
  def to_bitstring(%__MODULE__{} = t) do
    {:bitstring, {t.low_limit_enable, t.high_limit_enable}}
  end

  @doc """
  Validates whether the given limit enable is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          low_limit_enable: low_limit,
          high_limit_enable: high_limit
        } = _t
      )
      when is_boolean(low_limit) and is_boolean(high_limit),
      do: true

  def valid?(%__MODULE__{} = _t), do: false
end
