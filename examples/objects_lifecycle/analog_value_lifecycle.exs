# Run from the repository root: mix run examples/objects_lifecycle/analog_value_lifecycle.exs
defmodule BACnet.Examples.AnalogValueLifecycle do
  @moduledoc """
  Finite Analog Value walkthrough using supplied writes and retained lifecycle results.

  The caller's variables represent host storage. A running application needs to serialize
  operations and retain each complete result as described by
  `BACnet.Protocol.ObjectExecution.Lifecycle`. No process, timer or network I/O is needed.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.AnalogValue

  @now ~U[2026-11-08 10:00:00Z]

  @spec run() :: :ok
  def run() do
    {:ok, object} =
      AnalogValue.create(30, "Room setpoint", %{
        present_value: 21.0,
        units: :degrees_celsius,
        reliability: :process_error
      })

    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
    {:ok, stored} = write(stored, :present_value, 22.0, :application_write)
    22.0 = stored.object.present_value
    nil = stored.next_execution
    show(stored, "Application supplied the non-commandable value")

    {:ok, candidate} = AnalogValue.add_property(stored.object, :relinquish_default, 19.0)
    ctx = context(stored, {:application_write, :relinquish_default, nil, nil})
    {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    stored = %{stored | object: prepared}
    {:ok, stored} = Lifecycle.execute(stored.object, ctx)
    19.0 = stored.object.present_value

    {:ok, stored} = write(stored, :present_value, 23.0, :property_write, 8)
    {:ok, stored} = write(stored, :present_value, 18.0)
    23.0 = stored.object.present_value
    18.0 = stored.object.priority_array.priority_16
    show(stored, "Priority 8 masks the stored priority-16 command")

    {:error, :write_access_denied} = AnalogValue.set_priority(stored.object, 6, 24.0)
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, true)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = write(stored, :reliability, :communication_failure, :application_write)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, false)
    :communication_failure = stored.object.reliability
    show(stored, "Disabling inhibition restores the latest supplied reliability")

    {:ok, stored} = write(stored, :out_of_service, true)
    {:error, :out_of_service} = write(stored, :present_value, 25.0, :application_write, 8)
    {:ok, stored} = write(stored, :present_value, nil, :property_write, 8)
    18.0 = stored.object.present_value
    {:ok, stored} = write(stored, :present_value, nil)
    19.0 = stored.object.present_value
    show(stored, "BACnet relinquishment still arbitrates while out of service")

    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, true)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = write(stored, :reliability, :no_sensor)
    :no_sensor = stored.object.reliability
    {:ok, stored} = write(stored, :out_of_service, false)
    :no_fault_detected = stored.object.reliability
    show(stored, "Returning to service masks inhibited reliability simulation")

    {:ok, stored} =
      Lifecycle.prepare_read(
        stored.object,
        context(stored, {:property_read, :present_value, nil})
      )

    {:ok, 19.0} = AnalogValue.get_property(stored.object, :present_value)
    nil = stored.next_execution
    :ok
  end

  @spec context(Result.t(AnalogValue.t()) | nil, Context.trigger()) :: Context.t()
  defp context(stored, trigger) do
    Context.new(trigger, now: @now, monotonic_time: 0, state: if(stored, do: stored.state))
  end

  @spec write(
          Result.t(AnalogValue.t()),
          atom(),
          term(),
          :property_write | :application_write,
          1..16 | nil
        ) ::
          {:ok, Result.t(AnalogValue.t())} | {:error, term()}
  defp write(stored, property, value, source \\ :property_write, priority \\ nil) do
    ctx = context(stored, {source, property, nil, priority})

    candidate =
      if property == :present_value and AnalogValue.has_priority_array?(stored.object),
        do: AnalogValue.set_priority(stored.object, priority || 16, value),
        else: AnalogValue.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      stored = %{stored | object: prepared}
      Lifecycle.execute(stored.object, ctx)
    end
  end

  @spec show(Result.t(AnalogValue.t()), String.t()) :: :ok
  defp show(stored, label) do
    IO.inspect(Map.take(stored.object, [:present_value, :out_of_service, :reliability]),
      label: label
    )

    :ok
  end
end

BACnet.Examples.AnalogValueLifecycle.run()
