defmodule BACnet.Protocol.SecureConnect.Sequence do
  @moduledoc """
  Implements the shared context-tag encoding for BACnet/SC status sequences.

  Each sequence declares its fields in wire order. Their positions determine
  the context tag numbers. Optional fields can be omitted without changing the
  tag numbers of the fields that follow. The structs represent omitted
  values with `nil`. Constructed fields delegate to the existing BACnet
  encoders for timestamps, errors, and addresses.

  The parser consumes one sequence and returns the remaining tags. This lets
  Network Port properties carry lists of connection and failure records.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.HostNPort

  @typep field :: {atom(), field_type()}
  @typep field_type :: atom() | {:optional, atom()}

  @doc """
  Adds `encode/1` and `parse/1` to a sequence struct using the supplied
  ordered field definitions.
  """
  @spec __using__(Keyword.t()) :: Macro.t()
  defmacro __using__(fields: fields) do
    quote do
      @sequence_fields unquote(fields)

      @doc """
      Encodes the status record into its context-tagged BACnet representation.
      """
      @spec encode(t()) ::
              {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
      def encode(%__MODULE__{} = value) do
        BACnet.Protocol.SecureConnect.Sequence.encode(value, @sequence_fields)
      end

      @doc """
      Parses one status record and returns any tags belonging to subsequent values.
      """
      @spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
              {:ok, {t(), BACnet.Protocol.ApplicationTags.encoding_list()}} | {:error, term()}
      def parse(tags) do
        BACnet.Protocol.SecureConnect.Sequence.parse(__MODULE__, tags, @sequence_fields)
      end
    end
  end

  @doc """
  Encodes a struct according to its field definitions, omitting absent
  optional fields.
  """
  @spec encode(struct(), [field()]) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(value, fields) do
    result =
      fields
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, []}, fn {{key, spec}, index}, {:ok, acc} ->
        case encode_field(index, spec, Map.fetch!(value, key)) do
          {:ok, nil} -> {:cont, {:ok, acc}}
          {:ok, tag} -> {:cont, {:ok, [tag | acc]}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)

    case result do
      {:ok, tags} -> {:ok, Enum.reverse(tags)}
      error -> error
    end
  end

  @doc """
  Parses one sequence into the requested struct and returns the unconsumed
  tags so callers can continue decoding a list of sequences.
  """
  @spec parse(module(), ApplicationTags.encoding_list(), [field()]) ::
          {:ok, {struct(), ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(module, tags, fields) do
    result =
      fields
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, %{}, tags}, fn
        {{key, spec}, index}, {:ok, value, rest} ->
          case parse_field(index, spec, rest) do
            {:ok, field_value, rest} -> {:cont, {:ok, Map.put(value, key, field_value), rest}}
            {:error, _reason} = error -> {:halt, error}
          end
      end)

    case result do
      {:ok, value, rest} -> {:ok, {struct!(module, value), rest}}
      error -> error
    end
  end

  @spec encode_field(non_neg_integer(), field_type(), term()) ::
          {:ok, ApplicationTags.encoding() | nil} | {:error, term()}
  defp encode_field(_index, {:optional, _type}, nil), do: {:ok, nil}
  defp encode_field(index, {:optional, type}, value), do: encode_field(index, type, value)

  defp encode_field(index, :property_identifier, value) do
    encode_field(index, :enumerated, Constants.by_name_atom(:property_identifier, value))
  end

  defp encode_field(index, type, %type{} = value)
       when type in [BACnetDateTime, BACnetError, HostNPort] do
    with {:ok, tags} <- type.encode(value), do: {:ok, {:constructed, {index, tags, 0}}}
  end

  defp encode_field(_index, type, _value) when type in [BACnetDateTime, BACnetError, HostNPort],
    do: {:error, :invalid_value}

  defp encode_field(index, type, value),
    do: ApplicationTags.create_tag_encoding(index, type, value)

  @spec parse_field(non_neg_integer(), field_type(), ApplicationTags.encoding_list()) ::
          {:ok, term(), ApplicationTags.encoding_list()} | {:error, term()}
  defp parse_field(index, {:optional, type}, [tag | _rest] = tags)
       when elem(elem(tag, 1), 0) == index and elem(tag, 0) in [:tagged, :constructed],
       do: parse_field(index, type, tags)

  defp parse_field(_index, {:optional, _type}, tags), do: {:ok, nil, tags}

  defp parse_field(index, :property_identifier, tags) do
    with {:ok, value, rest} <- parse_field(index, :enumerated, tags) do
      {:ok, Constants.by_value(:property_identifier, value, value), rest}
    end
  end

  defp parse_field(index, type, [{:constructed, {index, fields, _length}} | rest])
       when type in [BACnetDateTime, BACnetError, HostNPort] do
    case type.parse(List.wrap(fields)) do
      {:ok, {value, []}} -> {:ok, value, rest}
      _other -> {:error, :invalid_tags}
    end
  end

  defp parse_field(index, type, [{:tagged, {index, data, _length}} | rest]) do
    with {:ok, {^type, value}} <- ApplicationTags.unfold_to_type(type, data),
         do: {:ok, value, rest}
  end

  defp parse_field(_index, _type, _tags), do: {:error, :invalid_tags}
end
