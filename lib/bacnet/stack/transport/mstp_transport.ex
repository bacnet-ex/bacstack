if Code.ensure_loaded?(Circuits.UART) do
  defmodule BACnet.Stack.Transport.MstpTransport do
    @moduledoc """
    Highly experimental transport for BACnet MS/TP.

    MS/TP stands for Master-Slave/Token-Passing and uses EIA-485 (RS485) as electrical transport.

    This transport implementation supports ASHRAE 135-2016 and as such COBS encoding to allow frames
    up to 1476 bytes. When sending such large APDUs the receiving device must also support ASHRAE 135-2016,
    otherwise it will ignore us, and that's a sad thing to do! As such, sending large APDUs is opt-in.

    It uses `Circuits.UART` to handle RS485 for us in active mode.

    If you want to use this transport, you'll have to add [`:circuits_uart`](https://hex.pm/packages/circuits_uart)
    to your `mix.exs` as dependency! It is an optional dependency and thus
    by default not present when you install this library.
    """

    # TODO: Convert Master Node FSM to :gen_statem?

    # For testing we can use `socat -d -d pty,rawer,echo=0 pty,rawer,echo=0` in the future
    # Output will contain two lines of `N PTY is /dev/pts/{number}` with can then be opened
    # using Circuits.UART.open(pid, "dev/pts/{number}")

    alias __MODULE__
    alias __MODULE__.EncodingTools
    alias __MODULE__.ReceiveFSM
    alias __MODULE__.ReceiveFSM.StateData

    alias BACnet.Protocol
    alias BACnet.Protocol.APDU
    alias BACnet.Protocol.Constants
    alias BACnet.Protocol.NPCI
    alias BACnet.Stack.EncoderProtocol
    alias BACnet.Stack.TransportBehaviour
    alias Circuits.UART

    import BACnet.Internal, only: [is_dest: 1, is_server: 1, log_debug: 1]

    require Constants
    require Logger

    use GenServer

    # Remove unused alias compile warning
    _unused = MstpTransport

    @behaviour TransportBehaviour

    @bacnet_proto :bacnet_mstp
    @transport_protocol {@bacnet_proto, __MODULE__}

    # Max-APDU for a regular packet is 0-501,
    # Max-APDU 1476 requires COBS Encoding (available since 135-2016)
    @max_apdu 501
    @max_apdu_extended 1476

    @min_master_addr 0
    @max_master_addr 127
    @min_slave_addr 128
    @max_slave_addr 254
    @broadcast_addr 255

    @apdu_timer_factor 0.95
    @call_timeout Application.compile_env(:bacstack, :mstp_transport_call_timeout, 60_000)

    # The number of tokens received or used before a Poll For Master cycle is executed
    @param_n_poll 50

    # The number of retries on sending Token
    @param_n_retry_token 1

    # The minimum number of DataAvailable or ReceiveError events that must be seen by a receiving node in order to declare the line "active"
    @param_n_min_octets 4

    # The maximum idle time a sending node may allow to elapse between octets of a frame the node is transmitting
    # Unit: Bit times
    # @param_t_frame_gap 20

    # The time without a DataAvailable or ReceiveError event before declaration of loss of token
    # Unit: ms
    @param_t_no_token 500

    # The maximum time after the end of the stop bit of the final octet of a transmitted frame before a node must disable its EIA-485 drive
    # Unit: Bit times
    # @param_t_postdrive 15

    # The maximum time a node may wait after reception of a frame that expects a reply before sending the first octet of a reply or Reply Postponed frame
    # Unit: ms
    @param_t_reply_delay 250

    # The minimum time without a DataAvailable or ReceiveError event that a node must wait for a station to begin replying to a confirmed request
    # (Implementations may use larger values for this timeout, not to exceed 300 milliseconds)
    # Unit: ms
    # Default: 255
    @param_t_reply_timeout 280

    # The width of the time slot within which a node may generate a token
    # Unit: ms
    @param_t_slot 10

    # The maximum time a node may wait after reception of the token or a Poll For Master frame before sending the first octet of a frame
    # Unit: ms
    # @param_t_usage 15

    # The minimum time without a DataAvailable or ReceiveError event that a node must wait for a remote node to begin using a token or replying to a Poll For Master frame
    # (Implementations may use larger values for this timeout, not to exceed 100 milliseconds)
    # Unit: ms
    # Default: 20
    @param_t_usage_timeout 80

    @param_n_min_cobs_length 5

    defmacrop log_debug_comm(state, message_or_fun) do
      quote bind_quoted: [message_or_fun: message_or_fun, state: state],
            generated: true,
            location: :keep do
        if state.opts.log_communication do
          log_debug(message_or_fun)
        end
      end
    end

    defmodule State do
      @moduledoc false

      @type slave_state :: :initialize | :idle | :answer_data_request
      @type master_state ::
              :initialize
              | :idle
              | :answer_data_request
              | :no_token
              | :pass_token
              | :poll_for_master
              | :done_with_token
              | :use_token
              | :wait_for_reply

      @type send_item ::
              {destination :: byte(), send_and_wait :: boolean() | :raw | :test,
               payload :: iodata(), payload_length :: non_neg_integer() | nil}

      @type t :: %__MODULE__{
              receive_fsm: pid(),
              uart_pid: pid(),
              callback: term(),
              local_address: 0..254,
              state_machine: MstpTransport.StateMachine.t(),
              transport_state: master_state() | slave_state(),
              active_test: from :: term() | nil,
              answer_invoke_id: non_neg_integer() | nil,
              send_queue: :queue.queue(send_item()),
              send_timer: :timer.tref() | nil,
              opts: %{
                baudrate: non_neg_integer(),
                local_address: 0..254,
                log_communication: boolean(),
                max_info_frames: pos_integer(),
                max_master_address: 0..127,
                port_name: binary(),
                supervisor: Supervisor.supervisor()
              },
              statistics: %{
                optional(atom()) => non_neg_integer()
              }
            }

      @fields [
        :uart_pid,
        :callback,
        :local_address,
        :state_machine,
        :receive_fsm,
        :transport_state,
        :active_test,
        :answer_invoke_id,
        :send_queue,
        :send_timer,
        :opts,
        :statistics
      ]
      @enforce_keys @fields
      defstruct @fields
    end

    defmodule StateMachine do
      @moduledoc false

      @typedoc """
      State Machine for the MS/TP Transport.

      From ASHRAE 135 Clause 9.5.2:

      FrameCount: The number of frames sent by this node during a single token hold.
                  When this counter reaches the value Nmax_info_frames, the node must pass the token.
      NS: "Next Station", the MAC address of the node to which This Station passes the token. If the Next Station is unknown, NS shall be equal to TS.
      PS: "Poll Station", the MAC address of the node to which This Station last sent a Poll For Master. This is used during token maintenance.
      RetryCount: A counter of transmission retries used for Token and Poll For Master transmission.
      SoleMaster: A Boolean flag set to TRUE by the master machine if this node is the only known master node.
      TokenCount: The number of tokens received by this node. When this counter reaches the value Npoll,
                  the node polls the address range between TS and NS for additional master nodes.
                  TokenCount is set to one at the end of the polling process.
      TS: "This Station", the MAC address of this node. Valid values for TS are 0 to 254.
      """
      @type t :: %__MODULE__{
              ns: -1..127,
              ps: -1..127,
              frame_count: non_neg_integer(),
              retry_count: integer(),
              silence_timer: term() | nil,
              silence_timestamp: non_neg_integer() | nil,
              source_address: 0..254 | nil,
              sole_master: boolean(),
              token_count: non_neg_integer(),
              ts: -1..127
            }

      @fields [
        :ns,
        :ps,
        :frame_count,
        :retry_count,
        :silence_timer,
        :silence_timestamp,
        :source_address,
        :sole_master,
        :token_count,
        :ts
      ]
      @enforce_keys @fields
      defstruct @fields

      @spec new() :: t()
      def new() do
        %__MODULE__{
          ns: -1,
          ps: -1,
          frame_count: 0,
          retry_count: 0,
          silence_timer: nil,
          silence_timestamp: nil,
          source_address: nil,
          sole_master: false,
          token_count: 0,
          ts: -1
        }
      end
    end

    @typedoc """
    Valid MS/TP frame types.

    The `t_{number}` "name" corresponds to the frame type number.

    Frame Type 32 + 33 were added in ASHRAE 135-2016 (they allow octets > 501).
    """
    @type frame_type ::
            :unknown
            | (t_0 :: :token)
            | (t_1 :: :poll_for_master)
            | (t_2 :: :reply_to_poll_for_master)
            | (t_3 :: :test_request)
            | (t_4 :: :test_response)
            | (t_5 :: :bacnet_data_expecting_reply)
            | (t_6 :: :bacnet_data_not_expecting_reply)
            | (t_7 :: :reply_postponed)
            | (t_32 :: :bacnet_extended_data_expecting_reply)
            | (t_33 :: :bacnet_extended_data_not_expecting_reply)
            | (t_prop :: {:proprietary, 128..255})

    @typedoc """
    Valid open options. For a description of each, see `open/2`.
    """
    @type open_option ::
            {:baudrate, non_neg_integer()}
            | {:local_address, source_address()}
            | {:log_communication, boolean()}
            | {:log_communication_rcv, boolean()}
            | {:max_info_frames, pos_integer()}
            | {:max_master_address, 0..127}
            | {:port_name, binary()}
            | {:supervisor, Supervisor.supervisor()}
            | GenServer.option()

    @typedoc """
    List of open options.
    """
    @type open_options :: [open_option()]

    @typedoc """
    Valid send options. For a description of each, see `send/4`.
    """
    @type send_option ::
            {:allow_extended_apdu, boolean()}
            | {:raw, boolean()}
            | {:use_extended_apdu, boolean()}
            | TransportBehaviour.transport_send_option()

    @typedoc """
    List of send options.
    """
    @type send_options :: [send_option()]

    @typedoc """
    The destination address is an integer in the range of 0-255,
    where 255 means broadcast.
    """
    @type destination_address :: 0..255

    @typedoc """
    The source address is an integer in the range of 0-254.
    """
    @type source_address :: 0..254

    @doc """
    Produces a supervisor child spec.
    It will call `child_spec(callback, opts)` with the given 2-element list elements.

    See also `Supervisor.child_spec/2` for the rest of the behaviour.
    """
    @spec child_spec(list()) :: Supervisor.child_spec()
    def child_spec(args)

    def child_spec([callback, opts]) when is_list(opts) do
      child_spec(callback, opts)
    end

    @doc """
    Produces a supervisor child spec based on the BACnet transport `open` callback, as such
    it will take the `callback` and `opts` for `open/2`.

    See also `Supervisor.child_spec/2` for the rest of the behaviour.
    """
    @spec child_spec(TransportBehaviour.transport_callback(), Keyword.t()) ::
            Supervisor.child_spec()
    def child_spec(callback, opts) when is_list(opts) do
      default = %{
        id: __MODULE__,
        start: {__MODULE__, :open, [callback, opts]}
      }

      Supervisor.child_spec(default, [])
    end

    @doc """
    Get the BACnet transport protocol this transport implements.
    """
    @spec bacnet_protocol() :: TransportBehaviour.transport_protocol()
    def bacnet_protocol(), do: @bacnet_proto

    @doc """
    Get the maximum APDU length for this transport.
    """
    @spec max_apdu_length() :: pos_integer()
    def max_apdu_length(), do: @max_apdu

    @doc """
    Get the maximum NPDU length for this transport.

    The NPDU length contains the maximum transmittable size
    of the NPDU, including the APDU, without violating
    the maximum transmission unit of the underlying transport.

    Any necessary transport header (i.e. BVLL, LLC) must have
    been taken into account when calculating this number.
    """
    @spec max_npdu_length() :: pos_integer()
    def max_npdu_length(), do: @max_apdu

    @doc """
    Opens/starts the Transport module. A process is started, that is linked to the caller process.

    See the `BACnet.Stack.TransportBehaviour` documentation for more information.

    In the case of this BACnet MS/TP transport, the transport PID/port is a `GenServer` receiving and sending
    RS485 data. The portal is the same transport PID/port, as access to the MS/TP network must be coordinated.

    This transport takes the following options, in addition to `t:GenServer.options/0`:
    - `baudrate: non_neg_integer` - Optional. The baud rate to use (defaults to `38400`).
    - `local_address: source_address()` - Required. The address to use - must be unique in the BACnet MS/TP network.
      Addresses 0-127 are for master nodes, while 128-254 are for slave nodes.
    - `log_communication: boolean()` - Optional. Logs all communication (debug), excluding receive states.
    - `log_communication_rcv: boolean()` - Optional. Logs all communication (debug) of receive states.
    - `max_info_frames: pos_integer()` - Optional. This value specifies the maximum number of information
      frames the node may send before it must pass the token (defaults to `1`).
    - `max_master_address: 0..127` - Optional. The maximum master address that is used in the MS/TP network.
      This is used for polling and successor determination. Defaults to `127`.
    - `port_name: binary()` - Required. Name of the serial port (use `Circuits.UART.enumerate/0`).
    - `supervisor: Supervisor.supervisor()` - Optional. The task supervisor to use to spawn tasks under.
      Tasks are spawned to invoke the given callback. If no supervisor is given,
      the tasks will be spawned unsupervised.
    """
    @spec open(
            callback :: TransportBehaviour.transport_callback(),
            opts :: open_options()
          ) :: {:ok, pid()} | {:error, term()}
    def open(callback, opts \\ []) do
      unless Keyword.keyword?(opts) do
        raise ArgumentError, "open/2 expected a keyword list, got: #{inspect(opts)}"
      end

      case callback do
        {module, function, arity}
        when is_atom(module) and is_atom(function) and arity == 3 ->
          unless function_exported?(module, function, arity) do
            raise ArgumentError,
                  "open/2 got a MFA tuple as callback, but function is not exported"
          end

        pid when is_server(pid) ->
          :ok

        fun when is_function(fun, 3) ->
          :ok

        term ->
          raise ArgumentError, "open/2 expected a valid callback, got: #{inspect(term)}"
      end

      {opts2, genserver_opts} =
        Keyword.split(opts, [
          :baudrate,
          :local_address,
          :log_communication,
          :log_communication_rcv,
          :max_info_frames,
          :max_master_address,
          :port_name,
          :supervisor
        ])

      validate_open_opts(opts2)

      GenServer.start_link(__MODULE__, {callback, Map.new(opts2)}, genserver_opts)
    end

    @doc """
    Closes the Transport module.
    """
    @spec close(GenServer.server()) :: :ok
    def close(transport) when is_server(transport) do
      GenServer.call(transport, :close)
    end

    @doc """
    Get the broadcast address.
    """
    @spec get_broadcast_address(GenServer.server()) :: destination_address()
    def get_broadcast_address(transport) when is_server(transport) do
      @broadcast_addr
    end

    @doc """
    Get the local address.
    """
    @spec get_local_address(GenServer.server()) :: source_address()
    def get_local_address(transport) when is_server(transport) do
      GenServer.call(transport, :get_local_address)
    end

    @doc """
    Get the transport module portal for the given transport PID/port.
    Transport modules may return the input as output, if the same
    PID or port is used for sending.

    This is used to get the portal before having received data from
    the transport module, so data can be sent prior to reception.
    """
    @spec get_portal(GenServer.server()) :: GenServer.server()
    def get_portal(transport) when is_server(transport) do
      transport
    end

    @doc """
    Checks whether the given destination is an address that needs to be routed.
    """
    @spec is_destination_routed(GenServer.server(), destination_address() | term()) ::
            boolean()
    def is_destination_routed(transport, destination) when is_server(transport) do
      GenServer.call(transport, {:is_destination_routed, destination})
    end

    @doc """
    Sends data to the BACnet network.

    Please note that not all MS/TP devices support extended APDUs (max. 1476 bytes)
    and thus you should make sure they do when sending large APDUs,
    or always default to the maximum as defined by ASHRAE 135-2012 (before 135-2016).

    See the `BACnet.Stack.TransportBehaviour` documentation for more information.
    The option `skip_headers` has no effect.

    In addition, the following options are available:
    - `allow_extended_apdu: boolean()` - Optional. Allow to send APDUs up to 1476 bytes,
      instead of 501 bytes. Extended APDUs require support of ASHRAE 135-2016 and newer.
    - `use_extended_apdu: boolean()` - Optional. Uses the extended APDU frame type to
      send the APDU (APDU length must be min. 5 bytes) - `allow_extended_apdu` must be `true`.
    - `raw: boolean()` - Optional. Sends raw data to the transport layer.
      The data MUST be BACnet MS/TP conform data.
    """
    @spec send(
            GenServer.server(),
            destination_address(),
            EncoderProtocol.t() | iodata(),
            send_options()
          ) ::
            :ok | {:error, term()}
    def send(portal, destination, data, opts \\ [])
        when is_server(portal) and is_integer(destination) and destination >= 0 and
               destination <= 255 and
               (is_binary(data) or is_list(data) or is_struct(data)) and
               is_list(opts) do
      unless Keyword.keyword?(opts) do
        raise ArgumentError, "send/4 expected a keyword list, got: #{inspect(opts)}"
      end

      is_broadcast = destination == @broadcast_addr

      # invoke_id is nil if it's not an answer
      invoke_id =
        cond do
          is_struct(data) ->
            if not EncoderProtocol.is_request(data) do
              case data do
                %{invoke_id: invoke_id} -> invoke_id
                _other -> nil
              end
            end

          # If it's a request, don't bother trying to find an invoke ID
          match?(
            <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), _pdu::size(4),
              _rest::binary>>,
            data
          ) ->
            nil

          match?(
            <<Constants.macro_by_name(:pdu_type, :unconfirmed_request)::size(4), _pdu::size(4),
              _rest::binary>>,
            data
          ) ->
            nil

          true ->
            case APDU.get_invoke_id_from_raw_apdu(data) do
              {:ok, id} -> id
              _other -> nil
            end
        end

      # Do not build a BACnet packet, if sending raw data
      build_result =
        if Keyword.get(opts, :raw) do
          {:ok, {[], data}}
        else
          TransportBehaviour.build_bacnet_packet(data, is_broadcast, opts)
        end

      with {:ok, {npci, bin_data}} <- build_result,
           bin_len = IO.iodata_length([npci, bin_data]),
           # With COBS-Encoding we can go higher (opt-in behaviour)
           max_apdu_len = if(opts[:allow_extended_apdu], do: @max_apdu_extended, else: @max_apdu),
           :ok <-
             (if bin_len > max_apdu_len do
                {:error, :apdu_too_long}
              else
                :ok
              end) do
        # Forces the use of extended APDUs (does not prevent it if allowed)
        use_extended =
          cond do
            !opts[:use_extended_apdu] ->
              false

            max_apdu_len != @max_apdu_extended ->
              raise ArgumentError,
                    "Extended APDUs can only be sent if the option allow_extended_apdu is also set"

            bin_len < @param_n_min_cobs_length ->
              raise ArgumentError,
                    "Extended APDUs can only be sent with data length minimum #{@param_n_min_cobs_length}"

            true ->
              true
          end

        send_and_wait =
          case Keyword.get(opts, :raw) do
            true ->
              :raw

            _else ->
              value =
                case Keyword.fetch(opts, :npci) do
                  {:ok, %NPCI{} = value} ->
                    value.expects_reply

                  {:ok, nil} ->
                    false

                  :error ->
                    Keyword.get_lazy(opts, :expects_reply, fn ->
                      if is_struct(data) do
                        EncoderProtocol.expects_reply(data)
                      else
                        # Data may be APDU or NPDU+APDU - but we have no way of telling
                        apdu_expects_reply(expand_data_to_binary(data))
                      end
                    end)
                end

              !!value
          end

        GenServer.call(
          portal,
          {:send, destination, send_and_wait, [npci, bin_data],
           if(use_extended and bin_len <= @max_apdu, do: 1000, else: bin_len), invoke_id},
          @call_timeout
        )
      end
    end

    @doc """
    Sends a Test-Request APDU to the specified destination.

    If the destination exists and is reachable, it will send the data back unchanged
    (or no data at all, if it for some reason unable to read the data).
    The destination must not be `255` (broadcast).
    The data must be less than 502 bytes long.

    This function will block until the Test-Response APDU has arrived
    or the timeout triggers.
    """
    @spec send_test(GenServer.server(), source_address(), iodata()) ::
            {:ok, iodata()} | {:error, term()}
    def send_test(portal, destination, data \\ "Hello World")
        when is_server(portal) and is_integer(destination) and destination >= 0 and
               destination <= 254 and
               (is_binary(data) or is_list(data)) do
      if IO.iodata_length(data) > @max_apdu do
        raise ArgumentError, "Data must be less than #{@max_apdu} bytes long"
      end

      GenServer.call(portal, {:send_test, destination, data}, @call_timeout)
    end

    @doc """
    Verifies whether the given destination is valid for the transport module.
    """
    @spec is_valid_destination(destination_address()) :: boolean()
    def is_valid_destination(destination) do
      is_integer(destination) and destination >= 0 and destination <= 255
    end

    @doc false
    def init({callback, opts}) do
      new_opts =
        opts
        |> Map.put_new(:log_communication, false)
        |> Map.put_new(:max_info_frames, 1)
        |> Map.put_new(:max_master_address, @max_master_addr)
        |> Map.put_new(:supervisor, nil)

      result =
        with {:ok, uart_pid} <- UART.start_link() do
          {UART.open(uart_pid, Map.fetch!(opts, :port_name),
             active: true,
             speed: Map.get(opts, :baudrate, 38_400),
             data_bits: 8,
             stop_bits: 1,
             parity: :none,
             flow_control: :none,
             framing: {UART.Framing.None, []},
             id: :pid
             # Supported only on Linux
             # rs485_enabled: true,
             # rs485_rts_on_send: false,
             # rs485_rts_after_send: false,
             # rs485_rx_during_tx: false,
             # rs485_terminate_bus: false
           ), uart_pid}
        end

      case result do
        {:ok, uart_pid} ->
          # Remove all current contents in the receive buffer
          UART.flush(uart_pid, :receive)

          local_addr = Map.fetch!(opts, :local_address)

          fsm_opts =
            new_opts
            |> Map.take([:baudrate, :local_address])
            |> Map.put(:log_communication, !!new_opts[:log_communication_rcv])
            |> Enum.to_list()

          case ReceiveFSM.start_link(self(), uart_pid, fsm_opts) do
            {:ok, fsm_pid} ->
              state = %State{
                uart_pid: uart_pid,
                callback: callback,
                local_address: local_addr,
                state_machine: StateMachine.new(),
                receive_fsm: fsm_pid,
                transport_state: :initialize,
                active_test: nil,
                answer_invoke_id: nil,
                send_queue: :queue.new(),
                send_timer: nil,
                opts: new_opts,
                statistics: %{}
              }

              log_debug(fn ->
                "BacMstpTransport: Started on #{inspect(self())} with address #{local_addr}, with ReceiveFSM started on #{inspect(fsm_pid)}"
              end)

              {:ok, state, {:continue, :initialize}}

            {:error, err} ->
              UART.stop(uart_pid)
              {:stop, err}
          end

        :ignore ->
          {:stop, {:error, :uart_returned_ignore}}

        {:error, err} ->
          {:stop, err}

        {{:error, err}, pid} ->
          UART.stop(pid)
          {:stop, err}
      end
    end

    @doc false
    def handle_continue(
          :initialize,
          %State{local_address: local_addr, state_machine: state_machine} = state
        )
        when local_addr < @min_slave_addr do
      # Initialize master node
      {:noreply,
       state_set_silence_timer(
         %{
           state
           | state_machine: %{
               state_machine
               | ns: local_addr,
                 ps: local_addr,
                 ts: local_addr,
                 token_count: @param_n_poll,
                 sole_master: false
             },
             transport_state: :idle
         },
         :timer_lost_token,
         # Add some "jitter" on init for the first time
         @param_t_no_token + @param_t_slot * local_addr * 2
       )}
    end

    def handle_continue(
          :initialize,
          %State{local_address: local_addr, state_machine: state_machine} = state
        ) do
      # Initialize slave node
      {:noreply,
       %{state | state_machine: %{state_machine | ts: local_addr}, transport_state: :idle}}
    end

    # We received a TOKEN frame, which hands us over the token, so enter USE_TOKEN state
    def handle_continue(
          :use_token,
          %State{local_address: local_addr, state_machine: state_machine} = state
        )
        when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Reached state USE_TOKEN"
      end)

      case :queue.out(state.send_queue) do
        # State NothingToSend
        {:empty, _queue} ->
          log_debug(fn ->
            "BacMstpTransport: Reached state USE_TOKEN and NothingToSend, transitioning to DONE_WITH_TOKEN"
          end)

          {:noreply,
           %{
             state
             | state_machine: %{state_machine | frame_count: state.opts.max_info_frames},
               transport_state: :done_with_token
           }, {:continue, :done_with_token}}

        # payload_length is only used to determine if extended frame or not,
        # it does NOT represent the actual payload size when extended APDU is forced
        {{:value, {destination, send_and_wait, payload, payload_length}}, new_queue} ->
          result =
            cond do
              send_and_wait == :raw ->
                send_uart_data(state, payload)

              send_and_wait == :test ->
                send_frame_test_request(state, destination, payload)

              send_and_wait and is_integer(payload_length) and payload_length > @max_apdu ->
                send_frame_ext_data_expecting_reply(state, destination, payload)

              send_and_wait ->
                send_frame_data_expecting_reply(state, destination, payload)

              is_integer(payload_length) and payload_length > @max_apdu ->
                send_frame_ext_data_not_expecting_reply(state, destination, payload)

              true ->
                send_frame_data_not_expecting_reply(state, destination, payload)
            end

          case result do
            # State SendAndWait
            {:ok, %State{state_machine: new_state_machine} = new_state}
            when send_and_wait in [true, :test] ->
              {:noreply,
               state_set_silence_timer(
                 %{
                   new_state
                   | state_machine: %{
                       new_state_machine
                       | frame_count: new_state_machine.frame_count + 1
                     },
                     send_queue: new_queue,
                     transport_state: :wait_for_reply
                 },
                 :timer_rcv_timeout,
                 @param_t_reply_timeout
               )}

            # State SendNoWait
            {:ok, %State{state_machine: new_state_machine} = new_state} ->
              {:noreply,
               %{
                 new_state
                 | state_machine: %{
                     new_state_machine
                     | frame_count: new_state_machine.frame_count + 1
                   },
                   send_queue: new_queue,
                   transport_state: :done_with_token
               }, {:continue, :done_with_token}}

            {:error, %State{state_machine: new_state_machine} = state} ->
              # On send error, immediately enter DONE_WITH_TOKEN state (this should never happen anyway)
              {:noreply,
               %{
                 state
                 | state_machine: %{new_state_machine | frame_count: state.opts.max_info_frames},
                   transport_state: :done_with_token
               }, {:continue, :done_with_token}}
          end
      end
    end

    # DONE_WITH_TOKEN state may be entered on the following conditions [OR]:
    # - USE_TOKEN nothing to send, send with no wait
    # - WAIT_FOR_REPLY timed out, invalid frame, reply received or reply postponed
    def handle_continue(
          :done_with_token,
          %State{
            local_address: local_addr,
            state_machine: %{frame_count: frame_count},
            opts: %{max_info_frames: max_frames}
          } =
            state
        )
        when local_addr < @min_slave_addr and frame_count < max_frames do
      # State SendAnotherFrame: Send another frame until frame_count reaches max
      # USE_TOKEN will set frame_count to max_frames when state NothingToSend is reached
      log_debug(fn ->
        "BacMstpTransport: Reached state DONE_WITH_TOKEN and transition to USE_TOKEN (frame_count < max_info_frames)"
      end)

      {:noreply, %{state | transport_state: :use_token}, {:continue, :use_token}}
    end

    def handle_continue(
          :done_with_token,
          %State{
            local_address: local_addr,
            state_machine: %{sole_master: false, ns: ns, ts: ts} = state_machine
          } =
            state
        )
        when local_addr < @min_slave_addr and ns == ts do
      # State NextStationUnknown
      ps = rem(ts + 1, state.opts.max_master_address + 1)

      log_debug(fn ->
        "BacMstpTransport: Reached state DONE_WITH_TOKEN and transition to POLL_FOR_MASTER (unknown successor) " <>
          "to destination #{ps}"
      end)

      new_state = %{
        state
        | state_machine: %{
            state_machine
            | ps: ps,
              retry_count: 0
          },
          transport_state: :poll_for_master
      }

      {_type, state} = send_frame_pfm(new_state, ps)
      {:noreply, state}
    end

    def handle_continue(
          :done_with_token,
          %State{
            local_address: local_addr,
            state_machine: %{sole_master: true, token_count: tokens} = state_machine
          } =
            state
        )
        when local_addr < @min_slave_addr and tokens < @param_n_poll - 1 do
      # State SoleMaster
      if false and :queue.is_empty(state.send_queue) do
        # This may be used in the future... but not now
        log_debug(fn ->
          "BacMstpTransport: Reached state DONE_WITH_TOKEN and transition to sleep with USE_TOKEN (no other masters)"
        end)
      else
        log_debug(fn ->
          "BacMstpTransport: Reached state DONE_WITH_TOKEN and transition to USE_TOKEN (no other masters)"
        end)
      end

      new_state = %{
        state
        | state_machine: %{state_machine | frame_count: 0, token_count: tokens + 1},
          transport_state: :use_token
      }

      if false and :queue.is_empty(state.send_queue) do
        new_state = %{
          new_state
          | send_timer: Process.send_after(self(), :wakeup_use_token, 10_000)
        }

        {:noreply, new_state}
      else
        {:noreply, new_state, {:continue, :use_token}}
      end
    end

    def handle_continue(
          :done_with_token,
          %State{
            local_address: local_addr,
            state_machine:
              %{sole_master: sole_master, ns: ns, ts: ts, token_count: tokens} = state_machine
          } =
            state
        )
        when local_addr < @min_slave_addr and
               (not sole_master or ns == rem(ts + 1, state.opts.max_master_address + 1)) and
               tokens < @param_n_poll - 1 do
      # State SendToken: The comparison of NS and TS+1 eliminates the Poll For Master
      #                  if there are no addresses between TS and NS, since there is
      #                  no address at which a new master node may be found in that case
      log_debug(fn ->
        "BacMstpTransport: Reached state DONE_WITH_TOKEN and transition to PASS_TOKEN (known successor) " <>
          "to destination #{ns}"
      end)

      ReceiveFSM.reset_event_count(state.receive_fsm)

      new_state = %{
        state
        | state_machine: %{
            state_machine
            | token_count: tokens + 1,
              retry_count: 0
          },
          transport_state: :pass_token
      }

      case send_frame_token(new_state, ns) do
        {:ok, state} ->
          new_state = state_set_silence_timer(state, :timer_rcv_timeout, @param_t_usage_timeout)
          {:noreply, new_state}

        {:error, state} ->
          # Retry again (non-cancelable)
          {:noreply,
           state_set_silence_timer(state, {:timer_retry_token_handoff, ns}, @param_t_slot)}
      end
    end

    def handle_continue(
          :done_with_token,
          %State{
            local_address: local_addr,
            state_machine: %{ns: ns, ps: ps, token_count: tokens} = state_machine
          } =
            state
        )
        when local_addr < @min_slave_addr and ns != rem(ps + 1, state.opts.max_master_address + 1) and
               tokens >= @param_n_poll - 1 do
      # State SendMaintenancePFM
      ps = rem(ps + 1, state.opts.max_master_address + 1)

      log_debug(fn ->
        "BacMstpTransport: Reached state DONE_WITH_TOKEN and do maintenance POLL_FOR_MASTER " <>
          "to destination #{ps}"
      end)

      new_state = %{
        state
        | state_machine: %{state_machine | ps: ps, retry_count: 0},
          transport_state: :poll_for_master
      }

      {_type, state} = send_frame_pfm(new_state, ps)
      {:noreply, state}
    end

    def handle_continue(
          :done_with_token,
          %State{
            local_address: local_addr,
            state_machine:
              %{sole_master: false, ns: ns, ps: ps, token_count: tokens} = state_machine
          } =
            state
        )
        when local_addr < @min_slave_addr and ns == rem(ps + 1, state.opts.max_master_address + 1) and
               tokens >= @param_n_poll - 1 do
      # State ResetMaintenancePFM
      log_debug(fn ->
        "BacMstpTransport: Reached state DONE_WITH_TOKEN and pass token to known successor (ResetMaintenancePFM) " <>
          "to destination #{ns}"
      end)

      ReceiveFSM.reset_event_count(state.receive_fsm)

      new_state = %{
        state
        | state_machine: %{
            state_machine
            | ps: state_machine.ts,
              retry_count: 0,
              token_count: 1
          },
          transport_state: :pass_token
      }

      case send_frame_token(new_state, ns) do
        {:ok, state} ->
          new_state = state_set_silence_timer(state, :timer_rcv_timeout, @param_t_usage_timeout)
          {:noreply, new_state}

        {:error, state} ->
          # Retry again (non-cancelable)
          {:noreply,
           state_set_silence_timer(state, {:timer_retry_token_handoff, ns}, @param_t_slot)}
      end
    end

    def handle_continue(
          :done_with_token,
          %State{
            local_address: local_addr,
            state_machine:
              %{sole_master: true, ns: ns, ps: ps, token_count: tokens} = state_machine
          } =
            state
        )
        when local_addr < @min_slave_addr and ns == rem(ps + 1, state.opts.max_master_address + 1) and
               tokens >= @param_n_poll - 1 do
      # State SoleMasterRestartMaintenancePFM
      ps = rem(ns + 1, state.opts.max_master_address + 1)

      log_debug(fn ->
        "BacMstpTransport: Reached state DONE_WITH_TOKEN and transition to POLL_FOR_MASTER (SoleMaster) " <>
          "to destination #{ps}"
      end)

      new_state = %{
        state
        | state_machine: %{
            state_machine
            | ps: ps,
              ns: state_machine.ts,
              retry_count: 0,
              token_count: 1
          },
          transport_state: :poll_for_master
      }

      {_type, state} = send_frame_pfm(new_state, ps)
      {:noreply, state}
    end

    @doc false
    def handle_call(:close, _from, %State{} = state) do
      log_debug("BacMstpTransport: Received close request")

      ReceiveFSM.close(state.receive_fsm)
      UART.close(state.uart_pid)

      {:stop, :normal, :ok, state}
    end

    def handle_call(:get_local_address, _from, %State{} = state) do
      log_debug("BacMstpTransport: Received get_local_address request")

      {:reply, state.local_address, state}
    end

    def handle_call({:is_destination_routed, destination}, _from, %State{} = state)
        when is_integer(destination) do
      log_debug(fn ->
        "BacMstpTransport: Received is_destination_routed request for #{inspect(destination)}"
      end)

      {:reply, !is_valid_destination(destination), state}
    end

    def handle_call({:is_destination_routed, destination}, _from, state) do
      log_debug(fn ->
        "BacMstpTransport: Received (non-MSTP) is_destination_routed request for #{inspect(destination)}"
      end)

      {:reply, true, state}
    end

    def handle_call(
          {:send, destination, send_and_wait, data, _data_length, invoke_id},
          _from,
          %State{
            state_machine: %{source_address: source} = _state_machine,
            transport_state: :answer_data_request,
            answer_invoke_id: answer_invoke_id
          } =
            state
        )
        when destination == source and not send_and_wait and not is_nil(invoke_id) and
               invoke_id == answer_invoke_id do
      # If we are in ANSWER_DATA_REQUEST state and destination is the source,
      # check if it's an answer and invoke_id matches (invoke_id is nil if it's not an answer)
      log_debug(fn ->
        "BacMstpTransport: Received send request to release ANSWER_DATA_REQUEST state for #{inspect(destination)}"
      end)

      state = state_cancel_silence_timer(state)
      state = state_set_silence_timer(state, :timer_lost_token, @param_t_no_token)

      {reply, new_state} =
        send_frame_data_not_expecting_reply(
          %{state | transport_state: :idle},
          destination,
          data
        )

      {:reply, reply, new_state}
    end

    def handle_call(
          {:send, destination, _send_and_wait, _data, _data_length, invoke_id},
          _from,
          %State{
            local_address: local_addr,
            transport_state: :idle
          } =
            state
        )
        when local_addr >= @min_slave_addr and not is_nil(invoke_id) do
      # If we are in we are in slave mode,
      # check if it's an answer and invoke_id matches (invoke_id is nil if it's not an answer)
      # This is the sign that we CAN NOT reply deferred
      log_debug(fn ->
        "BacMstpTransport: Received send request to release ANSWER_DATA_REQUEST state for #{inspect(destination)}" <>
          ", but we are in slave mode and transitioned to IDLE state, so we can not reply deferred"
      end)

      {:reply, {:error, :app_timeout}, state}
    end

    def handle_call(
          {:send, destination, send_and_wait, data, data_length, _invoke_id},
          _from,
          %State{local_address: local_addr} = state
        )
        when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Received send request for #{inspect(destination)}"
      end)

      new_queue = :queue.in({destination, send_and_wait, data, data_length}, state.send_queue)
      new_state = %{state | send_queue: new_queue}

      # send_timer contains timer for :wakeup_use_token
      if new_state.send_timer do
        Process.cancel_timer(new_state.send_timer)

        {:reply, :ok, %{new_state | send_timer: nil}, {:continue, :use_token}}
      else
        {:reply, :ok, new_state}
      end
    end

    def handle_call(
          {:send, _destination, _send_and_wait, _data, _data_length, _invoke_id},
          _from,
          %State{} = state
        ) do
      log_debug(fn ->
        "BacMstpTransport: Received send request in slave mode"
      end)

      {:reply, {:error, :slave_mode}, state}
    end

    def handle_call(
          {:send_test, destination, data},
          from,
          %State{local_address: local_addr} = state
        )
        when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Received send_test request for #{inspect(destination)}"
      end)

      new_queue = :queue.in({destination, :test, data, nil}, state.send_queue)
      new_state = %{state | send_queue: new_queue, active_test: from}

      # send_timer contains timer for :wakeup_use_token
      if new_state.send_timer do
        Process.cancel_timer(new_state.send_timer)

        {:noreply, %{new_state | send_timer: nil}, {:continue, :use_token}}
      else
        # Reply is sent asynchronously when Test-Response arrives
        {:noreply, new_state}
      end
    end

    def handle_call(
          {:send_test, _destination, _data},
          _from,
          %State{} = state
        ) do
      log_debug(fn ->
        "BacMstpTransport: Received send_test request in slave mode"
      end)

      {:reply, {:error, :slave_mode}, state}
    end

    def handle_call(_call, _from, state) do
      {:noreply, state}
    end

    @doc false
    def handle_cast(_cast, %State{} = state) do
      {:noreply, state}
    end

    @doc false
    def handle_info({:serial_crash, reason}, %State{} = state) do
      # This message is either sent by ReceiveFSM or when writing UART fails
      Logger.error(fn ->
        "BacMstpTransport: UART error encountered and shutting down, error: " <> inspect(reason)
      end)

      # Stop everything
      ReceiveFSM.close(state.receive_fsm)
      UART.close(state.uart_pid)

      {:stop, {:uart_error, reason}, state}
    end

    def handle_info(:wakeup_use_token, %State{} = state) do
      {:noreply, state, {:continue, :use_token}}
    end

    def handle_info(
          :timer_rcv_timeout,
          %State{
            state_machine: %{retry_count: retry} = state_machine,
            transport_state: :pass_token
          } =
            state
        )
        when retry < @param_n_retry_token do
      # State RetrySendToken
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state PASS_TOKEN - retrying"
      end)

      new_state =
        state_clear_silence_timer(%{
          state
          | state_machine: %{
              state_machine
              | retry_count: retry + 1
            }
        })

      case send_frame_token(new_state, state_machine.ns) do
        {:ok, state} ->
          new_state = state_set_silence_timer(state, :timer_rcv_timeout, @param_t_usage_timeout)
          {:noreply, new_state}

        {:error, state} ->
          # Retry again (non-cancelable)
          {:noreply, state_set_silence_timer(state, :timer_rcv_timeout, @param_t_slot)}
      end
    end

    def handle_info(
          :timer_rcv_timeout,
          %State{state_machine: %{ns: ns, ts: ts} = state_machine, transport_state: :pass_token} =
            state
        )
        when ts == rem(ns + 1, state.opts.max_master_address + 1) do
      # State FindNewSuccessorUnknown
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state PASS_TOKEN - " <>
          "transition to POLL_FOR_MASTER (FindNewSuccessorUnknown)"
      end)

      ps = rem(ts + 1, state.opts.max_master_address + 1)

      new_state =
        state_clear_silence_timer(%{
          state
          | state_machine: %{
              state_machine
              | ps: ps,
                ns: state_machine.ts,
                retry_count: 0,
                token_count: 0
            },
            transport_state: :poll_for_master
        })

      {_type, state} = send_frame_pfm(new_state, ps)
      {:noreply, state}
    end

    def handle_info(
          :timer_rcv_timeout,
          %State{state_machine: %{} = state_machine, transport_state: :pass_token} = state
        ) do
      # State FindNewSuccessor
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state PASS_TOKEN - " <>
          "transition to POLL_FOR_MASTER (FindNewSuccessor)"
      end)

      ps = rem(state_machine.ns + 1, state.opts.max_master_address + 1)

      new_state =
        state_clear_silence_timer(%{
          state
          | state_machine: %{
              state_machine
              | ps: ps,
                ns: state_machine.ts,
                retry_count: 0,
                token_count: 0
            },
            transport_state: :poll_for_master
        })

      {_type, state} = send_frame_pfm(new_state, ps)
      {:noreply, state}
    end

    def handle_info(
          :timer_rcv_timeout,
          %State{
            state_machine: %{sole_master: true} = state_machine,
            transport_state: :poll_for_master
          } = state
        ) do
      # State SoleMaster: There was no valid reply to the periodic poll by the sole known master for other masters
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state POLL_FOR_MASTER (sole master)"
      end)

      {:noreply,
       state_clear_silence_timer(%{
         state
         | state_machine: %{
             state_machine
             | frame_count: 0
           },
           transport_state: :use_token
       }), {:continue, :use_token}}
    end

    def handle_info(
          :timer_rcv_timeout,
          %State{
            state_machine: %{ns: ns, ts: ts} = state_machine,
            transport_state: :poll_for_master
          } = state
        )
        when ns != ts do
      # State DoneWithPFM: There was no valid reply to the maintenance poll for a master
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state POLL_FOR_MASTER (known successor)"
      end)

      ReceiveFSM.reset_event_count(state.receive_fsm)

      # Send TOKEN frame to NS (our successor)
      new_state =
        state_clear_silence_timer(%{
          state
          | state_machine: %{
              state_machine
              | retry_count: 0
            },
            transport_state: :pass_token
        })

      case send_frame_token(new_state, ns) do
        {:ok, state} ->
          new_state = state_set_silence_timer(state, :timer_rcv_timeout, @param_t_usage_timeout)
          {:noreply, new_state}

        {:error, state} ->
          # Retry again (non-cancelable)
          {:noreply, state_set_silence_timer(state, :timer_rcv_timeout, @param_t_slot)}
      end
    end

    def handle_info(
          :timer_rcv_timeout,
          %State{
            state_machine: %{ns: ns, ts: ts, ps: ps} = state_machine,
            transport_state: :poll_for_master
          } = state
        )
        when ns == ts and rem(ps + 1, state.opts.max_master_address + 1) != ts do
      # State SendNextPFM: There was no valid reply by the PS, so try to poll the next master
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state POLL_FOR_MASTER (unknown successor)"
      end)

      ps = rem(ps + 1, state.opts.max_master_address + 1)

      new_state =
        state_clear_silence_timer(%{
          state
          | state_machine: %{
              state_machine
              | ps: ps,
                retry_count: 0
            },
            transport_state: :poll_for_master
        })

      {_type, state} = send_frame_pfm(new_state, ps)
      {:noreply, state}
    end

    def handle_info(
          :timer_rcv_timeout,
          %State{
            state_machine: %{ns: ns, ts: ts, ps: ps} = state_machine,
            transport_state: :poll_for_master
          } = state
        )
        when ns == ts and rem(ps + 1, state.opts.max_master_address + 1) == ts do
      # DeclareSoleMaster: No known successor and no previous polled master has answered (none alive)
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state POLL_FOR_MASTER (declaring sole master)"
      end)

      new_state =
        state_clear_silence_timer(%{
          state
          | state_machine: %{
              state_machine
              | ps: ps,
                frame_count: 0,
                sole_master: true
            },
            transport_state: :use_token
        })

      {:noreply, new_state, {:continue, :use_token}}
    end

    def handle_info(
          :timer_rcv_timeout,
          %State{state_machine: state_machine, transport_state: :wait_for_reply} = state
        ) do
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state WAIT_FOR_REPLY"
      end)

      if state.active_test do
        GenServer.reply(state.active_test, {:error, :apdu_timeout})
      end

      # ASHRAE 135:
      # If SilenceTimer is greater than or equal to Treply_timeout,
      # then assume that the request has failed. Set FrameCount to Nmax_info_frames and enter the DONE_WITH_TOKEN state.
      # Any retry of the data frame shall await the next entry to the USE_TOKEN state.
      # (Because of the length of the timeout, this transition will cause the token to be passed regardless of the initial value of FrameCount)
      {:noreply,
       state_cancel_silence_timer(%{
         state
         | active_test: nil,
           state_machine: %{state_machine | frame_count: state.opts.max_info_frames},
           transport_state: :done_with_token
       }), {:continue, :done_with_token}}
    end

    def handle_info(
          :timer_rcv_timeout,
          %State{} = state
        ) do
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state " <>
          String.upcase(Atom.to_string(state.transport_state))
      end)

      {:noreply, state_cancel_silence_timer(state)}
    end

    # This message is sent by the ReceiveFSM
    # LostToken can only be in effect during state IDLE (and if not sole master)
    def handle_info(
          :timer_lost_token,
          %State{
            local_address: local_addr,
            transport_state: :idle,
            state_machine: %{sole_master: false}
          } = state
        )
        when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Received lost token timer message during state IDLE"
      end)

      Logger.info(fn ->
        "BacMstpTransport: Token has been lost - generating token in Tslot * TS (#{state.state_machine.ts})"
      end)

      # ASHRAE 135:
      #  LostToken:
      #  If SilenceTimer is greater than or equal to Tno_token,
      #  then assume that the token has been lost.
      #  Set EventCount to zero and enter the NO_TOKEN state.
      ReceiveFSM.reset_event_count(state.receive_fsm)

      {:noreply,
       state_set_silence_timer(
         state_clear_silence_timer(%{state | transport_state: :no_token}),
         {:timer_generate_token, System.time_offset(:millisecond)},
         max(trunc(@param_t_slot * state.state_machine.ts), 0)
       )}
    end

    # This message is sent by the ReceiveFSM
    # As slave, we ignore this
    def handle_info(
          :timer_lost_token,
          %State{} = state
        ),
        do: {:noreply, state_clear_silence_timer(state)}

    def handle_info(
          {:timer_generate_token, ts_offset},
          %State{state_machine: state_machine, transport_state: :no_token} = state
        ) do
      log_debug(fn ->
        "BacMstpTransport: Received generate token timer message"
      end)

      cond do
        # Assert timer was received BEFORE the next station would generate a new token
        System.time_offset(:millisecond) - ts_offset <
            @param_t_slot * (state.state_machine.ts + 1) ->
          Logger.info(fn ->
            "BacMstpTransport: Token has been lost and generating token now - " <>
              "transitioning to POLL_FOR_MASTER state"
          end)

          ps = rem(state.state_machine.ts + 1, state.opts.max_master_address + 1)

          new_state =
            state_clear_silence_timer(%{
              state
              | state_machine: %{
                  state_machine
                  | ps: ps,
                    ns: state.state_machine.ts,
                    retry_count: 0,
                    token_count: 0
                },
                transport_state: :poll_for_master
            })

          {_type, state} = send_frame_pfm(new_state, ps)
          {:noreply, state}

        # Timer was received AFTER our timeslot -> the next station generates a new token
        true ->
          {:noreply,
           state_set_silence_timer(
             %{state | transport_state: :idle},
             :timer_lost_token,
             @param_t_no_token
           )}
      end
    end

    def handle_info(
          {:timer_retry_token_handoff, ns},
          %State{state_machine: state_machine, transport_state: :pass_token} = state
        ) do
      log_debug(fn ->
        "BacMstpTransport: Received retry token handoff timer message"
      end)

      handle_token_handoff(
        ns,
        state_clear_silence_timer(%{state | state_machine: %{state_machine | retry_count: -1}})
      )
    end

    def handle_info(
          :timer_answer_timeout,
          %State{state_machine: state_machine} = state
        ) do
      log_debug(fn ->
        "BacMstpTransport: Received answer timeout timer message - sending REPLY_POSTPONED"
      end)

      new_state =
        state_clear_silence_timer(%{state | transport_state: :idle, answer_invoke_id: nil})

      new_state = state_set_silence_timer(new_state, :timer_lost_token, @param_t_no_token)

      # Do not send Reply-Postponed as slave
      {_type, new_state} =
        if state.local_address <= @max_master_addr do
          send_frame_reply_postponed(new_state, state_machine.source_address)
        else
          {nil, new_state}
        end

      {:noreply, new_state}
    end

    def handle_info(:received_invalid_frame, %State{} = state) do
      log_debug(fn ->
        "BacMstpTransport: Received received_invalid_frame message from MS/TP Receive FSM"
      end)

      state = state_cancel_silence_timer(state)

      new_state =
        if state.transport_state == :idle do
          state_set_silence_timer(state, :timer_lost_token, @param_t_no_token)
        else
          state
        end

      {:noreply, new_state}
      |> handle_maybe_poll_for_master_invalid_frame()
      |> handle_maybe_wait_for_reply_invalid_frame()
    end

    # During ANSWER_DATA_REQUEST state we MUST NOT receive any data,
    # no one should be sending any data anyway and instead wait for our answer
    # (The actual answer or REPLY_POSTPONED frame)
    def handle_info(
          {:received_frame, %StateData{} = data},
          %State{} = state
        )
        when state.transport_state == :answer_data_request do
      log_debug(fn ->
        "BacMstpTransport: Received unexpected received_frame message from MS/TP Receive FSM in " <>
          "ANSWER_DATA_REQUEST state - dropping frame"
      end)

      # state = state_cancel_silence_timer(state)

      # state =
      #  if state.transport_state == :idle do
      #    state_set_silence_timer(state, :timer_lost_token, @param_t_no_token)
      # else
      #     state
      #  end

      {:noreply,
       Map.update!(state, :statistics, fn map ->
         Map.update(map, data.frame_type, 1, &(&1 + 1))
       end)}
    end

    def handle_info(
          {:received_frame, %StateData{} = data},
          %State{} = state
        )
        when (state.transport_state == :poll_for_master and
                (data.destination_address != state.local_address or
                   data.frame_type != :reply_to_poll_for_master)) or
               (state.transport_state == :wait_for_reply and
                  (data.destination_address != state.local_address or
                     data.frame_type not in [
                       :test_response,
                       :bacnet_data_not_expecting_reply,
                       :bacnet_extended_data_not_expecting_reply,
                       :reply_postponed
                     ])) do
      log_debug(fn ->
        "BacMstpTransport: Received unexpected received_frame message from MS/TP Receive FSM in " <>
          String.upcase(Atom.to_string(state.transport_state)) <>
          " state - dropping frame and transition to IDLE"
      end)

      if state.active_test do
        GenServer.reply(state.active_test, {:error, :transport_line_access_conflict})
      end

      state = state_cancel_silence_timer(state)
      state = state_set_silence_timer(state, :timer_lost_token, @param_t_no_token)

      state_machine = state.state_machine

      new_state = %{
        state
        | transport_state: :idle,
          answer_invoke_id: nil,
          active_test: nil,
          state_machine: %{state_machine | sole_master: false}
      }

      {:noreply,
       Map.update!(new_state, :statistics, fn map ->
         Map.update(map, data.frame_type, 1, &(&1 + 1))
       end)}
    end

    def handle_info(
          {:received_frame, %StateData{} = data},
          %State{} = state
        ) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received received_frame message from MS/TP Receive FSM"
      end)

      state = state_cancel_silence_timer(state)

      state =
        if state.transport_state == :idle do
          state_set_silence_timer(state, :timer_lost_token, @param_t_no_token)
        else
          state
        end

      # We keep track of source_address directly in our state_machine for further use
      state_machine = state.state_machine
      state = %{state | state_machine: %{state_machine | source_address: data.source_address}}

      handle_mstp_frame(
        Map.update!(state, :statistics, fn map ->
          Map.update(map, data.frame_type, 1, &(&1 + 1))
        end),
        data
      )
    end

    def handle_info({:received_data, data_length}, %State{} = state) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received received_data message from MS/TP Receive FSM"
      end)

      cond do
        # State SawTokenUser: Assume that a frame has been sent by the new token user
        state.transport_state == :pass_token and data_length >= @param_n_min_octets ->
          log_debug_comm(state, fn ->
            "BacMstpTransport: State PASS_TOKEN and SawTokenUser fulfilled" <>
              " - transitioning to IDLE"
          end)

          {:noreply,
           state_set_silence_timer(
             state_cancel_silence_timer(%{state | transport_state: :idle}),
             :timer_lost_token,
             @param_t_no_token
           )}

        # Reset silence timer of LostToken, if we have received bytes,
        # if not, the token has been lost presumably (let the silence timer trigger)
        state.transport_state == :idle and data_length >= @param_n_min_octets ->
          log_debug_comm(state, fn ->
            "BacMstpTransport: State IDLE and LostToken not fulfilled"
          end)

          state = state_cancel_silence_timer(state)
          state = state_set_silence_timer(state, :timer_lost_token, @param_t_no_token)

          {:noreply, state}

        true ->
          {:noreply, state}
      end
    end

    def handle_info(_info, state) do
      {:noreply, state}
    end

    @spec handle_mstp_frame(State.t(), StateData.t()) ::
            {:noreply, State.t()} | {:noreply, State.t(), term()}
    defp handle_mstp_frame(state, state_data)

    # defp handle_mstp_frame(
    #        %State{} = state
    #        %{received_invalid_frame: invalid, received_valid_frame: valid} = _data
    #      )
    #      when invalid or not valid do
    #   # We should never enter this branch, but just in case we're handling it
    #   {:noreply, state}
    # end

    defp handle_mstp_frame(
           %State{local_address: addr} = state,
           %StateData{frame_type: :token, data_length: 0, destination_address: dest} = state_data
         )
         when addr <= @max_master_addr and dest != @broadcast_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type TOKEN with data length " <>
          "#{state_data.data_length} as master node"
      end)

      {:noreply,
       %{
         state
         | state_machine: %{state.state_machine | sole_master: false},
           transport_state: :use_token
       }, {:continue, :use_token}}
    end

    defp handle_mstp_frame(
           %State{
             local_address: addr
           } = state,
           %StateData{frame_type: :token, data_length: 0} = state_data
         )
         when addr >= @min_slave_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received invalid frame of type TOKEN with data length " <>
          "#{state_data.data_length} as slave node - current state " <>
          String.upcase(Atom.to_string(state.transport_state))
      end)

      {:noreply, state}
    end

    defp handle_mstp_frame(
           %State{
             local_address: addr
           } = state,
           %StateData{frame_type: :poll_for_master, data_length: 0, destination_address: dest} =
             state_data
         )
         when addr <= @max_master_addr and dest != @broadcast_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type POLL_FOR_MASTER with data length " <>
          "#{state_data.data_length} as master node - current state " <>
          String.upcase(Atom.to_string(state.transport_state))
      end)

      {_type, state} = send_frame_reply_pfm(state, state_data.source_address)
      {:noreply, state}
    end

    defp handle_mstp_frame(
           %State{
             local_address: addr
           } = state,
           %StateData{frame_type: :poll_for_master, data_length: 0} = state_data
         )
         when addr >= @min_slave_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received invalid frame of type POLL_FOR_MASTER with data length " <>
          "#{state_data.data_length} as slave node - current state " <>
          String.upcase(Atom.to_string(state.transport_state))
      end)

      {:noreply, state}
    end

    defp handle_mstp_frame(
           %State{
             local_address: addr,
             transport_state: :poll_for_master
           } = state,
           %StateData{
             frame_type: :reply_to_poll_for_master,
             data_length: 0,
             destination_address: dest
           } =
             state_data
         )
         when addr <= @max_master_addr and dest != @broadcast_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type REPLY_TO_POLL_FOR_MASTER with data length " <>
          "#{state_data.data_length} as master node"
      end)

      # Maybe Logger.info?
      log_debug(
        "BacMstpTransport: Found master at address #{state_data.source_address} - handing off TOKEN"
      )

      handle_token_handoff(state_data.source_address, state)
    end

    defp handle_mstp_frame(
           %State{} = state,
           %StateData{frame_type: :test_request} = state_data
         ) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type TEST_REQUEST with data length #{state_data.data_length}"
      end)

      {_type, new_state} = send_frame_test_response(state, state_data)
      {:noreply, new_state}
    end

    # We received a TEST_RESPONSE frame, which is a reply to our TEST_REQUEST frame
    defp handle_mstp_frame(
           %State{} = state,
           %StateData{frame_type: :test_response} = state_data
         ) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type TEST_RESPONSE with data length #{state_data.data_length}"
      end)

      # The test response is sent back to the one requesting it (state.active_test is the from arg of handle_call)
      if state.active_test do
        GenServer.reply(state.active_test, {:ok, state_data.input_buffer})
      end

      {:noreply,
       %{
         state
         | active_test: nil,
           state_machine: %{
             state.state_machine
             | silence_timer: nil
           },
           transport_state: :done_with_token
       }, {:continue, :done_with_token}}
    end

    defp handle_mstp_frame(
           %State{} = state,
           %StateData{
             frame_type: :bacnet_data_expecting_reply,
             data_length: len,
             destination_address: dest
           } = state_data
         )
         when len > 0 and dest != @broadcast_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type DATA_EXPECTING_REPLY with data length #{state_data.data_length}"
      end)

      handle_mstp_frame_data(state, state_data, true)
    end

    defp handle_mstp_frame(
           %State{} = state,
           %StateData{
             frame_type: :bacnet_data_not_expecting_reply,
             data_length: len
           } = state_data
         )
         when len > 0 do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type DATA_NOT_EXPECTING_REPLY with data length #{state_data.data_length}"
      end)

      handle_mstp_frame_data(state, state_data, false)
    end

    defp handle_mstp_frame(
           %State{} = state,
           %StateData{frame_type: :reply_postponed, data_length: 0, destination_address: dest} =
             state_data
         )
         when dest != @broadcast_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type REPLY_POSTPONED with data length #{state_data.data_length}"
      end)

      # We received a REPLY_POSTPONED frame to our request, so enter DONE_WITH_TOKEN state
      {:noreply, %{state | transport_state: :done_with_token}, {:continue, :done_with_token}}
    end

    defp handle_mstp_frame(
           %State{} = state,
           %StateData{
             frame_type: :bacnet_extended_data_expecting_reply,
             data_length: len,
             destination_address: dest
           } = state_data
         )
         when len > 0 and dest != @broadcast_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type EXT_DATA_EXPECTING_REPLY with data length #{state_data.data_length}"
      end)

      handle_mstp_frame_data(state, state_data, true)
    end

    defp handle_mstp_frame(
           %State{} = state,
           %StateData{
             frame_type: :bacnet_extended_data_not_expecting_reply,
             data_length: len
           } = state_data
         )
         when len > 0 do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type EXT_DATA_NOT_EXPECTING_REPLY with data length #{state_data.data_length}"
      end)

      handle_mstp_frame_data(state, state_data, false)
    end

    defp handle_mstp_frame(
           %State{} = state,
           %StateData{frame_type: {:proprietary, type_num}, destination_address: dest} =
             state_data
         ) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type PROPRIETARY (#{type_num}) with data length " <>
          "#{state_data.data_length} and destination #{dest}, it will be ignored however"
      end)

      {:noreply, state}
    end

    defp handle_mstp_frame(%State{} = state, %StateData{} = state_data) do
      # This is a catch-all clause to handle all invalid frames (i.e. destination = broadcast and frame type = TOKEN)
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received invalid frame of type #{state_data.frame_type} with " <>
          "data length #{state_data.data_length} - current state " <>
          String.upcase(Atom.to_string(state.transport_state))
      end)

      {:noreply, state}
    end

    # We received BACnet DATA frame (either expecting or non-expecting reply) as answer
    @spec handle_mstp_frame_data(State.t(), StateData.t(), boolean()) ::
            {:noreply, State.t()} | {:noreply, State.t(), term()}
    defp handle_mstp_frame_data(state, state_data, expects_reply)

    defp handle_mstp_frame_data(
           %State{state_machine: state_machine, transport_state: :wait_for_reply} = state,
           %StateData{} = state_data,
           true
         ) do
      case decode_packet(state_data) do
        {:ok, {npci, decoded}} ->
          after_decode_fanout_cb(state, state_data, npci, decoded)

        {:error, err} ->
          Logger.warning(
            "BacMstpTransport: Got error while decoding MS/TP packet, error: #{inspect(err)}"
          )

        {:ignore, reason} ->
          log_debug(fn ->
            "BacMstpTransport: Discards MS/TP packet, reason: #{inspect(reason)}"
          end)
      end

      new_state = %{
        state
        | answer_invoke_id: nil,
          state_machine: %{
            state_machine
            | silence_timer: nil
          },
          transport_state: :done_with_token
      }

      {:noreply, new_state, {:continue, :done_with_token}}
    end

    # We received BACnet DATA frame (either expecting or non-expecting reply), so handle it
    defp handle_mstp_frame_data(
           %State{} = state,
           %StateData{} = state_data,
           expects_reply
         ) do
      # Enter ANSWER_DATA_REQUEST state
      # Per specification we should wait T_reply_delay for a response from the higher layers
      # and if we receive one, immediately send it, or if not, send REPLY_POSTPONED frame

      case decode_packet(state_data) do
        {:ok, {npci, decoded}} ->
          after_decode_fanout_cb(state, state_data, npci, decoded)

        {:error, err} ->
          Logger.warning(
            "BacMstpTransport: Got error while decoding MS/TP packet, error: #{inspect(err)}"
          )

        {:ignore, reason} ->
          log_debug(fn ->
            "BacMstpTransport: Discards MS/TP packet, reason: #{inspect(reason)}"
          end)
      end

      answer_invoke_id =
        if expects_reply do
          case APDU.get_invoke_id_from_raw_apdu(state_data.input_buffer) do
            {:ok, id} -> id
            _other -> nil
          end
        end

      new_state =
        if answer_invoke_id do
          state_set_silence_timer(
            %{
              state
              | answer_invoke_id: answer_invoke_id,
                transport_state: :answer_data_request
            },
            :timer_answer_timeout,
            trunc(@param_t_reply_delay * @apdu_timer_factor)
          )
        else
          state
        end

      {:noreply, new_state}
    end

    # There are cases when an invalid frame needs to be explicitely handled to transit a state (i.e. during POLL_FOR_MASTER)
    # Returns from handle_received_data/2 with a triple tuple are ignored, because they already do a transition
    @spec handle_maybe_poll_for_master_invalid_frame(
            {:noreply, State.t()}
            | {:noreply, State.t(), term()}
          ) :: {:noreply, State.t()} | {:noreply, State.t(), term()}
    defp handle_maybe_poll_for_master_invalid_frame(return)

    defp handle_maybe_poll_for_master_invalid_frame(
           {:noreply,
            %{
              state_machine:
                %{sole_master: false, ns: ns, ts: ts} =
                  state_machine,
              transport_state: :poll_for_master
            } = state}
         )
         when ns != ts do
      # State DoneWithPFM: If POLL_FOR_MASTER and not SOLE_MASTER and known successor and invalid frame
      log_debug(fn ->
        "BacMstpTransport: Received invalid frame message at state POLL_FOR_MASTER (known successor)"
      end)

      ReceiveFSM.reset_event_count(state.receive_fsm)

      # Send TOKEN frame to NS (our successor)
      new_state = %{
        state
        | state_machine: %{
            state_machine
            | retry_count: 0
          },
          transport_state: :pass_token
      }

      case send_frame_token(new_state, ns) do
        {:ok, state} ->
          new_state = state_set_silence_timer(state, :timer_rcv_timeout, @param_t_usage_timeout)
          {:noreply, new_state}

        {:error, state} ->
          # Retry again (non-cancelable)
          {:noreply,
           state_set_silence_timer(state, {:timer_retry_token_handoff, ns}, @param_t_slot)}
      end
    end

    defp handle_maybe_poll_for_master_invalid_frame(
           {:noreply,
            %{
              state_machine:
                %{sole_master: false, ns: ns, ts: ts, ps: ps} =
                  state_machine,
              transport_state: :poll_for_master
            } = state}
         )
         when ns == ts and rem(ps + 1, state.opts.max_master_address + 1) != ts do
      # State SendNextPFM: If POLL_FOR_MASTER and not SOLE_MASTER and unknown successor and invalid frame
      log_debug(fn ->
        "BacMstpTransport: Received invalid frame message at state POLL_FOR_MASTER (unknown successor)"
      end)

      ps = rem(ps + 1, state.opts.max_master_address + 1)

      new_state = %{
        state
        | state_machine: %{
            state_machine
            | ps: ps,
              retry_count: 0,
              silence_timer: nil,
              silence_timestamp: nil
          },
          transport_state: :poll_for_master
      }

      {_type, state} = send_frame_pfm(new_state, ps)
      {:noreply, state}
    end

    defp handle_maybe_poll_for_master_invalid_frame(
           {:noreply,
            %{
              state_machine: %{sole_master: true} = state_machine,
              transport_state: :poll_for_master
            } = state}
         ) do
      # State SoleMaster: If POLL_FOR_MASTER and SOLE_MASTER and invalid frame, transit to USE_TOKEN state
      log_debug(fn ->
        "BacMstpTransport: Received invalid frame message at state POLL_FOR_MASTER (sole master)"
      end)

      {:noreply,
       %{
         state
         | state_machine: %{state_machine | frame_count: 0},
           transport_state: :use_token
       }, {:continue, :use_token}}
    end

    defp handle_maybe_poll_for_master_invalid_frame(return) do
      return
    end

    @spec handle_maybe_wait_for_reply_invalid_frame(
            {:noreply, State.t()}
            | {:noreply, State.t(), term()}
          ) :: {:noreply, State.t()} | {:noreply, State.t(), term()}
    defp handle_maybe_wait_for_reply_invalid_frame(return)

    defp handle_maybe_wait_for_reply_invalid_frame(
           {:noreply, %State{transport_state: :wait_for_reply} = state}
         ) do
      {:noreply,
       %{
         state
         | transport_state: :done_with_token
       }, {:continue, :done_with_token}}
    end

    defp handle_maybe_wait_for_reply_invalid_frame(return) do
      return
    end

    # Sends a Token Frame to target - if writing fails, it retries automatically 100ms later
    @spec handle_token_handoff(source_address(), State.t()) :: {:noreply, State.t()}
    defp handle_token_handoff(ns, state)

    defp handle_token_handoff(
           ns,
           %State{state_machine: %{retry_count: count} = state_machine} = state
         )
         when count >= @param_n_retry_token do
      successor_unknown = rem(ns + 1, state.opts.max_master_address + 1) == state_machine.ts

      log_debug(fn ->
        "BacMstpTransport: Failed to handoff token to successor #{ns} - " <>
          if(successor_unknown,
            do: "finding new unknown successor",
            else: "finding new successor"
          )
      end)

      ps =
        if successor_unknown do
          rem(state_machine.ts + 1, state.opts.max_master_address + 1)
        else
          rem(state_machine.ns + 1, state.opts.max_master_address + 1)
        end

      new_state = %{
        state
        | state_machine: %{
            state_machine
            | ns: state_machine.ts,
              ps: ps,
              retry_count: 0,
              token_count: 0
          },
          transport_state: :poll_for_master
      }

      {_type, state} = send_frame_pfm(new_state, ps)
      {:noreply, state}
    end

    defp handle_token_handoff(ns, %State{state_machine: state_machine} = state)
         when is_integer(ns) do
      ReceiveFSM.reset_event_count(state.receive_fsm)

      new_state = %{
        state
        | state_machine: %{
            state_machine
            | sole_master: false,
              ns: ns,
              retry_count: state_machine.retry_count + 1,
              ps: state_machine.ts
          },
          transport_state: :pass_token
      }

      case send_frame_token(new_state, ns) do
        {:ok, state} ->
          new_state = state_set_silence_timer(state, :timer_rcv_timeout, @param_t_usage_timeout)
          {:noreply, new_state}

        {:error, state} ->
          # Retry again (non-cancelable)
          {:noreply,
           state_set_silence_timer(state, {:timer_retry_token_handoff, ns}, @param_t_slot)}
      end
    end

    # MS/TP Frame Format:
    # Preamble: two octet preamble: X'55', X'FF'
    # Frame Type: one octet
    # Destination Address: one octet address
    # Source Address: one octet address
    # Length: two octets, most significant octet first
    # Header CRC: one octet
    # Data: (present only if Length is non-zero)
    # Data CRC: (present only if Length is non-zero) two octets, least significant octet first
    # (pad): (optional) at most one octet of padding: X'FF'

    # Sends a Token Frame to destination
    @spec send_frame_token(State.t(), destination_address()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_token(%State{} = state, destination) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending Token to MS/TP network with destination #{destination}"
      end)

      header = [0, destination, state.local_address, 0, 0]
      crc = EncodingTools.calculate_header_crc(header, 0xFF)
      payload = [0x55, 0xFF, header, crc]

      send_uart_data(state, payload)
    end

    # Sends a Poll-For-Master Frame to destination
    @spec send_frame_pfm(State.t(), destination_address()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_pfm(%State{} = state, destination) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending Poll-For-Master to MS/TP network with destination #{destination}"
      end)

      header = [1, destination, state.local_address, 0, 0]
      crc = EncodingTools.calculate_header_crc(header, 0xFF)
      payload = [0x55, 0xFF, header, crc]

      with {:ok, state} <- send_uart_data(state, payload) do
        new_state = state_set_silence_timer(state, :timer_rcv_timeout, @param_t_usage_timeout)
        {:ok, new_state}
      end
    end

    # Sends a Reply-Poll-For-Master Frame to destination
    @spec send_frame_reply_pfm(State.t(), destination_address()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_reply_pfm(%State{} = state, destination) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending Reply-Poll-For-Master to MS/TP network with destination #{destination}"
      end)

      header = [2, destination, state.local_address, 0, 0]
      crc = EncodingTools.calculate_header_crc(header, 0xFF)
      payload = [0x55, 0xFF, header, crc]

      send_uart_data(state, payload)
    end

    # Sends a Test-Request Frame to destination
    @spec send_frame_test_request(State.t(), destination_address(), iodata()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_test_request(%State{} = state, destination, data) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending Test-Request to MS/TP network with destination #{destination}"
      end)

      data_len = IO.iodata_length(data)

      header = [3, destination, state.local_address, <<data_len::size(16)>>]
      header_crc = EncodingTools.calculate_header_crc(header, 0xFF)

      # We need ones-complement of the DataCRC
      data_crc = 0xFFFF - EncodingTools.calculate_data_crc(data, 0xFFFF)

      payload = [
        0x55,
        0xFF,
        header,
        header_crc,
        data,
        Bitwise.band(data_crc, 0xFF),
        Bitwise.bsr(data_crc, 8)
      ]

      send_uart_data(state, payload)
    end

    # Sends a Test-Response Frame to destination
    @spec send_frame_test_response(State.t(), StateData.t()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_test_response(%State{} = state, %StateData{} = state_data) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending Test-Response to MS/TP network with destination #{state_data.source_address}"
      end)

      data = state_data.input_buffer
      data_len = state_data.data_length

      header = [4, state_data.source_address, state.local_address, <<data_len::size(16)>>]
      header_crc = EncodingTools.calculate_header_crc(header, 0xFF)

      # We need ones-complement of the DataCRC
      data_crc = 0xFFFF - EncodingTools.calculate_data_crc(data, 0xFFFF)

      payload = [
        0x55,
        0xFF,
        header,
        header_crc,
        data,
        Bitwise.band(data_crc, 0xFF),
        Bitwise.bsr(data_crc, 8)
      ]

      send_uart_data(state, payload)
    end

    # Sends a BACnet-Data-Expecting-Reply Frame to destination
    @spec send_frame_data_expecting_reply(State.t(), destination_address(), iodata()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_data_expecting_reply(%State{} = state, destination, data) do
      data_len = IO.iodata_length(data)

      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending BACnet-Data-Expecting-Reply  to MS/TP network " <>
          "with destination #{destination} " <>
          "and data length #{data_len} bytes"
      end)

      header = [5, destination, state.local_address, <<data_len::size(16)>>]
      header_crc = EncodingTools.calculate_header_crc(header, 0xFF)

      # We need ones-complement of the DataCRC
      data_crc = 0xFFFF - EncodingTools.calculate_data_crc(data, 0xFFFF)

      payload = [
        0x55,
        0xFF,
        header,
        header_crc,
        data,
        Bitwise.band(data_crc, 0xFF),
        Bitwise.bsr(data_crc, 8)
      ]

      send_uart_data(state, payload)
    end

    # Sends a BACnet-Data-Not-Expecting-Reply Frame to destination
    @spec send_frame_data_not_expecting_reply(State.t(), destination_address(), iodata()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_data_not_expecting_reply(%State{} = state, destination, data) do
      data_len = IO.iodata_length(data)

      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending BACnet-Data-Not-Expecting-Reply to MS/TP network " <>
          "with destination #{destination} " <>
          "and data length #{data_len} bytes"
      end)

      header = [6, destination, state.local_address, <<data_len::size(16)>>]
      header_crc = EncodingTools.calculate_header_crc(header, 0xFF)

      data_crc =
        data
        |> EncodingTools.calculate_data_crc(0xFFFF)
        |> Bitwise.bnot()
        |> Bitwise.band(0xFFFF)

      payload = [
        0x55,
        0xFF,
        header,
        header_crc,
        data,
        Bitwise.band(data_crc, 0xFF),
        Bitwise.bsr(data_crc, 8)
      ]

      send_uart_data(state, payload)
    end

    # Sends a Reply-Postponed Frame to destination
    @spec send_frame_reply_postponed(State.t(), destination_address()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_reply_postponed(%State{} = state, destination) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending Reply-Postponed to MS/TP network with destination #{destination}"
      end)

      header = [7, destination, state.local_address, 0, 0]
      crc = EncodingTools.calculate_header_crc(header, 0xFF)
      payload = [0x55, 0xFF, header, crc]

      send_uart_data(state, payload)
    end

    # Sends a BACnet-Extended-Data-Expecting-Reply Frame to destination
    @spec send_frame_ext_data_expecting_reply(State.t(), destination_address(), iodata()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_ext_data_expecting_reply(%State{} = state, destination, data) do
      bin_data = IO.iodata_to_binary(data)

      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending BACnet-Data-Expecting-Reply  to MS/TP network " <>
          "with destination #{destination} " <>
          "and data length #{byte_size(bin_data)} bytes"
      end)

      case EncodingTools.encode_cobs(bin_data) do
        {:ok, cobs_data} ->
          cobs_len = IO.iodata_length(cobs_data) - 2

          header = [32, destination, state.local_address, <<cobs_len::size(16)>>]
          header_crc = EncodingTools.calculate_header_crc(header, 0xFF)

          payload = [0x55, 0xFF, header, header_crc, cobs_data]

          send_uart_data(state, payload)

          # {:error, reason} ->
          #   Logger.warning(fn ->
          #     "BacMstpTransport: Got error while trying to encode COBS data for " <>
          #       "BACnet-Extended-Data-Expecting-Reply, error: " <>
          #       inspect(reason)
          #   end)

          #   {:error, state}
      end
    end

    # Sends a BACnet-Extended-Data-Not-Expecting-Reply Frame to destination
    @spec send_frame_ext_data_not_expecting_reply(State.t(), destination_address(), iodata()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_ext_data_not_expecting_reply(%State{} = state, destination, data) do
      bin_data = IO.iodata_to_binary(data)

      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending BACnet-Data-Not-Expecting-Reply to MS/TP network " <>
          "with destination #{destination} " <>
          "and data length #{byte_size(bin_data)} bytes"
      end)

      case EncodingTools.encode_cobs(bin_data) do
        {:ok, cobs_data} ->
          cobs_len = IO.iodata_length(cobs_data) - 2

          header = [33, destination, state.local_address, <<cobs_len::size(16)>>]
          header_crc = EncodingTools.calculate_header_crc(header, 0xFF)

          payload = [0x55, 0xFF, header, header_crc, cobs_data]

          send_uart_data(state, payload)

          # {:error, reason} ->
          #   Logger.warning(fn ->
          #     "BacMstpTransport: Got error while trying to encode COBS data for " <>
          #       "BACnet-Extended-Data-Not-Expecting-Reply, error: " <>
          #       inspect(reason)
          #   end)

          #   {:error, state}
      end
    end

    @spec send_uart_data(State.t(), iodata()) :: {:ok, State.t()} | {:error, State.t()}
    defp send_uart_data(%State{} = state, data) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending data to MS/TP network with data length #{IO.iodata_length(data)}"
      end)

      # case data do
      #    [_, _, [type | _] | _] when type in [5, 6, 32, 33] ->
      #     IO.inspect(
      #       data,
      #        label: "BacMstpTransport: Sending data to MS/TP network"
      #     )
      #
      #    _other ->
      #      :ok
      #  end

      case UART.write(state.uart_pid, data) do
        :ok ->
          case UART.drain(state.uart_pid) do
            :ok ->
              {:ok, state}

            {:error, reason} ->
              log_debug_comm(state, fn ->
                "BacMstpTransport: Got error while trying to wait for transmit to MS/TP network to finish, error: " <>
                  inspect(reason)
              end)

              # We do not know if it actually failed (no data written to RS485),
              # so we just assume it worked (if it actually failed, we will run into timeouts anyway)
              {:ok, state}
          end

        {:error, reason} ->
          Logger.warning(fn ->
            "BacMstpTransport: Got error while trying to write data to MS/TP network, error: " <>
              inspect(reason)
          end)

          # Common errors are :badf and :eio
          # They are bad enough we need to stop (serial port is gone, dead, etc.)
          if reason not in [:eagain, :eintr] do
            send(self(), {:serial_crash, reason})
          end

          {:error, state}
      end
    end

    @spec state_clear_silence_timer(State.t()) :: State.t()
    defp state_clear_silence_timer(%State{state_machine: state_machine} = state) do
      %{state | state_machine: %{state_machine | silence_timer: nil, silence_timestamp: nil}}
    end

    @spec state_cancel_silence_timer(State.t()) :: State.t()
    defp state_cancel_silence_timer(%State{state_machine: state_machine} = state) do
      if state_machine.silence_timer do
        Process.cancel_timer(state_machine.silence_timer)
      end

      # Receive any message (race condition)
      # We only need to do this once, because only one silence timer can be set at a time
      receive do
        :timer_answer_timeout -> :ok
        :timer_lost_token -> :ok
        :timer_rcv_timeout -> :ok
        {:timer_generate_token, _ts} -> :ok
        {:timer_retry_token_handoff, _ns} -> :ok
      after
        0 -> :ok
      end

      state_clear_silence_timer(state)
    end

    @spec state_set_silence_timer(State.t(), term(), non_neg_integer()) :: State.t()
    # defp state_set_silence_timer(%State{} = state, :timer_lost_token, timeout) when is_integer(timeout) do
    #   # Make sure any active timer is cancelled
    #   state_cancel_silence_timer(state)
    # end

    defp state_set_silence_timer(%State{state_machine: state_machine} = state, message, timeout)
         when is_integer(timeout) do
      # Make sure any active timer is cancelled
      state_cancel_silence_timer(state)

      %{
        state
        | state_machine: %{
            state_machine
            | silence_timer: Process.send_after(self(), message, timeout),
              silence_timestamp: System.time_offset(:millisecond)
          }
      }
    end

    #### Helpers ####

    # Spawns a new task (either supervisored or not) and invokes the function,
    # ignoring any errors that may occur by the callback
    @spec spawn_task(State.t(), tuple(), term(), fun()) :: any()
    defp spawn_task(state, data, source_addr, fun)

    defp spawn_task(%State{opts: %{supervisor: sup}} = _state, data, source_addr, fun)
         when not is_nil(sup) and is_function(fun, 3) do
      server = self()

      Task.Supervisor.start_child(sup, fn ->
        fun.(source_addr, data, server)
      end)
    end

    defp spawn_task(%State{} = _state, data, source_addr, fun) when is_function(fun, 3) do
      server = self()
      Task.start(fn -> fun.(source_addr, data, server) end)
    end

    # Fans out the frame to the transport callback
    @spec after_decode_fanout_cb(State.t(), StateData.t(), NPCI.t(), term()) :: any()
    defp after_decode_fanout_cb(%State{} = state, %StateData{} = state_data, npci, apdu_data) do
      server = self()

      data =
        {:apdu,
         if(state_data.destination_address == 255,
           do: :original_broadcast,
           else: :original_unicast
         ), npci, apdu_data}

      source_addr = state_data.source_address

      case state.callback do
        {module, function, arity}
        when is_atom(module) and is_atom(function) and arity == 3 ->
          if function_exported?(module, function, arity) do
            spawn_task(state, data, source_addr, Function.capture(module, function, arity))
          end

        pid when is_dest(pid) ->
          try do
            send(
              pid,
              {:bacnet_transport, @transport_protocol, source_addr, data, server}
            )
          catch
            # Ignore any exception coming from send/2 (an "invalid" destination raises! [i.e. an atom but it's not registered])
            _type, _err -> :ok
          end

        fun when is_function(fun, 3) ->
          spawn_task(state, data, source_addr, fun)
      end
    end

    defp validate_open_opts(opts) do
      case opts[:baudrate] do
        nil ->
          :ok

        term when is_integer(term) and term >= 0 ->
          :ok

        term ->
          raise ArgumentError,
                "open/2 expected baudrate to be a non negative integer, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:local_address] do
        nil ->
          raise ArgumentError,
                "open/2 expected local_address to be present (absent in opts)"

        term when is_integer(term) and term >= @min_master_addr and term <= @max_slave_addr ->
          :ok

        term ->
          raise ArgumentError,
                "open/2 expected local_address to be a valid address in the range of 0-254, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:log_communication] do
        nil ->
          :ok

        term when is_boolean(term) ->
          :ok

        term ->
          raise ArgumentError,
                "open/2 expected log_communication to be a boolean, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:log_communication_rcv] do
        nil ->
          :ok

        term when is_boolean(term) ->
          :ok

        term ->
          raise ArgumentError,
                "open/2 expected log_communication_rcv to be a boolean, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:max_info_frames] do
        nil ->
          :ok

        term when is_integer(term) and term > 0 ->
          :ok

        term ->
          raise ArgumentError,
                "open/2 expected max_info_frames to be a positive integer, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:max_master_address] do
        nil ->
          :ok

        term when is_integer(term) and term >= @min_master_addr and term <= @max_master_addr ->
          :ok

        term ->
          raise ArgumentError,
                "open/2 expected max_master_address to be an integer in the range 0-127, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:port_name] do
        nil ->
          raise ArgumentError,
                "open/2 expected port_name to be present (absent in opts)"

        term when is_binary(term) ->
          :ok

        term ->
          raise ArgumentError,
                "open/2 expected port_name to be a binary, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:supervisor] do
        nil ->
          :ok

        term when is_atom(term) ->
          :ok

        term when is_pid(term) ->
          :ok

        {:global, _term} ->
          :ok

        {:via, mod, _term} when is_atom(mod) ->
          :ok

        {term, node} when is_atom(term) and is_atom(node) ->
          :ok

        term ->
          raise ArgumentError,
                "open/2 expected supervisor to be a valid supervisor reference, " <>
                  "got: #{inspect(term)}"
      end
    end

    # Expands the iodata and only gets the first byte, if not a binary
    @spec expand_data_to_binary(iodata() | byte()) :: binary()
    defp expand_data_to_binary(data) do
      case data do
        _bin when is_binary(data) -> data
        _ing when data >= 0 and data <= 255 -> <<data>>
        [] -> <<>>
        [[] | tl] -> expand_data_to_binary(tl)
        [hd | _tl] -> expand_data_to_binary(hd)
      end
    end

    @spec apdu_expects_reply(binary()) :: boolean()
    defp apdu_expects_reply(apdu)

    defp apdu_expects_reply(
           <<Constants.macro_by_name(:pdu_type, :confirmed_request)::size(4), _rest::bitstring>>
         ),
         do: true

    # A segmented Complex-ACK also expects a reply (in the form of a Segment-ACK)
    defp apdu_expects_reply(
           <<Constants.macro_by_name(:pdu_type, :complex_ack)::size(4), _filler::size(1),
             1::size(1), _rest::bitstring>>
         ),
         do: true

    defp apdu_expects_reply(_apdu), do: false

    #### BACnet MS/TP NPDU+APDU Frame Parsing ####

    # Do not accept NPCI with hopcount = 0, this signifies a non-conformant BACnet router
    defguardp is_valid_hopcount(hopcount)
              when is_nil(hopcount) or (is_integer(hopcount) and hopcount > 0)

    # Parses NPCI/NPDU, it will return the raw APDU data to be consumed
    @spec decode_packet(StateData.t()) ::
            {:ok, {npci :: NPCI.t(), apdu :: binary()}}
            | {:error, term()}
            | {:ignore, term()}
    defp decode_packet(%StateData{} = state) do
      with {:ok, {%NPCI{hopcount: hopcount} = npci, nsdu_data}} when is_valid_hopcount(hopcount) <-
             Protocol.decode_npci(state.input_buffer),
           {:ok, {:apdu, nsdu_data}} <- Protocol.decode_npdu(npci, nsdu_data) do
        {:ok, {npci, nsdu_data}}
      else
        {:ok, {%NPCI{} = _npci, _nsdu_data}} -> {:ignore, :invalid_hopcount}
        {:ok, {_type, _data}} -> {:ignore, :invalid_apdu_payload}
        {:error, _err} = err -> err
      end
    end
  end
end
