defmodule BACnet.Stack.BBMD do
  # TODO: Docs
  # TODO: Allow to "pause" Foreign Device Registration and reject register requests with NAK

  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.BvlcForwardedNPDU
  alias BACnet.Protocol.BvlcFunction
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NetworkLayerProtocolMessage
  alias BACnet.Protocol.NPCI
  alias BACnet.Stack.Client
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [log_debug: 1]

  require Constants
  require Logger

  use GenServer

  defmodule ClientRef do
    @moduledoc false

    @type t :: %__MODULE__{
            ref: Process.dest() | GenServer.server(),
            transport_module: module(),
            transport: TransportBehaviour.transport(),
            portal: TransportBehaviour.portal(),
            network_number: NetworkLayerProtocolMessage.dnet(),
            ip_addr: {:inet.ip_address(), :inet.port_number()},
            broadcast_addr: {:inet.ip_address(), :inet.port_number()}
          }

    @keys [
      :ref,
      :transport_module,
      :transport,
      :portal,
      :network_number,
      :ip_addr,
      :broadcast_addr
    ]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            bdt: [BroadcastDistributionTableEntry.t()],
            clients: %{
              optional(NetworkLayerProtocolMessage.dnet()) => BACnet.Stack.BBMD.ClientRef.t()
            },
            registrations: %{
              optional({:inet.ip_address(), :inet.port_number()}) =>
                BACnet.Stack.BBMD.Registration.t()
            },
            opts: %{
              :ttl => pos_integer()
            }
          }

    @keys [:bdt, :clients, :registrations, :opts]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule Registration do
    @moduledoc false

    @type t :: %__MODULE__{
            client: BACnet.Stack.BBMD.ClientRef.t(),
            target: {:inet.ip_address(), :inet.port_number()},
            state: :alive | :waiting_for_ack | :uninitialized,
            timer: reference(),
            expires_at: NaiveDateTime.t() | nil
          }

    @keys [:client, :target, :state, :timer, :expires_at]
    @enforce_keys @keys
    defstruct @keys
  end

  # Checks whether pid is Process.dest()
  defguardp is_dest(pid)
            when is_atom(pid) or is_pid(pid) or is_port(pid) or
                   (is_tuple(pid) and tuple_size(pid) == 2 and is_atom(elem(pid, 0)) and
                      is_atom(elem(pid, 1)))

  # Checks whether pid is GenServer.server()
  defguardp is_server(pid)
            when is_dest(pid) or
                   (is_tuple(pid) and tuple_size(pid) == 3 and is_atom(elem(pid, 0)))

  @typedoc """
  Represents a `BACnet.Stack.Client` process and `BACnet.Stack.TransportBehaviour` module relations.
  """
  @type client ::
          {client :: Process.dest() | GenServer.server(), transport_module :: module(),
           transport :: TransportBehaviour.transport(), portal :: TransportBehaviour.portal()}

  @typedoc """
  Valid start options. For a description of each, see `start_link/1`.
  """
  @type start_option ::
          {:bdt, [BroadcastDistributionTableEntry.t()]}
          | {:clients, %{optional(NetworkLayerProtocolMessage.dnet()) => client()}}
          | GenServer.option()

  @typedoc """
  List of start options.
  """
  @type start_options :: [start_option()]

  @doc """
  Starts and links the BACnet Broadcast Management Device.

  The following options are available, in addition to `t:GenServer.options/0`:
    - `bdt: [BroadcastDistributionTableEntry.t()]` - Optional. The Broadcast Distribution Table to distribute broadcasts.
    - `clients: %{optional(NetworkLayerProtocolMessage.dnet()) => client()}` - Required. A map of clients with their network number as key.
      They're used to receive and send BACnet BVLC messages. It does not act as a router.
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {opts2, genserver_opts} = Keyword.split(opts, [:bdt, :clients])

    validate_start_link_opts(opts2)

    clients =
      Enum.reduce(Keyword.fetch!(opts2, :clients), %{}, fn {dnet, _client} = ref, acc ->
        case make_client_ref(ref) do
          {:ok, ref2} -> Map.put(acc, dnet, ref2)
          _else -> acc
        end
      end)

    GenServer.start_link(__MODULE__, {clients, Map.new(opts2)}, genserver_opts)
  end

  @doc false
  def init({clients, opts}) do
    new_opts =
      opts
      |> Map.drop([:bdt, :clients])
      |> Map.put_new(:ttl, 60)

    state = %State{
      bdt: Map.get(opts, :bdt, []),
      clients: clients,
      registrations: %{},
      opts: new_opts
    }

    # Subscribe to all clients for notifications (we only want BVLC)
    for {client, _mod, _transport, _portal} <- state.clients do
      GenServer.call(client, {:subscribe, self()})
    end

    log_debug(fn -> "BBMD: Started on #{inspect(self())}" end)
    {:ok, state}
  end

  @doc false
  def handle_info(
        {:bacnet_transport, _protocol_id, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
            data: fd_ttl
          } = _bvlc}, portal},
        %State{} = state
      ) do
    # We got a BVLC function (register foreign device) as a server, handle it
    log_debug(fn ->
      "BBMD: Received BVLC Register-Foreign-Device from source " <> format_ip(source_address)
    end)

    new_state =
      case Enum.find(state.clients, fn
             %ClientRef{portal: ^portal} -> true
             _else -> false
           end) do
        nil ->
          state

        %ClientRef{transport_module: trans_mod} = client_ref ->
          # Cancel timer for Foreign Device if present, registration gets overwritten later
          case Map.fetch(state.registrations, source_address) do
            {:ok, %Registration{} = reg} -> Process.cancel_timer(reg.timer)
            :error -> :ok
          end

          # 30 seconds is the grace period as defined by ASHRAE 135 Annex J.5.2.3
          reg = %Registration{
            client: client_ref,
            target: source_address,
            state: :active,
            timer:
              Process.send_after(self(), {:fd_reg_timer, source_address}, (fd_ttl + 30) * 1_000),
            expires_at: NaiveDateTime.add(NaiveDateTime.utc_now(), fd_ttl, :second)
          }

          new_state =
            update_in(state, [Access.key(:registrations), source_address], fn _val -> reg end)

          trans_mod.send(
            portal,
            source_address,
            <<Constants.macro_by_name(:bvlc_result_format, :successful_completion)>>,
            npci: false
          )

          new_state
      end

    {:noreply, new_state}
  end

  def handle_info(
        {:bacnet_client, _reply_ref, apdu,
         {{orig_ip, orig_port} = source_address, :distribute_broadcast_to_network,
          %NPCI{} = npci}, _client},
        %State{} = state
      ) do
    # We got an APDU payload to distribute
    log_debug(fn ->
      "BBMD: Received APDU to distribute from source " <> format_ip(source_address)
    end)

    case BvlcForwardedNPDU.encode(%BvlcForwardedNPDU{
           originating_ip: orig_ip,
           originating_port: orig_port
         }) do
      {:ok, new_bvlc} ->
        for %BroadcastDistributionTableEntry{} = bdt <- state.bdt do
          log_debug(fn ->
            "BBMD: Distribute APDU to BDT entry #{inspect(bdt.ip)}/#{inspect(bdt.mask)} transport"
          end)

          with %CIDR{} = bdt_cidr <-
                 CIDR.parse("#{format_ip(bdt.ip)}/#{calculate_bitlength(bdt.mask)}") do
            client =
              Enum.find_value(state.clients, fn
                {_dnet, %ClientRef{ip_addr: {ip, _port}} = client_ref} ->
                  match?({:ok, true}, CIDR.match(bdt_cidr, ip)) && client_ref

                _else ->
                  false
              end)

            if client do
              %ClientRef{} = client

              # Distribute APDU to network IF destination is absent OR destination equals to 65535 (global broadcast) or the network number
              if npci.destination == nil or
                   npci.destination.net in [nil, 65_535, client.network_number] do
                log_debug(fn ->
                  "BBMD: Distribute APDU to client with IP " <> format_ip(client.ip_addr)
                end)

                case Client.send(client.ref, client.broadcast_addr, apdu,
                       bvlc: new_bvlc,
                       npci: npci
                     ) do
                  :ok ->
                    :ok

                  {:error, error} ->
                    Logger.error(fn ->
                      "BBMD has encountered a transport error " <>
                        "while trying to distribute APDI to network, got: " <>
                        inspect(error)
                    end)

                    :ok
                end
              end
            end
          end
        end

      {:error, error} ->
        Logger.warning(fn ->
          "Invalid source_address for distribute APDU" <>
            ", error: " <>
            inspect(error) <>
            ", got: " <> format_ip(source_address)
        end)
    end

    {:noreply, state}
  end

  def handle_info({:fd_reg_timer, key}, %State{} = state) do
    # FD registration timer triggered
    # We need to check if the FD registration has expired and remove it
    log_debug(fn -> "BBMD: Received fd_reg_timer request for #{inspect(key)}" end)

    new_state =
      case Map.fetch(state.registrations, key) do
        {:ok, %Registration{} = reg} ->
          if reg.state != :active or
               NaiveDateTime.compare(reg.expires_at, NaiveDateTime.utc_now()) != :gt do
            Logger.debug(fn ->
              "BBMD detected that Foreign Device registration for target " <>
                inspect(reg.target) <> " has expired, removing"
            end)

            Process.cancel_timer(reg.timer)
            %State{state | registrations: Map.delete(state.registrations, key)}
          else
            state
          end

        :error ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @spec make_client_ref({non_neg_integer(), client()}) :: {:ok, ClientRef.t()} | {:error, term()}
  defp make_client_ref(dnet_ref)

  defp make_client_ref({dnet, {client, trans_mod, transport, portal}})
       when is_integer(dnet) and dnet in 1..65534 and
              is_server(client) and
              is_atom(trans_mod) do
    address = trans_mod.get_local_address(transport)

    if match?({{_a, _b, _c, _d}, _port}, address) do
      {:ok,
       %ClientRef{
         ref: client,
         transport_module: trans_mod,
         transport: transport,
         portal: portal,
         network_number: dnet,
         ip_addr: address,
         broadcast_addr: trans_mod.get_broadcast_address(transport)
       }}
    else
      {:error, :invalid_local_address}
    end
  end

  defp make_client_ref(_ref), do: {:error, :invalid_client}

  defp validate_start_link_opts(opts) do
    case opts[:bdt] do
      nil ->
        :ok

      term ->
        unless is_list(term) and Enum.all?(term, &is_struct(&1, BroadcastDistributionTableEntry)) do
          raise ArgumentError,
            message:
              "start_link/1 expected bdt to be a list of BroadcastDistributionTableEntry structs, " <>
                "got: #{inspect(term)}"
        end
    end

    clients = opts[:clients]

    unless is_map(clients) and Enum.all?(clients, &match?({:ok, _client}, make_client_ref(&1))) do
      raise ArgumentError,
        message:
          "start_link/1 expected clients to be a map of destination number to tuple (complex), " <>
            "got: #{inspect(clients)}"
    end
  end

  # Format IP to x.x.x.x or x.x.x.x:y
  @spec format_ip({:inet.ip4_address(), :inet.port_number()} | :inet.ip4_address() | term()) ::
          String.t()
  defp format_ip(ip_or_ip_port)

  defp format_ip({one, two, three, four} = _ip_or_ip_port) do
    "#{one}.#{two}.#{three}.#{four}"
  end

  defp format_ip({{one, two, three, four}, port} = _ip_or_ip_port) do
    "#{one}.#{two}.#{three}.#{four}:#{port}"
  end

  defp format_ip(term) do
    inspect(term)
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
end
