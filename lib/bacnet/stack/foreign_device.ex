defmodule BACnet.Stack.ForeignDevice do
  # TODO: Docs

  alias BACnet.Protocol.BvlcFunction
  alias BACnet.Protocol.BvlcResult
  alias BACnet.Protocol.Constants
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [log_debug: 1]

  require Constants
  require Logger

  use GenServer

  @bbmd_fd_reg_timer 10_000

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            bbmd: {:inet.ip_address(), :inet.port_number()},
            client: Process.dest() | GenServer.server(),
            transport_module: module(),
            transport: TransportBehaviour.transport(),
            portal: TransportBehaviour.portal(),
            ip_addr: {:inet.ip_address(), :inet.port_number()},
            broadcast_addr: {:inet.ip_address(), :inet.port_number()},
            registration: BACnet.Stack.ForeignDevice.Registration.t(),
            opts: %{
              :ttl => pos_integer()
            }
          }

    @keys [
      :bbmd,
      :client,
      :transport_module,
      :transport,
      :portal,
      :ip_addr,
      :broadcast_addr,
      :registration,
      :opts
    ]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule Registration do
    @moduledoc false

    @type t :: %__MODULE__{
            bbmd: {:inet.ip_address(), :inet.port_number()},
            state: :alive | :waiting_for_ack | :uninitialized,
            timer: reference(),
            expires_at: NaiveDateTime.t() | nil
          }

    @keys [:bbmd, :state, :timer, :expires_at]
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
          {:bbmd, {:inet.ip_address(), port :: 1..65_535}}
          | {:client, client()}
          | {:ttl, pos_integer()}
          | GenServer.option()

  @typedoc """
  List of start options.
  """
  @type start_options :: [start_option()]

  @doc """
  Starts and links the BACnet Foreign Device.

  The following options are available,
  in addition to `t:GenServer.options/0`:
    - `bbmd: {:inet.ip_address(), 1..65_535}` - Required. The BBMD address to register itself as Foreign Device with.
    - `client: client()` - Required. The client & transport information.
    - `ttl: pos_integer()` - Optional. The time in seconds until the Foreign Device Registration expires. Defaults to `60`.
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {opts2, genserver_opts} = Keyword.split(opts, [:bbmd, :client, :ttl])

    validate_start_link_opts(opts2)

    GenServer.start_link(__MODULE__, Map.new(opts2), genserver_opts)
  end

  @doc false
  def init(opts) do
    new_opts =
      opts
      |> Map.drop([:bbmd, :client])
      |> Map.put_new(:ttl, 60)

    bbmd = Map.fetch!(opts, :bbmd)
    {client, trans_mod, transport, portal} = Map.fetch!(opts, :client)

    state = %State{
      bbmd: bbmd,
      client: client,
      transport_module: trans_mod,
      transport: transport,
      portal: portal,
      ip_addr: trans_mod.get_local_address(transport),
      broadcast_addr: trans_mod.get_broadcast_address(transport),
      registration: %Registration{
        bbmd: bbmd,
        state: :uninitialized,
        timer: make_ref(),
        expires_at: nil
      },
      opts: new_opts
    }

    # Subscribe to BACnet.Stack.Client for notifications (we only want BVLC)
    GenServer.call(client, {:subscribe, self()})

    log_debug(fn -> "ForeignDevice: Started on #{inspect(self())}" end)
    {:ok, state, {:continue, :bbmd_fd_reg}}
  end

  @doc false
  def handle_continue(:bbmd_fd_reg, %State{} = state) do
    # Send the Foreign Device Registration to each defined BBMD,
    # we do not care about the operation itself, since we have a timeout anyway,
    # which will fire when we don't receive a reply
    new_state =
      case send_fd_registration(state) do
        {:ok, reg} ->
          Logger.debug(fn ->
            "ForeignDevice: Sent Foreign Device registration to BBMD " <> inspect(state.bbmd)
          end)

          %State{state | registration: reg}

        {:error, error} ->
          Logger.error(fn ->
            "ForeignDevice detected an error while trying to send Foreign Device Registration, got: " <>
              inspect(error)
          end)

          state
      end

    {:noreply, new_state}
  end

  @doc false
  def handle_info(
        {:bacnet_transport, _protocol_id, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device)
          } = _bvlc}, bvlc_portal},
        %State{transport_module: trans_mod, portal: portal} = state
      )
      when bvlc_portal == portal do
    # We got a BVLC function (register foreign device) and we are the meant recipient, return NAK
    log_debug(fn ->
      "ForeignDevice: Received BVLC Register-Foreign-Device as client from source " <>
        format_ip(source_address) <>
        ", returning NAK"
    end)

    nak_reply = [
      Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
      Constants.macro_by_name(:bvlc_result_format, :register_foreign_device_nak)
    ]

    trans_mod.send(portal, source_address, nak_reply, skip_headers: true)

    {:noreply, state}
  end

  def handle_info(
        {:bacnet_transport, _protocol_id, source_address,
         {:bvlc,
          %BvlcResult{
            result_code: Constants.macro_assert_name(:bvlc_result_format, :successful_completion)
          } = _bvlc}, _portal},
        %State{registration: %Registration{state: :waiting_for_ack} = reg} = state
      ) do
    # We got a BVLC positive result, handle it
    # Change the state to alive and start new timer to check aliveness
    log_debug(fn ->
      "ForeignDevice: Received BVLC positive Foreign Device registration ACK from BBMD " <>
        format_ip(source_address)
    end)

    Process.cancel_timer(reg.timer)

    new_reg = %Registration{
      reg
      | state: :active,
        timer:
          Process.send_after(
            self(),
            :fd_reg_timer,
            Map.fetch!(state.opts, :ttl) * 1_000
          ),
        expires_at:
          NaiveDateTime.add(NaiveDateTime.utc_now(), Map.fetch!(state.opts, :ttl), :second)
    }

    new_state = %State{state | registration: new_reg}

    {:noreply, new_state}
  end

  def handle_info(
        {:bacnet_transport, _protocol_id, source_address,
         {:bvlc,
          %BvlcResult{
            result_code:
              Constants.macro_assert_name(:bvlc_result_format, :register_foreign_device_nak)
          } = _bvlc}, _portal},
        %State{registration: %Registration{state: :waiting_for_ack} = reg} = state
      ) do
    # We got a BVLC negative result, handle it
    # We will change the state to uninitialized and retry it later
    log_debug(fn ->
      "ForeignDevice: Received BVLC negative Foreign Device registration ACK from BBMD " <>
        format_ip(source_address)
    end)

    Process.cancel_timer(reg.timer)

    new_reg = %Registration{
      reg
      | state: :uninitialized,
        timer: Process.send_after(self(), :fd_reg_retry, @bbmd_fd_reg_timer),
        expires_at: nil
    }

    new_state = %State{state | registration: new_reg}

    {:noreply, new_state}
  end

  def handle_info(
        :fd_reg_retry,
        %State{registration: %Registration{state: :uninitialized}} = state
      ) do
    # FD registration retry timer triggered
    # Retry FD registration if it still exists (it may have been removed)
    log_debug(fn -> "ForeignDevice: Received fd_reg_retry request for #{inspect(state.bbmd)}" end)

    new_state =
      case send_fd_registration(state) do
        {:ok, reg} ->
          Logger.debug(fn ->
            "ForeignDevice: Sent Foreign Device registration to BBMD " <> inspect(state.bbmd)
          end)

          %State{state | registration: reg}

        {:error, error} ->
          Logger.error(fn ->
            "ForeignDevice detected an error while trying to send Foreign Device registration " <>
              "to BBMD #{inspect(state.bbmd)}, got: " <> inspect(error)
          end)

          state
      end

    {:noreply, new_state}
  end

  def handle_info(:fd_reg_timer, %State{registration: %Registration{} = reg} = state) do
    # FD registration timer triggered
    # We need to check if the FD registration was completed, timed out or expired
    log_debug(fn -> "ForeignDevice: Received fd_reg_timer request for #{inspect(state.bbmd)}" end)

    new_state =
      if reg.state != :active or
           NaiveDateTime.compare(reg.expires_at, NaiveDateTime.utc_now()) != :gt do
        if reg.state != :active do
          Logger.warning(fn ->
            "ForeignDevice detected that Foreign Device registration " <>
              "on BBMD #{inspect(state.bbmd)} has timed out, retrying"
          end)
        else
          Logger.debug(fn ->
            "ForeignDevice detected that Foreign Device registration " <>
              "on BBMD #{inspect(state.bbmd)} is soon expiring, renewing"
          end)
        end

        case send_fd_registration(state) do
          {:ok, reg} ->
            Logger.debug(fn ->
              "ForeignDevice: Sent Foreign Device registration to BBMD " <> inspect(state.bbmd)
            end)

            %State{state | registration: reg}

          {:error, error} ->
            Logger.error(fn ->
              "ForeignDevice detected an error while trying to send Foreign Device registration " <>
                "to BBMD #{inspect(state.bbmd)}, got: " <> inspect(error)
            end)

            state
        end
      else
        state
      end

    {:noreply, new_state}
  end

  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @spec validate_client_ref(client()) ::
          :ok | {:error, term()}
  defp validate_client_ref(client_ref)

  defp validate_client_ref({client, trans_mod, transport, _portal})
       when is_server(client) and is_atom(trans_mod) do
    if match?({{_a, _b, _c, _d}, _port}, trans_mod.get_local_address(transport)) do
      :ok
    else
      {:error, :invalid_local_address}
    end
  end

  defp validate_client_ref(_ref), do: {:error, :invalid_client}

  @spec send_fd_registration(State.t()) ::
          {:ok, Registration.t()} | {:error, term()}
  defp send_fd_registration(
         %State{bbmd: bbmd, transport_module: trans_mod, portal: portal} = state
       ) do
    with {:ok, {fd_reg_bvlc, fd_reg_data}} <-
           BvlcFunction.encode(%BvlcFunction{
             function:
               Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
             data: Map.fetch!(state.opts, :ttl)
           }),
         :ok <- trans_mod.send(portal, bbmd, fd_reg_data, bvlc: <<fd_reg_bvlc>>, npci: false) do
      {:ok,
       %Registration{
         bbmd: bbmd,
         state: :waiting_for_ack,
         timer: Process.send_after(self(), :fd_reg_timer, @bbmd_fd_reg_timer),
         expires_at: nil
       }}
    end
  end

  defp validate_start_link_opts(opts) do
    unless is_ip_port(opts[:bbmd]) do
      raise ArgumentError,
        message:
          "start_link/1 expected bbmd to be a BBMD IPv4 address and port tuple, " <>
            "got: #{inspect(opts[:bbmd])}"
    end

    unless :ok == validate_client_ref(opts[:client]) do
      raise ArgumentError,
        message:
          "start_link/1 expected client to be a client information tuple, " <>
            "got: #{inspect(opts[:client])}"
    end

    case opts[:ttl] do
      nil ->
        :ok

      term when is_integer(term) and term > 0 ->
        :ok

      term ->
        raise ArgumentError,
          message: "start_link/1 expected ttl to be a positive integer, got: #{inspect(term)}"
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

  # Checks if given argument is an IP:Port tuple
  defp is_ip_port({{ip_a, ip_b, ip_c, ip_d}, port})
       when is_integer(ip_a) and ip_a in 1..255 and is_integer(ip_b) and ip_b in 0..255 and
              is_integer(ip_c) and ip_c in 0..255 and is_integer(ip_d) and ip_d in 1..254 and
              is_integer(port) and port in 1..65_535,
       do: true

  defp is_ip_port(_term), do: false
end
