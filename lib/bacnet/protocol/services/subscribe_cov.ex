defmodule BACnet.Protocol.Services.SubscribeCov do
  @moduledoc """
  This module represents the BACnet Subscribe COV service.

  The Subscribe COV service is used to subscribe to changes of an object. The standardized objects that may optionally
  provide COV support and the change of value algorithms they shall employ are summarized in ASHRAE 135 Table 13-1.

  Service Description (ASHRAE 135):
  > The SubscribeCOV service is used by a COV-client to subscribe for the receipt of notifications of changes that may occur to
  > the properties of a particular object. Certain BACnet standard objects may optionally support COV reporting. If a standard
  > object provides COV reporting, then changes of value of specific properties of the object, in some cases based on
  > programmable increments, trigger COV notifications to be sent to one or more subscriber clients. Typically, COV
  > notifications are sent to supervisory programs in BACnet client devices or to operators or logging devices. Proprietary objects
  > may support COV reporting at the implementor's option. The standardized objects that may optionally provide COV support
  > and the change of value algorithms they shall employ are summarized in Table 13-1.
  > The subscription establishes a connection between the change of value detection and reporting mechanism within the COVserver
  > device and a "process" within the COV-client device. Notifications of changes are issued by the COV-server device
  > when changes occur after the subscription has been established. The ConfirmedCOVNotification and
  > UnconfirmedCOVNotification services are used by the COV-server device to convey change notifications. The choice of
  > confirmed or unconfirmed service is made at the time the subscription is established.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants

  import Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs
  # if issue_confirmed_notifications and lifetime = nil: cancellation of a COV subscription

  @type t :: %__MODULE__{
          process_identifier: ApplicationTags.unsigned32(),
          monitored_object: Protocol.ObjectIdentifier.t(),
          issue_confirmed_notifications: boolean() | nil,
          lifetime: non_neg_integer() | nil
        }

  @fields [
    :process_identifier,
    :monitored_object,
    :issue_confirmed_notifications,
    :lifetime
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :confirmed_service_choice,
                  :subscribe_cov
                )

  @doc """
  Get the service name atom.
  """
  @spec get_name() :: atom()
  def get_name(), do: @service_name

  @doc """
  Whether the service is of type confirmed or unconfirmed.
  """
  @spec is_confirmed() :: true
  def is_confirmed(), do: true

  @doc """
  Converts the given Confirmed Service Request into a Subscribe COV Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    with {:ok, process_identifier, rest} <-
           pattern_extract_tags(
             request.parameters,
             {:tagged, {0, _t, _l}},
             :unsigned_integer,
             false
           ),
         {:ok, monitored_object, rest} <-
           pattern_extract_tags(rest, {:tagged, {1, _t, _l}}, :object_identifier, false),
         {:ok, issue_confirmed, rest} <-
           pattern_extract_tags(rest, {:tagged, {2, _t, _l}}, :boolean, true),
         {:ok, lifetime, _rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _t, _l}}, :unsigned_integer, true) do
      subscribe = %__MODULE__{
        process_identifier: process_identifier,
        monitored_object: monitored_object,
        issue_confirmed_notifications: issue_confirmed,
        lifetime: lifetime
      }

      {:ok, subscribe}
    else
      {:error, :missing_pattern} -> {:error, :invalid_request_parameters}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Subscribe COV Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, pid, _header} <-
           ApplicationTags.encode_value({:unsigned_integer, service.process_identifier}),
         {:ok, monitored_object, _header} <-
           ApplicationTags.encode_value({:object_identifier, service.monitored_object}),
         {:ok, issue_confirmed} <-
           (case service.issue_confirmed_notifications do
              nil ->
                {:ok, nil}

              _term ->
                with {:ok, bytes, _header} <-
                       ApplicationTags.encode_value(
                         {:unsigned_integer, service.issue_confirmed_notifications}
                       ) do
                  {:ok, {:tagged, {2, bytes, byte_size(bytes)}}}
                end
            end),
         {:ok, lifetime} <-
           (case service.lifetime do
              nil ->
                {:ok, nil}

              _term ->
                with {:ok, bytes, _header} <-
                       ApplicationTags.encode_value({:unsigned_integer, service.lifetime}) do
                  {:ok, {:tagged, {3, bytes, byte_size(bytes)}}}
                end
            end) do
      parameters = [
        {:tagged, {0, pid, byte_size(pid)}},
        {:tagged, {1, monitored_object, byte_size(monitored_object)}},
        issue_confirmed,
        lifetime
      ]

      req = %Protocol.APDU.ConfirmedServiceRequest{
        segmented_response_accepted: request_data[:segmented_response_accepted] || true,
        max_segments: request_data[:max_segments] || :more_than_64,
        max_apdu:
          request_data[:max_apdu] ||
            Constants.macro_by_name(:max_apdu_length_accepted_value, :octets_1476),
        invoke_id: request_data[:invoke_id] || 0,
        sequence_number: nil,
        proposed_window_size: nil,
        service: @service_name,
        parameters: Enum.reject(parameters, &is_nil/1)
      }

      {:ok, req}
    end
  end

  defimpl Protocol.Services.Protocol do
    alias BACnet.Protocol
    alias BACnet.Protocol.Constants
    require Constants

    @spec get_name(@for.t()) :: atom()
    def get_name(%@for{} = _service), do: @for.get_name()

    @spec is_confirmed(@for.t()) :: boolean()
    def is_confirmed(%@for{} = _service), do: @for.is_confirmed()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end