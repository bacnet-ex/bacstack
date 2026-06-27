defmodule BACnet.Protocol.Services.Ack.GetEnrollmentSummaryAck do
  @moduledoc """
  The Get Enrollment Summary Acknowledgment returns the list of objects that
  have been configured to generate event notifications to a particular
  recipient or notification class.

  Each entry is an Enrollment Summary record containing the object identifier,
  the type of event it generates, its current state, the priority it will use,
  and the notification class. This service is useful for auditing and managing
  which objects are currently "subscribed" to send alarms to a given system or
  operator.
  """

  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EnrollmentSummary

  require Constants

  @typedoc """
  Response for Get Enrollment Summary. Contains the filtered list of enrollment summaries
  describing which objects are subscribed to generate event notifications for particular recipients.
  """
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

  @doc """
  Converts a received `BACnet.Protocol.APDU.ComplexACK` APDU into a struct.
  """
  @spec from_apdu(ComplexACK.t()) :: {:ok, t()} | {:error, term()}
  def from_apdu(%ComplexACK{service: @service_name} = ack) do
    case parse_summaries(ack.payload) do
      {:ok, summary} ->
        struc = %__MODULE__{
          summaries: summary
        }

        {:ok, struc}

      {:error, :invalid_tags} ->
        {:error, :invalid_service_ack}

      {:error, _err} = err ->
        err
    end
  end

  def from_apdu(_ack) do
    {:error, :invalid_service_ack}
  end

  @doc """
  Constructs a `BACnet.Protocol.APDU.ComplexACK` APDU from a
  `BACnet.Protocol.Services.Ack.GetEnrollmentSummaryAck` struct.
  """
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
        _iter, {[], acc} ->
          {:halt, {:ok, acc}}

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
