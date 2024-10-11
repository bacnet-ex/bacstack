defmodule BACnet.Protocol.ObjectIdentifier do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  require Constants

  @type t :: %__MODULE__{
          type: Constants.object_type(),
          instance: non_neg_integer()
        }

  @fields [
    :type,
    :instance
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes an object identifier into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = id, _opts \\ []) do
    {:ok, [{:object_identifier, id}]}
  end

  @doc """
  Parses the number and retrieves the object identifier from an object identifier number.

  The object identifier number is a 32bit non-negative integer
  which consists of a 10bit object type number and 22bit instance number.
  """
  @spec from_number(non_neg_integer()) :: {:ok, t()} | {:error, term()}
  def from_number(number) when is_integer(number) and number >= 0 do
    ApplicationTags.decode_value(
      Constants.macro_by_name(:application_tag, :object_identifier),
      <<number::size(32)>>
    )
  end

  @doc """
  Parses an object identifier from application tags encoding.

  There's actually nothing special that needs to be done here, it just unwraps
  and gets the `{:object_identifier, t()}` tuple from the head of the tags list.
  The conversion is already handled by `ApplicationTags`.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:object_identifier, %__MODULE__{} = id} | rest] -> {:ok, {id, rest}}
      _else -> {:error, :invalid_tags}
    end
  end

  @doc """
  Converts the struct into an object identifier number.

  The object identifier number is a 32bit non-negative integer
  which consists of a 10bit object type number and 22bit instance number.
  """
  @spec to_number(t()) :: non_neg_integer()
  def to_number(%__MODULE__{} = t) do
    Bitwise.bor(Bitwise.bsl(Constants.by_name!(:object_type, t.type), 22), t.instance)
  end

  @doc """
  Validates whether the given object identifier is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = t) do
    Constants.has_by_name(:object_type, t.type) and is_integer(t.instance) and t.instance >= 0 and
      t.instance <= Constants.macro_by_name(:asn1, :max_instance_and_property_id)
  end
end
