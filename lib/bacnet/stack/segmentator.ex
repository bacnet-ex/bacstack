defmodule BACnet.Stack.Segmentator do
  @moduledoc """
  The Segmentator module is responsible for sending segmented requests or responses.
  Incoming segments need to be handled manually or through the `BACnet.Stack.SegmentsStore` module.

  The Segmentator segments the given APDU (`ComplexACK` or `ConfirmedServiceRequest`) into segments
  of maximum APDU size and checks if the remote device supports the amount of segments.
  Both parameters need to be discovered by the user and given to this module, when creating a segmented sequence.

  The Segmentator will automatically send segments in the window size given by the remote device and
  wait for their acknowledgement. Timeouts and retransmissions are handled automatically.
  Responses and retransmissions to the destination of a segmented request or response are automatically sent.

  When the remote device is outside of the local network (packets are routed through a router),
  this module will automatically overwrite the "Proposed Window Size" with 1, to ensure segments ordering.
  Due to the nature of the UDP protocol (which BACnet/IP is based on), UDP re-ordering can occur and thus
  segments may arrive out-of-order.
  Re-ordering through the network may not occurr on other transport mediums. Whether a destination is outside
  of the local network is determined through the `BACnet.Stack.TransportBehaviour` module.

  The Segmentator module is transport layer agnostic due to the nature of using the `TransportBehaviour`.

  Users of this module need to route incoming `Abort`, `Error`, `Reject` and `SegmentACK` APDUs to this module,
  so the Segmentator can function properly. See the `handle_apdu/3` documentation.

  This module is written to not require one instance per destination or transport layer protocol, as such when creating
  a new sequence, the transport module, transport, portal, and destination parameters need to be given.

  When wanting to send a new segmented request or response, first a new sequence must be created. As soon as the sequence
  is created, transmitting the segments, retransmissions and timeouts are handled automatically.
  """

  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.Constants
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Telemetry
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [is_server: 1, log_debug: 1]

  require Constants
  require Logger

  use GenServer

  @apdu_timer_offset 50

  @min_apdu 50
  @max_apdu 1476

  @default_apdu_retries 3
  @default_apdu_timeout 3000

  # 50ms time is given for a remote device to interrupt the sequence stream (negative ACK)
  @sequence_send_timer 50

  defmodule Sequence do
    @moduledoc """
    Internal module for `BACnet.Stack.Segmentator`.

    It is used to keep track of segmentation status and information,
    segmentation segments and transport information.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            module: module(),
            transport: term(),
            portal: term(),
            destination: term(),
            invoke_id: byte(),
            server: boolean(),
            sequence_number: non_neg_integer(),
            window_size: pos_integer(),
            retry_count: non_neg_integer(),
            segments: map(),
            send_opts: Keyword.t(),
            monotonic_time: integer(),
            timer: term(),
            seq_timer: term(),
            callback_to: pid() | nil,
            callback_msg: term()
          }

    @fields [
      :module,
      :transport,
      :portal,
      :destination,
      :invoke_id,
      :server,
      :sequence_number,
      :window_size,
      :retry_count,
      :segments,
      :send_opts,
      :monotonic_time,
      :timer,
      :seq_timer,
      :callback_to,
      :callback_msg
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule State do
    @moduledoc """
    Internal module for `BACnet.Stack.Segmentator`.

    It is used as `GenServer` state.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            sequences: %{
              optional({destination_address :: term(), invoke_id :: byte()}) =>
                %BACnet.Stack.Segmentator.Sequence{}
            },
            opts: %{
              apdu_retries: non_neg_integer(),
              apdu_timeout: pos_integer()
            }
          }

    @fields [:sequences, :opts]
    @enforce_keys @fields
    defstruct @fields
  end

  @typedoc """
  Represents a server process of the Segmentator module.
  """
  @type server :: GenServer.server()

  @typedoc """
  Valid start options. For a description of each, see `start_link/1`.
  """
  @type start_option ::
          {:apdu_retries, pos_integer()}
          | {:apdu_timeout, pos_integer()}
          | GenServer.option()

  @typedoc """
  List of start options.
  """
  @type start_options :: [start_option()]

  @doc """
  Starts and links the Segmentator.

  The following options need to be given, in addition to `t:GenServer.options/0`:
    - `apdu_retries: pos_integer()` - Optional. The amount of APDU sending retries (defaults to 3).
    - `apdu_timeout: pos_integer()` - Optional. The APDU timeout to be waiting for a response, in ms (defaults to 3000ms).
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {opts2, genserver_opts} = Keyword.split(opts, [:apdu_retries, :apdu_timeout])
    validate_start_link_opts(opts2, "start_link/1")

    GenServer.start_link(__MODULE__, Map.new(opts2), genserver_opts)
  end

  @doc """
  Configure the segmentator.

  Only some of the available `t:start_options/0` can be configured,
  unsupported options can only be changed by re-starting the segmentator completely.

  The following options are supported:
  - `apdu_retries`
  - `apdu_timeout`

  For a description of each option, see `start_link/1`.
  """
  @spec configure(server(), start_options()) :: :ok
  def configure(server, opts) when is_server(server) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "configure/2 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    validate_start_link_opts(opts, "configure/2")

    Enum.each(opts, fn
      # Supported options
      {key, _val}
      when key in [:apdu_retries, :apdu_timeout] ->
        true

      {key, _val} ->
        raise ArgumentError,
              "configure/2 does not support option " <> inspect(key)
    end)

    GenServer.call(server, {:configure, Map.new(opts)})
  end

  @doc """
  Creates a new Sequence for an APDU.

  This module will automatically send the segments or abort APDUs.
  Received `Abort` and `SegmentACK` APDUs need to be piped into this module through `handle_apdu/3`.

  The tuple form of `apdu` allows already encoded APDU data to be segmented more efficiently
  without doing the whole encoding of the APDU again.
  It uses the `EncoderProtocol.encode_to_segmented/3` function.

  The `opts` argument will be passed on to the transport module's send function without modification,
  with the exception of two options specific for this module:
  - `callback_to: pid()` - Optional. Specify the PID to be sent a message when the sequence finishes or cancels.
  - `callback_msg: term()` - Optional. Used for the second tuple element in the message. Must be used with `callback_to`.
    Messages sent to `callback_to` have the form of `{state, callback_msg}`, where `state` can be `:done | :timeout | :cancelled`.
  """
  @spec create_sequence(
          server(),
          {transport_module :: module(), transport :: TransportBehaviour.transport(),
           portal :: TransportBehaviour.portal()},
          term(),
          APDU.ConfirmedServiceRequest.t()
          | APDU.ComplexACK.t()
          | {APDU.ConfirmedServiceRequest.t() | APDU.ComplexACK.t(), iodata()},
          non_neg_integer(),
          non_neg_integer(),
          Keyword.t()
        ) :: :ok | {:error, term()}
  def create_sequence(
        server,
        transport,
        destination,
        apdu,
        max_apdu_size,
        max_segments,
        opts \\ []
      )

  def create_sequence(
        server,
        {transport_module, transport, portal},
        destination,
        %APDU.ConfirmedServiceRequest{proposed_window_size: window} = apdu,
        max_apdu_size,
        max_segments,
        opts
      )
      when is_server(server) and is_atom(transport_module) and window in 1..127 and
             max_apdu_size in @min_apdu..@max_apdu and
             is_integer(max_segments) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "create_sequence/9 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    GenServer.call(
      server,
      {:create, {transport_module, transport, portal}, destination, apdu, opts, max_apdu_size,
       max_segments}
    )
  end

  def create_sequence(
        server,
        {transport_module, transport, portal},
        destination,
        {%APDU.ConfirmedServiceRequest{proposed_window_size: window}, _data} = apdu,
        max_apdu_size,
        max_segments,
        opts
      )
      when is_server(server) and is_atom(transport_module) and window in 1..127 and
             max_apdu_size in @min_apdu..@max_apdu and
             is_integer(max_segments) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "create_sequence/9 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    GenServer.call(
      server,
      {:create, {transport_module, transport, portal}, destination, apdu, opts, max_apdu_size,
       max_segments}
    )
  end

  def create_sequence(
        server,
        {transport_module, transport, portal},
        destination,
        %APDU.ComplexACK{proposed_window_size: window} = apdu,
        max_apdu_size,
        max_segments,
        opts
      )
      when is_server(server) and is_atom(transport_module) and window in 1..127 and
             max_apdu_size in @min_apdu..@max_apdu and
             is_integer(max_segments) and is_list(opts) do
    GenServer.call(
      server,
      {:create, {transport_module, transport, portal}, destination, apdu, opts, max_apdu_size,
       max_segments}
    )
  end

  def create_sequence(
        server,
        {transport_module, transport, portal},
        destination,
        {%APDU.ComplexACK{proposed_window_size: window}, _data} = apdu,
        max_apdu_size,
        max_segments,
        opts
      )
      when is_server(server) and is_atom(transport_module) and window in 1..127 and
             max_apdu_size in @min_apdu..@max_apdu and
             is_integer(max_segments) and is_list(opts) do
    GenServer.call(
      server,
      {:create, {transport_module, transport, portal}, destination, apdu, opts, max_apdu_size,
       max_segments}
    )
  end

  @doc """
  Handles incoming `Abort`, `Error`, `Reject` and `SegmentACK` APDUs.

  Received `Abort`, `Error`, `Reject` and `SegmentACK` APDUs need to be piped into this module using this function.
  Only then this module can automatically function correctly and transmit or retransmit the segments.

  Unknown destination-invoke ID mappings are silently ignored. As such the user can simply call this function
  with all matching APDUs. Although if there is a lot of traffic, the user should consider filtering and only
  call this function with interesting APDUs (APDUs for segmented requests/responses).
  """
  @spec handle_apdu(
          server(),
          term(),
          APDU.Abort.t() | APDU.Error.t() | APDU.Reject.t() | APDU.SegmentACK.t()
        ) ::
          :ok | {:error, term()}
  def handle_apdu(server, destination, %APDU.Abort{} = apdu) when is_server(server) do
    GenServer.call(server, {:ack, destination, apdu})
  end

  def handle_apdu(server, destination, %APDU.Error{} = apdu) when is_server(server) do
    GenServer.call(server, {:ack, destination, apdu})
  end

  def handle_apdu(server, destination, %APDU.Reject{} = apdu) when is_server(server) do
    GenServer.call(server, {:ack, destination, apdu})
  end

  def handle_apdu(server, destination, %APDU.SegmentACK{} = apdu) when is_server(server) do
    GenServer.call(server, {:ack, destination, apdu})
  end

  @doc false
  def init(opts) do
    new_opts =
      opts
      |> Map.put_new(:apdu_retries, @default_apdu_retries)
      |> Map.put_new(:apdu_timeout, @default_apdu_timeout)

    state = %State{
      sequences: %{},
      opts: new_opts
    }

    log_debug(fn -> "Segmentator: Started on #{inspect(self())}" end)

    {:ok, state, :hibernate}
  end

  @doc false
  def handle_call({:configure, %{} = opts}, _from, %State{} = state) do
    new_state = %{state | opts: Map.merge(state.opts, opts)}
    {:reply, :ok, new_state}
  end

  def handle_call(
        {:create, {module, transport, portal}, destination, apdu, opts, apdu_size, max_segments},
        _from,
        %State{} = state
      ) do
    # apdu is either the APDU struct or a tuple of the struct and encoded data
    {apdu_struct, encoded_data} =
      case apdu do
        {apdu, data} -> {apdu, data}
        other -> {other, nil}
      end

    log_debug(fn ->
      "Segmentator: Received create request for " <>
        "#{inspect(destination)}:#{inspect(apdu_struct.invoke_id)}"
    end)

    id = {destination, apdu_struct.invoke_id}

    {reply, new_state} =
      if Map.has_key?(state.sequences, id) do
        {{:error, :already_exists}, state}
      else
        new_apdu_struct =
          if module.destination_routed?(transport, destination) do
            log_debug(fn ->
              "Segmentator: Overriding window size (destination routing) for " <>
                "#{inspect(destination)}:#{inspect(apdu_struct.invoke_id)}"
            end)

            # Create new APDU with window_size = 1
            # since UDP does not guarantee ordering
            # so we only do window of 1 to ensure the ordering
            # when the packet is bound to be routed and can be re-ordered
            # This is inefficient, but effective to keep ordering
            %{apdu_struct | proposed_window_size: 1}
          else
            apdu_struct
          end

        try do
          # Catch any errors when trying to encode the APDU

          apdu_bin =
            if encoded_data do
              EncoderProtocol.encode_to_segmented(new_apdu_struct, encoded_data, apdu_size)
            else
              EncoderProtocol.encode_segmented(new_apdu_struct, apdu_size)
            end

          apdu_bin
          |> Stream.with_index(0)
          |> Map.new(fn {value, key} ->
            {key, value}
          end)
        catch
          kind, e ->
            Telemetry.execute_segmentator_exception(
              self(),
              kind,
              e,
              __STACKTRACE__,
              %{
                transport_module: module,
                transport: transport,
                portal: portal,
                destination: destination,
                apdu: apdu_struct
              },
              state
            )

            {{:error, {e, __STACKTRACE__}}, state}
        else
          segments ->
            # Assert remote device can handle that many segments
            if max_segments == 0 or map_size(segments) <= max_segments do
              {callback_to, opts} = Keyword.pop(opts, :callback_to)
              {callback_msg, opts} = Keyword.pop(opts, :callback_msg)

              new_sequence = %Sequence{
                module: module,
                transport: transport,
                portal: portal,
                destination: destination,
                server: EncoderProtocol.response?(apdu_struct),
                invoke_id: apdu_struct.invoke_id,
                sequence_number: 0,
                # Window size will be overwritten by SegmentACK later
                window_size: 1,
                retry_count: 0,
                send_opts: opts,
                segments: segments,
                monotonic_time: System.monotonic_time(),
                timer:
                  Process.send_after(
                    self(),
                    {:timer, id},
                    state.opts.apdu_timeout + @apdu_timer_offset
                  ),
                seq_timer: nil,
                callback_to: callback_to,
                callback_msg: callback_msg
              }

              Telemetry.execute_segmentator_sequence_start(self(), new_sequence, state)

              # If the transport module support reply_postponed/3, send Reply-Postponed Frame
              # ASHRAE 135 Clause 9.8 (it is unlikely another transport layer implements it for any other reason)
              postponed_result =
                if function_exported?(module, :reply_postponed, 3) do
                  case module.reply_postponed(portal, destination, []) do
                    :ok ->
                      :ok

                    # An error like :slave_mode is not continuable,
                    # as only a master node can hold the token,
                    # and we need the token for segmentation
                    {:error, continuable}
                    when continuable in [:no_reply_pending, :destination_is_not_expecting_reply] ->
                      :ok

                    {:error, _err} = err ->
                      err
                  end
                else
                  :ok
                end

              case postponed_result do
                :ok ->
                  # Send first segment and wait for Segment ACK
                  case module.send(portal, destination, Map.get(segments, 0), opts) do
                    :ok ->
                      new_state = %State{
                        state
                        | sequences: Map.put(state.sequences, id, new_sequence)
                      }

                      {:ok, new_state}

                    {:error, _err} = error ->
                      log_transport_send_error(error)

                      Telemetry.execute_segmentator_sequence_stop(
                        self(),
                        new_sequence,
                        :transport_error,
                        state
                      )

                      {error, state}
                  end

                _other ->
                  {postponed_result, state}
              end
            else
              # Too many segments for the remote device, send BUFFER_OVERFLOW Abort
              abort = %APDU.Abort{
                sent_by_server: EncoderProtocol.response?(apdu_struct),
                invoke_id: apdu_struct.invoke_id,
                reason: Constants.macro_assert_name(:abort_reason, :buffer_overflow)
              }

              Telemetry.execute_segmentator_sequence_error(
                self(),
                module,
                transport,
                portal,
                destination,
                apdu_struct,
                opts,
                abort,
                :buffer_overflow,
                state
              )

              log_transport_send_error(module.send(portal, destination, abort, opts))

              {{:error, :too_many_segments}, state}
            end
        end
      end

    {:reply, reply, new_state}
  end

  def handle_call(
        {:ack, destination, %APDU.SegmentACK{actual_window_size: window_size} = apdu},
        _from,
        %State{} = state
      )
      when window_size < 1 or window_size > 127 do
    # Received invalid ACK from a remote BACnet device
    log_debug(fn ->
      "Segmentator: Received invalid window_size ACK request for " <>
        "#{inspect(destination)}:#{inspect(apdu.invoke_id)}"
    end)

    id = {destination, apdu.invoke_id}

    {reply, new_state} =
      case Map.fetch(state.sequences, id) do
        {:ok, %Sequence{module: module} = sequence} ->
          if sequence.timer do
            Process.cancel_timer(sequence.timer)
          end

          if sequence.seq_timer do
            Process.cancel_timer(sequence.seq_timer)
          end

          # Invalid APDU, actual window size is outside of the valid range 1..127
          abort = %APDU.Abort{
            sent_by_server: not apdu.sent_by_server,
            invoke_id: apdu.invoke_id,
            reason: Constants.macro_assert_name(:abort_reason, :window_size_out_of_range)
          }

          log_transport_send_error(
            module.send(sequence.portal, destination, abort, sequence.send_opts)
          )

          Telemetry.execute_segmentator_sequence_error(
            self(),
            module,
            sequence.transport,
            sequence.portal,
            destination,
            nil,
            nil,
            abort,
            :invalid_window_size,
            state
          )

          {:ok, %State{state | sequences: Map.delete(state.sequences, id)}}

        # Unknown sequence, silently ignore
        :error ->
          {:ok, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call(
        {:ack, destination, %APDU.SegmentACK{negative_ack: false} = apdu},
        _from,
        %State{} = state
      ) do
    # Received positive ACK from a remote BACnet device
    log_debug(fn ->
      "Segmentator: Received ACK request for " <>
        "#{inspect(destination)}:#{inspect(apdu.invoke_id)}"
    end)

    id = {destination, apdu.invoke_id}

    {reply, new_state} =
      case Map.fetch(state.sequences, id) do
        # Reached end of segments, mission completed
        {:ok, %Sequence{segments: segments} = sequence}
        when apdu.sequence_number + 1 >= map_size(segments) ->
          if sequence.timer do
            Process.cancel_timer(sequence.timer)
          end

          if sequence.seq_timer do
            Process.cancel_timer(sequence.seq_timer)
          end

          Telemetry.execute_segmentator_sequence_stop(self(), sequence, :completed, state)

          if is_pid(sequence.callback_to) do
            send(sequence.callback_to, {:done, sequence.callback_msg})
          end

          {:ok, %State{state | sequences: Map.delete(state.sequences, id)}}

        {:ok, %Sequence{} = sequence} ->
          if sequence.timer do
            Process.cancel_timer(sequence.timer)
          end

          if sequence.seq_timer do
            Process.cancel_timer(sequence.seq_timer)
          end

          Telemetry.execute_segmentator_sequence_ack(self(), sequence, apdu, state)

          new_sequence =
            send_segments(
              id,
              %Sequence{
                sequence
                | sequence_number: apdu.sequence_number + apdu.actual_window_size,
                  window_size: apdu.actual_window_size
              },
              apdu.sequence_number + 1,
              min(apdu.sequence_number + apdu.actual_window_size, map_size(sequence.segments)),
              state
            )

          new_state = %State{state | sequences: Map.put(state.sequences, id, new_sequence)}
          {:ok, new_state}

        # Unknown sequence, silently ignore
        :error ->
          {:ok, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call(
        {:ack, destination, %APDU.SegmentACK{negative_ack: true} = apdu},
        _from,
        %State{} = state
      ) do
    # Received negative ACK from a remote BACnet device, start sending from given sequence number
    log_debug(fn ->
      "Segmentator: Received NAK request for " <>
        "#{inspect(destination)}:#{inspect(apdu.invoke_id)}"
    end)

    id = {destination, apdu.invoke_id}

    {reply, new_state} =
      case Map.fetch(state.sequences, id) do
        {:ok, %Sequence{} = sequence} ->
          if sequence.timer do
            Process.cancel_timer(sequence.timer)
          end

          if sequence.seq_timer do
            Process.cancel_timer(sequence.seq_timer)
          end

          Telemetry.execute_segmentator_sequence_ack(self(), sequence, apdu, state)

          new_sequence =
            send_segments(
              id,
              %Sequence{sequence | window_size: apdu.actual_window_size},
              apdu.sequence_number,
              min(apdu.sequence_number + apdu.actual_window_size, map_size(sequence.segments)),
              state
            )

          new_state = %State{state | sequences: Map.put(state.sequences, id, new_sequence)}
          {:ok, new_state}

        # Unknown sequence, silently ignore
        :error ->
          {:ok, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call(
        {:ack, destination, %type{} = apdu},
        _from,
        %State{} = state
      )
      when type in [APDU.Abort, APDU.Error, APDU.Reject] do
    # Received Abort/Error/Reject from a remote BACnet device, abort sequence
    log_debug(fn ->
      "Segmentator: Received Abort/Error/Reject request for " <>
        "#{inspect(destination)}:#{inspect(apdu.invoke_id)}"
    end)

    id = {destination, apdu.invoke_id}

    {reply, new_state} =
      case Map.fetch(state.sequences, id) do
        {:ok, %Sequence{} = sequence} ->
          if sequence.timer do
            Process.cancel_timer(sequence.timer)
          end

          if sequence.seq_timer do
            Process.cancel_timer(sequence.seq_timer)
          end

          Telemetry.execute_segmentator_sequence_stop(
            self(),
            sequence,
            :cancelled_by_remote,
            state
          )

          if is_pid(sequence.callback_to) do
            send(sequence.callback_to, {:cancelled, sequence.callback_msg})
          end

          new_state = %State{state | sequences: Map.delete(state.sequences, id)}
          {:ok, new_state}

        # Unknown sequence, silently ignore
        :error ->
          {:ok, state}
      end

    {:reply, reply, new_state}
  end

  @doc false
  def handle_info({:timer, id}, %State{} = state) do
    # Check if timer is still relevant (sequence has not been dropped yet)
    # Sequence is dropped on abort or completion
    # If still relevant, send same sequence segment(s) again as missing ACK

    new_state =
      case Map.fetch(state.sequences, id) do
        # Abort mission, drop sequence
        {:ok, %Sequence{module: module, retry_count: retry_count} = sequence}
        when retry_count >= state.opts.apdu_retries ->
          if sequence.seq_timer do
            # Cancel any active sequence segment timer
            Process.cancel_timer(sequence.seq_timer)
          end

          # ASHRAE 135 5.4.4 [Requesting BACnet User (client)]
          # State SEGMENTED_REQUEST: [Segmentator]
          #  Timeout: Retry
          #  FinalTimeout: Abort-APDU to local application program and enter IDLE
          #
          # State AWAIT_CONFIRMATION: [Client]
          #  TimeoutSegmented: Retry
          #  FinalTimeout: Abort-APDU to local application program and enter IDLE
          #
          # State SEGMENTED_CONF: [SegmentsStore]
          #  Timeout: Abort-APDU to local application program and enter IDLE
          #
          # ASHRAE 135 5.4.5 [Responding BACnet User (server)]
          # State SEGMENTED_REQUEST: [SegmentsStore]
          #  Timeout: Stop SegmentTimer and enter IDLE
          #
          # State AWAIT_RESPONSE: [Client]
          #  Timeout: Abort-APDU to local application program and enter IDLE
          #
          # State SEGMENTED_RESPONSE: [Segmentator]
          #  FinalTimeout: Stop SegmentTimer and enter IDLE
          #
          # CONCLUSION: No Abort-APDU is ever sent to the remote BACnet user

          abort = %APDU.Abort{
            sent_by_server: sequence.server,
            invoke_id: sequence.invoke_id,
            reason: Constants.macro_assert_name(:abort_reason, :tsm_timeout)
          }

          Telemetry.execute_segmentator_sequence_error(
            self(),
            module,
            sequence.transport,
            sequence.portal,
            sequence.destination,
            nil,
            nil,
            abort,
            :timeout,
            state
          )

          Telemetry.execute_segmentator_sequence_stop(self(), sequence, :timeout, state)

          if is_pid(sequence.callback_to) do
            send(sequence.callback_to, {:timeout, sequence.callback_msg})
          end

          %State{state | sequences: Map.delete(state.sequences, id)}

        {:ok, %Sequence{} = sequence} ->
          if sequence.seq_timer do
            # Cancel any active sequence segment timer
            Process.cancel_timer(sequence.seq_timer)
          end

          Telemetry.execute_segmentator_sequence_error(
            self(),
            sequence.module,
            sequence.transport,
            sequence.portal,
            sequence.destination,
            nil,
            nil,
            nil,
            :timeout,
            state
          )

          new_sequence =
            send_segments(
              id,
              sequence,
              sequence.sequence_number,
              min(sequence.sequence_number + sequence.window_size, map_size(sequence.segments)),
              state
            )

          %State{
            state
            | sequences:
                Map.put(state.sequences, id, %{
                  new_sequence
                  | retry_count: sequence.retry_count + 1
                })
          }

        # Unknown sequence, silently ignore
        :error ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info({:seq_timer, id, seq_number_next, seq_number_end}, %State{} = state) do
    # Send the next segment, as we did not receive a negative ACK in the given time window

    new_state =
      case Map.fetch(state.sequences, id) do
        {:ok, %Sequence{} = sequence} ->
          new_sequence =
            send_segments(
              id,
              sequence,
              seq_number_next,
              seq_number_end,
              state
            )

          %State{state | sequences: Map.put(state.sequences, id, new_sequence)}

        # Unknown sequence, silently ignore
        :error ->
          state
      end

    {:noreply, new_state}
  end

  defp send_segments(
         id,
         %Sequence{module: module, window_size: window_size} = sequence,
         seq_number_start,
         seq_number_end,
         %State{} = state
       )
       when window_size == 1 or seq_number_start == seq_number_end do
    case module.send(
           sequence.portal,
           sequence.destination,
           Map.fetch!(sequence.segments, seq_number_start),
           sequence.send_opts
         ) do
      :ok ->
        Telemetry.execute_segmentator_sequence_segment(self(), sequence, seq_number_start, state)

      {:error, _err} = error ->
        log_transport_send_error(error)

        Telemetry.execute_segmentator_exception(
          self(),
          :error,
          error,
          [Telemetry.make_stacktrace_from_env(__ENV__)],
          %{sequence: sequence},
          state
        )
    end

    %Sequence{
      sequence
      | timer:
          Process.send_after(self(), {:timer, id}, state.opts.apdu_timeout + @apdu_timer_offset),
        seq_timer: nil
    }
  end

  defp send_segments(
         id,
         %Sequence{module: module} = sequence,
         seq_number_start,
         seq_number_end,
         %State{} = state
       ) do
    case module.send(
           sequence.portal,
           sequence.destination,
           Map.fetch!(sequence.segments, seq_number_start),
           sequence.send_opts
         ) do
      :ok ->
        Telemetry.execute_segmentator_sequence_segment(self(), sequence, seq_number_start, state)

      {:error, _err} = error ->
        log_transport_send_error(error)

        Telemetry.execute_segmentator_exception(
          self(),
          :error,
          error,
          [Telemetry.make_stacktrace_from_env(__ENV__)],
          %{sequence: sequence},
          state
        )
    end

    # New apdu timeout is set in the last window segment
    %Sequence{
      sequence
      | timer: nil,
        seq_timer:
          Process.send_after(
            self(),
            {:seq_timer, id, seq_number_start + 1, seq_number_end},
            @sequence_send_timer
          )
    }
  end

  defp log_transport_send_error(return_value)
  defp log_transport_send_error(:ok), do: :ok

  defp log_transport_send_error({:error, error}),
    do:
      Logger.error(fn ->
        "Segmentator: Unable to send APDU, transport error: #{inspect(error)}"
      end)

  defp validate_start_link_opts(opts, mfa) when is_binary(mfa) do
    case opts[:apdu_retries] do
      nil ->
        :ok

      term when is_integer(term) ->
        :ok

      term ->
        raise ArgumentError,
              mfa <> " expected apdu_retries to be an integer, got: #{inspect(term)}"
    end

    case opts[:apdu_timeout] do
      nil ->
        :ok

      term when is_integer(term) ->
        :ok

      term ->
        raise ArgumentError,
              mfa <> " expected apdu_timeout to be an integer, got: #{inspect(term)}"
    end
  end
end
