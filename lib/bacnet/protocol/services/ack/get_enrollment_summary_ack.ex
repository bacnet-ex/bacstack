defmodule BACnet.Protocol.Services.Ack.GetEnrollmentSummaryAck do
  # TODO: Docs

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EnrollmentSummary

  require Constants

  @type t :: %__MODULE__{
          summaries: [EnrollmentSummary.t()]
        }

  @fields [:summaries]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :get_enrollment_summary
                )

  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(%ComplexACK{service: @service_name} = ack) do
    with {:ok, summary} <- parse_summaries(ack.payload) do
      struc = %__MODULE__{
        summaries: summary
      }

      {:ok, struc}
    else
      {:error, :invalid_tags} -> {:error, :invalid_service_ack}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(_ack) do
    {:error, :invalid_service_ack}
  end

  @spec to_apdu(t(), 0..255) :: {:ok, ComplexACK.t()} | {:error, term()}
  def to_apdu(ack, invoke_id \\ 0)

  def to_apdu(%__MODULE__{} = ack, invoke_id) when invoke_id in 0..255 do
    with {:ok, summaries} <- encode_summaries(ack.summaries) do
      new_ack = %ComplexACK{
        invoke_id: invoke_id,
        sequence_number: nil,
        proposed_window_size: nil,
        service: @service_name,
        payload: summaries
      }

      {:ok, new_ack}
    end
  end

  def to_apdu(%__MODULE__{} = _ack, _invoke_id) do
    {:error, :invalid_parameter}
  end

  defp parse_summaries(payload) do
    result =
      Enum.reduce_while(1..100_000//1, {payload, []}, fn
        _iter, {tags, acc} ->
          case EnrollmentSummary.parse(tags) do
            {:ok, {item, []}} -> {:halt, {:ok, [item | acc]}}
            {:ok, {item, rest}} -> {:cont, {rest, [item | acc]}}
            {:error, _term} = term -> {:halt, term}
          end
      end)

    case result do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      term -> term
    end
  end

  defp encode_summaries(summaries) do
    result =
      Enum.reduce_while(summaries, {:ok, []}, fn
        summary, {:ok, acc} ->
          case EnrollmentSummary.encode(summary) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _err} = term -> {:halt, term}
          end
      end)

    case result do
      {:ok, list} ->
        params =
          list
          |> Enum.reverse()
          |> List.flatten()

        {:ok, params}

      term ->
        term
    end
  end
end
