defmodule BACnet.Protocol.AlarmSummary do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectIdentifier

  @type t :: %__MODULE__{
          object_identifier: ObjectIdentifier.t(),
          alarm_state: Constants.event_state(),
          acknowledged_transitions: EventTransitionBits.t()
        }

  @fields [:object_identifier, :alarm_state, :acknowledged_transitions]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet alarm summary into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(
        %__MODULE__{
          object_identifier: %ObjectIdentifier{},
          acknowledged_transitions: %EventTransitionBits{}
        } = summary,
        _opts \\ []
      ) do
    with {:ok, state} <-
           Constants.by_name_with_reason(
             :event_state,
             summary.alarm_state,
             {:unknown_state, summary.alarm_state}
           ) do
      params = [
        {:object_identifier, summary.object_identifier},
        {:enumerated, state},
        EventTransitionBits.to_bitstring(summary.acknowledged_transitions)
      ]

      {:ok, params}
    end
  end

  @doc """
  Parses a BACnet alarm summary from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:object_identifier, obj},
        {:enumerated, event_state},
        {:bitstring, {offnormal, fault, normal}}
        | rest
      ] ->
        with {:ok, alarm_state} <-
               Constants.by_value_with_reason(
                 :event_state,
                 event_state,
                 {:unknown_state, event_state}
               ) do
          summary = %__MODULE__{
            object_identifier: obj,
            alarm_state: alarm_state,
            acknowledged_transitions: %EventTransitionBits{
              to_offnormal: offnormal,
              to_fault: fault,
              to_normal: normal
            }
          }

          {:ok, {summary, rest}}
        end

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given alarm summary is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          object_identifier: %ObjectIdentifier{} = obj_ref,
          alarm_state: state,
          acknowledged_transitions: %EventTransitionBits{} = bits
        } = _t
      ) do
    ObjectIdentifier.valid?(obj_ref) and Constants.has_by_name(:event_state, state) and
      EventTransitionBits.valid?(bits)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
