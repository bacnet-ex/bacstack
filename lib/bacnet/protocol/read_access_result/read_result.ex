defmodule BACnet.Protocol.ReadAccessResult.ReadResult do
  # TODO: Docs

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.Constants

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil,
          property_value: Encoding.t() | [Encoding.t()] | nil,
          error: BACnetError.t() | nil
        }

  @fields [
    :property_identifier,
    :property_array_index,
    :property_value,
    :error
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet Read Access Result Read Result into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = result, _opts \\ []) do
    with {:ok, property_identifier, _header} <-
           ApplicationTags.encode_value(
             {:enumerated,
              Constants.by_name_atom(:property_identifier, result.property_identifier)}
           ),
         {:ok, array_index} <-
           (if result.property_array_index do
              with {:ok, index, _header} <-
                     ApplicationTags.encode_value(
                       {:unsigned_integer, result.property_array_index}
                     ),
                   do: {:ok, {:tagged, {3, index, byte_size(index)}}}
            else
              {:ok, nil}
            end),
         {:ok, prop_value} <-
           (cond do
              is_list(result.property_value) ->
                res =
                  Enum.reduce_while(result.property_value, {:ok, []}, fn item, {:ok, acc} ->
                    case Encoding.to_encoding(item) do
                      {:ok, encoding} -> {:cont, {:ok, [encoding | acc]}}
                      term -> {:halt, term}
                    end
                  end)

                case res do
                  {:ok, list} -> {:ok, {:constructed, {4, Enum.reverse(list), 0}}}
                  term -> term
                end

              result.property_value ->
                with {:ok, value} <-
                       Encoding.to_encoding(result.property_value),
                     do: {:ok, {:constructed, {4, value, 0}}}

              true ->
                {:ok, nil}
            end),
         {:ok, error} <-
           (if result.error do
              {:ok,
               {:constructed,
                {5,
                 [
                   enumerated: Constants.by_name_atom(:error_class, result.error.class),
                   enumerated: Constants.by_name_atom(:error_code, result.error.code)
                 ], 0}}}
            else
              {:ok, nil}
            end),
         :ok <-
           (if prop_value == nil and error == nil do
              {:error, :invalid_value_and_error}
            else
              :ok
            end) do
      params = [
        {:tagged, {2, property_identifier, byte_size(property_identifier)}},
        array_index,
        prop_value,
        error
      ]

      {:ok, Enum.reject(params, &is_nil/1)}
    end
  end

  @doc """
  Parses a BACnet Read Access Result Read Result from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, property, rest} <-
           pattern_extract_tags(tags, {:tagged, {2, _t, _l}}, :enumerated, false),
         {:ok, array_index, rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _t, _l}}, :unsigned_integer, true),
         {:ok, value, rest} <-
           pattern_extract_tags(
             rest,
             {:constructed, {4, _t, _l}},
             fn {:constructed, {4, value, 0}} -> {:ok, value} end,
             true
           ),
         {:ok, error_raw, rest} <-
           pattern_extract_tags(rest, {:constructed, {5, _t, _l}}, nil, true),
         {:ok, error} <- create_error(error_raw),
         :ok <-
           (if value == nil and error == nil do
              {:error, :invalid_value_and_error}
            else
              :ok
            end) do
      result = %__MODULE__{
        property_identifier: Constants.by_value(:property_identifier, property, property),
        property_array_index: array_index,
        property_value:
          cond do
            is_list(value) -> Enum.map(value, &Encoding.create!/1)
            value -> Encoding.create!(value)
            true -> nil
          end,
        error: error
      }

      {:ok, {result, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given read access read result is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          property_identifier: prop_identifier,
          property_array_index: array_index,
          property_value: value,
          error: nil
        } = _t
      )
      when is_list(value) do
    (Constants.has_by_name(:property_identifier, prop_identifier) or
       (is_integer(prop_identifier) and prop_identifier >= 0 and
          prop_identifier <= Constants.macro_by_name(:asn1, :max_instance_and_property_id))) and
      (is_nil(array_index) or (is_integer(array_index) and array_index >= 0)) and
      Enum.all?(value, &is_struct(&1, Encoding))
  end

  def valid?(
        %__MODULE__{
          property_identifier: prop_identifier,
          property_array_index: array_index,
          property_value: %Encoding{},
          error: nil
        } = _t
      ) do
    (Constants.has_by_name(:property_identifier, prop_identifier) or
       (is_integer(prop_identifier) and prop_identifier >= 0 and
          prop_identifier <= Constants.macro_by_name(:asn1, :max_instance_and_property_id))) and
      (is_nil(array_index) or (is_integer(array_index) and array_index >= 0))
  end

  def valid?(
        %__MODULE__{
          property_identifier: prop_identifier,
          property_array_index: array_index,
          property_value: nil,
          error: %BACnetError{} = error
        } = _t
      ) do
    (Constants.has_by_name(:property_identifier, prop_identifier) or
       (is_integer(prop_identifier) and prop_identifier >= 0 and
          prop_identifier <= Constants.macro_by_name(:asn1, :max_instance_and_property_id))) and
      (is_nil(array_index) or (is_integer(array_index) and array_index >= 0)) and
      BACnetError.valid?(error)
  end

  def valid?(%__MODULE__{} = _t), do: false

  defp create_error(nil), do: {:ok, nil}

  defp create_error({:constructed, {5, error, _len}}) do
    with {:ok, {err, []}} <- BACnetError.parse(error) do
      {:ok, err}
    else
      {:error, _err} = err -> err
    end
  end
end
