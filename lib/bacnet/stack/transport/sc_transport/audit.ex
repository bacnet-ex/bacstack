if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Audit do
    @moduledoc """
    Structured audit of property writes and routed frames from a BACnet/SC hub.

    ## Configuration

    Auditing is disabled by default. Pass an `:audit` keyword list to
    `BACnet.Stack.Transport.ScTransport.Hub.start_link/1` or
    `BACnet.Stack.Transport.ScTransport.Hub.reconfigure/2`.
    For a hub owned by a `BACnet.Stack.Transport.ScTransport.ManagedPort`,
    set `:audit` inside its `:hub` startup options.

    - `mode: :writes` records BACnet WriteProperty and WritePropertyMultiple
      requests, their correlated replies, and write decoding diagnostics.
    - `mode: :traffic` adds a raw event for every BVLC frame that reaches the
      hub's routing path, including routing drops. The scope covers frames
      from registered sessions. Connection-local exchanges, frames rejected
      before routing, and traffic that bypasses this hub fall outside it.
    - `:sink` is a one-argument callback that receives a
      `BACnet.Stack.Transport.ScTransport.Audit.Event`. Return `:ok` after
      accepting the event or `{:error, reason}` on failure. The application
      implements storage, indexing, and retention through this callback.
    - `:queue_limit` is a positive integer that limits outstanding captures,
      including the one being processed. It defaults to 1024.

    Supply your application's sink alongside the usual listener and TLS options.

    ```elixir
    alias BACnet.Stack.Transport.ScTransport.Hub

    audit = [mode: :writes, sink: &MyApp.AuditLog.append/1, queue_limit: 1_024]
    {:ok, hub} = Hub.start_link(Keyword.put(hub_options, :audit, audit))
    ```

    Reconfiguring the hub takes the full set of hub options. Include `:audit`
    to keep auditing enabled. Use `audit: nil` or omit the option to disable it.

    ## Records and peer identity

    Each event carries a UTC `timestamp`, the hub's UUID and VMAC, and a
    `capture_id`. In traffic mode, a raw frame and its decoded write event
    can share the same capture ID. Index by `kind` as well if storing both
    events by capture ID.

    `ingress` identifies the SC peer that sent the frame. It includes the
    peer's registered UUID and VMAC, remote IP address and port, and the
    SHA-256 digest of its authenticated TLS certificate in binary form.
    The peer supplies its UUID and VMAC during registration. Use the certificate
    fingerprint to identify the certificate the hub saw on that connection.
    `egress` identifies the selected SC peer for a queued unicast. For a
    routed BACnet packet, `npci.source` and `npci.destination` carry the
    BACnet addresses behind the SC peers, when present. Use these fields with
    `destination_vmac` and your site inventory to identify the target device.

    | Event kind | Contents |
    | --- | --- |
    | `:frame` | The ingress BVLC function, message ID, addresses, options, and original payload. Both the frame and its routing decision are recorded once per ingress, including for broadcasts. |
    | `:write_request` | The invoke ID, service, retry flag, and list of requested writes. Each write includes the object identifier, property identifier, optional array index, value, and supplied priority. A `nil` priority means the sender omitted it. |
    | `:write_result` | The linked write ID and the observed reply or expiry outcome. A WritePropertyMultiple error can include the first failed property reference. |
    | `:write_diagnostic` | The invoke ID, service, and reason when the worker can identify a write but cannot decode or assemble its details. |

    The `routing` field is `{:queued, count}`, `:no_recipient`,
    `:invalid_source`, or `:missing_destination`. A full egress queue reports
    `:egress_queue_full` if all recipients were dropped or
    `{:partially_queued, queued, dropped}` if some broadcast recipients were
    queued. A queued recipient
    can still drop the frame before sending it, for example if the frame
    exceeds its advertised receive limits.

    ## Matching replies to writes

    To review a write, filter `:write_request` events by time, sender,
    destination, object, and property. Join result events using
    `details.write_id`. Retransmissions of an outstanding request reuse
    that ID. An observed reply uses the responder as the event's ingress peer.

    The audit worker matches a reply to a queued unicast by reversing the SC
    sessions and any NPCI source and destination addresses, checking the
    invoke ID, and checking the service when the reply includes it. Ambiguous
    replies remain unassigned. Results can record a SimpleACK, Error, Reject,
    or server Abort. A SimpleACK records the device's BACnet acknowledgment.
    The device's effective property value requires a separate observation.

    An outstanding tracked request expires 60 seconds after its latest
    complete attempt. The worker emits `:reply_not_observed` with the original
    request's metadata and the time it reported the expiry. The worker can
    passively assemble up to 128 concurrent segmented writes, with a limit
    of 1024 segments and 256 KiB per write. A diagnostic can report an
    incomplete assembly or a reply observed before assembly finished.

    ## Delivery and capture gaps

    The hub keeps forwarding while a separate worker decodes captures and
    calls the sink serially. Each event gets one delivery attempt. If the
    sink returns `{:error, reason}`, the worker counts the failure in
    `:sink_failures`, discards the reason, and moves on to the next event.
    The worker tracks replies independently of sink delivery, so the sink
    may receive a `:write_result` for a request whose event it failed to store.

    A full queue drops new captures. The hub can also discard queued captures
    when the audit settings change or it shuts down. A capture gap clears
    pending matches and incomplete assemblies. Starting with the first
    captured frame after the gap, reply matching pauses for 60 seconds while
    the worker continues publishing write requests.
    Use `BACnet.Stack.Transport.ScTransport.Hub.audit_status/1` to monitor
    queued captures, queue drops, sink failures, and correlation losses.
    The counters are cumulative for the lifetime of the hub.

    Correlation losses counts disruptions to the audit worker's ability to
    match a BACnet reply to a write request.
    It increases when pending matches or segmented writes are discarded,
    when overlapping requests make a reply ambiguous, or when matching is
    paused after a capture gap. Resetting an active audit worker also adds one,
    so the counter is an indicator of lost tracking rather than an
    exact count of unmatched replies.
    """

    alias BACnet.Protocol
    alias BACnet.Protocol.APDU
    alias BACnet.Protocol.ApplicationTags.Encoding
    alias BACnet.Protocol.Constants
    alias BACnet.Protocol.SecureConnect.BVLC
    alias BACnet.Protocol.Services.Error.WritePropertyMultipleError
    alias BACnet.Protocol.Services.WriteProperty
    alias BACnet.Protocol.Services.WritePropertyMultiple

    require Constants
    use GenServer

    @lifetime 60_000
    @max_transactions 4096
    @max_assemblies 128
    @max_assembly_bytes 256 * 1024
    @max_segments 1024

    @confirmed Constants.macro_by_name(:pdu_type, :confirmed_request)
    @complex_ack Constants.macro_by_name(:pdu_type, :complex_ack)
    @write_property Constants.macro_by_name(:confirmed_service_choice, :write_property)
    @write_multiple Constants.macro_by_name(:confirmed_service_choice, :write_property_multiple)
    @write_services [@write_property, @write_multiple]
    @reply_types [
      Constants.macro_by_name(:pdu_type, :simple_ack),
      Constants.macro_by_name(:pdu_type, :error),
      Constants.macro_by_name(:pdu_type, :reject),
      Constants.macro_by_name(:pdu_type, :abort)
    ]

    defmodule Event do
      @moduledoc """
      An observation delivered to the hub's audit sink.

      A capture can produce both a raw frame and a write event. Results and
      retries use the first write observation's `capture_id` as their
      `write_id`. Expiry events carry the original observation's capture ID
      and the time the worker reported expiry.

      See also `BACnet.Stack.Transport.ScTransport.Audit`.
      """

      @typedoc """
      An ID unique to a capture within its audit worker's lifetime.
      """
      @type capture_id :: {<<_::128>>, pos_integer()}

      @typedoc """
      The registered BACnet/SC identity and authenticated TLS certificate.
      """
      @type peer :: %{
              uuid: <<_::128>>,
              vmac: BVLC.vmac(),
              remote: {:inet.ip_address(), :inet.port_number()},
              certificate_sha256: <<_::256>> | nil
            }

      @typedoc """
      A requested property write, including the priority if supplied.
      """
      @type property_write :: %{
              object_identifier: Protocol.ObjectIdentifier.t(),
              property_identifier: Constants.property_identifier() | non_neg_integer(),
              property_array_index: non_neg_integer() | nil,
              property_value: Encoding.t() | [Encoding.t()],
              priority: non_neg_integer() | nil
            }

      @typedoc """
      A hub routing decision. The recipient connection can still drop a queued frame.
      """
      @type routing ::
              :invalid_source
              | :missing_destination
              | :no_recipient
              | :egress_queue_full
              | {:queued, pos_integer()}
              | {:partially_queued, pos_integer(), pos_integer()}

      @typedoc """
      Metadata common to raw frames, write attempts, results, and diagnostics.
      """
      @type t :: %__MODULE__{
              kind: :frame | :write_request | :write_result | :write_diagnostic,
              timestamp: DateTime.t(),
              hub: %{uuid: <<_::128>>, vmac: BVLC.vmac()},
              capture_id: capture_id(),
              ingress: peer(),
              egress: peer() | nil,
              destination_vmac: BVLC.vmac() | nil,
              npci: Protocol.NPCI.t() | nil,
              routing: routing(),
              details: details()
            }

      @typedoc """
      The payload for the event's kind.
      """
      @type details ::
              BVLC.t()
              | %{
                  write_id: capture_id(),
                  invoke_id: byte(),
                  service: :write_property | :write_property_multiple,
                  writes: [property_write()],
                  retry: boolean()
                }
              | %{
                  required(:write_id) => capture_id(),
                  required(:outcome) =>
                    :acknowledged | :error | :rejected | :aborted | :reply_not_observed,
                  optional(:reply) =>
                    APDU.SimpleACK.t() | APDU.Error.t() | APDU.Reject.t() | APDU.Abort.t(),
                  optional(:first_failed_write_attempt) => Protocol.ObjectPropertyRef.t()
                }
              | %{
                  write_id: capture_id(),
                  invoke_id: byte(),
                  service: :write_property | :write_property_multiple,
                  reason: atom()
                }

      @fields [
        :kind,
        :timestamp,
        :hub,
        :capture_id,
        :ingress,
        :egress,
        :destination_vmac,
        :npci,
        :routing,
        :details
      ]
      @enforce_keys @fields
      defstruct @fields
    end

    defmodule Status do
      @moduledoc """
      Reports the hub's audit mode, outstanding captures, and cumulative loss counters.
      """

      @typedoc """
      Audit status for the lifetime of a hub.
      """
      @type t :: %__MODULE__{
              mode: :disabled | :writes | :traffic,
              queued: non_neg_integer(),
              queue_drops: non_neg_integer(),
              sink_failures: non_neg_integer(),
              correlation_losses: non_neg_integer()
            }

      @fields [:mode, :queued, :queue_drops, :sink_failures, :correlation_losses]
      @enforce_keys @fields
      defstruct @fields
    end

    @typedoc """
    A sink call runs in the audit worker and should return after accepting the event.
    """
    @type sink :: (Event.t() -> :ok | {:error, term()})

    @typedoc """
    Validated audit options. A nil configuration disables the stream.
    """
    @type config :: %{mode: :writes | :traffic, sink: sink(), queue_limit: pos_integer()}

    @doc false
    @spec configure(term()) :: {:ok, config() | nil} | {:error, :invalid_audit_options}
    def configure(nil), do: {:ok, nil}

    def configure(options) when is_list(options) do
      with true <- Keyword.keyword?(options),
           true <- Keyword.keys(options) -- [:mode, :sink, :queue_limit] == [],
           mode when mode in [:writes, :traffic] <- options[:mode],
           sink when is_function(sink, 1) <- options[:sink],
           limit when is_integer(limit) and limit > 0 <- Keyword.get(options, :queue_limit, 1024) do
        {:ok, %{mode: mode, sink: sink, queue_limit: limit}}
      else
        _invalid -> {:error, :invalid_audit_options}
      end
    end

    def configure(_options), do: {:error, :invalid_audit_options}

    @doc false
    @spec start_link({pid(), config(), boolean()}) :: GenServer.on_start()
    def start_link(args), do: GenServer.start_link(__MODULE__, args)

    @doc false
    def init({hub, config, paused?}) do
      {:ok,
       %{
         hub: hub,
         config: config,
         transactions: %{},
         assemblies: %{},
         paused_until: if(paused?, do: :gap),
         next_expiry: nil,
         failures: 0,
         losses: 0
       }}
    end

    @doc false
    def handle_cast({:capture, observation}, state) do
      state
      |> resume(observation.monotonic_time)
      |> advance(observation.monotonic_time)
      |> capture(observation)
      |> complete(:capture)
    end

    def handle_cast({:tick, now}, state) do
      state
      |> advance(now)
      |> complete(:tick)
    end

    def handle_cast(:gap, state) do
      # Restart the matching window at the first observation after the gap.
      state
      |> forget(:gap)
      |> complete(:gap)
    end

    @doc false
    def handle_info(_message, state), do: {:noreply, state}

    @doc false
    def format_status(status) do
      status
      |> Map.replace(:state, :redacted)
      |> Map.replace(:message, :redacted)
      |> Map.replace(:log, [])
    end

    defp complete(state, kind) do
      send(state.hub, {:sc_audit_complete, self(), kind, state.failures, state.losses})
      {:noreply, %{state | failures: 0, losses: 0}}
    end

    defp capture(state, %{frame: frame} = observation) do
      {npci, apdu} = decode_npdu(frame)

      observation =
        observation
        |> Map.delete(:frame)
        |> Map.put(:npci, npci)

      state =
        if state.config.mode == :traffic,
          do: emit(state, event(observation, :frame, frame)),
          else: state

      observe_apdu(state, observation, apdu)
    end

    defp decode_npdu(%BVLC{function: :npdu, payload: payload}) do
      case Protocol.decode_npci(payload) do
        {:ok, {%{is_network_message: false} = npci, apdu}} -> {npci, apdu}
        {:ok, {npci, _nsdu}} -> {npci, nil}
        {:error, _reason} -> {nil, nil}
      end
    end

    defp decode_npdu(_frame), do: {nil, nil}

    defp observe_apdu(
           state,
           observation,
           <<@confirmed::4, 0::1, _flags::3, _limits, invoke, service, tags::binary>> = apdu
         ) do
      request(state, observation, invoke, service, tags, apdu)
    end

    defp observe_apdu(
           state,
           observation,
           <<@confirmed::4, 1::1, _flags::3, _limits, invoke, _sequence, _window, service,
             _tags::binary>> = apdu
         )
         when service in @write_services do
      case safe_decode(fn -> APDU.decode(apdu) end) do
        {:incomplete, segment} -> segment(state, observation, service, segment)
        _invalid -> diagnostic(state, observation, invoke, service, :invalid_segment)
      end
    end

    defp observe_apdu(
           state,
           observation,
           <<@confirmed::4, 1::1, _flags::3, _limits, invoke, _sequence, _window, service,
             _tags::binary>>
         ) do
      request(state, observation, invoke, service, <<>>, nil)
    end

    # A final ComplexACK can release an invoke ID held by a non-write request.
    # Property writes use SimpleACK instead.
    defp observe_apdu(
           state,
           observation,
           <<@complex_ack::4, 0::4, invoke, service, _tags::binary>>
         ) do
      finish_other_request(state, observation, invoke, service)
    end

    defp observe_apdu(
           state,
           observation,
           <<@complex_ack::4, 8::4, invoke, _sequence, _window, service, _tags::binary>>
         ) do
      finish_other_request(state, observation, invoke, service)
    end

    defp observe_apdu(state, observation, <<type::4, _flags::4, invoke, _payload::binary>> = apdu)
         when type in @reply_types do
      key = reply_key(observation, invoke)

      if Map.has_key?(state.transactions, key) or Map.has_key?(state.assemblies, key) do
        case safe_decode(fn -> APDU.decode(apdu) end) do
          {:ok, reply} -> reply(state, observation, key, reply)
          _other -> state
        end
      else
        state
      end
    end

    defp observe_apdu(state, _observation, _apdu), do: state

    defp request(state, observation, invoke, service, tags, apdu) do
      key = request_key(observation, invoke)
      known_write? = service in @write_services
      signature = if known_write?, do: {service, :crypto.hash(:sha256, tags)}, else: service
      {state, previous} = transaction(state, key, signature, observation.monotonic_time)

      write_id =
        if previous && previous.event,
          do: previous.event.details.write_id,
          else: observation.capture_id

      {state, audit_event} =
        if known_write? do
          audit_event =
            case safe_decode(fn -> decode_write(apdu) end) do
              {:ok, writes} ->
                event(observation, :write_request, %{
                  write_id: write_id,
                  invoke_id: invoke,
                  service: service_name(service),
                  writes: writes,
                  retry: previous != nil
                })

              _invalid ->
                diagnostic = diagnostic_event(observation, invoke, service, :invalid_write)
                put_in(diagnostic.details.write_id, write_id)
            end

          {emit(state, audit_event), audit_event}
        else
          {state, nil}
        end

      anchor =
        if audit_event,
          do: %{audit_event | details: %{write_id: write_id}}

      store_request(state, key, signature, service, anchor, observation.monotonic_time)
    end

    defp transaction(state, nil, _signature, _now), do: {state, nil}

    defp transaction(state, key, signature, now) do
      case Map.get(state.transactions, key) do
        %{expires_at: expires_at} = entry when expires_at <= now ->
          state = expire_transaction(state, key, entry)
          {state, nil}

        %{signature: ^signature, event: %Event{}} = entry ->
          {state, entry}

        _other ->
          {state, nil}
      end
    end

    defp store_request(state, nil, _signature, _service, _event, _now), do: state

    defp store_request(%{paused_until: until} = state, _key, _signature, _service, event, now)
         when is_integer(until) and now < until do
      if event, do: %{state | losses: state.losses + 1}, else: state
    end

    defp store_request(state, key, signature, service, audit_event, now) do
      expires_at = now + @lifetime

      case Map.get(state.transactions, key) do
        nil when map_size(state.transactions) >= @max_transactions ->
          state = if audit_event, do: %{state | losses: state.losses + 1}, else: state
          forget(state, expires_at)

        nil ->
          put_in(state.transactions[key], %{
            signature: signature,
            service: service,
            event: audit_event,
            expires_at: expires_at
          })

        %{signature: ^signature} ->
          # Keep the first observation as the anchor while extending its reply window.
          put_in(state.transactions[key].expires_at, expires_at)

        %{signature: :ambiguous} = entry ->
          state = if audit_event, do: %{state | losses: state.losses + 1}, else: state
          put_in(state.transactions[key], %{entry | expires_at: expires_at})

        %{event: prior_event} ->
          losses = state.losses + Enum.count([prior_event, audit_event], &(&1 != nil))
          reserve_ambiguous(%{state | losses: losses}, key, expires_at)
      end
    end

    defp decode_write(apdu) do
      with {:ok, request} <- APDU.decode(apdu) do
        case request.service do
          :write_property ->
            with {:ok, write} <- WriteProperty.from_apdu(request) do
              {:ok, [property_write(write.object_identifier, write)]}
            end

          :write_property_multiple ->
            with {:ok, %{list: specifications}} <- WritePropertyMultiple.from_apdu(request) do
              writes =
                for specification <- specifications,
                    property <- specification.properties do
                  property_write(specification.object_identifier, property)
                end

              {:ok, writes}
            end
        end
      end
    end

    defp property_write(object, %{property_value: value} = property) when not is_nil(value) do
      %{
        object_identifier: object,
        property_identifier: property.property_identifier,
        property_array_index: property.property_array_index,
        property_value: value,
        priority: property.priority
      }
    end

    defp segment(state, observation, service, segment) do
      key = request_key(observation, segment.invoke_id)

      if key do
        assembly = Map.get(state.assemblies, key)
        receive_segment(state, observation, service, segment, key, assembly)
      else
        if segment.sequence_number == 0 do
          diagnostic(state, observation, segment.invoke_id, service, :unroutable_segmented_write)
        else
          state
        end
      end
    end

    defp receive_segment(state, observation, service, %{sequence_number: 0} = segment, key, nil)
         when map_size(state.assemblies) < @max_assemblies do
      assembly = %{
        observation: observation,
        service: service,
        next: 0,
        bytes: 0,
        count: 0,
        chunks: [],
        recent: %{},
        expires_at: observation.monotonic_time + @lifetime
      }

      receive_segment(state, observation, service, segment, key, assembly)
    end

    defp receive_segment(
           state,
           observation,
           service,
           segment,
           key,
           %{service: service, next: next} = assembly
         )
         when segment.sequence_number == next and observation.monotonic_time < assembly.expires_at and
                assembly.bytes + byte_size(segment.data) <= @max_assembly_bytes and
                assembly.count < @max_segments do
      if segment.more_follows do
        # A decoded chunk can be a slice of a much larger BVLC frame.
        data = :binary.copy(segment.data)

        assembly = %{
          assembly
          | next: rem(next + 1, 256),
            bytes: assembly.bytes + byte_size(segment.data),
            count: assembly.count + 1,
            chunks: [data | assembly.chunks],
            recent: Map.put(assembly.recent, next, data),
            expires_at: observation.monotonic_time + @lifetime
        }

        put_in(state.assemblies[key], assembly)
      else
        tags =
          [segment.data | assembly.chunks]
          |> Enum.reverse()
          |> IO.iodata_to_binary()

        # Keep the first segment's timestamp and capture ID, and start the
        # reply window at the time the final segment reached the hub.
        first = %{assembly.observation | monotonic_time: observation.monotonic_time}
        state = %{state | assemblies: Map.delete(state.assemblies, key)}
        request(state, first, segment.invoke_id, service, tags, segment.header <> tags)
      end
    end

    defp receive_segment(state, observation, service, segment, key, assembly) do
      sequence = segment.sequence_number
      data = segment.data

      case assembly do
        %{service: ^service, recent: %{^sequence => ^data}, expires_at: expires_at}
        when segment.more_follows and observation.monotonic_time < expires_at ->
          put_in(state.assemblies[key].expires_at, observation.monotonic_time + @lifetime)

        _other ->
          state = %{state | assemblies: Map.delete(state.assemblies, key)}
          state = invalidate_match(state, key, observation.monotonic_time)
          diagnostic(state, observation, segment.invoke_id, service, :incomplete_segment_sequence)
      end
    end

    defp finish_other_request(state, observation, invoke, service) do
      key = reply_key(observation, invoke)

      case state.transactions do
        %{^key => %{service: ^service, event: nil}} ->
          %{state | transactions: Map.delete(state.transactions, key)}

        _other ->
          state
      end
    end

    defp reply(state, observation, key, reply) do
      case state.assemblies do
        %{^key => assembly} -> reply_during_assembly(state, observation, key, assembly, reply)
        _other -> reply_to_request(state, observation, key, reply)
      end
    end

    defp reply_during_assembly(state, observation, key, assembly, reply) do
      if not is_struct(reply, APDU.SimpleACK) and terminal?(reply, service_name(assembly.service)) do
        request =
          diagnostic_event(
            assembly.observation,
            reply.invoke_id,
            assembly.service,
            :reply_before_reassembly
          )

        state = emit(%{state | assemblies: Map.delete(state.assemblies, key)}, request)

        case Map.get(state.transactions, key) do
          nil ->
            if is_integer(state.paused_until) and observation.monotonic_time < state.paused_until do
              %{state | losses: state.losses + 1}
            else
              emit(state, event(observation, :write_result, reply_details(request, reply)))
            end

          entry ->
            # A reply could refer to the in-progress write or to the prior
            # request with the same endpoints and invoke ID.
            losses = state.losses + if(entry.event, do: 2, else: 1)

            reserve_ambiguous(
              %{state | losses: losses},
              key,
              observation.monotonic_time + @lifetime
            )
        end
      else
        state
      end
    end

    defp reply_to_request(state, observation, key, reply) do
      case Map.get(state.transactions, key) do
        %{expires_at: expires_at} = entry when expires_at <= observation.monotonic_time ->
          expire_transaction(state, key, entry)

        %{service: service, event: request} when not is_nil(service) ->
          if terminal?(reply, service_name(service)) do
            state = %{state | transactions: Map.delete(state.transactions, key)}

            if request,
              do: emit(state, event(observation, :write_result, reply_details(request, reply))),
              else: state
          else
            state
          end

        _other ->
          state
      end
    end

    defp terminal?(%APDU.Abort{sent_by_server: server?}, _service), do: server?
    defp terminal?(%APDU.Reject{}, _service), do: true

    defp terminal?(%{service: service}, service), do: true
    defp terminal?(_reply, _service), do: false

    defp reply_details(request, reply) do
      details = %{write_id: write_id(request), outcome: outcome(reply), reply: reply}

      case safe_decode(fn -> WritePropertyMultipleError.from_apdu(reply) end) do
        {:ok, error} ->
          Map.put(details, :first_failed_write_attempt, error.first_failed_write_attempt)

        _other ->
          details
      end
    end

    defp reserve_ambiguous(state, key, expires_at) do
      entry = %{signature: :ambiguous, service: nil, event: nil, expires_at: expires_at}
      put_in(state.transactions[key], entry)
    end

    defp invalidate_match(state, key, now) do
      case state.transactions do
        %{^key => %{event: event}} ->
          losses = state.losses + if(event, do: 1, else: 0)
          reserve_ambiguous(%{state | losses: losses}, key, now + @lifetime)

        _other ->
          state
      end
    end

    defp outcome(%APDU.SimpleACK{}), do: :acknowledged
    defp outcome(%APDU.Error{}), do: :error
    defp outcome(%APDU.Reject{}), do: :rejected
    defp outcome(%APDU.Abort{}), do: :aborted

    defp request_key(%{egress_session: egress, routing: {:queued, 1}} = observation, invoke)
         when not is_nil(egress) do
      {observation.ingress_session, observation.npci.source, egress, observation.npci.destination,
       invoke}
    end

    defp request_key(_observation, _invoke), do: nil

    defp reply_key(observation, invoke) do
      case request_key(observation, invoke) do
        {ingress, source, egress, destination, ^invoke} ->
          {egress, destination, ingress, source, invoke}

        nil ->
          nil
      end
    end

    defp resume(%{paused_until: :gap} = state, now),
      do: %{state | paused_until: now + @lifetime}

    defp resume(state, _now), do: state

    defp advance(%{next_expiry: due} = state, now) when is_nil(due) or now >= due do
      state =
        Enum.reduce(state.transactions, state, fn
          {key, %{expires_at: expires_at} = entry}, acc when expires_at <= now ->
            expire_transaction(acc, key, entry)

          _entry, acc ->
            acc
        end)

      state =
        Enum.reduce(state.assemblies, state, fn
          {{_source_session, _source, _target_session, _target, invoke} = key,
           %{expires_at: expires_at} = assembly},
          acc
          when expires_at <= now ->
            acc = %{acc | assemblies: Map.delete(acc.assemblies, key)}
            diagnostic(acc, assembly.observation, invoke, assembly.service, :segment_timeout)

          _entry, acc ->
            acc
        end)

      %{state | next_expiry: now + 1000}
    end

    defp advance(state, _now), do: state

    defp expire_transaction(state, key, %{event: request}) do
      state = %{state | transactions: Map.delete(state.transactions, key)}

      if request do
        emit(state, %{
          request
          | timestamp: DateTime.utc_now(),
            kind: :write_result,
            details: %{write_id: write_id(request), outcome: :reply_not_observed}
        })
      else
        state
      end
    end

    defp forget(state, until) do
      lost = Enum.count(state.transactions, fn {_key, entry} -> entry.event != nil end)

      %{
        state
        | transactions: %{},
          assemblies: %{},
          paused_until: until,
          losses: state.losses + lost + map_size(state.assemblies)
      }
    end

    defp diagnostic(state, observation, invoke, service, reason),
      do: emit(state, diagnostic_event(observation, invoke, service, reason))

    defp diagnostic_event(observation, invoke, service, reason) do
      event(observation, :write_diagnostic, %{
        write_id: observation.capture_id,
        invoke_id: invoke,
        service: service_name(service),
        reason: reason
      })
    end

    defp event(observation, kind, details) do
      fields =
        Map.take(observation, [
          :timestamp,
          :hub,
          :capture_id,
          :ingress,
          :egress,
          :destination_vmac,
          :npci,
          :routing
        ])

      struct!(Event, Map.merge(fields, %{kind: kind, details: details}))
    end

    defp emit(state, event) do
      case safe_decode(fn -> state.config.sink.(event) end) do
        :ok -> state
        _failure -> %{state | failures: state.failures + 1}
      end
    end

    defp safe_decode(fun) do
      fun.()
    rescue
      _error -> {:error, :exception}
    catch
      _kind, _reason -> {:error, :exception}
    end

    defp service_name(service),
      do: Constants.by_value(:confirmed_service_choice, service, service)

    defp write_id(%Event{details: details}), do: details.write_id
  end
end
