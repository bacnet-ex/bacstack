defmodule BACnet.Protocol.Services.UnconfirmedTextMessage do
  @moduledoc """
  This module represents the BACnet Unconfirmed Text Message service.

  The Unconfirmed Text Message service is used to send a text message to one or more devices. What devices do with
  the text message is a local matter of the recipient.

  Service Description (ASHRAE 135):
  > The UnconfirmedTextMessage service is used by a client BACnet-user to send a text message to one or more BACnet
  > devices. This service may be broadcast, multicast, or addressed to a single recipient. This service may be used in cases
  > where confirmation that the text message was received is not required. Messages may be prioritized into normal or urgent
  > categories. In addition, a given text message may optionally be classified by a numeric class code or class identification
  > string. This classification may be used by receiving BACnet devices to determine how to handle the text message. For
  > example, the message class might indicate a particular output device on which to print text or a set of actions to take when
  > the text message is received. In any case, the interpretation of the class is a local matter.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
  require Constants

  @behaviour Protocol.Services.Behaviour

  # TODO: Docs
  # TODO: Add Service Procedure to docs

  @type t :: %__MODULE__{
          source_device: Protocol.ObjectIdentifier.t(),
          class: non_neg_integer() | String.t() | nil,
          priority: :normal | :urgent,
          message: String.t()
        }

  @fields [
    :source_device,
    :class,
    :priority,
    :message
  ]
  @enforce_keys @fields
  defstruct @fields

  @service_name Constants.macro_assert_name(
                  :unconfirmed_service_choice,
                  :unconfirmed_text_message
                )

  @doc """
  Get the service name atom.
  """
  @spec get_name() :: atom()
  def get_name(), do: @service_name

  @doc """
  Whether the service is of type confirmed or unconfirmed.
  """
  @spec is_confirmed() :: false
  def is_confirmed(), do: false

  @doc """
  Converts the given Unconfirmed Service Request into an Unconfirmed Text Message Service.
  """
  @spec from_apdu(Protocol.APDU.UnconfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.UnconfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case Protocol.Services.Common.decode_text_message(request) do
      {:ok, event} -> {:ok, struct(__MODULE__, event)}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.UnconfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Unconfirmed Service request for the given Unconfirmed Text Message Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, req} <- Protocol.Services.Common.encode_text_message(service) do
      Protocol.Services.Common.after_encode_convert(
        req,
        request_data,
        Protocol.APDU.UnconfirmedServiceRequest,
        @service_name
      )
    end
  end

  # @spec class_to_tag(non_neg_integer() | binary()) :: {atom(), term()}
  # defp class_to_tag(num) when num in 1..4_294_967_295, do: {:unsigned_integer, num}
  # defp class_to_tag(text) when is_binary(text), do: {:character_string, text}

  # @spec priority_to_tag(:normal | :urgent) :: 0 | 1
  # defp priority_to_tag(:normal), do: 0
  # defp priority_to_tag(:urgent), do: 1

  defimpl Protocol.Services.Protocol do
    alias BACnet.Protocol
    alias BACnet.Protocol.Constants
    require Constants

    @spec get_name(@for.t()) :: atom()
    def get_name(%@for{} = _service), do: @for.get_name()

    @spec is_confirmed(@for.t()) :: boolean()
    def is_confirmed(%@for{} = _service), do: @for.is_confirmed()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.UnconfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end