defmodule BACnet.Test.Stack.FakeTransport do
  @moduledoc false

  @behaviour BACnet.Stack.TransportBehaviour

  use GenServer

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :owner, self())
    {gen_opts, opts} = Keyword.split(opts, [:name, :debug, :spawn_opt, :hibernate_after])
    GenServer.start_link(__MODULE__, Map.new(opts), gen_opts)
  end

  @impl true
  def bacnet_protocol(), do: :bacnet_ipv4

  @impl true
  def max_apdu_length(), do: 480

  @impl true
  def max_npdu_length(), do: 501

  @impl true
  def max_ext_apdu_length(), do: 1476

  @impl true
  def max_ext_npdu_length(), do: 1497

  @impl true
  def open(callback, opts \\ []) do
    start_link(Keyword.put(opts, :callback, callback))
  end

  @impl true
  def close(transport) when is_pid(transport) do
    GenServer.call(transport, :close)
  end

  @impl true
  def get_broadcast_address(transport) do
    GenServer.call(transport, :get_broadcast_address)
  end

  @impl true
  def get_local_address(transport) do
    GenServer.call(transport, :get_local_address)
  end

  @impl true
  def get_portal(transport), do: transport

  @impl true
  def destination_routed?(_transport, {:routed, _destination}), do: true

  def destination_routed?(transport, destination) when is_pid(transport) do
    GenServer.call(transport, {:destination_routed?, destination})
  end

  def destination_routed?(_transport, _destination), do: false

  @doc false
  def set_routed(transport, destinations) when is_pid(transport) and is_list(destinations) do
    GenServer.call(transport, {:set_routed, destinations})
  end

  @impl true
  def valid_destination?(:invalid), do: false
  def valid_destination?({:raise_valid, message}), do: raise(ArgumentError, message)
  def valid_destination?(_destination), do: true

  @impl true
  def send(portal, destination, data, opts \\ []) when is_pid(portal) do
    GenServer.call(portal, {:send, destination, data, opts})
  end

  @impl true
  def reply_postponed(portal, destination, opts \\ []) when is_pid(portal) do
    GenServer.call(portal, {:reply_postponed, destination, opts})
  end

  @doc false
  def set_send_result(transport, result) when is_pid(transport) do
    GenServer.call(transport, {:set_send_result, result})
  end

  @doc false
  def scripted(term), do: term

  @doc false
  def set_crash_broadcast(transport, crash?) when is_pid(transport) and is_boolean(crash?) do
    GenServer.call(transport, {:set_crash_broadcast, crash?})
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       owner: Map.fetch!(opts, :owner),
       broadcast: Map.get(opts, :broadcast, :broadcast),
       local: Map.get(opts, :local, :local),
       sent: [],
       postponed: [],
       send_result: Map.get(opts, :send_result, :ok),
       crash_broadcast: false,
       routed: MapSet.new(Map.get(opts, :routed, []))
     }}
  end

  @impl true
  def handle_call(:close, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call(:get_broadcast_address, _from, %{crash_broadcast: true}) do
    raise "broadcast unavailable"
  end

  def handle_call(:get_broadcast_address, _from, state) do
    {:reply, state.broadcast, state}
  end

  def handle_call({:set_crash_broadcast, crash?}, _from, state) do
    {:reply, :ok, %{state | crash_broadcast: crash?}}
  end

  def handle_call(:get_local_address, _from, state) do
    {:reply, state.local, state}
  end

  def handle_call({:set_send_result, result}, _from, state) do
    {:reply, :ok, %{state | send_result: result}}
  end

  def handle_call({:set_routed, destinations}, _from, state) do
    {:reply, :ok, %{state | routed: MapSet.new(destinations)}}
  end

  def handle_call({:destination_routed?, destination}, _from, state) do
    {:reply, MapSet.member?(state.routed, destination), state}
  end

  def handle_call({:send, destination, data, opts}, _from, state) do
    send(state.owner, {:fake_transport_send, destination, data, opts})
    state = %{state | sent: [{destination, data, opts} | state.sent]}

    result =
      case state.send_result do
        fun when is_function(fun, 3) -> fun.(destination, data, opts)
        other -> other
      end

    {:reply, result, state}
  end

  def handle_call({:reply_postponed, destination, opts}, _from, state) do
    send(state.owner, {:fake_transport_postponed, destination, opts})
    state = %{state | postponed: [{destination, opts} | state.postponed]}

    result =
      case destination do
        {:postponed, :no_reply_pending} -> {:error, :no_reply_pending}
        {:postponed, :not_expecting} -> {:error, :destination_is_not_expecting_reply}
        {:postponed, reason} -> {:error, reason}
        _other -> :ok
      end

    {:reply, result, state}
  end
end

defmodule BACnet.Test.Stack.FakeTransport.Limited do
  @moduledoc false

  @behaviour BACnet.Stack.TransportBehaviour

  defdelegate bacnet_protocol(), to: BACnet.Test.Stack.FakeTransport
  defdelegate max_apdu_length(), to: BACnet.Test.Stack.FakeTransport
  defdelegate max_npdu_length(), to: BACnet.Test.Stack.FakeTransport
  defdelegate open(callback, opts), to: BACnet.Test.Stack.FakeTransport
  defdelegate close(transport), to: BACnet.Test.Stack.FakeTransport
  defdelegate get_broadcast_address(transport), to: BACnet.Test.Stack.FakeTransport
  defdelegate get_local_address(transport), to: BACnet.Test.Stack.FakeTransport
  defdelegate get_portal(transport), to: BACnet.Test.Stack.FakeTransport
  defdelegate destination_routed?(transport, destination), to: BACnet.Test.Stack.FakeTransport
  defdelegate valid_destination?(destination), to: BACnet.Test.Stack.FakeTransport
  defdelegate send(portal, destination, data, opts), to: BACnet.Test.Stack.FakeTransport
  defdelegate scripted(term), to: BACnet.Test.Stack.FakeTransport
end
