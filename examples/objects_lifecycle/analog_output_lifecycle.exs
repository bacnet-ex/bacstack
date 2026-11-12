# Run from the repository root: mix run examples/objects_lifecycle/analog_output_lifecycle.exs
defmodule BACnet.Examples.AnalogOutputLifecycle do
  @moduledoc """
  Finite Analog Output walkthrough with a simulated adapter and retained lifecycle results.

  The adapter records requests without claiming that an actuator reached the requested value.
  It holds its last request while out of service. A running host needs to serialize operations,
  retain results and implement its chosen physical policy as described by
  `BACnet.Protocol.ObjectExecution.Lifecycle`. No process, timer or network I/O is started.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.AnalogOutput

  @typep adapter :: %{
           last_requested: ApplicationTags.ieee_float() | nil,
           requests: [ApplicationTags.ieee_float()]
         }

  @now ~U[2026-11-08 10:00:00Z]

  @spec run() :: :ok
  def run() do
    {:ok, object} =
      AnalogOutput.create(40, "Valve command", %{
        units: :percent,
        relinquish_default: 20.0,
        reliability: :no_output
      })

    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
    adapter = apply_command(stored, %{last_requested: nil, requests: []})
    20.0 = adapter.last_requested

    {:ok, stored} = write(stored, :present_value, 40.0, :property_write, 8)
    adapter = apply_command(stored, adapter)
    {:ok, stored} = write(stored, :present_value, 75.0)
    40.0 = stored.object.present_value
    75.0 = stored.object.priority_array.priority_16
    show(stored, adapter, "Priority 8 masks the stored priority-16 command")

    {:error, :write_access_denied} = AnalogOutput.set_priority(stored.object, 6, 50.0)
    {:ok, stored} = write(stored, :out_of_service, true)
    {:ok, stored} = write(stored, :present_value, 90.0, :application_write, 2)
    adapter = apply_command(stored, adapter)
    90.0 = stored.object.present_value
    40.0 = adapter.last_requested
    +0.0 = AnalogOutput.get_output(stored.object)
    40.0 = AnalogOutput.get_output(stored.object, adapter.last_requested)

    show(
      stored,
      adapter,
      "Simulation changes the command while the adapter holds its last request"
    )

    {:ok, stored} = write(stored, :reliability, :no_fault_detected, :application_write)
    :no_fault_detected = stored.object.reliability

    {:ok, stored} = write(stored, :reliability, :process_error)
    :process_error = stored.object.reliability
    {:ok, stored} = write(stored, :present_value, nil, :application_write, 2)
    {:ok, stored} = write(stored, :present_value, nil, :property_write, 8)
    75.0 = stored.object.present_value
    adapter = apply_command(stored, adapter)
    40.0 = adapter.last_requested

    {:ok, stored} = write(stored, :out_of_service, false)
    adapter = apply_command(stored, adapter)
    75.0 = adapter.last_requested
    :no_output = stored.object.reliability

    show(
      stored,
      adapter,
      "Returning to service reapplies the current command and retained hardware status"
    )

    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, true)
    {:ok, stored} = write(stored, :reliability, :communication_failure, :application_write)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, false)
    :communication_failure = stored.object.reliability
    show(stored, adapter, "Inhibition retains a physical report without running event algorithms")

    {:ok, stored} =
      Lifecycle.prepare_read(
        stored.object,
        context(stored, {:property_read, :present_value, nil})
      )

    {:ok, 75.0} = AnalogOutput.get_property(stored.object, :present_value)
    nil = stored.next_execution
    :ok
  end

  @spec context(Result.t(AnalogOutput.t()) | nil, Context.trigger()) :: Context.t()
  defp context(stored, trigger) do
    Context.new(trigger, now: @now, monotonic_time: 0, state: if(stored, do: stored.state))
  end

  @spec write(
          Result.t(AnalogOutput.t()),
          atom(),
          term(),
          :property_write | :application_write,
          1..16 | nil
        ) ::
          {:ok, Result.t(AnalogOutput.t())} | {:error, term()}
  defp write(stored, property, value, source \\ :property_write, priority \\ nil) do
    ctx = context(stored, {source, property, nil, priority})

    candidate =
      if property == :present_value,
        do: AnalogOutput.set_priority(stored.object, priority || 16, value),
        else: AnalogOutput.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      stored = %{stored | object: prepared}
      Lifecycle.execute(stored.object, ctx)
    end
  end

  @spec apply_command(Result.t(AnalogOutput.t()), adapter()) :: adapter()
  defp apply_command(stored, adapter) do
    if stored.object.out_of_service do
      adapter
    else
      requested = AnalogOutput.get_output(stored.object)
      %{adapter | last_requested: requested, requests: [requested | adapter.requests]}
    end
  end

  @spec show(Result.t(AnalogOutput.t()), adapter(), String.t()) :: :ok
  defp show(stored, adapter, label) do
    IO.inspect(
      %{
        command: stored.object.present_value,
        out_of_service: stored.object.out_of_service,
        reliability: stored.object.reliability,
        last_adapter_request: adapter.last_requested
      },
      label: label
    )

    :ok
  end
end

BACnet.Examples.AnalogOutputLifecycle.run()
