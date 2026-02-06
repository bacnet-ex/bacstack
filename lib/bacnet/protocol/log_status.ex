defmodule BACnet.Protocol.LogStatus do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @type t :: %__MODULE__{
          log_disabled: boolean(),
          buffer_purged: boolean(),
          log_interrupted: boolean()
        }

  @fields [
    :log_disabled,
    :buffer_purged,
    :log_interrupted
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet log status into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = flags, _opts \\ []) do
    {:ok, [to_bitstring(flags)]}
  end

  @doc """
  Creates from an application tag bitstring a log status.
  """
  @spec from_bitstring({boolean(), boolean()} | {boolean(), boolean(), boolean()}) :: t()
  def from_bitstring(bitstring)

  def from_bitstring(bitstring) when is_tuple(bitstring) and tuple_size(bitstring) == 2 do
    %__MODULE__{
      log_disabled: elem(bitstring, 0),
      buffer_purged: elem(bitstring, 1),
      log_interrupted: false
    }
  end

  def from_bitstring(bitstring) when is_tuple(bitstring) and tuple_size(bitstring) == 3 do
    %__MODULE__{
      log_disabled: elem(bitstring, 0),
      buffer_purged: elem(bitstring, 1),
      log_interrupted: elem(bitstring, 2)
    }
  end

  @doc """
  Parses a BACnet log status from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:bitstring, {_b1, _b2} = bs} | rest] -> {:ok, {from_bitstring(bs), rest}}
      [{:bitstring, {_b1, _b2, _b3} = bs} | rest] -> {:ok, {from_bitstring(bs), rest}}
      _else -> {:error, :invalid_tags}
    end
  end

  @doc """
  Creates an application tag bitstring from a log status.
  """
  @spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
  def to_bitstring(%__MODULE__{} = t) do
    {:bitstring, {t.log_disabled, t.buffer_purged, t.log_interrupted}}
  end

  @doc """
  Validates whether the given log status is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          log_disabled: log_disabled,
          buffer_purged: buffer_purged,
          log_interrupted: log_interrupted
        } = _t
      )
      when is_boolean(log_disabled) and is_boolean(buffer_purged) and is_boolean(log_interrupted),
      do: true

  def valid?(%__MODULE__{} = _t), do: false
end
