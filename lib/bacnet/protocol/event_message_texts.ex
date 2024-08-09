defmodule BACnet.Protocol.EventMessageTexts do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @type t :: %__MODULE__{
          to_offnormal: String.t(),
          to_fault: String.t(),
          to_normal: String.t()
        }

  @fields [:to_offnormal, :to_fault, :to_normal]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet event message texts (BACnetArray[3] of CharacterString) into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = texts, _opts \\ []) do
    params = [
      {:character_string, texts.to_offnormal},
      {:character_string, texts.to_fault},
      {:character_string, texts.to_normal}
    ]

    {:ok, params}
  end

  @doc """
  Parses a BACnet event message texts (BACnetArray[3] of CharacterString) from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:character_string, to_offnormal},
        {:character_string, to_fault},
        {:character_string, to_normal}
        | rest
      ] ->
        texts = %__MODULE__{
          to_offnormal: to_offnormal,
          to_fault: to_fault,
          to_normal: to_normal
        }

        {:ok, {texts, rest}}

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given event message texts is in form valid.

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
      when is_binary(to_offnormal) and is_binary(to_fault) and is_binary(to_normal),
      do: true

  def valid?(%__MODULE__{} = _t), do: false
end
