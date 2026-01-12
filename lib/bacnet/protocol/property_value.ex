defmodule BACnet.Protocol.PropertyValue do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil,
          property_value: ApplicationTags.Encoding.t(),
          priority: 1..16 | nil
        }

  @fields [
    :property_identifier,
    :property_array_index,
    :property_value,
    :priority
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet property value into application tags encoding.
  """
  @spec encode(t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = property, opts \\ []) do
    with {:ok, propident, _header} <-
           ApplicationTags.encode_value(
             {:enumerated,
              Constants.by_name_atom(:property_identifier, property.property_identifier)},
             opts
           ),
         {:ok, propindex, _header} <-
           (if property.property_array_index do
              ApplicationTags.encode_value(
                {:unsigned_integer, property.property_array_index},
                opts
              )
            else
              {:ok, nil, nil}
            end),
         {:ok, value} <- ApplicationTags.Encoding.to_encoding(property.property_value),
         {:ok, priority, _header} <-
           (if property.priority do
              ApplicationTags.encode_value({:unsigned_integer, property.priority}, opts)
            else
              {:ok, nil, nil}
            end) do
      list =
        Enum.reduce(
          [{3, priority}, {2, value}, {1, propindex}, {0, propident}],
          [],
          fn
            {_tag, nil}, acc ->
              acc

            {2, element}, acc ->
              [{:constructed, {2, element, 0}} | acc]

            {tag, element}, acc ->
              [{:tagged, {tag, element, byte_size(element)}} | acc]
          end
        )

      {:ok, list}
    else
      {:error, _term} = term -> term
    end
  end

  @doc """
  Encode a list of property values into application tag-encoded property values.
  """
  @spec encode_all([t()], Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode_all(properties, opts \\ []) when is_list(properties) do
    result =
      Enum.reduce_while(properties, {:ok, []}, fn
        %__MODULE__{} = prop, {:ok, acc} ->
          case encode(prop, opts) do
            {:ok, enc} -> {:cont, {:ok, [enc | acc]}}
            term -> {:halt, term}
          end

        _prop, _acc ->
          {:halt, {:error, :invalid_list_element}}
      end)

    case result do
      {:ok, list} ->
        new_list =
          list
          |> Enum.reverse()
          |> List.flatten()

        {:ok, new_list}

      term ->
        term
    end
  end

  @doc """
  Parse application tag-encoded property value into a struct.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, property_identifier, prop} <-
           pattern_extract_tags(tags, {:tagged, {0, _t, _l}}, :enumerated, false),
         {:ok, prop_array_index, prop} <-
           pattern_extract_tags(prop, {:tagged, {1, _t, _l}}, :unsigned_integer, true),
         {:ok, {:constructed, {2, value, _l}}, prop} <-
           pattern_extract_tags(prop, {:constructed, {2, _t, _l}}, nil, false),
         {:ok, priority, rest} <-
           pattern_extract_tags(prop, {:tagged, {3, _t, _l}}, :unsigned_integer, true) do
      propvalue = %__MODULE__{
        property_identifier:
          Constants.by_value(:property_identifier, property_identifier, property_identifier),
        property_array_index: prop_array_index,
        property_value: ApplicationTags.Encoding.create!(value),
        priority: priority
      }

      {:ok, {propvalue, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parse application tag-encoded property values into a list of structs.
  """
  @spec parse_all(ApplicationTags.encoding_list()) ::
          {:ok, [t()]} | {:error, term()}
  def parse_all(tags) when is_list(tags) do
    result =
      Enum.reduce_while(1..100_000//1, {tags, []}, fn
        _iter, {tags, acc} ->
          case parse(tags) do
            {:ok, {item, []}} -> {:halt, {:ok, {nil, [item | acc]}}}
            {:ok, {item, rest}} -> {:cont, {rest, [item | acc]}}
            {:error, _err} = err -> {:halt, err}
          end
      end)

    case result do
      {:ok, {_rest, list}} -> {:ok, Enum.reverse(list)}
      term -> term
    end
  end

  @doc """
  Validates whether the given property value is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          property_identifier: prop_identifier,
          property_array_index: array_index,
          property_value: %ApplicationTags.Encoding{},
          priority: priority
        } = _t
      )
      when is_nil(priority) or priority in 1..16 do
    (Constants.has_by_name(:property_identifier, prop_identifier) or
       (is_integer(prop_identifier) and prop_identifier >= 0 and
          prop_identifier <= Constants.macro_by_name(:asn1, :max_instance_and_property_id))) and
      (is_nil(array_index) or (is_integer(array_index) and array_index >= 0))
  end

  def valid?(%__MODULE__{} = _t), do: false
end
