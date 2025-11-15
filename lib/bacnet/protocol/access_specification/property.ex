defmodule BACnet.Protocol.AccessSpecification.Property do
  # TODO: Docs
  # if property_value = nil, then read access specification

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil,
          property_value: Encoding.t() | nil
        }

  @fields [
    :property_identifier,
    :property_array_index,
    :property_value
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet Read/Write Access Specification Property into BACnet application tags encoding.
  """
  @spec encode(t() | :all | :required | :optional, Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(property, opts \\ [])

  def encode(property, _opts) when property in [:all, :required, :optional] do
    with {:ok, property, _header} <-
           ApplicationTags.encode_value(
             {:enumerated, Constants.by_name!(:property_identifier, property)}
           ) do
      {:ok, [{:tagged, {0, property, byte_size(property)}}]}
    end
  end

  def encode(%__MODULE__{} = property, _opts) do
    with {:ok, property_identifier, _header} <-
           ApplicationTags.encode_value(
             {:enumerated,
              Constants.by_name_atom(:property_identifier, property.property_identifier)}
           ),
         {:ok, array_index} <-
           (if property.property_array_index do
              case ApplicationTags.encode_value(
                     {:unsigned_integer, property.property_array_index}
                   ) do
                {:ok, array_index, _header} ->
                  {:ok, {:tagged, {1, array_index, byte_size(array_index)}}}

                term ->
                  term
              end
            else
              {:ok, nil}
            end),
         {:ok, prop_value} <-
           (if property.property_value do
              with {:ok, base} <- Encoding.to_encoding(property.property_value) do
                {:ok, {:constructed, {2, base, 0}}}
              end
            else
              {:ok, nil}
            end) do
      params = [
        {:tagged, {0, property_identifier, byte_size(property_identifier)}},
        array_index,
        prop_value
      ]

      {:ok, Enum.reject(params, &is_nil/1)}
    end
  end

  @doc """
  Parses a BACnet Read/Write Access Specification Property from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t() | :all | :required | :optional, rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, property_identifier, rest} <-
           pattern_extract_tags(tags, {:tagged, {0, _t, _l}}, :enumerated, false),
         {:ok, property_array_index, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :unsigned_integer, true),
         {:ok, prop_value, rest} <-
           pattern_extract_tags(rest, {:constructed, {2, _t, _l}}, nil, true) do
      item =
        case Constants.by_value(
               :property_identifier,
               property_identifier,
               property_identifier
             ) do
          propident when propident in [:all, :required, :optional] ->
            propident

          propident ->
            %__MODULE__{
              property_identifier: propident,
              property_array_index: property_array_index,
              property_value:
                case prop_value do
                  {:constructed, {2, tag, _len}} -> Encoding.create!(tag)
                  _else -> nil
                end
            }
        end

      {:ok, {item, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given access specification property is in form valid.

  It only validates the struct is valid as per type specification.

  Be aware, this function does not know whether it is a read or
  write access specification, thus it can't verify if the special
  property identifiers (atoms) are as per BACnet specification.
  Only read supports the special property identifiers.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          property_identifier: prop_identifier,
          property_array_index: array_index
        } = _t
      ) do
    (Constants.has_by_name(:property_identifier, prop_identifier) or
       (is_integer(prop_identifier) and prop_identifier >= 0 and
          prop_identifier <= Constants.macro_by_name(:asn1, :max_instance_and_property_id))) and
      (is_nil(array_index) or (is_integer(array_index) and array_index >= 0))
  end
end
