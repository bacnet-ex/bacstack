defmodule BACnet.Protocol.APDU do
  @moduledoc """
  This module provides decoding of Application Data Units (APDU).
  Encoding of APDUs are directly handled in the APDU modules.

  APDUs can be segmented and thus will require processing and merging the segments.
  The module `BACnet.Stack.SegmentsStore` fulfills this purpose and
  thus all `incomplete` tuples received from `decode/1` should be passed
  to an instance of that module (preferably under a supervisor).
  Only `ComplexACK` and `ConfirmedServiceRequest` APDUs can be segmented,
  as specified by the BACnet protocol specification.
  See also the `BACnet.Stack.SegmentsStore` module documentation.

  See also:
  - `BACnet.Protocol.APDU.Abort`
  - `BACnet.Protocol.APDU.ComplexACK`
  - `BACnet.Protocol.APDU.ConfirmedServiceRequest`
  - `BACnet.Protocol.APDU.Error`
  - `BACnet.Protocol.APDU.Reject`
  - `BACnet.Protocol.APDU.SegmentACK`
  - `BACnet.Protocol.APDU.SimpleACK`
  - `BACnet.Protocol.APDU.UnconfirmedServiceRequest`
  """

  # TODO: Docs

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.IncompleteAPDU

  require Constants

  @doc """
  Decodes the APDU. The binary data must contain only APDU data.

  If the APDU is segmented, this function will return an incomplete tuple,
  which must be handled by the `BACnet.Stack.SegmentsStore` module.

  See the `BACnet.Stack.SegmentsStore` module documentation for
  more information about incoming segmentation (`:segmented_receive`).
  """
  @spec decode(binary()) ::
          {:ok, Protocol.apdu()}
          | {:error, term()}
          | {:incomplete, IncompleteAPDU.t()}
  def decode(data)

  def decode(<<apdu_type::size(8), apdu_data::binary>>) do
    case Bitwise.bsr(apdu_type, 4) do
      Constants.macro_by_name(:pdu_type, :confirmed_request) ->
        decode_confirmed_request(apdu_type, apdu_data)

      Constants.macro_by_name(:pdu_type, :unconfirmed_request) ->
        decode_unconfirmed_request(apdu_type, apdu_data)

      Constants.macro_by_name(:pdu_type, :complex_ack) ->
        decode_complex_ack(apdu_type, apdu_data)

      Constants.macro_by_name(:pdu_type, :simple_ack) ->
        decode_simple_ack(apdu_type, apdu_data)

      Constants.macro_by_name(:pdu_type, :segment_ack) ->
        decode_segment_ack(apdu_type, apdu_data)

      Constants.macro_by_name(:pdu_type, :abort) ->
        decode_abort(apdu_type, apdu_data)

      Constants.macro_by_name(:pdu_type, :error) ->
        decode_error(apdu_type, apdu_data)

      Constants.macro_by_name(:pdu_type, :reject) ->
        decode_reject(apdu_type, apdu_data)

      _any ->
        {:error, :invalid_apdu_type}
    end
  end

  def decode(data) when is_binary(data) do
    {:error, :insufficient_apdu_data}
  end

  @doc """
  Decodes the Confirmed Service Request APDU from binary data.

  When encountering segmentation, this function will return an `incomplete` tuple.
  See `BACnet.Protocol` module for more information.
  """
  @spec decode_confirmed_request(byte(), binary()) ::
          {:ok, __MODULE__.ConfirmedServiceRequest.t()}
          | {:error, term()}
          | {:incomplete, BACnet.Protocol.IncompleteAPDU.t()}
  def decode_confirmed_request(apdu_type, apdu_data)
      when is_integer(apdu_type) and is_binary(apdu_data) do
    <<_pdu::size(4), segmented::size(1), more_follows::size(1), seg_resp_accepted::size(1),
      _filler::size(1)>> = <<apdu_type::size(8)>>

    segmented = segmented == 1
    more_follows = more_follows == 1
    seg_resp_accepted = seg_resp_accepted == 1

    # If segmented, break the data apart and return it
    # It will be after-processed by the SegmentsStore module
    if segmented do
      with <<_any::size(1), _max_segments::size(3), _max_apdu::size(4), real_apdu_data::binary>> <-
             apdu_data,
           {:ok, {invoke_id, seq_number, window_size, service, data}} <-
             data_segments_info_extract(real_apdu_data, segmented) do
        incomplete = %IncompleteAPDU{
          # Remove the segmented bit for the header
          header:
            <<Bitwise.band(apdu_type, 0xF7)::size(8), invoke_id::size(8), service::size(8)>>,
          server: true,
          invoke_id: invoke_id,
          sequence_number: seq_number,
          window_size: window_size,
          more_follows: more_follows,
          data: data
        }

        {:incomplete, incomplete}
      else
        term when is_binary(term) -> {:error, :invalid_apdu_confirmed_request_data}
        {:error, _err} = err -> err
      end
    else
      case apdu_data do
        <<_any::size(1), max_segments::size(3), max_apdu::size(4), data::binary>> ->
          with {:ok, {invoke_id, seq_number, window_size, service, tags}} <-
                 data_segments_info_extract(data, segmented),
               {:ok, values} <- read_tags_until_exhaust(tags) do
            request = %__MODULE__.ConfirmedServiceRequest{
              segmented_response_accepted: seg_resp_accepted,
              max_apdu: max_apdu_to_int(max_apdu),
              max_segments: max_segments_to_int_atom(max_segments),
              invoke_id: invoke_id,
              sequence_number: seq_number,
              proposed_window_size: window_size,
              service: Constants.by_value_safe(:confirmed_service_choice, service, service),
              parameters: values
            }

            {:ok, request}
          else
            {:error, _err} = err -> err
          end

        _any ->
          {:error, :invalid_apdu_confirmed_request_data}
      end
    end
  end

  @doc """
  Decodes the Unconfirmed Service Request APDU from binary data.
  """
  @spec decode_unconfirmed_request(byte(), binary()) ::
          {:ok, __MODULE__.UnconfirmedServiceRequest.t()} | {:error, term()}
  def decode_unconfirmed_request(apdu_type, apdu_data)
      when is_integer(apdu_type) and is_binary(apdu_data) do
    case apdu_data do
      <<service::size(8), tags::binary>> ->
        case read_tags_until_exhaust(tags) do
          {:ok, parameters} ->
            request = %__MODULE__.UnconfirmedServiceRequest{
              service: Constants.by_value_safe(:unconfirmed_service_choice, service, service),
              parameters: parameters
            }

            {:ok, request}

          term ->
            term
        end

      _any ->
        {:error, :invalid_apdu_unconfirmed_request_data}
    end
  end

  @doc """
  Decodes the Simple ACK APDU from binary data.
  """
  @spec decode_simple_ack(byte(), binary()) ::
          {:ok, __MODULE__.SimpleACK.t()} | {:error, term()}
  def decode_simple_ack(apdu_type, apdu_data)
      when is_integer(apdu_type) and is_binary(apdu_data) do
    case apdu_data do
      <<invoke_id::size(8), service::size(8)>> ->
        ack = %__MODULE__.SimpleACK{
          invoke_id: invoke_id,
          service: Constants.by_value_safe(:confirmed_service_choice, service, service)
        }

        {:ok, ack}

      _any ->
        {:error, :invalid_apdu_simple_ack_data}
    end
  end

  @doc """
  Decodes the Complex ACK APDU from binary data.

  When encountering segmentation, this function will return an `incomplete` tuple.
  See `BACnet.Protocol` module for more information.
  """
  @spec decode_complex_ack(byte(), binary()) ::
          {:ok, __MODULE__.ComplexACK.t()}
          | {:error, term()}
          | {:incomplete, BACnet.Protocol.IncompleteAPDU.t()}
  def decode_complex_ack(apdu_type, apdu_data)
      when is_integer(apdu_type) and is_binary(apdu_data) do
    segmented = Bitwise.band(apdu_type, 0x08) == 0x08
    more_follows = Bitwise.band(apdu_type, 0x04) == 0x04

    # If segmented, break the data apart and return it
    # It will be after-processed by the SegmentsStore module
    if segmented do
      case data_segments_info_extract(apdu_data, segmented) do
        {:ok, {invoke_id, seq_number, window_size, service, data}} ->
          incomplete = %IncompleteAPDU{
            # Remove the segmented bit for the header
            header:
              <<Bitwise.band(apdu_type, 0xF7)::size(8), invoke_id::size(8), service::size(8)>>,
            server: false,
            invoke_id: invoke_id,
            sequence_number: seq_number,
            window_size: window_size,
            more_follows: more_follows,
            data: data
          }

          {:incomplete, incomplete}

        {:error, _term} = err ->
          err
      end
    else
      with {:ok, {invoke_id, seq_number, window_size, service, tags}} <-
             data_segments_info_extract(apdu_data, segmented),
           {:ok, values} <- read_tags_until_exhaust(tags) do
        ack = %__MODULE__.ComplexACK{
          invoke_id: invoke_id,
          sequence_number: seq_number,
          proposed_window_size: window_size,
          service: Constants.by_value_safe(:confirmed_service_choice, service, service),
          payload: values
        }

        {:ok, ack}
      else
        {:error, _err} = err -> err
      end
    end
  end

  @doc """
  Decodes the Segment ACK APDU from binary data.
  """
  @spec decode_segment_ack(byte(), binary()) ::
          {:ok, __MODULE__.SegmentACK.t()} | {:error, term()}
  def decode_segment_ack(apdu_type, apdu_data)
      when is_integer(apdu_type) and is_binary(apdu_data) do
    case apdu_data do
      <<invoke_id::size(8), seq_number::size(8), window_size::size(8)>> ->
        ack = %__MODULE__.SegmentACK{
          negative_ack: Bitwise.band(apdu_type, 0x02) == 0x02,
          sent_by_server: Bitwise.band(apdu_type, 0x01) == 0x01,
          invoke_id: invoke_id,
          sequence_number: seq_number,
          actual_window_size: window_size
        }

        {:ok, ack}

      _any ->
        {:error, :invalid_apdu_segment_ack_data}
    end
  end

  @doc """
  Decodes the Abort APDU from binary data.
  """
  @spec decode_abort(byte(), binary()) :: {:ok, __MODULE__.Abort.t()} | {:error, term()}
  def decode_abort(apdu_type, apdu_data) when is_integer(apdu_type) and is_binary(apdu_data) do
    case apdu_data do
      <<invoke_id::size(8), reason::size(8)>> ->
        abort = %__MODULE__.Abort{
          sent_by_server: Bitwise.band(apdu_type, 0x01) == 0x01,
          invoke_id: invoke_id,
          reason: Constants.by_value_safe(:abort_reason, reason, reason)
        }

        {:ok, abort}

      _any ->
        {:error, :invalid_apdu_abort_data}
    end
  end

  @doc """
  Decodes the Error APDU from binary data.
  """
  @spec decode_error(byte(), binary()) :: {:ok, __MODULE__.Error.t()} | {:error, term()}
  def decode_error(apdu_type, apdu_data) when is_integer(apdu_type) and is_binary(apdu_data) do
    case apdu_data do
      <<invoke_id::size(8), service::size(8), data::binary>> ->
        with {:ok, tags} <- read_tags_until_exhaust(data),
             {:ok, {class, code}, payload} <- extract_error_code_and_class(tags) do
          error = %__MODULE__.Error{
            invoke_id: invoke_id,
            service: Constants.by_value_safe(:confirmed_service_choice, service, service),
            class: Constants.by_value_safe(:error_class, class, class),
            code: Constants.by_value_safe(:error_code, code, code),
            payload: payload
          }

          {:ok, error}
        else
          {:error, _err} = err -> err
        end

      _any ->
        {:error, :invalid_apdu_error_data}
    end
  end

  @doc """
  Decodes the Reject APDU from binary data.
  """
  @spec decode_reject(byte(), binary()) :: {:ok, __MODULE__.Reject.t()} | {:error, term()}
  def decode_reject(apdu_type, apdu_data) when is_integer(apdu_type) and is_binary(apdu_data) do
    case apdu_data do
      <<invoke_id::size(8), reason::size(8)>> ->
        reject = %__MODULE__.Reject{
          invoke_id: invoke_id,
          reason: Constants.by_value_safe(:reject_reason, reason, reason)
        }

        {:ok, reject}

      _any ->
        {:error, :invalid_apdu_reject_data}
    end
  end

  @doc """
  Extracts the invoke ID from the given raw APDU.

  This is useful for replying to APDUs, which can not be properly fully decoded.
  """
  @spec get_invoke_id_from_raw_apdu(binary) :: {:ok, invoke_id :: byte()} | {:error, term()}
  def get_invoke_id_from_raw_apdu(apdu)

  def get_invoke_id_from_raw_apdu(
        <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), _pdu::size(4),
          _filler::size(8), invoke_id::size(8), _rest::binary>>
      ) do
    {:ok, invoke_id}
  end

  def get_invoke_id_from_raw_apdu(
        <<Constants.macro_by_name(:pdu_type, :complex_ack)::size(4), _pdu::size(4),
          invoke_id::size(8), _rest::binary>>
      ) do
    {:ok, invoke_id}
  end

  def get_invoke_id_from_raw_apdu(
        <<Constants.macro_by_name(:pdu_type, :simple_ack)::size(4), _pdu::size(4),
          invoke_id::size(8), _rest::binary>>
      ) do
    {:ok, invoke_id}
  end

  def get_invoke_id_from_raw_apdu(
        <<Constants.macro_by_name(:pdu_type, :segment_ack)::size(4), _pdu::size(4),
          invoke_id::size(8), _rest::binary>>
      ) do
    {:ok, invoke_id}
  end

  def get_invoke_id_from_raw_apdu(
        <<Constants.macro_by_name(:pdu_type, :abort)::size(4), _pdu::size(4), invoke_id::size(8),
          _rest::binary>>
      ) do
    {:ok, invoke_id}
  end

  def get_invoke_id_from_raw_apdu(
        <<Constants.macro_by_name(:pdu_type, :error)::size(4), _pdu::size(4), invoke_id::size(8),
          _rest::binary>>
      ) do
    {:ok, invoke_id}
  end

  def get_invoke_id_from_raw_apdu(
        <<Constants.macro_by_name(:pdu_type, :reject)::size(4), _pdu::size(4), invoke_id::size(8),
          _rest::binary>>
      ) do
    {:ok, invoke_id}
  end

  def get_invoke_id_from_raw_apdu(_apdu) do
    {:error, :invalid_apdu}
  end

  @spec data_segments_info_extract(binary(), boolean()) ::
          {:ok, {integer(), integer() | nil, integer() | nil, integer(), binary()}}
          | {:error, term()}
  defp data_segments_info_extract(apdu_data, segmented)

  defp data_segments_info_extract(
         <<invoke_id::size(8), seq_number::size(8), window_size::size(8), service::size(8),
           tags::binary>>,
         true
       ) do
    {:ok, {invoke_id, seq_number, window_size, service, tags}}
  end

  defp data_segments_info_extract(<<invoke_id::size(8), service::size(8), tags::binary>>, false) do
    {:ok, {invoke_id, nil, nil, service, tags}}
  end

  defp data_segments_info_extract(_apdu_data, _segmented), do: {:error, :invalid_apdu_data}

  @spec read_tags_until_exhaust(binary()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  defp read_tags_until_exhaust(tags) when is_binary(tags) do
    1..byte_size(tags)//1
    |> Enum.reduce_while({:ok, {tags, []}}, fn
      _index, {:ok, {<<>>, acc}} ->
        {:halt, {:ok, {"", acc}}}

      _index, {:ok, {tags, acc}} ->
        case ApplicationTags.decode(tags) do
          {:ok, value, rest} -> {:cont, {:ok, {rest, [value | acc]}}}
          {:error, _err} = err -> {:halt, err}
        end
    end)
    |> case do
      {:ok, {_tags, []}} -> {:ok, []}
      {:ok, {_tags, list}} -> {:ok, Enum.reverse(list)}
      term -> term
    end
  end

  @spec extract_error_code_and_class(ApplicationTags.encoding_list()) ::
          {:ok, {class :: integer(), code :: integer()}, list()} | {:error, term()}
  defp extract_error_code_and_class(tags)

  defp extract_error_code_and_class([
         {:constructed, {0, [enumerated: class, enumerated: code], 0}} | tail
       ]) do
    {:ok, {class, code}, tail}
  end

  defp extract_error_code_and_class([{:enumerated, class}, {:enumerated, code} | tail]) do
    {:ok, {class, code}, tail}
  end

  defp extract_error_code_and_class(_term), do: {:error, :unknown_tag_encoding}

  @spec max_segments_to_int_atom(byte()) :: non_neg_integer() | :unspecified | :more_than_64
  defp max_segments_to_int_atom(Constants.macro_by_name(:max_segments_accepted, :segments_0)),
    do: :unspecified

  defp max_segments_to_int_atom(Constants.macro_by_name(:max_segments_accepted, :segments_2)),
    do: 2

  defp max_segments_to_int_atom(Constants.macro_by_name(:max_segments_accepted, :segments_4)),
    do: 4

  defp max_segments_to_int_atom(Constants.macro_by_name(:max_segments_accepted, :segments_8)),
    do: 8

  defp max_segments_to_int_atom(Constants.macro_by_name(:max_segments_accepted, :segments_16)),
    do: 16

  defp max_segments_to_int_atom(Constants.macro_by_name(:max_segments_accepted, :segments_32)),
    do: 32

  defp max_segments_to_int_atom(Constants.macro_by_name(:max_segments_accepted, :segments_64)),
    do: 64

  defp max_segments_to_int_atom(Constants.macro_by_name(:max_segments_accepted, :segments_65)),
    do: :more_than_64

  @spec max_apdu_to_int(byte()) :: non_neg_integer()
  defp max_apdu_to_int(Constants.macro_by_name(:max_apdu_length_accepted, :octets_50)), do: 50
  defp max_apdu_to_int(Constants.macro_by_name(:max_apdu_length_accepted, :octets_128)), do: 128
  defp max_apdu_to_int(Constants.macro_by_name(:max_apdu_length_accepted, :octets_206)), do: 206
  defp max_apdu_to_int(Constants.macro_by_name(:max_apdu_length_accepted, :octets_480)), do: 480
  defp max_apdu_to_int(Constants.macro_by_name(:max_apdu_length_accepted, :octets_1024)), do: 1024
  defp max_apdu_to_int(Constants.macro_by_name(:max_apdu_length_accepted, :octets_1476)), do: 1476
end
