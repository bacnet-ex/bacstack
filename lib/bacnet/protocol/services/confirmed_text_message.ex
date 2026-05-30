defmodule BACnet.Protocol.Services.ConfirmedTextMessage do
  @moduledoc """
  This module represents the BACnet Confirmed Text Message service.

  The Confirmed Text Message service is used to send a text message to one devices. What the device does with
  the text message is a local matter of the recipient.

  #### Service Description (ASHRAE 135)

  > The ConfirmedTextMessage service is used by a client BACnet-user to send a text message to another BACnet device. This
  > service is not a broadcast or multicast service. This service may be used in cases when confirmation that the text message
  > was received is required. The confirmation does not guarantee that a human operator has seen the message. Messages may
  > be prioritized into normal or urgent categories. In addition, a given text message may be optionally classified by a numeric
  > class code or class identification string. This classification may be used by the receiving BACnet device to determine how
  > to handle the text message. For example, the message class might indicate a particular output device on which to print text
  > or a set of actions to take when the text is received. In any case, the interpretation of the class is a local matter.

  #### Service Procedure (ASHRAE 135)

  > After verifying the validity of the request, the responding BACnet-user shall take whatever local actions have been assigned
  > to the indicated 'Message Class' and issue a 'Result(+)' service primitive. If the service request cannot be executed, a
  > 'Result(-)' service primitive shall be issued indicating the encountered error. Other than the requirement to return a success
  > or failure response, actions taken in response to this notification are a local matter. However, typically the receiving device
  > would take the text specified by the 'Message' parameter and display, print, or file it according to the classification
  > specified by the 'Message Class' parameter. If the 'Message Class' parameter is omitted, then some general class might be
  > assumed. If 'Message Priority' is URGENT, then clearly the messages should be considered as more important than existing
  > NORMAL messages, which may be awaiting printing or some other action.

  #### Result(-) Errors (ASHRAE 135)

  The 'Result(-)' parameter shall indicate that the service request has failed. The reason for failure shall be specified by the
  'Error Type' parameter.

  The 'Error Class' and 'Error Code' are per Clause 18. The service procedure notes that errors during local handling of the
  message (display/print/file) are a local matter after the Result(-) has been returned.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.Services.Common
  require Constants

  @behaviour Protocol.Services.Behaviour

  @typedoc """
  Parameters for the Confirmed Text Message service.

  Carries a text message from a source device, with optional class (numeric or string) and priority
  (normal or urgent). The receiving device interprets the class and message contents locally.
  """
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

  @service_name Constants.macro_assert_name(:confirmed_service_choice, :confirmed_text_message)

  @doc """
  Get the service name atom.
  """
  @spec get_name() :: atom()
  def get_name(), do: @service_name

  @doc """
  Whether the service is of type confirmed or unconfirmed.
  """
  @spec confirmed?() :: true
  def confirmed?(), do: true

  @doc """
  Converts the given Unconfirmed Service Request into an Confirmed Text Message Service.
  """
  @spec from_apdu(Protocol.APDU.ConfirmedServiceRequest.t()) ::
          {:ok, t()} | {:error, term()}
  def from_apdu(
        %Protocol.APDU.ConfirmedServiceRequest{
          service: @service_name
        } = request
      ) do
    case Common.decode_text_message(request) do
      {:ok, event} -> {:ok, struct(__MODULE__, event)}
      {:error, _err} = err -> err
    end
  end

  def from_apdu(%Protocol.APDU.ConfirmedServiceRequest{} = _request) do
    {:error, :invalid_request}
  end

  @doc """
  Get the Confirmed Service request for the given Confirmed Text Message Service.

  See the `BACnet.Protocol.Services.Protocol` function documentation for more information.
  """
  @spec to_apdu(t(), Keyword.t()) ::
          {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
          | {:error, term()}
  def to_apdu(%__MODULE__{} = service, request_data) do
    with {:ok, req} <- Common.encode_text_message(service) do
      Common.after_encode_convert(
        req,
        request_data,
        Protocol.APDU.ConfirmedServiceRequest,
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

    @spec confirmed?(@for.t()) :: boolean()
    def confirmed?(%@for{} = _service), do: @for.confirmed?()

    @spec to_apdu(@for.t(), Keyword.t()) ::
            {:ok, Protocol.APDU.ConfirmedServiceRequest.t()}
            | {:error, term()}
    def to_apdu(%@for{} = service, request_data), do: @for.to_apdu(service, request_data)
  end
end
