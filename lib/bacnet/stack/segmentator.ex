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
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [log_debug: 1]

  require Constants
  require Logger

  use GenServer

  @min_apdu 50
  @max_apdu 1476

  @default_apdu_retries 3
  @default_apdu_timeout 3000

  # 50ms time is given for a remote device to interrupt the sequence stream (negative ACK)
  @sequence_send_timer 50

  defmodule Sequence do
    @moduledoc false

    @type t :: %__MODULE__{
            module: module(),
            portal: term(),
            destination: term(),
            invoke_id: byte(),
            sequence_number: non_neg_integer(),
            window_size: pos_integer(),
            segments: map(),
            send_opts: Keyword.t(),
            timer: :timer.tref(),
            seq_timer: :timer.tref()
          }

    @fields [
      :module,
      :portal,
      :destination,
      :invoke_id,
      :sequence_number,
      :window_size,
      :segments,
      :send_opts,
      :timer,
      :seq_timer
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule State do
    @moduledoc false

    # Sequences is a map that is mapped by destination_address and invoke_id
    @type t :: %__MODULE__{
            sequences: %{optional({term(), byte()}) => %BACnet.Stack.Segmentator.Sequence{}},
            opts: map()
          }

    @fields [:sequences, :opts]
    @enforce_keys @fields
    defstruct @fields
  end

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
    validate_start_link_opts(opts2)

    GenServer.start_link(__MODULE__, Map.new(opts2), genserver_opts)
  end

  @doc """
  Creates a new Sequence for an APDU.

  This module will automatically send the segments or abort APDUs.
  Received `Abort` and `SegmentACK` APDUs need to be piped into this module through `handle_apdu/3`.

  The `opts` argument will be passed on to the transport module's send function without modification.
  """
  @spec create_sequence(
          GenServer.server(),
          {transport_module :: module(), transport :: TransportBehaviour.transport(),
           portal :: TransportBehaviour.portal()},
          term(),
          APDU.ConfirmedServiceRequest.t() | APDU.ComplexACK.t(),
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
      when is_atom(transport_module) and window in 1..127 and
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
      when is_atom(transport_module) and window in 1..127 and
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
          GenServer.server(),
          term(),
          APDU.Abort.t() | APDU.Error.t() | APDU.Reject.t() | APDU.SegmentACK.t()
        ) ::
          :ok | {:error, term()}
  def handle_apdu(server, destination, %APDU.Abort{} = apdu) do
    GenServer.call(server, {:ack, destination, apdu})
  end

  def handle_apdu(server, destination, %APDU.Error{} = apdu) do
    GenServer.call(server, {:ack, destination, apdu})
  end

  def handle_apdu(server, destination, %APDU.Reject{} = apdu) do
    GenServer.call(server, {:ack, destination, apdu})
  end

  def handle_apdu(server, destination, %APDU.SegmentACK{actual_window_size: window} = apdu)
      when window in 1..127 do
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
  def handle_call(
        {:create, {module, transport, portal}, destination, %{} = apdu, opts, apdu_size,
         max_segments},
        _from,
        %State{} = state
      ) do
    log_debug(fn ->
      "Segmentator: Received create request for " <>
        "#{inspect(destination)}:#{inspect(apdu.invoke_id)}"
    end)

    id = {destination, apdu.invoke_id}

    {reply, new_state} =
      if Map.has_key?(state.sequences, id) do
        {{:error, :already_exists}, state}
      else
        new_apdu =
          if module.is_destination_routed(transport, destination) do
            log_debug(fn ->
              "Segmentator: Overriding window size (destination routing) for " <>
                "#{inspect(destination)}:#{inspect(apdu.invoke_id)}"
            end)

            # Create new APDU with window_size = 1
            # since UDP does not guarantee ordering
            # so we only do window of 1 to ensure the ordering
            # when the packet is bound to be routed and can be re-ordered
            # This is inefficient, but effective to keep ordering
            %{apdu | proposed_window_size: 1}
          else
            apdu
          end

        try do
          # Catch any errors when trying to encode the APDU
          new_apdu
          |> BACnet.Stack.EncoderProtocol.encode_segmented(apdu_size)
          |> Stream.with_index(0)
          |> Stream.map(fn {value, key} ->
            {key, value}
          end)
          |> Enum.into(%{})
        catch
          _kind, e -> {{:error, e}, state}
        else
          segments ->
            # Assert remote device can handle that many segments
            if max_segments == 0 or map_size(segments) <= max_segments do
              new_sequence = %Sequence{
                module: module,
                portal: portal,
                destination: destination,
                invoke_id: apdu.invoke_id,
                sequence_number: 0,
                window_size: nil,
                send_opts: opts,
                segments: segments,
                timer: Process.send_after(self(), {:timer, id}, state.opts.apdu_timeout),
                seq_timer: nil
              }

              # Send first segment and wait for Segment ACK
              module.send(portal, destination, Map.get(segments, 0), opts)

              new_state = %State{state | sequences: Map.put(state.sequences, id, new_sequence)}
              {:ok, new_state}
            else
              # Too many segments for the remote device, send BUFFER_OVERFLOW Abort
              abort = %APDU.Abort{
                sent_by_server: true,
                invoke_id: apdu.invoke_id,
                reason: Constants.macro_assert_name(:abort_reason, :buffer_overflow)
              }

              module.send(portal, destination, abort, opts)
              {{:error, :too_many_segments}, state}
            end
        end
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
      if Map.has_key?(state.sequences, id) do
        sequence = Map.get(state.sequences, id)
        Process.cancel_timer(sequence.timer)

        if sequence.seq_timer do
          Process.cancel_timer(sequence.seq_timer)
        end

        new_sequence =
          send_segments(
            id,
            %Sequence{sequence | window_size: apdu.actual_window_size},
            apdu.sequence_number + 1,
            apdu.sequence_number + apdu.actual_window_size,
            state
          )

        new_state = %State{state | sequences: Map.put(state.sequences, id, new_sequence)}
        {:ok, new_state}
      else
        # Unknown sequence, silently ignore
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
      if Map.has_key?(state.sequences, id) do
        sequence = Map.get(state.sequences, id)

        if sequence.seq_timer do
          Process.cancel_timer(sequence.seq_timer)
        end

        new_sequence =
          send_segments(
            id,
            %Sequence{sequence | window_size: apdu.actual_window_size},
            apdu.sequence_number,
            apdu.sequence_number + apdu.actual_window_size,
            state
          )

        new_state = %State{state | sequences: Map.put(state.sequences, id, new_sequence)}
        {:ok, new_state}
      else
        # Unknown sequence, silently ignore
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
      if Map.has_key?(state.sequences, id) do
        sequence = Map.get(state.sequences, id)

        if sequence.seq_timer do
          Process.cancel_timer(sequence.seq_timer)
        end

        new_state = %State{state | sequences: Map.delete(state.sequences, id)}
        {:ok, new_state}
      else
        # Unknown sequence, silently ignore
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
      if Map.has_key?(state.sequences, id) do
        sequence = Map.get(state.sequences, id)

        if sequence.seq_timer do
          # Cancel any active sequence segment timer
          Process.cancel_timer(sequence.seq_timer)
        end

        new_sequence =
          send_segments(
            id,
            sequence,
            sequence.sequence_number,
            sequence.sequence_number + sequence.window_size,
            state
          )

        %State{state | sequences: Map.put(state.sequences, id, new_sequence)}
      else
        # Unknown sequence, silently ignore
        state
      end

    {:noreply, new_state}
  end

  def handle_info({:seq_timer, id, seq_number_next, seq_number_end}, %State{} = state) do
    # Send the next segment, as we did not receive a negative ACK in the given time window

    new_state =
      if Map.has_key?(state.sequences, id) do
        sequence = Map.get(state.sequences, id)

        new_sequence =
          send_segments(
            id,
            sequence,
            seq_number_next,
            seq_number_end,
            state
          )

        %State{state | sequences: Map.put(state.sequences, id, new_sequence)}
      else
        # Unknown sequence, silently ignore
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
    module.send(
      sequence.portal,
      sequence.destination,
      Map.get(sequence.segments, seq_number_start),
      sequence.send_opts
    )

    %Sequence{
      sequence
      | sequence_number: seq_number_start + 1,
        timer: Process.send_after(self(), {:timer, id}, state.opts.apdu_timeout),
        seq_timer: nil
    }
  end

  defp send_segments(
         id,
         %Sequence{module: module, window_size: window_size} = sequence,
         seq_number_start,
         seq_number_end,
         %State{} = _state
       ) do
    module.send(
      sequence.portal,
      sequence.destination,
      Map.get(sequence.segments, seq_number_start),
      sequence.send_opts
    )

    # New apdu timeout is set in the last window segment
    %Sequence{
      sequence
      | sequence_number: seq_number_start + window_size,
        timer: nil,
        seq_timer:
          Process.send_after(
            self(),
            {:seq_timer, id, seq_number_start + 1, seq_number_end},
            @sequence_send_timer
          )
    }
  end

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
  end
end
