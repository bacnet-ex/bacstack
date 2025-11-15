defmodule BACnet.Protocol.Device.ObjectTypesSupported do
  @moduledoc """
  BACnet object types need to be supported by the device, in order for a BACnet client
  to be able to handle them.

  This module contains a struct that represents the support state for each object type.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants.ObjectsSupported
  alias BACnet.Protocol.ObjectsUtility

  fields = Enum.map(ObjectsSupported.get_constants(), &{elem(&1, 1), false})
  type_fields = Enum.map(fields, &{elem(&1, 0), {:boolean, [], []}})

  @mapper Enum.map(ObjectsSupported.get_constants(), &{elem(&1, 1), elem(&1, 2)})

  encoder =
    @mapper
    |> Enum.sort_by(fn {_name, bit} -> bit end, :asc)
    |> Enum.map(fn {name, _val} ->
      quote do
        !!Map.get(var!(objects), unquote(name))
      end
    end)

  @encoder (quote do
              {unquote_splicing(encoder)}
            end)

  @typedoc """
  Represents which BACnet object types are supported.
  """
  @type t :: %__MODULE__{
          unquote_splicing(type_fields)
        }

  defstruct fields

  @doc """
  Creates a new struct, defaulting to the local implementation status.
  See `ObjectsUtility.get_supported_object_types/0`.
  """
  @spec new() :: t()
  def new() do
    map = Map.new(ObjectsUtility.get_object_type_mappings(), fn {key, _val} -> {key, true} end)

    struct(__MODULE__, map)
  end

  @doc """
  Decodes the BACnet application tag bitstring into a struct.
  """
  @spec parse(
          ApplicationTags.encoding()
          | ApplicationTags.Encoding.t()
          | ApplicationTags.encoding_list()
        ) ::
          {:ok, t()} | {:error, term()}
  def parse(app_tag)

  def parse([head | _tail]) do
    parse(head)
  end

  def parse({:bitstring, bits}) do
    {:ok, struct(__MODULE__, decode_value(bits))}
  end

  def parse(%ApplicationTags.Encoding{type: :bitstring, value: bits}) do
    {:ok, struct(__MODULE__, decode_value(bits))}
  end

  def parse(_term), do: {:error, :invalid_tags}

  @doc """
  Encodes the struct into BACnet application tag bitstring.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = objects, _opts \\ []) do
    bits = unquote(@encoder)
    {:ok, [{:bitstring, bits}]}
  end

  @spec decode_value(tuple()) :: map()
  defp decode_value(bits) do
    Enum.reduce(@mapper, %{}, fn {name, bit}, acc ->
      Map.put(acc, name, get_bit(bits, bit))
    end)
  end

  @spec get_bit(tuple(), non_neg_integer()) :: boolean()
  defp get_bit(bits, bit) when tuple_size(bits) > bit do
    elem(bits, bit)
  end

  defp get_bit(_bits, _bit), do: false
end
