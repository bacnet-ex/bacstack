defmodule BACnet.Protocol.ObjectTypes.Accumulator do
  @moduledoc """
  The Accumulator counts pulses from equipment such as an electricity, water or gas
  meter. Present_Value holds the running count. Prescale controls how many input
  pulses contribute to it, and Max_Pres_Value sets the rollover point. Optional
  properties report the pulse rate, record when the count was preset, or capture
  a sample for a logger.

  ### Object Description (ASHRAE 135)

  > The Accumulator object type defines a standardized object whose properties
  > represent the externally visible characteristics of a device that indicates
  > measurements made by counting pulses.
  >
  > Accumulator objects that support intrinsic reporting shall apply the UNSIGNED_RANGE event algorithm.

  ### Count pulses

  Initialize the restored object with
  `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and an
  `:initialization` context. Deliver raw input pulse batches with
  `record_pulses/3` and the prior result's state. The host needs to submit each
  batch once and retain the whole successful result before another operation.
  This module applies Prescale using integer arithmetic and carries the
  fractional remainder between batches. The divisor must be greater than
  zero. The count wraps modulo Max_Pres_Value plus one.

  An adapter that already maintains the absolute count can report it through
  `update_property/3` with an `:application_write` trigger. Use a 1:1 Prescale
  when submitting batches of already prescaled pulses. Scale describes the
  engineering-unit conversion for clients reading Present_Value. The lifecycle
  leaves the count in its unsigned representation.

  Initialization preserves the supplied count and starts fresh runtime state.
  A new lifecycle, a changed Prescale or a Value_Set write starts a fresh
  fractional remainder.

  ### Measure the pulse rate

  Select Pulse_Rate or Limit_Monitoring_Interval to enable both properties.
  Intrinsic reporting also selects the pair. The interval is in seconds and
  must be positive. Pulse_Rate is the number of input pulses in the most
  recently completed fixed window, before prescaling. The host needs to supply
  a batch's acquisition time in the monotonic clock domain. A batch at the
  window boundary belongs to the new window. A completed window without
  pulses reports zero.

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  needs to arm the returned monotonic wakeup and deliver it with a `:timer`
  context. Replace the previous deadline after each successful step. An
  interval change starts a fresh window. The lifecycle also completes overdue
  windows on ordinary operations.

  ### Preset the count and simulate inputs

  When Value_Set is present, a write to it replaces Present_Value, stores the
  previous visible count in Value_Before_Change and stamps Value_Change_Time
  using the supplied device-local clock. This also happens when the same
  preset is written again. Value_Set is writable in either service state.
  Value_Before_Change and Value_Change_Time are read-only.

  Construct property candidates with `update_property/3`, call
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` and execute the
  prepared candidate with the same context and prior state. The host needs to
  preserve the write origin, enforce service access and serialize operations.
  Rejection leaves the previous result in storage.

  Present_Value and Pulse_Rate are writable to BACnet clients while out of
  service. Incoming pulse batches are ignored and the rate timer is cancelled
  while isolated. Returning to service restores the retained count, including
  any Value_Set preset, and opens a new rate window.

  The host supplies Reliability from its input adapter. Inhibition exposes
  NO_FAULT_DETECTED while retaining the physical report. While out of service,
  either write origin can supply an alternate simulated Reliability. Refresh
  physical reports held only in runtime state after restarting.

  ### Qualified reads of Logging_Record

  Logging_Record holds the latest snapshot of the meter. It captures the
  acquisition time, the count at that time, the accumulated count since the
  preceding acquisition, and the status of that interval. The native property
  value is a one-element list containing a `BACnet.Protocol.AccumulatorRecord`.
  A host that needs a history can store each acquired snapshot separately.

  A *qualified read* of Logging_Record acquires a new snapshot and starts the
  next accumulation interval. Select Logging_Object when one local object
  should control those intervals. For example, an hourly logger can measure
  consumption between its samples while a dashboard or maintenance client
  reads the last hourly record at any time. Those readers see the retained
  timestamp and counts, and their reads leave the logger's interval intact.
  Without Logging_Object, every Logging_Record read acquires a new snapshot.

  Selecting Logging_Object also selects Logging_Record. Use
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before getting the
  property. When a local object initiates a read, the host supplies its
  identifier as `:reader_identifier` in the
  `BACnet.Protocol.ObjectExecution.Context` options. A read qualifies when
  that identifier matches Logging_Object. Leave the option unset for network
  clients. Retain the successful result so the next read uses the same
  snapshot and interval state.

  Before the first acquisition, readers see STARTING with an unspecified
  timestamp and zero counts. The first qualified read captures the current
  time and count, with zero accumulated value, and establishes the baseline.
  Later acquisitions report the modular count delta. A Value_Set write is
  excluded from the delta and marks the interval RECOVERED when otherwise
  healthy. A delivered clock change marks the interval ABNORMAL. An exposed
  fault marks it FAILED and the acquired record reports zero delta. Changing
  Logging_Object or initializing the object starts a fresh baseline.

  With `intrinsic_reporting: true`, UNSIGNED_RANGE evaluates Pulse_Rate. The
  next wakeup includes rate sampling and reporting deadlines. After retaining
  the result, the host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1`. Remote
  snapshots remain passive.

  The runnable walkthrough is `examples/objects_lifecycle/accumulator_lifecycle.exs`.

  ### Examples

  Creating an Accumulator:

      iex> {:ok, acc} = BACnet.Protocol.ObjectTypes.Accumulator.create(200, "Energy", %{units: :kilowatt_hours, scale: 10, prescale: %BACnet.Protocol.Prescale{multiplier: 1, modulo_divide: 1}}); acc.object_name
      "Energy"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.UnsignedRange`
  """

  alias BACnet.Protocol.AccumulatorRecord
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.Prescale

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Accumulator object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents an Accumulator object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  The `max_present_value` property defaults to `2^32-1` and can be manually
  set to a higher value, if desired and/or needed.
  """
  bac_object Constants.macro_assert_name(:object_type, :accumulator) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)
    field(:present_value, non_neg_integer(), required: true, default: 0)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:scale, float() | integer(),
      required: true,
      annotation: [
        decoder: fn %Encoding{extras: extras} = encoding ->
          case Keyword.fetch(extras, :tag_number) do
            {:ok, 0} ->
              with {:ok, {_tag, value}} <- ApplicationTags.unfold_to_type(:real, encoding.value) do
                {:ok, value}
              end

            {:ok, 1} ->
              with {:ok, {_tag, value}} <-
                     ApplicationTags.unfold_to_type(:signed_integer, encoding.value) do
                {:ok, value}
              end

            _other ->
              {:error, :invalid_tags}
          end
        end,
        encoder: fn
          float when is_float(float) ->
            with {:ok, raw, _more} <- ApplicationTags.encode_value({:real, float}) do
              Encoding.create({:tagged, {0, raw, byte_size(raw)}})
            end

          int when is_integer(int) ->
            with {:ok, raw, _more} <- ApplicationTags.encode_value({:signed_integer, int}) do
              Encoding.create({:tagged, {1, raw, byte_size(raw)}})
            end

          other ->
            {:error, {:invalid_property_value, {:scale, other}}}
        end
      ]
    )

    field(:prescale, Prescale.t(), required: true)
    field(:max_present_value, non_neg_integer(), required: true, default: 4_294_967_295)

    field(:value_change_time, BACnetDateTime.t(),
      readonly: true,
      annotation: [required_when: {:property, :value_set}],
      init_fun: &ObjectsMacro.get_default_bacnet_datetime/0
    )

    field(:value_before_change, non_neg_integer(),
      readonly: true,
      default: 0,
      annotation: [required_when: {:property, :value_set}],
      implicit_relationship: :value_change_time
    )

    field(:value_set, non_neg_integer())

    field(:logging_record, [AccumulatorRecord.t()],
      readonly: true,
      default: [],
      annotation: [required_when: {:property, :logging_object}]
    )

    field(:logging_object, ObjectIdentifier.t())

    # Intrinsic Reporting
    field(:high_limit, non_neg_integer(), intrinsic: true, default: 0)
    field(:low_limit, non_neg_integer(), intrinsic: true, default: 0)

    field(:pulse_rate, non_neg_integer(),
      default: 0,
      annotation: [required_when: {:opts, :intrinsic_reporting}],
      implicit_relationship: :limit_monitoring_interval
    )

    field(:limit_monitoring_interval, non_neg_integer(),
      default: 1,
      annotation: [required_when: {:opts, :intrinsic_reporting}]
    )
  end

  @typep reliability_value :: Constants.reliability() | non_neg_integer() | nil

  @typep rate_window :: %{
           period: pos_integer(),
           deadline: integer(),
           pulses: non_neg_integer()
         }

  @typep logging_state :: %{
           reader: ObjectIdentifier.t() | nil,
           acquired: boolean(),
           accumulated: non_neg_integer(),
           status: :normal | :recovered | :abnormal | :failed
         }

  @typep execution_state :: %{
           identifier: ObjectIdentifier.t(),
           monotonic_time: integer(),
           present_value: non_neg_integer(),
           retained_count: non_neg_integer(),
           prescale: Prescale.t(),
           remainder: non_neg_integer(),
           out_of_service: boolean(),
           rate_window: rate_window() | nil,
           logging: logging_state() | nil,
           physical_reliability: reliability_value(),
           manual_reliability: reliability_value()
         }

  @doc """
  Records a batch of raw input pulses using the supplied clocks and retained runtime state.

  Initialize the object first. Each batch belongs to the fixed rate window containing
  the supplied monotonic time. While out of service, the batch is ignored. Retain the
  entire result before submitting another batch or exposing a property operation.
  """
  @doc group: "Functions Operational"
  @spec record_pulses(t(), non_neg_integer(), Context.t()) ::
          {:ok, Result.t(t())} | {:error, term()}
  def record_pulses(object, pulses, context)

  def record_pulses(%__MODULE__{_metadata: %{remote_object: remote}}, _pulses, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def record_pulses(%__MODULE__{} = object, pulses, %Context{} = context)
      when is_integer(pulses) and pulses >= 0 do
    step(object, %{context | trigger: :periodic}, pulses)
  end

  def record_pulses(%__MODULE__{}, _pulses, %Context{}), do: {:error, :invalid_pulse_count}

  @doc """
  Reports Present_Value and Pulse_Rate as writable to BACnet clients while out of service.
  """
  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
  def property_writable?(object, property)

  def property_writable?(%__MODULE__{} = object, property)
      when property in [:present_value, :pulse_rate] do
    object.out_of_service == true and has_property?(object, property)
  end

  def property_writable?(%__MODULE__{} = object, property), do: super(object, property)

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_configuration(object),
         :ok <- validate_state(object, context) do
      validate_retained_count(object, Context.previous_state(context))
    end
  end

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with :ok <- validate_execution(original, context),
         :ok <- validate_execution(candidate, context),
         :ok <- validate_write(original, candidate, context) do
      prepare_adjustment(candidate, context)
    end
  end

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote),
      do: {:ok, %Result{object: object, state: context.state, next_execution: nil}}

  def execute(%__MODULE__{} = object, %Context{} = context), do: step(object, context, 0)

  @spec step(t(), Context.t(), non_neg_integer()) :: {:ok, Result.t(t())} | {:error, term()}
  defp step(object, context, pulses) do
    previous = Context.previous_state(context)

    with :ok <- validate_execution(object, context),
         :ok <- validate_write(object, object, context),
         {:ok, adjusted} <- prepare_adjustment(object, context),
         {:ok, reliable, reliability_state} <- reconcile_reliability(adjusted, context) do
      {counted, count, remainder} = update_count(reliable, previous, context, pulses)
      {measured, window} = update_rate(counted, previous, context.monotonic_time, pulses)

      with {:ok, updated, logging} <- update_logging(measured, previous, context) do
        state =
          Map.merge(reliability_state, %{
            identifier: get_object_identifier(updated),
            monotonic_time: context.monotonic_time,
            present_value: updated.present_value,
            retained_count: count,
            prescale: updated.prescale,
            remainder: remainder,
            out_of_service: updated.out_of_service,
            rate_window: window,
            logging: logging
          })

        wakeup = if window, do: %Wakeup{wall_time: nil, monotonic_time: window.deadline}
        result = %Result{object: updated, state: state, next_execution: wakeup}

        {:ok,
         IntrinsicReporting.evaluate(result, context, EventAlgorithms.UnsignedRange, [
           :pulse_rate,
           :present_value
         ])}
      end
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object) do
    cond do
      object.prescale.modulo_divide <= 0 ->
        {:error, {:invalid_configuration, :prescale}}

      object.present_value > object.max_present_value ->
        {:error, {:property_out_of_range, :present_value}}

      has_property?(object, :pulse_rate) and
          (is_nil(object.limit_monitoring_interval) or object.limit_monitoring_interval == 0) ->
        {:error, {:invalid_configuration, :limit_monitoring_interval}}

      true ->
        :ok
    end
  end

  @spec validate_retained_count(t(), execution_state() | nil) :: :ok | {:error, term()}
  defp validate_retained_count(object, previous) do
    if previous && (object.out_of_service or previous.out_of_service) &&
         previous.retained_count > object.max_present_value do
      {:error, {:property_out_of_range, :max_present_value}}
    else
      :ok
    end
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, term()}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state, monotonic_time: now}) do
    case state do
      %{
        identifier: %ObjectIdentifier{} = identifier,
        monotonic_time: previous_time,
        present_value: present_value,
        retained_count: retained_count,
        prescale: %Prescale{modulo_divide: divisor} = prescale,
        remainder: remainder,
        out_of_service: out_of_service,
        rate_window: window,
        logging: logging,
        physical_reliability: physical,
        manual_reliability: manual
      }
      when is_integer(previous_time) and is_integer(present_value) and present_value >= 0 and
             is_integer(retained_count) and retained_count >= 0 and is_integer(remainder) and
             remainder >= 0 and remainder < divisor and is_boolean(out_of_service) ->
        cond do
          identifier != get_object_identifier(object) or not Prescale.valid?(prescale) or
            not valid_window?(window) or not valid_logging?(logging) or
            not ObjectOperations.valid_reliability?(object_contract(), object, physical) or
              not ObjectOperations.valid_reliability?(object_contract(), object, manual) ->
            {:error, :invalid_execution_state}

          now < previous_time ->
            {:error, :monotonic_time_went_backwards}

          true ->
            :ok
        end

      _invalid ->
        {:error, :invalid_execution_state}
    end
  end

  @spec valid_window?(term()) :: boolean()
  defp valid_window?(window)

  defp valid_window?(nil), do: true

  defp valid_window?(%{period: period, deadline: deadline, pulses: pulses})
       when is_integer(period) and period > 0 and is_integer(deadline) and is_integer(pulses) and
              pulses >= 0,
       do: true

  defp valid_window?(_window), do: false

  @spec valid_logging?(term()) :: boolean()
  defp valid_logging?(logging)

  defp valid_logging?(nil), do: true

  defp valid_logging?(%{reader: reader, acquired: acquired, accumulated: delta, status: status})
       when (is_nil(reader) or is_struct(reader, ObjectIdentifier)) and is_boolean(acquired) and
              is_integer(delta) and delta >= 0 and
              status in [:normal, :recovered, :abnormal, :failed],
       do: true

  defp valid_logging?(_logging), do: false

  @spec validate_write(t(), t(), Context.t()) :: :ok | {:error, term()}
  defp validate_write(original, candidate, context) do
    property = Context.written_property(context)
    simulated = original.out_of_service and candidate.out_of_service

    cond do
      property in [:logging_record, :value_before_change, :value_change_time] ->
        {:error, :write_access_denied}

      property == :pulse_rate and not simulated ->
        {:error, :write_access_denied}

      property == :present_value and not simulated and
          match?({:property_write, _property, _index, _priority}, context.trigger) ->
        {:error, :write_access_denied}

      property == :value_set and is_nil(candidate.value_set) ->
        {:error, {:unknown_property, :value_set}}

      property == :value_set and candidate.value_set > candidate.max_present_value ->
        {:error, {:property_out_of_range, :value_set}}

      true ->
        :ok
    end
  end

  @spec prepare_adjustment(t(), Context.t()) :: {:ok, t()} | {:error, term()}
  defp prepare_adjustment(object, context) do
    if Context.written_property(context) == :value_set do
      with {:ok, timestamp} <- timestamp(context),
           {:ok, configured} <- ensure_adjustment_properties(object) do
        {:ok,
         %{
           configured
           | present_value: configured.value_set,
             value_before_change: context.state.present_value,
             value_change_time: timestamp
         }}
      end
    else
      {:ok, object}
    end
  end

  @spec ensure_adjustment_properties(t()) :: {:ok, t()} | {:error, term()}
  defp ensure_adjustment_properties(object) do
    if has_property?(object, :value_change_time) do
      {:ok, object}
    else
      add_property(object, :value_change_time, ObjectsMacro.get_default_bacnet_datetime())
    end
  end

  @spec update_count(t(), execution_state() | nil, Context.t(), non_neg_integer()) ::
          {object :: t(), count :: non_neg_integer(), remainder :: non_neg_integer()}
  defp update_count(object, previous, context, pulses) do
    remainder =
      if previous && previous.prescale == object.prescale, do: previous.remainder, else: 0

    cond do
      Context.written_property(context) == :value_set ->
        {object, object.present_value, 0}

      object.out_of_service ->
        count = if previous, do: previous.retained_count, else: object.present_value
        {object, count, remainder}

      true ->
        baseline =
          if previous && previous.out_of_service &&
               Context.written_property(context) != :present_value,
             do: previous.retained_count,
             else: object.present_value

        prescale = object.prescale
        numerator = remainder + pulses * prescale.multiplier
        count = modulo_count(object, baseline + div(numerator, prescale.modulo_divide))
        {%{object | present_value: count}, count, rem(numerator, prescale.modulo_divide)}
    end
  end

  @spec update_rate(t(), execution_state() | nil, integer(), non_neg_integer()) ::
          {object :: t(), window :: rate_window() | nil}
  defp update_rate(object, previous, now, pulses) do
    if not object.out_of_service and has_property?(object, :pulse_rate) do
      period = object.limit_monitoring_interval * 1000
      window = if previous, do: previous.rate_window

      case window do
        %{period: ^period, deadline: deadline, pulses: pending} when now >= deadline ->
          elapsed = div(now - deadline, period)
          rate = if elapsed == 0, do: pending, else: 0
          next = deadline + (elapsed + 1) * period
          {%{object | pulse_rate: rate}, %{window | deadline: next, pulses: pulses}}

        %{period: ^period, pulses: pending} ->
          {object, %{window | pulses: pending + pulses}}

        _new_window ->
          measured =
            if previous && previous.out_of_service, do: %{object | pulse_rate: 0}, else: object

          {measured, %{period: period, deadline: now + period, pulses: pulses}}
      end
    else
      {object, nil}
    end
  end

  @spec update_logging(t(), execution_state() | nil, Context.t()) ::
          {:ok, object :: t(), logging :: logging_state() | nil} | {:error, term()}
  defp update_logging(object, previous, context) do
    if has_property?(object, :logging_record) or has_property?(object, :logging_object) do
      with {:ok, object, logging} <- logging_baseline(object, previous) do
        logging = track_logging(object, logging, previous, context)

        if qualified_read?(object, context) do
          acquire_record(object, logging, context)
        else
          {:ok, object, logging}
        end
      end
    else
      {:ok, object, nil}
    end
  end

  @spec logging_baseline(t(), execution_state() | nil) ::
          {:ok, object :: t(), logging :: logging_state()} | {:error, term()}
  defp logging_baseline(object, previous) do
    case previous do
      %{logging: %{reader: reader} = logging} when reader == object.logging_object ->
        {:ok, object, logging}

      _new_logging ->
        record = [starting_record()]

        result =
          if has_property?(object, :logging_record),
            do: update_property(object, :logging_record, record),
            else: add_property(object, :logging_record, record)

        with {:ok, initialized} <- result do
          {:ok, initialized,
           %{reader: object.logging_object, acquired: false, accumulated: 0, status: :normal}}
        end
    end
  end

  @spec track_logging(t(), logging_state(), execution_state() | nil, Context.t()) ::
          logging_state()
  defp track_logging(object, logging, previous, context) do
    adjustment = Context.written_property(context) == :value_set

    delta =
      cond do
        is_nil(previous) or adjustment ->
          0

        previous.out_of_service and not object.out_of_service ->
          object.present_value - previous.retained_count

        true ->
          object.present_value - previous.present_value
      end

    status =
      cond do
        object.reliability not in [nil, :no_fault_detected] or logging.status == :failed ->
          :failed

        context.trigger == :clock_change or logging.status == :abnormal ->
          :abnormal

        adjustment or logging.status == :recovered ->
          :recovered

        true ->
          :normal
      end

    %{logging | accumulated: modulo_count(object, logging.accumulated + delta), status: status}
  end

  @spec qualified_read?(t(), Context.t()) :: boolean()
  defp qualified_read?(object, context)

  defp qualified_read?(object, %Context{
         trigger: {:property_read, property, nil},
         options: options
       }) do
    property_name(property) == :logging_record and
      (is_nil(object.logging_object) or
         object.logging_object == Keyword.get(options, :reader_identifier))
  end

  defp qualified_read?(_object, _context), do: false

  @spec acquire_record(t(), logging_state(), Context.t()) ::
          {:ok, object :: t(), logging :: logging_state()} | {:error, term()}
  defp acquire_record(object, logging, context) do
    with {:ok, timestamp} <- timestamp(context) do
      status = if logging.acquired, do: logging.status, else: :starting
      accumulated = if status in [:starting, :failed], do: 0, else: logging.accumulated

      record = %AccumulatorRecord{
        timestamp: timestamp,
        present_value: object.present_value,
        accumulated_value: accumulated,
        status: status
      }

      with {:ok, updated} <- update_property(object, :logging_record, [record]) do
        {:ok, updated, %{logging | acquired: true, accumulated: 0, status: :normal}}
      end
    end
  end

  @spec starting_record() :: AccumulatorRecord.t()
  defp starting_record() do
    %AccumulatorRecord{
      timestamp: ObjectsMacro.get_default_bacnet_datetime(),
      present_value: 0,
      accumulated_value: 0,
      status: :starting
    }
  end

  @spec timestamp(Context.t()) :: {:ok, BACnetDateTime.t()} | {:error, :invalid_wall_time}
  defp timestamp(context) do
    if context.now.year in 1900..2154,
      do: {:ok, BACnetDateTime.from_datetime(context.now)},
      else: {:error, :invalid_wall_time}
  end

  @spec modulo_count(t(), integer()) :: non_neg_integer()
  defp modulo_count(object, count), do: Integer.mod(count, object.max_present_value + 1)

  @spec property_name(Constants.property_identifier() | non_neg_integer()) ::
          Constants.property_identifier() | nil
  defp property_name(property)

  defp property_name(property) when is_integer(property),
    do: Constants.by_value(:property_identifier, property, nil)

  defp property_name(property), do: property

  @spec reconcile_reliability(t(), Context.t()) ::
          {:ok, t(),
           %{physical_reliability: reliability_value(), manual_reliability: reliability_value()}}
          | {:error, term()}
  defp reconcile_reliability(object, context) do
    previous = Context.previous_state(context)

    if has_property?(object, :reliability) do
      physical =
        cond do
          not object.out_of_service and
              (Context.written_property(context) == :reliability or is_nil(previous)) ->
            object.reliability

          previous ->
            previous.physical_reliability

          true ->
            nil
        end

      manual =
        cond do
          not object.out_of_service ->
            nil

          is_nil(previous) or Context.written_property(context) == :reliability ->
            object.reliability

          previous.out_of_service ->
            previous.manual_reliability

          true ->
            nil
        end

      base =
        if not object.out_of_service and not is_nil(physical),
          do: physical,
          else: object.reliability

      value =
        if object.reliability_evaluation_inhibit,
          do: manual || :no_fault_detected,
          else: base

      with {:ok, updated} <- update_property(object, :reliability, value) do
        {:ok, updated, %{physical_reliability: physical, manual_reliability: manual}}
      end
    else
      with {:ok, updated} <-
             update_property(object, :status_flags, %{object.status_flags | fault: false}) do
        {:ok, updated, %{physical_reliability: nil, manual_reliability: nil}}
      end
    end
  end
end
