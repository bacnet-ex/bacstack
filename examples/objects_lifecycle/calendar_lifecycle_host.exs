defmodule BACnet.Examples.CalendarLifecycleHost do
  @moduledoc """
  Example application host for one Calendar.

  Here the host is the application component that owns the Calendar and drives
  its lifecycle. `BACnet.Protocol.ObjectExecution.Lifecycle` documents the shared
  object execution host contract.

  The GenServer retains the execution result, serializes operations and manages
  the requested wall-clock timer. Load this file from IEx with
  `Code.require_file("examples/objects_lifecycle/calendar_lifecycle_host.exs")`.

  Starting the example accepts `:timezone` (default `"Etc/UTC"`), `:timezone_database`
  (default `Calendar.UTCOnlyTimeZoneDatabase`), an optional `:name`, and an optional
  `:clock` function returning `{device_local_datetime, monotonic_milliseconds}`.

  Synchronous operation errors are returned to the caller. A failed write
  preparation preserves the stored result. An execution error after write commit
  retains the accepted properties and returns `:execution_failed_after_commit`.
  Timer execution errors stop the host. The application reports clock changes
  through the example's clock-change operation.
  """

  use GenServer

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject

  @type clock :: (-> {wall_time :: DateTime.t(), monotonic_time_ms :: integer()})
  @type option ::
          {:timezone, String.t()}
          | {:timezone_database, module()}
          | {:clock, clock()}
          | {:name, GenServer.name()}

  @type t :: %__MODULE__{
          execution: Result.t(CalendarObject.t()),
          clock: clock(),
          timezone_database: module(),
          timer: reference() | nil,
          token: reference() | nil
        }

  @fields [:execution, :clock, :timezone_database, :timer, :token]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Starts the host and initializes the Calendar before accepting requests.
  """
  @spec start_link(CalendarObject.t(), [option()]) :: GenServer.on_start()
  def start_link(object, options \\ []) do
    GenServer.start_link(__MODULE__, {object, options}, Keyword.take(options, [:name]))
  end

  @doc """
  Refreshes and reads Present_Value using current supplied time.
  """
  @spec present_value(GenServer.server()) :: {:ok, boolean()} | {:error, term()}
  def present_value(server), do: GenServer.call(server, :present_value)

  @doc """
  Validates, commits and executes a property write, including same-value writes.
  """
  @spec write_property(GenServer.server(), atom(), term()) :: :ok | {:error, term()}
  def write_property(server, property, value),
    do: GenServer.call(server, {:write_property, property, value})

  @doc """
  Recalculates the Calendar after a change to the supplied clock.
  """
  @spec clock_changed(GenServer.server()) :: :ok | {:error, term()}
  def clock_changed(server), do: GenServer.call(server, :clock_changed)

  @doc """
  Returns the last stored result for inspection, without refreshing it.
  """
  @spec snapshot(GenServer.server()) :: Result.t(CalendarObject.t())
  def snapshot(server), do: GenServer.call(server, :snapshot)

  @impl GenServer
  @spec init({CalendarObject.t(), options :: [option()]}) :: {:ok, t()} | {:stop, term()}
  def init({object, options}) do
    timezone = Keyword.get(options, :timezone, "Etc/UTC")
    database = Keyword.get(options, :timezone_database, Calendar.UTCOnlyTimeZoneDatabase)

    clock =
      Keyword.get_lazy(options, :clock, fn ->
        fn -> {DateTime.now!(timezone, database), System.monotonic_time(:millisecond)} end
      end)

    state = %__MODULE__{
      execution: %Result{object: object, state: nil, next_execution: nil},
      clock: clock,
      timezone_database: database,
      timer: nil,
      token: nil
    }

    case execute_step(state, :initialization) do
      {:ok, initialized} -> {:ok, initialized}
      {:error, reason} -> {:stop, {:initialization_failed, reason}}
    end
  end

  @impl GenServer
  @spec handle_call(term(), GenServer.from(), t()) :: {:reply, reply :: term(), t()}
  def handle_call(request, from, state)

  def handle_call(:snapshot, _from, state), do: {:reply, state.execution, state}

  def handle_call(:present_value, _from, state) do
    case execute_step(state, {:property_read, :present_value, nil}) do
      {:ok, refreshed} ->
        value = CalendarObject.get_property(refreshed.execution.object, :present_value)
        {:reply, value, refreshed}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:clock_changed, _from, state) do
    case execute_step(state, :clock_change) do
      {:ok, refreshed} -> {:reply, :ok, refreshed}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:write_property, property, value}, _from, state) do
    object = state.execution.object
    context = context(state, {:property_write, property, nil, nil})

    with :ok <- check_writable(object, property),
         {:ok, candidate} <- CalendarObject.update_property(object, property, value),
         {:ok, prepared} <- Lifecycle.prepare_write(object, candidate, context) do
      # Commit the accepted property value before executing its post-write step.
      committed = %{state | execution: %{state.execution | object: prepared}}

      case Lifecycle.execute(prepared, context) do
        {:ok, result} ->
          {:reply, :ok, retain_result(committed, result)}

        {:error, reason} ->
          {:reply, {:error, {:execution_failed_after_commit, reason}}, committed}
      end
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  @spec handle_info(term(), t()) :: {:noreply, t()} | {:stop, reason :: term(), t()}
  def handle_info(message, state)

  def handle_info({:calendar_wakeup, token}, %{token: token} = state) when is_reference(token) do
    context = context(state, :timer)
    state = %{state | timer: nil, token: nil}

    if Wakeup.due?(state.execution.next_execution, context) do
      case Lifecycle.execute(state.execution.object, context) do
        {:ok, result} -> {:noreply, retain_result(state, result)}
        {:error, reason} -> {:stop, {:execution_failed, reason}, state}
      end
    else
      # A clock correction or early delivery can leave the deadline in the future.
      {:noreply, arm_wakeup(state)}
    end
  end

  # Cancellation can race with delivery. Only the current token may execute.
  def handle_info(_message, state), do: {:noreply, state}

  @impl GenServer
  @spec terminate(term(), t()) :: :ok
  def terminate(_reason, state) do
    cancel_timer(state.timer)
    :ok
  end

  @spec context(t(), Context.trigger()) :: Context.t()
  defp context(state, trigger) do
    {now, monotonic_time} = state.clock.()

    %Context{
      device_identifier: nil,
      now: now,
      timezone_database: state.timezone_database,
      monotonic_time: monotonic_time,
      trigger: trigger,
      state: state.execution.state,
      lookup_object: nil,
      read_property_multiple: nil,
      read_property: nil,
      write_property: nil,
      options: []
    }
  end

  @spec execute_step(t(), Context.trigger()) :: {:ok, t()} | {:error, term()}
  defp execute_step(state, trigger) do
    context = context(state, trigger)

    result =
      case trigger do
        {:property_read, _property, _index} ->
          Lifecycle.prepare_read(state.execution.object, context)

        _other ->
          Lifecycle.execute(state.execution.object, context)
      end

    case result do
      {:ok, result} -> {:ok, retain_result(state, result)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec retain_result(t(), Result.t(CalendarObject.t())) :: t()
  defp retain_result(state, result) do
    cancel_timer(state.timer)
    # Keep object, opaque runtime state and the replacement wakeup together.
    arm_wakeup(%{state | execution: result, timer: nil, token: nil})
  end

  @spec arm_wakeup(t()) :: t()
  defp arm_wakeup(state)

  defp arm_wakeup(%{execution: %Result{next_execution: nil}} = state), do: state

  defp arm_wakeup(%{execution: %Result{next_execution: %Wakeup{wall_time: deadline}}} = state)
       when not is_nil(deadline) do
    # Re-sample after execution, so calculation time is not added to the delay.
    {now, _monotonic_time} = state.clock.()
    delay_us = max(DateTime.diff(deadline, now, :microsecond), 0)
    delay_ms = div(delay_us + 999, 1000)
    token = make_ref()
    timer = Process.send_after(self(), {:calendar_wakeup, token}, delay_ms)
    %{state | timer: timer, token: token}
  end

  @spec cancel_timer(reference() | nil) :: :ok
  defp cancel_timer(timer)

  defp cancel_timer(nil), do: :ok

  defp cancel_timer(timer) do
    Process.cancel_timer(timer)
    :ok
  end

  @spec check_writable(CalendarObject.t(), atom()) :: :ok | {:error, term()}
  defp check_writable(object, property) do
    cond do
      not CalendarObject.has_property?(object, property) ->
        {:error, {:unknown_property, property}}

      not CalendarObject.property_writable?(object, property) ->
        {:error, {:write_access_denied, property}}

      true ->
        :ok
    end
  end
end
