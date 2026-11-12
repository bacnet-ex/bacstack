# Run from the repository root: mix run examples/objects_lifecycle/binary_output_lifecycle.exs
defmodule BACnet.Examples.BinaryOutputLifecycle do
  @moduledoc """
  Finite Binary Output walkthrough with retained lifecycle results and a simulated adapter.

  The adapter records its physical signal and holds it unchanged while out of service.
  Feedback is supplied separately. No network traffic, processes or timers are started.
  A running host needs to serialize operations and service requested wakeups as documented
  by `BACnet.Protocol.ObjectExecution.Lifecycle`.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectTypes.BinaryOutput

  @now ~U[2026-11-08 10:00:00Z]

  @typep host_state :: %{
           stored: Result.t(BinaryOutput.t()),
           physical_signal: boolean(),
           applications: non_neg_integer()
         }

  @spec run() :: :ok
  def run() do
    {:ok, object} =
      BinaryOutput.create(30, "Pump enable", %{
        polarity: :reverse,
        min_on_time: 3,
        min_off_time: 2,
        feedback_value: false,
        reliability: :no_fault_detected,
        change_of_state_count: 0,
        elapsed_active_time: 0
      })

    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization, 0))
    host = apply_output(%{stored: stored, physical_signal: false, applications: 0})
    true = host.physical_signal
    show(host, "INACTIVE with reverse polarity - physical signal is ON")

    {:ok, host} = write(host, :present_value, true, 100, 8)
    false = host.physical_signal
    false = host.stored.object.feedback_value
    show(host, "ACTIVE command - actual feedback remains independent")

    {:ok, host} = write(host, :polarity, :normal, 150, nil)
    true = host.physical_signal
    1 = host.stored.object.change_of_state_count
    show(host, "Polarity changed the signal without a logical transition")

    {:ok, host} = write(host, :feedback_value, true, 200, nil, :application_write)
    {:ok, host} = write(host, :present_value, false, 500, 8)
    true = host.stored.object.present_value
    false = host.stored.object.priority_array.priority_8
    show(host, "INACTIVE command retained beneath minimum on time")

    {:ok, host} = timer(host, 3100)
    false = host.physical_signal
    false = host.stored.object.present_value
    true = host.stored.object.feedback_value
    2 = host.stored.object.change_of_state_count
    3 = host.stored.object.elapsed_active_time
    show(host, "Hold expired - feedback still reports the separately supplied state")

    {:ok, host} = write(host, :out_of_service, true, 3200, nil)
    applications = host.applications

    {:error, :out_of_service} =
      write(host, :feedback_value, false, 3300, nil, :application_write)

    {:ok, host} = write(host, :reliability, :process_error, 3300, nil, :application_write)
    true = host.stored.object.status_flags.fault

    {:ok, host} = write(host, :present_value, true, 3400, 2, :application_write)
    true = host.stored.object.present_value
    false = host.physical_signal
    ^applications = host.applications
    show(host, "Out of service - local command accepted, adapter remains isolated")

    {:ok, host} = write(host, :feedback_value, false, 3500, nil)
    {:ok, host} = write(host, :change_of_state_count, 0, 3600, nil)
    {:ok, host} = write(host, :out_of_service, false, 3700, nil)
    true = host.physical_signal
    0 = host.stored.object.change_of_state_count
    show(host, "Return to service reapplies the current command")

    {:ok, modeled} = BinaryOutput.create(31, "Modeled output", %{}, auto_write_feedback: true)
    {:ok, stored} = Lifecycle.execute(modeled, context(nil, :initialization, 0))
    modeled_host = %{stored: stored, physical_signal: false, applications: 0}
    {:ok, modeled_host} = write(modeled_host, :present_value, true, 100, 8)
    true = modeled_host.stored.object.feedback_value

    {:error, :feedback_managed_automatically} =
      write(modeled_host, :feedback_value, false, 200, nil)

    show(modeled_host, "Automatic feedback models the command - no measured confirmation")
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

  @spec write(
          host_state(),
          atom(),
          term(),
          integer(),
          1..16 | nil,
          :property_write | :application_write
        ) :: {:ok, host_state()} | {:error, term()}
  defp write(host, property, value, milliseconds, priority, source \\ :property_write) do
    stored = host.stored
    ctx = context(stored, {source, property, nil, priority}, milliseconds)

    candidate =
      if property == :present_value,
        do: BinaryOutput.set_priority(stored.object, priority || 16, value),
        else: BinaryOutput.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx),
         {:ok, updated} <- Lifecycle.execute(prepared, ctx) do
      # Retain the complete result before applying its command to this example's adapter.
      {:ok, apply_output(%{host | stored: updated})}
    end
  end

  @spec timer(host_state(), integer()) :: {:ok, host_state()} | {:error, term()}
  defp timer(host, milliseconds) do
    stored = host.stored
    ctx = context(stored, :timer, milliseconds)

    if is_struct(stored.next_execution, Wakeup) and Wakeup.due?(stored.next_execution, ctx) do
      with {:ok, updated} <- Lifecycle.execute(stored.object, ctx) do
        {:ok, apply_output(%{host | stored: updated})}
      end
    else
      {:ok, host}
    end
  end

  @spec apply_output(host_state()) :: host_state()
  defp apply_output(host) do
    if host.stored.object.out_of_service do
      host
    else
      %{
        host
        | physical_signal: BinaryOutput.get_output(host.stored.object),
          applications: host.applications + 1
      }
    end
  end

  @spec show(host_state(), String.t()) :: :ok
  defp show(host, label) do
    IO.inspect(
      %{
        logical_command: host.stored.object.present_value,
        physical_signal: host.physical_signal,
        feedback: host.stored.object.feedback_value,
        out_of_service: host.stored.object.out_of_service,
        transitions: Map.get(host.stored.object, :change_of_state_count),
        active_seconds: Map.get(host.stored.object, :elapsed_active_time),
        next_execution: host.stored.next_execution
      },
      label: label
    )

    :ok
  end
end

BACnet.Examples.BinaryOutputLifecycle.run()
