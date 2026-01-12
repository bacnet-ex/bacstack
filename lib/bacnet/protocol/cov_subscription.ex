defmodule BACnet.Protocol.CovSubscription do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.Recipient

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]

  @type t :: %__MODULE__{
          recipient: Recipient.t(),
          recipient_process: non_neg_integer(),
          monitored_object_property: ObjectPropertyRef.t(),
          issue_confirmed_notifications: boolean(),
          time_remaining: non_neg_integer(),
          cov_increment: float() | nil
        }

  @fields [
    :recipient,
    :recipient_process,
    :monitored_object_property,
    :issue_confirmed_notifications,
    :time_remaining,
    :cov_increment
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a COV subscription struct into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = cov, opts \\ []) do
    with {:ok, [recipient]} <- Recipient.encode(cov.recipient, opts),
         {:ok, process_id, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, cov.recipient_process}, opts),
         {:ok, obj_prop} <- ObjectPropertyRef.encode(cov.monitored_object_property, opts),
         {:ok, issue_confirmed} <-
           ApplicationTags.create_tag_encoding(2, {:boolean, cov.issue_confirmed_notifications}),
         {:ok, time_remaining} <-
           ApplicationTags.create_tag_encoding(3, {:unsigned_integer, cov.time_remaining}),
         {:ok, cov_increment} <-
           (if cov.cov_increment do
              ApplicationTags.create_tag_encoding(4, {:real, cov.cov_increment})
            else
              {:ok, nil}
            end) do
      tags = [
        {:constructed,
         {0,
          [
            constructed: {0, recipient, 0},
            tagged: {1, process_id, byte_size(process_id)}
          ], 0}},
        {:constructed, {1, obj_prop, 0}},
        issue_confirmed,
        time_remaining,
        cov_increment
      ]

      {:ok, Enum.reject(tags, &is_nil/1)}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parses a BACnet COV subscription application tags encoding into a struct.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok,
          {:constructed,
           {0,
            [
              constructed: {0, recipient_raw, _len},
              tagged: {1, process_identifier_raw, _len2}
            ], _len3}}, rest} <-
           pattern_extract_tags(tags, {:constructed, {0, _c, _l}}, nil, false),
         {:ok, {recipient, _rest}} <- Recipient.parse([recipient_raw]),
         {:ok, {:unsigned_integer, process_id}} <-
           ApplicationTags.unfold_to_type(:unsigned_integer, process_identifier_raw),
         {:ok, {:constructed, {1, objpropref_raw, _len}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {1, _c, _l}}, nil, false),
         {:ok, {objpropref, _rest}} <- ObjectPropertyRef.parse(objpropref_raw),
         {:ok, issue_confirmed, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _c, _l}}, :boolean, false),
         {:ok, time_remaining, rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _c, _l}}, :unsigned_integer, false),
         {:ok, cov_increment, rest} <-
           pattern_extract_tags(rest, {:tagged, {4, _c, _l}}, :real, true) do
      cov = %__MODULE__{
        recipient: recipient,
        recipient_process: process_id,
        monitored_object_property: objpropref,
        issue_confirmed_notifications: issue_confirmed,
        time_remaining: time_remaining,
        cov_increment: cov_increment
      }

      {:ok, {cov, rest}}
    else
      {:ok, {:constructed, _term}, _rest} -> {:error, :invalid_tags}
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given COV subscription is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          recipient: %Recipient{} = recipient,
          recipient_process: process_id,
          monitored_object_property: %ObjectPropertyRef{} = ref,
          issue_confirmed_notifications: issue_confirmed,
          time_remaining: time_remaining,
          cov_increment: cov_increment
        } = _t
      )
      when is_integer(process_id) and process_id >= 0 and process_id <= 4_294_967_295 and
             is_boolean(issue_confirmed) and
             is_integer(time_remaining) and time_remaining >= 0 and
             (is_nil(cov_increment) or is_float(cov_increment)) do
    Recipient.valid?(recipient) and ObjectPropertyRef.valid?(ref)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
