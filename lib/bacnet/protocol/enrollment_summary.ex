defmodule BACnet.Protocol.EnrollmentSummary do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier

  @type t :: %__MODULE__{
          object_identifier: ObjectIdentifier.t(),
          event_type: Constants.event_type(),
          event_state: Constants.event_state(),
          priority: byte(),
          notification_class: non_neg_integer() | nil
        }

  @fields [
    :object_identifier,
    :event_type,
    :event_state,
    :priority,
    :notification_class
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet enrollment summary into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(
        %__MODULE__{} = summary,
        _opts \\ []
      ) do
    with :ok <-
           if(ApplicationTags.valid_int?(summary.priority, 8),
             do: :ok,
             else: {:error, :invalid_priority_value}
           ),
         {:ok, event_type} <-
           Constants.by_name_with_reason(
             :event_type,
             summary.event_type,
             {:unknown_type, summary.event_type}
           ),
         {:ok, event_state} <-
           Constants.by_name_with_reason(
             :event_state,
             summary.event_state,
             {:unknown_state, summary.event_state}
           ) do
      tail =
        if summary.notification_class do
          [{:unsigned_integer, summary.notification_class}]
        else
          []
        end

      params = [
        {:object_identifier, summary.object_identifier},
        {:enumerated, event_type},
        {:enumerated, event_state},
        {:unsigned_integer, summary.priority}
        | tail
      ]

      {:ok, params}
    end
  end

  @doc """
  Parses a BACnet enrollment summary from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:object_identifier, obj},
        {:enumerated, event_type},
        {:enumerated, event_state},
        {:unsigned_integer, priority}
        # Parse optional notification class in function body
        | rest
      ] ->
        with :ok <-
               if(ApplicationTags.valid_int?(priority, 8),
                 do: :ok,
                 else: {:error, :invalid_priority_value}
               ),
             {:ok, event_type_c} <-
               Constants.by_value_with_reason(
                 :event_type,
                 event_type,
                 {:unknown_type, event_type}
               ),
             {:ok, event_state_c} <-
               Constants.by_value_with_reason(
                 :event_state,
                 event_state,
                 {:unknown_state, event_state}
               ) do
          {notif_class, rest} =
            case rest do
              [{:unsigned_integer, notif_class} | rest] -> {notif_class, rest}
              _term -> {nil, rest}
            end

          summary = %__MODULE__{
            object_identifier: obj,
            event_type: event_type_c,
            event_state: event_state_c,
            priority: priority,
            notification_class: notif_class
          }

          {:ok, {summary, rest}}
        end

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given enrollment summary is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          object_identifier: %ObjectIdentifier{} = obj_ref,
          event_type: type,
          event_state: state,
          priority: priority,
          notification_class: class
        } = _t
      )
      when is_integer(priority) and priority >= 0 and priority <= 255 and
             (is_nil(class) or (is_integer(class) and class >= 0 and class <= 4_294_967_295)) do
    ObjectIdentifier.valid?(obj_ref) and Constants.has_by_name(:event_type, type) and
      Constants.has_by_name(:event_state, state)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
