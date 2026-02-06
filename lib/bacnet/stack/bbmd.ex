defmodule BACnet.Stack.BBMD do
  @moduledoc """
  The BBMD module is responsible for acting as a BACnet/IPv4 Broadcast Management Device (BBMD).

  It will subscribe for BACnet/IP Virtual Link Layer messages from the `BACnet.Stack.Client`
  and act accordingly on BBMD-specific BVLC messages.
  It will handle both Broadcast Distribution according to the Broadcast Distribution Table (BDT)
  on local broadcast and Foreign Device Registration, including distributing broadcasts from those.

  It allows to read the BDT and registered Foreign Devices through BVLC messages and
  the module functions. New Foreign Device Registrations may be "paused" and "resumed" at any time.
  Pausing Foreign Device Registrations will mean that new Register messages will be rejected.

  BBMDs allow a Foreign Device (a device not residing on the same subnet) to send broadcasts
  to the network the BBMD is connected to. More specifically, the Foreign Device will tell the BBMD
  to distribute a specific APDU as broadcast and the BBMD will forward that APDU as broadcast
  on the network. BACnet devices on that network will then respond with `I-Am` APDUs directly
  to that device. As such, proper network routing is required for this to work.

  For each network (client/transport) one BBMD process is required,
  if Foreign Devices should be served (enables to discover local BACnet devices).
  **Only one BBMD is allowed on a BACnet network.**
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.BvlcForwardedNPDU
  alias BACnet.Protocol.BvlcFunction
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ForeignDeviceTableEntry
  alias BACnet.Protocol.NPCI
  alias BACnet.Stack.Client
  alias BACnet.Stack.Telemetry
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [is_server: 1, log_debug: 1]

  require Constants
  require Logger

  use GenServer

  @fd_table_max_size 512

  defmodule ClientRef do
    @moduledoc """
    Internal module for `BACnet.Stack.BBMD`.

    It is used to keep track of the necessary
    client and transport information.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            ref: Client.server(),
            transport_module: module(),
            transport: TransportBehaviour.transport(),
            portal: TransportBehaviour.portal(),
            ip_addr: {:inet.ip_address(), :inet.port_number()},
            broadcast_addr: {:inet.ip_address(), :inet.port_number()}
          }

    @keys [
      :ref,
      :transport_module,
      :transport,
      :portal,
      :ip_addr,
      :broadcast_addr
    ]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule Registration do
    @moduledoc """
    Internal module for `BACnet.Stack.BBMD`.

    It is used to track registration of Foreign Device
    inside the BBMD.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            target: {:inet.ip_address(), :inet.port_number()},
            state: :active | :waiting_for_ack | :uninitialized,
            timer: reference(),
            ttl: non_neg_integer(),
            expires_at: NaiveDateTime.t() | nil
          }

    @keys [:target, :state, :timer, :ttl, :expires_at]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule State do
    @moduledoc """
    Internal module for `BACnet.Stack.BBMD`.

    It is used as `GenServer` state.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            bdt: [BroadcastDistributionTableEntry.t()],
            client: BACnet.Stack.BBMD.ClientRef.t(),
            registrations: %{
              optional({:inet.ip_address(), :inet.port_number()}) =>
                BACnet.Stack.BBMD.Registration.t()
            },
            paused: boolean(),
            opts: %{
              bdt_readonly: boolean(),
              max_fd_registrations: pos_integer(),
              proxy_mode: boolean()
            }
          }

    @keys [:bdt, :client, :registrations, :paused, :opts]
    @enforce_keys @keys
    defstruct @keys
  end

  # Checks whether the given argument is a :inet.ip4_address()
  defguardp is_ip4_addr(ip)
            when is_tuple(ip) and tuple_size(ip) == 4 and is_integer(elem(ip, 0)) and
                   elem(ip, 0) in 0..255 and
                   is_integer(elem(ip, 1)) and elem(ip, 1) in 0..255 and
                   is_integer(elem(ip, 2)) and elem(ip, 2) in 0..255 and
                   is_integer(elem(ip, 3)) and elem(ip, 3) in 0..255

  @typedoc """
  Represents a `BACnet.Stack.Client` process. It will be used to retrieve the
  transport module, transport and portal through the `BACnet.Stack.Client` API.
  """
  @type client :: Client.server()

  @typedoc """
  Represents a server process of the BBMD module.
  """
  @type server :: GenServer.server()

  @typedoc """
  Valid start options. For a description of each, see `start_link/1`.
  """
  @type start_option ::
          {:bdt, [BroadcastDistributionTableEntry.t()]}
          | {:bdt_readonly, boolean()}
          | {:client, client()}
          | {:max_fd_registrations, pos_integer()}
          | {:override_port, 47_808..65_535}
          | {:paused, boolean()}
          | {:proxy_mode, boolean()}
          | GenServer.option()

  @typedoc """
  List of start options.
  """
  @type start_options :: [start_option()]

  @doc """
  Starts and links the BACnet Broadcast Management Device.

  The following options are available, in addition to `t:GenServer.options/0`:
    - `bdt: [BroadcastDistributionTableEntry.t()]` - Optional. The Broadcast Distribution Table to distribute broadcasts to peers.
    - `bdt_readonly: boolean()` - Optional. Whether the Broadcast Distribution Table is readonly on the BACnet side.
      By default the BDT can be written to and changed. Setting this to `true` will only allow writes through the Elixir side.
    - `client: client()` - Required. The client & transport information.
    - `max_fd_registrations: pos_integer()` - Optional. The amount of Foreign Device registrations that can be accepted
      are limited by this option (defaults to `512`). That is by design to not allow an unlimited number of registrations to be
      accumulated with a long Time-To-Live. Only up to the given number will be accepted at most concurrently,
      any further registration will be rejected and must wait until one registration times out or
      gets deleted to allow a new registration to be accepted.
      The maximum Time-To-Live is `65_535` seconds (ca. 18h 12mins), as per ASHRAE 135 J.5.2.1.
    - `override_port: 47_808..65_535` - Optional. Overrides the used broadcast port (defaults to transport port number).
    - `paused: boolean()` - Optional. Start in paused state. See also `pause_fd_registration/1` and `resume_fd_registration/1`.
    - `proxy_mode: boolean()` - Optional. This is an alternate mode to the BBMD operation as described in ASHRAE 135 Annex J.4.5.
      Instead of broadcasting received BVLL `Distribute-Broadcast-To-Network` as `Forwarded-NPDU`, it will do a regular broadcast.
      Which means the devices will respond unicast to the BBMD.
      The BBMD will forward all received `IAm` and `IHave` NPDUs to all Foreign Devices, even if the Foreign Device has not
      sent a request for `WhoIs` or the request has been long ago executed. This mode is only for development and testing purposes.
      It should not be used in production for regular BBMD operation.
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {opts2, genserver_opts} =
      Keyword.split(opts, [
        :bdt,
        :bdt_readonly,
        :client,
        :max_fd_registrations,
        :override_port,
        :paused,
        :proxy_mode
      ])

    validate_start_link_opts(opts2)

    GenServer.start_link(__MODULE__, Map.new(opts2), genserver_opts)
  end

  @doc """
  Add an entry to the Broadcast Distribution Table.
  """
  @spec add_bdt_entry(server(), BroadcastDistributionTableEntry.t()) :: :ok | {:error, term()}
  def add_bdt_entry(server, %BroadcastDistributionTableEntry{} = entry) when is_server(server) do
    unless is_ip4_addr(entry.ip) and is_integer(entry.port) and entry.port in 1..65_535 and
             is_ip4_addr(entry.mask) do
      raise ArgumentError, message: "Invalid broadcast distribution table entry"
    end

    GenServer.call(server, {:add_bdt, entry})
  end

  @doc """
  Get the Foreign Device Table.
  """
  @spec get_broadcast_distribution_table(server()) :: [BroadcastDistributionTableEntry.t()]
  def get_broadcast_distribution_table(server) when is_server(server) do
    GenServer.call(server, :get_bdt)
  end

  @doc """
  Get the Foreign Device Table.
  """
  @spec get_foreign_device_table(server()) :: [ForeignDeviceTableEntry.t()]
  def get_foreign_device_table(server) when is_server(server) do
    GenServer.call(server, :get_fd_table)
  end

  @doc """
  Pause Foreign Device Registration process.

  All new Foreign Device Registration requests will be rejected.
  Leading to "draining" of the BBMD through expiration of registrations,
  as long as expiration time (TTL) are not exorbitantly large.

  See also `resume_fd_registration/1` for resuming.
  """
  @spec pause_fd_registration(server()) :: :ok
  def pause_fd_registration(server) when is_server(server) do
    GenServer.call(server, :pause_fd_registration)
  end

  @doc """
  Removes an entry from the Broadcast Distribution Table.
  """
  @spec remove_bdt_entry(server(), BroadcastDistributionTableEntry.t()) :: :ok | {:error, term()}
  def remove_bdt_entry(server, %BroadcastDistributionTableEntry{} = entry)
      when is_server(server) do
    GenServer.call(server, {:remove_bdt, entry})
  end

  @doc """
  Removes a Foreign Device from the Foreign Device table.

  This may be used to remove known dead devices with long expiration time
  manually without having to wait for the entries to expire.
  """
  @spec remove_foreign_device(server(), ForeignDeviceTableEntry.t()) :: :ok | {:error, term()}
  def remove_foreign_device(server, %ForeignDeviceTableEntry{} = fd)
      when is_server(server) do
    GenServer.call(server, {:remove_fd_device, fd})
  end

  @doc """
  Resumes Foreign Device Registration process.

  All new Foreign Device Registration requests will be processed as normal.
  This function reverses `pause_fd_registration/1`.
  """
  @spec resume_fd_registration(server()) :: :ok
  def resume_fd_registration(server) when is_server(server) do
    GenServer.call(server, :resume_fd_registration)
  end

  @doc false
  def init(opts) do
    client = Map.fetch!(opts, :client)
    {trans_mod, transport, portal} = Client.get_transport(client)

    with {:ok, clientref} <- make_client_ref({client, trans_mod, transport, portal}, opts),
         # Subscribe to BACnet.Stack.Client for notifications
         :ok <- Client.subscribe(clientref.ref, self()) do
      actual_opts =
        opts
        |> Map.drop([:bdt, :client, :paused, :override_port])
        |> Map.put_new(:bdt_readonly, false)
        |> Map.put_new(:max_fd_registrations, @fd_table_max_size)
        |> Map.put_new(:proxy_mode, false)

      state = %State{
        bdt: Map.get(opts, :bdt, []),
        client: clientref,
        registrations: %{},
        paused: !!Map.get(opts, :paused, false),
        opts: actual_opts
      }

      log_debug(fn -> "BBMD: Started on #{inspect(self())}" end)
      {:ok, state}
    else
      err ->
        {:stop, err, %{}}
    end
  end

  @doc false
  def handle_call(:pause_fd_registration, _from, %State{} = state) do
    log_debug(fn -> "BBMD: Received pause_fd_registration request" end)

    new_state = %State{state | paused: true}
    {:reply, :ok, new_state}
  end

  def handle_call(:resume_fd_registration, _from, %State{} = state) do
    log_debug(fn -> "BBMD: Received resume_fd_registration request" end)

    new_state = %State{state | paused: false}
    {:reply, :ok, new_state}
  end

  def handle_call({:add_bdt, %BroadcastDistributionTableEntry{} = entry}, _from, %State{} = state) do
    log_debug(fn -> "BBMD: Received add_bdt request" end)

    new_state = update_in(state, [Access.key(:bdt)], fn bdts -> bdts ++ [entry] end)
    {:reply, :ok, new_state}
  end

  def handle_call(:get_bdt, _from, %State{} = state) do
    log_debug(fn -> "BBMD: Received get_bdt request" end)
    {:reply, state.bdt, state}
  end

  def handle_call(
        {:remove_bdt, %BroadcastDistributionTableEntry{} = entry},
        _from,
        %State{} = state
      ) do
    log_debug(fn -> "BBMD: Received remove_bdt request" end)

    new_state = update_in(state, [Access.key(:bdt)], fn bdts -> List.delete(bdts, entry) end)
    {:reply, :ok, new_state}
  end

  def handle_call(:get_fd_table, _from, %State{} = state) do
    log_debug(fn -> "BBMD: Received get_fd_table request" end)
    {:reply, calculate_foreign_device_table(state.registrations), state}
  end

  def handle_call({:remove_fd_device, %ForeignDeviceTableEntry{} = fd}, _from, %State{} = state) do
    log_debug(fn -> "BBMD: Received remove_fd_device request" end)

    new_state =
      update_in(state, [Access.key(:registrations)], fn regs -> Map.delete(regs, fd) end)

    {:reply, :ok, new_state}
  end

  def handle_call(:stop, _from, %State{} = state) do
    log_debug(fn -> "BBMD: Received stop request" end)
    {:stop, :normal, :ok, state}
  end

  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def handle_cast(_msg, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def handle_info(
        {:bacnet_transport, {_protocol_id, trans_mod}, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device)
          } = _bvlc}, portal},
        %State{paused: true} = state
      ) do
    # We got a BVLC function (register foreign device), however FD registration is paused
    log_debug(fn ->
      "BBMD: Received BVLC Register-Foreign-Device from source " <>
        format_ip(source_address) <>
        ", however Foreign Device registration is paused, returning NAK"
    end)

    trans_mod.send(
      portal,
      source_address,
      <<Constants.macro_by_name(:bvlc_result_format, :register_foreign_device_nak)::size(16)>>,
      bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
      npci: false
    )

    {:noreply, state}
  end

  def handle_info(
        {:bacnet_transport, {_protocol_id, trans_mod}, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device)
          } = _bvlc}, portal},
        %State{} = state
      )
      when map_size(state.registrations) >= state.opts.max_fd_registrations and
             not :erlang.is_map_key(source_address, state.registrations) do
    # We got a BVLC function (register foreign device), however we have reached max registration size
    log_debug(fn ->
      "BBMD: Received BVLC Register-Foreign-Device from source " <>
        format_ip(source_address) <>
        ", however we have reached the maximum registrations record size, returning NAK"
    end)

    trans_mod.send(
      portal,
      source_address,
      <<Constants.macro_by_name(:bvlc_result_format, :register_foreign_device_nak)::size(16)>>,
      bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
      npci: false
    )

    {:noreply, state}
  end

  def handle_info(
        {:bacnet_transport, _protocol_id, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
            data: fd_ttl
          } = _bvlc}, portal},
        %State{client: %{transport_module: trans_mod}} = state
      ) do
    # We got a BVLC function (register foreign device), handle it
    log_debug(fn ->
      "BBMD: Received BVLC Register-Foreign-Device from source " <> format_ip(source_address)
    end)

    # Cancel timer for Foreign Device if present, registration gets overwritten later
    case Map.fetch(state.registrations, source_address) do
      {:ok, %Registration{} = reg} -> Process.cancel_timer(reg.timer)
      :error -> :ok
    end

    # 30 seconds is the grace period as defined by ASHRAE 135 Annex J.5.2.3
    reg = %Registration{
      target: source_address,
      state: :active,
      timer: Process.send_after(self(), {:fd_reg_timer, source_address}, (fd_ttl + 30) * 1_000),
      ttl: fd_ttl,
      expires_at: NaiveDateTime.add(NaiveDateTime.utc_now(), fd_ttl + 30, :second)
    }

    Telemetry.execute_bbmd_add_fd_registration(self(), source_address, reg, state)

    trans_mod.send(
      portal,
      source_address,
      <<Constants.macro_by_name(:bvlc_result_format, :successful_completion)::size(16)>>,
      bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
      npci: false
    )

    new_state = update_in(state, [Access.key(:registrations), source_address], fn _val -> reg end)

    {:noreply, new_state}
  end

  def handle_info(
        {:bacnet_transport, {_protocol_id, trans_mod}, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(
                :bvlc_result_purpose,
                :bvlc_delete_foreign_device_table_entry
              ),
            data: %ForeignDeviceTableEntry{} = fd_entry
          } = _bvlc}, portal},
        %State{} = state
      ) do
    # We got a BVLC function (delete foreign device table entry), handle it
    log_debug(fn ->
      "BBMD: Received BVLC Delete-Foreign-Device-Table-Entry from source " <>
        format_ip(source_address) <>
        " for Foreign Device Table Entry " <> format_ip({fd_entry.ip, fd_entry.port})
    end)

    reg_key = {fd_entry.ip, fd_entry.port}

    # Cancel timer and remove registration from state, if present
    new_state =
      case Map.fetch(state.registrations, reg_key) do
        {:ok, %Registration{} = reg} ->
          log_debug(fn ->
            "BBMD: Removing Foreign Device Table Entry for " <>
              format_ip(reg_key) <>
              " on request through BVLC function by " <> format_ip(source_address)
          end)

          Telemetry.execute_bbmd_del_fd_registration(self(), source_address, reg, state)

          Process.cancel_timer(reg.timer)
          %State{state | registrations: Map.delete(state.registrations, reg_key)}

        :error ->
          state
      end

    # Send an acknowledge, even if we didn't find it, so it was probably best that it's gone
    trans_mod.send(
      portal,
      source_address,
      <<Constants.macro_by_name(:bvlc_result_format, :successful_completion)::size(16)>>,
      bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
      npci: false
    )

    {:noreply, new_state}
  end

  def handle_info(
        {:bacnet_transport, {_protocol_id, trans_mod}, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_read_foreign_device_table)
          } = _bvlc}, portal},
        %State{} = state
      ) do
    # We got a BVLC function (read foreign device table), handle it
    log_debug(fn ->
      "BBMD: Received BVLC Read-Foreign-Device-Table from source " <> format_ip(source_address)
    end)

    Telemetry.execute_bbmd_read_fd_table(self(), source_address, state.registrations, state)

    case BvlcFunction.encode(%BvlcFunction{
           function:
             Constants.macro_assert_name(
               :bvlc_result_purpose,
               :bvlc_read_foreign_device_table_ack
             ),
           data: calculate_foreign_device_table(state.registrations)
         }) do
      {:ok, {bvlc_header, bvlc_data}} ->
        trans_mod.send(portal, source_address, bvlc_data, bvlc: <<bvlc_header>>, npci: false)

      {:error, error} ->
        Logger.error(fn ->
          "BBMD has encountered an encode error " <>
            "while trying to encode foreign device table for BVLC, " <>
            "got: " <> inspect(error)
        end)

        Telemetry.execute_bbmd_exception(
          self(),
          :error,
          error,
          [Telemetry.make_stacktrace_from_env(__ENV__)],
          %{},
          state
        )

        trans_mod.send(
          portal,
          source_address,
          <<Constants.macro_by_name(:bvlc_result_format, :read_foreign_device_table_nak)::size(16)>>,
          bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
          npci: false
        )
    end

    {:noreply, state}
  end

  def handle_info(
        {:bacnet_transport, {_protocol_id, trans_mod}, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(
                :bvlc_result_purpose,
                :bvlc_read_broadcast_distribution_table
              )
          } = _bvlc}, portal},
        %State{} = state
      ) do
    # We got a BVLC function (read broadcast distribution table), handle it
    log_debug(fn ->
      "BBMD: Received BVLC Read-Broadcast-Distribution-Table from source " <>
        format_ip(source_address)
    end)

    Telemetry.execute_bbmd_read_bdt(self(), source_address, state.bdt, state)

    case BvlcFunction.encode(%BvlcFunction{
           function:
             Constants.macro_assert_name(
               :bvlc_result_purpose,
               :bvlc_read_broadcast_distribution_table_ack
             ),
           data: state.bdt
         }) do
      {:ok, {bvlc_header, bvlc_data}} ->
        trans_mod.send(portal, source_address, bvlc_data, bvlc: <<bvlc_header>>, npci: false)

      {:error, error} ->
        Logger.error(fn ->
          "BBMD has encountered an encode error " <>
            "while trying to encode broadcast distribution table for BVLC, " <>
            "got: " <> inspect(error)
        end)

        Telemetry.execute_bbmd_exception(
          self(),
          :error,
          error,
          [Telemetry.make_stacktrace_from_env(__ENV__)],
          %{},
          state
        )

        trans_mod.send(
          portal,
          source_address,
          <<Constants.macro_by_name(
              :bvlc_result_format,
              :read_broadcast_distribution_table_nak
            )::size(16)>>,
          bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
          npci: false
        )
    end

    {:noreply, state}
  end

  def handle_info(
        {:bacnet_transport, {_protocol_id, trans_mod}, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(
                :bvlc_result_purpose,
                :bvlc_write_broadcast_distribution_table
              ),
            data: bdt
          } = _bvlc}, portal},
        %State{} = state
      ) do
    # We got a BVLC function (write broadcast distribution table), handle it
    log_debug(fn ->
      "BBMD: Received BVLC Write-Broadcast-Distribution-Table from source " <>
        format_ip(source_address)
    end)

    # if BDT is invalid (not a list), pass an empty list instead
    Telemetry.execute_bbmd_write_bdt(
      self(),
      source_address,
      if(is_list(bdt), do: bdt, else: []),
      state
    )

    new_state =
      if not state.opts.bdt_readonly and
           is_list(bdt) and
           Enum.all?(bdt, fn entry ->
             is_struct(entry, BroadcastDistributionTableEntry) and is_ip4_addr(entry.ip) and
               is_integer(entry.port) and entry.port in 1..65_535 and
               is_ip4_addr(entry.mask)
           end) do
        trans_mod.send(
          portal,
          source_address,
          <<Constants.macro_by_name(:bvlc_result_format, :successful_completion)::size(16)>>,
          bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
          npci: false
        )

        %State{state | bdt: bdt}
      else
        Logger.info(fn ->
          "BBMD has encountered an invalid BDT while trying " <>
            "to handle write broadcast distribution table for BVLC"
        end)

        Telemetry.execute_bbmd_exception(
          self(),
          :error,
          :invalid_bdt_payload,
          [Telemetry.make_stacktrace_from_env(__ENV__)],
          %{},
          state
        )

        trans_mod.send(
          portal,
          source_address,
          <<Constants.macro_by_name(
              :bvlc_result_format,
              :write_broadcast_distribution_table_nak
            )::size(16)>>,
          bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
          npci: false
        )

        state
      end

    {:noreply, new_state}
  end

  def handle_info(
        {:bacnet_client, _reply_ref,
         %UnconfirmedServiceRequest{
           service: service
         } = apdu,
         {{orig_ip, orig_port} = source_address, :original_unicast,
          %NPCI{expects_reply: false} = npci}, _client},
        %State{opts: %{proxy_mode: true}} = state
      )
      when source_address != state.client.ip_addr and
             service in [
               Constants.macro_assert_name(:unconfirmed_service_choice, :i_am),
               Constants.macro_assert_name(:unconfirmed_service_choice, :i_have)
             ] do
    # We got an original-unicast APDU payload to send to ours peers in the FDT in proxy mode
    # We are asserting it does not expect a reply (otherwise it's a malformed packet)
    log_debug(fn ->
      "BBMD: Received original unicast APDU in proxy mode to send to FDT from source " <>
        format_ip(source_address)
    end)

    case BvlcForwardedNPDU.encode(%BvlcForwardedNPDU{
           originating_ip: orig_ip,
           originating_port: orig_port
         }) do
      {:ok, new_bvlc} ->
        Telemetry.execute_bbmd_distribute_broadcast(
          self(),
          source_address,
          :original_unicast,
          apdu,
          npci,
          state
        )

        distribute_broadcast_to_fdt(new_bvlc, apdu, npci, state, source_address)

      {:error, error} ->
        Logger.info(fn ->
          "Invalid source_address for unicast APDU" <>
            ", error: " <>
            inspect(error) <>
            ", got: " <> format_ip(source_address)
        end)

        Telemetry.execute_bbmd_exception(
          self(),
          :error,
          error,
          [Telemetry.make_stacktrace_from_env(__ENV__)],
          %{},
          state
        )
    end

    {:noreply, state}
  end

  def handle_info(
        {:bacnet_client, _reply_ref, apdu,
         {source_address, :original_broadcast, %NPCI{expects_reply: false} = npci}, _client},
        %State{} = state
      )
      when source_address != state.client.ip_addr do
    # We got an original-broadcast APDU payload to send to ours peers in the BDT
    # We are asserting it does not expect a reply (otherwise it's a malformed packet)
    log_debug(fn ->
      "BBMD: Received original broadcast APDU to send to BDT/FDT from source " <>
        format_ip(source_address)
    end)

    Telemetry.execute_bbmd_distribute_broadcast(
      self(),
      source_address,
      :original_broadcast,
      apdu,
      npci,
      state
    )

    distribute_broadcast_to_all_devices(apdu, npci, state, source_address)

    {:noreply, state}
  end

  def handle_info(
        {:bacnet_client, _reply_ref, apdu,
         {{orig_ip, orig_port} = source_address, :distribute_broadcast_to_network,
          %NPCI{expects_reply: false} = npci}, _orig_client},
        %State{client: %ClientRef{transport_module: trans_mod}} = state
      ) do
    # We got an APDU payload to distribute
    # We are asserting it does not expect a reply (otherwise it's a malformed packet)
    log_debug(fn ->
      "BBMD: Received APDU to distribute from source " <> format_ip(source_address)
    end)

    # Only accept Distribute-Broadcast-To-Network from registered Foreign Devices
    if Map.has_key?(state.registrations, source_address) do
      Telemetry.execute_bbmd_distribute_broadcast(
        self(),
        source_address,
        :distribute_broadcast_to_network,
        apdu,
        npci,
        state
      )

      distribute_broadcast_to_all_devices(apdu, npci, state, source_address)

      bvlc_encode =
        if state.opts.proxy_mode do
          {:ok, nil}
        else
          BvlcForwardedNPDU.encode(%BvlcForwardedNPDU{
            originating_ip: orig_ip,
            originating_port: orig_port
          })
        end

      case bvlc_encode do
        {:ok, new_bvlc} ->
          log_debug(fn ->
            "BBMD: Distribute APDU as broadcast to client #{format_ip(state.client.ip_addr)}"
          end)

          send_opts =
            if state.opts.proxy_mode do
              []
            else
              [
                bvlc:
                  <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_forwarded_npdu),
                    new_bvlc::binary>>,
                npci: npci
              ]
            end

          case Client.send(state.client.ref, state.client.broadcast_addr, apdu, send_opts) do
            :ok ->
              :ok

            {:error, error} ->
              Logger.error(fn ->
                "BBMD has encountered a transport error while trying " <>
                  "to distribute APDU to network as broadcast, got: " <>
                  inspect(error)
              end)

              Telemetry.execute_bbmd_exception(
                self(),
                :error,
                error,
                [Telemetry.make_stacktrace_from_env(__ENV__)],
                %{},
                state
              )

              # Send NAK on failure of local broadcast
              trans_mod.send(
                state.client.portal,
                source_address,
                <<Constants.macro_by_name(
                    :bvlc_result_format,
                    :distribute_broadcast_to_network_nak
                  )::size(16)>>,
                bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
                npci: false
              )
          end

        {:error, error} ->
          Logger.info(fn ->
            "BBMD: Invalid source_address for distribute APDU" <>
              ", error: " <>
              inspect(error) <>
              ", got: " <>
              format_ip(source_address) <>
              ", returning NAK"
          end)

          Telemetry.execute_bbmd_exception(
            self(),
            :error,
            error,
            [Telemetry.make_stacktrace_from_env(__ENV__)],
            %{},
            state
          )

          # Send NAK on failure of local broadcast
          trans_mod.send(
            state.client.portal,
            source_address,
            <<Constants.macro_by_name(
                :bvlc_result_format,
                :distribute_broadcast_to_network_nak
              )::size(16)>>,
            bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
            npci: false
          )
      end
    else
      Logger.info(fn ->
        "BBMD: Unknown Foreign Device for distribute APDU, returning NAK"
      end)

      Telemetry.execute_bbmd_exception(
        self(),
        :error,
        :unknown_foreign_device,
        [Telemetry.make_stacktrace_from_env(__ENV__)],
        %{},
        state
      )

      trans_mod.send(
        state.client.portal,
        source_address,
        <<Constants.macro_by_name(
            :bvlc_result_format,
            :distribute_broadcast_to_network_nak
          )::size(16)>>,
        bvlc: <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>,
        npci: false
      )
    end

    {:noreply, state}
  end

  def handle_info(
        {:bacnet_client, _reply_ref, apdu,
         {source_address, %BvlcForwardedNPDU{} = npdu, %NPCI{expects_reply: false} = npci},
         _orig_client},
        %State{client: %ClientRef{transport_module: trans_mod}} = state
      ) do
    # We got a Forwarded NPDU
    log_debug(fn ->
      "BBMD: Received Forwarded NPDU from source " <> format_ip(source_address)
    end)

    case BvlcForwardedNPDU.encode(npdu) do
      {:ok, new_bvlc} ->
        Telemetry.execute_bbmd_distribute_broadcast(
          self(),
          source_address,
          npdu,
          apdu,
          npci,
          state
        )

        distribute_broadcast_to_fdt(new_bvlc, apdu, npci, state, source_address)

        # Check if messages was received NOT through directed broadcast
        # (if peer is routed, it was not directed broadcast but unicast)
        # In that case, we do a local broadcast
        if trans_mod.is_destination_routed(state.client.transport, source_address) do
          case Client.send(state.client.ref, state.client.broadcast_addr, apdu,
                 bvlc:
                   <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_forwarded_npdu),
                     new_bvlc::binary>>,
                 npci: npci
               ) do
            :ok ->
              :ok

            {:error, error} ->
              Logger.error(fn ->
                "BBMD has encountered a transport error while trying " <>
                  "to distribute Forwarded APDU to network as broadcast, got: " <>
                  inspect(error)
              end)
          end
        end

      {:error, error} ->
        Logger.info(fn ->
          "Invalid source_address for broadcast APDU" <>
            ", error: " <>
            inspect(error) <>
            ", got: " <> format_ip(source_address)
        end)

        Telemetry.execute_bbmd_exception(
          self(),
          :error,
          error,
          [Telemetry.make_stacktrace_from_env(__ENV__)],
          %{},
          state
        )
    end

    {:noreply, state}
  end

  def handle_info({:fd_reg_timer, key}, %State{} = state) do
    # FD registration timer triggered
    # We need to check if the FD registration has expired and remove it
    log_debug(fn -> "BBMD: Received fd_reg_timer request for #{format_ip(key)}" end)

    new_state =
      case Map.fetch(state.registrations, key) do
        {:ok, %Registration{} = reg} ->
          if reg.state != :active or
               NaiveDateTime.compare(reg.expires_at, NaiveDateTime.utc_now()) != :gt do
            Logger.debug(fn ->
              "BBMD detected that Foreign Device registration for target " <>
                format_ip(reg.target) <> " has expired, removing"
            end)

            Telemetry.execute_bbmd_del_fd_registration(self(), nil, reg, state)

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

  @spec make_client_ref(
          {client(), module(), TransportBehaviour.transport(), TransportBehaviour.portal()},
          map()
        ) :: {:ok, ClientRef.t()} | no_return()
  defp make_client_ref(client_ref, opts)

  defp make_client_ref({client, trans_mod, transport, portal}, opts) when is_map(opts) do
    address = trans_mod.get_local_address(transport)

    unless match?({{_ip_a, _ip_b, _ip_c, _ip_d}, _port}, address) do
      raise ArgumentError,
            "Invalid Transport Module - it must return an IPv4 address and port tuple, " <>
              "however we got: " <> inspect(address)
    end

    broadcast_addr = trans_mod.get_broadcast_address(transport)

    unless match?({{_ip_a, _ip_b, _ip_c, _ip_d}, _port}, broadcast_addr) do
      raise ArgumentError,
            "Invalid Transport Module - it must return an IPv4 address and port tuple, " <>
              "however we got: " <> inspect(broadcast_addr)
    end

    broadcast_addr =
      case Map.fetch(opts, :override_port) do
        {:ok, new_port} ->
          {ip, _port} = broadcast_addr
          {ip, new_port}

        _other ->
          broadcast_addr
      end

    {:ok,
     %ClientRef{
       ref: client,
       transport_module: trans_mod,
       transport: transport,
       portal: portal,
       ip_addr: address,
       broadcast_addr: broadcast_addr
     }}
  end

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

    case opts[:bdt_readonly] do
      nil ->
        :ok

      term ->
        unless is_boolean(term) do
          raise ArgumentError,
            message: "start_link/1 expected bdt_readonly to be a boolean, got: #{inspect(term)}"
        end
    end

    unless is_server(opts[:client]) do
      raise ArgumentError,
        message:
          "start_link/1 expected client to be a process reference, " <>
            "got: #{inspect(opts[:client])}"
    end

    case opts[:max_fd_registrations] do
      nil ->
        :ok

      term when is_integer(term) and term > 0 ->
        :ok

      term ->
        raise ArgumentError,
          message:
            "start_link/1 expected max_fd_registrations to be a positive integer (min: 1), got: #{inspect(term)}"
    end

    case opts[:override_port] do
      nil ->
        :ok

      term when is_integer(term) and term in 47_808..65_535 ->
        :ok

      term ->
        raise ArgumentError,
          message:
            "start_link/1 expected override_port to be an integer in the range 47_808..65_535, got: #{inspect(term)}"
    end

    case opts[:paused] do
      nil ->
        :ok

      term ->
        unless is_boolean(term) do
          raise ArgumentError,
            message: "start_link/1 expected paused to be a boolean, got: #{inspect(term)}"
        end
    end

    case opts[:proxy_mode] do
      nil ->
        :ok

      term ->
        unless is_boolean(term) do
          raise ArgumentError,
            message: "start_link/1 expected proxy_mode to be a boolean, got: #{inspect(term)}"
        end
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

  # # Convert an IPv4 tuple to the IP integer (32bit)
  # @spec convert_ip_to_int(:inet.ip4_address()) :: non_neg_integer()
  # defp convert_ip_to_int({ip_a, ip_b, ip_c, ip_d}) do
  #   Bitwise.bsl(ip_a, 24) +
  #     Bitwise.bsl(ip_b, 16) +
  #     Bitwise.bsl(ip_c, 8) +
  #     ip_d
  # end

  # # Convert an IP integer (32bit) to the IPv4 tuple
  # @spec convert_int_to_ip(non_neg_integer()) :: :inet.ip4_address()
  # defp convert_int_to_ip(int) when is_integer(int) do
  #   ip_a = Bitwise.band(Bitwise.bsr(int, 24), 0xFF)
  #   ip_b = Bitwise.band(Bitwise.bsr(int, 16), 0xFF)
  #   ip_c = Bitwise.band(Bitwise.bsr(int, 8), 0xFF)
  #   ip_d = Bitwise.band(int, 0xFF)

  #   {ip_a, ip_b, ip_c, ip_d}
  # end

  # Calculates the foreign device table from the registration state map
  @spec calculate_foreign_device_table(%{
          optional({:inet.ip_address(), 1..65_535}) => Registration.t()
        }) :: [ForeignDeviceTableEntry.t()]
  defp calculate_foreign_device_table(registrations) when is_map(registrations) do
    time_now = NaiveDateTime.utc_now()

    Enum.map(registrations, fn {_key, %Registration{target: {ip, port}} = reg} ->
      %ForeignDeviceTableEntry{
        ip: ip,
        port: port,
        time_to_live: reg.ttl,
        remaining_time: max(NaiveDateTime.diff(reg.expires_at, time_now, :second), 0)
      }
    end)
  end

  @spec distribute_broadcast_to_all_devices(
          Protocol.apdu(),
          NPCI.t(),
          State.t(),
          {:inet.ip_address(), :inet.port_number()}
        ) :: :ok
  defp distribute_broadcast_to_all_devices(
         apdu,
         npci,
         %State{} = state,
         {orig_ip, orig_port} = source_address
       ) do
    case BvlcForwardedNPDU.encode(%BvlcForwardedNPDU{
           originating_ip: orig_ip,
           originating_port: orig_port
         }) do
      {:ok, new_bvlc} ->
        distribute_broadcast_to_bdt(new_bvlc, apdu, npci, state, source_address)
        distribute_broadcast_to_fdt(new_bvlc, apdu, npci, state, source_address)

      {:error, error} ->
        Logger.info(fn ->
          "Invalid source_address for broadcast APDU" <>
            ", error: " <>
            inspect(error) <>
            ", got: " <> format_ip(source_address)
        end)
    end

    :ok
  end

  @spec distribute_broadcast_to_bdt(
          binary(),
          Protocol.apdu(),
          NPCI.t(),
          State.t(),
          {:inet.ip_address(), :inet.port_number()}
        ) :: :ok
  defp distribute_broadcast_to_bdt(
         bvlc,
         apdu,
         npci,
         %State{client: %{transport_module: trans_mod, transport: trans_pid}} = state,
         {orig_ip, orig_port} = source_address
       ) do
    for %BroadcastDistributionTableEntry{} = bdt <- state.bdt,
        bdt.ip != elem(state.client.ip_addr, 0),
        elem(bdt.ip, 0) != 127 do
      # As defined by ASHRAE 135 Annex J.4.5

      # Calculate IPv4 address string and subnet mask as integer from the BDT entry
      ip4 = :inet.ntoa(bdt.ip)
      mask = calculate_bitlength(bdt.mask)

      # Parse it and use it to check if the source of the broadcast is in the same
      # subnet as the BDT entry, if not, we skip broadcasting, as the hosts in that subnet
      # already received it directly
      case CIDR.parse("#{ip4}/#{mask}") do
        %CIDR{} = cidr ->
          destination = {cidr.last, bdt.port}

          cond do
            # As defined by ASHRAE 135 Annex J.4.5
            not trans_mod.is_destination_routed(trans_pid, source_address) ->
              log_debug(fn ->
                "BBMD: Skip distribute broadcast APDU to destination " <>
                  format_ip(destination) <>
                  " through BDT entry " <>
                  format_ip(bdt.ip) <>
                  "/" <>
                  format_ip(bdt.mask) <>
                  " to our own IP subnet"
              end)

            # Prevent potential broadcast loop AND it makes no sense to send the broadcast to the same
            # IP network it came from (which should never happen in a properly configured BACnet network)
            {:ok, true} == CIDR.match(cidr, orig_ip) and orig_port == bdt.port ->
              log_debug(fn ->
                "BBMD: Skip distribute broadcast APDU to destination " <>
                  format_ip(destination) <>
                  " through BDT entry " <>
                  format_ip(bdt.ip) <>
                  "/" <>
                  format_ip(bdt.mask) <>
                  " due to the IP subnet and port equal to origin"
              end)

            true ->
              log_debug(fn ->
                "BBMD: Distribute broadcast APDU to destination " <>
                  format_ip(destination) <>
                  " through BDT entry " <> format_ip(bdt.ip) <> "/" <> format_ip(bdt.mask)
              end)

              case Client.send(state.client.ref, destination, apdu,
                     bvlc:
                       <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_forwarded_npdu),
                         bvlc::binary>>,
                     npci: npci
                   ) do
                :ok ->
                  :ok

                {:error, error} ->
                  Logger.error(fn ->
                    "BBMD has encountered a transport error while trying to " <>
                      "distribute broadcast APDU to BDT entry, " <>
                      "got: " <> inspect(error)
                  end)
              end
          end

        _other ->
          :ok
      end
    end

    :ok
  end

  @spec distribute_broadcast_to_fdt(
          binary(),
          Protocol.apdu(),
          NPCI.t(),
          State.t(),
          {:inet.ip_address(), :inet.port_number()}
        ) :: :ok
  defp distribute_broadcast_to_fdt(
         bvlc,
         apdu,
         npci,
         %State{} = state,
         source_address
       ) do
    for {_key, %Registration{} = fd} <- state.registrations, fd.target != source_address do
      log_debug(fn ->
        "BBMD: Distribute broadcast APDU to " <>
          "Foreign Device #{format_ip(fd.target)}"
      end)

      case Client.send(state.client.ref, fd.target, apdu,
             bvlc:
               <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_forwarded_npdu),
                 bvlc::binary>>,
             npci: npci
           ) do
        :ok ->
          :ok

        {:error, error} ->
          Logger.error(fn ->
            "BBMD has encountered a transport error while trying to " <>
              "distribute broadcast APDU to Foreign Device, " <>
              "got: " <> inspect(error)
          end)

          :ok
      end
    end

    :ok
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
