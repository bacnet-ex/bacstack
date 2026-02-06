defmodule BACnet.Stack.ForeignDevice do
  @moduledoc """
  The Foreign Device module is a server process that takes care of registering the application
  (client/transport) as a Foreign Device in a BACnet/IPv4 Broadcast Management Device (BBMD).

  It will automatically renew the registration in the BBMD, as long as this
  Foreign Device process is alive. The default Time-To-Live (TTL) is a
  development value and should always be overwritten in a production environment
  to lessen network traffic caused by Foreign Device registration.

  It also allows to read the BBMD's Broadcast Distribution Table,
  Foreign Device Table and distribute Unconfirmed Service Request APDUs
  through it.

  If registration in the BBMD fails, it will automatically retry to
  register in the BBMD at a later point in time (10 seconds).
  Currently this value can not be changed and is hardcoded.

  For each BBMD (client/transport) one Foreign Device process is required.
  This allows to register in many BBMDs as Foreign Device.
  """

  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.BvlcFunction
  alias BACnet.Protocol.BvlcResult
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ForeignDeviceTableEntry
  alias BACnet.Protocol.Services.IAm
  alias BACnet.Protocol.Services.WhoIs
  alias BACnet.Stack.Client
  alias BACnet.Stack.Telemetry
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [is_server: 1, log_debug: 1]

  require Constants
  require Logger

  use GenServer

  @bbmd_fd_reg_timer 10_000

  defmodule Registration do
    @moduledoc """
    Internal module for `BACnet.Stack.ForeignDevice`.

    It is used to track registration as Foreign Device
    in a remote BBMD.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            bbmd: {:inet.ip_address(), :inet.port_number()},
            status: :registered | :waiting_for_ack | :uninitialized,
            timer: reference(),
            expires_at: NaiveDateTime.t() | nil
          }

    @keys [:bbmd, :status, :timer, :expires_at]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule State do
    @moduledoc """
    Internal module for `BACnet.Stack.ForeignDevice`.

    It is used as `GenServer` state.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            bbmd: {:inet.ip_address(), :inet.port_number()},
            client: Client.server(),
            transport_module: module(),
            transport: TransportBehaviour.transport(),
            portal: TransportBehaviour.portal(),
            ip_addr: {:inet.ip_address(), :inet.port_number()},
            broadcast_addr: {:inet.ip_address(), :inet.port_number()},
            registration: BACnet.Stack.ForeignDevice.Registration.t(),
            opts: %{
              reply_rfd: boolean(),
              ttl: pos_integer()
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

  @typedoc """
  Represents a `BACnet.Stack.Client` process. It will be used to retrieve the
  transport module, transport and portal through the `BACnet.Stack.Client` API.
  """
  @type client :: Client.server()

  @typedoc """
  Represents a server process of the Foreign Device module.
  """
  @type server :: GenServer.server()

  @typedoc """
  Valid start options. For a description of each, see `start_link/1`.
  """
  @type start_option ::
          {:bbmd, {:inet.ip4_address(), port :: 1..65_535}}
          | {:client, client()}
          | {:reply_rfd, boolean()}
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
    - `bbmd: {:inet.ip4_address(), 1..65_535}` - Required. The BBMD address to register itself as Foreign Device with.
    - `client: client()` - Required. The client & transport information.
    - `reply_rfd: boolean()` - Optional. Enables replying to `Register-Foreign-Device` packets from other BACnet clients.
      Defaults to `true`. If multiple `ForeignDevice` processes are running on the same client/transport,
      all except for one MUST have this option disabled.
    - `ttl: pos_integer()` - Optional. The time in seconds until the Foreign Device Registration expires. Defaults to `60`.
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {opts2, genserver_opts} = Keyword.split(opts, [:bbmd, :client, :reply_rfd, :ttl])

    validate_start_link_opts(opts2)

    GenServer.start_link(__MODULE__, Map.new(opts2), genserver_opts)
  end

  @doc """
  Distributes the given APDU as broadcast through the BBMD.
  Only unconfirmed service requests can be sent as broadcast.

  It will spawn a new `Task` to temporarily subscribe for
  `BACnet.Stack.Client` notifications to receive BVLL/BVLC messages.

  It uses `BACnet.Stack.Client` to send the APDU,
  all `opts` will be given to `BACnet.Stack.Client.send/4`,
  in addition, the following are available for this function only:
  - `receive_timeout: non_neg_integer()` - Optional. The timeout to use to await
    BVLL/BVLC NAK response from the BBMD. Defaults to `1_000`.
  """
  @spec distribute_broadcast(server(), UnconfirmedServiceRequest.t(), Keyword.t()) ::
          :ok | {:error, BvlcResult.t()} | {:error, term()}
  def distribute_broadcast(server, %UnconfirmedServiceRequest{} = apdu, opts \\ [])
      when is_server(server) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "distribute_broadcast/3 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    if opts[:expects_reply] || opts[:npci][:expects_reply] do
      raise ArgumentError, "Invalid NPCI, expects reply must not be set"
    end

    receive_timeout = opts[:receive_timeout] || 1_000

    if receive_timeout == :infinity do
      raise ArgumentError,
        message:
          "Receive timeout must not be atom :infinity, " <>
            "as it may block the process forever waiting for a response that may never arrive"
    end

    with {:ok, {client, bbmd, _trans_mod, _portal}} <- GenServer.call(server, :get_client) do
      bvlc = Constants.macro_by_name(:bvlc_result_purpose, :bvlc_distribute_broadcast_to_network)

      new_opts =
        opts
        |> Keyword.put(:bvlc, <<bvlc>>)
        |> Keyword.drop([:fd, :receive_timeout])

      Telemetry.execute_foreign_device_distribute_broadcast(server, bbmd, apdu, new_opts, client)

      task =
        Task.async(fn ->
          with :ok <- Client.subscribe(client, self()),
               :ok <- Client.send(client, bbmd, apdu, new_opts) do
            receive do
              {:bacnet_transport, _protocol_id, ^bbmd,
               {:bvlc,
                %BvlcResult{
                  result_code:
                    Constants.macro_assert_name(
                      :bvlc_result_format,
                      :distribute_broadcast_to_network_nak
                    )
                } = result}, _portal} ->
                Telemetry.execute_foreign_device_exception(
                  server,
                  :error,
                  :distribute_broadcast_nak,
                  [Telemetry.make_stacktrace_from_env(__ENV__)],
                  %{},
                  struct(State, client: client)
                )

                {:error, result}
            after
              receive_timeout -> :ok
            end
          end
        end)

      Task.await(task)
    end
  end

  @doc """
  Get the status of Foreign Device registration.
  """
  @spec get_status(server()) :: :registered | :waiting_for_ack | :uninitialized
  def get_status(server) when is_server(server) do
    GenServer.call(server, :get_status)
  end

  @doc """
  Reads the Broadcast Distribution Table of the BBMD.

  This function will only read the BBMD address from the Foreign Device server,
  all communication to the BBMD is done in the caller process using a `Task`.
  The new `Task` will temporarily subscribe for `BACnet.Stack.Client` notifications
  to be able to process BVLL/BVLC messages.

  The following options are available:
  - `timeout: non_neg_integer() | :infinity` - Optional.
    The timeout to use for waiting for the BBMD reply.
  """
  @spec read_broadcast_distribution_table(server(), Keyword.t()) ::
          {:ok, [BroadcastDistributionTableEntry.t()]}
          | {:error, BvlcResult.t()}
          | {:error, term()}
  def read_broadcast_distribution_table(server, opts \\ [])
      when is_server(server) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "read_broadcast_distribution_table/2 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    with {:ok, {client, bbmd, _mod, _portal} = client_data} <- GenServer.call(server, :get_client) do
      result =
        Task.await(
          send_bvll_message_and_wait_in_task(
            client_data,
            %BvlcFunction{
              function:
                Constants.macro_assert_name(
                  :bvlc_result_purpose,
                  :bvlc_read_broadcast_distribution_table
                ),
              data: nil
            },
            Constants.macro_assert_name(
              :bvlc_result_purpose,
              :bvlc_read_broadcast_distribution_table_ack
            ),
            Constants.macro_assert_name(
              :bvlc_result_format,
              :read_broadcast_distribution_table_nak
            ),
            opts
          )
        )

      case result do
        {:ok, bdt} when is_list(bdt) ->
          Telemetry.execute_foreign_device_read_bdt(server, bbmd, bdt, client)
          result

        {:error, nak} ->
          Telemetry.execute_foreign_device_exception(
            server,
            :error,
            :read_bdt_nak,
            [Telemetry.make_stacktrace_from_env(__ENV__)],
            %{result: nak},
            struct(State, client: client)
          )

          result
      end
    end
  end

  @doc """
  Reads the Foreign Device Table of the BBMD.

  This function will only read the BBMD address from the Foreign Device server,
  all communication to the BBMD is done in the caller process using a `Task`.
  The new `Task` will temporarily subscribe for `BACnet.Stack.Client` notifications
  to be able to process BVLL/BVLC messages.

  The following options are available:
  - `timeout: non_neg_integer() | :infinity` - Optional.
    The timeout to use for waiting for the BBMD reply.
  """
  @spec read_foreign_device_table(server(), Keyword.t()) ::
          {:ok, [ForeignDeviceTableEntry.t()]} | {:error, BvlcResult.t()} | {:error, term()}
  def read_foreign_device_table(server, opts \\ []) when is_server(server) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "read_foreign_device_table/2 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    with {:ok, {client, bbmd, _mod, _portal} = client_data} <- GenServer.call(server, :get_client) do
      result =
        Task.await(
          send_bvll_message_and_wait_in_task(
            client_data,
            %BvlcFunction{
              function:
                Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_read_foreign_device_table),
              data: nil
            },
            Constants.macro_assert_name(
              :bvlc_result_purpose,
              :bvlc_read_foreign_device_table_ack
            ),
            Constants.macro_assert_name(:bvlc_result_format, :read_foreign_device_table_nak),
            opts
          )
        )

      case result do
        {:ok, regs} when is_list(regs) ->
          Telemetry.execute_foreign_device_read_fd_table(server, bbmd, regs, client)
          result

        {:error, nak} ->
          Telemetry.execute_foreign_device_exception(
            server,
            :error,
            :read_fd_table_nak,
            [Telemetry.make_stacktrace_from_env(__ENV__)],
            %{result: nak},
            struct(State, client: client)
          )

          result
      end
    end
  end

  @doc """
  Explicitely renews the Foreign Device Registration in the BBMD.

  This function returns `:ok` almost immediately,
  without waiting for a response from the BBMD.
  """
  @spec renew(server()) :: :ok
  def renew(server) when is_server(server) do
    GenServer.call(server, :renew)
  end

  @doc """
  Sends a Who-Is APDU to the BBMD for local broadcast.

  It uses `distribute_broadcast/3` to do the broadcast
  and then collects the incoming `BACnet.Protocol.Services.IAm` messages.
  This function will always spawn a new `Task`
  to send and collect messages.

  It accepts the same options as `BACnet.Stack.ClientHelper.who_is/3`,
  except `apdu_destination` and `no_subscribe`.
  """
  @spec send_whois(server(), non_neg_integer(), Keyword.t()) ::
          {:ok, [IAm.t()]} | {:error, term()}
  def send_whois(server, timeout \\ 5000, opts \\ [])
      when is_server(server) and is_integer(timeout) and timeout >= 100 and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "send_whois/3 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    who_is = %WhoIs{
      device_id_low_limit: opts[:low_limit],
      device_id_high_limit: opts[:high_limit]
    }

    with {:ok, apdu} <- WhoIs.to_apdu(who_is, []),
         {:ok, {client, _bbmd, _mod, _portal}} <- GenServer.call(server, :get_client) do
      req_opts =
        Keyword.drop(opts, [:high_limit, :low_limit, :apdu_destination, :no_subscribe])

      task =
        Task.async(fn ->
          with :ok <- Client.subscribe(client, self()),
               :ok <- distribute_broadcast(server, apdu, req_opts) do
            do_who_is(client, timeout, opts)
          end
        end)

      Task.await(task, trunc(timeout * 1.5))
    end
  end

  @doc """
  Stops and shuts down the Foreign Device.

  If a registration is active, it will try to delete it in the BBMD.
  """
  @spec stop(server()) :: :ok
  def stop(server) when is_server(server) do
    GenServer.call(server, :stop)
  end

  @doc """
  Writes the Broadcast Distribution Table of the BBMD.

  This function will only read the BBMD address from the Foreign Device server,
  all communication to the BBMD is done in the caller process using a `Task`.
  The new `Task` will temporarily subscribe for `BACnet.Stack.Client` notifications
  to be able to process BVLL/BVLC messages.

  Since the response from the BBMD is a generic success message, without any
  other information, you MUST make sure that this is the ONLY BVLL command that
  gets executed concurrently. Otherwise this or any other concurrent BVLL command
  MAY receive a false positive response instead of a negative response that would
  be the actual response to the BVLL command.

  The following options are available:
  - `timeout: non_neg_integer() | :infinity` - Optional.
    The timeout to use for waiting for the BBMD reply.
  """
  @spec write_broadcast_distribution_table(
          server(),
          [BroadcastDistributionTableEntry.t()],
          Keyword.t()
        ) ::
          :ok
          | {:error, BvlcResult.t()}
          | {:error, term()}
  def write_broadcast_distribution_table(server, bdt, opts \\ [])
      when is_server(server) and is_list(bdt) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "write_broadcast_distribution_table/3 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    unless Enum.all?(bdt, &is_struct(&1, BroadcastDistributionTableEntry)) do
      raise ArgumentError,
            "write_broadcast_distribution_table/3 expected bdt to be a " <>
              "list of BroadcastDistributionTableEntry structs, " <>
              "got: #{inspect(bdt)}"
    end

    with {:ok, {client, bbmd, _mod, _portal} = client_data} <- GenServer.call(server, :get_client) do
      result =
        Task.await(
          send_bvll_message_and_wait_in_task(
            client_data,
            %BvlcFunction{
              function:
                Constants.macro_assert_name(
                  :bvlc_result_purpose,
                  :bvlc_write_broadcast_distribution_table
                ),
              data: bdt
            },
            Constants.macro_assert_name(:bvlc_result_format, :successful_completion),
            Constants.macro_assert_name(
              :bvlc_result_format,
              :write_broadcast_distribution_table_nak
            ),
            opts
          )
        )

      case result do
        :ok ->
          Telemetry.execute_foreign_device_write_bdt(server, bbmd, bdt, client)
          :ok

        {:error, nak} ->
          Telemetry.execute_foreign_device_exception(
            server,
            :error,
            :write_bdt_nak,
            [Telemetry.make_stacktrace_from_env(__ENV__)],
            %{result: nak},
            struct(State, client: client)
          )

          result
      end
    end
  end

  # Returns :ok | {:ok, BvlcFunction.t()} | {:error, BvlcResult.t()} | {:error, term()}
  @spec send_bvll_message_and_wait_in_task(
          {Client.server(), {:inet.ip_address(), :inet.port_number()}, module(), term()},
          BvlcFunction.t(),
          Constants.bvlc_result_purpose() | Constants.bvlc_result_format(),
          Constants.bvlc_result_format(),
          Keyword.t()
        ) :: Task.t()
  defp send_bvll_message_and_wait_in_task(
         {client, bbmd, trans_mod, portal},
         %BvlcFunction{} = bvlc_function,
         function_reply,
         function_reply_nak,
         opts
       )
       when is_atom(function_reply) and is_atom(function_reply_nak) and is_list(opts) do
    Task.async(fn ->
      with :ok <- Client.subscribe(client, self()),
           {:ok, {bbmd_bvlc, bbmd_data}} <- BvlcFunction.encode(bvlc_function),
           :ok <-
             trans_mod.send(portal, bbmd, bbmd_data, bvlc: <<bbmd_bvlc>>, npci: false) do
        receive do
          {:bacnet_transport, _protocol_id, ^bbmd,
           {:bvlc, %BvlcFunction{function: ^function_reply, data: payload}}, _portal} ->
            {:ok, payload}

          {:bacnet_transport, _protocol_id, ^bbmd,
           {:bvlc, %BvlcResult{result_code: ^function_reply}}, _portal} ->
            :ok

          {:bacnet_transport, _protocol_id, ^bbmd,
           {:bvlc, %BvlcResult{result_code: ^function_reply_nak} = result}, _portal} ->
            {:error, result}
        after
          opts[:timeout] || :infinity ->
            {:error, :timeout}
        end
      end
    end)
  end

  defp do_who_is(client, timeout, opts) do
    ref = make_ref()
    timer = Process.send_after(self(), {__MODULE__, :stop_who_is, ref}, timeout)

    max_items = opts[:max]

    iams =
      Enum.reduce_while(1..10_000_000, [], fn _index, acc ->
        if max_items > 0 and length(acc) >= max_items do
          {:halt, acc}
        else
          receive do
            {:bacnet_client, _ref,
             %UnconfirmedServiceRequest{
               service: Constants.macro_assert_name(:unconfirmed_service_choice, :i_am)
             } = apdu, {source_addr, _bvlc, _npci}, _pid} ->
              case IAm.from_apdu(apdu) do
                {:ok, service} ->
                  {:cont, [{source_addr, service} | acc]}

                {:error, err} ->
                  log_debug(fn ->
                    "ClientHelper.who_is/3 encountered an error during " <>
                      "APDU to service transformation, error: #{inspect(err)}"
                  end)

                  {:cont, acc}
              end

            {__MODULE__, :stop_who_is, ^ref} ->
              {:halt, acc}
          end
        end
      end)

    # Cleanup subscription
    Client.unsubscribe(client, self())

    # Cleanup timer
    Process.cancel_timer(timer)

    # Receive timer in case it was sent before cancellation (and after reduce)
    receive do
      {__MODULE__, :stop_who_is, ^ref} -> :ok
    after
      0 -> :ok
    end

    {:ok, iams}
  end

  @doc false
  def init(opts) do
    bbmd = Map.fetch!(opts, :bbmd)

    client = Map.fetch!(opts, :client)
    {trans_mod, transport, portal} = Client.get_transport(client)
    local_addr = trans_mod.get_local_address(transport)

    if match?({{_a, _b, _c, _d}, _e}, local_addr) do
      new_opts =
        opts
        |> Map.drop([:bbmd, :client])
        |> Map.put_new(:ttl, 60)
        |> Map.put_new(:reply_rfd, true)

      state = %State{
        bbmd: bbmd,
        client: client,
        transport_module: trans_mod,
        transport: transport,
        portal: portal,
        ip_addr: local_addr,
        broadcast_addr: trans_mod.get_broadcast_address(transport),
        registration: %Registration{
          bbmd: bbmd,
          status: :uninitialized,
          timer: make_ref(),
          expires_at: nil
        },
        opts: new_opts
      }

      # Subscribe to BACnet.Stack.Client for notifications
      :ok = Client.subscribe(client, self())

      # If not a PID (i.e. name | {name, node} | {:global, name}), then monitor the process
      # unless is_pid(client.ref) do
      #   # Once the client goes down, we will wait for it to come back up and subscribe again
      #   Process.monitor(client.ref)
      # end

      log_debug(fn -> "ForeignDevice: Started on #{inspect(self())}" end)
      {:ok, state, {:continue, :bbmd_fd_reg}}
    else
      {:stop, {:error, :invalid_local_address}, %{}}
    end
  end

  @doc false
  def terminate(reason, %State{} = state) do
    log_debug(fn ->
      "ForeignDevice: Terminating due to reason " <>
        inspect(reason) <> " for BBMD " <> format_ip(state.bbmd)
    end)

    Client.unsubscribe(state.client, self())

    if state.registration.status == :registered do
      log_debug(fn ->
        "ForeignDevice: Deleting Foreign Device Table Entry from BBMD " <> format_ip(state.bbmd)
      end)

      delete_fd_registration(state)
    end

    {:stop, :ok, state}
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
            "ForeignDevice: Sent Foreign Device registration to BBMD " <> format_ip(state.bbmd)
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
  def handle_call(:get_client, _from, %State{} = state) do
    {:reply, {:ok, {state.client, state.bbmd, state.transport_module, state.portal}}, state}
  end

  def handle_call(:get_status, _from, %State{} = state) do
    {:reply, state.registration.status, state}
  end

  def handle_call(:renew, _from, %State{} = state) do
    # We got a renew request, so renew FD registration
    log_debug(fn ->
      "ForeignDevice: Received renew request for BBMD " <> format_ip(state.bbmd)
    end)

    {reply, new_state} =
      case send_fd_registration(state) do
        {:ok, reg} -> {:ok, %State{state | registration: reg}}
        err -> {err, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call(:stop, _from, %State{} = state) do
    # We got a stop request, so try to delete ourself from the BBMD (if active)
    log_debug(fn -> "ForeignDevice: Received stop request for BBMD " <> format_ip(state.bbmd) end)

    if state.registration.status == :registered do
      delete_fd_registration(state)
    end

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
        {:bacnet_transport, _protocol_id, source_address,
         {:bvlc,
          %BvlcFunction{
            function:
              Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device)
          } = _bvlc}, bvlc_portal},
        %State{transport_module: trans_mod, portal: portal, opts: %{reply_rfd: true}} = state
      )
      when bvlc_portal == portal do
    # We got a BVLC function (register foreign device) and we are the meant recipient, return NAK
    log_debug(fn ->
      "ForeignDevice: Received BVLC Register-Foreign-Device from source " <>
        format_ip(source_address) <>
        ", returning NAK"
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
          %BvlcResult{
            result_code: Constants.macro_assert_name(:bvlc_result_format, :successful_completion)
          } = _bvlc}, _portal},
        %State{bbmd: bbmd, registration: %Registration{status: :waiting_for_ack} = reg} = state
      )
      when bbmd == source_address do
    # We got a BVLC positive result, handle it
    # Change the state to alive and start new timer to check aliveness
    log_debug(fn ->
      "ForeignDevice: Received BVLC positive Foreign Device registration ACK from BBMD " <>
        format_ip(source_address)
    end)

    Process.cancel_timer(reg.timer)

    new_reg = %Registration{
      reg
      | status: :registered,
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
        %State{bbmd: bbmd, registration: %Registration{status: :waiting_for_ack} = reg} = state
      )
      when bbmd == source_address do
    # We got a BVLC negative result, handle it
    # We will change the status to uninitialized and retry it later
    log_debug(fn ->
      "ForeignDevice: Received BVLC negative Foreign Device registration ACK from BBMD " <>
        format_ip(source_address)
    end)

    Process.cancel_timer(reg.timer)

    new_reg = %Registration{
      reg
      | status: :uninitialized,
        timer: Process.send_after(self(), :fd_reg_retry, @bbmd_fd_reg_timer),
        expires_at: nil
    }

    new_state = %State{state | registration: new_reg}

    {:noreply, new_state}
  end

  def handle_info(
        :fd_reg_retry,
        %State{registration: %Registration{status: :uninitialized}} = state
      ) do
    # FD registration retry timer triggered
    # Retry FD registration if it still exists (it may have been removed)
    log_debug(fn ->
      "ForeignDevice: Received fd_reg_retry request for #{format_ip(state.bbmd)}"
    end)

    new_state =
      case send_fd_registration(state) do
        {:ok, reg} ->
          Logger.debug(fn ->
            "ForeignDevice: Sent Foreign Device registration to BBMD " <> format_ip(state.bbmd)
          end)

          %State{state | registration: reg}

        {:error, error} ->
          Logger.error(fn ->
            "ForeignDevice detected an error while trying to send Foreign Device registration " <>
              "to BBMD #{format_ip(state.bbmd)}, got: " <> inspect(error)
          end)

          state
      end

    {:noreply, new_state}
  end

  def handle_info(:fd_reg_timer, %State{registration: %Registration{} = reg} = state) do
    # FD registration timer triggered
    # We need to check if the FD registration was completed, timed out or expired
    log_debug(fn ->
      "ForeignDevice: Received fd_reg_timer request for #{format_ip(state.bbmd)}"
    end)

    new_state =
      if reg.status != :registered or
           NaiveDateTime.compare(reg.expires_at, NaiveDateTime.utc_now()) != :gt do
        if reg.status != :registered do
          Logger.warning(fn ->
            "ForeignDevice detected that Foreign Device registration " <>
              "on BBMD #{format_ip(state.bbmd)} has timed out, retrying"
          end)

          # Execute telemetry for timing out
          Telemetry.execute_foreign_device_add_fd_registration(self(), state.bbmd, reg, state)
        else
          Logger.debug(fn ->
            "ForeignDevice detected that Foreign Device registration " <>
              "on BBMD #{format_ip(state.bbmd)} is soon expiring, renewing"
          end)
        end

        case send_fd_registration(state) do
          {:ok, reg} ->
            Logger.debug(fn ->
              "ForeignDevice: Sent Foreign Device registration to BBMD " <> format_ip(state.bbmd)
            end)

            %State{state | registration: reg}

          {:error, error} ->
            Logger.error(fn ->
              "ForeignDevice detected an error while trying to send Foreign Device registration " <>
                "to BBMD #{format_ip(state.bbmd)}, got: " <> inspect(error)
            end)

            Telemetry.execute_foreign_device_exception(
              self(),
              :error,
              error,
              [Telemetry.make_stacktrace_from_env(__ENV__)],
              %{},
              state
            )

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
      reg = %Registration{
        bbmd: bbmd,
        status: :waiting_for_ack,
        timer: Process.send_after(self(), :fd_reg_timer, @bbmd_fd_reg_timer),
        expires_at: nil
      }

      Telemetry.execute_foreign_device_add_fd_registration(self(), bbmd, reg, state)

      {:ok, reg}
    end
  end

  @spec delete_fd_registration(State.t()) :: {:ok, State.t()} | {:error, term()}
  defp delete_fd_registration(
         %State{
           bbmd: bbmd,
           ip_addr: {ip, port},
           transport_module: trans_mod,
           portal: portal,
           registration: reg
         } =
           state
       ) do
    Telemetry.execute_foreign_device_del_fd_registration(self(), bbmd, reg, state)

    with {:ok, {fd_reg_bvlc, fd_reg_data}} <-
           BvlcFunction.encode(%BvlcFunction{
             function:
               Constants.macro_assert_name(
                 :bvlc_result_purpose,
                 :bvlc_delete_foreign_device_table_entry
               ),
             data: %ForeignDeviceTableEntry{
               ip: ip,
               port: port,
               time_to_live: nil,
               remaining_time: nil
             }
           }),
         :ok <- trans_mod.send(portal, bbmd, fd_reg_data, bvlc: <<fd_reg_bvlc>>, npci: false) do
      Process.cancel_timer(reg.timer)

      {:ok, %State{state | registration: %{reg | status: :uninitialized, expires_at: nil}}}
    end
  end

  defp validate_start_link_opts(opts) do
    case opts[:reply_rfd] do
      nil ->
        :ok

      term when is_boolean(term) ->
        :ok

      term ->
        raise ArgumentError,
          message:
            "start_link/1 expected reply_rfd to be a boolean, " <>
              "got: #{inspect(term)}"
    end

    unless is_ip_port(opts[:bbmd]) do
      raise ArgumentError,
        message:
          "start_link/1 expected bbmd to be a BBMD IPv4 address and port tuple, " <>
            "got: #{inspect(opts[:bbmd])}"
    end

    unless is_server(opts[:client]) do
      raise ArgumentError,
        message:
          "start_link/1 expected client to be a process reference, " <>
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
  @spec format_ip({:inet.ip_address(), :inet.port_number()} | :inet.ip4_address() | term()) ::
          String.t()
  defp format_ip(ip_or_ip_port)

  defp format_ip({one, two, three, four} = _ip_or_ip_port) do
    "#{one}.#{two}.#{three}.#{four}"
  end

  defp format_ip({ip, port} = _ip_or_ip_port) when is_tuple(ip) and tuple_size(ip) == 4 do
    format_ip(ip) <> ":#{port}"
  end

  defp format_ip(ip_or_ip_port) when is_tuple(ip_or_ip_port) and tuple_size(ip_or_ip_port) == 8 do
    str =
      ip_or_ip_port
      |> Tuple.to_list()
      |> Enum.map(&Integer.to_string(&1, 16))
      |> Enum.join(":")

    "[" <> str <> "]"
  end

  defp format_ip({ip, port} = _ip_or_ip_port) when is_tuple(ip) and tuple_size(ip) == 8 do
    format_ip(ip) <> ":#{port}"
  end

  defp format_ip(term) do
    inspect(term)
  end

  # Checks if given argument is an IP:Port tuple
  defp is_ip_port({{ip_a, ip_b, ip_c, ip_d}, port})
       when is_integer(ip_a) and ip_a in 0..255 and is_integer(ip_b) and ip_b in 0..255 and
              is_integer(ip_c) and ip_c in 0..255 and is_integer(ip_d) and ip_d in 0..255 and
              is_integer(port) and port in 1..65_535,
       do: true

  # Currently IPv6 is a delicate matter (due to BVLL handling in BACnet.Protocol and the BVLL structs)
  # defp is_ip_port({{ip_a, ip_b, ip_c, ip_d, ip_e, ip_f, ip_g, ip_h}, port})
  #      when is_integer(ip_a) and ip_a in 0..65_535 and is_integer(ip_b) and ip_b in 0..65_535 and
  #             is_integer(ip_c) and ip_c in 0..65_535 and is_integer(ip_d) and ip_d in 0..65_535 and
  #             is_integer(ip_e) and ip_e in 0..65_535 and is_integer(ip_f) and ip_f in 0..65_535 and
  #             is_integer(ip_g) and ip_g in 0..65_535 and is_integer(ip_h) and ip_h in 0..65_535 and
  #             is_integer(port) and port in 1..65_535,
  #      do: true

  defp is_ip_port(_term), do: false
end
