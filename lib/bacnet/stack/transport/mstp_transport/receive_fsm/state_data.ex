if Code.ensure_loaded?(Circuits.UART) do
  defmodule BACnet.Stack.Transport.MstpTransport.ReceiveFSM.StateData do
    @moduledoc false

    alias BACnet.Stack.Transport.MstpTransport

    @typedoc """
    Receive State Data for the MS/TP Transport Receive State Machine.

    From ASHRAE 135 Clause 9.5.2:

    DataCRC: Used to accumulate the CRC on the data field of a frame.
    DataLength: Used to store the data length of a received frame.
    DestinationAddress: Used to store the destination address of a received frame.
    EventCount: Used to count the number of received octets or errors. This is used in the detection of link activity.
    FrameType: Used to store the frame type of a received frame.
    HeaderCRC: Used to accumulate the CRC on the header of a frame.
    Index: Used as an index by the Receive State Machine, up to the value of DataLength+1.
    InputBuffer[]: An array of octets, used to store octets as they are received. InputBuffer is indexed from 0 to InputBufferSize-1.
    GoodHeader: A Boolean flag set to TRUE or FALSE by the CheckHeader procedure (see Clause 9.5.8).
    ReceivedInvalidFrame: A Boolean flag set to TRUE by the Receive State Machine if an error is detected during the reception of a frame.
    ReceivedValidFrame: A Boolean flag set to TRUE by the Receive State Machine if a valid frame is received.
    SilenceTimer: A timer with nominal 5 millisecond resolution used to measure and generate silence on the medium between octets.
                  It is incremented by a timer process and is cleared by the Receive State Machine when activity is detected and
                  by the SendFrame procedure as each octet is transmitted. Since the timer resolution is limited and the timer is
                  not necessarily synchronized to other machine events, a timer value of N will actually denote intervals between N-1 and N.
    SourceAddress: Used to store the Source Address of a received frame.
    """
    @type t :: %__MODULE__{
            transport_master: pid(),
            uart_port: pid(),
            local_address: 0..254,
            opts: %{
              autobaud: boolean(),
              baudrate: non_neg_integer(),
              log_communication: boolean()
            },
            data_crc_header: non_neg_integer(),
            data_crc: non_neg_integer(),
            data_length: non_neg_integer(),
            destination_address: 0..255,
            event_count: integer(),
            frame_type: MstpTransport.frame_type(),
            frame_type_raw: 0..255,
            header_crc: non_neg_integer(),
            index: non_neg_integer(),
            input_buffer: iodata(),
            good_header: boolean(),
            received_invalid_frame: boolean(),
            received_valid_frame: boolean(),
            silence_timer: term() | nil,
            silence_timestamp: non_neg_integer() | nil,
            source_address: 0..254
          }

    @fields [
      :transport_master,
      :uart_port,
      :local_address,
      :opts,
      :data_crc_header,
      :data_crc,
      :data_length,
      :destination_address,
      :event_count,
      :frame_type,
      :frame_type_raw,
      :header_crc,
      :index,
      :input_buffer,
      :good_header,
      :received_invalid_frame,
      :received_valid_frame,
      :retry_count,
      :silence_timer,
      :silence_timestamp,
      :source_address
    ]
    @enforce_keys @fields
    defstruct @fields

    @spec new(pid(), pid(), Keyword.t()) :: t()
    def new(master, uart_port, opts) do
      new_opts =
        opts
        |> Map.new()
        |> Map.put_new(:autobaud, false)
        |> Map.put_new(:baudrate, 38_400)
        |> Map.put_new(:log_communication, false)

      %__MODULE__{
        transport_master: master,
        uart_port: uart_port,
        local_address: Map.fetch!(new_opts, :local_address),
        opts: Map.drop(new_opts, [:local_address]),
        data_crc_header: 0,
        data_crc: 0,
        data_length: 0,
        destination_address: 0,
        event_count: 0,
        frame_type: :unknown,
        frame_type_raw: 0,
        header_crc: 0,
        index: 0,
        input_buffer: [],
        good_header: false,
        received_invalid_frame: false,
        received_valid_frame: false,
        retry_count: 0,
        silence_timer: nil,
        silence_timestamp: nil,
        source_address: 0
      }
    end
  end
end
