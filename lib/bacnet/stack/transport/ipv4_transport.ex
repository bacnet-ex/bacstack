defmodule BACnet.Stack.Transport.IPv4Transport do
  @moduledoc """
  The BACnet transport for BACnet/IP on IPv4.

  BACnet/IPv4 uses UDP/IPv4 for communication. It uses both unicast and broadcast.
  Broadcast is used for unconfirmed services, such as discovery.

  The BACnet specification allows for using multicast, however multicast is not implemented,
  as the majority of the commercial devices solely use unicast and broadcast.
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

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{}

    @fields [:callback, :local_ip, :local_port, :broadcast_addr, :cidr, :port, :active_num, :opts]
    @enforce_keys @fields
    defstruct @fields
  end

  @typedoc """
  Valid open options. For a description of each, see `open/2`.
  """
  @type open_option ::
          {:bacnet_port, 47_808..65_535}
          | {:inet_backend, :inet | :socket}
          | {:local_ip, :inet.ip4_address()}
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
          | TransportBehaviour.transport_send_option()

  @typedoc """
  List of send options.
  """
  @type send_options :: [send_option()]

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
  However the portal is the UDP port where the data is sent to directly, without going through the `GenServer`.
  The BACnet/IPv4 transport module makes sure the data is correctly wrapped for the BACnet/IPv4 protocol.
  Source and destination address is a tuple of IP address and port.

  This transport takes the following options, in addition to `t:GenServer.options/0`:
  - `bacnet_port: 47808..65535` - Optional. The port number to use for BACnet. Defaults to `0xBAC0` (47808).
  - `inet_backend: :inet | :socket` - Optional. Allows to switch the inet (gen_udp) backend.
  - `local_ip: :inet.ip4_address()` - Optional. The local IP address to bind to. If not specified,
    the first private IP address will be discovered. As private IP addresses count the IANA private IP range -
    `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16`.
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
  @spec get_broadcast_address(GenServer.server()) :: {:inet.ip4_address(), :inet.port_number()}
  def get_broadcast_address(transport) when is_server(transport) do
    GenServer.call(transport, :get_broadcast_address)
  end

  @doc """
  Get the local address.
  """
  @spec get_local_address(GenServer.server()) :: {:inet.ip4_address(), :inet.port_number()}
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
  @spec is_destination_routed(GenServer.server(), {:inet.ip4_address(), :inet.port_number()}) ::
          boolean()
  def is_destination_routed(transport, destination) when is_server(transport) do
    GenServer.call(transport, {:is_destination_routed, destination})
  end

  @doc """
  Verifies whether the given destination is valid for the transport module.
  """
  @spec is_valid_destination(term()) :: boolean()
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
  """
  @spec send(
          port(),
          {:inet.ip4_address(), :inet.port_number()},
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
              {{ip_a, ip_b, ip_c, ip_d}, port}
              when ip_a in 1..255 and ip_b in 0..255 and ip_c in 0..255 and
                     ip_d in 1..255 and port in 47_808..65_535 ->
                {:ok, ip_d == 255}

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
    local_ip = opts[:local_ip] || local_ipv4() || raise "Unable to discover local IPv4 address"

    {broadcast_addr, subnet_mask} =
      get_broadcast_and_subnet_by_address(local_ip) ||
        raise "No broadcast address and subnet mask found for #{inspect(local_ip)}"

    ip4 = :inet.ntoa(local_ip)
    mask = calculate_bitlength(subnet_mask)
    %CIDR{} = cidr = CIDR.parse("#{ip4}/#{mask}")

    # Allow to use socket backend, instead of the current default inet
    {backend, opts_tail} =
      if Map.get(opts, :inet_backend, nil) == :socket do
        {:socket, [reuseport: !!Map.get(opts, :reuseport, false)]}
      else
        {:inet, []}
      end

    case :gen_udp.open(bac_port, [
           {:inet_backend, backend},
           :binary,
           {:ip, local_ip},
           {:active, @active_num_start},
           {:broadcast, true}
           | opts_tail
         ]) do
      {:ok, port} ->
        state = %State{
          callback: callback,
          port: port,
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

        {:ok, state}

      {:error, err} ->
        {:stop, err}
    end
  end

  @doc false
  def handle_call(:close, _from, %State{} = state) do
    log_debug("BacIPv4Transport: Received close request")

    :gen_udp.close(state.port)
    {:stop, :normal, :ok, state}
  end

  def handle_call(:get_local_address, _from, %State{} = state) do
    log_debug("BacIPv4Transport: Received get_local_address request")
    {:reply, {state.local_ip, state.local_port}, state}
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
      "BacIPv4Transport: Received (invalid) is_destination_routed request for #{inspect(destination)}"
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

  def handle_info({:udp, _port, source_addr, sender_port, data}, %State{} = state) do
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
        log_debug(fn -> "BacIPv4Transport: Discards UDP packet, reason: #{inspect(reason)}" end)
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

  def handle_info({:udp_passive, port}, %State{} = state) do
    :inet.setopts(port, active: @active_num_start)
    new_state = %State{state | active_num: @active_num_start}

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
        send(pid, {:bacnet_transport, @transport_protocol, source_addr, data, state.port})

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
    case :net.getifaddrs(%{family: :inet, flags: :any}) do
      {:ok, ifaddrs} ->
        cidr1 = CIDR.parse("10.0.0.0/8")
        cidr2 = CIDR.parse("172.16.0.0/12")
        cidr3 = CIDR.parse("192.168.0.0/16")

        Enum.find_value(ifaddrs, fn
          %{addr: %{addr: {_one, _two, _three, _four} = address}} ->
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
    end
  end

  # Get the broadcast address and subnet mask for the IP address
  @spec get_broadcast_and_subnet_by_address(:inet.ip4_address()) ::
          {:inet.ip4_address(), subnet :: :inet.ip4_address()} | nil
  defp get_broadcast_and_subnet_by_address({_one, _two, _three, _four} = address) do
    case :net.getifaddrs(%{family: :inet, flags: :any}) do
      {:ok, ifaddrs} ->
        Enum.find_value(ifaddrs, fn
          %{addr: %{addr: ^address}, netmask: %{addr: netmask}} = ifaddr ->
            {get_in(ifaddr, [:broadaddr, :addr]) ||
               calculate_broadcast_address(address, netmask), netmask}

          _else ->
            nil
        end)

      _else ->
        nil
    end
  end

  # Calculates the broadcast address for the given IP address and subnet mask
  @spec calculate_broadcast_address(:inet.ip4_address(), :inet.ip4_address()) ::
          :inet.ip4_address() | nil
  defp calculate_broadcast_address(
         {ip_one, ip_two, ip_three, ip_four} = _address,
         {net_one, net_two, net_three, net_four} = _subnet
       ) do
    ipaddr_int =
      Bitwise.bsl(ip_one, 24) + Bitwise.bsl(ip_two, 16) + Bitwise.bsl(ip_three, 8) + ip_four

    netmask_int =
      Bitwise.bsl(net_one, 24) + Bitwise.bsl(net_two, 16) + Bitwise.bsl(net_three, 8) + net_four

    netmask_inverse = Bitwise.band(0xFFFFFFFF, Bitwise.bnot(netmask_int))
    max_addr = Bitwise.bor(Bitwise.band(ipaddr_int, netmask_int), netmask_inverse)

    one = Bitwise.bsr(Bitwise.band(max_addr, 0xFF000000), 24)
    two = Bitwise.bsr(Bitwise.band(max_addr, 0x00FF0000), 16)
    three = Bitwise.bsr(Bitwise.band(max_addr, 0x0000FF00), 8)
    four = Bitwise.band(max_addr, 0x000000FF)

    {one, two, three, four}
  end

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

      term ->
        raise ArgumentError,
              "open/2 expected local_ip to be a valid IPv4 address (tuple), " <>
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
end
