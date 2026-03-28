if Code.ensure_loaded?(Circuits.UART) do
  defmodule BACnet.Stack.Transport.MstpTransport do
    @moduledoc """
    The BACnet transport for BACnet MS/TP (Master-Slave/Token Passing)
    on a physical two wire electrical bus system called EIA-485 (RS485).

    This transport should be considered experimental, but it is fairly tested
    with BACnet certified devices and BACnet stack C open source implementation.

    This transport implementation supports ASHRAE 135-2016 and as such COBS encoding to allow frames
    up to 1476 bytes. When sending such large APDUs the receiving device must also support ASHRAE 135-2016,
    otherwise it will ignore us, and that's a sad thing to do! As such, sending large APDUs is opt-in.

    It can act as a master or slave node, depending on the address this transport is started with.
    As a slave node, it'll only be able to respond to request and never be able to initiate requests.
    Master nodes actively participate in the Token Passing and are able to send MS/TP frames freely
    when holding the token. Slave nodes are restricted to only responding to requests and also are
    not able to use segmentation, since segmentation requires nodes to be able to send MS/TP frames
    whenever needed.

    The recommendation is to always start this transport as master node with a distinct and
    unique address in the range `0..127`. Note that other MS/TP nodes `max_master_address`
    needs to be considered when selecting an address.

    Proprietary frames are sent to the defined `callback` as:

    ```elixir
    {:proprietary, {type :: 128..255, vendor_id :: 0..65_535}, destination :: destination_address(), data :: iodata()}
    ```
    As defined by `t:BACnet.Stack.TransportBehaviour.transport_cb_frame/0`.

    It uses `Circuits.UART` to handle RS485 for us in active mode.
    If you want to use this transport, you'll have to add [`:circuits_uart`](https://hex.pm/packages/circuits_uart)
    to your `mix.exs` as dependency! It is an optional dependency and thus
    by default not present when you install this library.

    ### Autobaud

    This transport implements automatically detecting the used baudrate by listening to the network ("autobaud").
    Once it detects a valid BACnet frame, the baudrate that detected the frame will be used and autobaud will be disabled.
    If there's no valid BACnet frame in a short time window (~5.5s) or an invalid frame is detected,
    then the next baudrate will be tried. It will go through all defined baudrates specified by the BACnet protocol.
    If no valid BACnet frame has been detected and all baudrates have been tested, the transport will fallback
    to baudrate `38_400` - a Logger warning will be issued.
    Autobaud can be manually re-enabled through `configure/2` - **note that all communication will be unrecoverable dropped**!

    The following baudrates will be tried in this order: 9600, 19_200, 38_400, 57_600, 76_800, 115_200.

    Autobaud can be used by specifying `baudrate: :auto` when starting the transport (recommended way to use autobaud).
    Autobaud can also be manually enabled through `configure/2` - but communication is disruptive and thus not recommended.

    > #### Empty Network {: .warning}
    >
    > Autobaud requires at least one active device on the MS/TP network!
    > If there are no active devices (other than itself) on the network,
    > it will fail to detect the baudrate and fallback to the default.

    ### Logger warning spam due to bad data/devices/network

    This section is only relevant if you're working on this project or have bacstack debugging enabled.

    If you have bad devices or the MS/TP network has some physical troubles and
    the received data is invalid (CRC mismatch), then the specific module used
    for the receive state machine will log warnings.
    You may want to silence those, if you are not interested in those.

    You can do this at runtime using

    ```elixir
    Logger.put_module_level(BACnet.Stack.Transport.MstpTransport.ReceiveFSM, :error)
    ```

    or using the `config.exs` (purging at compile time):

    ```elixir
    config :logger,
      compile_time_purge_matching: [
        [
          level_lower_than: :error,
          module: BACnet.Stack.Transport.MstpTransport.ReceiveFSM
        ]
      ]
    ```

    Note that this will also remove info or debugging output (`log_communication_rcv` option of this transport).
    """

    # TODO: Convert Master Node FSM to :gen_statem?

    # For testing we can use `socat -d -d pty,rawer,echo=0 pty,rawer,echo=0` in the future
    # Output will contain two lines of `N PTY is /dev/pts/{number}` with can then be opened
    # using Circuits.UART.open(pid, "/dev/pts/{number}")

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

    @mstp_start_byte 0x55
    @mstp_preamble_byte 0xFF

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

    @autobaud_timeout_timer 5500
    @autobaud_default_baudrates [9600, 19_200, 38_400, 57_600, 76_800, 115_200]

    # The number of tokens received or used before a Poll For Master cycle is executed
    @param_n_poll 50

    # The number of retries on sending Token
    @param_n_retry_token 1

    # The minimum number of DataAvailable or ReceiveError events that must be seen by a receiving node
    # in order to declare the line "active"
    @param_n_min_octets 4

    # The maximum idle time a sending node may allow to elapse between octets of a frame the node is transmitting
    # Unit: Bit times
    # @param_t_frame_gap 20

    # The time without a DataAvailable or ReceiveError event before declaration of loss of token
    # Unit: ms
    @param_t_no_token 500

    # The maximum time after the end of the stop bit of the final octet of a transmitted frame before
    # a node must disable its EIA-485 drive
    # Unit: Bit times
    # @param_t_postdrive 15

    # The maximum time a node may wait after reception of a frame that expects a reply before
    # sending the first octet of a reply or Reply Postponed frame
    # Unit: ms
    @param_t_reply_delay 250

    # The minimum time without a DataAvailable or ReceiveError event that a node must wait for a station
    # to begin replying to a confirmed request
    # (Implementations may use larger values for this timeout, not to exceed 300 milliseconds)
    # Unit: ms
    # Default: 255
    @param_t_reply_timeout 280

    # The width of the time slot within which a node may generate a token
    # Unit: ms
    @param_t_slot 10

    # The minimum time after the end of the stop bit of the final octet of a received frame
    # before a node may enable its EIA-485 driver.
    # Unit: Bit times
    @param_t_turnaround 40

    # The maximum time a node may wait after reception of the token or a Poll For Master frame before
    # sending the first octet of a frame
    # Unit: ms
    # @param_t_usage 15

    # The minimum time without a DataAvailable or ReceiveError event that a node must wait for a remote node to
    # begin using a token or replying to a Poll For Master frame
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
              | :autobaud_detection

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
              disable_maintenance_pfm: boolean(),
              disable_token_passing: boolean(),
              autobaud_baudrate: non_neg_integer() | nil,
              autobaud_baudrates_pending: [non_neg_integer()] | nil,
              autobaud_timer: term() | nil,
              opts: %{
                baudrate: non_neg_integer() | :auto,
                local_address: 0..254,
                log_communication: boolean(),
                max_info_frames: pos_integer(),
                max_master_address: 1..127,
                port_name: binary(),
                supervisor: Supervisor.supervisor()
              },
              statistics: %{
                previous_state: master_state() | slave_state(),
                states: %{optional(master_state() | slave_state()) => non_neg_integer()},
                received: %{
                  optional(:invalid_frame) => non_neg_integer(),
                  optional(MstpTransport.frame_type()) => non_neg_integer()
                },
                sent: %{
                  optional(MstpTransport.frame_type()) => non_neg_integer()
                }
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
        :disable_maintenance_pfm,
        :disable_token_passing,
        :autobaud_baudrate,
        :autobaud_baudrates_pending,
        :autobaud_timer,
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
            {:baudrate, non_neg_integer() | :auto}
            | {:local_address, source_address()}
            | {:log_communication, boolean()}
            | {:log_communication_rcv, boolean()}
            | {:max_info_frames, pos_integer()}
            | {:max_master_address, 1..127}
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
    Get the maximum extended APDU length for this transport,
    if the transport also supports a higher (extended) APDU.
    """
    @spec max_ext_apdu_length() :: pos_integer()
    def max_ext_apdu_length(), do: @max_apdu_extended

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
    Get the maximum extended NPDU length for this transport,
    if the transport also supports a higher (extended) NPDU.

    The NPDU length contains the maximum transmittable size
    of the NPDU, including the APDU, without violating
    the maximum transmission unit of the underlying transport.

    Any necessary transport header (i.e. BVLL, LLC) must have
    been taken into account when calculating this number.
    """
    @spec max_ext_npdu_length() :: pos_integer()
    def max_ext_npdu_length(), do: @max_apdu_extended

    @doc """
    Opens/starts the Transport module. A process is started, that is linked to the caller process.

    See the `BACnet.Stack.TransportBehaviour` documentation for more information.

    In the case of this BACnet MS/TP transport, the transport PID/port is a `GenServer` receiving and sending
    RS485 data. The portal is the same transport PID/port, as access to the MS/TP network must be coordinated.

    This transport takes the following options, in addition to `t:GenServer.options/0`:
    - `baudrate: non_neg_integer | :auto` - Optional. The baud rate to use (defaults to `38400`).
      See the module documentation regarding the autobaud feature.
    - `local_address: source_address()` - Required. The address to use - must be unique in the BACnet MS/TP network.
      Addresses 0-127 are for master nodes, while 128-254 are for slave nodes.
    - `log_communication: boolean()` - Optional. Logs all communication (debug), excluding receive states.
    - `log_communication_rcv: boolean()` - Optional. Logs all communication (debug) of receive states.
    - `max_info_frames: pos_integer()` - Optional. This value specifies the maximum number of information
      frames the node may send before it must pass the token (defaults to `1`).
    - `max_master_address: 1..127` - Optional. The maximum master address that is used in the MS/TP network.
      This is used for polling and successor determination (defaults to `127`).
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

      validate_open_opts(opts2, "open/2", false)

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
    Get the current transport state.

    This function is important when disabling token passing and
    waiting for the transport to transition to the IDLE or NO_TOKEN state,
    to then be able to shut down the transport gracefully.

    See also `disable_token_passing/1`.
    """
    @spec get_state(TransportBehaviour.transport()) :: :idle | :no_token | atom()
    def get_state(transport) when is_server(transport) do
      GenServer.call(transport, :get_state)
    end

    @doc """
    Get the current active baudrate.

    `{:auto, non_neg_integer()}` is returned during autobaud detection,
    when it has not finished yet. The contained number is the current active baudrate.
    Once autobaud detection finishes, this function will return a plain number
    with the current active baudrate.
    """
    @spec get_baudrate(TransportBehaviour.transport()) ::
            non_neg_integer() | {:auto, non_neg_integer()}
    def get_baudrate(transport) when is_server(transport) do
      GenServer.call(transport, :get_baudrate)
    end

    @doc """
    Disables the transport's token passing (only if master node).

    Disabling the token passing will try to pass on the token, if held,
    as soon as possible, but only if the successor is known.
    If the successor is unknown or a timeout occurrs, the token will be dropped.
    The consequence of dropping the token will be that the remaining
    MS/TP master nodes will notice the lost token and generate a new token.

    Whether it transitions to IDLE or NO_TOKEN state depends on
    its current state and could even change later on from IDLE to NO_TOKEN.
    Once the transport reaches IDLE or NO_TOKEN, the transport can be
    safely shut down.

    When the token passing is disabled, sending any frame that does not
    involve sending a reply is disabled and return an error.

    After disabling the transport token passing, it can only be re-enabled
    by restarting the transport.
    """
    @spec disable_token_passing(TransportBehaviour.transport()) :: :ok | {:error, term()}
    def disable_token_passing(transport) when is_server(transport) do
      GenServer.call(transport, :disable_token_passing)
    end

    @doc """
    Configures the transport.

    Only some of the available `t:open_options/0` can be configured,
    unsupported options can only be changed by re-starting the transport completely.

    The following options are supported:
    - `baudrate`
    - `log_communication`
    - `log_communication_rcv`
    - `max_info_frames`
    - `max_master_address`

    For a description of each option, see `open/2`.

    Note that reconfiguring the baudrate on the fly MAY lead to invalid frames!
    May also lead to dropping token.
    """
    @spec configure(TransportBehaviour.transport(), open_options()) :: :ok | {:error, term()}
    def configure(transport, opts) when is_server(transport) and is_list(opts) do
      unless Keyword.keyword?(opts) do
        raise ArgumentError, "configure/2 expected a keyword list, got: #{inspect(opts)}"
      end

      validate_open_opts(opts, "configure/2", true)

      Enum.each(opts, fn
        # Supported options
        {key, _val}
        when key in [
               :baudrate,
               :log_communication,
               :log_communication_rcv,
               :max_info_frames,
               :max_master_address
             ] ->
          true

        {key, _val} ->
          raise ArgumentError,
                "configure/2 does not support option " <> inspect(key)
      end)

      GenServer.call(transport, {:configure, Map.new(opts)})
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

    Returns true for any non-valid `destination_address()`, because they need
    to be routed by a BACnet router residing on this transport layer/network.
    """
    @spec destination_routed?(GenServer.server(), destination_address() | term()) ::
            boolean()
    def destination_routed?(transport, destination) when is_server(transport) do
      not valid_destination?(destination)
    end

    @doc """
    Verifies whether the given destination is valid for the transport module.
    """
    @spec valid_destination?(destination_address() | term()) :: boolean()
    def valid_destination?(destination) do
      is_integer(destination) and destination >= 0 and destination <= 255
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
    # credo:disable-for-lines:50 Credo.Check.Refactor.CyclomaticComplexity
    @spec send(
            GenServer.server(),
            destination_address(),
            EncoderProtocol.t() | iodata(),
            send_options()
          ) ::
            :ok | {:error, term()} | {:error, :slave_mode} | {:error, :token_passing_disabled}
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
            if not EncoderProtocol.request?(data) do
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
    @spec send_test(TransportBehaviour.portal(), source_address(), iodata()) ::
            {:ok, iodata()}
            | {:error, term()}
            | {:error, :invalid_frame_response}
            | {:error, :slave_mode}
            | {:error, :token_passing_disabled}
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
    Sends a Reply-Postponed Frame to the destination.

    Sending an explicit Reply-Postponed Frame is necessary,
    when the reply is to be segmented.
    A segmented Complex-ACK APDU can only be transmitted
    when we hold the token (ASHRAE 135 Clause 9.8).

    There are no options at this time.
    """
    @spec reply_postponed(TransportBehaviour.portal(), source_address(), Keyword.t()) ::
            :ok
            | {:error, term()}
            | {:error, :slave_mode}
            | {:error, :no_reply_pending}
            | {:error, :destination_is_not_expecting_reply}
    def reply_postponed(portal, destination, opts \\ [])
        when is_server(portal) and is_integer(destination) and destination >= 0 and
               destination <= 254 and is_list(opts) do
      GenServer.call(portal, {:reply_postponed, destination, opts}, @call_timeout)
    end

    @doc """
    Enables or disables maintenance POLL_FOR_MASTER in the case the successor node is known.
    If the successor node is unknown, POLL_FOR_MASTER will be regardless done.

    This function is only for development and testing purpose. It must not be used in production.
    Periodic maintenance polling for masters is required to find new nodes in between this node
    and the next current successor node. Nodes may come up and go down any time, which
    the BACnet specification accounts for and thus includes a POLL_FOR_MASTER mechanism.
    """
    @spec set_maintenance_pfm(TransportBehaviour.transport(), boolean()) :: :ok
    def set_maintenance_pfm(transport, state) when is_server(transport) and is_boolean(state) do
      GenServer.call(transport, {:disable_maintenance_pfm, not state})
    end

    @doc false
    def init({callback, opts}) do
      new_opts =
        opts
        |> Map.put_new(:baudrate, 38_400)
        |> Map.put_new(:log_communication, false)
        |> Map.put_new(:max_info_frames, 1)
        |> Map.put_new(:max_master_address, @max_master_addr)
        |> Map.put_new(:supervisor, nil)

      # We only make sure we have a valid baudrate in case of autobaud
      baudrate =
        if new_opts.baudrate == :auto do
          [baudrate | _rest] = @autobaud_default_baudrates
          baudrate
        else
          new_opts.baudrate
        end

      result =
        with {:ok, uart_pid} <- UART.start_link() do
          {UART.open(uart_pid, Map.fetch!(opts, :port_name),
             active: true,
             speed: baudrate,
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
                disable_maintenance_pfm: false,
                disable_token_passing: false,
                autobaud_baudrate: nil,
                autobaud_baudrates_pending: nil,
                autobaud_timer: nil,
                opts: new_opts,
                statistics: %{
                  previous_state: :initialize,
                  states: %{},
                  received: %{},
                  sent: %{}
                }
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
    def handle_continue(arg, %State{} = state) do
      arg
      |> do_handle_continue(state)
      |> update_state_statistics()
    end

    defp do_handle_continue(
           :initialize,
           %State{opts: %{baudrate: :auto}} = state
         ) do
      # This is the initialize phase for auto baudrate -
      # once we find the correct baudrate, the transport state gets resetted to :initialize
      # and the real initialize phase gets called and executed

      # Get first baudrate and "queue" the rest as pending
      [baudrate | rest] = @autobaud_default_baudrates

      # Cancel silence timer (necessary when autobaud-ing after transport started up)
      state = state_cancel_silence_timer(state)

      # Update transport state - that isn't done automatically
      state = %{state | transport_state: :autobaud_detection}

      autobaud_switch_baudrate(state, baudrate, rest, true)
    end

    defp do_handle_continue(
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

    defp do_handle_continue(
           :initialize,
           %State{local_address: local_addr, state_machine: state_machine} = state
         ) do
      # Initialize slave node
      {:noreply,
       %{state | state_machine: %{state_machine | ts: local_addr}, transport_state: :idle}}
    end

    defp do_handle_continue(
           :use_token,
           %State{
             local_address: local_addr,
             state_machine: state_machine,
             disable_token_passing: true
           } = state
         )
         when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Reached state USE_TOKEN, but token passing is disabled, " <>
          "switching to DONE_WITH_TOKEN"
      end)

      {:noreply,
       %{
         state
         | state_machine: %{state_machine | frame_count: state.opts.max_info_frames},
           transport_state: :done_with_token
       }, {:continue, :done_with_token}}
    end

    # We received a TOKEN frame, which hands us over the token, so enter USE_TOKEN state
    defp do_handle_continue(
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
    defp do_handle_continue(
           :done_with_token,
           %State{
             local_address: local_addr,
             state_machine: %{frame_count: frame_count},
             disable_token_passing: false,
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

    defp do_handle_continue(
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

    defp do_handle_continue(
           :done_with_token,
           %State{
             local_address: local_addr,
             disable_token_passing: false,
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

    defp do_handle_continue(
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

    defp do_handle_continue(
           :done_with_token,
           %State{
             local_address: local_addr,
             disable_maintenance_pfm: true,
             disable_token_passing: false,
             state_machine: %{ns: ns, ps: ps, ts: ts, token_count: tokens} = state_machine
           } =
             state
         )
         when local_addr < @min_slave_addr and
                ns != rem(ps + 1, state.opts.max_master_address + 1) and
                ns != ts and
                tokens >= @param_n_poll - 1 do
      log_debug(fn ->
        "BacMstpTransport: Reached state DONE_WITH_TOKEN and skipping maintenance POLL_FOR_MASTER, " <>
          "skipping to USE_TOKEN instead (maintenance PFM disabled)"
      end)

      new_state = %{
        state
        | state_machine: %{state_machine | frame_count: 0, token_count: 0},
          transport_state: :use_token
      }

      {:noreply, new_state, {:continue, :use_token}}
    end

    # If token passing is disabled, do not engage maintenance PFM, instead:
    # - If successor known, pass it to the successor
    # - If successor unknown, drop the token
    defp do_handle_continue(
           :done_with_token,
           %State{
             local_address: local_addr,
             disable_token_passing: false,
             state_machine: %{ns: ns, ps: ps, token_count: tokens} = state_machine
           } =
             state
         )
         when local_addr < @min_slave_addr and
                ns != rem(ps + 1, state.opts.max_master_address + 1) and
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

    defp do_handle_continue(
           :done_with_token,
           %State{
             local_address: local_addr,
             state_machine:
               %{sole_master: false, ns: ns, ps: ps, token_count: tokens} = state_machine
           } =
             state
         )
         when local_addr < @min_slave_addr and
                ns == rem(ps + 1, state.opts.max_master_address + 1) and
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

    defp do_handle_continue(
           :done_with_token,
           %State{local_address: local_addr, disable_token_passing: true} = state
         )
         when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Reached state DONE_WITH_TOKEN with disabled token passing, " <>
          "but successor is unknown - dropping the token as action"
      end)

      new_state = %{
        state
        | transport_state: :no_token
      }

      {:noreply, new_state}
    end

    defp do_handle_continue(
           :done_with_token,
           %State{
             local_address: local_addr,
             state_machine:
               %{sole_master: true, ns: ns, ps: ps, token_count: tokens} = state_machine
           } =
             state
         )
         when local_addr < @min_slave_addr and
                ns == rem(ps + 1, state.opts.max_master_address + 1) and
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
    def handle_call(arg, from, %State{} = state) do
      arg
      |> do_handle_call(from, state)
      |> update_state_statistics()
    end

    defp do_handle_call(:close, _from, %State{} = state) do
      log_debug("BacMstpTransport: Received close request")

      ReceiveFSM.close(state.receive_fsm)
      UART.close(state.uart_pid)

      {:stop, :normal, :ok, state}
    end

    defp do_handle_call(:get_state, _from, %State{} = state) do
      log_debug(fn ->
        "BacMstpTransport: Received get_state request"
      end)

      {:reply, state.transport_state, state}
    end

    defp do_handle_call(:get_baudrate, _from, %State{} = state) do
      log_debug(fn ->
        "BacMstpTransport: Received get_baudrate request"
      end)

      baud =
        case state.opts.baudrate do
          :auto -> {:auto, state.autobaud_baudrate}
          int -> int
        end

      {:reply, baud, state}
    end

    defp do_handle_call(:disable_token_passing, _from, %State{local_address: local_addr} = state)
         when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Received disable_token_passing request during state " <>
          String.upcase(Atom.to_string(state.transport_state))
      end)

      new_state = %{state | disable_token_passing: true}

      {:reply, :ok, new_state}
    end

    defp do_handle_call(:disable_token_passing, _from, %State{} = state) do
      log_debug(fn ->
        "BacMstpTransport: Received disable_token_passing reques in slave_mode"
      end)

      {:reply, {:error, :slave_mode}, state}
    end

    defp do_handle_call({:configure, %{} = opts}, _from, %State{} = state) do
      log_debug(fn -> "BacMstpTransport: Received configure request" end)

      new_opts = Map.merge(state.opts, opts)

      reply =
        case Map.fetch(opts, :baudrate) do
          {:ok, :auto} ->
            :auto

          {:ok, baudrate} ->
            with :ok <- UART.configure(state.uart_pid, speed: baudrate) do
              ReceiveFSM.configure(state.receive_fsm, %{
                autobaud: false,
                baudrate: baudrate,
                log_communication: new_opts.log_communication_rcv
              })
            end

          :error ->
            :ok
        end

      case reply do
        :ok ->
          # Cancel lingering timer
          if state.autobaud_timer do
            Process.cancel_timer(state.autobaud_timer)

            # Clear messagebox
            receive do
              :autobaud_timer -> :ok
            after
              0 -> :ok
            end
          end

          new_trans_state =
            if state.transport_state == :autobaud_detection do
              :idle
            else
              state.transport_state
            end

          new_state = %{
            state
            | transport_state: new_trans_state,
              autobaud_baudrate: nil,
              autobaud_baudrates_pending: nil,
              autobaud_timer: nil,
              opts: new_opts
          }

          if state.transport_state == :autobaud_detection do
            {:reply, :ok, new_state, {:continue, :initialize}}
          else
            {:reply, :ok, new_state}
          end

        :auto ->
          # Cancel any pending silence timers when switching to AUTOBAUD
          state = state_cancel_silence_timer(state)

          new_state = %{state | transport_state: :autobaud_detection, opts: new_opts}

          # Switch to AUTOBAUD_DETECTION state and let initialize continue callback do the rest
          {:reply, :ok, new_state, {:continue, :initialize}}

        _other ->
          {:reply, reply, state}
      end
    end

    defp do_handle_call(:get_local_address, _from, %State{} = state) do
      log_debug("BacMstpTransport: Received get_local_address request")

      {:reply, state.local_address, state}
    end

    defp do_handle_call(
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
          %{state | transport_state: :idle, answer_invoke_id: nil},
          destination,
          data
        )

      {:reply, reply, new_state}
    end

    defp do_handle_call(
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

    defp do_handle_call(
           {:send, _destination, _send_and_wait, _data, _data_length, _invoke_id},
           _from,
           %State{local_address: local_addr, disable_token_passing: true} = state
         )
         when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Received send request while token passing is disabled"
      end)

      {:reply, {:error, :token_passing_disabled}, state}
    end

    defp do_handle_call(
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

    defp do_handle_call(
           {:send, _destination, _send_and_wait, _data, _data_length, _invoke_id},
           _from,
           %State{} = state
         ) do
      log_debug(fn ->
        "BacMstpTransport: Received send request in slave mode"
      end)

      {:reply, {:error, :slave_mode}, state}
    end

    defp do_handle_call(
           {:send_test, _destination, _data},
           _from,
           %State{local_address: local_addr, disable_token_passing: true} = state
         )
         when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Received send_test request while token passing is disabled"
      end)

      {:reply, {:error, :token_passing_disabled}, state}
    end

    defp do_handle_call(
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

    defp do_handle_call(
           {:send_test, _destination, _data},
           _from,
           %State{} = state
         ) do
      log_debug(fn ->
        "BacMstpTransport: Received send_test request in slave mode"
      end)

      {:reply, {:error, :slave_mode}, state}
    end

    defp do_handle_call(
           {:reply_postponed, destination, _opts},
           _from,
           %State{local_address: local_addr, state_machine: %{source_address: source}} = state
         )
         when local_addr < @min_slave_addr do
      log_debug(fn ->
        "BacMstpTransport: Received reply_postponed request"
      end)

      {reply, new_state} =
        cond do
          source != destination ->
            {{:error, :destination_is_not_expecting_reply}, state}

          state.transport_state == :answer_data_request ->
            # Remove the reply timer
            state = state_cancel_silence_timer(state)
            state = state_set_silence_timer(state, :timer_lost_token, @param_t_no_token)

            case send_frame_reply_postponed(state, destination) do
              {:ok, state} -> {:ok, %{state | transport_state: :idle, answer_invoke_id: nil}}
              {:error, state} -> {{:error, :sending_failed}, state}
            end

          true ->
            {{:error, :no_reply_pending}, state}
        end

      {:reply, reply, new_state}
    end

    defp do_handle_call({:reply_postponed, _destination, _opts}, _from, %State{} = state) do
      log_debug(fn ->
        "BacMstpTransport: Received reply_postponed request in slave mode"
      end)

      {:reply, {:error, :slave_mode}, state}
    end

    defp do_handle_call({:disable_maintenance_pfm, pfm_state}, _from, %State{} = state)
         when is_boolean(pfm_state) do
      log_debug(fn ->
        "BacMstpTransport: Received disable_maintenance_pfm request with " <>
          "value #{pfm_state}"
      end)

      {:reply, :ok, %{state | disable_maintenance_pfm: pfm_state}}
    end

    defp do_handle_call(_call, _from, state) do
      {:noreply, state}
    end

    @doc false
    def handle_cast(_cast, %State{} = state) do
      {:noreply, state}
    end

    @doc false
    def handle_info(arg, %State{} = state) do
      arg
      |> do_handle_info(state)
      |> update_state_statistics()
    end

    defp do_handle_info({:serial_crash, reason}, %State{} = state) do
      # This message is either sent by ReceiveFSM or when writing UART fails
      Logger.error(fn ->
        "BacMstpTransport: UART error encountered and shutting down, error: " <> inspect(reason)
      end)

      # Stop everything
      ReceiveFSM.close(state.receive_fsm)
      UART.close(state.uart_pid)

      exit({:uart_error, reason})
    end

    defp do_handle_info(:wakeup_use_token, %State{} = state) do
      {:noreply, state, {:continue, :use_token}}
    end

    defp do_handle_info(
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

    defp do_handle_info(
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

    defp do_handle_info(
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

    defp do_handle_info(
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

    defp do_handle_info(
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

    defp do_handle_info(
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

    defp do_handle_info(
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

    defp do_handle_info(
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
      # (Because of the length of the timeout, this transition will cause the token to be passed
      #  regardless of the initial value of FrameCount)
      {:noreply,
       state_cancel_silence_timer(%{
         state
         | active_test: nil,
           state_machine: %{state_machine | frame_count: state.opts.max_info_frames},
           transport_state: :done_with_token
       }), {:continue, :done_with_token}}
    end

    defp do_handle_info(:timer_rcv_timeout, %State{disable_token_passing: true} = state) do
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message while token passing is disabled, " <>
          "if we were holding the token, we will drop it now"
      end)

      state = state_clear_silence_timer(state)
      new_state = %{state | transport_state: :no_token}

      {:noreply, new_state}
    end

    defp do_handle_info(
           :timer_rcv_timeout,
           %State{} = state
         ) do
      log_debug(fn ->
        "BacMstpTransport: Received receive timeout timer message at state " <>
          String.upcase(Atom.to_string(state.transport_state))
      end)

      {:noreply, state_cancel_silence_timer(state)}
    end

    defp do_handle_info(:timer_lost_token, %State{disable_token_passing: true} = state) do
      log_debug(fn ->
        "BacMstpTransport: Received lost token timer message while token passing is disabled, " <>
          "ignoring it and transitioning to NO_TOKEN"
      end)

      state = state_clear_silence_timer(state)
      new_state = %{state | transport_state: :no_token}

      {:noreply, new_state}
    end

    # LostToken can only be in effect during state IDLE (and if not sole master)
    defp do_handle_info(
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
         {:timer_generate_token, System.monotonic_time(:millisecond)},
         max(trunc(@param_t_slot * state.state_machine.ts), 0)
       )}
    end

    # This message is sent by the ReceiveFSM
    # As slave, we ignore this
    defp do_handle_info(
           :timer_lost_token,
           %State{} = state
         ),
         do: {:noreply, state_clear_silence_timer(state)}

    defp do_handle_info(
           {:timer_generate_token, _ts_offset},
           %State{disable_token_passing: true} = state
         ) do
      log_debug(fn ->
        "BacMstpTransport: Received generate token timer message while token passing is disabled, " <>
          "ignoring it and continue staying in NO_TOKEN state"
      end)

      state = state_clear_silence_timer(state)
      {:noreply, state}
    end

    defp do_handle_info(
           {:timer_generate_token, ts_offset},
           %State{state_machine: state_machine, transport_state: :no_token} = state
         ) do
      log_debug(fn ->
        "BacMstpTransport: Received generate token timer message"
      end)

      # Assert timer was received BEFORE the next station would generate a new token
      if System.monotonic_time(:millisecond) - ts_offset <
           @param_t_slot * (state.state_machine.ts + 1) do
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
      else
        # Timer was received AFTER our timeslot -> the next station generates a new token
        {:noreply,
         state_set_silence_timer(
           %{state | transport_state: :idle},
           :timer_lost_token,
           @param_t_no_token
         )}
      end
    end

    defp do_handle_info(
           {:timer_retry_token_handoff, _ns},
           %State{
             state_machine: state_machine,
             transport_state: :pass_token,
             disable_token_passing: true
           } = state
         ) do
      log_debug(fn ->
        "BacMstpTransport: Received retry token handoff timer message during token passing is disabled, " <>
          "ignoring it, if we are holding the token, it will be dropped and transitioning to NO_TOKEN state"
      end)

      state =
        state_clear_silence_timer(%{state | state_machine: %{state_machine | retry_count: -1}})

      new_state = %{state | transport_state: :no_token}

      {:noreply, new_state}
    end

    defp do_handle_info(
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

    defp do_handle_info(
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

    defp do_handle_info(
           :received_valid_frame_autobaud,
           %State{transport_state: :autobaud_detection} = state
         ) do
      log_debug(fn ->
        "BacMstpTransport: Received received_valid_frame_autobaud message from MS/TP Receive FSM, " <>
          "we found a valid frame at baudrate #{state.autobaud_baudrate}"
      end)

      Logger.info(fn ->
        "BacMstpTransport: Autobaud selected baudrate #{state.autobaud_baudrate}"
      end)

      # Cancel lingering timer
      if state.autobaud_timer do
        Process.cancel_timer(state.autobaud_timer)

        # Clear messagebox
        receive do
          :autobaud_timer -> :ok
        after
          0 -> :ok
        end
      end

      new_state = %{
        state
        | transport_state: :initialize,
          autobaud_baudrate: nil,
          autobaud_baudrates_pending: nil,
          autobaud_timer: nil,
          opts: %{state.opts | baudrate: state.autobaud_baudrate}
      }

      ReceiveFSM.configure(state.receive_fsm, autobaud: false, baudrate: new_state.opts.baudrate)

      # Now that we've found the correct baudrate, initialize the node fully
      {:noreply, new_state, {:continue, :initialize}}
    end

    defp do_handle_info(
           :received_invalid_frame,
           %State{transport_state: :autobaud_detection, autobaud_baudrates_pending: []} = state
         ) do
      log_debug(fn ->
        "BacMstpTransport: Received received_invalid_frame message from MS/TP Receive FSM " <>
          "during autobaud detection phase"
      end)

      Logger.warning(fn ->
        "BacMstpTransport: Autobaud failed to discover baudrate - defaulting to 38_400 baudrate"
      end)

      case autobaud_switch_baudrate(state, 38_400, [], false) do
        {:noreply, new_state} ->
          {:noreply,
           %{new_state | transport_state: :idle, opts: %{state.opts | baudrate: 38_400}},
           {:continue, :initialize}}

        other ->
          other
      end
    end

    defp do_handle_info(
           :received_invalid_frame,
           %State{transport_state: :autobaud_detection} = state
         ) do
      [new_baudrate | rest] = state.autobaud_baudrates_pending

      log_debug(fn ->
        "BacMstpTransport: Received received_invalid_frame message from MS/TP Receive FSM " <>
          "during autobaud detection phase, changing baudrate from #{state.autobaud_baudrate} " <>
          "to #{new_baudrate}"
      end)

      autobaud_switch_baudrate(state, new_baudrate, rest, true)
    end

    defp do_handle_info(:received_invalid_frame, %State{} = state) do
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

      # If a test is active, resolve it with an error
      new_state =
        if state.active_test do
          GenServer.reply(state.active_test, {:error, :invalid_frame_response})

          %{new_state | active_test: nil}
        else
          new_state
        end

      # Update received frame counter
      new_state = update_received_statistics(:invalid_frame, new_state)

      {:noreply, new_state}
      |> handle_maybe_poll_for_master_invalid_frame()
      |> handle_maybe_wait_for_reply_invalid_frame()
    end

    # During ANSWER_DATA_REQUEST state we MUST NOT receive any data,
    # no one should be sending any data anyway and instead wait for our answer
    # (The actual answer or REPLY_POSTPONED frame)
    defp do_handle_info(
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

      # Update received frame counter
      state = update_received_statistics(data.frame_type, state)

      {:noreply, state}
    end

    defp do_handle_info(
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

      # Update received frame counter
      new_state = update_received_statistics(data.frame_type, new_state)

      {:noreply, new_state}
    end

    defp do_handle_info(
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

      # Update received frame counter
      state = update_received_statistics(data.frame_type, state)

      handle_mstp_frame(state, data)
    end

    defp do_handle_info({:received_data, data_length}, %State{} = state) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received received_data message from MS/TP Receive FSM"
      end)

      # state = %{
      #   state
      #   | statistics:
      #       Map.put(state.statistics, :rcv_timestamp, System.monotonic_time(:microsecond))
      # }

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

    defp do_handle_info(
           :autobaud_timer,
           %State{transport_state: :autobaud_detection, autobaud_baudrates_pending: []} = state
         ) do
      log_debug(fn -> "BacMstpTransport: Received autobaud_timer timer message" end)

      Logger.warning(fn ->
        "BacMstpTransport: Autobaud failed to discover baudrate - defaulting to 38_400 baudrate"
      end)

      case autobaud_switch_baudrate(state, 38_400, [], false) do
        {:noreply, new_state} ->
          {:noreply,
           %{new_state | transport_state: :idle, opts: %{state.opts | baudrate: 38_400}},
           {:continue, :initialize}}

        other ->
          other
      end
    end

    defp do_handle_info(:autobaud_timer, %State{transport_state: :autobaud_detection} = state) do
      [new_baudrate | rest] = state.autobaud_baudrates_pending

      log_debug(fn ->
        "BacMstpTransport: Received autobaud_timer timer message, " <>
          "changing baudrate from #{state.autobaud_baudrate} " <>
          "to #{new_baudrate}"
      end)

      autobaud_switch_baudrate(state, new_baudrate, rest, true)
    end

    defp do_handle_info(_info, state) do
      {:noreply, state}
    end

    @spec autobaud_switch_baudrate(
            State.t(),
            non_neg_integer(),
            [non_neg_integer()],
            boolean()
          ) :: {:noreply, State.t()} | {:stop, term(), State.t()}
    defp autobaud_switch_baudrate(
           %State{} = state,
           new_baudrate,
           pending_baudrates,
           new_timer
         )
         when is_integer(new_baudrate) and is_list(pending_baudrates) and is_boolean(new_timer) do
      # Cancel lingering timer
      if state.autobaud_timer do
        Process.cancel_timer(state.autobaud_timer)

        # Clear messagebox
        receive do
          :autobaud_timer -> :ok
        after
          0 -> :ok
        end
      end

      case UART.configure(state.uart_pid, speed: new_baudrate) do
        :ok ->
          ReceiveFSM.configure(state.receive_fsm, autobaud: new_timer, baudrate: new_baudrate)

          {:noreply,
           %{
             state
             | autobaud_baudrate: if(new_timer, do: new_baudrate),
               autobaud_baudrates_pending: if(new_timer, do: pending_baudrates),
               autobaud_timer:
                 if(new_timer,
                   do: Process.send_after(self(), :autobaud_timer, @autobaud_timeout_timer)
                 ),
               active_test: nil,
               answer_invoke_id: nil,
               send_queue: :queue.new(),
               send_timer: nil
           }}

        {:error, err} ->
          {:stop, {:uart_error_during_autobaud, err}, state}
      end
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

    # defp handle_mstp_frame(
    #        %State{local_address: addr} = state,
    #        %StateData{destination_address: dest, opts: %{listening_mode: true}} = state_data
    #      )
    #      when dest not in [addr, @broadcast_addr] do
    #   log_debug_comm(state, fn ->
    #     "BacMstpTransport: Received valid frame of type #{inspect(state_data.frame_type)} " <>
    #       "with data length " <> "#{state_data.data_length}, not meant for us but address #{dest}"
    #   end)

    #   case decode_packet(state_data) do
    #     {:ok, {npci, decoded}} ->
    #       after_decode_fanout_cb(
    #         state,
    #         state_data,
    #         {:apdu,
    #          if(state_data.destination_address == @broadcast_addr,
    #            do: :original_broadcast,
    #            else: :original_unicast
    #          ), npci, decoded}
    #       )

    #     # If the packet is not meant for us, ignore any other return value
    #     _other ->
    #       :ok
    #   end

    #   {:noreply, state}
    # end

    defp handle_mstp_frame(
           %State{local_address: addr, disable_token_passing: true} = state,
           %StateData{frame_type: :token, data_length: 0, destination_address: dest} = state_data
         )
         when addr <= @max_master_addr and dest != @broadcast_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type TOKEN with data length " <>
          "#{state_data.data_length} as master node, during token passing disabled, " <>
          "the frame will be ignored"
      end)

      {:noreply, state}
    end

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
           %State{local_address: addr} = state,
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
           %State{local_address: addr, disable_token_passing: true} = state,
           %StateData{frame_type: :poll_for_master, data_length: 0, destination_address: dest} =
             state_data
         )
         when addr <= @max_master_addr and dest != @broadcast_addr do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type POLL_FOR_MASTER with data length " <>
          "#{state_data.data_length} as master node, during token passing disabled, " <>
          "the frame will be ignored"
      end)

      {:noreply, state}
    end

    defp handle_mstp_frame(
           %State{local_address: addr} = state,
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

    defp handle_mstp_frame(%State{disable_token_passing: true} = state, %StateData{} = state_data) do
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received valid frame of type #{inspect(state_data.frame_type)} " <>
          "with data length #{state_data.data_length}, " <>
          "while token passing disabled, frame will be ignored"
      end)

      {:noreply, state}
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
          "#{state_data.data_length} and destination #{dest}"
      end)

      {vendor_id, buffer} =
        case state_data.input_buffer do
          <<vendor_id::size(16), rest::binary>> -> {vendor_id, rest}
          [b1, b2 | rest] -> {Bitwise.bsl(b1, 8) + b2, rest}
          _other -> {0, state_data.input_buffer}
        end

      after_decode_fanout_cb(
        state,
        state_data,
        {:proprietary, {type_num, vendor_id}, dest, buffer}
      )

      {:noreply, state}
    end

    defp handle_mstp_frame(%State{} = state, %StateData{} = state_data) do
      # This is a catch-all clause to handle all invalid frames (i.e. destination = broadcast and frame type = TOKEN)
      log_debug_comm(state, fn ->
        "BacMstpTransport: Received invalid frame of type #{inspect(state_data.frame_type)} with " <>
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
          after_decode_fanout_cb(
            state,
            state_data,
            {:apdu,
             if(state_data.destination_address == @broadcast_addr,
               do: :original_broadcast,
               else: :original_unicast
             ), npci, decoded}
          )

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
          after_decode_fanout_cb(
            state,
            state_data,
            {:apdu,
             if(state_data.destination_address == @broadcast_addr,
               do: :original_broadcast,
               else: :original_unicast
             ), npci, decoded}
          )

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

    # There are cases when an invalid frame needs to be explicitely handled to transit a state
    # (i.e. during POLL_FOR_MASTER)
    # Returns from handle_received_data/2 with a triple tuple are ignored, because they already do a transition
    @spec handle_maybe_poll_for_master_invalid_frame(
            {:noreply, State.t()}
            | {:noreply, State.t(), term()}
          ) :: {:noreply, State.t()} | {:noreply, State.t(), term()}
    defp handle_maybe_poll_for_master_invalid_frame(return)

    defp handle_maybe_poll_for_master_invalid_frame(
           {:noreply,
            %{
              disable_token_passing: false,
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
              disable_token_passing: false,
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
              disable_token_passing: false,
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
      crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
      payload = [@mstp_start_byte, @mstp_preamble_byte, header, crc]

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
      crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
      payload = [@mstp_start_byte, @mstp_preamble_byte, header, crc]

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
      crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
      payload = [@mstp_start_byte, @mstp_preamble_byte, header, crc]

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
      header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)

      data_payload =
        if data_len > 0 do
          # We need ones-complement of the DataCRC
          data_crc = 0xFFFF - EncodingTools.calculate_data_crc(data, 0xFFFF)

          [
            data,
            Bitwise.band(data_crc, 0xFF),
            Bitwise.bsr(data_crc, 8)
          ]
        else
          []
        end

      payload = [
        @mstp_start_byte,
        @mstp_preamble_byte,
        header,
        header_crc,
        data_payload
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
      header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)

      data_payload =
        if data_len > 0 do
          # We need ones-complement of the DataCRC
          # data_crc = 0xFFFF - EncodingTools.calculate_data_crc(data, 0xFFFF)

          # Use Data CRC from frame
          data_crc = state_data.data_crc_header

          [
            data,
            Bitwise.band(data_crc, 0xFF),
            Bitwise.bsr(data_crc, 8)
          ]
        else
          []
        end

      payload = [
        @mstp_start_byte,
        @mstp_preamble_byte,
        header,
        header_crc,
        data_payload
      ]

      send_uart_data(state, payload)
    end

    # Sends a BACnet-Data-Expecting-Reply Frame to destination
    @spec send_frame_data_expecting_reply(State.t(), destination_address(), iodata()) ::
            {:ok, State.t()} | {:error, State.t()}
    defp send_frame_data_expecting_reply(%State{} = state, destination, data) do
      data_len = IO.iodata_length(data)

      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending BACnet-Data-Expecting-Reply to MS/TP network " <>
          "with destination #{destination} " <>
          "and data length #{data_len} bytes"
      end)

      header = [5, destination, state.local_address, <<data_len::size(16)>>]
      header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)

      data_payload =
        if data_len > 0 do
          # We need ones-complement of the DataCRC
          data_crc = 0xFFFF - EncodingTools.calculate_data_crc(data, 0xFFFF)

          [
            data,
            Bitwise.band(data_crc, 0xFF),
            Bitwise.bsr(data_crc, 8)
          ]
        else
          []
        end

      payload = [
        @mstp_start_byte,
        @mstp_preamble_byte,
        header,
        header_crc,
        data_payload
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
      header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)

      data_payload =
        if data_len > 0 do
          # We need ones-complement of the DataCRC
          data_crc = 0xFFFF - EncodingTools.calculate_data_crc(data, 0xFFFF)

          [
            data,
            Bitwise.band(data_crc, 0xFF),
            Bitwise.bsr(data_crc, 8)
          ]
        else
          []
        end

      payload = [
        @mstp_start_byte,
        @mstp_preamble_byte,
        header,
        header_crc,
        data_payload
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
      crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
      payload = [@mstp_start_byte, @mstp_preamble_byte, header, crc]

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
          header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)

          payload = [@mstp_start_byte, @mstp_preamble_byte, header, header_crc, cobs_data]

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
          header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)

          payload = [@mstp_start_byte, @mstp_preamble_byte, header, header_crc, cobs_data]

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
      # Update statistics (calculate when we want to send data vs. when we received last data)
      # state = update_rcv_send_statistics(state)

      # ASHRAE 135 Clause 9.2.3
      # Receive to Transmit turn-around:
      # A node shall not enable its EIA-485 driver for at least Tturnaround
      # after the node receives the final stop bit of any octet
      state = sleep_send_uart_data(state)

      log_debug_comm(state, fn ->
        "BacMstpTransport: Sending data to MS/TP network with data length #{IO.iodata_length(data)}"
      end)

      # Update sent frame counter
      # We do this here, so frames sent "raw" are counted too
      state =
        case data do
          [@mstp_start_byte, @mstp_preamble_byte, [type | _rest] | _tail]
          when type in 0..255//1 ->
            update_sent_statistics(get_frametype(type), state)

          _else ->
            update_sent_statistics(:unknown, state)
        end

      # case data do
      #    [@mstp_start_byte, @mstp_preamble_byte, [type | _] | _] when type in [5, 6, 32, 33] ->
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

    @spec sleep_send_uart_data(State.t()) :: State.t()
    defp sleep_send_uart_data(%State{} = state) do
      # We should just always sleep the Tturnaround time
      # This is needed so devices can switch around from sending to receiving

      # At worst 4.2ms -> 5ms @9600kbit/s / 1.1ms -> 2ms @38_400kbit/s
      # See also comment in send_uart_data/2

      turnaround_time = calculate_bittimes_to_us(@param_t_turnaround, state)
      sleep_time = max(1, trunc(Float.ceil(turnaround_time / 1000)))

      log_debug_comm(state, fn ->
        "BacMstpTransport: Sleeping in send_uart_data/2 for #{sleep_time}ms (turnaround time: #{turnaround_time}us)"
      end)

      Process.sleep(sleep_time)
      state
    end

    # This is the version that uses the statistics to calculate
    # when we last received and then only sleeps as long as necessary
    # defp sleep_send_uart_data(%State{} = state) do
    #   case state.statistics.received_to_send do
    #     {_min, last, _max} ->
    #       wait_time =
    #         calculate_bittimes_to_us(@param_t_turnaround, state) - last

    #       # Wait if longer than 50us (that's really short and shouldn't be an issue,
    #       # since we have a delay between writing and actually writing due to UART Port implementation detail)
    #       if wait_time > 50 do
    #         sleep_time = max(1, trunc(wait_time / 1000))

    #         log_debug_comm(state, fn ->
    #           "BacMstpTransport: Sleeping in send_uart_data/2 for #{sleep_time}ms (wait time: #{wait_time}us)"
    #         end)

    #         Process.sleep(sleep_time)
    #       end

    #       receive do
    #         # Whoops! Collision? We received data on the serial while sleeping!
    #         {:received_data, data_length} ->
    #           # Call the message callback manually
    #           return = handle_info({:received_data, data_length}, state)
    #           %State{} = new_state = elem(return, 1)

    #           # Update received_to_send statistics, then check sleep again
    #           new_state = update_rcv_send_statistics(new_state)
    #           sleep_send_uart_data(new_state)
    #       after
    #         0 -> state
    #       end

    #     _other ->
    #       state
    #   end
    # end

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
              silence_timestamp: System.monotonic_time(:millisecond)
          }
      }
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

    # In dev/test environment we want to keep counters on received and sent frames
    # In prod this is unnecessary, so we just return the state as is
    @spec update_received_statistics(frame_type() | :invalid_frame, State.t()) :: State.t()
    @spec update_sent_statistics(frame_type(), State.t()) :: State.t()
    if Mix.env() in [:dev, :test] do
      defp update_received_statistics(type, %State{} = state)
           when is_atom(type) or
                  (is_tuple(type) and tuple_size(type) == 2 and elem(type, 0) == :proprietary and
                     is_integer(elem(type, 1))) do
        update_in(state, [Access.key(:statistics), :received, type], fn num ->
          (num || 0) + 1
        end)
      end

      # Ignore invalid types (dont let it crash us)
      defp update_received_statistics(_type, %State{} = state), do: state

      defp update_sent_statistics(type, %State{} = state)
           when is_atom(type) or
                  (is_tuple(type) and tuple_size(type) == 2 and elem(type, 0) == :proprietary and
                     is_integer(elem(type, 1))) do
        update_in(state, [Access.key(:statistics), :sent, type], fn num ->
          (num || 0) + 1
        end)
      end

      # Ignore invalid types (dont let it crash us)
      defp update_sent_statistics(_type, %State{} = state), do: state

      @spec update_state_statistics(var) :: var
            when var:
                   {atom(), State.t()}
                   | {atom(), term(), State.t()}
                   | {atom(), State.t(), term()}
                   | {atom(), term(), State.t(), term()}
      defp update_state_statistics(
             {_type, %State{statistics: %{previous_state: prev}, transport_state: now}} = return
           )
           when prev == now,
           do: return

      defp update_state_statistics({type, %State{transport_state: now} = state})
           when is_atom(type) do
        {type, update_state_statistics_map(state, now)}
      end

      defp update_state_statistics(
             {_type, _reply, %State{statistics: %{previous_state: prev}, transport_state: now}} =
               return
           )
           when prev == now,
           do: return

      defp update_state_statistics({type, reply, %State{transport_state: now} = state})
           when is_atom(type) do
        {type, reply, update_state_statistics_map(state, now)}
      end

      defp update_state_statistics(
             {_type, %State{statistics: %{previous_state: prev}, transport_state: now}, _cont} =
               return
           )
           when prev == now,
           do: return

      defp update_state_statistics({type, %State{transport_state: now} = state, cont})
           when is_atom(type) do
        {type, update_state_statistics_map(state, now), cont}
      end

      defp update_state_statistics(
             {_type, _reply, %State{statistics: %{previous_state: prev}, transport_state: now},
              _cont} = return
           )
           when prev == now,
           do: return

      defp update_state_statistics({type, reply, %State{transport_state: now} = state, cont})
           when is_atom(type) do
        {type, reply, update_state_statistics_map(state, now), cont}
      end

      # defp update_state_statistics(value), do: value

      @spec update_state_statistics_map(State.t(), atom()) :: State.t()
      defp update_state_statistics_map(%State{} = state, key) when is_atom(key) do
        state
        |> update_in([Access.key(:statistics), :states, key], fn
          nil -> 1
          counter -> counter + 1
        end)
        |> update_in([Access.key(:statistics), :previous_state], fn
          _old -> state.transport_state
        end)
      end
    else
      @compile {:inline,
                update_received_statistics: 2,
                update_sent_statistics: 2,
                update_state_statistics: 1}
      defp update_received_statistics(_type, %State{} = state), do: state
      defp update_sent_statistics(_type, %State{} = state), do: state
      defp update_state_statistics(return), do: return
    end

    # @spec update_rcv_send_statistics(State.t()) :: State.t()
    # defp update_rcv_send_statistics(%State{} = state) do
    #   %{
    #     state
    #     | statistics:
    #         Map.update(state.statistics, :received_to_send, nil, fn
    #           {min, _last, max} when state.statistics.rcv_timestamp != nil ->
    #             new = System.monotonic_time(:microsecond)
    #             last = new - state.statistics.rcv_timestamp

    #             # Do not accept 0 as min value
    #             new_min =
    #               cond do
    #                 last == 0 -> min
    #                 min == 0 -> last
    #                 true -> min(min, last)
    #               end

    #             {new_min, last, max(max, last)}

    #           nil when state.statistics.rcv_timestamp != nil ->
    #             new = System.monotonic_time(:microsecond)
    #             last = new - state.statistics.rcv_timestamp

    #             {last, last, last}

    #           other ->
    #             other
    #         end)
    #   }
    # end

    #### Helpers ####

    # Calculates based on the baudrate and the amount of bit times the necessary time in us
    @spec calculate_bittimes_to_us(non_neg_integer(), State.t()) :: ms :: non_neg_integer()
    defp calculate_bittimes_to_us(bittimes, state)

    defp calculate_bittimes_to_us(bittimes, %State{
           opts: %{baudrate: :auto},
           autobaud_baudrate: baud
         }) do
      trunc(1_000_000 / baud * bittimes)
    end

    defp calculate_bittimes_to_us(bittimes, %State{opts: %{baudrate: baud}}) do
      trunc(1_000_000 / baud * bittimes)
    end

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
    @spec after_decode_fanout_cb(
            State.t(),
            StateData.t(),
            TransportBehaviour.transport_cb_frame()
          ) :: any()
    defp after_decode_fanout_cb(%State{} = state, %StateData{} = state_data, cb_frame) do
      server = self()
      source_addr = state_data.source_address

      case state.callback do
        {module, function, arity}
        when is_atom(module) and is_atom(function) and arity == 3 ->
          if function_exported?(module, function, arity) do
            spawn_task(state, cb_frame, source_addr, Function.capture(module, function, arity))
          end

        pid when is_dest(pid) ->
          try do
            send(
              pid,
              {:bacnet_transport, @transport_protocol, source_addr, cb_frame, server}
            )
          catch
            # Ignore any exception coming from send/2
            # (an "invalid" destination raises! [i.e. an atom but it's not registered])
            _type, _err -> :ok
          end

        fun when is_function(fun, 3) ->
          spawn_task(state, cb_frame, source_addr, fun)
      end
    end

    # credo:disable-for-lines:50 Credo.Check.Refactor.CyclomaticComplexity
    defp validate_open_opts(opts, mfa, skip_check)
         when is_binary(mfa) and is_boolean(skip_check) do
      case opts[:baudrate] do
        nil ->
          :ok

        :auto ->
          :ok

        term when is_integer(term) and term >= 0 ->
          :ok

        term ->
          raise ArgumentError,
                mfa <>
                  " expected baudrate to be a non negative integer, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:local_address] do
        nil ->
          if not skip_check do
            raise ArgumentError,
                  mfa <> " expected local_address to be present (absent in opts)"
          end

        term when is_integer(term) and term >= @min_master_addr and term <= @max_slave_addr ->
          :ok

        term ->
          raise ArgumentError,
                mfa <>
                  " expected local_address to be a valid address in the range of 0-254, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:log_communication] do
        nil ->
          :ok

        term when is_boolean(term) ->
          :ok

        term ->
          raise ArgumentError,
                mfa <>
                  " expected log_communication to be a boolean, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:log_communication_rcv] do
        nil ->
          :ok

        term when is_boolean(term) ->
          :ok

        term ->
          raise ArgumentError,
                mfa <>
                  " expected log_communication_rcv to be a boolean, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:max_info_frames] do
        nil ->
          :ok

        term when is_integer(term) and term > 0 ->
          :ok

        term ->
          raise ArgumentError,
                mfa <>
                  " expected max_info_frames to be a positive integer, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:max_master_address] do
        nil ->
          :ok

        term when is_integer(term) and term >= 1 and term <= 127 ->
          :ok

        term ->
          raise ArgumentError,
                mfa <>
                  " expected max_master_address to be an integer in the range 1-127, " <>
                  "got: #{inspect(term)}"
      end

      case opts[:port_name] do
        nil ->
          if not skip_check do
            raise ArgumentError,
                  mfa <> " expected port_name to be present (absent in opts)"
          end

        term when is_binary(term) ->
          :ok

        term ->
          raise ArgumentError,
                mfa <>
                  " expected port_name to be a binary, " <>
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
                mfa <>
                  " expected supervisor to be a valid supervisor reference, " <>
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
