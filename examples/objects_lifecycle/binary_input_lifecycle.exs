# Run from the repository root: mix run examples/objects_lifecycle/binary_input_lifecycle.exs
defmodule BACnet.Examples.BinaryInputLifecycle do
  @moduledoc """
  Finite Binary Input walkthrough using supplied samples, clocks and retained results.

  The host adapter is represented by explicit sample/reliability calls. No processes,
  hardware I/O or network traffic are started. A running host needs to serialize those
  operations and service the requested wakeups as described by
  `BACnet.Protocol.ObjectExecution.Lifecycle`.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectTypes.BinaryInput

  @now ~U[2026-11-08 10:00:00Z]

  @spec run() :: :ok
  def run() do
    {:ok, object} =
      BinaryInput.create(40, "Door contact", %{
        interface_value: :undefined,
        reliability: :no_fault_detected,
        change_of_state_count: 0,
        elapsed_active_time: 0
      })

    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization, 0))
    show(stored, "Initialized - physical input unknown")

    {:ok, stored} = sample(stored, true, 100)
    true = stored.object.present_value
    1 = stored.object.change_of_state_count
    {:ok, stored} = write(stored, :polarity, :reverse, 200)
    false = stored.object.present_value
    false = stored.object.interface_value
    2 = stored.object.change_of_state_count
    show(stored, "Steady contact - polarity edit changed the logical value")

    {:ok, stored} = write(stored, :out_of_service, true, 300)
    {:ok, stored} = write(stored, :present_value, true, 400)
    {:ok, stored} = sample(stored, true, 500)
    true = stored.object.present_value
    false = stored.object.interface_value
    show(stored, "OOS simulation is independent of the physical interface")

    {:ok, stored} = write(stored, :polarity, :normal, 600)
    true = stored.object.present_value
    3 = stored.object.change_of_state_count
    {:ok, stored} = sample(stored, nil, 700)
    :undefined = stored.object.interface_value
    true = stored.object.present_value
    show(stored, "Unknown sample marks Interface_Value unknown without a logical change")

    {:ok, stored} = sample(stored, false, 800)
    {:ok, stored} = write(stored, :reliability, :process_error, 900, :application_write)
    true = stored.object.status_flags.fault
    show(stored, "Local Reliability simulation while the physical input is decoupled")
    {:ok, stored} = timer(stored, 1400)
    1 = stored.object.elapsed_active_time
    {:ok, stored} = write(stored, :out_of_service, false, 1500)
    false = stored.object.present_value
    4 = stored.object.change_of_state_count
    show(stored, "Return to service reconciled the retained sample")

    {:ok, stored} = write(stored, :reliability, :process_error, 1600, :application_write)
    true = stored.object.status_flags.fault
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, true, 1700)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = write(stored, :reliability, :communication_failure, 1800, :application_write)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, false, 1900)
    :communication_failure = stored.object.reliability
    show(stored, "Latest physical reliability restored after inhibition")

    {:ok, stored} = write(stored, :change_of_state_count, 0, 2000)
    {:ok, stored} = write(stored, :elapsed_active_time, 0, 2100)
    0 = stored.object.change_of_state_count
    0 = stored.object.elapsed_active_time
    {:error, :write_access_denied} = write(stored, :present_value, true, 2200)
    show(stored, "Totals reset - BACnet value writes remain protected in service")
    :ok
  end

  @spec context(Result.t() | nil, Context.trigger(), integer()) :: Context.t()
  defp context(stored, trigger, milliseconds) do
    Context.new(trigger,
      now: DateTime.add(@now, milliseconds, :millisecond),
      monotonic_time: milliseconds,
      state: if(stored, do: stored.state)
    )
  end

  @spec sample(Result.t(BinaryInput.t()), boolean() | nil, integer()) ::
          {:ok, Result.t(BinaryInput.t())} | {:error, term()}
  defp sample(stored, raw, milliseconds) do
    ctx = context(stored, {:application_write, :present_value, nil, nil}, milliseconds)

    with {:ok, candidate} <- BinaryInput.set_input(stored.object, raw),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      Lifecycle.execute(prepared, ctx)
    end
  end

  @spec write(
          Result.t(BinaryInput.t()),
          atom(),
          term(),
          integer(),
          :property_write | :application_write
        ) :: {:ok, Result.t(BinaryInput.t())} | {:error, term()}
  defp write(stored, property, value, milliseconds, source \\ :property_write) do
    ctx = context(stored, {source, property, nil, nil}, milliseconds)

    with {:ok, candidate} <- BinaryInput.update_property(stored.object, property, value),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      Lifecycle.execute(prepared, ctx)
    end
  end

  @spec timer(Result.t(BinaryInput.t()), integer()) ::
          {:ok, Result.t(BinaryInput.t())} | {:error, term()}
  defp timer(stored, milliseconds) do
    ctx = context(stored, :timer, milliseconds)

    if is_struct(stored.next_execution, Wakeup) and Wakeup.due?(stored.next_execution, ctx),
      do: Lifecycle.execute(stored.object, ctx),
      else: {:ok, stored}
  end

  @spec show(Result.t(BinaryInput.t()), String.t()) :: :ok
  defp show(stored, label) do
    IO.inspect(
      %{
        present_value: stored.object.present_value,
        interface_value: stored.object.interface_value,
        polarity: stored.object.polarity,
        out_of_service: stored.object.out_of_service,
        reliability: stored.object.reliability,
        transitions: stored.object.change_of_state_count,
        active_seconds: stored.object.elapsed_active_time,
        next_execution: stored.next_execution
      },
      label: label
    )

    :ok
  end
end

BACnet.Examples.BinaryInputLifecycle.run()
