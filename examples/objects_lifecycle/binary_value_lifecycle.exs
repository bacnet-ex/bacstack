# Run from the repository root: mix run examples/objects_lifecycle/binary_value_lifecycle.exs
defmodule BACnet.Examples.BinaryValueLifecycle do
  @moduledoc """
  Finite Binary Value walkthrough using retained results and supplied clocks.

  No process, sleeping or network operations are needed for the object algorithm.
  A running host needs to serialize writes and service the returned wakeups - see
  `BACnet.Protocol.ObjectExecution.Lifecycle` for timer ownership and arming examples.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectTypes.BinaryValue

  @now ~U[2026-11-08 10:00:00Z]

  @spec run() :: :ok
  def run() do
    {:ok, object} =
      BinaryValue.create(20, "Ventilation enable", %{
        relinquish_default: false,
        min_on_time: 3,
        min_off_time: 2,
        change_of_state_count: 0,
        elapsed_active_time: 0
      })

    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization, 0))
    show(stored, "Initialized")

    {:ok, stored} = write(stored, :present_value, true, 100, 8)
    true = stored.object.priority_array.priority_6
    show(stored, "ACTIVE - minimum on time started")

    {:ok, stored} = write(stored, :present_value, false, 500, 8)
    true = stored.object.present_value
    false = stored.object.priority_array.priority_8
    show(stored, "INACTIVE command stored beneath the hold")

    {:ok, stored} = timer(stored, 1100)
    1 = stored.object.elapsed_active_time
    {:ok, stored} = timer(stored, 3100)
    false = stored.object.present_value
    2 = stored.object.change_of_state_count
    3 = stored.object.elapsed_active_time
    show(stored, "Hold expired - pending command became effective")

    {:ok, stored} = write(stored, :change_of_state_count, 0, 3200, nil)
    0 = stored.object.change_of_state_count
    show(stored, "Counter reset with its supplied wall timestamp")

    {:ok, stored} = write(stored, :out_of_service, true, 3300, nil)

    {:error, :out_of_service} =
      write(stored, :present_value, true, 3400, 8, :application_write)

    {:ok, stored} = write(stored, :present_value, true, 3500, 2)
    true = stored.object.present_value
    show(stored, "BACnet priority-2 write accepted while out of service")

    {:ok, plain} = BinaryValue.create(21, "Software flag", %{min_on_time: 2})
    {:ok, plain} = Lifecycle.execute(plain, context(nil, :initialization, 0))
    {:ok, plain} = write(plain, :present_value, true, 100, nil, :application_write)

    {:error, {:minimum_time_active, 2100}} =
      write(plain, :present_value, false, 500, nil, :application_write)

    {:ok, plain} = timer(plain, 2100)
    {:ok, plain} = write(plain, :present_value, false, 2100, nil, :application_write)
    false = plain.object.present_value
    show(plain, "Non-commandable conflicting write retried after expiry")
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
          Result.t(BinaryValue.t()),
          atom(),
          term(),
          integer(),
          1..16 | nil,
          :property_write | :application_write
        ) :: {:ok, Result.t(BinaryValue.t())} | {:error, term()}
  defp write(stored, property, value, milliseconds, priority, source \\ :property_write) do
    ctx = context(stored, {source, property, nil, priority}, milliseconds)

    candidate =
      if property == :present_value and BinaryValue.has_priority_array?(stored.object),
        do: BinaryValue.set_priority(stored.object, priority || 16, value),
        else: BinaryValue.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      # This example retains the returned result in the caller before any other operation.
      Lifecycle.execute(prepared, ctx)
    end
  end

  @spec timer(Result.t(BinaryValue.t()), integer()) ::
          {:ok, Result.t(BinaryValue.t())} | {:error, term()}
  defp timer(stored, milliseconds) do
    ctx = context(stored, :timer, milliseconds)

    if is_struct(stored.next_execution, Wakeup) and Wakeup.due?(stored.next_execution, ctx),
      do: Lifecycle.execute(stored.object, ctx),
      else: {:ok, stored}
  end

  @spec show(Result.t(BinaryValue.t()), String.t()) :: :ok
  defp show(stored, label) do
    IO.inspect(
      %{
        present_value: stored.object.present_value,
        transitions: Map.get(stored.object, :change_of_state_count),
        active_seconds: Map.get(stored.object, :elapsed_active_time),
        next_execution: stored.next_execution
      },
      label: label
    )

    :ok
  end
end

BACnet.Examples.BinaryValueLifecycle.run()
