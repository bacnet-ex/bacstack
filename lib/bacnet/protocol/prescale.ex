defmodule BACnet.Protocol.Prescale do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @type t :: %__MODULE__{
          multiplier: non_neg_integer(),
          modulo_divide: non_neg_integer()
        }

  @fields [
    :multiplier,
    :modulo_divide
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet prescale into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = prescale, opts \\ []) do
    with {:ok, multiplier, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, prescale.multiplier}, opts),
         {:ok, modulo, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, prescale.modulo_divide}, opts) do
      {:ok,
       [
         tagged: {0, multiplier, byte_size(multiplier)},
         tagged: {1, modulo, byte_size(modulo)}
       ]}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parses a BACnet prescale from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, multiplier, rest} <-
           pattern_extract_tags(tags, {:tagged, {0, _t, _l}}, :unsigned_integer, false),
         {:ok, modulo, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :unsigned_integer, false) do
      prescale = %__MODULE__{
        multiplier: multiplier,
        modulo_divide: modulo
      }

      {:ok, {prescale, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given prescale is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          multiplier: multiplier,
          modulo_divide: modulo_divide
        } = _t
      )
      when is_integer(multiplier) and multiplier >= 0 and is_integer(modulo_divide) and
             modulo_divide >= 0,
      do: true

  def valid?(%__MODULE__{} = _t), do: false
end
