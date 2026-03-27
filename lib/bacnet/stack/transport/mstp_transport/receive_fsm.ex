if Code.ensure_loaded?(Circuits.UART) do
  defmodule BACnet.Stack.Transport.MstpTransport.ReceiveFSM do
    @moduledoc false
    # This module contains the Receive Finite State Machine for the MS/TP Transport.
    # It is implemented using :gen_statem and is the controlling process for the UART port,
    # and as such receives transport data directly.

    alias __MODULE__.StateData
    alias BACnet.Stack.Transport.MstpTransport
    alias BACnet.Stack.Transport.MstpTransport.EncodingTools
    alias Circuits.UART

    import BACnet.Internal, only: [do_if_in_library_or_debugging: 1, log_debug: 1]

    require Logger

    @behaviour :gen_statem

    @mstp_start_byte 0x55
    @mstp_preamble_byte 0xFF

    # Max-APDU for a regular packet is 0-501,
    # Max-APDU 1476 requires COBS Encoding (available since 135-2016)
    @max_apdu 501

    @broadcast_addr 255

    # The minimum number of DataAvailable or ReceiveError events that must be seen by a receiving node
    # in order to declare the line "active"
    # @param_n_min_octets 4

    # The minimum time without a DataAvailable or ReceiveError event within a frame before
    # a receiving node may discard the frame
    # (Implementations may use larger values for this timeout, not to exceed 100 milliseconds)
    # Unit: Bit times
    # 60 * 15 = 93ms for 9.6kbits/s
    # 60 * 15 = 23ms for 38.4kbits/s
    # 60 * 30 = 46ms for 38.4kbits/s
    @param_t_frame_abort 60 * 15

    @param_n_min_cobs_type 32
    @param_n_max_cobs_type 127
    @param_n_min_cobs_length 5
    @param_n_max_cobs_length 2043

    defmacrop log_debug_comm(state, message_or_fun) do
      quote bind_quoted: [message_or_fun: message_or_fun, state: state],
            generated: true,
            location: :keep do
        if state.opts.log_communication do
          log_debug(message_or_fun)
        end
      end
    end

    @type state ::
            :idle
            | :preamble
            | :header
            | :header_crc
            | :skip_data
            | :data
            | :data_crc
            | :cobs_data

    @doc """
    Starts and links the Receive state machine.
    """
    @spec start_link(pid(), pid(), Keyword.t()) :: {:ok, pid()} | {:error, term()}
    def start_link(transport, uart_port, opts)
        when is_pid(transport) and is_pid(uart_port) and is_list(opts) do
      {my_opts, gen_opts} =
        Keyword.split(opts, [
          :autobaud,
          :baudrate,
          :local_address,
          :log_communication
        ])

      :gen_statem.start_link(__MODULE__, {transport, uart_port, my_opts}, gen_opts)
    end

    @doc """
    Stops the Receive FSM server.
    """
    @spec close(pid()) :: :ok
    def close(server) when is_pid(server) do
      :gen_statem.call(server, :close)
    end

    @doc """
    Reset the event count parameter.
    """
    @spec reset_event_count(pid()) :: :ok
    def reset_event_count(server) when is_pid(server) do
      :gen_statem.call(server, :reset_event_count)
    end

    @doc """
    Configures the options.
    """
    @spec configure(pid(), map() | Keyword.t()) :: :ok
    def configure(server, opts) when is_pid(server) and (is_map(opts) or is_list(opts)) do
      :gen_statem.call(server, {:configure, Map.new(opts)})
    end

    @doc false
    def callback_mode(), do: [:handle_event_function, :state_enter]

    @doc false
    def init({transport_master, uart_port, opts}) do
      case UART.controlling_process(uart_port, self()) do
        :ok -> {:ok, :idle, StateData.new(transport_master, uart_port, opts)}
        {:error, err} -> {:stop, err}
      end
    end

    # --- State functions ---

    defp get_state_timeout(%StateData{} = data),
      do: {:state_timeout, calculate_bittimes_to_ms(@param_t_frame_abort, data), :silence_timer}

    @doc false
    def handle_event(:enter, _old_state, state, %StateData{} = data) when state == :idle do
      # log_debug(fn ->
      # "BacMstpTransport_ReceiveFSM: Entered FSM state #{state}"
      # end)

      {:keep_state, data, []}
    end

    def handle_event(:enter, _old_state, state, %StateData{} = data)
        when state in [:preamble, :header, :header_crc, :skip_data, :data, :data_crc, :cobs_data] do
      # log_debug(fn ->
      #   "BacMstpTransport_ReceiveFSM: Entered FSM state #{state}"
      # end)

      {:keep_state, data, [get_state_timeout(data)]}
    end

    # --- Handling Incoming Process Messages --- (such as from Circuits.UART)

    def handle_event(
          :info,
          {:circuits_uart, _serial_port_id, {:error, reason}},
          state,
          %StateData{} = data
        ) do
      log_debug(fn ->
        "BacMstpTransport_ReceiveFSM: Received error from UART during state #{state}, got: " <>
          inspect(reason)
      end)

      if reason not in [:eagain, :eintr] do
        # Notify Transport Master and it will shut everything down
        send(data.transport_master, {:serial_crash, reason})
      end

      {:keep_state, %{data | event_count: data.event_count + 1}}
    end

    def handle_event(
          :info,
          {:circuits_uart, _serial_port_id, serial_data},
          state,
          %StateData{} = data
        )
        when is_binary(serial_data) do
      log_debug_comm(data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data from UART, got #{byte_size(serial_data)} bytes" <>
          ", got: " <> inspect(serial_data)
      end)

      # Always send Transport Master update on whether we have currently received data
      send(data.transport_master, {:received_data, byte_size(serial_data)})

      handle_receive_data(serial_data, state, %{
        data
        | event_count: data.event_count + byte_size(serial_data)
      })
    end

    def handle_event(:info, _event, state, %StateData{} = data) do
      actions =
        if state != :idle do
          [get_state_timeout(data)]
        else
          [{:state_timeout, :infinity, :silence_timer}]
        end

      {:keep_state, data, actions}
    end

    def handle_event(:state_timeout, :silence_timer, state, %StateData{} = data) do
      log_debug(fn ->
        "BacMstpTransport_ReceiveFSM: Received state_timeout silence_timer event " <>
          "at state #{state}"
      end)

      handle_receive_invalid_or_timeout(data, true, <<>>)
    end

    # For internal triggering of serial data processing
    def handle_event(:internal, {:serial_data, serial_data}, state, %StateData{} = data) do
      handle_receive_data(serial_data, state, data)
    end

    # Handles :gen_statem.call(:close)
    def handle_event({:call, from}, :close, _state, %StateData{} = _data) do
      log_debug(fn -> "BacMstpTransport_ReceiveFSM: Received close call" end)

      {:stop_and_reply, :normal, [{:reply, from, :ok}]}
    end

    # Handles :gen_statem.call(:reset_event_count)
    def handle_event({:call, from}, :reset_event_count, _state, %StateData{} = data) do
      log_debug(fn -> "BacMstpTransport_ReceiveFSM: Received reset_event_count call" end)

      {:keep_state, %{data | event_count: 0}, [{:reply, from, :ok}]}
    end

    # Handles :gen_statem.call({:configure, opts})
    def handle_event({:call, from}, {:configure, %{} = opts}, _state, %StateData{} = data) do
      log_debug(fn -> "BacMstpTransport_ReceiveFSM: Received configure call" end)

      {:keep_state, %{data | opts: Map.merge(data.opts, opts)}, [{:reply, from, :ok}]}
    end

    # --- Receiving Data ---

    @spec handle_receive_data(binary(), atom(), StateData.t()) ::
            {atom(), StateData.t()} | {atom(), StateData.t(), term()}
    defp handle_receive_data(data, state, data)

    defp handle_receive_data(<<>>, state, %StateData{} = data) do
      log_debug_comm(data, fn ->
        "BacMstpTransport_ReceiveFSM: Received end of received data"
      end)

      actions =
        if state == :idle do
          [{:state_timeout, :cancel}]
        else
          [get_state_timeout(data)]
        end

      {:keep_state, data, actions}
    end

    # IDLE|PREAMBLE -> PREAMBLE
    defp handle_receive_data(
           <<@mstp_start_byte, rest::binary>>,
           state,
           %StateData{} = state_data
         )
         when state in [:idle, :preamble] do
      if state == :idle do
        log_debug_comm(state_data, fn ->
          "BacMstpTransport_ReceiveFSM: Received data moving from IDLE to PREAMBLE"
        end)
      else
        log_debug_comm(state_data, fn ->
          "BacMstpTransport_ReceiveFSM: Received repeated PREAMBLE data"
        end)
      end

      {:next_state, :preamble,
       %{
         state_data
         | data_crc_header: 0,
           data_crc: 0,
           data_length: 0,
           header_crc: 0,
           index: 0,
           input_buffer: [],
           good_header: false,
           received_valid_frame: false,
           received_invalid_frame: false
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # IDLE
    defp handle_receive_data(
           <<_byte, rest::binary>>,
           :idle,
           %StateData{} = state_data
         ) do
      # If we're idling and the first byte isn't the START 0x55, then skip over it until we find it
      {:keep_state, state_data,
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # PREAMBLE -> HEADER
    defp handle_receive_data(
           <<@mstp_preamble_byte, rest::binary>>,
           :preamble,
           %StateData{} = state_data
         ) do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data moving from PREAMBLE to HEADER"
      end)

      {:next_state, :header,
       %{
         state_data
         | header_crc: 0xFF
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # HEADER Index 0: Frame Type
    defp handle_receive_data(
           <<frame_type, rest::binary>>,
           :header,
           %StateData{index: 0} = state_data
         ) do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data header index 0 frame type -> #{frame_type}"
      end)

      {:keep_state,
       %{
         state_data
         | frame_type: get_frametype(frame_type),
           frame_type_raw: frame_type,
           index: 1,
           header_crc: EncodingTools.calculate_header_crc(frame_type, state_data.header_crc)
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # HEADER Index 1: Destination
    defp handle_receive_data(
           <<dest, rest::binary>>,
           :header,
           %StateData{index: 1} = state_data
         ) do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data header index 1 destination -> #{dest}"
      end)

      {:keep_state,
       %{
         state_data
         | destination_address: dest,
           index: 2,
           header_crc: EncodingTools.calculate_header_crc(dest, state_data.header_crc)
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # HEADER Index 2: Source
    defp handle_receive_data(
           <<src, rest::binary>>,
           :header,
           %StateData{index: 2} = state_data
         ) do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data header index 2 source -> #{src}"
      end)

      {:keep_state,
       %{
         state_data
         | source_address: src,
           index: 3,
           header_crc: EncodingTools.calculate_header_crc(src, state_data.header_crc)
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # HEADER Index 3: Length1
    defp handle_receive_data(
           <<length, rest::binary>>,
           :header,
           %StateData{index: 3} = state_data
         ) do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data header index 3 data length1 -> #{length}"
      end)

      {:keep_state,
       %{
         state_data
         | data_length: length,
           index: 4,
           header_crc: EncodingTools.calculate_header_crc(length, state_data.header_crc)
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # HEADER Index 4: Length2
    defp handle_receive_data(
           <<length, rest::binary>>,
           :header,
           %StateData{index: 4} = state_data
         ) do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data header index 4 data length2 -> #{length}"
      end)

      {:keep_state,
       %{
         state_data
         | data_length: length + Bitwise.bsl(state_data.data_length, 8),
           index: 5,
           header_crc: EncodingTools.calculate_header_crc(length, state_data.header_crc)
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # HEADER Index 5: Header CRC
    defp handle_receive_data(
           <<crc, rest::binary>>,
           :header,
           %StateData{index: 5} = state_data
         ) do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data header index 5 header CRC -> #{crc}"
      end)

      actual_crc = EncodingTools.calculate_header_crc(crc, state_data.header_crc)
      good_header = 0x55 == actual_crc and state_data.source_address < 255

      frame_too_long =
        ((state_data.frame_type_raw < @param_n_min_cobs_type or
            state_data.frame_type_raw > @param_n_max_cobs_type) and
           state_data.data_length > @max_apdu) or
          (state_data.frame_type_raw >= @param_n_min_cobs_type and
             state_data.frame_type_raw <= @param_n_max_cobs_type and
             state_data.data_length + 2 < @param_n_min_cobs_length) or
          (state_data.frame_type_raw >= @param_n_min_cobs_type and
             state_data.frame_type_raw <= @param_n_max_cobs_type and
             state_data.data_length + 2 > @param_n_max_cobs_length)

      # If we're doing autobaud (no baudrate detected yet), tell the Transport Master
      # when a valid frame has been detected as soon as frame header is good,
      # we don't need to wait until all data received and validated
      if good_header and not frame_too_long and state_data.opts.autobaud do
        send(state_data.transport_master, :received_valid_frame_autobaud)
      end

      cond do
        not good_header ->
          # Only log CRC warnings if we're working on this project or debugging enabled
          do_if_in_library_or_debugging do
            Logger.warning(fn ->
              "BacMstpTransport_ReceiveFSM: Received data with bad header, expected crc: #{0x55}, actual crc: #{actual_crc}"
            end)
          end

          handle_receive_invalid_or_timeout(state_data, true, rest)

        state_data.destination_address not in [state_data.local_address, @broadcast_addr] ->
          if state_data.data_length > 0 do
            log_debug_comm(state_data, fn ->
              "BacMstpTransport_ReceiveFSM: Received data with destination not for us - moving to SKIP_DATA"
            end)

            {:next_state, :skip_data,
             %{
               state_data
               | input_buffer: [],
                 index: 0,
                 received_invalid_frame: true,
                 good_header: true
             },
             [
               {:next_event, :internal, {:serial_data, rest}},
               get_state_timeout(state_data)
             ]}
          else
            log_debug_comm(state_data, fn ->
              "BacMstpTransport_ReceiveFSM: Received data with destination not for us - moving to IDLE"
            end)

            handle_receive_invalid_or_timeout(state_data, false, rest)
          end

        state_data.data_length == 0 ->
          log_debug_comm(state_data, fn ->
            "BacMstpTransport_ReceiveFSM: Received valid frame of type #{state_data.frame_type} with no data"
          end)

          handle_mstp_frame(
            %{
              state_data
              | index: 0,
                received_invalid_frame: false,
                received_valid_frame: true,
                good_header: true
            },
            rest
          )

        frame_too_long ->
          Logger.warning(fn ->
            "BacMstpTransport_ReceiveFSM: Received data with frame too long - moving to SKIP_DATA"
          end)

          {:next_state, :skip_data,
           %{
             state_data
             | input_buffer: [],
               index: 0,
               received_invalid_frame: true,
               good_header: true
           },
           [
             {:next_event, :internal, {:serial_data, rest}},
             get_state_timeout(state_data)
           ]}

        state_data.frame_type_raw in @param_n_min_cobs_type..@param_n_max_cobs_type//1 ->
          log_debug_comm(state_data, fn ->
            "BacMstpTransport_ReceiveFSM: Received valid COBS-encoded frame - moving to COBS_DATA"
          end)

          {:next_state, :cobs_data,
           %{
             state_data
             | data_crc: 0,
               data_length: state_data.data_length + 2,
               index: 0,
               good_header: true
           },
           [
             {:next_event, :internal, {:serial_data, rest}},
             get_state_timeout(state_data)
           ]}

        true ->
          log_debug_comm(state_data, fn ->
            "BacMstpTransport_ReceiveFSM: Received valid frame - moving to DATA"
          end)

          {:next_state, :data,
           %{
             state_data
             | data_crc: 0xFFFF,
               index: 0,
               good_header: true
           },
           [
             {:next_event, :internal, {:serial_data, rest}},
             get_state_timeout(state_data)
           ]}
      end
    end

    # DATA
    defp handle_receive_data(
           <<data, rest::binary>>,
           :data,
           %StateData{
             index: index,
             data_length: data_length
           } = state_data
         )
         when index < data_length do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data byte"
      end)

      {:keep_state,
       %{
         state_data
         | index: index + 1,
           input_buffer: [data | state_data.input_buffer],
           data_crc: EncodingTools.calculate_data_crc(data, state_data.data_crc)
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # DATA CRC1
    defp handle_receive_data(
           <<crc, rest::binary>>,
           :data,
           %StateData{
             index: index,
             data_length: data_length
           } = state_data
         )
         when index == data_length do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data CRC1 -> #{crc}"
      end)

      {:keep_state,
       %{
         state_data
         | index: index + 1,
           data_crc: EncodingTools.calculate_data_crc(crc, state_data.data_crc),
           data_crc_header: crc
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # DATA CRC2
    defp handle_receive_data(
           <<crc, rest::binary>>,
           :data,
           %StateData{
             index: index,
             data_length: data_length
           } = state_data
         )
         when index == data_length + 1 do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received data CRC2 -> #{crc}"
      end)

      state_data = %{
        state_data
        | data_crc: EncodingTools.calculate_data_crc(crc, state_data.data_crc),
          data_crc_header: Bitwise.bsl(crc, 8) + state_data.data_crc_header
      }

      cond do
        state_data.data_crc == 0xF0B8 ->
          log_debug_comm(state_data, fn ->
            "BacMstpTransport_ReceiveFSM: Received valid frame of type #{state_data.frame_type} " <>
              "with data length #{state_data.data_length}"
          end)

          handle_mstp_frame(
            %{
              state_data
              | input_buffer: IO.iodata_to_binary(Enum.reverse(state_data.input_buffer)),
                data_crc_header: 0,
                received_invalid_frame: false,
                received_valid_frame: true
            },
            rest
          )

        state_data.frame_type == :test_request ->
          log_debug_comm(state_data, fn ->
            "BacMstpTransport_ReceiveFSM: Received frame of type #{state_data.frame_type} " <>
              "with data length #{state_data.data_length}, but data CRC does not match, " <>
              "data will be dropped and frame will propagate without data"
          end)

          handle_mstp_frame(
            %{
              state_data
              | input_buffer: [],
                data_length: 0,
                data_crc: 0,
                data_crc_header: 0,
                received_invalid_frame: false,
                received_valid_frame: true
            },
            rest
          )

        true ->
          Logger.warning(fn ->
            "BacMstpTransport_ReceiveFSM: Received frame with bad data - moving to IDLE"
          end)

          handle_receive_invalid_or_timeout(state_data, true, rest)
      end
    end

    # COBS DATA
    defp handle_receive_data(
           <<data, rest::binary>>,
           :cobs_data,
           %StateData{
             index: index,
             data_length: data_length
           } = state_data
         )
         when index + 1 < data_length do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received COBS data byte"
      end)

      {:keep_state,
       %{
         state_data
         | index: index + 1,
           input_buffer: [data | state_data.input_buffer]
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    defp handle_receive_data(
           <<data, rest::binary>>,
           :cobs_data,
           %StateData{} = state_data
         ) do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Received last COBS data byte"
      end)

      new_data = Enum.reverse([data | state_data.input_buffer])

      case EncodingTools.decode_cobs(new_data) do
        {:ok, decoded_data} ->
          decoded_bin_data = IO.iodata_to_binary(decoded_data)

          log_debug_comm(state_data, fn ->
            "BacMstpTransport_ReceiveFSM: Received valid COBS-encoded frame of type #{state_data.frame_type} " <>
              "with data length #{byte_size(decoded_bin_data)}"
          end)

          handle_mstp_frame(
            %{
              state_data
              | input_buffer: decoded_bin_data,
                data_length: byte_size(decoded_bin_data),
                data_crc: 0,
                data_crc_header: 0,
                received_invalid_frame: false,
                received_valid_frame: true
            },
            rest
          )

        {:error, _reason} ->
          Logger.warning(fn ->
            "BacMstpTransport_ReceiveFSM: Received COBS-encoded frame with bad data - moving to IDLE"
          end)

          handle_receive_invalid_or_timeout(state_data, true, rest)
      end
    end

    # SKIP_DATA Done -> IDLE
    defp handle_receive_data(
           data,
           :skip_data,
           %StateData{
             index: index,
             data_length: data_length
           } = state_data
         )
         when index == data_length + 1 do
      log_debug_comm(state_data, fn ->
        "BacMstpTransport_ReceiveFSM: Encountered end of SKIP_DATA - moving to IDLE"
      end)

      handle_receive_invalid_or_timeout(state_data, false, data)
    end

    # SKIP_DATA
    defp handle_receive_data(
           <<_byte, rest::binary>>,
           :skip_data,
           %StateData{} = state_data
         ) do
      {:keep_state,
       %{
         state_data
         | index: state_data.index + 1
       },
       [
         {:next_event, :internal, {:serial_data, rest}},
         get_state_timeout(state_data)
       ]}
    end

    # Invalid data bytes -> reset to idle
    defp handle_receive_data(_data, _state, %StateData{} = state_data) do
      handle_receive_invalid_or_timeout(state_data, true)
    end

    @spec get_frametype(byte()) :: MstpTransport.frame_type()
    defp get_frametype(type)

    defp get_frametype(0), do: :token
    defp get_frametype(1), do: :poll_for_master
    defp get_frametype(2), do: :reply_to_poll_for_master
    defp get_frametype(3), do: :test_request
    defp get_frametype(4), do: :test_response
    defp get_frametype(5), do: :bacnet_data_expecting_reply
    defp get_frametype(6), do: :bacnet_data_not_expecting_reply
    defp get_frametype(7), do: :reply_postponed
    defp get_frametype(32), do: :bacnet_extended_data_expecting_reply
    defp get_frametype(33), do: :bacnet_extended_data_not_expecting_reply
    defp get_frametype(type) when type >= 128 and type <= 255, do: {:proprietary, type}
    defp get_frametype(_type), do: :unknown

    # Calculates based on the baudrate and the amount of bit times the necessary time in ms
    @spec calculate_bittimes_to_ms(non_neg_integer(), StateData.t()) :: ms :: non_neg_integer()
    defp calculate_bittimes_to_ms(bittimes, %StateData{opts: %{baudrate: baud}}) do
      trunc(1_000 / baud * bittimes)
    end

    @spec handle_receive_invalid_or_timeout(StateData.t(), boolean(), binary()) :: tuple()
    defp handle_receive_invalid_or_timeout(%StateData{} = state, invalid_frame, rest \\ <<>>)
         when is_boolean(invalid_frame) and is_binary(rest) do
      if invalid_frame do
        send(state.transport_master, :received_invalid_frame)
      end

      actions =
        if byte_size(rest) > 0 do
          [
            {:next_event, :internal, {:serial_data, rest}},
            get_state_timeout(state)
          ]
        else
          [{:state_timeout, :cancel}]
        end

      {:next_state, :idle,
       %{
         state
         | input_buffer: [],
           index: 0,
           received_invalid_frame: invalid_frame,
           received_valid_frame: false
       }, actions}
    end

    @spec handle_mstp_frame(StateData.t(), binary()) :: tuple()
    defp handle_mstp_frame(%StateData{} = data, rest) when is_binary(rest) do
      # We do not actually handle any MS/TP frame here,
      # instead it gets sent to the Transport master
      send(data.transport_master, {:received_frame, data})

      actions =
        if byte_size(rest) > 0 do
          [
            {:next_event, :internal, {:serial_data, rest}},
            get_state_timeout(data)
          ]
        else
          [{:state_timeout, :cancel}]
        end

      {:next_state, :idle,
       %{
         data
         | input_buffer: [],
           index: 0,
           received_invalid_frame: false,
           received_valid_frame: false
       }, actions}
    end
  end
end
