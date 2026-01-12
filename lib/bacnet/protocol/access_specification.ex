defmodule BACnet.Protocol.AccessSpecification do
  @moduledoc """
  Represents BACnet Access Specification, used in BACnet `Read-Property-Multiple` and `Write-Property-Multiple`,
  as Read Access Specification and Write Access Specification, respectively.
  """

  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.AccessSpecification.Property
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ObjectIdentifier

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @type t :: %__MODULE__{
          object_identifier: ObjectIdentifier.t(),
          properties: [Property.t() | :all | :required | :optional]
        }

  @fields [
    :object_identifier,
    :properties
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet Read/Write Access Specification into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(
        %__MODULE__{object_identifier: %ObjectIdentifier{}} = access_spec,
        _opts \\ []
      ) do
    with {:ok, object_identifier, _header} <-
           ApplicationTags.encode_value({:object_identifier, access_spec.object_identifier}),
         {:ok, properties} <- encode_access_spec_property_list(access_spec.properties) do
      params = [
        {:tagged, {0, object_identifier, byte_size(object_identifier)}},
        {:constructed, {1, properties, 0}}
      ]

      {:ok, params}
    end
  end

  @doc """
  Parses a BACnet Read/Write Access Specification from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, object, rest} <-
           pattern_extract_tags(
             tags,
             {:tagged, {0, _t, _l}},
             :object_identifier,
             false
           ),
         {:ok, {:constructed, {1, proplist, _len}}, rest} <-
           pattern_extract_tags(
             rest,
             {:constructed, {1, _t, _l}},
             nil,
             false
           ),
         {:ok, properties} <- parse_access_spec_property_list(proplist) do
      access_spec = %__MODULE__{
        object_identifier: object,
        properties: properties
      }

      {:ok, {access_spec, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given access specification is in form valid.

  It only validates the struct is valid as per type specification.

  Be aware, this function does not know whether it is a read or
  write access specification, thus it can't verify if the special
  property identifiers (atoms) are as per BACnet specification.
  Only read supports the special property identifiers.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          object_identifier: %ObjectIdentifier{} = obj,
          properties: [_props | _tl] = props
        } = _t
      ) do
    ObjectIdentifier.valid?(obj) and
      Enum.all?(props, fn
        :all -> true
        :required -> true
        :optional -> true
        %Property{} = prop -> Property.valid?(prop)
        _else -> false
      end)
  end

  def valid?(%__MODULE__{} = _t), do: false

  defp parse_access_spec_property_list(tags) do
    result =
      Enum.reduce_while(1..8192//1, {tags, []}, fn
        _iter, {tags, acc} ->
          case Property.parse(tags) do
            {:ok, {item, []}} -> {:halt, {:ok, [item | acc]}}
            {:ok, {item, rest}} -> {:cont, {rest, [item | acc]}}
            {:error, _term} = term -> {:halt, term}
          end
      end)

    case result do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      term -> term
    end
  end

  defp encode_access_spec_property_list(properties) do
    result =
      Enum.reduce_while(properties, {:ok, []}, fn
        property, {:ok, acc} ->
          case Property.encode(property) do
            {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
            term -> {:halt, term}
          end
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
end
