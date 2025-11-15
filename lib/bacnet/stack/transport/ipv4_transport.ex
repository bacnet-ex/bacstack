defmodule BACnet.Stack.Transport.IPv4Transport do
  @moduledoc """
  The BACnet transport for BACnet/IP on IPv4.

  BACnet/IPv4 uses UDP/IPv4 for communication. It uses both unicast and broadcast.
  Broadcast is used for unconfirmed services, such as discovery.

  The BACnet specification allows for using multicast, however multicast is not implemented,
  as the majority of the commercial devices solely use unicast and broadcast.

  For retrieving the broadcast address to send BACnet data the GenServer will be called.
  When sending BACnet data in large quantities (high performance scenario),
  this is however unwanted because it can slow down the process and bottleneck the whole
  traffic, if the transport has huge traffic to handle.
  For those rare cases, retrieving the broadcast address for sending can be optimized
  by storing the broadcast address in `:persistent_term`.
  This can be enabled in the application environment `:bacstack`
  under `:client_broadcast_addr_in_persistent_term` with the value `true`.
  Alternatively you can provide the option `:is_broadcast` for `send/4`.
  When using `BACnet.Stack.Client`, it will provide `:is_broadcast` pre-calculated.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NPCI
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [is_dest: 1, is_server: 1, log_debug: 1]

  require Constants
  require Logger

  use GenServer

  @behaviour TransportBehaviour

  @active_num_start 10

  @bacnet_port Constants.macro_by_name(:bvll, :default_port_bacnet_ip)
  @bacnet_ip_bvll Constants.macro_by_name(:bvll, :type_bacnet_ipv4)
  @bvll_header_length 4

  @bacnet_proto :bacnet_ipv4
  @max_apdu 1476
  @transport_protocol {@bacnet_proto, __MODULE__}

  # Looks up the transport PID through the portal (but only if the port is still open)
  @spec lookup_broadcast_address_by_portal_port(port()) ::
          {:inet.ip4_address(), :inet.port_number()}
  defp lookup_broadcast_address_by_portal_port(portal) do
    case :inet.info(portal) do
      %{owner: owner} -> get_broadcast_address(owner)
      _else -> {{255, 255, 255, 255}, @bacnet_port}
    end
  end

  # Get the broadcast address
  # If enabled, try :persistent_term first and then fall back to GenServer.call/2
  @spec lookup_broadcast_address_by_portal(port()) :: {:inet.ip4_address(), :inet.port_number()}
  defp lookup_broadcast_address_by_portal(portal) do
    if Application.get_env(:bacstack, :client_broadcast_addr_in_persistent_term, false) do
      :persistent_term.get({__MODULE__, portal}, nil)
    end || lookup_broadcast_address_by_portal_port(portal)
  end

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{}

    @fields [
      :port,
      :broadcast_rcv_port,
      :callback,
      :local_ip,
      :local_port,
      :broadcast_addr,
      :cidr,
      :active_num,
      :opts
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  @typedoc """
  Valid open options. For a description of each, see `open/2`.
  """
  @type open_option ::
          {:bacnet_port, 47_808..65_535}
          | {:inet_backend, :inet | :socket}
          | {:local_ip, :inet.ip4_address() | binary() | :none}
          | {:reuseaddr, boolean()}
          | {:reuseport, boolean()}
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
          {:bvlc, binary()}
          | {:is_broadcast, boolean()}
          | TransportBehaviour.transport_send_option()

  @typedoc """
  List of send options.
  """
  @type send_options :: [send_option()]

  @typedoc """
  The destination and source address is a tuple of IPv4 address and UDP port.
  """
  @type iplink_address :: {:inet.ip4_address(), :inet.port_number()}

  @doc """
  Get the IPv4 address for the given ethernet interface name.
  Only interfaces with broadcast capabilities are considered.

  Even if multiple IP addresses are bound to the interface,
  only the first one is returned.
  Which one is the first is undefined and may be platform-specific.
  Do not rely on consistent results for interfaces with multiple IPv4 addresses,
  unless you've tested it in full.

  This is a helper function to get the address (which may be from DHCP) by
  the ethernet interface name, which is useful for `open/2`/`child_spec/1`
  when you don't directly know the IPv4 address of the interface you want to use.
  """
  @spec get_address_for_ifname(binary()) ::
          {:ok, :inet.ip4_address()} | {:error, :inet.posix() | :not_found}
  def get_address_for_ifname(ifname) when is_binary(ifname) do
    case getifaddrs() do
      {:ok, ifs} ->
        case Map.fetch(ifs, ifname) do
          {:ok, [{ip, _sub, _brd} | _tl]} ->
            {:ok, ip}

          :error ->
            {:error, :not_found}
        end

      error ->
        error
    end
  end

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
  def max_npdu_length() do
    # Ethernet MTU = 1500
    # IP header =     -20
    # UDP header =     -8
    # BVLL header =   -10

    1462
  end

  @doc """
  Opens/starts the Transport module. A process is started, that is linked to the caller process.

  See the `BACnet.Stack.TransportBehaviour` documentation for more information.

  In the case of this BACnet/IPv4 transport, the transport PID/port is a `GenServer` receiving the UDP unicast
  and broadcast packets.
  However the portal is the UDP port where the data is sent to directly,
  without going through the `GenServer` for sending the data.
  The BACnet/IPv4 transport module makes sure the data is correctly wrapped for the BACnet/IPv4 protocol.
  Source and destination address is a tuple of IP address and port.

  Two UDP sockets will be opened, unless we do not bind to a specific interface. The second socket is only
  used for receiving broadcasts, since as soon as we bind to a specific interface, the kernel will not
  send us broadcast packets anymore. On Windows, broadcasts are also received when binding.
  We internally filter broadcast packets on the non-broadcast socket in such cases, where two sockets will be opened.

  This transport takes the following options, in addition to `t:GenServer.options/0`:
  - `bacnet_port: 47808..65535` - Optional. The port number to use for BACnet. Defaults to `0xBAC0` (47808).
  - `inet_backend: :inet | :socket` - Optional. Allows to switch the inet (gen_udp) backend.
  - `local_ip: :inet.ip4_address() | binary() | :none` - Optional. The local IP address to bind to. If not specified,
    the first private IP address will be discovered. As private IP addresses count the IANA private IP range -
    `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16`.
    It may also be an ethernet interface name as a binary - in that case,
    the ethernet  interface adapters will be enumerated and
    the IP address of the given interface will be used to bind to.
    Use `:none` to not bind explicitely to a specific ethernet interface adapter, which in turn will automatically
    bind to all ethernet interfaces and all destinations will be marked as "routed" (`is_destination_routed/2`).
    As a consequence, broadcast traffic may not be sent to the network you may want to and some devices will not reply
    to such broadcasts (`255.255.255.255`),
    unless you explicitely specify the correct broadcast address as destination when sending BACnet frames.
    Some functionality, such as BBMD and Foreign Device, will not work, because we are unable to determine
    our IP address (we do not know the default routing interface). We will try to automatically update the information,
    however that requires receiving a broadcast from ourself (some OS don't give us our broadcast back, i.e. BSD),
    which will however in normal circumstances be too late, since the relevant processes have already been started in the supervision tree.
    The `:none` value is thus not recommended and should not be used in a production environment.
    The default way of discovering the network interface should work in non-complex environments (only one network interface),
    for complex environments you should specify the network interface explicitely.
  - `reuseaddr: boolean()` - Optional. Allows to set `SO_REUSEADDR` on the UDP socket.
  - `reuseport: boolean()` - Optional. Allows to set `SO_REUSEPORT` on the UDP socket - only with socket backend.
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
          raise ArgumentError, "open/2 got a MFA tuple as callback, but function is not exported"
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
        :bacnet_port,
        :inet_backend,
        :local_ip,
        :reuseaddr,
        :reuseport,
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
  @spec get_broadcast_address(GenServer.server()) :: iplink_address()
  def get_broadcast_address(transport) when is_server(transport) do
    GenServer.call(transport, :get_broadcast_address)
  end

  @doc """
  Get the local address.
  """
  @spec get_local_address(GenServer.server()) :: iplink_address()
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
  @spec get_portal(GenServer.server()) :: port()
  def get_portal(transport) when is_server(transport) do
    GenServer.call(transport, :get_portal)
  end

  @doc """
  Checks whether the given destination is an address that needs to be routed.
  """
  @spec is_destination_routed(GenServer.server(), iplink_address() | term()) :: boolean()
  def is_destination_routed(transport, destination) when is_server(transport) do
    GenServer.call(transport, {:is_destination_routed, destination})
  end

  @doc """
  Verifies whether the given destination is valid for the transport module.
  """
  @spec is_valid_destination(iplink_address() | term()) :: boolean()
  def is_valid_destination(destination) do
    case destination do
      {{ip_a, ip_b, ip_c, ip_d}, port}
      when ip_a in 1..255 and ip_b in 0..255 and ip_c in 0..255 and
             ip_d in 1..255 and port in 47_808..65_535 ->
        true

      _else ->
        false
    end
  end

  @doc """
  Sends data to the BACnet network.

  See the `BACnet.Stack.TransportBehaviour` documentation for more information.

  In addition, the following options are available:
  - `bvlc: binary()` - Optional. The BACnet/IP Virtual Link Control to use.
    This needs to be the binary representation of any BVLC (i.e. of `BACnet.Protocol.BvlcForwardedNPDU`),
    including the BVLC function. The BVLC function gets automatically extracted and placed at the correct position.
  - `is_broadcast: boolean()` - Optional. Whether the destination is a broadcast address or not.
    If omitted it will be automatically determined by calling the GenServer
    to get the broadcast address (or using `:persistent_term`, if enabled).
  """
  @spec send(
          port(),
          iplink_address(),
          EncoderProtocol.t() | iodata(),
          send_options()
        ) ::
          :ok | {:error, term()}
  def send(portal, destination, data, opts \\ [])
      when is_port(portal) and is_tuple(destination) and
             (is_binary(data) or is_list(data) or is_struct(data)) and
             is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "send/4 expected a keyword list, got: #{inspect(opts)}"
    end

    with {:ok, is_broadcast} <-
           (case destination do
              {{ip_a, ip_b, ip_c, ip_d} = dest_addr, port}
              when ip_a in 1..255 and ip_b in 0..255 and ip_c in 0..255 and
                     ip_d in 1..255 and port in 47_808..65_535 ->
                # Also make sure the UDP broadcast address all 255 is considered
                is_broadcast =
                  {255, 255, 255, 255} == dest_addr or
                    Keyword.get_lazy(opts, :is_broadcast, fn ->
                      # Verification whether destination is broadcast or not
                      # Default: Use persistent term for faster lookup performance
                      # Fallback: Call the GenServer to get the broadcast address
                      {brd_addr, _port} = lookup_broadcast_address_by_portal(portal)
                      dest_addr == brd_addr
                    end)

                {:ok, is_broadcast}

              _else ->
                {:error, :invalid_destination}
            end),
         {:ok, {_npci, bin_data} = pkg} <-
           TransportBehaviour.build_bacnet_packet(data, is_broadcast, opts),
         bin_len = IO.iodata_length(bin_data),
         :ok <-
           (if bin_len > @max_apdu do
              {:error, :apdu_too_long}
            else
              :ok
            end),
         :ok <-
           (if bin_len == 0 and opts[:bvlc] == nil do
              {:error, :data_empty}
            else
              :ok
            end) do
      out_data =
        cond do
          opts[:skip_headers] == true -> bin_data
          true -> add_bvll(pkg, bin_len, is_broadcast, opts)
        end

      :gen_udp.send(portal, destination, out_data)
    end
  end

  @doc false
  def init({callback, opts}) do
    bac_port = opts[:bacnet_port] || @bacnet_port

    local_ip =
      case opts[:local_ip] do
        :none ->
          nil

        {_a, _b, _c, _d} = ip ->
          ip

        ifname when is_binary(ifname) ->
          case get_address_for_ifname(ifname) do
            {:ok, ip} ->
              ip

            {:error, :not_found} ->
              raise "Unable to find ethernet interface " <>
                      "(with broadcast flag) called " <>
                      ifname

            {:error, err} ->
              raise "Unable to enumerate ethernet interfaces, error: " <> inspect(err)
          end

        nil ->
          local_ipv4() || raise "Unable to discover local IPv4 address"
      end

    {broadcast_addr, cidr, opts_tail} =
      if local_ip do
        {broadcast_addr, cidr} = calculate_cidr_and_broadcast_for_ip(local_ip)
        {broadcast_addr, cidr, [ip: local_ip]}
      else
        %CIDR{} = cidr = CIDR.parse("255.255.255.255/32")
        {{255, 255, 255, 255}, cidr, []}
      end

    opts_tail = Keyword.put(opts_tail, :reuseaddr, !!Map.get(opts, :reuseaddr, false))

    # Allow to use socket backend, instead of the current default inet
    {backend, opts_tail} =
      if Map.get(opts, :inet_backend, nil) == :socket do
        {:socket, [{:reuseport, !!Map.get(opts, :reuseport, false)} | opts_tail]}
      else
        {:inet, opts_tail}
      end

    case :gen_udp.open(bac_port, [
           {:inet_backend, backend},
           :binary,
           :inet,
           {:active, @active_num_start},
           {:broadcast, true}
           | opts_tail
         ]) do
      {:ok, port} ->
        # For broadcasts and not on Windows, open separate broadcast receive udp port,
        # because on Linux you can not receive broadcasts once you bind
        # to a particular IP address (ethernet interface)

        broadcast_operation =
          if local_ip != nil and not match?({:win32, _name}, :os.type()) do
            brd_opts_tail = Keyword.replace!(opts_tail, :ip, broadcast_addr)

            :gen_udp.open(bac_port, [
              {:inet_backend, backend},
              :binary,
              :inet,
              {:active, @active_num_start}
              | brd_opts_tail
            ])
          else
            {:ok, nil}
          end

        case broadcast_operation do
          {:ok, broadcast_port} ->
            state = %State{
              port: port,
              broadcast_rcv_port: broadcast_port,
              callback: callback,
              local_ip: local_ip,
              local_port: bac_port,
              broadcast_addr: broadcast_addr,
              cidr: cidr,
              active_num: @active_num_start,
              opts: opts
            }

            log_debug(fn ->
              "BacIPv4Transport: Started on #{inspect(self())} with IP " <>
                "#{format_ip({local_ip, bac_port})} and broadcast " <>
                format_ip({broadcast_addr, bac_port})
            end)

            if Application.get_env(:bacstack, :client_broadcast_addr_in_persistent_term, false) do
              :persistent_term.put({__MODULE__, port}, {broadcast_addr, bac_port})
            end

            {:ok, state}

          {:error, err} ->
            {:stop, err}
        end

      {:error, err} ->
        {:stop, err}
    end
  end

  @doc false
  def handle_call(:close, _from, %State{} = state) do
    log_debug("BacIPv4Transport: Received close request")

    :gen_udp.close(state.port)

    if state.broadcast_rcv_port do
      :gen_udp.close(state.broadcast_rcv_port)
    end

    if Application.get_env(:bacstack, :client_broadcast_addr_in_persistent_term, false) do
      :persistent_term.erase({__MODULE__, state.port})
    end

    {:stop, :normal, :ok, state}
  end

  def handle_call(:get_local_address, _from, %State{} = state) do
    log_debug("BacIPv4Transport: Received get_local_address request")

    # Make sure we have a "valid" IP address (valid as in only in form for validation)
    {:reply, {state.local_ip || {0, 0, 0, 0}, state.local_port}, state}
  end

  def handle_call(:get_broadcast_address, _from, %State{} = state) do
    log_debug("BacIPv4Transport: Received get_broadcast_address request")
    {:reply, {state.broadcast_addr, state.local_port}, state}
  end

  def handle_call({:is_destination_routed, {destination, _port}}, _from, %State{} = state)
      when is_tuple(destination) and tuple_size(destination) == 4 do
    log_debug(fn ->
      "BacIPv4Transport: Received is_destination_routed request for #{inspect(destination)}"
    end)

    routed =
      case CIDR.match(state.cidr, destination) do
        {:ok, result} -> !result
        _term -> true
      end

    {:reply, routed, state}
  end

  def handle_call({:is_destination_routed, destination}, _from, state) do
    log_debug(fn ->
      "BacIPv4Transport: Received (non-IP) is_destination_routed request for #{inspect(destination)}"
    end)

    {:reply, true, state}
  end

  def handle_call(:get_portal, _from, %State{} = state) do
    log_debug("BacIPv4Transport: Received get_portal request")

    {:reply, state.port, state}
  end

  def handle_call(_call, _from, state) do
    {:noreply, state}
  end

  @doc false
  def handle_info({:udp, _port, source_addr, sender_port, _data}, %State{} = state)
      when state.local_ip == source_addr and state.local_port == sender_port do
    # Ignore broadcasts from us
    {:noreply, state}
  end

  def handle_info({:udp, rcv_port, source_addr, sender_port, data}, %State{} = state) do
    # If we are not bound to a specific network interface and we receive a packet,
    # we need to check first if it's a packet from ourself, if so, we need to ignore it
    is_packet_from_us =
      if match?(%{local_port: ^sender_port, opts: %{local_ip: :none}}, state) do
        case getifaddrs() do
          {:ok, ifs} ->
            Enum.find_value(ifs, fn
              {_ifname, props} ->
                Enum.any?(props, &match?({^source_addr, _sub, _brd}, &1))

              _else ->
                nil
            end) == true

          _error ->
            false
        end
      else
        false
      end

    # If we have a broadcast socket, we need to ignore broadcast packets from the normal socket (we MAY receive them duplicated, this is a countermeasurement)
    # On Windows we do not have a broadcast socket, since Windows receives broadcasts also on the normal socket
    # On Linux we do have a broadcast socket (when binding), since Linux does NOT receive broadcasts on the normal socket
    # If we have already determined that this is a packet from us, we can ignore the check here, the result of this operation is not used
    is_packet_from_non_broadcast_socket =
      if !is_packet_from_us and state.broadcast_rcv_port != nil and
           state.broadcast_rcv_port != rcv_port do
        case getifaddrs() do
          {:ok, ifs} ->
            Enum.find_value(ifs, fn
              {_ifname, props} ->
                Enum.any?(props, &match?({_addr, _sub, ^source_addr}, &1))

              _else ->
                nil
            end) == true

          _error ->
            false
        end
      else
        false
      end

    # When sending broadcasts, we will receive it too (broadcast loopback)
    cond do
      # Ignore packets from us (not bound to a specific interface)
      is_packet_from_us and is_nil(state.local_ip) ->
        # We will also update the local_ip,
        # since we know it now but previously didn't when creating the UDP socket
        {broadcast_addr, cidr} = calculate_cidr_and_broadcast_for_ip(source_addr)
        {:noreply, %{state | local_ip: source_addr, broadcast_addr: broadcast_addr, cidr: cidr}}

      is_packet_from_us ->
        {:noreply, state}

      # Ignore broadcast packets from non-broadcast socket, if we have one (we don't on Windows in any case)
      is_packet_from_non_broadcast_socket ->
        log_debug(fn ->
          "BacIPv4Transport: Ignoring broadcast UDP packet on non-broadcast socket from " <>
            "#{format_ip({source_addr, sender_port})} with data length #{byte_size(data)}"
        end)

        {:noreply, state}

      true ->
        log_debug(fn ->
          "BacIPv4Transport: Received UDP packet from " <>
            "#{format_ip({source_addr, sender_port})} with data length #{byte_size(data)}"
        end)

        case decode_packet(data) do
          {:ok, decoded} ->
            after_decode_fanout_cb(state, decoded, {source_addr, sender_port})

          {:error, err} ->
            Logger.warning(
              "BacIPv4Transport: Got error while decoding UDP packet, error: #{inspect(err)}"
            )

          {:ignore, reason} ->
            log_debug(fn ->
              "BacIPv4Transport: Discards UDP packet, reason: #{inspect(reason)}"
            end)
        end

        # Reset active counter on the second last message
        new_state =
          if state.active_num <= 2 do
            :inet.setopts(state.port, active: @active_num_start)
            %State{state | active_num: @active_num_start}
          else
            %State{state | active_num: state.active_num - 1}
          end

        {:noreply, new_state}
    end
  end

  def handle_info({:udp_passive, port}, %State{} = state) do
    :inet.setopts(port, active: @active_num_start)

    # Only update state active_num if we've updated the main socket
    new_state =
      if port == state.port do
        %State{state | active_num: @active_num_start}
      else
        state
      end

    {:noreply, new_state}
  end

  def handle_info({:udp_error, _port, :econnreset}, %State{} = state) do
    # Ignore unreachable destination (getting back ICMP unreachable)
    {:noreply, state}
  end

  #### BACnet/IP Frame Parsing ####

  # Do not accept NPCI with hopcount = 0, this signifies a non-conformant BACnet router
  defguardp is_valid_hopcount(hopcount)
            when is_nil(hopcount) or (is_integer(hopcount) and hopcount > 0)

  # Parses BVLL and NSDU, it will return the raw APDU data to be consumed
  @spec decode_packet(binary()) ::
          {:ok, {:bvlc, bvlc :: Protocol.bvlc()}}
          | {:ok,
             {:network, bvlc :: Protocol.bvlc(), npci :: NPCI.t(),
              nsdu :: Protocol.NetworkLayerProtocolMessage.t()}}
          | {:ok, {:apdu, bvlc :: Protocol.bvlc(), npci :: NPCI.t(), apdu :: binary()}}
          | {:error, term()}
          | {:ignore, term()}
  defp decode_packet(data)

  defp decode_packet(
         <<Constants.macro_by_name(:bvll, :type_bacnet_ipv4)::size(8), bvlc_function::size(8),
           msg_length::size(16), rest::binary>> = data
       )
       when byte_size(data) < 1600 do
    # Assert UDP packet hasn't been fragmented and thus is longer than Ethernet MTU (1500) + some more
    # and thus prevent getting large amount of data when we only allow a small number of APDU segments
    if byte_size(data) == msg_length do
      with {:ok, {bvlc_additional_length, bvlc, npci_data}} <-
             Protocol.decode_bvll(@bacnet_ip_bvll, bvlc_function, rest),
           :continue <-
             (if msg_length - @bvll_header_length - bvlc_additional_length > 0 do
                :continue
              else
                {:ok, {:bvlc, bvlc}}
              end),
           {:ok, {%NPCI{hopcount: hopcount} = npci, nsdu_data}} when is_valid_hopcount(hopcount) <-
             Protocol.decode_npci(npci_data),
           {:ok, {type, nsdu_data}} <- Protocol.decode_npdu(npci, nsdu_data) do
        {:ok, {type, bvlc, npci, nsdu_data}}
      else
        {:ok, {%NPCI{} = _npci, _nsdu_data}} -> {:ignore, :invalid_hopcount}
        {:ok, _term} = term -> term
        {:error, _err} = err -> err
      end
    else
      {:error, :bvlc_length_mismatch}
    end
  end

  defp decode_packet(_data) do
    {:ignore, :invalid_bvll_packet}
  end

  #### Helpers ####

  # Spawns a new task (either supervisored or not) and invokes the function,
  # ignoring any errors that may occur by the callback
  @spec spawn_task(State.t(), tuple(), term(), fun()) :: any()
  defp spawn_task(state, data, source_addr, fun)

  defp spawn_task(%State{port: port, opts: %{supervisor: sup}} = _state, data, source_addr, fun)
       when not is_nil(sup) and is_function(fun, 3) do
    Task.Supervisor.start_child(sup, fn -> fun.(source_addr, data, port) end)
  end

  defp spawn_task(%State{port: port} = _state, data, source_addr, fun) when is_function(fun, 3) do
    Task.start(fn -> fun.(source_addr, data, port) end)
  end

  # Fans out the frame to the transport callback
  @spec after_decode_fanout_cb(State.t(), tuple(), term()) :: any()
  defp after_decode_fanout_cb(%State{} = state, data, source_addr) do
    case state.callback do
      {module, function, arity}
      when is_atom(module) and is_atom(function) and arity == 3 ->
        if function_exported?(module, function, arity) do
          spawn_task(state, data, source_addr, Function.capture(module, function, arity))
        end

      pid when is_dest(pid) ->
        try do
          send(pid, {:bacnet_transport, @transport_protocol, source_addr, data, state.port})
        catch
          # Ignore any exception coming from send/2 (an "invalid" destination raises! [i.e. an atom but it's not registered])
          _type, _err -> :ok
        end

      fun when is_function(fun, 3) ->
        spawn_task(state, data, source_addr, fun)
    end
  end

  @spec get_bvlc(boolean(), Keyword.t()) :: binary()
  defp get_bvlc(is_broadcast, opts) do
    cond do
      bvlc = opts[:bvlc] ->
        unless is_binary(bvlc) do
          raise ArgumentError, "Expected opts[:bvlc] to be a binary, got: #{inspect(bvlc)}"
        end

        bvlc

      is_broadcast ->
        <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_original_broadcast_npdu)>>

      true ->
        <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_original_unicast_npdu)>>
    end
  end

  @spec add_bvll(tuple(), pos_integer(), boolean(), Keyword.t()) :: iodata()
  defp add_bvll({npci_bin, data}, datalength, is_broadcast, opts)
       when is_integer(datalength) and is_boolean(is_broadcast) and
              is_list(opts) do
    <<bvlc_bin::binary-size(1), after_bvlc_bin::binary>> = get_bvlc(is_broadcast, opts)
    msg_length = 4 + IO.iodata_length(after_bvlc_bin) + IO.iodata_length(npci_bin) + datalength

    [
      @bacnet_ip_bvll,
      bvlc_bin,
      <<msg_length::size(16)>>,
      after_bvlc_bin,
      npci_bin,
      data
    ]
  end

  # Get the first non-local IPv4 address of the system
  @spec local_ipv4() :: :inet.ip4_address() | nil
  defp local_ipv4() do
    case getifaddrs() do
      {:ok, ifaddrs} ->
        cidr1 = CIDR.parse("10.0.0.0/8")
        cidr2 = CIDR.parse("172.16.0.0/12")
        cidr3 = CIDR.parse("192.168.0.0/16")

        Enum.find_value(ifaddrs, fn
          {_name, ips} ->
            Enum.find_value(ips, fn
              {address, _subnet, broadcast} when not is_nil(broadcast) ->
                if {:ok, true} == CIDR.match(cidr1, address) or
                     {:ok, true} == CIDR.match(cidr2, address) or
                     {:ok, true} == CIDR.match(cidr3, address) do
                  address
                end

              _else ->
                nil
            end)

          _else ->
            nil
        end)

      _else ->
        nil
    end
  end

  # Get the broadcast address and subnet mask for the IP address
  @spec get_broadcast_and_subnet_by_address(:inet.ip4_address()) ::
          {:inet.ip4_address() | nil, subnet :: :inet.ip4_address()} | nil
  defp get_broadcast_and_subnet_by_address({_one, _two, _three, _four} = address) do
    case getifaddrs() do
      {:ok, ifaddrs} ->
        Enum.find_value(ifaddrs, fn
          {_name, props} ->
            Enum.find_value(props, fn
              {^address, subnet, broadcast} ->
                {broadcast, subnet}

              _else ->
                nil
            end)

          _else ->
            nil
        end)

      _else ->
        nil
    end
  end

  @spec calculate_cidr_and_broadcast_for_ip(:inet.ip4_address()) ::
          {broadcast_addr :: :inet.ip4_address() | nil, %CIDR{}}
  defp calculate_cidr_and_broadcast_for_ip(local_ip) do
    {broadcast_addr, subnet_mask} =
      get_broadcast_and_subnet_by_address(local_ip) ||
        raise "No broadcast address and subnet mask found for #{inspect(local_ip)}"

    ip4 = :inet.ntoa(local_ip)
    mask = calculate_bitlength(subnet_mask)
    %CIDR{} = cidr = CIDR.parse("#{ip4}/#{mask}")

    {broadcast_addr, cidr}
  end

  # Calculates the broadcast address for the given IP address and subnet mask
  # @spec calculate_broadcast_address(:inet.ip4_address(), :inet.ip4_address()) ::
  #         :inet.ip4_address() | nil
  # defp calculate_broadcast_address(
  #        address,
  #        subnet
  #      )

  # defp calculate_broadcast_address(
  #        _address,
  #        {255, 255, 255, 255}
  #      ) do
  #   nil
  # end

  # defp calculate_broadcast_address(
  #        {ip_one, ip_two, ip_three, ip_four} = _address,
  #        {net_one, net_two, net_three, net_four} = _subnet
  #      ) do
  #   ipaddr_int =
  #     Bitwise.bsl(ip_one, 24) + Bitwise.bsl(ip_two, 16) + Bitwise.bsl(ip_three, 8) + ip_four

  #   netmask_int =
  #     Bitwise.bsl(net_one, 24) + Bitwise.bsl(net_two, 16) + Bitwise.bsl(net_three, 8) + net_four

  #   netmask_inverse = Bitwise.band(0xFFFFFFFF, Bitwise.bnot(netmask_int))
  #   max_addr = Bitwise.bor(Bitwise.band(ipaddr_int, netmask_int), netmask_inverse)

  #   one = Bitwise.bsr(Bitwise.band(max_addr, 0xFF000000), 24)
  #   two = Bitwise.bsr(Bitwise.band(max_addr, 0x00FF0000), 16)
  #   three = Bitwise.bsr(Bitwise.band(max_addr, 0x0000FF00), 8)
  #   four = Bitwise.band(max_addr, 0x000000FF)

  #   {one, two, three, four}
  # end

  # Calculate the bitmask length of a subnet mask (netmask)
  @spec calculate_bitlength(:inet.ip4_address()) :: integer()
  defp calculate_bitlength({net_one, net_two, net_three, net_four} = _netmask) do
    netmask_int =
      Bitwise.bsl(net_one, 24) + Bitwise.bsl(net_two, 16) + Bitwise.bsl(net_three, 8) + net_four

    netmask_int
    |> Integer.to_charlist(2)
    |> Enum.reduce(0, fn char, acc ->
      acc + if char == ?1, do: 1, else: 0
    end)
  end

  @spec format_ip({:inet.ip4_address(), :inet.port_number()}) :: String.t()
  defp format_ip({nil, port} = _ip_port), do: "0.0.0.0:#{port}"

  defp format_ip({{one, two, three, four}, port} = _ip_port) do
    "#{one}.#{two}.#{three}.#{four}:#{port}"
  end

  defp validate_open_opts(opts) do
    case opts[:bacnet_port] do
      nil ->
        :ok

      term when is_integer(term) and term in 47_808..65_535 ->
        :ok

      term ->
        raise ArgumentError,
              "open/2 expected bacnet_port to be an integer in the range 47808-65535, " <>
                "got: #{inspect(term)}"
    end

    case opts[:local_ip] do
      nil ->
        :ok

      {ip_a, ip_b, ip_c, ip_d}
      when ip_a in 1..255 and ip_b in 0..255 and ip_c in 0..255 and
             ip_d in 1..254 ->
        :ok

      term when is_binary(term) ->
        :ok

      :none ->
        :ok

      term ->
        raise ArgumentError,
              "open/2 expected local_ip to be a valid IPv4 address (tuple) " <>
                "or binary or :none, " <>
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

  # Iterates :inet.getifaddrs() and returns a neat map of list of IPv4 addresses (only those with broadcast-capabilities)
  @spec getifaddrs() ::
          {:ok,
           %{
             (ifname :: String.t()) => [
               {addr :: :inet.ip4_address(), subnet :: :inet.ip4_address(),
                broadcast_addr :: :inet.ip4_address()}
             ]
           }}
          | {:error, :inet.posix()}
  defp getifaddrs() do
    case :inet.getifaddrs() do
      {:ok, ifs} ->
        res =
          Enum.reduce(ifs, %{}, fn {ifname, props}, acc ->
            case iterate_getifaddrs(props, []) do
              [] -> acc
              defs -> Map.put(acc, List.to_string(ifname), Enum.reverse(defs))
            end
          end)

        {:ok, res}

      error ->
        error
    end
  end

  @spec iterate_getifaddrs([Keyword.t()], list()) :: [
          {addr :: :inet.ip4_address(), subnet :: :inet.ip4_address(),
           broadcast_addr :: :inet.ip4_address() | nil}
        ]
  defp iterate_getifaddrs(
         [
           {:addr, {_one, _two, _three, _four} = addr},
           {:netmask, subnet},
           {:broadaddr, broadcast} | tail
         ],
         acc
       ) do
    iterate_getifaddrs(tail, [{addr, subnet, broadcast} | acc])
  end

  defp iterate_getifaddrs(
         [{:addr, _addr}, {:netmask, _subnet}, {:broadaddr, _broadcast} | tail],
         acc
       ) do
    iterate_getifaddrs(tail, acc)
  end

  # defp iterate_getifaddrs(
  #        [{:addr, {_one, _two, _three, _four} = addr}, {:netmask, subnet} | tail],
  #        acc
  #      ) do
  #   iterate_getifaddrs(tail, [{addr, subnet, calculate_broadcast_address(addr, subnet)} | acc])
  # end

  defp iterate_getifaddrs([{:addr, _addr}, {:netmask, _subnet} | tail], acc) do
    iterate_getifaddrs(tail, acc)
  end

  defp iterate_getifaddrs([{_any, _val} | tail], acc) do
    iterate_getifaddrs(tail, acc)
  end

  defp iterate_getifaddrs([], acc) do
    acc
  end
end
