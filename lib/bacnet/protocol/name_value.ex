defmodule BACnet.Protocol.NameValue do
  @moduledoc """
  BACnetNameValue is a structure used primarily for the `Tags` property
  (of type BACnetARRAY of BACnetNameValue) that exists on nearly every
  standardized BACnet object type (ASHRAE 135-2016 Clause 12.x and Annex Y).

  Each entry associates a name (CharacterString) with an optional value.
  When the value is absent the tag is considered a "semantic tag".

  The value, when present, is limited to any primitive BACnet datatype
  or BACnetDateTime.

  ### ASN.1 (ASHRAE 135-2016)

      BACnetNameValue ::= SEQUENCE {
        name  [0] CharacterString,
        value ABSTRACT-SYNTAX.&Type OPTIONAL
          -- value is limited to primitive datatypes and BACnetDateTime
      }
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Utility

  import Utility, only: [pattern_extract_tags: 4]

  @typedoc """
  A single BACnetNameValue entry.

  Only primitive `Encoding` or `BACnetDateTime` are allowed as value.
  """
  @type t :: %__MODULE__{
          name: String.t(),
          value: Encoding.t() | BACnetDateTime.t() | nil
        }

  @fields [:name, :value]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Parses a BACnetNameValue from application tags encoding (context tagged elements).
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, name, rest} <-
           pattern_extract_tags(tags, {:tagged, {0, _val, _len}}, :character_string, false),
         {:ok, {value, rest}} <-
           (case rest do
              [{:date, _date}, {:time, _time} | _rest] ->
                BACnetDateTime.parse(rest)

              [value | rest] ->
                case Encoding.create(value) do
                  {:ok, %Encoding{encoding: :primitive} = enc} -> {:ok, {enc, rest}}
                  {:ok, _other} -> {:error, :invalid_value}
                  other -> other
                end

              _other ->
                {:ok, {nil, rest}}
            end) do
      nv = %__MODULE__{name: name, value: value}
      {:ok, {nv, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Encodes a BACnetNameValue into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{name: name, value: value}, _opts \\ []) do
    with true <- is_binary(name) and byte_size(name) > 0,
         {:ok, name_tag} <- ApplicationTags.create_tag_encoding(0, :character_string, name) do
      case value do
        nil ->
          {:ok, [name_tag]}

        %BACnetDateTime{} ->
          with {:ok, value_tag} <- BACnetDateTime.encode(value) do
            {:ok, [name_tag | value_tag]}
          end

        %Encoding{encoding: :primitive} ->
          with {:ok, value_tag} <- Encoding.to_encoding(value) do
            {:ok, [name_tag, value_tag]}
          end

        _other ->
          {:error, :invalid_value}
      end
    else
      false -> {:error, :invalid_name}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Returns true if the NameValue struct contains a valid name and (optionally) a
  well-formed value of a supported type.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{name: name, value: value} = _t)
      when is_binary(name) and byte_size(name) > 0 do
    case value do
      nil -> true
      %BACnetDateTime{} -> true
      %Encoding{encoding: :primitive} -> true
      _other -> false
    end
  end

  def valid?(%__MODULE__{} = _tag), do: false
end
