defmodule BACnet.Stack.Telemetry do
  @moduledoc """
  Contains functions for easier interaction with telemetry.

  For full functionality, `:telemetry` dependency must be installed.
  If you want to disable emitting telemetry events even if telemetry is installed,
  set the environment `:bacstack` key `:no_telemetry` to true and recompile.
  For recompiling when bacstack is a dependency, use `mix deps.compile --force`.

  All measurements contain at least `monotonic_time` (native units) and `system_time`.
  The event metadata will depend on the event, but will at least contain the following keys:
  - `self: GenServer.server()`
  - `transport_module: module()` (only for client messages)
  - `portal: TransportBehaviour.portal()` (only for client messages)
  - `client: Client.server()` (only for BBMD/foreign device messages)
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.APDU.Reject
  alias BACnet.Protocol.APDU.SegmentACK
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ForeignDeviceTableEntry
  alias BACnet.Protocol.IncompleteAPDU
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.Services.ConfirmedCovNotification
  alias BACnet.Protocol.Services.ConfirmedEventNotification
  alias BACnet.Protocol.Services.UnconfirmedEventNotification
  alias BACnet.Stack.BBMD
  alias BACnet.Stack.Client
  alias BACnet.Stack.ForeignDevice
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Stack.TransportBehaviour
  alias BACnet.Stack.TrendLogger

  @doc """
  Makes a single stacktrace entry from the environment.

  Use case is calling `execute_*_exception` functions here without a real stacktrace.
  """
  @spec make_stacktrace_from_env(Macro.Env.t()) :: Exception.stacktrace_entry()
  def make_stacktrace_from_env(%Macro.Env{} = env) do
    {fun, arity} = env.function
    {env.module, fun, arity, [file: env.file, line: env.line]}
  end

  @doc """
  Get basic telemetry measurements, such as `monotonic_time` and `system_time`.
  The given map will be merged into the basic measurements map.
  """
  @spec get_telemetry_measurements(map()) :: %{
          :monotonic_time => any(),
          :system_time => any(),
          optional(any()) => any()
        }
  def get_telemetry_measurements(map \\ %{}) do
    Map.merge(%{monotonic_time: System.monotonic_time(), system_time: System.system_time()}, map)
  end

  # All functions in this IF are only fully usable when :telemetry is installed,
  # otherwise dummy functions are created which are NO-OP
  if Code.ensure_loaded?(:telemetry) and
       not Application.compile_env(:bacstack, :no_telemetry, false) do
    import BACnet.Internal, only: [is_server: 1], warn: false

    @doc false
    @spec compiled_with_telemetry() :: boolean()
    def compiled_with_telemetry(), do: true

    # Spawn a new process and call telemetry there,
    # to make sure nothing ever blocks the callee
    @spec execute_event(
            :telemetry.event_name(),
            :telemetry.event_measurements(),
            :telemetry.event_metadata()
          ) :: :ok
    defp execute_event(event, measurements, metadata) do
      spawn(fn -> :telemetry.execute(event, measurements, metadata) end)
      :ok
    end

    # Telemetry functions
    ###############################################

    @doc """
    Executes telemetry for an error or exception as `[:bacstack, :bbmd, :exception]`.

    The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.
    """
    @spec execute_bbmd_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            BBMD.State.t()
          ) :: :ok
    def execute_bbmd_exception(
          self,
          kind,
          reason,
          stacktrace,
          %{} = basic_metadata,
          %BBMD.State{} = state
        )
        when is_server(self) and is_list(stacktrace) do
      execute_event(
        [:bacstack, :bbmd, :exception],
        get_telemetry_measurements(%{}),
        Map.merge(
          %{
            self: self,
            client: state.client,
            kind: kind,
            reason: reason,
            stacktrace: stacktrace
          },
          basic_metadata
        )
      )
    end

    @doc """
    Executes telemetry for deleting foreign device registration
    as `[:bacstack, :bbmd, :foreign_device, :delete]`.

    This function is only called for BACnet interactions,
    not for local interactions through the `BBMD` public API.
    However this function is called for expiring registrations (source_address = nil).

    The arguments `source_adress` and `registration` are part of the event metadata.
    """
    @spec execute_bbmd_del_fd_registration(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()} | nil,
            BBMD.Registration.t(),
            BBMD.State.t()
          ) ::
            :ok
    def execute_bbmd_del_fd_registration(
          self,
          source_address,
          %BBMD.Registration{} = registration,
          %BBMD.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :bbmd, :foreign_device, :delete],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: state.client,
          source_address: source_address,
          registration: registration
        }
      )
    end

    @doc """
    Executes telemetry for new foreign device registration
    as `[:bacstack, :bbmd, :foreign_device, :add]`.

    The arguments `source_adress` and `registration` are part of the event metadata.
    """
    @spec execute_bbmd_add_fd_registration(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            BBMD.Registration.t(),
            BBMD.State.t()
          ) ::
            :ok
    def execute_bbmd_add_fd_registration(
          self,
          source_address,
          %BBMD.Registration{} = registration,
          %BBMD.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :bbmd, :foreign_device, :add],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: state.client,
          source_address: source_address,
          registration: registration
        }
      )
    end

    @doc """
    Executes telemetry for reading foreign device table
    as `[:bacstack, :bbmd, :foreign_device, :read_table]`.

    This function is only called for BACnet interactions,
    not for local interactions through the `BBMD` public API.

    The arguments `source_adress` and `registrations` are part of the event metadata.
    """
    @spec execute_bbmd_read_fd_table(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            %{optional({:inet.ip_address(), :inet.port_number()}) => BBMD.Registration.t()},
            BBMD.State.t()
          ) ::
            :ok
    def execute_bbmd_read_fd_table(
          self,
          source_address,
          registrations,
          %BBMD.State{} = state
        )
        when is_server(self) and is_map(registrations) do
      execute_event(
        [:bacstack, :bbmd, :foreign_device, :read_table],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: state.client,
          source_address: source_address,
          registrations: registrations
        }
      )
    end

    @doc """
    Executes telemetry for distributing broadcasts
    as `[:bacstack, :bbmd, :broadcast_distribution, :distribute]`.

    The arguments `source_adress`, `apdu` and `npci` are part of the event metadata.
    """
    @spec execute_bbmd_distribute_broadcast(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            Protocol.bvlc(),
            Protocol.apdu(),
            NPCI.t(),
            BBMD.State.t()
          ) :: :ok
    def execute_bbmd_distribute_broadcast(
          self,
          source_address,
          bvlc,
          apdu,
          %NPCI{} = npci,
          %BBMD.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :bbmd, :broadcast_distribution, :distribute],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: state.client,
          source_address: source_address,
          bvlc: bvlc,
          apdu: apdu,
          npci: npci
        }
      )
    end

    @doc """
    Executes telemetry for reading broadcast distribution table
    as `[:bacstack, :bbmd, :broadcast_distribution, :read_table]`.

    This function is only called for BACnet interactions,
    not for local interactions through the `BBMD` public API.

    The arguments `source_adress` and `bdt` are part of the event metadata.
    """
    @spec execute_bbmd_read_bdt(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            [BroadcastDistributionTableEntry.t()],
            BBMD.State.t()
          ) :: :ok
    def execute_bbmd_read_bdt(
          self,
          source_address,
          bdt,
          %BBMD.State{} = state
        )
        when is_server(self) and is_list(bdt) do
      execute_event(
        [:bacstack, :bbmd, :broadcast_distribution, :read_table],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: state.client,
          source_address: source_address,
          bdt: bdt
        }
      )
    end

    @doc """
    Executes telemetry for writing broadcast distribution table
    as `[:bacstack, :bbmd, :broadcast_distribution, :write_table]`.

    This function is only called for BACnet interactions,
    not for local interactions through the `BBMD` public API.

    The arguments `source_adress` and `bdt` are part of the event metadata.
    """
    @spec execute_bbmd_write_bdt(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            [BroadcastDistributionTableEntry.t()],
            BBMD.State.t()
          ) :: :ok
    def execute_bbmd_write_bdt(
          self,
          source_address,
          bdt,
          %BBMD.State{} = state
        )
        when is_server(self) and is_list(bdt) do
      execute_event(
        [:bacstack, :bbmd, :broadcast_distribution, :write_table],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: state.client,
          source_address: source_address,
          bdt: bdt
        }
      )
    end

    @doc """
    Executes telemetry for an error or exception as `[:bacstack, :client, :exception]`.

    The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.
    """
    @spec execute_client_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            Client.State.t()
          ) :: :ok
    def execute_client_exception(
          self,
          kind,
          reason,
          stacktrace,
          %{} = basic_metadata,
          %Client.State{} = state
        )
        when is_server(self) and is_list(stacktrace) do
      execute_event(
        [:bacstack, :client, :exception],
        get_telemetry_measurements(%{}),
        Map.merge(
          %{
            self: self,
            transport_module: state.transport_mod,
            portal: state.transport_portal,
            kind: kind,
            reason: reason,
            stacktrace: stacktrace
          },
          basic_metadata
        )
      )
    end

    @doc """
    Executes telemetry for incoming APDU (decoded) as `[:bacstack, :client, :incoming_apdu]`.

    The arguments `source_address`, `bvlc`, `npci` and `apdu` are part of the event metadata.
    """
    @spec execute_client_inc_apdu(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Protocol.apdu(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu(self, source_address, bvlc, npci, apdu, %Client.State{} = state)
        when is_server(self) do
      execute_event(
        [:bacstack, :client, :incoming_apdu],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          source_address: source_address,
          bvlc: bvlc,
          npci: npci,
          apdu: apdu
        }
      )
    end

    @doc """
    Executes telemetry for incoming APDU decode error as `[:bacstack, :client, :incoming_apdu, :error]`.

    The arguments `source_address`, `bvlc`, `npci`, `raw_apdu` and `error` are part of the event metadata.
    """
    @spec execute_client_inc_apdu_decode_error(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            binary(),
            term(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_decode_error(
          self,
          source_address,
          bvlc,
          npci,
          raw_apdu,
          error,
          %Client.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :client, :incoming_apdu, :error],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          source_address: source_address,
          bvlc: bvlc,
          npci: npci,
          raw_apdu: raw_apdu,
          error: error
        }
      )
    end

    @doc """
    Executes telemetry for incoming APDU (duplicated)
    as`[:bacstack, :client, :incoming_apdu, :duplicated]`.
    The APDU has been detected as being deduplicated and is not passed on to the application.

    The arguments `source_address`, `bvlc`, `npci` and `apdu` are part of the event metadata.
    """
    @spec execute_client_inc_apdu_duplicated(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Protocol.apdu(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_duplicated(
          self,
          source_address,
          bvlc,
          npci,
          apdu,
          %Client.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :client, :incoming_apdu, :duplicated],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          source_address: source_address,
          bvlc: bvlc,
          npci: npci,
          apdu: apdu
        }
      )
    end

    @doc """
    Executes telemetry for incoming APDU (handled) as `[:bacstack, :client, :incoming_apdu, :start]`.
    Handled refers to the APDU not being deduplicated and passed on to the application,
    if a notification receiver is registered.

    The arguments `source_address`, `bvlc`, `npci` and `apdu` are part of the event metadata.
    """
    @spec execute_client_inc_apdu_handled(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Protocol.apdu(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_handled(
          self,
          source_address,
          bvlc,
          npci,
          apdu,
          %Client.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :client, :incoming_apdu, :start],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          source_address: source_address,
          bvlc: bvlc,
          npci: npci,
          apdu: apdu
        }
      )
    end

    @doc """
    Executes telemetry for incoming APDU rejected as `[:bacstack, :client, :incoming_apdu, :error]`.

    Rejected means there is no configured notification receiver (listener) and as such can not
    respond to APDU requests expecting reply.

    The arguments `source_address`, `bvlc`, `npci`, `reject_apdu` and `original_apdu` are part
    of the event metadata. Additionally, key `reason` will be set to `:no_listener`.
    """
    @spec execute_client_inc_apdu_rejected(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Reject.t(),
            Protocol.apdu(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_rejected(
          self,
          source_address,
          bvlc,
          npci,
          reject_apdu,
          original_apdu,
          %Client.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :client, :incoming_apdu, :rejected],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          source_address: source_address,
          bvlc: bvlc,
          npci: npci,
          reason: :no_listener,
          reject_apdu: reject_apdu,
          original_apdu: original_apdu
        }
      )
    end

    @doc """
    Executes telemetry for incoming APDU segmented completed
    as `[:bacstack, :client, :incoming_apdu, :segmented, :completed]`.

    The arguments `source_address`, `bvlc`, `npci`, `raw_apdu`, `complete_apdu`
    and `incomplete`are part of the event metadata.
    """
    @spec execute_client_inc_apdu_segmentation_completed(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            binary(),
            binary(),
            IncompleteAPDU.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_segmentation_completed(
          self,
          source_address,
          bvlc,
          npci,
          raw_apdu,
          complete_apdu,
          %IncompleteAPDU{} = incomplete,
          %Client.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :client, :incoming_apdu, :segmented, :completed],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          source_address: source_address,
          bvlc: bvlc,
          npci: npci,
          raw_apdu: raw_apdu,
          complete_apdu: complete_apdu,
          incomplete: incomplete
        }
      )
    end

    @doc """
    Executes telemetry for incoming APDU segmented incomplete
    as `[:bacstack, :client, :incoming_apdu, :segmented, :incomplete]`.

    The arguments `source_address`, `bvlc`, `npci`, `raw_apdu` and `incomplete`
    are part of the event metadata.
    """
    @spec execute_client_inc_apdu_segmentation_incomplete(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            binary(),
            IncompleteAPDU.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_segmentation_incomplete(
          self,
          source_address,
          bvlc,
          npci,
          raw_apdu,
          %IncompleteAPDU{} = incomplete,
          %Client.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :client, :incoming_apdu, :segmented, :incomplete],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          source_address: source_address,
          bvlc: bvlc,
          npci: npci,
          raw_apdu: raw_apdu,
          incomplete: incomplete
        }
      )
    end

    @doc """
    Executes telemetry for incoming APDU segmented error
    as `[:bacstack, :client, :incoming_apdu, :segmented, :error]`.

    The arguments `source_address`, `bvlc`, `npci`, `raw_apdu`, `incomplete`, `error` and
    `cancelled` are part of the event metadata.
    """
    @spec execute_client_inc_apdu_segmentation_error(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            binary(),
            IncompleteAPDU.t(),
            term(),
            boolean(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_segmentation_error(
          self,
          source_address,
          bvlc,
          npci,
          raw_apdu,
          %IncompleteAPDU{} = incomplete,
          error,
          cancelled,
          %Client.State{} = state
        )
        when is_server(self) and is_boolean(cancelled) do
      execute_event(
        [:bacstack, :client, :incoming_apdu, :segmented, :error],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          source_address: source_address,
          bvlc: bvlc,
          npci: npci,
          raw_apdu: raw_apdu,
          incomplete: incomplete,
          error: error,
          cancelled: cancelled
        }
      )
    end

    @doc """
    Executes telemetry for APDU application response
    as `[:bacstack, :client, :incoming_apdu, :stop]`.
    A `duration` key will be set in measurements using monotonic time native units.

    The arguments `apdu` and `send_opts` are part of the events metadata.
    Additionally, the following keys are set:
    - `source_address: term()`
    - `ref: reference()`
    """
    @spec execute_client_inc_apdu_reply(
            GenServer.server(),
            Protocol.apdu(),
            Keyword.t(),
            Client.ReplyTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_reply(
          self,
          apdu,
          send_opts,
          %Client.ReplyTimer{} = timer,
          %Client.State{} = state
        )
        when is_server(self) and is_list(send_opts) do
      execute_event(
        [:bacstack, :client, :incoming_apdu, :stop],
        get_telemetry_measurements(%{duration: System.monotonic_time() - timer.monotonic_time}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: timer.portal,
          source_address: timer.source_addr,
          apdu: apdu,
          send_opts: send_opts,
          ref: timer.ref
        }
      )
    end

    @doc """
    Executes telemetry for APDU application response timeout
    as `[:bacstack, :client, :incoming_apdu, :stop]`.
    A `duration` key will be set in measurements using monotonic time native units.

    The following keys are exposed as part of the event metadata:
    - `source_address: term()`
    - `bvlc: Protocol.bvlc()`
    - `npci: NPCI.t()`
    - `apdu: Protocol.apdu()`
    - `ref: reference()`
    - `error: :reply_timeout`
    """
    @spec execute_client_inc_apdu_timeout(
            GenServer.server(),
            Client.ReplyTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_timeout(
          self,
          %Client.ReplyTimer{} = timer,
          %Client.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :client, :incoming_apdu, :stop],
        get_telemetry_measurements(%{duration: System.monotonic_time() - timer.monotonic_time}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: timer.portal,
          source_address: timer.source_addr,
          bvlc: timer.bvlc,
          npci: timer.npci,
          apdu: timer.service_req,
          ref: timer.ref,
          error: :reply_timeout
        }
      )
    end

    @doc """
    Executes telemetry for request start as `[:bacstack, :client, :request, :start]`.
    Requests are started by sending APDU with `expect_reply: true`.
    Responses will be emitted for the request through `:stop`.

    The arguments `destination`, `apdu` and `send_opts` are part of the event metadata.
    """
    @spec execute_client_request_start(
            GenServer.server(),
            term(),
            Protocol.apdu(),
            Keyword.t(),
            Client.ApduTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_request_start(
          self,
          destination,
          apdu,
          send_opts,
          %Client.ApduTimer{} = timer,
          %Client.State{} = state
        )
        when is_server(self) and is_list(send_opts) do
      execute_event(
        [:bacstack, :client, :request, :start],
        # Use the timer's monotonic_time instead
        get_telemetry_measurements(%{monotonic_time: timer.monotonic_time}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          destination: destination,
          apdu: apdu,
          send_opts: send_opts,
          telemetry_span_context: timer.call_ref
        }
      )
    end

    @doc """
    Executes telemetry for request stop as `[:bacstack, :client, :request, :stop]`.
    A `duration` key will be set in measurements using monotonic time native units.

    BVLC, NPCI and APDU are the response and belong to the request that got started.
    See also `execute_client_request_start/6`.

    The arguments `destination`, `bvlc`, `npci` and `apdu` are part of the event metadata.
    Additionally, the following keys are set:
    - `original_apdu: Protocol.apdu()`
    - `retry_count: non_neg_integer()`
    """
    @spec execute_client_request_stop(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Protocol.apdu(),
            Client.ApduTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_request_stop(
          self,
          destination,
          bvlc,
          npci,
          apdu,
          %Client.ApduTimer{} = timer,
          %Client.State{} = state
        )
        when is_server(self) do
      measurements = get_telemetry_measurements(%{})

      execute_event(
        [:bacstack, :client, :request, :stop],
        Map.put(measurements, :duration, measurements.monotonic_time - timer.monotonic_time),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          destination: destination,
          bvlc: bvlc,
          npci: npci,
          apdu: apdu,
          original_apdu: timer.apdu,
          retry_count: timer.retry_count,
          telemetry_span_context: timer.call_ref
        }
      )
    end

    @doc """
    Executes telemetry for APDU request timeout as `[:bacstack, :client, :request, :stop]`.
    A `duration` key will be set in measurements using monotonic time native units.

    The arguments `destination`, `bvlc`, `npci` and `apdu` are part of the event metadata.
    Additionally, the following keys are set:
    - `original_apdu: Protocol.apdu()`
    - `retry_count: non_neg_integer()`
    """
    @spec execute_client_request_apdu_timer(
            GenServer.server(),
            Client.ApduTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_request_apdu_timer(
          self,
          %Client.ApduTimer{} = timer,
          %Client.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :client, :request, :stop],
        get_telemetry_measurements(%{duration: System.monotonic_time() - timer.monotonic_time}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: timer.portal,
          destination: timer.destination,
          bvlc: nil,
          npci: nil,
          apdu: nil,
          original_apdu: timer.apdu,
          retry_count: timer.retry_count,
          telemetry_span_context: timer.call_ref,
          error: :apdu_timeout
        }
      )
    end

    @doc """
    Executes telemetry for sending APDUs as `[:bacstack, :client, :send]`.
    Segmented will indicate whether segmenting and sending the APDU has been
    handed off to `BACnet.Stack.Segmentator`.

    The arguments `destination`, `apdu`, `send_opts` and `segmented` are part of the event metadata.
    """
    @spec execute_client_send(
            GenServer.server(),
            term(),
            Protocol.apdu(),
            Keyword.t(),
            boolean(),
            Client.State.t()
          ) :: :ok
    def execute_client_send(
          self,
          destination,
          apdu,
          send_opts,
          segmented,
          %Client.State{} = state
        )
        when is_server(self) and is_list(send_opts) and is_boolean(segmented) do
      execute_event(
        [:bacstack, :client, :send],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          destination: destination,
          apdu: apdu,
          send_opts: send_opts,
          segmented: segmented
        }
      )
    end

    @doc """
    Executes telemetry for send error as `[:bacstack, :client, :send, :error]`.
    Send errors are encountered for APDU too long (no segmentation) or
    recipient device does not support segmentation.

    The arguments `destination`, `original_apdu`, `send_opts`, `reply_apdu` and
    `reason` are part of the event metadata.
    """
    @spec execute_client_send_error(
            GenServer.server(),
            term(),
            Protocol.apdu(),
            Keyword.t(),
            Protocol.apdu(),
            atom(),
            Client.State.t()
          ) :: :ok
    def execute_client_send_error(
          self,
          destination,
          original_apdu,
          send_opts,
          reply_apdu,
          reason,
          %Client.State{} = state
        )
        when is_server(self) and is_list(send_opts) and is_atom(reason) do
      execute_event(
        [:bacstack, :client, :send, :error],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          destination: destination,
          original_apdu: original_apdu,
          send_opts: send_opts,
          reply_apdu: reply_apdu,
          reason: reason
        }
      )
    end

    @doc """
    Executes telemetry for an error or exception as `[:bacstack, :client, :transport, :message]`.

    The argument `transport_msg` is part of the event metadata.
    """
    @spec execute_client_transport_message(
            GenServer.server(),
            TransportBehaviour.transport_msg(),
            Client.State.t()
          ) :: :ok
    def execute_client_transport_message(
          self,
          transport_msg,
          %Client.State{} = state
        )
        when is_server(self) and is_tuple(transport_msg) do
      execute_event(
        [:bacstack, :client, :transport, :message],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: state.transport_mod,
          portal: state.transport_portal,
          transport_msg: transport_msg
        }
      )
    end

    @doc """
    Executes telemetry for an error or exception as `[:bacstack, :foreign_device, :exception]`.

    The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.
    """
    @spec execute_foreign_device_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            ForeignDevice.State.t()
          ) ::
            :ok
    def execute_foreign_device_exception(
          self,
          kind,
          reason,
          stacktrace,
          %{} = basic_metadata,
          %ForeignDevice.State{} = state
        )
        when is_server(self) and is_list(stacktrace) do
      execute_event(
        [:bacstack, :foreign_device, :exception],
        get_telemetry_measurements(%{}),
        Map.merge(
          %{
            self: self,
            client: state.client,
            kind: kind,
            reason: reason,
            stacktrace: stacktrace
          },
          basic_metadata
        )
      )
    end

    @doc """
    Executes telemetry for distributing broadcast through the remote BBMD
    as `[:bacstack, :foreign_device, :broadcast_distribution, :distribute]`.

    The arguments `bbmd`, `apdu` and `send_opts` are part of the event metadata.
    """
    @spec execute_foreign_device_distribute_broadcast(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            UnconfirmedServiceRequest.t(),
            Keyword.t(),
            Client.server()
          ) :: :ok
    def execute_foreign_device_distribute_broadcast(
          self,
          bbmd,
          %UnconfirmedServiceRequest{} = apdu,
          send_opts,
          client
        )
        when is_server(self) and is_tuple(bbmd) and is_list(send_opts) do
      execute_event(
        [:bacstack, :foreign_device, :broadcast_distribution, :distribute],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: client,
          bbmd: bbmd,
          apdu: apdu,
          send_opts: send_opts
        }
      )
    end

    @doc """
    Executes telemetry for reading the broadcast distribution table from the remote BBMD
    as `[:bacstack, :foreign_device, :broadcast_distribution, :read_table]`.

    The arguments `bbmd` and `bdt` are part of the event metadata.
    """
    @spec execute_foreign_device_read_bdt(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            [BroadcastDistributionTableEntry.t()],
            Client.server()
          ) :: :ok
    def execute_foreign_device_read_bdt(
          self,
          bbmd,
          bdt,
          client
        )
        when is_server(self) and is_list(bdt) do
      execute_event(
        [:bacstack, :foreign_device, :broadcast_distribution, :read_table],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: client,
          bbmd: bbmd,
          bdt: bdt
        }
      )
    end

    @doc """
    Executes telemetry for writing the broadcast distribution table to the remote BBMD
    as `[:bacstack, :foreign_device, :broadcast_distribution, :write_table]`.

    The arguments `bbmd` and `bdt` are part of the event metadata.
    """
    @spec execute_foreign_device_write_bdt(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            [BroadcastDistributionTableEntry.t()],
            Client.server()
          ) :: :ok
    def execute_foreign_device_write_bdt(
          self,
          bbmd,
          bdt,
          client
        )
        when is_server(self) and is_list(bdt) do
      execute_event(
        [:bacstack, :foreign_device, :broadcast_distribution, :write_table],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: client,
          bbmd: bbmd,
          bdt: bdt
        }
      )
    end

    @doc """
    Executes telemetry for reading the foreign device table from the remote BBMD
    as `[:bacstack, :foreign_device, :foreign_device, :read_table]`.

    The arguments `bbmd` and `registrations` are part of the event metadata.
    """
    @spec execute_foreign_device_read_fd_table(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            [ForeignDeviceTableEntry.t()],
            Client.server()
          ) :: :ok
    def execute_foreign_device_read_fd_table(
          self,
          bbmd,
          registrations,
          client
        )
        when is_server(self) and is_list(registrations) do
      execute_event(
        [:bacstack, :foreign_device, :foreign_device, :read_table],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: client,
          bbmd: bbmd,
          registrations: registrations
        }
      )
    end

    @doc """
    Executes telemetry for adding the foreign device registration in the remote BBMD
    as `[:bacstack, :foreign_device, :foreign_device, :add]`.

    The registration is always about ourself - status may not be registered
    when this metric event gets called.

    The arguments `bbmd` and `registration` are part of the event metadata.
    """
    @spec execute_foreign_device_add_fd_registration(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            ForeignDevice.Registration.t(),
            ForeignDevice.State.t()
          ) :: :ok
    def execute_foreign_device_add_fd_registration(
          self,
          bbmd,
          %ForeignDevice.Registration{} = registration,
          %ForeignDevice.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :foreign_device, :foreign_device, :add],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: state.client,
          bbmd: bbmd,
          registration: registration
        }
      )
    end

    @doc """
    Executes telemetry for deleting the foreign device registration in the remote BBMD
    as `[:bacstack, :foreign_device, :foreign_device, :delete]`.

    The arguments `bbmd` and `registration` are part of the event metadata.
    """
    @spec execute_foreign_device_del_fd_registration(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            ForeignDevice.Registration.t(),
            ForeignDevice.State.t()
          ) :: :ok
    def execute_foreign_device_del_fd_registration(
          self,
          bbmd,
          %ForeignDevice.Registration{} = registration,
          %ForeignDevice.State{} = state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :foreign_device, :foreign_device, :delete],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          client: state.client,
          bbmd: bbmd,
          registration: registration
        }
      )
    end

    @doc """
    Executes telemetry for an error or exception as `[:bacstack, :segmentator, :exception]`.

    The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.
    """
    @spec execute_segmentator_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_exception(
          self,
          kind,
          reason,
          stacktrace,
          %{} = basic_metadata,
          %Segmentator.State{} = _state
        )
        when is_server(self) and is_list(stacktrace) do
      execute_event(
        [:bacstack, :segmentator, :exception],
        get_telemetry_measurements(%{}),
        Map.merge(
          %{
            self: self,
            kind: kind,
            reason: reason,
            stacktrace: stacktrace
          },
          basic_metadata
        )
      )
    end

    @doc """
    Executes telemetry for sequence ack as `[:bacstack, :segmentator, :sequence, :ack]`.
    A segment ACK has been sent from the remote BACnet client.

    The arguments `sequence` and `ack` is part of the event metadata.
    """
    @spec execute_segmentator_sequence_ack(
            GenServer.server(),
            Segmentator.Sequence.t(),
            SegmentACK.t(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_ack(
          self,
          %Segmentator.Sequence{} = sequence,
          %SegmentACK{} = ack,
          %Segmentator.State{} = _state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :segmentator, :sequence, :ack],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          sequence: sequence,
          ack: ack,
          telemetry_span_context: {sequence.destination, sequence.invoke_id}
        }
      )
    end

    @doc """
    Executes telemetry for sequence error as `[:bacstack, :segmentator, :sequence, :error]`.

    The arguments `transport_module`, `transport`, `portal`, `destination`, `original_apdu`,
    `send_opts`, `reply_apdu` and `reason` is part of the event metadata.
    """
    @spec execute_segmentator_sequence_error(
            GenServer.server(),
            module(),
            TransportBehaviour.transport(),
            TransportBehaviour.portal(),
            term(),
            Protocol.apdu() | nil,
            Keyword.t() | nil,
            Protocol.apdu() | nil,
            atom(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_error(
          self,
          transport_module,
          transport,
          portal,
          destination,
          original_apdu,
          send_opts,
          reply_apdu,
          reason,
          %Segmentator.State{} = _state
        )
        when is_server(self) and is_atom(transport_module) and
               (is_list(send_opts) or is_nil(send_opts)) and
               is_atom(reason) do
      execute_event(
        [:bacstack, :segmentator, :sequence, :error],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: transport_module,
          transport: transport,
          portal: portal,
          destination: destination,
          original_apdu: original_apdu,
          send_opts: send_opts,
          reply_apdu: reply_apdu,
          reason: reason
        }
      )
    end

    @doc """
    Executes telemetry for sequence start as `[:bacstack, :segmentator, :sequence, :start]`.

    The argument `sequence` is part of the event metadata.
    """
    @spec execute_segmentator_sequence_start(
            GenServer.server(),
            Segmentator.Sequence.t(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_start(
          self,
          %Segmentator.Sequence{} = sequence,
          %Segmentator.State{} = _state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :segmentator, :sequence, :start],
        # Use the sequence's monotonic_time instead
        get_telemetry_measurements(%{monotonic_time: sequence.monotonic_time}),
        %{
          self: self,
          sequence: sequence,
          telemetry_span_context: {sequence.destination, sequence.invoke_id}
        }
      )
    end

    @doc """
    Executes telemetry for sequence segment as `[:bacstack, :segmentator, :sequence, :segment]`.
    An individual segment has been sent to the remote BACnet client.

    The arguments `sequence` and `segment_number` is part of the event metadata.
    """
    @spec execute_segmentator_sequence_segment(
            GenServer.server(),
            Segmentator.Sequence.t(),
            non_neg_integer(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_segment(
          self,
          %Segmentator.Sequence{} = sequence,
          segment_number,
          %Segmentator.State{} = _state
        )
        when is_server(self) and is_integer(segment_number) and segment_number >= 0 do
      execute_event(
        [:bacstack, :segmentator, :sequence, :segment],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          sequence: sequence,
          segment_number: segment_number,
          telemetry_span_context: {sequence.destination, sequence.invoke_id}
        }
      )
    end

    @doc """
    Executes telemetry for sequence stop as `[:bacstack, :segmentator, :sequence, :stop]`.
    A `duration` key will be set in measurements using monotonic time native units.

    The arguments `sequence` and `reason` are part of the event metadata.
    """
    @spec execute_segmentator_sequence_stop(
            GenServer.server(),
            Segmentator.Sequence.t(),
            atom(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_stop(
          self,
          %Segmentator.Sequence{} = sequence,
          reason,
          %Segmentator.State{} = _state
        )
        when is_server(self) and is_atom(reason) do
      measurements = get_telemetry_measurements(%{})

      execute_event(
        [:bacstack, :segmentator, :sequence, :stop],
        Map.put(measurements, :duration, measurements.monotonic_time - sequence.monotonic_time),
        %{
          self: self,
          sequence: sequence,
          reason: reason,
          telemetry_span_context: {sequence.destination, sequence.invoke_id}
        }
      )
    end

    @doc """
    Executes telemetry for an error or exception as `[:bacstack, :segments_store, :exception]`.

    The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.
    """
    @spec execute_segments_store_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_exception(
          self,
          kind,
          reason,
          stacktrace,
          %{} = basic_metadata,
          %SegmentsStore.State{} = _state
        )
        when is_server(self) and is_list(stacktrace) do
      execute_event(
        [:bacstack, :segments_store, :exception],
        get_telemetry_measurements(%{}),
        Map.merge(
          %{
            self: self,
            kind: kind,
            reason: reason,
            stacktrace: stacktrace
          },
          basic_metadata
        )
      )
    end

    @doc """
    Executes telemetry for sequence ack as `[:bacstack, :segments_store, :sequence, :ack]`.
    A segment ACK has been sent to the remote BACnet client.

    The arguments `sequence` and `ack` is part of the event metadata.
    """
    @spec execute_segments_store_sequence_ack(
            GenServer.server(),
            SegmentsStore.Sequence.t(),
            SegmentACK.t(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_ack(
          self,
          %SegmentsStore.Sequence{} = sequence,
          %SegmentACK{} = ack,
          %SegmentsStore.State{} = _state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :segments_store, :sequence, :ack],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          sequence: sequence,
          ack: ack,
          telemetry_span_context: {sequence.source_address, sequence.invoke_id}
        }
      )
    end

    @doc """
    Executes telemetry for sequence error as `[:bacstack, :segments_store, :sequence, :error]`.

    The arguments `transport_module`, `portal`, `destination`, `incomplete_apdu`,
    `send_opts`, `reply_apdu` and `reason` is part of the event metadata.
    """
    @spec execute_segments_store_sequence_error(
            GenServer.server(),
            module(),
            TransportBehaviour.portal(),
            term(),
            IncompleteAPDU.t() | nil,
            Keyword.t() | nil,
            Protocol.apdu() | nil,
            atom(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_error(
          self,
          transport_module,
          portal,
          destination,
          incomplete_apdu,
          send_opts,
          reply_apdu,
          reason,
          %SegmentsStore.State{} = _state
        )
        when is_server(self) and is_atom(transport_module) and
               (is_list(send_opts) or is_nil(send_opts)) and
               is_atom(reason) do
      execute_event(
        [:bacstack, :segments_store, :sequence, :error],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          transport_module: transport_module,
          portal: portal,
          destination: destination,
          incomplete_apdu: incomplete_apdu,
          send_opts: send_opts,
          reply_apdu: reply_apdu,
          reason: reason
        }
      )
    end

    @doc """
    Executes telemetry for sequence start as `[:bacstack, :segments_store, :sequence, :start]`.

    The argument `sequence` is part of the event metadata.
    """
    @spec execute_segments_store_sequence_start(
            GenServer.server(),
            SegmentsStore.Sequence.t(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_start(
          self,
          %SegmentsStore.Sequence{} = sequence,
          %SegmentsStore.State{} = _state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :segments_store, :sequence, :start],
        # Use the sequence's monotonic_time instead
        get_telemetry_measurements(%{monotonic_time: sequence.monotonic_time}),
        %{
          self: self,
          sequence: sequence,
          telemetry_span_context: {sequence.source_address, sequence.invoke_id}
        }
      )
    end

    @doc """
    Executes telemetry for sequence segment as `[:bacstack, :segments_store, :sequence, :segment]`.
    An individual segment has been received from the remote BACnet client.

    The arguments `sequence` and `segment_number` is part of the event metadata.
    """
    @spec execute_segments_store_sequence_segment(
            GenServer.server(),
            SegmentsStore.Sequence.t(),
            non_neg_integer(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_segment(
          self,
          %SegmentsStore.Sequence{} = sequence,
          segment_number,
          %SegmentsStore.State{} = _state
        )
        when is_server(self) and is_integer(segment_number) and segment_number >= 0 do
      execute_event(
        [:bacstack, :segments_store, :sequence, :segment],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          sequence: sequence,
          segment_number: segment_number,
          telemetry_span_context: {sequence.source_address, sequence.invoke_id}
        }
      )
    end

    @doc """
    Executes telemetry for sequence stop as `[:bacstack, :segments_store, :sequence, :stop]`.
    A `duration` key will be set in measurements using monotonic time native units.

    The arguments `sequence` and `reason` are part of the event metadata.
    """
    @spec execute_segments_store_sequence_stop(
            GenServer.server(),
            SegmentsStore.Sequence.t(),
            atom(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_stop(
          self,
          %SegmentsStore.Sequence{} = sequence,
          reason,
          %SegmentsStore.State{} = _state
        )
        when is_server(self) and is_atom(reason) do
      measurements = get_telemetry_measurements(%{})

      execute_event(
        [:bacstack, :segments_store, :sequence, :stop],
        Map.put(measurements, :duration, measurements.monotonic_time - sequence.monotonic_time),
        %{
          self: self,
          sequence: sequence,
          reason: reason,
          telemetry_span_context: {sequence.source_address, sequence.invoke_id}
        }
      )
    end

    @doc """
    Executes telemetry for an error or exception as `[:bacstack, :trend_logger, :exception]`.

    The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.
    """
    @spec execute_trend_logger_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_exception(
          self,
          kind,
          reason,
          stacktrace,
          %{} = basic_metadata,
          %TrendLogger.State{} = _state
        )
        when is_server(self) and is_list(stacktrace) do
      execute_event(
        [:bacstack, :trend_logger, :exception],
        get_telemetry_measurements(%{}),
        Map.merge(
          %{
            self: self,
            kind: kind,
            reason: reason,
            stacktrace: stacktrace
          },
          basic_metadata
        )
      )
    end

    @doc """
    Executes telemetry for log object start as `[:bacstack, :trend_logger, :log_object, :start]`.
    This function is called when a log object gets added to the Trend Logger.

    The argument `log` is part of the event metadata.
    """
    @spec execute_trend_logger_log_start(
            GenServer.server(),
            TrendLogger.Log.t(),
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_start(
          self,
          %TrendLogger.Log{} = log,
          %TrendLogger.State{} = _state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :trend_logger, :log_object, :start],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          log: log,
          telemetry_span_context: {self, log.object}
        }
      )
    end

    @doc """
    Executes telemetry for log object stop as `[:bacstack, :trend_logger, :log_object, :stop]`.
    This function is called when a log object gets removed from the Trend Logger.

    The argument `log` is part of the event metadata.
    """
    @spec execute_trend_logger_log_stop(
            GenServer.server(),
            TrendLogger.Log.t(),
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_stop(
          self,
          %TrendLogger.Log{} = log,
          %TrendLogger.State{} = _state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :trend_logger, :log_object, :stop],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          log: log,
          telemetry_span_context: {self, log.object}
        }
      )
    end

    @doc """
    Executes telemetry for notifications of the log object
    as `[:bacstack, :trend_logger, :log_object, :notify]`.
    This function is called when a log object produces
    notifications in the Trend Logger.
    Notify types can happen concurrently, so be prepared.

    The arguments `log` and `notify_type` are part of the event metadata.
    """
    @spec execute_trend_logger_log_notify(
            GenServer.server(),
            TrendLogger.Log.t(),
            :buffer_full | :intrinsic_reporting,
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_notify(
          self,
          %TrendLogger.Log{} = log,
          notify_type,
          %TrendLogger.State{} = _state
        )
        when is_server(self) and is_atom(notify_type) do
      execute_event(
        [:bacstack, :trend_logger, :log_object, :notify],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          log: log,
          notify_type: notify_type,
          telemetry_span_context: {self, log.object}
        }
      )
    end

    @doc """
    Executes telemetry for trigger of the log object
    as `[:bacstack, :trend_logger, :log_object, :notify]`.
    This function is called when a log object gets
    triggered to log in the Trend Logger.

    The argument `log` and `log_entry` are part of the event metadata.
    """
    @spec execute_trend_logger_log_trigger(
            GenServer.server(),
            TrendLogger.Log.t(),
            ConfirmedEventNotification.t()
            | UnconfirmedEventNotification.t()
            | ConfirmedCovNotification.t()
            | ObjectsUtility.bacnet_object()
            | [ObjectsUtility.bacnet_object()]
            | :interrupted
            | {:time_change, float()},
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_trigger(
          self,
          %TrendLogger.Log{} = log,
          log_entry,
          %TrendLogger.State{} = _state
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :trend_logger, :log_object, :trigger],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          log: log,
          log_entry: log_entry,
          telemetry_span_context: {self, log.object}
        }
      )
    end

    @doc """
    Executes telemetry for updates to the log object
    as `[:bacstack, :trend_logger, :log_object, :update]`.
    This function is called when a log object gets updated in the Trend Logger.
    Updates may happen explicitely by the user (changing properties,
    enabling/disabling, etc.), or by updates to the buffer
    produced by the logging algorithm.

    The arguments `log` and `type` is part of the event metadata.
    """
    @spec execute_trend_logger_log_update(
            GenServer.server(),
            TrendLogger.Log.t(),
            :buffer | :state,
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_update(
          self,
          %TrendLogger.Log{} = log,
          type,
          %TrendLogger.State{} = _state
        )
        when is_server(self) and is_atom(type) do
      execute_event(
        [:bacstack, :trend_logger, :log_object, :update],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          log: log,
          type: type,
          telemetry_span_context: {self, log.object}
        }
      )
    end

    @doc """
    Executes telemetry for subscribing COV
    as `[:bacstack, :trend_logger, :lookup_object, :cov_sub]`.
    This function is called when subscribing for COV
    in the Trend Logger. Most notably for COV logs.

    The argument `object_ref` is part of the event metadata.
    """
    @spec execute_trend_logger_cov_sub(
            GenServer.server(),
            DeviceObjectPropertyRef.t()
          ) :: :ok
    def execute_trend_logger_cov_sub(
          self,
          %DeviceObjectPropertyRef{} = object_ref
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :trend_logger, :lookup_object, :cov_sub],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          object_ref: object_ref,
          telemetry_span_context: {self, object_ref}
        }
      )
    end

    @doc """
    Executes telemetry for unsubscribing COV
    as `[:bacstack, :trend_logger, :lookup_object, :cov_unsub]`.
    This function is called when unsubscribing for COV
    in the Trend Logger. Most notably for COV logs.

    The argument `object_ref` is part of the event metadata.
    """
    @spec execute_trend_logger_cov_unsub(
            GenServer.server(),
            DeviceObjectPropertyRef.t()
          ) :: :ok
    def execute_trend_logger_cov_unsub(
          self,
          %DeviceObjectPropertyRef{} = object_ref
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :trend_logger, :lookup_object, :cov_unsub],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          object_ref: object_ref,
          telemetry_span_context: {self, object_ref}
        }
      )
    end

    @doc """
    Executes telemetry for error during look up objects
    as `[:bacstack, :trend_logger, :lookup_object, :error]`.

    A `duration` measurement is present in monotonic native units.
    For the calculation of duration, separate monotonic time is used
    and may differ a bit from both monotonic time present in start
    and stop metrics.

    The arguments `object_ref` and `error` are part of the event metadata.
    """
    @spec execute_trend_logger_lookup_object_error(
            GenServer.server(),
            DeviceObjectRef.t(),
            BACnetError.t(),
            integer()
          ) :: :ok
    def execute_trend_logger_lookup_object_error(
          self,
          %DeviceObjectRef{} = object_ref,
          %BACnetError{} = error,
          duration
        )
        when is_server(self) and is_integer(duration) do
      execute_event(
        [:bacstack, :trend_logger, :lookup_object, :error],
        get_telemetry_measurements(%{duration: duration}),
        %{
          self: self,
          object_ref: object_ref,
          error: error,
          telemetry_span_context: {self, object_ref}
        }
      )
    end

    @doc """
    Executes telemetry for looking up objects
    as `[:bacstack, :trend_logger, :lookup_object, :start]`.
    This function is called when objects are looked up
    in the Trend Logger. Most notably for poll logs.

    The argument `object_ref` is part of the event metadata.
    """
    @spec execute_trend_logger_lookup_object_start(
            GenServer.server(),
            DeviceObjectRef.t()
          ) :: :ok
    def execute_trend_logger_lookup_object_start(
          self,
          %DeviceObjectRef{} = object_ref
        )
        when is_server(self) do
      execute_event(
        [:bacstack, :trend_logger, :lookup_object, :start],
        get_telemetry_measurements(%{}),
        %{
          self: self,
          object_ref: object_ref,
          telemetry_span_context: {self, object_ref}
        }
      )
    end

    @doc """
    Executes telemetry for stop looking up objects
    as `[:bacstack, :trend_logger, :lookup_object, :stop]`.

    A `duration` measurement is present in monotonic native units.
    For the calculation of duration, separate monotonic time is used
    and may differ a bit from both monotonic time present in start
    and stop metrics.

    The arguments `object_ref` and `result` are part of the event metadata.
    """
    @spec execute_trend_logger_lookup_object_stop(
            GenServer.server(),
            DeviceObjectRef.t(),
            ObjectsUtility.bacnet_object(),
            integer()
          ) :: :ok
    def execute_trend_logger_lookup_object_stop(
          self,
          %DeviceObjectRef{} = object_ref,
          %{} = result,
          duration
        )
        when is_server(self) and is_integer(duration) do
      execute_event(
        [:bacstack, :trend_logger, :lookup_object, :stop],
        get_telemetry_measurements(%{duration: duration}),
        %{
          self: self,
          object_ref: object_ref,
          result: result,
          telemetry_span_context: {self, object_ref}
        }
      )
    end
  else
    @doc false
    @spec compiled_with_telemetry() :: boolean()
    def compiled_with_telemetry(), do: false

    # Dummy functions (NO-OP)
    ###############################################

    @doc false
    @spec execute_bbmd_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            BBMD.State.t()
          ) :: :ok
    def execute_bbmd_exception(
          _self,
          _kind,
          _reason,
          _stacktrace,
          %{} = _basic_metadata,
          %BBMD.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_bbmd_del_fd_registration(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()} | nil,
            BBMD.Registration.t(),
            BBMD.State.t()
          ) ::
            :ok
    def execute_bbmd_del_fd_registration(
          _self,
          _source_address,
          %BBMD.Registration{} = _registration,
          %BBMD.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_bbmd_add_fd_registration(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            BBMD.Registration.t(),
            BBMD.State.t()
          ) ::
            :ok
    def execute_bbmd_add_fd_registration(
          _self,
          _source_address,
          %BBMD.Registration{} = _registration,
          %BBMD.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_bbmd_read_fd_table(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            %{optional({:inet.ip_address(), :inet.port_number()}) => BBMD.Registration.t()},
            BBMD.State.t()
          ) ::
            :ok
    def execute_bbmd_read_fd_table(
          _self,
          _source_address,
          _registrations,
          %BBMD.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_bbmd_distribute_broadcast(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            Protocol.bvlc(),
            Protocol.apdu(),
            NPCI.t(),
            BBMD.State.t()
          ) :: :ok
    def execute_bbmd_distribute_broadcast(
          _self,
          _source_address,
          _bvlc,
          _apdu,
          %NPCI{} = _npci,
          %BBMD.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_bbmd_read_bdt(
            GenServer.server(),
            {{:inet.ip4_address(), :inet.port_number()}, :inet.port_number()},
            [BroadcastDistributionTableEntry.t()],
            BBMD.State.t()
          ) :: :ok
    def execute_bbmd_read_bdt(
          _self,
          _source_address,
          _bdt,
          %BBMD.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_bbmd_write_bdt(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            [BroadcastDistributionTableEntry.t()],
            BBMD.State.t()
          ) :: :ok
    def execute_bbmd_write_bdt(
          _self,
          _source_address,
          _bdt,
          %BBMD.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            Client.State.t()
          ) :: :ok
    def execute_client_exception(
          _self,
          _kind,
          _reason,
          _stacktrace,
          %{} = _basic_metadata,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Protocol.apdu(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu(
          _self,
          _source_address,
          _bvlc,
          _npci,
          _apdu,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu_decode_error(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            binary(),
            term(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_decode_error(
          _self,
          _source_address,
          _bvlc,
          _npci,
          _raw_apdu,
          _error,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu_duplicated(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Protocol.apdu(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_duplicated(
          _self,
          _source_address,
          _bvlc,
          _npci,
          _apdu,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu_handled(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Protocol.apdu(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_handled(
          _self,
          _source_address,
          _bvlc,
          _npci,
          _apdu,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu_rejected(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Reject.t(),
            Protocol.apdu(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_rejected(
          _self,
          _source_address,
          __bvlc,
          _npci,
          _reject_apdu,
          _original_apdu,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu_segmentation_completed(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            binary(),
            binary(),
            IncompleteAPDU.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_segmentation_completed(
          _self,
          _source_address,
          _bvlc,
          _npci,
          _raw_apdu,
          _complete_apdu,
          %IncompleteAPDU{} = _incomplete,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu_segmentation_incomplete(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            binary(),
            IncompleteAPDU.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_segmentation_incomplete(
          _self,
          _source_address,
          _bvlc,
          _npci,
          _raw_apdu,
          %IncompleteAPDU{} = _incomplete,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu_segmentation_error(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            binary(),
            term(),
            boolean(),
            IncompleteAPDU.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_segmentation_error(
          _self,
          _source_address,
          _bvlc,
          _npci,
          _raw_apdu,
          %IncompleteAPDU{} = _incomplete,
          _error,
          _cancelled,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu_reply(
            GenServer.server(),
            Protocol.apdu(),
            Keyword.t(),
            Client.ReplyTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_reply(
          _self,
          _apdu,
          _send_opts,
          %Client.ReplyTimer{} = _timer,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_inc_apdu_timeout(
            GenServer.server(),
            Client.ReplyTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_inc_apdu_timeout(
          _self,
          %Client.ReplyTimer{} = _timer,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_request_start(
            GenServer.server(),
            term(),
            Protocol.apdu(),
            Keyword.t(),
            Client.ApduTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_request_start(
          _self,
          _destination,
          _apdu,
          _send_opts,
          %Client.ApduTimer{} = _timer,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_request_stop(
            GenServer.server(),
            term(),
            Protocol.bvlc(),
            NPCI.t(),
            Protocol.apdu(),
            Client.ApduTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_request_stop(
          _self,
          _destination,
          _bvlc,
          _npci,
          _apdu,
          %Client.ApduTimer{} = _timer,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_request_apdu_timer(
            GenServer.server(),
            Client.ApduTimer.t(),
            Client.State.t()
          ) :: :ok
    def execute_client_request_apdu_timer(
          _self,
          %Client.ApduTimer{} = _timer,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_send(
            GenServer.server(),
            term(),
            Protocol.apdu(),
            Keyword.t(),
            boolean(),
            Client.State.t()
          ) :: :ok
    def execute_client_send(
          _self,
          _destination,
          _apdu,
          _send_opts,
          _segmented,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_send_error(
            GenServer.server(),
            term(),
            Protocol.apdu(),
            Keyword.t(),
            Protocol.apdu(),
            atom(),
            Client.State.t()
          ) :: :ok
    def execute_client_send_error(
          _self,
          _destination,
          _original_apdu,
          _send_opts,
          _reply_apdu,
          _reason,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_client_transport_message(
            GenServer.server(),
            TransportBehaviour.transport_msg(),
            Client.State.t()
          ) :: :ok
    def execute_client_transport_message(
          _self,
          _transport_msg,
          %Client.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_foreign_device_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            ForeignDevice.State.t()
          ) ::
            :ok
    def execute_foreign_device_exception(
          _self,
          _kind,
          _reason,
          _stacktrace,
          %{} = _basic_metadata,
          %ForeignDevice.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_foreign_device_distribute_broadcast(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            UnconfirmedServiceRequest.t(),
            Keyword.t(),
            Client.server()
          ) :: :ok
    def execute_foreign_device_distribute_broadcast(
          _self,
          _bbmd,
          %UnconfirmedServiceRequest{} = _apdu,
          _send_opts,
          _client
        ),
        do: :ok

    @doc false
    @spec execute_foreign_device_read_bdt(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            [BroadcastDistributionTableEntry.t()],
            Client.server()
          ) :: :ok
    def execute_foreign_device_read_bdt(
          _self,
          _bbmd,
          _bdt,
          _client
        ),
        do: :ok

    @doc false
    @spec execute_foreign_device_write_bdt(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            [BroadcastDistributionTableEntry.t()],
            Client.server()
          ) :: :ok
    def execute_foreign_device_write_bdt(
          _self,
          _bbmd,
          _bdt,
          _client
        ),
        do: :ok

    @doc false
    @spec execute_foreign_device_read_fd_table(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            [ForeignDeviceTableEntry.t()],
            Client.server()
          ) :: :ok
    def execute_foreign_device_read_fd_table(
          _self,
          _bbmd,
          _registrations,
          _client
        ),
        do: :ok

    @doc false
    @spec execute_foreign_device_add_fd_registration(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            ForeignDevice.Registration.t(),
            ForeignDevice.State.t()
          ) :: :ok
    def execute_foreign_device_add_fd_registration(
          _self,
          _bbmd,
          %ForeignDevice.Registration{} = _registration,
          %ForeignDevice.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_foreign_device_del_fd_registration(
            GenServer.server(),
            {:inet.ip4_address(), :inet.port_number()},
            ForeignDevice.Registration.t(),
            ForeignDevice.State.t()
          ) :: :ok
    def execute_foreign_device_del_fd_registration(
          _self,
          _bbmd,
          %ForeignDevice.Registration{} = _registration,
          %ForeignDevice.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segmentator_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_exception(
          _self,
          _kind,
          _reason,
          _stacktrace,
          %{} = _basic_metadata,
          %Segmentator.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segmentator_sequence_ack(
            GenServer.server(),
            Segmentator.Sequence.t(),
            SegmentACK.t(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_ack(
          _self,
          %Segmentator.Sequence{} = _sequence,
          %SegmentACK{} = _ack,
          %Segmentator.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segmentator_sequence_error(
            GenServer.server(),
            module(),
            TransportBehaviour.transport(),
            TransportBehaviour.portal(),
            term(),
            Protocol.apdu() | nil,
            Keyword.t() | nil,
            Protocol.apdu() | nil,
            atom(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_error(
          _self,
          _transport_module,
          _transport,
          _portal,
          _destination,
          _original_apdu,
          _send_opts,
          _reply_apdu,
          _reason,
          %Segmentator.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segmentator_sequence_start(
            GenServer.server(),
            Segmentator.Sequence.t(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_start(
          _self,
          %Segmentator.Sequence{} = _sequence,
          %Segmentator.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segmentator_sequence_segment(
            GenServer.server(),
            Segmentator.Sequence.t(),
            non_neg_integer(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_segment(
          _self,
          %Segmentator.Sequence{} = _sequence,
          _segment_number,
          %Segmentator.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segmentator_sequence_stop(
            GenServer.server(),
            Segmentator.Sequence.t(),
            atom(),
            Segmentator.State.t()
          ) :: :ok
    def execute_segmentator_sequence_stop(
          _self,
          %Segmentator.Sequence{} = _sequence,
          _reason,
          %Segmentator.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segments_store_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_exception(
          _self,
          _kind,
          _reason,
          _stacktrace,
          %{} = _basic_metadata,
          %SegmentsStore.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segments_store_sequence_ack(
            GenServer.server(),
            SegmentsStore.Sequence.t(),
            SegmentACK.t(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_ack(
          _self,
          %SegmentsStore.Sequence{} = _sequence,
          %SegmentACK{} = _ack,
          %SegmentsStore.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segments_store_sequence_error(
            GenServer.server(),
            module(),
            TransportBehaviour.portal(),
            term(),
            IncompleteAPDU.t() | nil,
            Keyword.t() | nil,
            Protocol.apdu() | nil,
            atom(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_error(
          _self,
          _transport_module,
          _portal,
          _destination,
          _incomplete_apdu,
          _send_opts,
          _reply_apdu,
          _reason,
          %SegmentsStore.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segments_store_sequence_start(
            GenServer.server(),
            SegmentsStore.Sequence.t(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_start(
          _self,
          %SegmentsStore.Sequence{} = _sequence,
          %SegmentsStore.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segments_store_sequence_segment(
            GenServer.server(),
            SegmentsStore.Sequence.t(),
            non_neg_integer(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_segment(
          _self,
          %SegmentsStore.Sequence{} = _sequence,
          _segment_number,
          %SegmentsStore.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_segments_store_sequence_stop(
            GenServer.server(),
            SegmentsStore.Sequence.t(),
            atom(),
            SegmentsStore.State.t()
          ) :: :ok
    def execute_segments_store_sequence_stop(
          _self,
          %SegmentsStore.Sequence{} = _sequence,
          _reason,
          %SegmentsStore.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_exception(
            GenServer.server(),
            term(),
            term(),
            list(),
            map(),
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_exception(
          _self,
          _kind,
          _reason,
          _stacktrace,
          %{} = _basic_metadata,
          %TrendLogger.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_log_start(
            GenServer.server(),
            TrendLogger.Log.t(),
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_start(
          _self,
          %TrendLogger.Log{} = _log,
          %TrendLogger.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_log_stop(
            GenServer.server(),
            TrendLogger.Log.t(),
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_stop(
          _self,
          %TrendLogger.Log{} = _log,
          %TrendLogger.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_log_update(
            GenServer.server(),
            TrendLogger.Log.t(),
            :buffer | :state,
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_update(
          _self,
          %TrendLogger.Log{} = _log,
          _type,
          %TrendLogger.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_log_notify(
            GenServer.server(),
            TrendLogger.Log.t(),
            :buffer_full | :intrinsic_reporting,
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_notify(
          _self,
          %TrendLogger.Log{} = _log,
          _notify_type,
          %TrendLogger.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_log_trigger(
            GenServer.server(),
            TrendLogger.Log.t(),
            ConfirmedEventNotification.t()
            | UnconfirmedEventNotification.t()
            | ConfirmedCovNotification.t()
            | ObjectsUtility.bacnet_object()
            | [ObjectsUtility.bacnet_object()]
            | :interrupted
            | {:time_change, float()},
            TrendLogger.State.t()
          ) :: :ok
    def execute_trend_logger_log_trigger(
          _self,
          %TrendLogger.Log{} = _log,
          _log_entry,
          %TrendLogger.State{} = _state
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_cov_sub(
            GenServer.server(),
            DeviceObjectPropertyRef.t()
          ) :: :ok
    def execute_trend_logger_cov_sub(
          _self,
          %DeviceObjectPropertyRef{} = _object_ref
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_cov_unsub(
            GenServer.server(),
            DeviceObjectPropertyRef.t()
          ) :: :ok
    def execute_trend_logger_cov_unsub(
          _self,
          %DeviceObjectPropertyRef{} = _object_ref
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_lookup_object_error(
            GenServer.server(),
            DeviceObjectRef.t(),
            BACnetError.t(),
            integer()
          ) :: :ok
    def execute_trend_logger_lookup_object_error(
          _self,
          %DeviceObjectRef{} = _object_ref,
          %BACnetError{} = _error,
          _duration
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_lookup_object_start(
            GenServer.server(),
            DeviceObjectRef.t()
          ) :: :ok
    def execute_trend_logger_lookup_object_start(
          _self,
          %DeviceObjectRef{} = _object_ref
        ),
        do: :ok

    @doc false
    @spec execute_trend_logger_lookup_object_stop(
            GenServer.server(),
            DeviceObjectRef.t(),
            ObjectsUtility.bacnet_object(),
            integer()
          ) :: :ok
    def execute_trend_logger_lookup_object_stop(
          _self,
          %DeviceObjectRef{} = _object_ref,
          %{} = _result,
          _duration
        ),
        do: :ok
  end
end
