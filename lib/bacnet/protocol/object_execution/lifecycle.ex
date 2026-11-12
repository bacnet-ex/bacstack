defmodule BACnet.Protocol.ObjectExecution.Lifecycle do
  @moduledoc """
  Stateless lifecycle operations for an
  [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host).
  Runs BACnet object behaviour one step at a time.

  Use this module to initialize objects, run their behaviour after a change, prepare property
  writes and refresh computed values before a read. Each operation runs in the caller's process. The
  host retains the result and decides when to call again based on the result and the object's
  documented triggers.

  The object module defines the behaviour, including which triggers and capabilities it supports.
  The default execution preserves the object and state. This module adds preflight and passive
  remote-snapshot handling around the callbacks described in `BACnet.Protocol.ObjectsBehaviour`.

  ## First execution

  Create a local Calendar and initialize it with a fixed UTC sample. This is enough to run
  the Calendar's date calculation in IEx. Other objects can require additional inputs, such
  as a property-read callback or an observation from a driver.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject
      iex> {:ok, object} = CalendarObject.create(1, "Holidays")
      iex> context = Context.new(:initialization, now: ~U[2026-12-24 12:00:00Z])
      iex> {:ok, stored} = Lifecycle.execute(object, context)
      iex> CalendarObject.get_property(stored.object, :present_value)
      {:ok, false}
      iex> stored.next_execution.wall_time
      ~U[2026-12-25 00:00:00Z]

  Use `stored.object` for subsequent operations and pass `stored.state` as the next context's
  `state:` option. The Calendar has an empty date list, so its Present_Value is false. Its
  next request is to run at midnight. See [wakeup examples](#module-wakeups-continuations-and-restarts)
  to turn that request into a timer, or follow the
  [complete Calendar example](#module-complete-example-a-calendar-through-the-lifecycle)
  for writes, reads and clock changes.

  ## Object execution host

  In the object execution documentation, **host** means the integrating application code or
  higher-level BACnet stack responsible for owning object instances and driving their lifecycle.
  It connects the object modules' calculations and execution requests to application storage,
  clocks, scheduling and any required I/O. A program managing a single local Calendar can fill this
  role, as can a BACnet device server managing many interacting objects.

  A host can use a GenServer, an application loop or cooperating storage, scheduling and I/O
  components. Keep one current result per instance and process operations on that instance in order. A single process can manage multiple objects.

  BACstack supplies object representations and property operations, the callbacks in
  `BACnet.Protocol.ObjectsBehaviour`, dispatch through `BACnet.Protocol.ObjectsProtocol`, and the
  operations in this module. The integrating application supplies the context, object storage and
  timers. Host callbacks in `BACnet.Protocol.ObjectExecution.Context` provide access to other
  objects and properties. Use `BACnet.Protocol.ObjectExecution.Context.new/2` to sample clocks
  for a context or supply samples from the application's own clock source.

  The host's shared responsibilities are:

  | Responsibility | What the integrating host needs to provide |
  | --- | --- |
  | Object ownership | Retain the current object, opaque runtime state and replacement request from `BACnet.Protocol.ObjectExecution.Result` together, separately for each instance. |
  | Operation ordering | Serialize each instance's preparation, commit, execution and computed reads. Commit intermediate results and finish immediate continuations before the next external operation. |
  | Execution inputs | Supply fresh device-local wall time, a supporting timezone database, VM-monotonic milliseconds, the trigger and the previous runtime state through `BACnet.Protocol.ObjectExecution.Context`. |
  | Lifecycle delivery | Initialize before serving live values, execute committed writes including same-value writes, refresh computed reads, and deliver clock changes, dependency changes and requested execution steps as required by the object. |
  | Scheduling | Interpret every replacement request, cancel superseded timers, ignore stale deliveries, recheck due deadlines and run immediate continuations. The wakeup examples below show timer arming and delivery. |
  | Property access | Resolve object and property identifiers, enforce access, array-index and priority rules, build validated candidates through property operations, and obtain computed values through the documented read path. |
  | Physical I/O isolation | Apply object-specific out-of-service decoupling. For physical inputs/outputs, stop forwarding automatic hardware Reliability reports while out of service. Inputs also need automatic Present_Value updates isolated from simulation. Explicit local and BACnet Reliability writes can simulate conditions. |
  | Cross-object operations | Supply the lookup/read/write callbacks required by the selected object configuration. Resolve local/remote references, retain target updates, bound transport waits, detect cyclic reads and avoid synchronous calls into an already blocked owner. |
  | Dependencies | Track relevant dependencies and notify affected objects when configuration or values change. Nested reads within one operation need the same supplied time. |
  | Failures and recovery | Retain results according to the commit phase, preserve accepted writes and completed I/O after later errors, and choose a recovery policy without assuming retries are safe. |
  | Restart | Reinitialize with current clocks and fresh runtime state after a VM restart. VM-monotonic timestamps are valid only in the VM that sampled them. |

  These requirements apply to the operations and capabilities being used. Optional I/O callbacks
  may be `nil` when the object does not require them. For example, Calendar needs time and
  scheduling but no lookup/read/write callbacks. If an application exposes BACnet services, it also
  needs to handle transport, service-error mapping and subscriptions, including applicable COV
  delivery. Those service responsibilities belong to that application's integration layer.

  The [complete Calendar example](#module-complete-example-a-calendar-through-the-lifecycle)
  also links to a runnable GenServer example. The GenServer retains the result, serializes
  requests and manages the timer. `BACnet.Protocol.ObjectTypes.Calendar` evaluates the date
  list and returns the next midnight request.

  ## Intrinsic transitions

  Use `intrinsic_reporting: true` at creation to select the intrinsic reporting documented by
  the object module. The object module describes its monitored properties and algorithms.
  `BACnet.Protocol.ObjectExecution.IntrinsicReporting` describes algorithm selection, retained
  reporting state and how event deadlines use the monotonic clock and contribute to wakeups.

  Supply a `lookup_object` callback when the host can resolve the object's
  Notification Class. The execution result includes the new event state, event
  timestamp, acknowledgment bits and any transition recorded during that step.

  Check every result with `BACnet.Protocol.ObjectExecution.EventReporting.transition/1`
  after committing it, including results of immediate continuations. In this
  example, `commit` and `deliver` are the host's storage and notification callbacks.

  ```elixir
  with {:ok, result} <- BACnet.Protocol.ObjectExecution.Lifecycle.execute(object, context),
       :ok <- commit.(result) do
    case BACnet.Protocol.ObjectExecution.EventReporting.transition(result) do
      %{enabled: true, routing: routing} = transition when not is_nil(routing) ->
        deliver.(result.object, transition)

      _other ->
        :ok
    end
  end
  ```

  For Event Log, Trend Log and Trend Log Multiple, the logger's
  `event: :intrinsic_reporting` message requests execution. Use the log
  identifier from the message to look up the current object and retained
  state. Call `execute/2` with a `:periodic` context that includes
  `[trend_logger: logger]`. The execution checks the logger's current
  threshold and reporting eligibility. Commit and inspect that result
  using the delivery pattern above.

  Event_Enable controls notification delivery. The result still records the transition when delivery is disabled.
  For AcknowledgeAlarm, the host validates the requested event state and uses
  `BACnet.Protocol.ObjectExecution.EventReporting.acknowledge/3` to match the
  transition timestamp and update its acknowledgment bit. Commit the returned
  object before delivering the acknowledgment notification.

  ## Host responsibilities and retained state

  Retain the complete `BACnet.Protocol.ObjectExecution.Result` for each instance:

  - `object` is the current BACnet object, including computed property updates.
  - `state` is opaque runtime state owned by the object module. Pass it back in
    the next context for that same instance - property writes do not clear it.
  - `next_execution` is the replacement request for subsequent execution. It is
    part of the retained result even when it is `nil`.

  Start with `state: nil` and `trigger: :initialization`, then atomically retain each successful
  result before processing the next operation. Changing an object through its property API does not
  automatically invoke lifecycle execution. The host needs to deliver the triggers required by the
  object and service the returned requests. Periodic calls alone do not cover writes, computed reads
  or dependency changes that need to take effect immediately.

  Build a context for each operation with `BACnet.Protocol.ObjectExecution.Context.new/2`.
  Pass the trigger, prior runtime state and any required host callbacks. By default it samples
  `now` in `config :bacstack, :default_timezone` (or `"Etc/UTC"` when unconfigured), uses the
  configured timezone database and samples monotonic milliseconds. You can supply explicit
  values for any of these fields. Direct struct construction requires every field.

  Monotonic values may be negative. Sample fresh clocks for each new operation and keep the
  same supplied time for preparation, execution and nested reads within one operation.
  Each continuation is a new execution step and needs fresh clock samples after the preceding
  step and its callbacks return. `BACnet.Protocol.ObjectTypes.Command` uses that later monotonic
  sample to establish its post-delay deadline. See `BACnet.Protocol.ObjectExecution.Context`
  for callback contracts.

  Set `device_identifier` to the containing Device's identity when needed to resolve explicit
  self-device references. See
  `BACnet.Protocol.ObjectTypes.Schedule` for target reference routing.

  ## Entry points and triggers

  | Operation | Entry point and trigger | Host action after success |
  | --- | --- | --- |
  | Start or restart an instance | `execute/2`, `:initialization` | Retain the result before serving it. |
  | Proposed property write | `prepare_write/3`, `{:property_write, property, index, priority}` | Commit the returned candidate, then execute the committed write with the same context. |
  | Computed property read | `prepare_read/2`, `{:property_read, property, index}` | Retain the result and finish continuations before calling the getter. |
  | Requested deadline reached | `execute/2`, `:timer` | Retain the result and replace the previous request. |
  | Wall-clock correction or timezone change | `execute/2`, `:clock_change` | Retain the result and reconcile wall-clock timers. |
  | Referenced object changed | `execute/2`, `{:object_changed, reference}` | Retain the result and propagate relevant changes to dependants. |
  | Immediate continuation | `execute/2`, `:continuation` | Retain each result and continue until no immediate step remains. |
  | Application polling | `execute/2`, `:periodic` | Retain the result and honor its next request. |

  Local application writes can use `{:application_write, property, array_index, priority}`
  with the same preparation and commit order. The object module defines support for this
  origin - `BACnet.Protocol.ObjectTypes.BinaryValue`, `BACnet.Protocol.ObjectTypes.AnalogValue`
  and `BACnet.Protocol.ObjectTypes.MultistateValue`
  use it to enforce out-of-service
  isolation of local application updates. Host callbacks handling BACnet commands need to
  retain the BACnet origin even when the operation is performed locally. See the
  [complete application-write example](BACnet.Protocol.ObjectTypes.BinaryValue.html#module-complete-write-example).
  `BACnet.Protocol.ObjectTypes.BinaryOutput` uses the application origin for physical
  feedback isolation while allowing logical commands during out-of-service
  simulation. Its module documentation and runnable example describe the adapter boundary.
  `BACnet.Protocol.ObjectTypes.AnalogOutput` accepts logical commands from both origins
  while the host decouples the physical output. Explicit out-of-service Reliability
  simulation is accepted from either origin. The host needs to stop forwarding automatic
  hardware Reliability reports while decoupled - origin alone does not identify intent.
  `BACnet.Protocol.ObjectTypes.BinaryInput` uses application writes for physical samples
  and physical reliability reports, while BACnet Present_Value writes require out of
  service. Its module documentation includes a complete physical-sample example.
  `BACnet.Protocol.ObjectTypes.AnalogInput` accepts in-service engineering readings and
  out-of-service simulation from either origin. Physical observations through
  `BACnet.Protocol.ObjectTypes.AnalogInput.set_input/2` can maintain Interface_Value
  independently of simulation. Its host owns acquisition, report isolation and delivery
  of a current reading when service resumes.

  Property indices and priorities are `nil` when omitted. The write trigger identifies the
  proposed change during preparation. During execution the object already contains the committed
  change, and the trigger identifies which write led to this execution.

  ## Writes

  Resolve the property and any array index or priority. For a BACnet service write, check
  client write access and decode the BACnet value before building the candidate. The object's
  internal setters can also serve application operations with different access rules.

  1. Build a candidate through the object's property functions. For an ordinary property use
     the module's `update_property/3`. For a priority command or relinquishment use its
     `set_priority/3`, where supported.
  2. Call `prepare_write/3` with the original object, candidate and write context. Preparation can
     apply further validated changes and runs preflight on the final candidate. A rejection leaves
     the retained result intact.
  3. Commit the returned object with the previous state and wakeup. Call `execute/2` with that
     committed object and the same context, including for same-value writes. Retain every
     successful execution result and handle its next request before accepting another operation.

  If execution fails after commit, retain the accepted object and the previous state and wakeup.
  Any I/O already performed remains effective. See the
  [complete Calendar example](#module-complete-example-a-calendar-through-the-lifecycle) for
  an ordinary property write and the
  [Binary Value write example](BACnet.Protocol.ObjectTypes.BinaryValue.html#module-complete-write-example)
  for writes with different origins.

  ## Reads and dependencies

  For a property that the object documents as computed on read, use `prepare_read/2` with
  a `{:property_read, property, array_index}` trigger and the operation's clock samples.
  Commit its result, finish any immediate continuations, then use the object's getter.
  Use the same sequence when serving a computed property through
  `BACnet.Protocol.ObjectExecution.Context.read_property/2`. A lookup returns the stored
  snapshot. A dependent object that needs the current computed value needs a property read
  or a shared pure calculation.

  For example, `BACnet.Protocol.ObjectTypes.Device` calculates its clock properties from
  the supplied time during read preparation. Its `:on_read_function` annotations for
  Local_Date and Local_Time are an alternative for applications reading without lifecycle
  execution. Choose the lifecycle path when several values need to reflect one clock sample.

  The host needs to serialize operations for each object, track dependencies and deliver
  `{:object_changed, reference}` when a dependency changes. For example, a local Calendar edit must
  invalidate affected Schedules even if their own properties have not changed. All nested reads in
  one operation must use the same supplied time. Detect cyclic reads rather than recursively
  executing an object already active.

  Host callbacks run synchronously. Bound transport waits and avoid synchronous calls into a process
  that is already blocked executing this object. A host read callback must retain any refreshed
  target object, state and wakeup before returning its property value to the requesting object.

  ## Wakeups, continuations and restarts

  Each successful result replaces the previous request, including one returned by a read or a
  same-value write:

  | `next_execution` | Host responsibility |
  | --- | --- |
  | `nil` | Cancel the previous request - external lifecycle triggers still apply. |
  | `BACnet.Protocol.ObjectExecution.Wakeup` with `wall_time` | Arrange execution at or after this absolute wall-clock instant. |
  | `BACnet.Protocol.ObjectExecution.Wakeup` with `monotonic_time` | Arrange execution at or after this absolute VM-monotonic millisecond value. |
  | Both deadlines in `BACnet.Protocol.ObjectExecution.Wakeup` | Execute when the first deadline is reached. |
  | `:immediate` | Commit the result, then execute with `:continuation` before the next external operation. |

  `BACnet.Protocol.ObjectExecution.Wakeup.due?/2` checks the supplied clocks, including equality. On
  timer delivery, sample time again, ignore deliveries for superseded requests, and rearm an early
  request rather than treating it as due. Compute delays from absolute deadlines using current time
  after committing the result. Replace or cancel old timers whenever the request changes -
  cancellation can race with message delivery.

  An immediate continuation lets an object make a change visible before the next step uses it.
  For example, Command publishes its busy flag before it writes to a target. Commit every intermediate result and pass its state to the next step.
  Implementations must make progress and eventually finish or request a future wakeup. An error ends
  that attempt - it is not a successful continuation or an instruction to retry indefinitely.

  Report wall-clock corrections and timezone changes with `:clock_change`, using the new
  device-local time and supporting database. Reconcile wall-clock timers then - elapsed-time
  deadlines remain in the monotonic clock domain. After a VM restart, initialize with fresh runtime
  state and current clocks. Previously stored monotonic timestamps cannot be reused across VMs.
  Durable recovery of object-specific runtime state requires an explicit contract from that object.

  ### Example: arming and replacing a timer

  The following helper is example application code. Call it in the process that will receive the
  timer message, after retaining a successful result. It cancels the previous timer, calculates a
  delay from each supplied deadline and arms the earlier one with `Process.send_after/3`. The
  returned timer reference and token need to be retained alongside the current request.

  ```elixir
  defmodule ExampleLifecycleDriver do
    alias BACnet.Protocol.ObjectExecution.Context
    alias BACnet.Protocol.ObjectExecution.Lifecycle
    alias BACnet.Protocol.ObjectExecution.Result
    alias BACnet.Protocol.ObjectExecution.Wakeup

    @type timer :: {timer_reference :: reference(), delivery_token :: reference()} | nil
    @type commit :: (Result.t() -> :ok)
    @type sample_context :: (Result.t() -> Context.t())

    @spec replace_timer(timer(), Wakeup.t() | nil, Context.t()) :: timer()
    def replace_timer(previous_timer, request, context)

    def replace_timer(previous_timer, nil, %Context{}) do
      cancel_timer(previous_timer)
      nil
    end

    def replace_timer(previous_timer, %Wakeup{} = request, %Context{} = context) do
      cancel_timer(previous_timer)

      wall_delay =
        if request.wall_time do
          microseconds = max(DateTime.diff(request.wall_time, context.now, :microsecond), 0)
          div(microseconds + 999, 1000)
        end

      monotonic_delay =
        if request.monotonic_time do
          max(request.monotonic_time - context.monotonic_time, 0)
        end

      case Enum.reject([wall_delay, monotonic_delay], &is_nil/1) do
        [] ->
          nil

        delays ->
          token = make_ref()
          # Recheck long deadlines at least once per minute in this example.
          delay = min(Enum.min(delays), 60_000)
          timer = Process.send_after(self(), {:object_wakeup, token}, delay)
          {timer, token}
      end
    end

    @spec retain_and_continue(Result.t(), sample_context(), commit()) ::
            {:ok, Result.t()} | {:error, term(), Result.t()}
    def retain_and_continue(result, sample_context, commit) do
      :ok = commit.(result)

      case result.next_execution do
        :immediate ->
          next_context = %{sample_context.(result) | state: result.state, trigger: :continuation}

          case Lifecycle.execute(result.object, next_context) do
            {:ok, next} -> retain_and_continue(next, sample_context, commit)
            {:error, reason} -> {:error, reason, result}
          end

        _request ->
          {:ok, result}
      end
    end

    @spec cancel_timer(timer()) :: :ok
    defp cancel_timer(timer)

    defp cancel_timer(nil), do: :ok

    defp cancel_timer({reference, _token}) do
      Process.cancel_timer(reference)
      :ok
    end
  end
  ```

  The example caps each wait at one minute. If a timer arrives before its deadline, check
  the remaining delay and rearm it. Wall delays are rounded up to milliseconds. Due or past deadlines
  receive a zero delay. An empty `BACnet.Protocol.ObjectExecution.Wakeup` has no deadline and
  produces no timer.

  ### Examples: every wakeup option

  After defining the helper above, run this block in the same process. These constructed requests
  demonstrate the timing contract independently of an object's algorithm. Each replacement cancels
  the timer from the previous line.

  ```elixir
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Wakeup

  context = Context.new(:initialization, now: DateTime.utc_now())

  # A wall deadline five seconds after the sampled wall time.
  wall = %Wakeup{wall_time: DateTime.add(context.now, 5, :second), monotonic_time: nil}
  timer = ExampleLifecycleDriver.replace_timer(nil, wall, context)

  # An absolute monotonic deadline three seconds after the sampled monotonic time.
  monotonic = %Wakeup{wall_time: nil, monotonic_time: context.monotonic_time + 3000}
  timer = ExampleLifecycleDriver.replace_timer(timer, monotonic, context)

  # Both deadlines: the earlier one wins (the monotonic deadline in this example).
  both = %Wakeup{wall_time: wall.wall_time, monotonic_time: monotonic.monotonic_time}
  timer = ExampleLifecycleDriver.replace_timer(timer, both, context)

  # No replacement request: cancel the preceding timer and retain nil.
  nil = ExampleLifecycleDriver.replace_timer(timer, nil, context)

  # An empty wakeup likewise schedules nothing.
  nil = ExampleLifecycleDriver.replace_timer(nil, %Wakeup{wall_time: nil, monotonic_time: nil}, context)
  ```

  In an application, sample current clocks again after committing the result and use those samples
  when arming its request. The fixed samples above keep the delay calculations easy to inspect.

  ### Example: timer delivery and early or stale messages

  This continues after the helper and context blocks above. A supplied UTC clock starts twenty
  milliseconds before midnight and advances with the real monotonic clock. This lets the example
  service Calendar's actual wall-clock request without waiting for a real midnight. The local
  bindings represent retained state for this one example. After a successful step, a host needs to
  retain the result and service its new request - the example ends by cancelling that new timer.

  ```elixir
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject

  {:ok, calendar} = CalendarObject.create(500, "Timer example")
  initial = %{context | now: ~U[2026-12-24 23:59:59.980Z],
    monotonic_time: System.monotonic_time(:millisecond), state: nil, trigger: :initialization}
  sample = fn ->
    monotonic = System.monotonic_time(:millisecond)
    %{initial | now: DateTime.add(initial.now, monotonic - initial.monotonic_time, :millisecond),
      monotonic_time: monotonic}
  end
  {:ok, stored} = Lifecycle.execute(calendar, initial)
  request = stored.next_execution
  timer = ExampleLifecycleDriver.replace_timer(nil, request, sample.())

  await = fn recur, current_timer ->
    receive do
      {:object_wakeup, received_token} ->
        case current_timer do
          {_reference, ^received_token} ->
            fresh = %{sample.() | state: stored.state, trigger: :timer}

            if Wakeup.due?(request, fresh) do
              case Lifecycle.execute(stored.object, fresh) do
                {:ok, result} ->
                  # Retain first, then re-sample after calculation time.
                  stored = result
                  schedule_context = sample.()
                  next_timer = ExampleLifecycleDriver.replace_timer(
                    current_timer, stored.next_execution, schedule_context)
                  ExampleLifecycleDriver.replace_timer(next_timer, nil, schedule_context)
                  {:ok, stored}

                {:error, reason} ->
                  # Preserve stored and request - let the caller choose recovery.
                  {:error, reason, stored, request}
              end
            else
              rearmed = ExampleLifecycleDriver.replace_timer(current_timer, request, fresh)
              recur.(recur, rearmed)
            end

          _stale ->
            # Leave the current result and timer unchanged.
            recur.(recur, current_timer)
        end
    end
  end

  {:ok, _updated} = await.(await, timer)
  ```

  The token check must precede execution. Cancelling a timer with `Process.cancel_timer/1` does not
  remove a message that has already arrived in the mailbox. The loop above ignores stale deliveries
  and rearms early ones until a due request executes. It stops after that one execution.

  ### Example: immediate continuations and visible commits

  An immediate continuation needs a synchronous commit followed by another execution step, rather
  than a process timer. The helper's continuation function above commits every intermediate result
  before dispatching `execute/2` with `:continuation`. It obtains fresh clock inputs from
  a caller-supplied context factory after each commit and fills in the continuation trigger and
  retained state. On failure it returns the last committed result, including its pending request. The object module
  decides whether to return `:immediate` - Calendar does not.

  This block, following the helper and context blocks, defines a small custom object that returns
  one intermediate result and then finishes its update. An Agent serves as the example's storage.
  Target I/O callbacks would need to read this committed storage directly, without calling an
  executing owner that is synchronously blocked.

  ```elixir
  defmodule ExampleStagedObject do
    use BACnet.Protocol.ObjectsMacro

    alias BACnet.Protocol.ObjectExecution.Context
    alias BACnet.Protocol.ObjectExecution.Result

    @type object_opts :: common_object_opts()

    bac_object :binary_value do
      services(intrinsic: false)
      field(:present_value, boolean(), required: true, default: false)
    end

    @impl BACnet.Protocol.ObjectsBehaviour
    @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
    def execute(object, context) do
      case context.state do
        nil ->
          {:ok, %Result{object: object, state: :pending, next_execution: :immediate}}

        :pending ->
          with {:ok, updated} <- update_property(object, :present_value, true) do
            {:ok, %Result{object: updated, state: :finished, next_execution: nil}}
          end

        :finished ->
          {:ok, %Result{object: object, state: :finished, next_execution: nil}}
      end
    end
  end

  alias BACnet.Protocol.ObjectExecution.Lifecycle

  {:ok, object} = ExampleStagedObject.create(501, "Continuation example")
  {:ok, storage} = Agent.start_link(fn -> nil end)
  commit = fn result -> Agent.update(storage, fn _previous -> result end) end

  sample_context = fn _stored ->
    %{context | now: DateTime.now!(context.now.time_zone, context.timezone_database),
      monotonic_time: System.monotonic_time(:millisecond)}
  end

  try do
    {:ok, first} = Lifecycle.execute(object, context)
    :immediate = first.next_execution

    case ExampleLifecycleDriver.retain_and_continue(first, sample_context, commit) do
      {:ok, settled} ->
        true = settled.object.present_value
        :finished = settled.state
        ^settled = Agent.get(storage, & &1)
        fresh = %{context | now: DateTime.utc_now(),
          monotonic_time: System.monotonic_time(:millisecond)}
        timer = ExampleLifecycleDriver.replace_timer(nil, settled.next_execution, fresh)
        ExampleLifecycleDriver.replace_timer(timer, nil, fresh)

      {:error, reason, last_committed} ->
        {:error, reason, last_committed}
    end
  after
    Agent.stop(storage)
  end
  ```

  ## Execution and failure

  Local execution first calls the object's
  `c:BACnet.Protocol.ObjectsBehaviour.validate_execution/2`. This pure callback rejects unsupported
  selected capabilities, invalid configuration or missing host operations before side effects. A
  successful preflight is not a promise that later I/O will succeed.
  `BACnet.Protocol.ObjectExecution.Context.require_operations/2` checks required callbacks - object
  modules define the capabilities and configuration they support.

  Operation failures requiring retained state (including per-target outcomes) must be returned in a
  successful `BACnet.Protocol.ObjectExecution.Result`, with appropriate object properties. Partial
  I/O has no rollback - do not blindly retry an error. Callback exceptions and malformed results are
  programming errors. Library/integration errors remain distinct from BACnet service errors - the
  host needs to map them at its service boundary.

  Remote snapshots execute passively without invoking any object or host callback - preparing a write
  to a remote snapshot is rejected. A local object referencing remote targets is subject to its own
  capability checks instead.

  A successful remote-snapshot execution requests no further execution. The host needs to cancel any
  previous wakeup when retaining that result.

  | Outcome | Retained state |
  | --- | --- |
  | Write preparation rejected | Original object, runtime state and wakeup. |
  | Successful execution | Returned object, runtime state and replacement wakeup. |
  | Execution error without a new write commit | Previous object, runtime state and wakeup - earlier host I/O remains effective. |
  | Execution error after write commit | Accepted candidate, previous runtime state and wakeup - earlier host I/O remains effective. |

  Common errors include `:object_identity_mismatch`, `:operation_not_available_for_remote_objects`,
  `{:unsupported_operation, operation}` and `{:unsupported_capability, capability}`. Configuration
  and operation errors are documented by the object module. All are returned as `{:error, reason}`.
  Decide recovery and service-error mapping at the host boundary, preserving the distinction between
  a rejected write and an execution failure after acceptance.

  ## Complete example: a Calendar through the lifecycle

  This example can be pasted into IEx with BACstack loaded. It supplies explicit UTC clock samples
  to demonstrate initialization, a write, a due midnight timer, a fresh read and a backward clock
  correction. `stored` is the host's retained result - rebinding it represents committing the result
  for this one instance. The pattern matches follow the successful path. An application must also
  handle errors using the retention rules above and arrange actual timers.

      iex> alias BACnet.Protocol.BACnetDate
      iex> alias BACnet.Protocol.CalendarEntry
      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle, Result, Wakeup}
      iex> alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject
      iex> {:ok, object} = CalendarObject.create(500, "Special days")
      iex> context = Context.new(:initialization,
      ...>   now: ~U[2026-12-24 12:00:00Z], monotonic_time: 0)
      iex> {:ok, %Result{} = stored} = Lifecycle.execute(object, context)
      iex> stored.object.present_value
      false
      iex> special_day = %CalendarEntry{
      ...>   type: :date,
      ...>   date: BACnetDate.from_date(~D[2026-12-24]),
      ...>   date_range: nil,
      ...>   week_n_day: nil
      ...> }
      iex> write_context = %{context | state: stored.state,
      ...>   trigger: {:property_write, :date_list, nil, nil}}
      iex> true = CalendarObject.property_writable?(stored.object, :date_list)
      iex> {:ok, candidate} = CalendarObject.update_property(stored.object, :date_list, [special_day])
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write_context)
      iex> stored = %{stored | object: prepared}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, write_context)
      iex> stored.object.present_value
      true
      iex> stored.next_execution.wall_time
      ~U[2026-12-25 00:00:00Z]
      iex> timer_context = %{context | now: ~U[2026-12-25 00:00:00Z],
      ...>   monotonic_time: 43_200_000, state: stored.state, trigger: :timer}
      iex> Wakeup.due?(stored.next_execution, timer_context)
      true
      iex> {:ok, stored} = Lifecycle.execute(stored.object, timer_context)
      iex> stored.object.present_value
      false
      iex> read_context = %{context | now: ~U[2026-12-26 12:00:00Z],
      ...>   monotonic_time: 172_800_000, state: stored.state,
      ...>   trigger: {:property_read, :present_value, nil}}
      iex> {:ok, stored} = Lifecycle.prepare_read(stored.object, read_context)
      iex> CalendarObject.get_property(stored.object, :present_value)
      {:ok, false}
      iex> changed_context = %{context | now: ~U[2026-12-24 12:00:00Z],
      ...>   monotonic_time: 172_800_001, state: stored.state, trigger: :clock_change}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, changed_context)
      iex> {stored.object.present_value, stored.next_execution.wall_time}
      {true, ~U[2026-12-25 00:00:00Z]}
      iex> repeat_context = %{changed_context | state: stored.state,
      ...>   trigger: {:property_write, :date_list, nil, nil}}
      iex> {:ok, candidate} = CalendarObject.update_property(stored.object, :date_list, [special_day])
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, repeat_context)
      iex> stored = %{stored | object: prepared}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, repeat_context)
      iex> stored.object.present_value
      true
      iex> rejected_context = %{repeat_context | trigger: {:property_write, :present_value, nil, nil}}
      iex> {:ok, candidate} = CalendarObject.update_property(stored.object, :present_value, false)
      iex> Lifecycle.prepare_write(stored.object, candidate, rejected_context)
      {:error, {:write_access_denied, :present_value}}
      iex> stored.object.present_value
      true
      iex> polling_context = %{changed_context | state: stored.state, trigger: :periodic}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, polling_context)
      iex> Context.require_operations(polling_context, [:read_property])
      {:error, {:unsupported_operation, :read_property}}
      iex> reference = %BACnet.Protocol.DeviceObjectRef{
      ...>   device_identifier: nil,
      ...>   object_identifier: %BACnet.Protocol.ObjectIdentifier{type: :calendar, instance: 501}}
      iex> dependency_context = %{polling_context | state: stored.state,
      ...>   trigger: {:object_changed, reference}}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, dependency_context)
      iex> stored.object.present_value
      true

  The repeated write follows the same preparation/commit/execution phases. The rejected write leaves
  `stored` unchanged. The final calls illustrate periodic execution, missing-operation preflight and
  construction of a dependency-change trigger. Calendar recalculates its date predicate for that
  trigger without looking up the reference - an object that consumes dependencies needs its own
  documented callbacks and capability checks.

  A remote snapshot is passive. This separate example preserves even a supplied
  runtime-state marker and rejects local write preparation:

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject
      iex> {:ok, snapshot} = CalendarObject.create(502, "Remote Calendar",
      ...>   %{date_list: [], present_value: false}, remote_object: 42)
      iex> context = %Context{
      ...>   device_identifier: nil,
      ...>   now: ~U[2026-12-25 12:00:00Z],
      ...>   timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
      ...>   monotonic_time: 0,
      ...>   trigger: :initialization,
      ...>   state: :retained,
      ...>   lookup_object: nil,
      ...>   read_property_multiple: nil,
      ...>   read_property: nil,
      ...>   write_property: nil,
      ...>   options: []
      ...> }
      iex> {:ok, passive} = Lifecycle.execute(snapshot, context)
      iex> {passive.object == snapshot, passive.state, passive.next_execution}
      {true, :retained, nil}
      iex> write_context = %{context | trigger: {:property_write, :date_list, nil, nil}}
      iex> Lifecycle.prepare_write(snapshot, snapshot, write_context)
      {:error, :operation_not_available_for_remote_objects}

  Calendar returns wall-clock wakeups and preserves the supplied runtime state. Other object modules
  may use host callbacks, runtime state or continuations as described in their documentation. For a
  runnable example with an actual timer, serialized operations and error handling, use the
  example host in
  `examples/objects_lifecycle/calendar_lifecycle_host.exs` - run its walkthrough with `mix run
  examples/objects_lifecycle/calendar_lifecycle.exs` from the repository root.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.ObjectsProtocol

  @doc """
  Runs local preflight and one execution step, or preserves a remote snapshot.

  For local objects, calls `c:BACnet.Protocol.ObjectsBehaviour.validate_execution/2` before the
  module's `c:BACnet.Protocol.ObjectsBehaviour.execute/2` callback. A successful result must be
  retained before servicing its next request or accepting another operation. On error, no
  replacement result is supplied - preserve the previous state, accounting for any property write
  already committed.

  Supply the trigger and prior runtime state in the context. This function does not check timer
  deadlines, apply a proposed property write, drain continuations or schedule subsequent calls.
  Remote snapshots preserve the object and supplied state without invoking object or host callbacks
  and return no wakeup request.
  """
  @spec execute(struct(), Context.t()) :: {:ok, Result.t()} | {:error, term()}
  def execute(object, context)

  def execute(%_module{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote) do
    ObjectsProtocol.impl_for!(object)
    {:ok, %Result{object: object, state: context.state, next_execution: nil}}
  end

  def execute(%_module{} = object, %Context{} = context) do
    context = Context.normalize_write(context)

    with :ok <- ObjectsProtocol.validate_execution(object, context) do
      ObjectsProtocol.execute(object, context)
    end
  end

  @doc """
  Prepares a candidate for atomic commit, without executing its behaviour.

  Requires a property-write or application-write trigger. Candidates must retain their module,
  instance number and local/remote identity. The host needs to validate property requirements and constraints through
  the object's property operations before this call and enforce property access, array indices
  and the request's priority rules.
  A command or indexed write targeting slot 6 is denied. The proposed candidate
  must preserve slot 6 so that the binary minimum-time callback can maintain the hold.

  Calls the module's pure `c:BACnet.Protocol.ObjectsBehaviour.prepare_write/3` callback, checks the
  returned identity and runs execution preflight on that final candidate. It neither commits the
  candidate nor executes behaviour. On success, commit the returned object while retaining runtime
  state, then call `execute/2` with the same write
  context, including for same-value writes. On error, leave the original result and request
  unchanged. Preparing a write to a remote snapshot returns `{:error,
  :operation_not_available_for_remote_objects}`.
  """
  @spec prepare_write(struct(), struct(), Context.t()) :: {:ok, struct()} | {:error, term()}
  def prepare_write(
        object,
        candidate,
        %Context{trigger: {source, _property, _index, _priority}} = context
      )
      when source in [:property_write, :application_write] do
    context = Context.normalize_write(context)

    with :ok <- local_object(object),
         :ok <- same_identity(object, candidate),
         :ok <- ObjectOperations.check_priority_array_change(object, candidate),
         {:ok, prepared} <- ObjectsProtocol.prepare_write(object, candidate, context),
         :ok <- ObjectOperations.check_priority_write(candidate, context.trigger),
         :ok <- same_identity(object, prepared),
         :ok <- ObjectsProtocol.validate_execution(prepared, context) do
      {:ok, prepared}
    end
  end

  @doc """
  Runs the object's read step using a property-read trigger.

  Performs one `execute/2` step and returns its execution result. Retain it,
  finish any immediate continuations, then obtain the property through the object's getter.
  The object defines which values the read step refreshes. For
  example, `BACnet.Protocol.ObjectTypes.EventEnrollment` returns its last
  evaluated state and preserves its pending deadline. The same ordering
  applies to reads requested by another executing object. On error, keep the
  previous result and return the failure to the reader.
  """
  @spec prepare_read(struct(), Context.t()) :: {:ok, Result.t()} | {:error, term()}
  def prepare_read(object, %Context{trigger: {:property_read, _property, _index}} = context) do
    execute(object, context)
  end

  @spec local_object(struct()) :: :ok | {:error, :operation_not_available_for_remote_objects}
  defp local_object(object)

  defp local_object(%{_metadata: %{remote_object: nil}}), do: :ok

  defp local_object(%{_metadata: %{remote_object: _remote}}),
    do: {:error, :operation_not_available_for_remote_objects}

  @spec same_identity(struct(), term()) :: :ok | {:error, :object_identity_mismatch}
  defp same_identity(object, candidate)

  defp same_identity(
         %{
           __struct__: module,
           object_instance: instance,
           _metadata: %{remote_object: remote}
         },
         %{
           __struct__: module,
           object_instance: instance,
           _metadata: %{remote_object: remote}
         }
       ),
       do: :ok

  defp same_identity(_object, _candidate), do: {:error, :object_identity_mismatch}
end
