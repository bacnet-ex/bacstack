defmodule BACnet.Stack.Transport.EthernetTransport do
  @moduledoc """
  The BACnet transport for BACnet/Ethernet.

  This module uses the `:socket` module and requires `NET_RAW`
  capabilities to use raw ethernet sockets.

  Windows does not support raw ethernet sockets as part of its API
  and thus trying to start an Ethernet transport will fail at socket level.

  The Linux kernel/driver will re-calculate the ethernet frame size
  and not honor the ethernet frame size in the ethernet frame itself,
  thus all padding zeros will be included in the frame and APDU.
  This may lead to unexpected behaviour in some edge cases.
  Use the IP transport or use BSD as an operating system instead,
  if you're having issues due to padding zeros being in the payload.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.NPCI
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [is_dest: 1, is_server: 1, log_debug: 1]

  require Logger

  use GenServer

  @behaviour TransportBehaviour

  @broadcast_addr <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>
  @receive_timeout 50

  @bacnet_proto :bacnet_ethernet
  @max_apdu 1476
  @transport_protocol {@bacnet_proto, __MODULE__}

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{}

    @fields [:callback, :eth_ifname, :eth_ifindex, :eth_mac, :port, :opts]
    @enforce_keys @fields
    defstruct @fields
  end

  @typedoc """
  Valid open options. For a description of each, see `open/2`.
  """
  @type open_option ::
          {:eth_ifname, binary()}
          | {:supervisor, Supervisor.supervisor()}
          | GenServer.option()

  @typedoc """
  List of open options.
  """
  @type open_options :: [open_option()]

  @typedoc """
  Valid send options. For a description of each, see `send/4`.
  """
  @type send_option :: TransportBehaviour.transport_send_option()

  @typedoc """
  List of send options.
  """
  @type send_options :: [send_option()]

  @typedoc """
  The destination and source address is a binary representing the MAC address of the ethernet link.
  """
  @type mac_address :: binary()

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

  In case of this BACnet/Ethernet transport, the transport is a PID,
  due to the GenServer receiving and processing Ethernet frames.
  The portal is a tuple of the underlying socket, the ethernet interface index and the MAC address of the interface,
  so that there's no need to go through the GenServer. The BACnet/Ethernet transport module makes sure
  the data is correctly wrapped for the BACnet/Ethernet protocol.
  Source and destination address is a binary containing the MAC address.

  This transport takes the following options, in addition to `t:GenServer.options/0`:
  - `eth_ifname: binary()` - Optional. The ethernet interface to use. Defaults to the first one (normally loopback).
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

    {opts2, genserver_opts} = Keyword.split(opts, [:eth_ifname, :supervisor])
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

  Since the broadcast address is static,
  you can also use `nil` as `transport` argument.
  """
  @spec get_broadcast_address(GenServer.server()) :: mac_address()
  def get_broadcast_address(transport) when is_server(transport) do
    @broadcast_addr
  end

  @doc """
  Get the local address.
  """
  @spec get_local_address(GenServer.server()) :: mac_address()
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
  @spec get_portal(GenServer.server()) :: term()
  def get_portal(transport) when is_server(transport) do
    GenServer.call(transport, :get_portal)
  end

  @doc """
  Checks whether the given destination is an address that needs to be routed.

  Always returns `false` due to how Ethernet works (no routing).
  """
  @spec is_destination_routed(GenServer.server(), mac_address() | term()) :: boolean()
  def is_destination_routed(transport, _destination) when is_server(transport) do
    false
  end

  @doc """
  Verifies whether the given destination is valid for the transport module.
  """
  @spec is_valid_destination(mac_address() | term()) :: boolean()
  def is_valid_destination(destination) do
    is_binary(destination) and byte_size(destination) == 6
  end

  @doc """
  Sends data to the BACnet network.

  See the `BACnet.Stack.TransportBehaviour` documentation for more information.
  """
  @spec send(
          TransportBehaviour.portal(),
          mac_address(),
          EncoderProtocol.t() | iodata(),
          send_options()
        ) ::
          :ok | {:error, term()}
  def send(portal, destination, data, opts \\ [])

  def send({portal, ifindex, src_mac}, destination, data, opts)
      when is_integer(ifindex) and ifindex > 0 and is_binary(src_mac) and
             is_binary(destination) and
             (is_binary(data) or is_list(data) or is_struct(data)) and
             is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "send/4 expected a keyword list, got: #{inspect(opts)}"
    end

    with :ok <-
           (if is_valid_destination(destination) do
              :ok
            else
              {:error, :invalid_destination}
            end),
         is_broadcast = destination == @broadcast_addr,
         {:ok, {npci_data, bin_data}} <-
           TransportBehaviour.build_bacnet_packet(data, is_broadcast, opts),
         bin_len = IO.iodata_length(bin_data),
         :ok <-
           (if bin_len > @max_apdu do
              {:error, :apdu_too_long}
            else
              :ok
            end),
         :ok <-
           (if bin_len == 0 do
              {:error, :data_empty}
            else
              :ok
            end) do
      {out_len, out_data} =
        cond do
          opts[:skip_headers] == true ->
            {bin_len, bin_data}

          true ->
            npci_len = IO.iodata_length(npci_data)
            {bin_len + npci_len + 3, [0x82, 0x82, 0x03, npci_data, bin_data]}
        end

      :socket.sendto(
        portal,
        [destination, src_mac, <<out_len::size(16)>>, out_data],
        %{family: 17, addr: <<0::size(16), ifindex::size(32)-native, 0::size(128)>>},
        [],
        :infinity
      )
    end
  end

  @doc false
  def init({callback, opts}) do
    eth_ifname =
      opts[:eth_ifname] || local_first_eth_ifname() || raise "Unable to find ethernet interface"

    {eth_ifindex, eth_mac} =
      get_ifindex_for_ifname(eth_ifname) ||
        raise "No ifindex and hwaddr found for #{inspect(eth_ifname)}"

    # AF_PACKET, SOCK_RAW, ETH_P_ALL
    with {:ok, port} <- :socket.open(17, 3, 3),
         :ok <-
           :socket.bind(port, %{
             family: 17,
             addr: <<3::size(16), eth_ifindex::size(32)-native, 0::size(112)>>
           }) do
      state = %State{
        callback: callback,
        port: port,
        eth_ifname: eth_ifname,
        eth_ifindex: eth_ifindex,
        eth_mac: eth_mac,
        opts: opts
      }

      log_debug(fn ->
        "BacEthTransport: Started on #{inspect(self())} with " <>
          "ethernet interface " <> eth_ifname
      end)

      {:ok, state, {:continue, :receive}}
    else
      {:error, err} ->
        {:stop, err}
    end
  end

  @doc false
  def handle_continue(:receive, %State{} = state) do
    {type, new_state} =
      case :socket.recv(state.port, 1600, [], 0) do
        {:ok,
         <<dst_mac::binary-size(6), src_mac::binary-size(6), len::size(16), 0x82, 0x82, 0x03,
           payload::binary>>} ->
          {:noreply,
           handle_packet(
             dst_mac,
             src_mac,
             if(byte_size(payload) > len, do: binary_part(payload, 0, len), else: payload),
             state
           )}

        # Ignore non-BACnet frames
        {:ok, _term} ->
          {:noreply, state}

        {:error, :timeout} ->
          {:noreply, state}

        {:error, _err} = err ->
          {:stop, err}
      end

    {type, new_state, if(type == :stop, do: state, else: @receive_timeout)}
  end

  @doc false
  def handle_call(:close, _from, %State{} = state) do
    log_debug("BacEthTransport: Received close request")

    :socket.close(state.port)
    {:stop, :normal, :ok, state}
  end

  def handle_call(:get_local_address, _from, %State{} = state) do
    log_debug("BacEthTransport: Received get_local_address request")
    {:reply, state.eth_mac, state, {:continue, :receive}}
  end

  def handle_call(:get_portal, _from, %State{} = state) do
    log_debug("BacEthTransport: Received get_portal request")

    {:reply, {state.port, state.eth_ifindex, state.eth_mac}, state, {:continue, :receive}}
  end

  def handle_call(_call, _from, state) do
    {:noreply, state, {:continue, :receive}}
  end

  @doc false
  def handle_cast(_cast, %State{} = state) do
    {:noreply, state, {:continue, :receive}}
  end

  @doc false
  def handle_info(:timeout, %State{} = state) do
    {:noreply, state, {:continue, :receive}}
  end

  def handle_info(_info, %State{} = state) do
    {:noreply, state, {:continue, :receive}}
  end

  defp handle_packet(dst_mac, src_mac, _data, %State{eth_mac: eth_mac} = state)
       when dst_mac not in [@broadcast_addr, eth_mac] or src_mac == eth_mac do
    # Ignore any packets that are from us or not sent to us (not broadcast or our MAC as destination)
    state
  end

  defp handle_packet(dst_mac, src_mac, data, %State{} = state) do
    log_debug(fn ->
      "BacEthTransport: Received IEEE 802.3 packet from " <>
        "#{inspect(dst_mac)} with data length #{byte_size(data)}"
    end)

    case decode_packet(data, dst_mac, src_mac) do
      {:ok, decoded} ->
        after_decode_fanout_cb(state, decoded, src_mac)

      {:error, err} ->
        Logger.warning(
          "BacEthTransport: Got error while decoding IEEE 802.3 packet, error: #{inspect(err)}"
        )

      {:ignore, reason} ->
        log_debug(fn ->
          "BacEthTransport: Discards IEEE 802.3 packet, reason: #{inspect(reason)}"
        end)
    end

    state
  end

  #### BACnet/Ethernet Frame Parsing ####

  # Do not accept NPCI with hopcount = 0, this signifies a non-conformant BACnet router
  defguardp is_valid_hopcount(hopcount)
            when is_nil(hopcount) or (is_integer(hopcount) and hopcount > 0)

  # Parses NSDU, it will return the raw APDU data to be consumed
  @spec decode_packet(binary(), binary(), binary()) ::
          {:ok, {:bvlc, bvlc :: Protocol.bvlc()}}
          | {:ok,
             {:network, bvlc :: Protocol.bvlc(), npci :: NPCI.t(),
              nsdu :: Protocol.NetworkLayerProtocolMessage.t()}}
          | {:ok, {:apdu, bvlc :: Protocol.bvlc(), npci :: NPCI.t(), apdu :: binary()}}
          | {:error, term()}
          | {:ignore, term()}
  defp decode_packet(data, dst_mac, src_mac)

  defp decode_packet(data, dst_mac, _src_mac) do
    bvlc =
      if(dst_mac == get_broadcast_address(self()),
        do: :original_broadcast,
        else: :original_unicast
      )

    with {:ok, {%NPCI{hopcount: hopcount} = npci, nsdu_data}} when is_valid_hopcount(hopcount) <-
           Protocol.decode_npci(data),
         {:ok, {type, nsdu_data}} <- Protocol.decode_npdu(npci, nsdu_data) do
      {:ok, {type, bvlc, npci, nsdu_data}}
    else
      {:ok, {%NPCI{} = _npci, _nsdu_data}} -> {:ignore, :invalid_hopcount}
      {:error, _err} = err -> err
    end
  end

  #### Helpers ####

  # Spawns a new task (either supervisored or not) and invokes the function,
  # ignoring any errors that may occur by the callback
  @spec spawn_task(State.t(), tuple(), term(), fun()) :: any()
  defp spawn_task(state, data, source_addr, fun)

  defp spawn_task(%State{opts: %{supervisor: sup}} = state, data, source_addr, fun)
       when not is_nil(sup) and is_function(fun, 3) do
    Task.Supervisor.start_child(sup, fn ->
      fun.(source_addr, data, {state.port, state.eth_ifindex, state.eth_mac})
    end)
  end

  defp spawn_task(%State{} = state, data, source_addr, fun) when is_function(fun, 3) do
    Task.start(fn -> fun.(source_addr, data, {state.port, state.eth_ifindex, state.eth_mac}) end)
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
          send(
            pid,
            {:bacnet_transport, @transport_protocol, source_addr, data,
             {state.port, state.eth_ifindex, state.eth_mac}}
          )
        catch
          # Ignore any exception coming from send/2 (an "invalid" destination raises! [i.e. an atom but it's not registered])
          _type, _err -> :ok
        end

      fun when is_function(fun, 3) ->
        spawn_task(state, data, source_addr, fun)
    end
  end

  # Get the first ethernet interface of the system
  @spec local_first_eth_ifname() :: binary() | nil
  defp local_first_eth_ifname() do
    case :net.getifaddrs(%{family: :inet, flags: :any}) do
      {:ok, [ifn | _tl] = _ifaddrs} ->
        :binary.list_to_bin(ifn.name)

      _else ->
        nil
    end
  end

  # Get the interface index (required for :socket.sendto/4)
  @spec get_ifindex_for_ifname(binary()) :: {ifindex :: pos_integer(), mac :: binary} | nil
  defp get_ifindex_for_ifname(ifname) do
    ifname1 = :binary.bin_to_list(ifname)

    case :inet.getifaddrs() do
      {:ok, ifaddrs} ->
        ifaddrs
        |> Stream.with_index(1)
        |> Enum.find_value(fn
          {{^ifname1, data}, index} ->
            if hwaddr = Keyword.get(data, :hwaddr), do: {index, :binary.list_to_bin(hwaddr)}

          _else ->
            nil
        end)

      _else ->
        nil
    end
  end

  defp validate_open_opts(opts) do
    case opts[:eth_ifname] do
      nil ->
        :ok

      term when is_binary(term) ->
        :ok

      term ->
        raise ArgumentError,
              "open/2 expected eth_ifname to be a binary, " <>
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
