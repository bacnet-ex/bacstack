defmodule BACnet.Protocol.ObjectTypes.Averaging do
  @moduledoc """
  An Averaging object tracks the minimum, maximum and arithmetic mean of a
  property over a moving window. It can also report variance and the timestamps of the
  extrema. For example, sample the same temperature periodically to see how far
  it varies over the last hour.

  `object_property_reference` identifies a local or remote property. Every
  `window_interval / window_samples` seconds, execution attempts to acquire that property
  through the host's read callback. The latest `window_samples` attempts form the window.
  A failed acquisition occupies a missed slot rather than contributing a zero value.

  ### Object Description (ASHRAE 135)

  > The Averaging object type defines a standardized object whose properties represent
  > the externally visible characteristics of a value that is sampled periodically over
  > a specified time interval.

  ## Statistics and sample values

  `min_value`, `max_value` and `average_value` describe the valid samples in the current
  window. `attempted_samples` counts retained attempts and `valid_samples` counts successful
  acquisitions, so their difference gives the missed samples. Both counts stop growing when
  the window is full. Displacing an attempt also removes its value from the statistics.

  Optional `variance_value` uses **population variance**, dividing the sum of squared deviations
  by the valid sample count. A single finite sample has zero variance. Optional
  `min_value_timestamp` and `max_value_timestamp` record the acquisition time of each extremum.
  When values tie, the oldest retained sample's timestamp wins. These choices are implementation
  policies - the object clause does not prescribe the variance formula or timestamp tie policy.

  Accepted inputs are native booleans, integers and REAL floats, or primitive
  `BACnet.Protocol.ApplicationTags.Encoding` values of type BOOLEAN, INTEGER, Unsigned,
  Enumerated or REAL. A singleton list of those encodings is also accepted. Booleans become
  zero or one, and enumerations use their unsigned numeric value. Convert application-specific
  enumeration atoms to their BACnet numeric encoding in the host adapter, for example with
  `BACnet.Protocol.ObjectsUtility.cast_value_to_property/4`. DOUBLE, NULL, constructed values,
  multi-value lists and other unsupported values are missed samples. Numeric conversion and
  aggregate results use single-precision REAL through `BACnet.Protocol.ApplicationTags`,
  including its configured float-decoding rounding.

  REAL special values `:inf`, `:infn` and `:NaN` remain valid samples. Opposite infinities give a
  NaN mean, and any infinite sample gives NaN variance. A NaN sample propagates to all four
  statistics while retained, with unspecified extrema timestamps. If there are no valid samples,
  minimum is `:inf`, maximum is `:infn`, mean and variance are `:NaN`, and optional timestamps are
  unspecified. Check counts and special values before using the statistics in application logic.

  ## Configuration and reset writes

  Supply `window_interval` in seconds. The default `window_samples` is **15**. Local execution
  requires both values to be positive and the resulting period to be at least one millisecond.
  This implementation's minimum window interval is one second. These timing limits reflect its
  millisecond clock resolution, rather than a BACnet-wide minimum. Sample counts above 15 are
  supported when their period satisfies that limit.

  Initialization and accepted writes to any of these properties clear the entire buffer:

  - `attempted_samples` - only zero may be written by a BACnet client.
  - `object_property_reference` - selecting the same source also resets the window.
  - `window_interval` and `window_samples` - same-value writes also reset the window.

  Resetting publishes zero counts, empty statistics and unspecified optional timestamps. The
  first sample is due one new period after reset, without an immediate source read. There is no
  independent count-only mode, standardized `out_of_service` switch or priority array.
  Calculated properties are read-only to BACnet clients. Low-level `update_property/3` updates
  storage without executing or clearing the runtime buffer - client writes need lifecycle
  preparation and execution, as described below.

  ## Lifecycle integration

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  owns storage, operation ordering, clocks, callback routing and timers. The module owns sampling,
  the rolling window and the calculations. The host needs to:

  1. Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2`, an initialization
     trigger and fresh state. Retain the complete result before serving live statistics.
  2. Supply a bounded read callback in `BACnet.Protocol.ObjectExecution.Context`. It needs to
     obtain the identified property's current value, including its array index, and refresh any
     dependent computed object before returning its value. Detect cyclic reads rather than
     synchronously entering an already executing owner.
  3. Retain each result's object, opaque state and replacement wakeup together, and deliver due
     timers with fresh clocks and the retained state. See the timer arming, replacement and
     stale-delivery examples in `BACnet.Protocol.ObjectExecution.Lifecycle`.
  4. Prepare client writes with `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`.
     Commit the returned candidate, then execute the same write trigger before processing the
     next external operation. This is required even when the written value is unchanged.
  5. Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before reading statistics.
     A due read can acquire one sample and returns an updated lifecycle result to retain first.

  Local references are supported. An explicit reference to the context's `device_identifier`
  normalizes to a local reference. Other device-qualified references are passed to the read
  callback unchanged, including when the local identity is nil. Remote acquisition is supported
  through that callback - the host needs to resolve routing and access and return the value or
  an operational error. A remote Averaging **snapshot** itself remains passive.

  ## Timing, failures and restart

  Sampling uses VM-monotonic milliseconds. Deadlines are rounded up from the absolute rational
  schedule, so fractional periods do not accumulate rounding drift. Wall-clock corrections affect
  acquisition timestamps, without moving the monotonic sampling origin. Early or repeated calls
  preserve the pending request and do not reacquire the same slot.

  If delivery is late, expired earlier slots become missed attempts and one instantaneous sample
  is acquired for the latest due slot at the supplied current wall time. Execution does not issue
  repeated current reads as historical samples. Work and retained storage are bounded by the
  configured sample count even after a long pause. The next deadline retains the original cadence.
  Slow callbacks can make later slots late - the host needs to bound callback waits and resample
  clocks for subsequent steps.

  Preflight rejects malformed configuration, incompatible runtime state and a missing read
  callback before I/O. Lifecycle execution does not execute intrinsic reporting. A failed read
  or unsupported value returns `{:ok, result}`, with a missed attempt and error details in opaque runtime state, so the host
  can retain progress and continue sampling. A successful acquisition clears the latest error.
  Averaging has no Reliability property or standardized intrinsic algorithm. Callback exceptions
  and malformed callback results remain programming errors.

  Keep the sample buffer as well as the object while the instance is running - aggregates alone
  cannot reconstruct a sliding window. After a VM restart, initialize with fresh state and clocks.
  This discards samples, resets statistics and schedules the first new acquisition. Do not restore
  old VM-monotonic timestamps. A separate `BACnet.Protocol.ObjectTypes.EventEnrollment` can
  monitor a statistic for algorithmic reporting when that integration is implemented.

  ## Examples

  Creating an Averaging object for a one-hour window:

      iex> {:ok, average} = BACnet.Protocol.ObjectTypes.Averaging.create(300, "AvgTemp", %{window_interval: 3600})
      iex> {average.object_name, average.window_samples}
      {"AvgTemp", 15}

  Initializing and driving one sample with explicit clocks:

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Averaging
      iex> {:ok, object} = Averaging.create(301, "One-minute statistics", %{window_interval: 60})
      iex> context = Context.new(:initialization, now: ~U[2026-11-09 08:00:00Z],
      ...>   monotonic_time: 0, read_property: fn _reference -> {:ok, 21.5} end)
      iex> {:ok, stored} = Lifecycle.execute(object, context)
      iex> {stored.object.valid_samples, stored.next_execution.monotonic_time}
      {0, 4000}
      iex> timer_context = %{context | trigger: :timer, state: stored.state,
      ...>   now: ~U[2026-11-09 08:00:04Z], monotonic_time: 4000}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, timer_context)
      iex> {stored.object.valid_samples, stored.object.average_value}
      {1, 21.5}

  This snippet represents retention by rebinding `stored`. A complete finite walkthrough of
  rolling windows, failed reads, resets and remote references is available in
  `examples/objects_lifecycle/averaging_lifecycle.exs` in the repository.

  For many observers sharing a source, a host may share acquisition or cache work when it can
  still supply the required sample at each object's due time. It needs to preserve each instance's
  independent window and avoid presenting a stale cached value as a successful fresh acquisition.

  ### See Also

  - `BACnet.Protocol.ObjectExecution.Lifecycle`
  - `BACnet.Protocol.ObjectTypes.EventEnrollment`
  - `BACnet.Protocol.ObjectTypes.TrendLog`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Averaging object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents an Averaging object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.
  """
  bac_object Constants.macro_assert_name(:object_type, :averaging) do
    services(intrinsic: false)

    field(:description, String.t())

    field(:min_value, ApplicationTags.ieee_float(),
      required: true,
      readonly: true,
      default: :inf
    )

    field(:min_value_timestamp, BACnetDateTime.t(),
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:average_value, ApplicationTags.ieee_float(),
      required: true,
      readonly: true,
      default: :NaN
    )

    field(:variance_value, ApplicationTags.ieee_float(),
      readonly: true,
      default: :NaN
    )

    field(:max_value, ApplicationTags.ieee_float(),
      required: true,
      readonly: true,
      default: :infn
    )

    field(:max_value_timestamp, BACnetDateTime.t(),
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:attempted_samples, non_neg_integer(), required: true, default: 0)
    field(:valid_samples, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:object_property_reference, DeviceObjectPropertyRef.t(),
      required: true,
      default: ObjectsMacro.get_default_dev_object_ref()
    )

    field(:window_interval, non_neg_integer(), required: true)
    field(:window_samples, non_neg_integer(), required: true, default: 15)
  end

  @reset_properties [
    :attempted_samples,
    :object_property_reference,
    :window_interval,
    :window_samples
  ]
  @computed_properties [
    :min_value,
    :min_value_timestamp,
    :average_value,
    :variance_value,
    :max_value,
    :max_value_timestamp,
    :valid_samples
  ]

  @typep sample ::
           :missed | {value :: ApplicationTags.ieee_float(), sampled_at :: BACnetDateTime.t()}
  @typep configuration ::
           {DeviceObjectPropertyRef.t(), window_interval_seconds :: pos_integer(),
            window_samples :: pos_integer()}
  @typep execution_state :: %{
           configuration: configuration(),
           origin: integer(),
           next_slot: pos_integer(),
           samples: [sample()],
           last_error: term()
         }

  @doc """
  Validates sampling configuration, runtime state and the required read callback without I/O.

  Local instances require a positive window interval and sample count, with a sample period
  of at least one millisecond. Normal sampling requires initialized runtime state.
  Initialization and reset writes replace any previous state.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_configuration(object),
         :ok <- validate_request(object, context),
         :ok <- validate_state(object, context) do
      Context.require_operations(context, [:read_property])
    end
  end

  @doc """
  Rejects writes to calculated properties and resets statistics for a sampling reset write.

  Only zero may be written to `attempted_samples`. Writes to that property, the source reference
  or either window setting reset statistics even if the value is unchanged. Execution after
  commit clears the sample buffer and establishes a new sampling origin.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    property = Context.written_property(context, :property_write)

    cond do
      property in @computed_properties ->
        {:error, {:write_access_denied, property}}

      property == :attempted_samples and candidate.attempted_samples != 0 ->
        {:error, :value_out_of_range}

      property in @reset_properties ->
        reset_statistics(candidate)

      true ->
        super(original, candidate, context)
    end
  end

  @doc """
  Resets sampling or records one due acquisition and updates the rolling statistics.

  Initialization and reset writes clear the window without reading. Other triggers acquire at
  most once when a slot is due. Skipped slots and failed acquisitions occupy missed entries,
  and every result replaces the previous monotonic wakeup. Operational failures return a
  successful result containing the updated counts and runtime error details.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote), do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_execution(object, context) do
      if reset?(context) do
        {:ok, object} = reset_statistics(object)

        state = %{
          configuration: configuration(object),
          origin: context.monotonic_time,
          next_slot: 1,
          samples: [],
          last_error: nil
        }

        result(object, state)
      else
        sample_if_due(object, context, context.state)
      end
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object) do
    cond do
      not is_integer(object.window_interval) or object.window_interval < 1 ->
        {:error, {:invalid_configuration, :window_interval}}

      not is_integer(object.window_samples) or object.window_samples < 1 or
          object.window_samples > object.window_interval * 1000 ->
        {:error, {:invalid_configuration, :window_samples}}

      not is_struct(object.object_property_reference, DeviceObjectPropertyRef) or
          not DeviceObjectPropertyRef.valid?(object.object_property_reference) ->
        {:error, {:invalid_configuration, :object_property_reference}}

      true ->
        :ok
    end
  end

  @spec validate_request(t(), Context.t()) :: :ok | {:error, :value_out_of_range}
  defp validate_request(object, context) do
    if Context.written_property(context, :property_write) == :attempted_samples and
         object.attempted_samples != 0,
       do: {:error, :value_out_of_range},
       else: :ok
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context) do
    valid =
      if reset?(context) do
        true
      else
        case context.state do
          %{
            configuration: config,
            origin: origin,
            next_slot: slot,
            samples: samples,
            last_error: _error
          }
          when is_integer(origin) and is_integer(slot) and slot > 0 and is_list(samples) ->
            config == configuration(object) and context.monotonic_time >= origin and
              length(samples) == min(slot - 1, object.window_samples) and
              Enum.all?(samples, &valid_sample?/1)

          _other ->
            false
        end
      end

    if valid, do: :ok, else: {:error, :invalid_execution_state}
  end

  @spec valid_sample?(term()) :: boolean()
  defp valid_sample?(sample)
  defp valid_sample?(:missed), do: true

  defp valid_sample?({value, %BACnetDateTime{} = timestamp}),
    do: (is_float(value) or value in [:inf, :infn, :NaN]) and BACnetDateTime.valid?(timestamp)

  defp valid_sample?(_sample), do: false

  @spec configuration(t()) :: configuration()
  defp configuration(object),
    do: {object.object_property_reference, object.window_interval, object.window_samples}

  @spec reset?(Context.t()) :: boolean()
  defp reset?(context),
    do:
      context.trigger == :initialization or
        Context.written_property(context, :property_write) in @reset_properties

  @spec reset_statistics(t()) :: {:ok, t()} | {:error, term()}
  defp reset_statistics(object), do: update_statistics(object, [], 0)

  @spec sample_if_due(t(), Context.t(), execution_state()) :: {:ok, Result.t(t())}
  defp sample_if_due(object, context, state) do
    slot =
      div(
        (context.monotonic_time - state.origin) * object.window_samples,
        object.window_interval * 1000
      )

    if slot < state.next_slot do
      result(object, state)
    else
      {sample, error} = acquire(object, context)
      missed = min(slot - state.next_slot, object.window_samples - 1)

      samples =
        [sample | List.duplicate(:missed, missed)] ++
          Enum.take(state.samples, object.window_samples - missed - 1)

      state = %{state | next_slot: slot + 1, samples: samples, last_error: error}
      {:ok, object} = update_statistics(object, samples, length(samples))
      result(object, state)
    end
  end

  @spec acquire(t(), Context.t()) :: {sample(), error_details :: term()}
  defp acquire(object, context) do
    ref = object.object_property_reference

    ref =
      if ref.device_identifier == context.device_identifier,
        do: %{ref | device_identifier: nil},
        else: ref

    with {:ok, value} <- Context.read_property(context, ref),
         {:ok, value} <- sample_value(value) do
      {{value, BACnetDateTime.from_datetime(context.now)}, nil}
    else
      {:error, reason} -> {:missed, {ref, reason}}
    end
  end

  @spec sample_value(term()) :: {:ok, ApplicationTags.ieee_float()} | {:error, term()}
  defp sample_value(value)
  defp sample_value([%Encoding{} = value]), do: sample_value(value)

  defp sample_value(%Encoding{encoding: :primitive, type: :boolean, value: value})
       when is_boolean(value), do: sample_value(value)

  defp sample_value(%Encoding{encoding: :primitive, type: type, value: value})
       when type in [:unsigned_integer, :enumerated] and is_integer(value) and value >= 0,
       do: real(value)

  defp sample_value(%Encoding{encoding: :primitive, type: :signed_integer, value: value})
       when is_integer(value), do: real(value)

  defp sample_value(%Encoding{encoding: :primitive, type: :real, value: value})
       when is_float(value) or value in [:inf, :infn, :NaN], do: real(value)

  defp sample_value(value) when is_boolean(value), do: {:ok, if(value, do: 1.0, else: 0.0)}
  defp sample_value(value) when is_number(value) or value in [:inf, :infn, :NaN], do: real(value)
  defp sample_value(_value), do: {:error, :invalid_sample_value}

  @spec real(number() | :inf | :infn | :NaN) ::
          {:ok, ApplicationTags.ieee_float()} | {:error, term()}
  defp real(value) do
    value = if is_integer(value), do: value / 1, else: value

    with {:ok, bytes, _header} <- ApplicationTags.encode_value({:real, value}) do
      ApplicationTags.decode_value(Constants.macro_by_name(:application_tag, :real), bytes)
    end
  rescue
    ArithmeticError -> {:error, :invalid_sample_value}
    ArgumentError -> {:error, :invalid_sample_value}
  end

  @spec update_statistics(t(), [sample()], non_neg_integer()) :: {:ok, t()} | {:error, term()}
  defp update_statistics(object, samples, attempted) do
    valid = for {value, timestamp} <- Enum.reverse(samples), do: {value, timestamp}
    statistics = statistics(valid)
    updates = [attempted_samples: attempted, valid_samples: length(valid)] ++ statistics

    Enum.reduce_while(updates, {:ok, object}, fn {property, value}, {:ok, current} ->
      if property in @computed_properties and is_nil(Map.fetch!(current, property)) do
        {:cont, {:ok, current}}
      else
        case update_property(current, property, value) do
          {:ok, updated} -> {:cont, {:ok, updated}}
          {:error, _reason} = error -> {:halt, error}
        end
      end
    end)
  end

  @spec statistics([{value :: ApplicationTags.ieee_float(), sampled_at :: BACnetDateTime.t()}]) ::
          Keyword.t()
  defp statistics(samples)

  defp statistics([]) do
    [
      min_value: :inf,
      max_value: :infn,
      average_value: :NaN,
      variance_value: :NaN,
      min_value_timestamp: ObjectsMacro.get_default_bacnet_datetime(),
      max_value_timestamp: ObjectsMacro.get_default_bacnet_datetime()
    ]
  end

  defp statistics(samples) do
    if Enum.any?(samples, fn {value, _timestamp} -> value == :NaN end) do
      Keyword.merge(statistics([]), min_value: :NaN, max_value: :NaN)
    else
      {minimum, min_timestamp} = extreme(samples, :min)
      {maximum, max_timestamp} = extreme(samples, :max)
      values = Enum.map(samples, &elem(&1, 0))
      average = average(values)
      variance = variance(values, average)
      {:ok, average} = real(average)
      {:ok, variance} = real(variance)

      [
        min_value: minimum,
        max_value: maximum,
        average_value: average,
        variance_value: variance,
        min_value_timestamp: min_timestamp,
        max_value_timestamp: max_timestamp
      ]
    end
  end

  @spec extreme(
          [{value :: ApplicationTags.ieee_float(), sampled_at :: BACnetDateTime.t()}],
          :min | :max
        ) ::
          {value :: ApplicationTags.ieee_float(), sampled_at :: BACnetDateTime.t()}
  defp extreme([first | rest], direction) do
    Enum.reduce(rest, first, fn {value, _timestamp} = sample, {previous, _time} = current ->
      replace = if direction == :min, do: less?(value, previous), else: less?(previous, value)
      if replace, do: sample, else: current
    end)
  end

  @spec less?(ApplicationTags.ieee_float(), ApplicationTags.ieee_float()) :: boolean()
  defp less?(left, right)
  defp less?(value, value), do: false
  defp less?(:infn, _right), do: true
  defp less?(_left, :inf), do: true
  defp less?(:inf, _right), do: false
  defp less?(_left, :infn), do: false
  defp less?(left, right), do: left < right

  @spec average([ApplicationTags.ieee_float()]) :: ApplicationTags.ieee_float()
  defp average(values) do
    count = length(values)

    cond do
      :inf in values and :infn in values -> :NaN
      :inf in values -> :inf
      :infn in values -> :infn
      true -> Enum.reduce(values, 0.0, fn value, total -> total + value / count end)
    end
  end

  @spec variance([ApplicationTags.ieee_float()], ApplicationTags.ieee_float()) ::
          ApplicationTags.ieee_float()
  defp variance(values, average)

  defp variance(values, average) when is_float(average) do
    count = length(values)
    Enum.reduce(values, 0.0, fn value, total -> total + (value - average) ** 2 / count end)
  end

  defp variance(_values, _average), do: :NaN

  @spec result(t(), execution_state()) :: {:ok, Result.t(t())}
  defp result(object, state) do
    # Round each absolute rational deadline up, rather than repeatedly rounding a period.
    numerator = state.next_slot * object.window_interval * 1000
    deadline = state.origin + div(numerator + object.window_samples - 1, object.window_samples)

    {:ok,
     %Result{
       object: object,
       state: state,
       next_execution: %Wakeup{wall_time: nil, monotonic_time: deadline}
     }}
  end
end
