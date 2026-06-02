defmodule BACnet.Protocol.APDU do
  @moduledoc """
  This module provides decoding of Application Data Units (APDU).

  APDUs form the application layer of the BACnet protocol. Every BACnet message
  exchanged between devices ultimately carries an APDU (after the NPCI and optional
  BVLL headers). See Clause 5.1 and 5.3 for the application layer model and
  transmission of APDUs.

  The canonical definitions of all APDU types are given in Clause 21 as an ASN.1
  module (`BACnetModule`). The fixed-part encoding rules (APCI) are in Clause 20.1.

  Encoding of APDUs is handled directly by the individual APDU submodules via their
  `encode/1` function (or through the `BACnet.Stack.EncoderProtocol`).

  ## APDU Types

  The BACnet standard defines eight APDU types, identified by the high nibble of the
  first byte (PDU Type):

  | Type                          | PDU | Sent By     | Requires Reply | Segmentation | Description                                                                                                             |
  |-------------------------------|-----|-------------|----------------|--------------|:------------------------------------------------------------------------------------------------------------------------|
  | `ConfirmedServiceRequest`     | 0   | Client      | Yes            | Yes          | Confirmed service invocation (Read/Write, etc.). See `BACnet-Confirmed-Request-PDU` in Clause 21                        |
  | `UnconfirmedServiceRequest`   | 1   | Either      | No             | No           | Unconfirmed services (Who-Is, I-Am, COV notifications, ...). See `BACnet-Unconfirmed-Request-PDU` in Clause 21          |
  | `SimpleACK`                   | 2   | Server      | No             | No           | Positive reply for services that return no data. See `BACnet-SimpleACK-PDU` in Clause 21                                |
  | `ComplexACK`                  | 3   | Server      | No             | Yes          | Positive reply containing data (property values, etc.). See `BACnet-ComplexACK-PDU` in Clause 21                        |
  | `SegmentACK`                  | 4   | Either      | No             | No           | Acknowledges received segments and/or requests more. See `BACnet-SegmentACK-PDU` in Clause 21                           |
  | `Error`                       | 5   | Server      | No             | No           | Service failed; contains error class + code (+ optional payload). See `BACnet-Error-PDU` in Clause 21                   |
  | `Reject`                      | 6   | Server      | No             | No           | Request rejected due to protocol/syntax error (before execution). See `BACnet-Reject-PDU` in Clause 21 and Clause 18.8  |
  | `Abort`                       | 7   | Either      | No             | No           | Transaction aborted (timeout, resources, security, etc.). See `BACnet-Abort-PDU` in Clause 21 and Clause 18.10          |

  ## Segmentation

  Only `ConfirmedServiceRequest` and `ComplexACK` APDUs support segmentation.
  When the "segmented" flag is set, `decode/1` (and the specific `decode_*` functions)
  return an `{:incomplete, BACnet.Protocol.IncompleteAPDU.t()}` tuple.

  These incomplete APDUs **must** be passed to a `BACnet.Stack.SegmentsStore`
  instance (usually started under a supervisor), so that segments can be reassembled.
  Once reassembly is complete, the `SegmentsStore` returns the full APDU for decoding.

  The companion `BACnet.Stack.Segmentator` is used when *sending* segmented APDU.

  See the `BACnet.Stack.SegmentsStore` and `BACnet.Stack.Segmentator` documentation
  for details and configuration (timeouts, window sizes, etc.).

  ## Working with APDUs

  Most applications should use the higher-level service modules
  (`BACnet.Protocol.Services.*`) together with `BACnet.Stack.Client` / `BACnet.Stack.ClientHelper`.
  Direct APDU manipulation is useful for:
  - Implementing new services
  - Low-level debugging / protocol analysis tools
  - Building test harnesses or fuzzers

  ### Decoding raw data

      iex> raw = <<0x20, 0x46, 0x0F>>  # Simple-ACK, invoke_id=70, service=15 (write_property)
      iex> APDU.decode(raw)
      {:ok, %APDU.SimpleACK{invoke_id: 70, service: :write_property}}

  ### Encoding an APDU directly

      iex> apdu = %APDU.Abort{
      ...>   sent_by_server: false,
      ...>   invoke_id: 42,
      ...>   reason: :other
      ...> }
      iex> APDU.Abort.encode(apdu)
      {:ok, <<0x70, 0x2A, 0x00>>}

  ### Converting a request APDU into a high-level service struct

      iex> {:ok, req} = APDU.decode(<<0x02, 0x03, 0x23, 0x0F, 0x0C, 0x00, 0x80, 0x00, 0x00, 0x19, 0x55, 0x3E, 0x44, 0x42, 0xC8, 0x00, 0x00, 0x3F, 0x49, 0x0A>>)
      iex> %APDU.ConfirmedServiceRequest{service: :write_property} = req
      iex> APDU.ConfirmedServiceRequest.to_service(req)
      {:ok, %BACnet.Protocol.Services.WriteProperty{
        object_identifier: %BACnet.Protocol.ObjectIdentifier{type: :analog_value, instance: 0},
        priority: 10,
        property_array_index: nil,
        property_identifier: :present_value,
        property_value: %BACnet.Protocol.ApplicationTags.Encoding{type: :real, value: 100.0, encoding: :primitive, extras: []}
      }}

  ## See Also

  - `BACnet.Protocol` - top-level PDU decoding (BVLL / NPCI)
  - `BACnet.Protocol.APDU.Abort`
  - `BACnet.Protocol.APDU.ComplexACK`
  - `BACnet.Protocol.APDU.ConfirmedServiceRequest`
  - `BACnet.Protocol.APDU.Error`
  - `BACnet.Protocol.APDU.Reject`
  - `BACnet.Protocol.APDU.SegmentACK`
  - `BACnet.Protocol.APDU.SimpleACK`
  - `BACnet.Protocol.APDU.UnconfirmedServiceRequest`
  - `BACnet.Protocol.IncompleteAPDU`
  - `BACnet.Stack.Segmentator`
  - `BACnet.Stack.SegmentsStore`
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.IncompleteAPDU

  require Constants

  @doc """
  Decodes a complete APDU from raw binary data.

  The binary must start with a valid APDU header (PDU type in the high nibble of
  the first byte). Only the APDU portion should be passed (i.e. after any BVLL
  and NPCI headers have been stripped).

  On success a typed APDU struct is returned. When the APDU is the first (or a
  subsequent) segment of a segmented message, `{:incomplete, IncompleteAPDU.t()}`
  is returned instead. Pass that value to a `BACnet.Stack.SegmentsStore` so the
  full message can be reassembled.

  ### Examples

      iex> APDU.decode(<<0x20, 0x46, 0x0F>>)
      {:ok, %APDU.SimpleACK{invoke_id: 70, service: :write_property}}

      iex> APDU.decode(<<0x10, 0x00, 0xC4, 0x02, 0x00, 0x00, 0x03, 0x22, 0x05, 0xC4, 0x23, 0x00, 0x21, 0x01>>)
      {:ok, %APDU.UnconfirmedServiceRequest{service: :i_am, parameters: [{:object_identifier, %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 3}}, {:unsigned_integer, 1476}, {:unsigned_integer, 8449}]}}

      iex> APDU.decode(<<0x10, 0x08>>)
      {:ok, %APDU.UnconfirmedServiceRequest{service: :who_is, parameters: []}}

      iex> APDU.decode(<<0x60, 0x2A, 0x01>>)
      {:ok, %APDU.Reject{invoke_id: 42, reason: :buffer_overflow}}

      iex> APDU.decode(<<0xFF>>)
      {:error, :invalid_apdu_type}

  Segmented messages return an incomplete tuple that must be handled by `SegmentsStore`:

      iex> {:incomplete, inc} = APDU.decode(<<10, 117, 1, 0, 8, 12, 145, 0, 117, 11, 0, 104, 101, 108, 108, 111>>)
      iex> inc.invoke_id
      1

  See `BACnet.Stack.SegmentsStore` for handling of segmented traffic and the
  individual `decode_*` functions for type-specific decoding.
  """
  @spec decode(binary()) ::
          {:ok, Protocol.apdu()}
          | {:error, term()}
          | {:incomplete, IncompleteAPDU.t()}
  def decode(data)

  def decode(
        <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), _filler::size(4),
          _rest::binary>> = apdu_data
      ),
      do: decode_confirmed_request(apdu_data)

  def decode(
        <<Constants.macro_by_name(:pdu_type, :unconfirmed_request)::size(4), _filler::size(4),
          _rest::binary>> = apdu_data
      ),
      do: decode_unconfirmed_request(apdu_data)

  def decode(
        <<Constants.macro_by_name(:pdu_type, :complex_ack)::size(4), _filler::size(4),
          _rest::binary>> = apdu_data
      ),
      do: decode_complex_ack(apdu_data)

  def decode(
        <<Constants.macro_by_name(:pdu_type, :simple_ack)::size(4), _filler::size(4),
          _rest::binary>> = apdu_data
      ),
      do: decode_simple_ack(apdu_data)

  def decode(
        <<Constants.macro_by_name(:pdu_type, :segment_ack)::size(4), _filler::size(4),
          _rest::binary>> = apdu_data
      ),
      do: decode_segment_ack(apdu_data)

  def decode(
        <<Constants.macro_by_name(:pdu_type, :abort)::size(4), _filler::size(4), _rest::binary>> =
          apdu_data
      ),
      do: decode_abort(apdu_data)

  def decode(
        <<Constants.macro_by_name(:pdu_type, :error)::size(4), _filler::size(4), _rest::binary>> =
          apdu_data
      ),
      do: decode_error(apdu_data)

  def decode(
        <<Constants.macro_by_name(:pdu_type, :reject)::size(4), _filler::size(4), _rest::binary>> =
          apdu_data
      ),
      do: decode_reject(apdu_data)

  def decode(<<_apdu_type::size(4), _filler::size(4), _rest::binary>>) do
    {:error, :invalid_apdu_type}
  end

  def decode(data) when is_binary(data) do
    {:error, :insufficient_apdu_data}
  end

  @doc """
  Decodes the Confirmed Service Request APDU from binary data.
  The data must contain the APDU header (such as the PDU type byte).

  When encountering segmentation, this function will return an `incomplete` tuple.
  See `BACnet.Protocol` module for more information.
  """
  @spec decode_confirmed_request(binary()) ::
          {:ok, __MODULE__.ConfirmedServiceRequest.t()}
          | {:error, term()}
          | {:incomplete, BACnet.Protocol.IncompleteAPDU.t()}
  def decode_confirmed_request(data)

  # If segmented, break the data apart and return it
  # It will be after-processed by the SegmentsStore module
  # The 1::size(1) after pdu_type means it is segmented
  def decode_confirmed_request(
        <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), 1::size(1),
          more_follows::size(1), seg_resp_accepted::size(1), _filler::size(1), _any::size(1),
          _max_segments::size(3), _max_apdu::size(4), apdu_data::binary>>
      ) do
    with {:ok, {invoke_id, seq_number, window_size, service, data}} <-
           data_segments_info_extract(apdu_data, true) do
      incomplete = %IncompleteAPDU{
        # Remove the segmented bit for the header
        header:
          <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), 0::size(1),
            more_follows::size(1), seg_resp_accepted::size(1), 0::size(1), invoke_id::size(8),
            service::size(8)>>,
        server: true,
        invoke_id: invoke_id,
        sequence_number: seq_number,
        window_size: window_size,
        more_follows: more_follows == 1,
        data: data
      }

      {:incomplete, incomplete}
    end
  end

  # The 0::size(1) after pdu_type means it is not segmented
  def decode_confirmed_request(
        <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), 0::size(1),
          _more_follows::size(1), seg_resp_accepted::size(1), _filler::size(1), _any::size(1),
          max_segments::size(3), max_apdu::size(4), data::binary>>
      ) do
    with {:ok, {invoke_id, seq_number, window_size, service, tags}} <-
           data_segments_info_extract(data, false),
         {:ok, values} <- read_tags_until_exhaust(tags) do
      request = %__MODULE__.ConfirmedServiceRequest{
        segmented_response_accepted: seg_resp_accepted == 1,
        max_apdu: max_apdu_to_int(max_apdu),
        max_segments: max_segments_to_int_atom(max_segments),
        invoke_id: invoke_id,
        sequence_number: seq_number,
        proposed_window_size: window_size,
        service: Constants.by_value(:confirmed_service_choice, service, service),
        parameters: values
      }

      {:ok, request}
    end
  end

  def decode_confirmed_request(
        <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), _apdu_type::size(4),
          _rest::binary>>
      ) do
    {:error, :invalid_apdu_confirmed_request_data}
  end

  @doc """
  Decodes the Unconfirmed Service Request APDU from binary data.
  The data must contain the APDU header (such as the PDU type byte).
  """
  @spec decode_unconfirmed_request(binary()) ::
          {:ok, __MODULE__.UnconfirmedServiceRequest.t()} | {:error, term()}
  def decode_unconfirmed_request(data)

  def decode_unconfirmed_request(
        <<Constants.macro_by_name(:pdu_type, :unconfirmed_request)::size(4), _apdu_type::size(4),
          service::size(8), tags::binary>>
      ) do
    case read_tags_until_exhaust(tags) do
      {:ok, parameters} ->
        request = %__MODULE__.UnconfirmedServiceRequest{
          service: Constants.by_value(:unconfirmed_service_choice, service, service),
          parameters: parameters
        }

        {:ok, request}

      term ->
        term
    end
  end

  def decode_unconfirmed_request(
        <<Constants.macro_by_name(:pdu_type, :unconfirmed_request)::size(4), _apdu_type::size(4),
          _rest::binary>>
      ) do
    {:error, :invalid_apdu_unconfirmed_request_data}
  end

  @doc """
  Decodes the Simple ACK APDU from binary data.
  The data must contain the APDU header (such as the PDU type byte).
  """
  @spec decode_simple_ack(binary()) ::
          {:ok, __MODULE__.SimpleACK.t()} | {:error, term()}
  def decode_simple_ack(data)

  def decode_simple_ack(
        <<Constants.macro_by_name(:pdu_type, :simple_ack)::size(4), _apdu_type::size(4),
          invoke_id::size(8), service::size(8)>>
      ) do
    ack = %__MODULE__.SimpleACK{
      invoke_id: invoke_id,
      service: Constants.by_value(:confirmed_service_choice, service, service)
    }

    {:ok, ack}
  end

  def decode_simple_ack(
        <<Constants.macro_by_name(:pdu_type, :simple_ack)::size(4), _apdu_type::size(4),
          _rest::binary>>
      ) do
    {:error, :invalid_apdu_simple_ack_data}
  end

  @doc """
  Decodes the Complex ACK APDU from binary data.
  The data must contain the APDU header (such as the PDU type byte).

  When encountering segmentation, this function will return an `incomplete` tuple.
  See `BACnet.Protocol` module for more information.
  """
  @spec decode_complex_ack(binary()) ::
          {:ok, __MODULE__.ComplexACK.t()}
          | {:error, term()}
          | {:incomplete, BACnet.Protocol.IncompleteAPDU.t()}
  def decode_complex_ack(data)

  # If segmented, break the data apart and return it
  # It will be after-processed by the SegmentsStore module
  # The 1::size(1) after pdu_type means it is segmented
  def decode_complex_ack(
        <<Constants.macro_by_name(:pdu_type, :complex_ack)::size(4), 1::size(1),
          more_follows::size(1), 0::size(2), apdu_data::binary>>
      ) do
    case data_segments_info_extract(apdu_data, true) do
      {:ok, {invoke_id, seq_number, window_size, service, data}} ->
        incomplete = %IncompleteAPDU{
          # Remove the segmented bit for the header
          header:
            <<Constants.macro_by_name(:pdu_type, :complex_ack)::size(4), 0::size(1),
              more_follows::size(1), 0::size(2), invoke_id::size(8), service::size(8)>>,
          server: false,
          invoke_id: invoke_id,
          sequence_number: seq_number,
          window_size: window_size,
          more_follows: more_follows == 1,
          data: data
        }

        {:incomplete, incomplete}

      {:error, _term} = err ->
        err
    end
  end

  # The 0::size(1) after pdu_type means it is not segmented
  def decode_complex_ack(
        <<Constants.macro_by_name(:pdu_type, :complex_ack)::size(4), 0::size(1),
          _more_follows::size(1), 0::size(2), apdu_data::binary>>
      ) do
    with {:ok, {invoke_id, seq_number, window_size, service, tags}} <-
           data_segments_info_extract(apdu_data, false),
         {:ok, values} <- read_tags_until_exhaust(tags) do
      ack = %__MODULE__.ComplexACK{
        invoke_id: invoke_id,
        sequence_number: seq_number,
        proposed_window_size: window_size,
        service: Constants.by_value(:confirmed_service_choice, service, service),
        payload: values
      }

      {:ok, ack}
    end
  end

  @doc """
  Decodes the Segment ACK APDU from binary data.
  The data must contain the APDU header (such as the PDU type byte).
  """
  @spec decode_segment_ack(binary()) ::
          {:ok, __MODULE__.SegmentACK.t()} | {:error, term()}
  def decode_segment_ack(data)

  def decode_segment_ack(
        <<Constants.macro_by_name(:pdu_type, :segment_ack)::size(4), apdu_type::size(4),
          invoke_id::size(8), seq_number::size(8), window_size::size(8)>>
      ) do
    ack = %__MODULE__.SegmentACK{
      negative_ack: Bitwise.band(apdu_type, 0x02) == 0x02,
      sent_by_server: Bitwise.band(apdu_type, 0x01) == 0x01,
      invoke_id: invoke_id,
      sequence_number: seq_number,
      actual_window_size: window_size
    }

    {:ok, ack}
  end

  def decode_segment_ack(
        <<Constants.macro_by_name(:pdu_type, :segment_ack)::size(4), _apdu_type::size(4),
          _rest::binary>>
      ) do
    {:error, :invalid_apdu_segment_ack_data}
  end

  @doc """
  Decodes the Abort APDU from binary data.
  The data must contain the APDU header (such as the PDU type byte).
  """
  @spec decode_abort(binary()) :: {:ok, __MODULE__.Abort.t()} | {:error, term()}
  def decode_abort(data)

  def decode_abort(
        <<Constants.macro_by_name(:pdu_type, :abort)::size(4), apdu_type::size(4),
          invoke_id::size(8), reason::size(8)>>
      ) do
    abort = %__MODULE__.Abort{
      sent_by_server: Bitwise.band(apdu_type, 0x01) == 0x01,
      invoke_id: invoke_id,
      reason: Constants.by_value(:abort_reason, reason, reason)
    }

    {:ok, abort}
  end

  def decode_abort(
        <<Constants.macro_by_name(:pdu_type, :abort)::size(4), _apdu_type::size(4),
          _rest::binary>>
      ) do
    {:error, :invalid_apdu_abort_data}
  end

  @doc """
  Decodes the Error APDU from binary data.
  The data must contain the APDU header (such as the PDU type byte).
  """
  @spec decode_error(binary()) :: {:ok, __MODULE__.Error.t()} | {:error, term()}
  def decode_error(data)

  def decode_error(
        <<Constants.macro_by_name(:pdu_type, :error)::size(4), _apdu_type::size(4),
          invoke_id::size(8), service::size(8), data::binary>>
      ) do
    with {:ok, tags} <- read_tags_until_exhaust(data),
         {:ok, {class, code}, payload} <- extract_error_code_and_class(tags) do
      error = %__MODULE__.Error{
        invoke_id: invoke_id,
        service: Constants.by_value(:confirmed_service_choice, service, service),
        class: Constants.by_value(:error_class, class, class),
        code: Constants.by_value(:error_code, code, code),
        payload: payload
      }

      {:ok, error}
    else
      {:error, _err} = err -> err
    end
  end

  def decode_error(
        <<Constants.macro_by_name(:pdu_type, :error)::size(4), _apdu_type::size(4),
          _rest::binary>>
      ) do
    {:error, :invalid_apdu_error_data}
  end

  @doc """
  Decodes the Reject APDU from binary data.
  The data must contain the APDU header (such as the PDU type byte).
  """
  @spec decode_reject(binary()) :: {:ok, __MODULE__.Reject.t()} | {:error, term()}
  def decode_reject(data)

  def decode_reject(
        <<Constants.macro_by_name(:pdu_type, :reject)::size(4), _apdu_type::size(4),
          invoke_id::size(8), reason::size(8)>>
      ) do
    reject = %__MODULE__.Reject{
      invoke_id: invoke_id,
      reason: Constants.by_value(:reject_reason, reason, reason)
    }

    {:ok, reject}
  end

  def decode_reject(
        <<Constants.macro_by_name(:pdu_type, :reject)::size(4), _apdu_type::size(4),
          _rest::binary>>
      ) do
    {:error, :invalid_apdu_reject_data}
  end

  @doc """
  Extracts the invoke ID from a raw APDU binary without full decoding.

  This is particularly useful when you need to send an Abort or Reject reply
  for a message that is too malformed to be decoded by the normal `decode/1`
  functions, or when performing very early filtering / logging.

  Only APDU types that carry an invoke ID are supported.

  ### Example

      iex> raw = <<0x02, 0x03, 0x23, 0x0F, 0x0C, 0x00, 0x80, 0x00, 0x00, 0x19, 0x55>>
      iex> APDU.get_invoke_id_from_raw_apdu(raw)
      {:ok, 35}

      iex> APDU.get_invoke_id_from_raw_apdu(<<0x71, 0x07, 0x04>>)
      {:ok, 7}

  Returns `{:error, :invalid_apdu}` for unconfirmed requests or completely
  truncated headers.
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
