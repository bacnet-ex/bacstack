defmodule BACnet.Protocol.Destination do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.DaysOfWeek
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.Recipient

  @typedoc """
  Represents a BACnet destination.
  """
  @type t :: %__MODULE__{
          recipient: Recipient.t(),
          process_identifier: ApplicationTags.unsigned32(),
          issue_confirmed_notifications: boolean(),
          transitions: EventTransitionBits.t(),
          valid_days: DaysOfWeek.t(),
          from_time: BACnetTime.t(),
          to_time: BACnetTime.t()
        }

  @fields [
    :recipient,
    :process_identifier,
    :issue_confirmed_notifications,
    :transitions,
    :valid_days,
    :from_time,
    :to_time
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet destination into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = destination, _opts \\ []) do
    with :ok <-
           if(
             destination.process_identifier >= 0 and
               ApplicationTags.valid_int?(destination.process_identifier, 32),
             do: :ok,
             else: {:error, :invalid_process_identifier_value}
           ),
         {:ok, [recipient_raw]} <- Recipient.encode(destination.recipient) do
      params = [
        DaysOfWeek.to_bitstring(destination.valid_days),
        {:time, destination.from_time},
        {:time, destination.to_time},
        recipient_raw,
        {:unsigned_integer, destination.process_identifier},
        {:boolean, destination.issue_confirmed_notifications},
        EventTransitionBits.to_bitstring(destination.transitions)
      ]

      {:ok, params}
    end
  end

  @doc """
  Parses a BACnet destination from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:bitstring, days},
        {:time, from_time},
        {:time, to_time},
        recipient_raw,
        {:unsigned_integer, process_id},
        {:boolean, issue_confirmed},
        {:bitstring, event_trans}
        | rest
      ] ->
        with :ok <-
               if(ApplicationTags.valid_int?(process_id, 32),
                 do: :ok,
                 else: {:error, :invalid_process_identifier_value}
               ),
             {:ok, {recipient, _rest}} <- Recipient.parse([recipient_raw]) do
          dest = %__MODULE__{
            recipient: recipient,
            process_identifier: process_id,
            issue_confirmed_notifications: issue_confirmed,
            transitions: EventTransitionBits.from_bitstring(event_trans),
            valid_days: DaysOfWeek.from_bitstring(days),
            from_time: from_time,
            to_time: to_time
          }

          {:ok, {dest, rest}}
        end

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given BACnet destination is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          recipient: %Recipient{} = recip,
          process_identifier: process_id,
          issue_confirmed_notifications: issue_confirmed,
          transitions: %EventTransitionBits{} = trans,
          valid_days: %DaysOfWeek{} = days,
          from_time: %BACnetTime{} = from_t,
          to_time: %BACnetTime{} = to_t
        } = _t
      )
      when is_integer(process_id) and process_id >= 0 and process_id <= 4_294_967_295 and
             is_boolean(issue_confirmed) do
    Recipient.valid?(recip) and EventTransitionBits.valid?(trans) and DaysOfWeek.valid?(days) and
      BACnetTime.valid?(from_t) and BACnetTime.valid?(to_t) and BACnetTime.specific?(from_t) and
      BACnetTime.specific?(to_t)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
