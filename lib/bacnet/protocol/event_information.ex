defmodule BACnet.Protocol.EventInformation do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventTimestamps
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectIdentifier

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @type t :: %__MODULE__{
          object_identifier: ObjectIdentifier.t(),
          event_state: Constants.event_state(),
          acknowledged_transitions: EventTransitionBits.t(),
          event_timestamps: EventTimestamps.t(),
          notify_type: Constants.notify_type(),
          event_enable: EventTransitionBits.t(),
          event_priorities: {to_offnormal :: byte(), to_fault :: byte(), to_normal :: byte()}
        }

  @fields [
    :object_identifier,
    :event_state,
    :acknowledged_transitions,
    :event_timestamps,
    :notify_type,
    :event_enable,
    :event_priorities
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet event information into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{event_priorities: {ev_prio1, ev_prio2, ev_prio3}} = event, _opts \\ []) do
    with {:ok, obj, _header} <-
           ApplicationTags.encode_value({:object_identifier, event.object_identifier}),
         {:ok, event_state_c} <-
           Constants.by_name_with_reason(
             :event_state,
             event.event_state,
             {:unknown_state, event.event_state}
           ),
         {:ok, event_state, _header} <-
           ApplicationTags.encode_value({:enumerated, event_state_c}),
         {:ok, event_transbits, _header} <-
           ApplicationTags.encode_value(
             EventTransitionBits.to_bitstring(event.acknowledged_transitions)
           ),
         {:ok, timestamps} <- EventTimestamps.encode(event.event_timestamps),
         {:ok, notify_type_c} <-
           Constants.by_name_with_reason(
             :notify_type,
             event.notify_type,
             {:unknown_notify_type, event.notify_type}
           ),
         {:ok, notify_type, _header} <-
           ApplicationTags.encode_value({:enumerated, notify_type_c}),
         {:ok, event_enable, _header} <-
           ApplicationTags.encode_value(EventTransitionBits.to_bitstring(event.event_enable)) do
      params = [
        {:tagged, {0, obj, byte_size(obj)}},
        {:tagged, {1, event_state, byte_size(event_state)}},
        {:tagged, {2, event_transbits, byte_size(event_transbits)}},
        {:constructed, {3, timestamps, 0}},
        {:tagged, {4, notify_type, byte_size(notify_type)}},
        {:tagged, {5, event_enable, byte_size(event_enable)}},
        {:constructed,
         {6,
          [
            {:unsigned_integer, ev_prio1},
            {:unsigned_integer, ev_prio2},
            {:unsigned_integer, ev_prio3}
          ], 0}}
      ]

      {:ok, params}
    end
  end

  @doc """
  Parses a BACnet event information from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, obj, rest} <-
           pattern_extract_tags(tags, {:tagged, {0, _c, _l}}, :object_identifier, false),
         {:ok, event_state, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _c, _l}}, :enumerated, false),
         {:ok, event_state_c} <-
           Constants.by_value_with_reason(
             :event_state,
             event_state,
             {:unknown_state, event_state}
           ),
         {:ok, {offnormal, fault, normal}, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _c, _l}}, :bitstring, false),
         {:ok, {:constructed, {3, event_timestamps_raw, _len}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {3, _c, _l}}, nil, false),
         {:ok, {event_timestamps, _rest}} <- EventTimestamps.parse(event_timestamps_raw),
         {:ok, notify_type, rest} <-
           pattern_extract_tags(rest, {:tagged, {4, _c, _l}}, :enumerated, false),
         {:ok, notify_type_c} <-
           Constants.by_value_with_reason(
             :notify_type,
             notify_type,
             {:unknown_notify_type, notify_type}
           ),
         {:ok, {ev_offnormal, ev_fault, ev_normal}, rest} <-
           pattern_extract_tags(rest, {:tagged, {5, _c, _l}}, :bitstring, false),
         {:ok,
          {:constructed,
           {6,
            [
              unsigned_integer: prio1,
              unsigned_integer: prio2,
              unsigned_integer: prio3
            ], _len}},
          rest} <-
           pattern_extract_tags(rest, {:constructed, {6, _c, _l}}, nil, false) do
      info = %__MODULE__{
        object_identifier: obj,
        event_state: event_state_c,
        acknowledged_transitions: %EventTransitionBits{
          to_offnormal: offnormal,
          to_fault: fault,
          to_normal: normal
        },
        event_timestamps: event_timestamps,
        notify_type: notify_type_c,
        event_enable: %EventTransitionBits{
          to_offnormal: ev_offnormal,
          to_fault: ev_fault,
          to_normal: ev_normal
        },
        event_priorities: {prio1, prio2, prio3}
      }

      {:ok, {info, rest}}
    else
      {:ok, _term, _rest} -> {:error, :invalid_tags}
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given event information is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          object_identifier: %ObjectIdentifier{} = obj_ref,
          event_state: state,
          acknowledged_transitions: %EventTransitionBits{} = ack_trans,
          event_timestamps: %EventTimestamps{} = event,
          notify_type: type,
          event_enable: %EventTransitionBits{} = enable,
          event_priorities: {to_offnormal, to_fault, to_normal}
        } = _t
      )
      when is_integer(to_offnormal) and to_offnormal >= 0 and to_offnormal <= 255 and
             is_integer(to_fault) and to_fault >= 0 and to_fault <= 255 and
             is_integer(to_normal) and to_normal >= 0 and to_normal <= 255 do
    ObjectIdentifier.valid?(obj_ref) and Constants.has_by_name(:event_state, state) and
      EventTransitionBits.valid?(ack_trans) and EventTimestamps.valid?(event) and
      Constants.has_by_name(:notify_type, type) and EventTransitionBits.valid?(enable)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
