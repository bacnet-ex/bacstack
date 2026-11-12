# Run from the repository root: mix run examples/objects_lifecycle/multistate_value_lifecycle.exs
defmodule BACnet.Examples.MultistateValueLifecycle do
  @moduledoc """
  Finite walkthrough of an application mode with commandability and retained results.

  The variables stand for serialized host storage. A running host needs to retain each
  result and enforce service permissions - see `BACnet.Protocol.ObjectExecution.Lifecycle`.
  This example starts no process, timer, hardware or network operation.
  """

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.MultistateValue

  @now ~U[2026-11-08 10:00:00Z]

  @spec run() :: :ok
  def run() do
    {:ok, object} =
      MultistateValue.create(5, "Operating mode", %{
        number_of_states: 3,
        state_text: BACnetArray.from_list(["Off", "Low", "High"]),
        relinquish_default: 1,
        reliability: :no_fault_detected
      })

    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
    {:ok, stored} = write(stored, :present_value, 2, :application_write)
    {:ok, stored} = write(stored, :present_value, 3, :property_write, 8)
    3 = stored.object.present_value
    show(stored, "Priority 8 masks the application's priority 16 command")

    {:ok, stored} = write(stored, :out_of_service, true)
    {:error, :out_of_service} = write(stored, :present_value, 2, :application_write)
    {:ok, stored} = write(stored, :present_value, 1, :property_write, 8)
    1 = stored.object.present_value
    show(stored, "BACnet simulation continues while local value production is isolated")
    {:ok, stored} = write(stored, :out_of_service, false)
    {:ok, stored} = write(stored, :present_value, nil, :property_write, 8)
    2 = stored.object.present_value
    {:error, :write_access_denied} = write(stored, :present_value, 3, :property_write, 6)

    {:ok, stored} = write(stored, :number_of_states, 4, :application_write)
    ["Off", "Low", "High", ""] = BACnetArray.to_list(stored.object.state_text)
    {:ok, stored} = write(stored, :present_value, 4, :application_write)

    {:error, {:invalid_configuration, :present_value}} =
      write(stored, :number_of_states, 2, :application_write)

    4 = stored.object.number_of_states
    {:ok, stored} = write(stored, :present_value, 2, :application_write)
    {:ok, stored} = write(stored, :number_of_states, 2, :application_write)
    {:ok, stored} = write(stored, :state_text, BACnetArray.from_list(["Off", "Running"]))
    2 = stored.object.number_of_states
    show(stored, "Reconcile commands before shrinking the state set")

    {:ok, stored} = write(stored, :reliability, :process_error, :application_write)
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, true)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = write(stored, :reliability, :communication_failure, :application_write)
    :no_fault_detected = stored.object.reliability
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, false)
    :communication_failure = stored.object.reliability
    {:ok, stored} = write(stored, :reliability_evaluation_inhibit, true)
    {:ok, stored} = write(stored, :out_of_service, true)
    {:ok, stored} = write(stored, :reliability, :process_error, :application_write)
    :process_error = stored.object.reliability
    true = stored.object.status_flags.fault
    show(stored, "Explicit Reliability simulation remains available while inhibited")

    {:ok, stored} =
      Lifecycle.prepare_read(
        stored.object,
        context(stored, {:property_read, :present_value, nil})
      )

    {:ok, 2} = MultistateValue.get_property(stored.object, :present_value)
    nil = stored.next_execution
    {:ok, restarted} = Lifecycle.execute(stored.object, context(nil, :initialization))
    2 = restarted.object.present_value
    :process_error = restarted.object.reliability
    :ok
  end

  @spec context(Result.t(MultistateValue.t()) | nil, Context.trigger()) :: Context.t()
  defp context(stored, trigger) do
    Context.new(trigger, now: @now, monotonic_time: 0, state: if(stored, do: stored.state))
  end

  @spec write(
          Result.t(MultistateValue.t()),
          atom(),
          term(),
          :property_write | :application_write,
          1..16 | nil
        ) :: {:ok, Result.t(MultistateValue.t())} | {:error, term()}
  defp write(stored, property, value, source \\ :property_write, priority \\ nil) do
    ctx = context(stored, {source, property, nil, priority})

    candidate =
      if property == :present_value and MultistateValue.has_priority_array?(stored.object),
        do: MultistateValue.set_priority(stored.object, priority || 16, value),
        else: MultistateValue.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      stored = %{stored | object: prepared}
      Lifecycle.execute(stored.object, ctx)
    end
  end

  @spec show(Result.t(MultistateValue.t()), String.t()) :: :ok
  defp show(stored, label) do
    IO.inspect(
      Map.take(stored.object, [:present_value, :number_of_states, :out_of_service, :reliability]),
      label: label
    )

    :ok
  end
end

BACnet.Examples.MultistateValueLifecycle.run()
