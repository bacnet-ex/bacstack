defmodule BACnet.Stack.SegmentsStore do
  @moduledoc """
  The Segments Store module handles incoming segments of a segmented request or response.
  Outgoing segments need to be handled manually or through the `BACnet.Stack.Segmentator` module.

  New segment sequences are automatically created when receiving a segmented request or response,
  through the `segment/6` function. Responses to the source of a segmented request or response are
  automatically sent.

  Users of this module need to route incoming `Abort`, `Error`, `Reject` and segmented APDUs
  (identified by the `:incomplete` tuple of `BACnet.APDU.decode/1`) to this module,
  so the Segments Store can function properly. See the `cancel/3` and `segment/6` documentation.

  The Segments Store module is transport layer agnostic due to the nature of using
  the `BACnet.Stack.TransportBehaviour`.

  This module is written to not require one instance per destination or transport layer protocol,
  as such when handling a segment, the transport module, portal, and source address need to be given.

  Please note that in some circumstances, such as BACnet/IP and IP routing, the packets are under subject
  to packet re-ordering. To address this, you may overwrite the window size field for packets outside
  of the local network using `BACnet.IncompleteAPDU.set_window_size/2` before calling `segment/6`.
  The value should be set to `1`, so for each segment an acknowledge needs to be sent (thus preventing
  packet re-ordering and packets arriving out of order).
  """

  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.IncompleteAPDU
  alias BACnet.Stack.Telemetry
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [log_debug: 1]

  require Constants
  require Logger

  use GenServer

  @default_apdu_retries 3
  @default_apdu_timeout 3000
  @default_max_segments :more_than_64

  defmodule Sequence do
    @moduledoc """
    Internal module for `BACnet.Stack.SegmentsStore`.

    It is used to keep track of segmentation status and information,
    segmentation segments and transport information.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            transport_module: module(),
            portal: TransportBehaviour.portal(),
            source_address: term(),
            send_opts: Keyword.t(),
            server: boolean(),
            invoke_id: non_neg_integer(),
            window_size: non_neg_integer(),
            count_segments: non_neg_integer(),
            segments: [binary()],
            timer: term(),
            initial_sequence_number: non_neg_integer(),
            last_sequence_number: non_neg_integer() | nil,
            last_sequence_time: integer() | nil,
            duplicate_count: non_neg_integer(),
            timeout_count: non_neg_integer(),
            monotonic_time: integer()
          }

    @fields [
      :transport_module,
      :portal,
      :source_address,
      :send_opts,
      :server,
      :invoke_id,
      :window_size,
      :count_segments,
      :segments,
      :timer,
      :initial_sequence_number,
      :last_sequence_number,
      :last_sequence_time,
      :duplicate_count,
      :timeout_count,
      :monotonic_time
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule State do
    @moduledoc """
    Internal module for `BACnet.Stack.SegmentsStore`.

    It is used as `GenServer` state.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            sequences: %{
              optional({source_address :: term(), invoke_id :: byte()}) =>
                %BACnet.Stack.SegmentsStore.Sequence{}
            },
            opts: map()
          }

    @fields [
      :sequences,
      :opts
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  @typedoc """
  Represents a server process of the Segments Store module.
  """
  @type server :: GenServer.server()

  @typedoc """
  Valid start options. For a description of each, see `start_link/1`.
  """
  @type start_option ::
          {:apdu_retries, pos_integer()}
          | {:apdu_timeout, pos_integer()}
          | {:max_segments, Constants.max_segments()}
          | GenServer.option()

  @typedoc """
  List of start options.
  """
  @type start_options :: [start_option()]

  @doc """
  Starts and links the Segments Store.

  The following options are available, in addition to `t:GenServer.options/0`:
    - `apdu_retries: pos_integer()` - Optional. The amount of APDU sending retries (defaults to 3).
    - `apdu_timeout: pos_integer()` - Optional. The APDU timeout to be waiting for a response, in ms (defaults to 3000ms).
    - `max_segments: Constants.max_segments()` - Optional. The maximum amount of segments to allow (defaults to `:more_than_64`).
      While `:unspecified` is allowed here, it shouldn't be used anywhere, because it makes it for the server unable to determine
      if the response is transmittable. Since this setting here does not go to the server, `:unspecified` is allowed here.
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {opts2, genserver_opts} = Keyword.split(opts, [:apdu_retries, :apdu_timeout])
    validate_start_link_opts(opts2)

    GenServer.start_link(__MODULE__, Map.new(opts2), genserver_opts)
  end

  @doc """
  Sends a segment to the Store to be handled. `cancel` specifies whether segmentation is aborted/cancelled.

  If no segment sequence for the source address and invoke ID exist yet, one will be created automatically. Sequences
  aborted by the Store are automatically removed from it and the remote BACnet device is notified.

  Once all segments have been received, an ok-tuple is returned with the complete APDU binary data,
  which then can be decoded using the `BACnet.Protocol` module.

  This module sends answers directly to the remote BACnet device, as such the transport module and portal needs to be specified.

  The `opts` argument will be passed on to the transport module's send function without modification.
  """
  @spec segment(
          server(),
          IncompleteAPDU.t(),
          module(),
          TransportBehaviour.portal(),
          term(),
          Keyword.t()
        ) ::
          {:ok, complete_data :: binary()} | :incomplete | {:error, term(), cancel :: boolean()}
  def segment(
        server,
        %IncompleteAPDU{} = incomplete,
        transport,
        portal,
        source_address,
        opts \\ []
      )
      when is_list(opts) do
    if transport.is_valid_destination(source_address) do
      GenServer.call(server, {:segment, incomplete, {transport, portal}, source_address, opts})
    else
      {:error, :invalid_source_address, true}
    end
  end

  @doc """
  Cancels a segment sequence in the Store.

  This function must be called by the user when one of the following conditions is met:
    - Abort PDU received with the same invoke ID
    - Error PDU received with the same invoke ID
    - Reject PDU received with the same invoke ID
    - SimpleACK PDU received with the same invoke ID

  This function does nothing if no sequence exists in the Store, thus it is safe to call it,
  even if no segmentation is in progress. Although if there is a lot of traffic, the user
  should consider filtering and only call this function with interesting
  APDUs (APDUs for segmented requests/responses).
  """
  @spec cancel(
          server(),
          term(),
          APDU.Abort.t()
          | APDU.Error.t()
          | APDU.Reject.t()
          | APDU.SimpleACK.t()
          | (invoke_id :: 0..255)
        ) :: :ok
  def cancel(server, source_address, apdu)

  def cancel(server, source_address, %APDU.Abort{} = abort),
    do: GenServer.cast(server, {:cancel, abort.invoke_id, source_address})

  def cancel(server, source_address, %APDU.Error{} = error),
    do: GenServer.cast(server, {:cancel, error.invoke_id, source_address})

  def cancel(server, source_address, %APDU.Reject{} = reject),
    do: GenServer.cast(server, {:cancel, reject.invoke_id, source_address})

  def cancel(server, source_address, %APDU.SimpleACK{} = simple),
    do: GenServer.cast(server, {:cancel, simple.invoke_id, source_address})

  def cancel(server, source_address, invoke_id) when invoke_id in 0..255 do
    GenServer.cast(server, {:cancel, invoke_id, source_address})
  end

  @doc false
  def init(opts) do
    new_opts =
      opts
      |> Map.put_new(:apdu_retries, @default_apdu_retries)
      |> Map.put_new(:apdu_timeout, @default_apdu_timeout)
      |> Map.put_new(:max_segments, @default_max_segments)

    state = %State{
      sequences: %{},
      opts: new_opts
    }

    log_debug(fn -> "SegmentsStore: Started on #{inspect(self())}" end)

    {:ok, state, :hibernate}
  end

  @doc false
  def handle_call(
        {:segment, %IncompleteAPDU{} = incomplete, {module, portal} = transport, source_addr,
         send_opts},
        _from,
        %State{} = state
      ) do
    log_debug(fn ->
      "SegmentsStore: Received segment request for " <>
        "#{inspect(source_addr)}:#{inspect(incomplete.invoke_id)}"
    end)

    id = {source_addr, incomplete.invoke_id}
    has_id = Map.has_key?(state.sequences, id)

    {reply, new_state} =
      cond do
        incomplete.window_size < 1 or incomplete.window_size > 127 ->
          # Invalid APDU, proposed window size is outside of the valid range 1..127
          abort = %APDU.Abort{
            sent_by_server: incomplete.server,
            invoke_id: incomplete.invoke_id,
            reason: Constants.macro_assert_name(:abort_reason, :window_size_out_of_range)
          }

          Telemetry.execute_segments_store_sequence_error(
            self(),
            module,
            portal,
            source_addr,
            incomplete,
            send_opts,
            abort,
            :invalid_window_size,
            state
          )

          log_transport_send_error(module.send(portal, source_addr, abort, send_opts))

          case Map.fetch(state.sequences, id) do
            {:ok, %Sequence{timer: timer} = _seq} -> Process.cancel_timer(timer)
            _else -> :ok
          end

          new_state = %State{state | sequences: Map.delete(state.sequences, id)}
          {{:error, :invalid_proposed_window_size, true}, new_state}

        incomplete.sequence_number == 0 and has_id ->
          # Invalid APDU, as sequence number 0 received even though we have an active sequence
          abort = %APDU.Abort{
            sent_by_server: incomplete.server,
            invoke_id: incomplete.invoke_id,
            reason: Constants.macro_assert_name(:abort_reason, :invalid_apdu_in_this_state)
          }

          Telemetry.execute_segments_store_sequence_error(
            self(),
            module,
            portal,
            source_addr,
            incomplete,
            send_opts,
            abort,
            :invalid_sequence_number,
            state
          )

          log_transport_send_error(module.send(portal, source_addr, abort, send_opts))

          Process.cancel_timer(Map.fetch!(state.sequences, id).timer)

          new_state = %State{state | sequences: Map.delete(state.sequences, id)}
          {{:error, :invalid_apdu_in_this_state, true}, new_state}

        incomplete.sequence_number != 0 and not has_id ->
          # Invalid APDU, as sequence number is not 0 and we have no active sequence
          abort = %APDU.Abort{
            sent_by_server: incomplete.server,
            invoke_id: incomplete.invoke_id,
            reason: Constants.macro_assert_name(:abort_reason, :invalid_apdu_in_this_state)
          }

          Telemetry.execute_segments_store_sequence_error(
            self(),
            module,
            portal,
            source_addr,
            incomplete,
            send_opts,
            abort,
            :invalid_sequence_number,
            state
          )

          log_transport_send_error(module.send(portal, source_addr, abort, send_opts))

          {{:error, :invalid_apdu_in_this_state, true}, state}

        true ->
          # Valid APDU
          sequence =
            get_or_create_sequence(incomplete, id, transport, source_addr, send_opts, state)

          if has_id do
            Process.cancel_timer(sequence.timer)
          end

          {reply, new_sequence} =
            cond do
              is_integer(state.opts.max_segments) and
                  sequence.count_segments >= state.opts.max_segments ->
                abort = %APDU.Abort{
                  sent_by_server: sequence.server,
                  invoke_id: sequence.invoke_id,
                  reason: Constants.macro_assert_name(:abort_reason, :buffer_overflow)
                }

                Telemetry.execute_segments_store_sequence_error(
                  self(),
                  module,
                  portal,
                  source_addr,
                  incomplete,
                  send_opts,
                  abort,
                  :buffer_overflow,
                  state
                )

                log_transport_send_error(
                  module.send(portal, sequence.source_address, abort, sequence.send_opts)
                )

                {{:error, :too_many_segments}, :drop}

              incomplete.sequence_number == (sequence.last_sequence_number || -1) + 1 ->
                Telemetry.execute_segments_store_sequence_segment(
                  self(),
                  sequence,
                  incomplete.sequence_number,
                  state
                )

                # Expected sequence number (last number + 1)
                handle_segment_expected_segment(
                  sequence,
                  incomplete,
                  transport,
                  source_addr,
                  state
                )

              true ->
                {err_code, new} =
                  if incomplete.sequence_number == sequence.last_sequence_number do
                    Telemetry.execute_segments_store_sequence_error(
                      self(),
                      module,
                      portal,
                      source_addr,
                      incomplete,
                      send_opts,
                      nil,
                      :duplicated_segment,
                      state
                    )

                    # Duplicated segment
                    handle_segment_duplicated_segment(
                      sequence,
                      transport,
                      source_addr,
                      state
                    )
                  else
                    Telemetry.execute_segments_store_sequence_error(
                      self(),
                      module,
                      portal,
                      source_addr,
                      incomplete,
                      send_opts,
                      nil,
                      :segment_out_of_order,
                      state
                    )

                    # Segment received out of order
                    handle_segment_out_of_order(
                      sequence,
                      transport,
                      source_addr,
                      state
                    )
                  end

                {{:error, err_code, false}, new}
            end

          {reply, handle_segment_compute_state(state, id, new_sequence)}
      end

    {:reply, reply, new_state}
  end

  @doc false
  def handle_cast({:cancel, invoke_id, source_addr}, %State{} = state) do
    log_debug(fn ->
      "SegmentsStore: Received cancel request for #{inspect(source_addr)}:#{invoke_id}"
    end)

    new_state =
      case Map.pop(state.sequences, {source_addr, invoke_id}) do
        {%Sequence{} = sequence, new_map} ->
          Telemetry.execute_segments_store_sequence_stop(
            self(),
            sequence,
            :cancelled_by_remote,
            state
          )

          %State{state | sequences: new_map}

        {_default, _old} ->
          state
      end

    {:noreply, new_state}
  end

  @doc false
  def handle_info({:timer, id}, %State{} = state) do
    # Check if timer is still relevant (sequence has not been dropped yet)
    # Sequence is dropped on abort or completion
    new_state =
      case Map.fetch(state.sequences, id) do
        {:ok, %Sequence{transport_module: module} = sequence} ->
          # Receiving segments has timed out
          new_sequence =
            if sequence.timeout_count + 1 >= state.opts.apdu_retries do
              abort = %APDU.Abort{
                sent_by_server: sequence.server,
                invoke_id: sequence.invoke_id,
                reason: Constants.macro_assert_name(:abort_reason, :tsm_timeout)
              }

              Telemetry.execute_segments_store_sequence_error(
                self(),
                module,
                sequence.portal,
                sequence.source_address,
                nil,
                sequence.send_opts,
                abort,
                :timeout,
                state
              )

              log_transport_send_error(
                module.send(sequence.portal, sequence.source_address, abort, sequence.send_opts)
              )

              :drop
            else
              Telemetry.execute_segments_store_sequence_error(
                self(),
                module,
                sequence.portal,
                sequence.source_address,
                nil,
                sequence.send_opts,
                nil,
                :timeout,
                state
              )

              # On timeout, increment counter
              %Sequence{sequence | timeout_count: sequence.timeout_count + 1}
            end

          handle_segment_compute_state(state, id, new_sequence)

        _else ->
          state
      end

    {:noreply, new_state}
  end

  defp get_or_create_sequence(
         %IncompleteAPDU{} = incomplete,
         id,
         {module, portal},
         source_addr,
         send_opts,
         %State{} = state
       ) do
    case Map.fetch(state.sequences, id) do
      {:ok, %Sequence{} = sequence} ->
        sequence

      :error ->
        log_debug(fn ->
          "SegmentsStore: Creating new sequence for #{inspect(source_addr)}:#{incomplete.invoke_id}"
        end)

        ack = %APDU.SegmentACK{
          negative_ack: false,
          sent_by_server: incomplete.server,
          invoke_id: incomplete.invoke_id,
          sequence_number: 0,
          actual_window_size: incomplete.window_size
        }

        # Send initial ACK with window_size
        log_transport_send_error(module.send(portal, source_addr, ack, send_opts))

        sequence = %Sequence{
          transport_module: module,
          portal: portal,
          source_address: source_addr,
          send_opts: send_opts,
          server: incomplete.server,
          invoke_id: incomplete.invoke_id,
          window_size: incomplete.window_size,
          count_segments: 0,
          segments: [],
          timer: Process.send_after(self(), {:timer, id}, state.opts.apdu_timeout),
          initial_sequence_number: incomplete.sequence_number,
          last_sequence_number: nil,
          last_sequence_time: nil,
          duplicate_count: 0,
          timeout_count: 0,
          monotonic_time: System.monotonic_time()
        }

        Telemetry.execute_segments_store_sequence_start(self(), sequence, state)
        Telemetry.execute_segments_store_sequence_ack(self(), sequence, ack, state)

        sequence
    end
  end

  @spec handle_segment_expected_segment(
          Sequence.t(),
          IncompleteAPDU.t(),
          {module(), pid() | port()},
          term(),
          State.t()
        ) :: {{:ok, binary()}, :drop} | {:incomplete, Sequence.t()}
  defp handle_segment_expected_segment(
         %Sequence{transport_module: module} = sequence,
         %IncompleteAPDU{} = incomplete,
         {module, portal},
         source_addr,
         %State{} = state
       ) do
    log_debug(fn ->
      "SegmentsStore: Received segment ##{incomplete.sequence_number} for " <>
        "#{inspect(source_addr)}:#{incomplete.invoke_id}"
    end)

    new = %Sequence{
      sequence
      | segments: [incomplete.data | sequence.segments],
        count_segments: sequence.count_segments + 1,
        last_sequence_number: incomplete.sequence_number,
        last_sequence_time: System.monotonic_time(:millisecond)
    }

    # Do not send segment ACK if it's the first segment - it has already been ACK'ed
    if not incomplete.more_follows or
         (Integer.mod(incomplete.sequence_number, sequence.window_size) == 0 and
            incomplete.sequence_number > 0) do
      log_debug(fn ->
        "SegmentsStore: Sending segment ACK on reaching window or end for #{inspect(source_addr)}:#{incomplete.invoke_id}"
      end)

      # Send ACK on last segment or if window size reached
      ack = %APDU.SegmentACK{
        negative_ack: false,
        sent_by_server: sequence.server,
        invoke_id: sequence.invoke_id,
        sequence_number: new.last_sequence_number,
        actual_window_size: sequence.window_size
      }

      Telemetry.execute_segments_store_sequence_ack(self(), sequence, ack, state)

      log_transport_send_error(module.send(portal, source_addr, ack, sequence.send_opts))
    end

    if incomplete.more_follows do
      if new.count_segments >= state.opts.max_segments do
        # Reached max segments but still incomplete, send abort
        log_debug(fn ->
          "SegmentsStore: Received max segments, still incomplete, " <>
            "sending abort for #{inspect(source_addr)}:#{incomplete.invoke_id}"
        end)

        abort = %APDU.Abort{
          sent_by_server: sequence.server,
          invoke_id: sequence.invoke_id,
          reason: Constants.macro_assert_name(:abort_reason, :buffer_overflow)
        }

        Telemetry.execute_segments_store_sequence_error(
          self(),
          module,
          sequence.portal,
          sequence.source_address,
          incomplete,
          sequence.send_opts,
          abort,
          :too_many_segments,
          state
        )

        log_transport_send_error(
          module.send(sequence.portal, sequence.source_address, abort, sequence.send_opts)
        )

        {{:error, :too_many_segments}, :drop}
      else
        {:incomplete, new}
      end
    else
      log_debug(fn ->
        "SegmentsStore: Received all segments for #{inspect(source_addr)}:#{incomplete.invoke_id}"
      end)

      complete_data =
        new.segments
        |> Enum.reverse()
        # Add APDU header (without segmented bit) to the segments
        |> then(&[incomplete.header | &1])
        |> Enum.join("")

      Telemetry.execute_segments_store_sequence_stop(self(), sequence, :completed, state)

      {{:ok, complete_data}, :drop}
    end
  end

  @spec handle_segment_duplicated_segment(
          Sequence.t(),
          {module(), pid() | port()},
          term(),
          State.t()
        ) :: {:duplicated_segments, Sequence.t()}
  defp handle_segment_duplicated_segment(
         %Sequence{} = sequence,
         {module, portal},
         source_addr,
         %State{} = state
       ) do
    dup_count =
      if sequence.duplicate_count + 1 >= sequence.window_size do
        log_debug(fn ->
          "SegmentsStore: Received duplicated segment #{sequence.last_sequence_number}, " <>
            "sending NAK for #{inspect(source_addr)}:#{sequence.invoke_id}"
        end)

        ack = %APDU.SegmentACK{
          negative_ack: true,
          sent_by_server: sequence.server,
          invoke_id: sequence.invoke_id,
          sequence_number: sequence.last_sequence_number,
          actual_window_size: sequence.window_size
        }

        Telemetry.execute_segments_store_sequence_ack(self(), sequence, ack, state)

        log_transport_send_error(module.send(portal, source_addr, ack, sequence.send_opts))

        0
      else
        log_debug(fn ->
          "SegmentsStore: Received duplicated segment #{sequence.last_sequence_number} " <>
            "for #{inspect(source_addr)}:#{sequence.invoke_id}"
        end)

        sequence.duplicate_count + 1
      end

    {:duplicated_segments,
     %Sequence{
       sequence
       | last_sequence_time: System.monotonic_time(:millisecond),
         duplicate_count: dup_count
     }}
  end

  @spec handle_segment_out_of_order(
          Sequence.t(),
          {module(), pid() | port()},
          term(),
          State.t()
        ) :: {:segments_out_of_order, Sequence.t()}
  defp handle_segment_out_of_order(
         %Sequence{} = sequence,
         {module, portal},
         source_addr,
         %State{} = state
       ) do
    log_debug(fn ->
      "SegmentsStore: Received segment #{sequence.last_sequence_number} out of order, " <>
        "sending NAK for #{inspect(source_addr)}:#{sequence.invoke_id}"
    end)

    ack = %APDU.SegmentACK{
      negative_ack: true,
      sent_by_server: sequence.server,
      invoke_id: sequence.invoke_id,
      sequence_number: sequence.last_sequence_number,
      actual_window_size: sequence.window_size
    }

    Telemetry.execute_segments_store_sequence_ack(self(), sequence, ack, state)

    log_transport_send_error(module.send(portal, source_addr, ack, sequence.send_opts))

    {:segments_out_of_order,
     %Sequence{
       sequence
       | last_sequence_time: System.monotonic_time(:millisecond)
     }}
  end

  @spec handle_segment_compute_state(State.t(), {term(), byte()}, Sequence.t() | :drop) ::
          State.t()
  defp handle_segment_compute_state(%State{} = state, id, new_sequence) do
    if new_sequence == :drop do
      %State{state | sequences: Map.delete(state.sequences, id)}
    else
      %State{
        state
        | sequences:
            Map.put(state.sequences, id, %{
              new_sequence
              | timer: Process.send_after(self(), {:timer, id}, state.opts.apdu_timeout),
                timeout_count: 0
            })
      }
    end
  end

  defp log_transport_send_error(return_value)
  defp log_transport_send_error(:ok), do: :ok

  defp log_transport_send_error({:error, error}),
    do:
      Logger.error(fn ->
        "SegmentsStore: Unable to send APDU, transport error: #{inspect(error)}"
      end)

  defp validate_start_link_opts(opts) do
    case opts[:apdu_retries] do
      nil ->
        :ok

      term when is_integer(term) ->
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected apdu_retries to be an integer, got: #{inspect(term)}"
    end

    case opts[:apdu_timeout] do
      nil ->
        :ok

      term when is_integer(term) ->
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected apdu_timeout to be an integer, got: #{inspect(term)}"
    end

    case opts[:max_segments] do
      nil ->
        :ok

      term when is_integer(term) ->
        :ok

      term when term == :more_than_64 or term == :unspecified ->
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected max_segments to be an integer or the atom unspecified or more_than_64, got: #{inspect(term)}"
    end
  end
end
