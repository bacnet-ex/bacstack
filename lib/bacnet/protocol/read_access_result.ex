defmodule BACnet.Protocol.ReadAccessResult do
  @moduledoc """
  Represents BACnet Read Access Result, used in BACnet `Read-Property-Multiple`.
  """

  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ReadAccessResult.ReadResult

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @type t :: %__MODULE__{
          object_identifier: ObjectIdentifier.t(),
          results: [ReadResult.t()]
        }

  @fields [
    :object_identifier,
    :results
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet Read Access Result into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = result, _opts \\ []) do
    with {:ok, obj, _header} <-
           ApplicationTags.encode_value({:object_identifier, result.object_identifier}),
         {:ok, properties} <- encode_result_list(result.results) do
      result_list =
        if properties != [] do
          [{:constructed, {1, properties, 0}}]
        else
          []
        end

      parameters = [
        {:tagged, {0, obj, byte_size(obj)}}
        | result_list
      ]

      {:ok, parameters}
    end
  end

  @doc """
  Parses a BACnet Read Access Result from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, obj, rest} <-
           pattern_extract_tags(tags, {:tagged, {0, _t, _l}}, :object_identifier, false),
         {:ok, results_raw, rest} <-
           pattern_extract_tags(rest, {:constructed, {1, _t, _l}}, nil, true),
         {:ok, results} <- parse_result_list(results_raw) do
      result = %__MODULE__{
        object_identifier: obj,
        results: results
      }

      {:ok, {result, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given read access result is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          object_identifier: %ObjectIdentifier{} = obj,
          results: results
        } = _t
      )
      when is_list(results) do
    ObjectIdentifier.valid?(obj) and
      Enum.all?(results, fn
        %ReadResult{} = prop -> ReadResult.valid?(prop)
        _else -> false
      end)
  end

  def valid?(%__MODULE__{} = _t), do: false

  defp encode_result_list([]), do: {:ok, []}

  defp encode_result_list(results) do
    result =
      Enum.reduce_while(results, {:ok, []}, fn item, {:ok, acc} ->
        case ReadResult.encode(item) do
          {:ok, list} -> {:cont, {:ok, [list | acc]}}
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

  defp parse_result_list(nil), do: {:ok, []}

  defp parse_result_list({:constructed, {1, results, _len}}) do
    result =
      Enum.reduce_while(1..100_000//1, {results, []}, fn
        _iter, {tags, acc} ->
          case ReadResult.parse(tags) do
            {:ok, {item, []}} -> {:halt, {:ok, [item | acc]}}
            {:ok, {item, rest}} -> {:cont, {rest, [item | acc]}}
            term -> {:halt, term}
          end
      end)

    case result do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      term -> term
    end
  end
end
