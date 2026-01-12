defmodule BACnet.Protocol.BACnetError do
  # TODO: Docs
  # TODO: Validate class and code combination
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  @typedoc """
  Represents a casual BACnet Error.

  To allow forward compatibility, each field can be an integer.
  """
  @type t :: %__MODULE__{
          class: Constants.error_class() | non_neg_integer(),
          code: Constants.error_code() | non_neg_integer()
        }

  @fields [
    :class,
    :code
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet error into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(
        %__MODULE__{} = error,
        _opts \\ []
      ) do
    params = [
      enumerated: Constants.by_name_atom(:error_class, error.class),
      enumerated: Constants.by_name_atom(:error_code, error.code)
    ]

    {:ok, params}
  end

  @doc """
  Parses a BACnet error from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:enumerated, class},
        {:enumerated, code}
        | rest
      ] ->
        error = %__MODULE__{
          class: Constants.by_value(:error_class, class, class),
          code: Constants.by_value(:error_code, code, code)
        }

        {:ok, {error, rest}}

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given status flags is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          class: class,
          code: code
        } = _t
      ) do
    (Constants.has_by_name(:error_class, class) or
       (is_integer(class) and class >= 0 and class <= 65_535)) and
      (Constants.has_by_name(:error_code, code) or
         (is_integer(code) and code >= 0 and code <= 65_535))
  end
end
