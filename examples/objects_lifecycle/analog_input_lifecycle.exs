# Run from the repository root: mix run examples/objects_lifecycle/analog_input_lifecycle.exs
defmodule BACnet.Examples.AnalogInputLifecycle do
  @moduledoc """
  Finite Analog Input walkthrough with supplied engineering readings and retained results.

  Physical observations use `BACnet.Protocol.ObjectTypes.AnalogInput.set_input/2` so a
  selected Interface_Value can update during simulation without changing Present_Value. The automatic-report helper
  suppresses hardware Reliability reports while out of service. Explicit local simulation
  uses the same application origin but bypasses that helper deliberately.
  A running host needs to serialize operations and deliver current readings/status on
  resumption - see `BACnet.Protocol.ObjectExecution.Lifecycle`. No sensor, process, timer
  or network operation is started by this example.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.AnalogInput

  @now ~U[2026-11-08 10:00:00Z]

  @spec run() :: :ok
  def run() do
    {:ok, object} =
      AnalogInput.create(50, "Room temperature", %{
        present_value: 21.5,
        interface_value: :undefined,
        units: :degrees_celsius,
        update_interval: 100,
        reliability: :no_fault_detected
      })

    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
    {:ok, stored} = automatic_report(stored, :present_value, 22.0)
    22.0 = stored.object.present_value
    22.0 = stored.object.interface_value
    {:error, :write_access_denied} = write(stored, :present_value, 30.0)
    show(stored, "In-service reading - BACnet value writes are rejected")

    {:ok, stored} = write(stored, :out_of_service, true)
    {:ok, stored} = write(stored, :present_value, 30.0, :application_write)
    {:ok, stored} = write(stored, :reliability, :process_error, :application_write)
    true = stored.object.status_flags.fault
    latest = %{present_value: 23.0, reliability: :no_fault_detected}
    {:ok, stored} = automatic_report(stored, :present_value, latest.present_value)
    30.0 = stored.object.present_value
    23.0 = stored.object.interface_value
    {:ok, stored} = automatic_report(stored, :present_value, :undefined)
    30.0 = stored.object.present_value
    :undefined = stored.object.interface_value
    {:ok, stored} = automatic_report(stored, :present_value, latest.present_value)
    {:ok, unchanged} = automatic_report(stored, :reliability, latest.reliability)
    ^stored = unchanged

    show(
      stored,
      "Simulation preserves Present_Value while Interface_Value tracks the physical input"
    )

    {:ok, stored} = write(stored, :present_value, 31.0)
    31.0 = stored.object.present_value
    23.0 = stored.object.interface_value
    {:ok, stored} = write(stored, :out_of_service, false)
    31.0 = stored.object.present_value
    {:ok, stored} = automatic_report(stored, :present_value, latest.present_value)
    {:ok, stored} = automatic_report(stored, :reliability, latest.reliability)
    23.0 = stored.object.present_value
    23.0 = stored.object.interface_value
    false = stored.object.status_flags.fault
    show(stored, "Current driver observations supplied before exposing the live reading")

    {:ok, stored} = automatic_report(stored, :reliability, :no_sensor)
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, true)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = automatic_report(stored, :reliability, :communication_failure)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, false)
    :communication_failure = stored.object.reliability
    show(stored, "Inhibition retains the latest in-service hardware report")

    {:ok, stored} = write(stored, :out_of_service, true)
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, true)
    {:ok, stored} = write(stored, :reliability, :process_error, :application_write)
    :process_error = stored.object.reliability

    {:ok, stored} =
      Lifecycle.prepare_read(
        stored.object,
        context(stored, {:property_read, :present_value, nil})
      )

    {:ok, 23.0} = AnalogInput.get_property(stored.object, :present_value)
    nil = stored.next_execution
    show(stored, "Local Reliability simulation remains available while inhibited")
    :ok
  end

  @spec context(Result.t(AnalogInput.t()) | nil, Context.trigger()) :: Context.t()
  defp context(stored, trigger) do
    Context.new(trigger, now: @now, monotonic_time: 0, state: if(stored, do: stored.state))
  end

  @spec write(Result.t(AnalogInput.t()), atom(), term(), :property_write | :application_write) ::
          {:ok, Result.t(AnalogInput.t())} | {:error, term()}
  defp write(stored, property, value, source \\ :property_write) do
    ctx = context(stored, {source, property, nil, nil})

    with {:ok, candidate} <- AnalogInput.update_property(stored.object, property, value),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      stored = %{stored | object: prepared}
      Lifecycle.execute(stored.object, ctx)
    end
  end

  @spec sample(Result.t(AnalogInput.t()), term()) ::
          {:ok, Result.t(AnalogInput.t())} | {:error, term()}
  defp sample(stored, value) do
    ctx = context(stored, {:application_write, :present_value, nil, nil})

    with {:ok, candidate} <- AnalogInput.set_input(stored.object, value),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      stored = %{stored | object: prepared}
      Lifecycle.execute(stored.object, ctx)
    end
  end

  @spec automatic_report(Result.t(AnalogInput.t()), :present_value | :reliability, term()) ::
          {:ok, Result.t(AnalogInput.t())} | {:error, term()}
  defp automatic_report(stored, property, value)

  defp automatic_report(stored, :present_value, value), do: sample(stored, value)

  defp automatic_report(stored, :reliability, value) do
    if stored.object.out_of_service,
      do: {:ok, stored},
      else: write(stored, :reliability, value, :application_write)
  end

  @spec show(Result.t(AnalogInput.t()), String.t()) :: :ok
  defp show(stored, label) do
    IO.inspect(
      Map.take(stored.object, [:present_value, :interface_value, :out_of_service, :reliability]),
      label: label
    )

    :ok
  end
end

BACnet.Examples.AnalogInputLifecycle.run()
