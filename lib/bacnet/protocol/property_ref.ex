defmodule BACnet.Protocol.PropertyRef do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @type t :: %__MODULE__{
          property_identifier: Constants.property_identifier() | non_neg_integer(),
          property_array_index: non_neg_integer() | nil
        }

  @fields [
    :property_identifier,
    :property_array_index
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet property reference into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = ref, opts \\ []) do
    with {:ok, propident, _header} <-
           ApplicationTags.encode_value(
             {:enumerated, Constants.by_name_atom(:property_identifier, ref.property_identifier)},
             opts
           ),
         {:ok, propindex, _header} <-
           (if ref.property_array_index do
              ApplicationTags.encode_value({:unsigned_integer, ref.property_array_index}, opts)
            else
              {:ok, nil, nil}
            end) do
      base = [
        tagged: {0, propident, byte_size(propident)},
        tagged: {1, propindex, byte_size(propindex || <<>>)}
      ]

      {:ok, Enum.filter(base, fn {_type, {_t, con, _l}} -> con end)}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parses a BACnet property reference into a struct.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, property_identifier, ref} <-
           pattern_extract_tags(tags, {:tagged, {0, _t, _l}}, :enumerated, false),
         {:ok, prop_array_index, rest} <-
           pattern_extract_tags(ref, {:tagged, {1, _t, _l}}, :unsigned_integer, true) do
      objref = %__MODULE__{
        property_identifier:
          Constants.by_value(:property_identifier, property_identifier, property_identifier),
        property_array_index: prop_array_index
      }

      {:ok, {objref, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given property reference is in form valid.

  It only validates the struct is valid as per type specification.
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
