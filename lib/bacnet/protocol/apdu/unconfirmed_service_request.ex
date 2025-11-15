defmodule BACnet.Protocol.APDU.UnconfirmedServiceRequest do
  @moduledoc """
  Unconfirmed Service Request APDUs are used to convey the information
  contained in unconfirmed service request primitives.

  Unconfirmed Service Requests are as their name implies unconfirmed,
  that means a response is not required. Some services will trigger
  a response from BACnet servers that match with the service request.
  For example, this may be a `I Am` being transmitted due to a `Who Is` received.

  This module has functions for encoding Unconfirmed Service Request APDUs.
  Decoding is handled by `BACnet.Protocol.APDU`.

  This module implements the `BACnet.Stack.EncoderProtocol`.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.Services

  require Constants

  @typedoc """
  BACnet Unconfirmed Service Request service structs.
  """
  @type service ::
          Services.IAm.t()
          | Services.IHave.t()
          | Services.WhoHas.t()
          | Services.WhoIs.t()
          | Services.TimeSynchronization.t()
          | Services.UnconfirmedCovNotification.t()
          | Services.UnconfirmedEventNotification.t()
          | Services.UnconfirmedPrivateTransfer.t()
          | Services.UnconfirmedTextMessage.t()
          | Services.UtcTimeSynchronization.t()
          | Services.WriteGroup.t()

  @typedoc """
  Represents the Application Data Unit (APDU) Unconfirmed Service Request.

  To allow forward compatibility, reason is allowed to be an integer.
  """
  @type t :: %__MODULE__{
          service: Constants.unconfirmed_service_choice() | non_neg_integer(),
          parameters: ApplicationTags.encoding_list()
        }

  @fields [
    :service,
    :parameters
  ]
  @enforce_keys @fields
  defstruct @fields

  @encoder_module Module.concat([BACnet.Stack.EncoderProtocol, __MODULE__])

  @doc """
  Encodes the Unconfirmed Service Request APDU into binary data.
  """
  @spec encode(t()) :: {:ok, iodata()} | {:error, term()}
  def encode(%__MODULE__{} = apdu) do
    res = @encoder_module.encode(apdu)
    {:ok, res}
  rescue
    e -> {:error, e}
  end

  @doc """
  Converts the APDU into a service, if supported and possible.
  """
  @spec to_service(t()) :: {:ok, service()} | {:error, term()} | :not_supported
  def to_service(%__MODULE__{} = apdu) do
    case apdu.service do
      Constants.macro_assert_name(:unconfirmed_service_choice, :i_am) ->
        Services.IAm.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :i_have) ->
        Services.IHave.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :who_has) ->
        Services.WhoHas.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :who_is) ->
        Services.WhoIs.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :time_synchronization) ->
        Services.TimeSynchronization.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :unconfirmed_cov_notification) ->
        Services.UnconfirmedCovNotification.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :unconfirmed_event_notification) ->
        Services.UnconfirmedEventNotification.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :unconfirmed_private_transfer) ->
        Services.UnconfirmedPrivateTransfer.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :unconfirmed_text_message) ->
        Services.UnconfirmedTextMessage.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :utc_time_synchronization) ->
        Services.UtcTimeSynchronization.from_apdu(apdu)

      Constants.macro_assert_name(:unconfirmed_service_choice, :write_group) ->
        Services.WriteGroup.from_apdu(apdu)

      _else ->
        :not_supported
    end
  end

  defimpl BACnet.Stack.EncoderProtocol do
    alias BACnet.Protocol.ApplicationTags
    alias BACnet.Protocol.Constants

    require Constants

    @doc """
    Whether the struct expects a reply (i.e. Confirmed Service Request).

    This is useful for NPCI calculation.
    """
    @spec expects_reply(@for.t()) :: boolean()
    def expects_reply(%@for{} = _apdu), do: false

    @doc """
    Whether the struct is a request.
    """
    @spec is_request(@for.t()) :: boolean()
    def is_request(%@for{} = _apdu), do: true

    @doc """
    Whether the struct is a response.
    """
    @spec is_response(@for.t()) :: boolean()
    def is_response(%@for{} = _apdu), do: false

    @spec encode(@for.t()) :: iodata()
    def encode(%@for{} = apdu) do
      service =
        if is_atom(apdu.service) do
          Constants.by_name!(:unconfirmed_service_choice, apdu.service)
        else
          apdu.service
        end

      parameters = encode_parameters(apdu.parameters)

      <<Constants.macro_by_name(:pdu_type, :unconfirmed_request)::size(4), 0::size(4),
        service::size(8), parameters::binary>>
    end

    @spec supports_segmentation(@for.t()) :: boolean()
    def supports_segmentation(_apdu), do: false

    @spec encode_segmented(@for.t(), integer()) :: [binary()]
    def encode_segmented(%@for{} = _t, _apdu_size) do
      raise "Illegal function call, APDU can not be segmented"
    end

    @spec encode_parameters(term()) :: binary()
    defp encode_parameters(parameters) when is_list(parameters) do
      parameters
      |> Enum.reduce([], fn param, acc ->
        case ApplicationTags.encode(param) do
          {:ok, bin} ->
            [bin | acc]

          {:error, err} ->
            raise "Unable to encode parameters in unconfirmed service request encode, error: #{inspect(err)}"
        end
      end)
      |> Enum.reverse()
      |> IO.iodata_to_binary()
    end
  end
end
