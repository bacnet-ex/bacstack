defmodule BACnet.Protocol.APDU.ConfirmedServiceRequest do
  @moduledoc """
  Confirmed Service Request APDUs are used to convey
  the information contained in confirmed service request primitives.

  Confirmed Service Requests require the BACnet server
  to reply with an appropriate response (such as ACK or error).

  This module has functions for encoding Confirmed Service Request APDUs.
  Decoding is handled by `BACnet.Protocol.APDU`.

  This module implements the `BACnet.Stack.EncoderProtocol`.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.Services

  require Constants

  @typedoc """
  BACnet Confirmed Service Request service structs.
  """
  @type service ::
          Services.AcknowledgeAlarm.t()
          | Services.AddListElement.t()
          | Services.AtomicReadFile.t()
          | Services.AtomicWriteFile.t()
          | Services.ConfirmedCovNotification.t()
          | Services.ConfirmedEventNotification.t()
          | Services.ConfirmedPrivateTransfer.t()
          | Services.ConfirmedTextMessage.t()
          | Services.CreateObject.t()
          | Services.DeleteObject.t()
          | Services.DeviceCommunicationControl.t()
          | Services.GetAlarmSummary.t()
          | Services.GetEnrollmentSummary.t()
          | Services.GetEventInformation.t()
          | Services.LifeSafetyOperation.t()
          | Services.ReadProperty.t()
          | Services.ReadPropertyMultiple.t()
          | Services.ReadRange.t()
          | Services.ReinitializeDevice.t()
          | Services.RemoveListElement.t()
          | Services.SubscribeCov.t()
          | Services.SubscribeCovProperty.t()
          | Services.WriteProperty.t()
          | Services.WritePropertyMultiple.t()

  @typedoc """
  Represents the Application Data Unit (APDU) Confirmed Service Request.

  To allow forward compatibility, service is allowed to be an integer.
  """
  @type t :: %__MODULE__{
          segmented_response_accepted: boolean(),
          max_apdu: Constants.max_apdu(),
          max_segments: Constants.max_segments(),
          invoke_id: 0..255,
          sequence_number: 0..255 | nil,
          proposed_window_size: 1..127 | nil,
          service: Constants.confirmed_service_choice() | non_neg_integer(),
          parameters: ApplicationTags.encoding_list()
        }

  @fields [
    :segmented_response_accepted,
    :max_apdu,
    :max_segments,
    :invoke_id,
    :sequence_number,
    :proposed_window_size,
    :service,
    :parameters
  ]
  @enforce_keys @fields
  defstruct @fields

  @encoder_module Module.concat([BACnet.Stack.EncoderProtocol, __MODULE__])

  @doc """
  Encodes the Confirmed Service Request APDU into binary data.

  Note that segmentation is ignored.
  """
  @spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
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
      Constants.macro_assert_name(:confirmed_service_choice, :acknowledge_alarm) ->
        Services.AcknowledgeAlarm.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :add_list_element) ->
        Services.AddListElement.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :atomic_read_file) ->
        Services.AtomicReadFile.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :atomic_write_file) ->
        Services.AtomicWriteFile.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :confirmed_cov_notification) ->
        Services.ConfirmedCovNotification.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :confirmed_event_notification) ->
        Services.ConfirmedEventNotification.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :confirmed_private_transfer) ->
        Services.ConfirmedPrivateTransfer.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :confirmed_text_message) ->
        Services.ConfirmedTextMessage.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :create_object) ->
        Services.CreateObject.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :delete_object) ->
        Services.DeleteObject.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :device_communication_control) ->
        Services.DeviceCommunicationControl.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :get_alarm_summary) ->
        Services.GetAlarmSummary.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :get_enrollment_summary) ->
        Services.GetEnrollmentSummary.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :get_event_information) ->
        Services.GetEventInformation.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :life_safety_operation) ->
        Services.LifeSafetyOperation.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :read_property) ->
        Services.ReadProperty.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :read_property_multiple) ->
        Services.ReadPropertyMultiple.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :read_range) ->
        Services.ReadRange.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :reinitialize_device) ->
        Services.ReinitializeDevice.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :remove_list_element) ->
        Services.RemoveListElement.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :subscribe_cov) ->
        Services.SubscribeCov.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :subscribe_cov_property) ->
        Services.SubscribeCovProperty.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :write_property) ->
        Services.WriteProperty.from_apdu(apdu)

      Constants.macro_assert_name(:confirmed_service_choice, :write_property_multiple) ->
        Services.WritePropertyMultiple.from_apdu(apdu)

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
    def expects_reply(%@for{} = _apdu), do: true

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
      {header, data} = encode_struct(apdu)
      <<header::binary, data::binary>>
    end

    @spec supports_segmentation(@for.t()) :: boolean()
    def supports_segmentation(_apdu), do: true

    @spec encode_segmented(@for.t(), integer()) :: [binary()]
    def encode_segmented(
          %@for{proposed_window_size: window_size} = apdu,
          apdu_size
        )
        when window_size != nil do
      case encode_struct(apdu) do
        {header, ""} ->
          [<<header::binary>>]

        {header, data} ->
          # Rework header, add Segmentation and More Follows bit as set
          <<pdu_type::size(4), _segmented::size(2), rest1::bitstring-size(18), service::size(8)>> =
            header

          seg_header = <<pdu_type::size(4), 1::size(1), 1::size(1), rest1::bitstring>>
          last_header = <<pdu_type::size(4), 1::size(1), 0::size(1), rest1::bitstring>>

          0..255//1
          |> Enum.reduce_while({data, []}, fn
            _index, {<<>>, segments} ->
              {:halt, segments}

            index, {data, segments} ->
              start = binary_part(data, 0, min(byte_size(data), apdu_size))

              rest =
                case max(0, byte_size(data) - byte_size(start)) do
                  0 -> ""
                  len -> binary_part(data, apdu_size, len)
                end

              this_header =
                if byte_size(rest) == 0 do
                  last_header
                else
                  seg_header
                end

              # Inject Sequence Number (index) and Window Size into the APCI
              {:cont,
               {rest,
                [
                  <<this_header::bitstring, index::size(8), window_size::size(8),
                    service::size(8), start::binary>>
                  | segments
                ]}}
          end)
          |> Enum.reverse()
      end
    end

    @spec encode_struct(@for.t()) ::
            {header :: binary(), data :: binary()}
    defp encode_struct(
           %@for{
             invoke_id: invoke_id
           } = apdu
         ) do
      unless invoke_id >= 0 and invoke_id <= 255 do
        raise ArgumentError,
              "Invoke ID must be between 0 and 255 inclusive, got: #{inspect(invoke_id)}"
      end

      unless is_nil(apdu.sequence_number) or
               (apdu.sequence_number >= 0 and apdu.sequence_number <= 255) do
        raise ArgumentError,
              "Sequence number must be nil or between 0 and 255 inclusive, " <>
                "got: #{inspect(apdu.sequence_number)}"
      end

      unless is_nil(apdu.proposed_window_size) or
               (apdu.proposed_window_size >= 0 and apdu.proposed_window_size <= 255) do
        raise ArgumentError,
              "Proposed window size must be nil or between 0 and 255 inclusive, " <>
                "got: #{inspect(apdu.proposed_window_size)}"
      end

      unless (is_nil(apdu.sequence_number) and is_nil(apdu.proposed_window_size)) or
               (is_integer(apdu.sequence_number) and is_integer(apdu.proposed_window_size)) do
        raise ArgumentError,
              "Sequence number and proposed window size must both be nil or an integer (same data type)"
      end

      service =
        if is_atom(apdu.service) do
          Constants.by_name!(:confirmed_service_choice, apdu.service)
        else
          apdu.service
        end

      seg_accepted = if apdu.segmented_response_accepted, do: 1, else: 0
      parameters = encode_parameters(apdu.parameters)

      header =
        <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), 0::size(2),
          seg_accepted::size(1), 0::size(2), max_segments_to_binary(apdu.max_segments)::size(3),
          max_apdu_to_binary(apdu.max_apdu)::size(4), invoke_id::size(8), service::size(8)>>

      {header, parameters}
    end

    @spec encode_parameters(term()) :: binary()
    defp encode_parameters(parameters) when is_list(parameters) do
      Enum.reduce(parameters, <<>>, fn param, acc ->
        case ApplicationTags.encode(param) do
          {:ok, bin} ->
            <<acc::binary, bin::binary>>

          {:error, err} ->
            raise "Unable to encode parameters in confirmed service request encode, error: #{inspect(err)}"
        end
      end)
    end

    @spec max_segments_to_binary(non_neg_integer() | :more_than_64 | :unspecified) :: byte()
    defp max_segments_to_binary(2),
      do: Constants.macro_by_name(:max_segments_accepted, :segments_2)

    defp max_segments_to_binary(4),
      do: Constants.macro_by_name(:max_segments_accepted, :segments_4)

    defp max_segments_to_binary(8),
      do: Constants.macro_by_name(:max_segments_accepted, :segments_8)

    defp max_segments_to_binary(16),
      do: Constants.macro_by_name(:max_segments_accepted, :segments_16)

    defp max_segments_to_binary(32),
      do: Constants.macro_by_name(:max_segments_accepted, :segments_32)

    defp max_segments_to_binary(64),
      do: Constants.macro_by_name(:max_segments_accepted, :segments_64)

    defp max_segments_to_binary(:more_than_64),
      do: Constants.macro_by_name(:max_segments_accepted, :segments_65)

    defp max_segments_to_binary(:unspecified),
      do: Constants.macro_by_name(:max_segments_accepted, :segments_0)

    @spec max_apdu_to_binary(non_neg_integer()) :: byte()
    defp max_apdu_to_binary(50),
      do: Constants.macro_by_name(:max_apdu_length_accepted, :octets_50)

    defp max_apdu_to_binary(128),
      do: Constants.macro_by_name(:max_apdu_length_accepted, :octets_128)

    defp max_apdu_to_binary(206),
      do: Constants.macro_by_name(:max_apdu_length_accepted, :octets_206)

    defp max_apdu_to_binary(480),
      do: Constants.macro_by_name(:max_apdu_length_accepted, :octets_480)

    defp max_apdu_to_binary(1024),
      do: Constants.macro_by_name(:max_apdu_length_accepted, :octets_1024)

    defp max_apdu_to_binary(1476),
      do: Constants.macro_by_name(:max_apdu_length_accepted, :octets_1476)
  end
end
