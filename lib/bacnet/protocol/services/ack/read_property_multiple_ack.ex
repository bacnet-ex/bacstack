defmodule BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck do
  # TODO: Docs

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ReadAccessResult

  require Constants

  @type t :: %__MODULE__{
          results: [ReadAccessResult.t()]
        }

  @fields [
    :results
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :read_property_multiple
                )

  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(%ComplexACK{service: @service_name} = ack) do
    with {:ok, results} <- parse_results(ack.payload) do
      struc = %__MODULE__{
        results: results
      }

      {:ok, struc}
    else
      {:error, :invalid_tags} -> {:error, :invalid_service_ack}
      {:error, :invalid_value_and_error} -> {:error, :invalid_service_ack}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(_ack) do
    {:error, :invalid_service_ack}
  end

  @spec to_apdu(t(), 0..255) :: {:ok, ComplexACK.t()} | {:error, term()}
  def to_apdu(ack, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = ack, invoke_id) when invoke_id in 0..255 do
    with {:ok, parameters} <- encode_results(ack.results) do
      new_ack = %ComplexACK{
        invoke_id: invoke_id,
        sequence_number: nil,
        proposed_window_size: nil,
        service: @service_name,
        payload: Enum.reject(parameters, &is_nil/1)
      }

      {:ok, new_ack}
    end
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end

  defp parse_results(tags) do
    result =
      Enum.reduce_while(1..100_000//1, {tags, []}, fn
        _iter, {tags, acc} ->
          case ReadAccessResult.parse(tags) do
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

  defp encode_results(results) do
    result =
      Enum.reduce_while(results, {:ok, []}, fn item, {:ok, acc} ->
        case ReadAccessResult.encode(item) do
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
end
