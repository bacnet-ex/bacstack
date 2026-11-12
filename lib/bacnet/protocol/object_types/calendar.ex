defmodule BACnet.Protocol.ObjectTypes.Calendar do
  @moduledoc """
  A Calendar lists dates, ranges or patterns that mark days such as holidays.
  Its Present_Value tells clients whether the device's current local date
  matches an entry. Several Schedule objects can reference the same Calendar
  to share one list of exceptions.

  The `present_value` is a Boolean that is true precisely when today's date matches at least one
  entry in the `date_list`. The list can contain both concrete dates and recurring patterns, giving
  a very flexible way to define "every third Wednesday in November", date ranges, etc.

  ### Object Description (ASHRAE 135)

  > The Calendar object type defines a standardized object used to describe > a list of calendar
  dates, which might be thought of as "holidays", "special events", > or simply as a list of dates.

  ### Behaviour and Operation

  Calendar objects define date-list predicates. The `date_list` property (containing concrete dates,
  DateRanges, WeekNDay patterns, etc.) is normally configured at creation time or by a configuration
  tool / operator and then left alone. The object's `execute/2`
  evaluates the list against the supplied local date to decide whether the calendar is "active".

  The `present_value` is `true` when the current local date matches any entry. The device must keep
  the system clock (and thus the evaluation) accurate. The calendar is not a control point but a
  reference used by Schedules and other objects.

  ### Developer Implementation Notes (geared to device server / application authors)

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that owns this Calendar and drives
  its lifecycle. The linked contract defines the shared host requirements - this module describes
  the Calendar-specific interactions.

  The generated code handles the object representation and property mechanics (validation, implicit relationships and
  readonly annotations). This module implements the date matching and live-value calculation. A
  device server / application supplies local time and needs to invoke the lifecycle callbacks at the
  required moments - it does not need to implement a separate calendar evaluator.

  **Special / live properties and expected developer behaviour**

  - `present_value`: "Is today a special day per this calendar?"
    (yes/no for use by Schedules etc.). This is computed live and read-only to BACnet clients.
    `execute/2` evaluates every CalendarEntry against the
    supplied device-local date, including wildcards, ranges and WeekNDay. The host needs to refresh
    it at day changes, clock/timezone changes and before serving computed reads. Internal updates
    still use `update_property/3` - a property update alone does
    not invoke behaviour.

  - `date_list`: The definition of special days.
    Populate it at creation/configuration time (by workstation, client, or your setup). Clients can
    rewrite it at runtime. The host needs to validate and commit a write through the lifecycle, then
    execute the Calendar so that its value reflects the new list on the same day. Notify dependent
    objects after edits.

  A Calendar is a *shared date predicate*. Any number of Schedules (and potentially your own custom
  logic) can ask "is today one of the special days defined by this calendar?" by simply reading its
  `present_value`.

  **Wildcards and patterns**: The power of a calendar comes from the rich wildcard rules (month 13 =
  odd, 14 = even, day-of-month 32 = last day, weekday 7 = Sunday, unspecified = wildcard, etc.).
  Each specified component must match independently, and entries are ORed together. Impossible date
  patterns never match and are not clamped to another date. The shared pure
  `BACnet.Protocol.CalendarEntry.matches_date?/2` predicate implements these rules. WeekNDay
  supports weeks 1..9 and unspecified.

  **Remote calendars**: Applications may obtain a remote Calendar's value through host read
  operations. Standard Schedule exception references are local Calendar ObjectIdentifiers - that
  reference datatype contains no remote device address. Remote Calendar snapshots remain passive
  when executed and preserve their object and runtime state.

  **Writing the date_list**: It is a writable BACnetLIST of CalendarEntry values, represented by an
  Elixir list. Clients can completely rewrite the holidays at runtime. All three choices are
  supported: dates/patterns, inclusive ranges with specific or fully unspecified endpoints, and
  WeekNDay. Configuration validation checks the entries' date-matching semantics.

  Calendars are the classic example of a "pure reference object" whose only job is to answer a
  yes/no question that many other objects need.

  ### Lifecycle Execution

  Use `BACnet.Protocol.ObjectExecution.Lifecycle` to initialize the Calendar, validate proposed
  writes and refresh computed-property reads. Every local execution recomputes `present_value` from
  `date_list` and the date of `context.now`. An empty list evaluates to `false` - otherwise any
  matching entry makes the value `true`. The result depends on the supplied current date, even if
  execution was delayed or the clock moved backward. Missed days are not replayed as a series of
  transitions.

  #### Inputs and runtime state

  Supply `context.now` already expressed in the device's configured timezone. Calendar uses that
  DateTime's date and zone directly - the database in `context.timezone_database` resolves future
  local deadlines. UTC can use `Calendar.UTCOnlyTimeZoneDatabase`. Regional zones require a database
  that supports the zone. No implicit clock read or timezone conversion takes place.

  Supply the required `BACnet.Protocol.ObjectExecution.Context` execution inputs, including current monotonic
  milliseconds even though Calendar requests wall-clock deadlines. `lookup_object`, `read_property`
  and `write_property` may all be `nil`: Calendar invokes no host I/O callbacks. It uses no
  object-specific `context.options`, so `[]` is sufficient. Start with `state: nil` - Calendar
  preserves the supplied opaque state without requiring a cached previous value. The host needs to
  retain the complete result and pass its state back for this same instance.

  #### When the host executes the Calendar

  | Event | Required interaction |
  | --- | --- |
  | Creation or restart | Execute with `:initialization` and current time before serving a live value. Creation supplies property defaults - it does not evaluate the current date. |
  | Requested midnight reached | Check the current request with `BACnet.Protocol.ObjectExecution.Wakeup.due?/2`, then execute with `:timer`. |
  | Clock correction or timezone change | Execute with `:clock_change` using the new local time and database, and replace the previous timer. |
  | Successful property write | Prepare and commit the candidate, then execute with `{:property_write, property, nil, nil}`, including same-value writes. |
  | Read of `present_value` | Call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` with `{:property_read, :present_value, nil}`, retain the result, then obtain the property through `get_property/2`. |

  A raw getter returns the value stored in the struct, which may be stale after a day change or
  edit. Fresh reads are also required when another object asks the host for this Calendar's value.
  Nested reads use the same supplied time as the enclosing operation. Polling can refresh a value,
  but the host must also handle writes, reads and clock changes promptly.

  For `date_list` writes, check client write access and build the candidate using
  `update_property/3`, then call
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` with the original, candidate and write
  context. Commit the returned candidate before calling
  `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` with that same context. Retain the returned
  object, runtime state and wakeup together. This makes edits take effect on the same day.
  `present_value` is read-only to BACnet clients - internal property functions remain available to
  the implementation and do not replace host access checks.

  The host needs to track dependent objects and deliver dependency-change notifications after
  Calendar configuration or value changes. A `date_list` edit can require reevaluating a Schedule
  even when the Calendar's Boolean value stays unchanged. COV subscription handling and delivery
  belong to the host's services.

  #### Next execution and timer ownership

  Every successful local execution requests the next local midnight as a
  `BACnet.Protocol.ObjectExecution.Wakeup` with `wall_time` set. This happens even for an empty list
  or when the next day will have the same Boolean value. Calendar requests neither a monotonic
  deadline nor an immediate continuation.

  An ambiguous midnight uses its first future occurrence - a midnight in a gap uses the first instant
  after the gap, including skipped dates. The host needs to retain this request, cancel the
  superseded timer and schedule execution against the absolute deadline. Check time again when the
  timer arrives and rearm an early request. Ignore messages from cancelled or replaced requests. A
  wall-clock change requires explicit notification and timer reconciliation - a process timer alone
  does not detect the correction. After a restart, initialize with fresh runtime state and current
  clocks.

  #### Validation, errors and remote snapshots

  Local preflight validates the date-list matching semantics and availability of the next local
  midnight. It returns `{:error, {:invalid_configuration, :date_list}}` for an invalid list,
  or `{:error, {:timezone_error, reason}}` when the supplied database cannot resolve the zone/deadline.
  Lifecycle execution does not execute intrinsic reporting.
  Deadline resolution is required even when the list is empty. Date-range endpoint requirements and
  weekday handling are documented in `BACnet.Protocol.CalendarEntry.valid_for_matching?/1`.

  Rejected write preparation leaves the stored object, runtime state and pending wakeup unchanged.
  An execution error supplies no replacement result. The host needs to retain the previous result,
  or the already committed candidate plus previous state and wakeup if a write was accepted first.
  It must report that latter case distinctly from a rejected write. See
  `BACnet.Protocol.ObjectExecution.Lifecycle` for the general retention contract.

  Remote Calendar snapshots execute passively: their object and supplied state are preserved, and no
  wakeup is requested. They are not locally recomputed or polled by execution. Preparing a write to
  a remote snapshot through the lifecycle returns `{:error,
  :operation_not_available_for_remote_objects}` - accessing a remote device belongs to the host's
  BACnet client operations.

  Calendar has no commandability, out-of-service or intrinsic-reporting capability.

  See the calendar lifecycle example in the examples directory for a runnable host and
  a walkthrough of initialization, wakeups, reads, writes and clock changes.

  ### Examples

  Creating a Calendar:

      iex> {:ok, cal} = BACnet.Protocol.ObjectTypes.Calendar.create(500, "Holidays", %{}); cal.object_name
      "Holidays"

  #### Complete example: Christmas and fresh reads

  Paste this example into IEx with BACstack loaded. It creates an annually recurring Christmas
  entry, initializes before midnight, services the returned deadline and refreshes a read on the
  following day. Explicit clock samples make the results reproducible. The example retains each
  result in `stored` - a running application must also arrange timer delivery and handle errors as
  described above.

      iex> alias BACnet.Protocol.BACnetDate
      iex> alias BACnet.Protocol.CalendarEntry
      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle, Wakeup}
      iex> alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject
      iex> christmas = %CalendarEntry{
      ...>   type: :date,
      ...>   date: %BACnetDate{year: :unspecified, month: 12, day: 25, weekday: :unspecified},
      ...>   date_range: nil,
      ...>   week_n_day: nil
      ...> }
      iex> {:ok, calendar} = CalendarObject.create(500, "Holidays", %{date_list: [christmas]})
      iex> context = %Context{
      ...>   device_identifier: nil,
      ...>   now: ~U[2026-12-24 23:59:00Z],
      ...>   timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
      ...>   monotonic_time: -60_000,
      ...>   trigger: :initialization,
      ...>   state: nil,
      ...>   lookup_object: nil,
      ...>   read_property_multiple: nil,
      ...>   read_property: nil,
      ...>   write_property: nil,
      ...>   options: []
      ...> }
      iex> {:ok, stored} = Lifecycle.execute(calendar, context)
      iex> {stored.object.present_value, stored.next_execution.wall_time}
      {false, ~U[2026-12-25 00:00:00Z]}
      iex> timer_context = %{context | now: ~U[2026-12-25 00:00:00Z],
      ...>   monotonic_time: 0, state: stored.state, trigger: :timer}
      iex> Wakeup.due?(stored.next_execution, timer_context)
      true
      iex> {:ok, stored} = Lifecycle.execute(stored.object, timer_context)
      iex> {stored.object.present_value, stored.next_execution.wall_time}
      {true, ~U[2026-12-26 00:00:00Z]}
      iex> read_context = %{context | now: ~U[2026-12-26 12:00:00Z],
      ...>   monotonic_time: 129_600_000, state: stored.state,
      ...>   trigger: {:property_read, :present_value, nil}}
      iex> CalendarObject.get_property(stored.object, :present_value)
      {:ok, true}
      iex> {:ok, stored} = Lifecycle.prepare_read(stored.object, read_context)
      iex> CalendarObject.get_property(stored.object, :present_value)
      {:ok, false}

  The first getter still sees the retained Christmas result. Only the prepared read evaluates
  December 26 and returns its next wakeup. For a complete pre-commit write and clock-change
  sequence, see the example in `BACnet.Protocol.ObjectExecution.Lifecycle`.

  ### See Also
  - Related: `BACnet.Protocol.ObjectTypes.Schedule`
  """

  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Calendar object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Calendar properties. Use property operations for updates and lifecycle execution to refresh the
  computed present value.
  """
  bac_object Constants.macro_assert_name(:object_type, :calendar) do
    services(intrinsic: false)

    field(:description, String.t())

    field(:date_list, [CalendarEntry.t()],
      required: true,
      default: [],
      validator_fun: &valid_date_list?/2
    )

    field(:present_value, boolean(), required: true, default: false, readonly: true)
  end

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_configuration(object),
         {:ok, _wakeup} <- next_wakeup(context) do
      :ok
    end
  end

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    if Context.written_property(context, :property_write) == :present_value,
      do: {:error, {:write_access_denied, :present_value}},
      else: super(original, candidate, context)
  end

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote), do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_execution(object, context),
         {:ok, wakeup} <- next_wakeup(context),
         today = DateTime.to_date(context.now),
         value = Enum.any?(object.date_list, &CalendarEntry.matches_date?(&1, today)),
         {:ok, updated} <- update_property(object, :present_value, value) do
      {:ok, %Result{object: updated, state: context.state, next_execution: wakeup}}
    end
  end

  @spec valid_date_list?([CalendarEntry.t()], map()) :: boolean()
  defp valid_date_list?(entries, object)

  defp valid_date_list?(entries, %{_metadata: %{remote_object: nil}}) do
    Enum.all?(entries, &CalendarEntry.valid_for_matching?/1)
  end

  defp valid_date_list?(_entries, _object), do: true

  @spec validate_configuration(t()) :: :ok | {:error, {:invalid_configuration, :date_list}}
  defp validate_configuration(object) do
    if is_list(object.date_list) and valid_date_list?(object.date_list, object),
      do: :ok,
      else: {:error, {:invalid_configuration, :date_list}}
  end

  @spec next_wakeup(Context.t()) :: {:ok, Wakeup.t()} | {:error, {:timezone_error, term()}}
  defp next_wakeup(context) do
    tomorrow =
      context.now
      |> DateTime.to_date()
      |> Date.add(1)

    case DateTime.new(tomorrow, ~T[00:00:00], context.now.time_zone, context.timezone_database) do
      {:ok, midnight} ->
        {:ok, %Wakeup{wall_time: midnight, monotonic_time: nil}}

      {:ambiguous, first, second} ->
        midnight = if DateTime.compare(first, context.now) == :gt, do: first, else: second
        {:ok, %Wakeup{wall_time: midnight, monotonic_time: nil}}

      {:gap, _before, first_after} ->
        {:ok, %Wakeup{wall_time: first_after, monotonic_time: nil}}

      {:error, reason} ->
        {:error, {:timezone_error, reason}}
    end
  end
end
