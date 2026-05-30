defmodule BACnet.Protocol.Prescale do
  @moduledoc """
  A Prescale is a simple multiplier / modulo-divide pair used by Accumulator objects
  to scale the raw pulse count coming from a physical meter into the engineering units
  that the present value property should report.

  The multiplier is applied first, then the result is divided by the modulo_divide
  value (the remainder is discarded). This two-stage scaling allows devices to
  represent both fractional pulses (for example, a meter that produces one pulse
  per 0.1 kWh) and to handle situations where the display on the physical meter
  rolls over at a different point than the internal counter.

  The structure exists because many real-world utility meters do not produce
  pulses that directly correspond to the desired engineering units. By exposing
  the scaling factors as readable and writable properties, BACnet makes it
  possible to commission or reconfigure pulse scaling without changing firmware.

  ### Examples (Doc Test)

  ```elixir
  iex> scale = %Prescale{multiplier: 10, modulo_divide: 1000}
  iex> scale.multiplier
  10
  ```
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @typedoc """
  Represents the prescaling factors used by Accumulator objects.
  """
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
