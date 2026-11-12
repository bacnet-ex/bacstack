# Run from the repository root: mix run examples/objects_lifecycle/command_lifecycle.exs
defmodule BACnet.Examples.CommandLifecycle do
  @moduledoc """
  Finite Command walkthrough with application-owned storage and controlled clock samples.

  Local writes apply to an in-memory BinaryOutput. Remote writes construct a WriteProperty
  request and simulate its result - no network traffic is sent. A running application needs
  the timer and ownership integration described by `BACnet.Protocol.ObjectExecution.Lifecycle`.
  """

  alias BACnet.Protocol.ActionCommand
  alias BACnet.Protocol.ActionList
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.BinaryOutput
  alias BACnet.Protocol.ObjectTypes.Command
  alias BACnet.Protocol.Services.WriteProperty

  @now ~U[2026-11-09 08:00:00Z]

  @spec run() :: :ok
  def run() do
    on = Encoding.create!({:enumerated, 1})
    null = Encoding.create!({:null, nil})
    {:ok, output} = BinaryOutput.create(2, "Lighting")

    list = %ActionList{
      actions: [
        action(on, nil, 2, false),
        action(on, %ObjectIdentifier{type: :device, instance: 42}, nil, true),
        action(null, nil, nil, false)
      ]
    }

    {:ok, object} =
      Command.create(1, "Occupied scene", %{
        action: BACnetArray.from_list([list]),
        action_text: BACnetArray.from_list(["Lights and remote scene"])
      })

    {:ok, store} =
      Agent.start_link(fn ->
        %{
          command: %Result{object: object, state: nil, next_execution: nil},
          output: %Result{object: output, state: nil, next_execution: nil},
          remote_failure: false,
          remote_requests: []
        }
      end)

    try do
      {:ok, output_result} =
        Lifecycle.execute(
          output,
          context(store, snapshot(store).output, :initialization, 0)
        )

      Agent.update(store, &%{&1 | output: output_result})

      {:ok, initialized} =
        Lifecycle.execute(object, context(store, snapshot(store).command, :initialization, 0))

      retain(store, initialized)
      false = snapshot(store).output.object.present_value
      show(store, "Initialized without running a sequence")

      :ok = write_command(store, 1, 0)
      true = snapshot(store).output.object.present_value
      2000 = snapshot(store).command.next_execution.monotonic_time
      true = snapshot(store).command.object.in_process
      show(store, "First write succeeded - waiting two seconds")

      before_rejection = snapshot(store).command
      {:error, :busy} = write_command(store, 1, 0)
      ^before_rejection = snapshot(store).command
      :ok = timer(store, 1999)
      [] = snapshot(store).remote_requests
      show(store, "Busy write rejected and early timer leaves the request pending")

      :ok = timer(store, 2000)
      false = snapshot(store).output.object.present_value
      true = snapshot(store).command.object.all_writes_successful
      show(store, "Deadline reached - remote write encoded and local priority relinquished")

      :ok = write_command(store, 1, 2000)
      4000 = snapshot(store).command.next_execution.monotonic_time
      :ok = timer(store, 4000)
      2 = length(snapshot(store).remote_requests)
      show(store, "Same-value write ran the sequence again")

      Agent.update(store, &%{&1 | remote_failure: true})
      :ok = write_command(store, 1, 4000)
      :ok = timer(store, 6000)
      true = snapshot(store).output.object.present_value
      false = snapshot(store).command.object.all_writes_successful
      false = snapshot(store).command.object.in_process
      [true, false, false] = success_flags(snapshot(store).command.object)
      show(store, "Simulated remote failure stopped the list - earlier local write remains")
      :ok
    after
      Agent.stop(store)
    end
  end

  @spec action(Encoding.t(), ObjectIdentifier.t() | nil, non_neg_integer() | nil, boolean()) ::
          ActionCommand.t()
  defp action(value, device, delay, quit) do
    %ActionCommand{
      device_identifier: device,
      object_identifier: %ObjectIdentifier{type: :binary_output, instance: 2},
      property_identifier: :present_value,
      property_array_index: nil,
      property_value: value,
      priority: 8,
      post_delay: delay,
      quit_on_failure: quit,
      write_successful: false
    }
  end

  @spec snapshot(pid()) :: map()
  defp snapshot(store), do: Agent.get(store, & &1)

  @spec retain(pid(), Result.t()) :: :ok
  defp retain(store, result), do: Agent.update(store, &%{&1 | command: result})

  @spec context(pid(), Result.t(), Context.trigger(), integer()) :: Context.t()
  defp context(store, stored, trigger, monotonic) do
    Context.new(trigger,
      now: DateTime.add(@now, monotonic, :millisecond),
      monotonic_time: monotonic,
      state: stored.state,
      write_property: fn reference, value, priority ->
        write_target(store, reference, value, priority, monotonic)
      end
    )
  end

  @spec write_command(pid(), non_neg_integer(), integer()) :: :ok | {:error, term()}
  defp write_command(store, code, monotonic) do
    stored = snapshot(store).command
    trigger = {:property_write, :present_value, nil, nil}
    ctx = context(store, stored, trigger, monotonic)

    with {:ok, candidate} <- Command.update_property(stored.object, :present_value, code),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      retain(store, %{stored | object: prepared})
      execute_step(store, trigger, monotonic)
    end
  end

  @spec execute_step(pid(), Context.trigger(), integer()) :: :ok | {:error, term()}
  defp execute_step(store, trigger, monotonic) do
    stored = snapshot(store).command

    with {:ok, result} <-
           Lifecycle.execute(stored.object, context(store, stored, trigger, monotonic)) do
      retain(store, result)

      if result.next_execution == :immediate,
        do: execute_step(store, :continuation, monotonic),
        else: :ok
    end
  end

  @spec timer(pid(), integer()) :: :ok | {:error, term()}
  defp timer(store, monotonic) do
    stored = snapshot(store).command

    if Wakeup.due?(stored.next_execution, context(store, stored, :timer, monotonic)),
      do: execute_step(store, :timer, monotonic),
      else: :ok
  end

  @spec write_target(pid(), DeviceObjectPropertyRef.t(), Encoding.t(), 1..16 | nil, integer()) ::
          :ok | {:error, term()}
  defp write_target(store, reference, value, priority, monotonic)

  defp write_target(
         store,
         %DeviceObjectPropertyRef{device_identifier: nil} = reference,
         value,
         priority,
         monotonic
       ) do
    stored = snapshot(store).output
    object = stored.object
    identifier = BinaryOutput.get_object_identifier(object)

    cond do
      reference.object_identifier != identifier ->
        {:error, :unknown_object}

      reference.property_identifier != :present_value or
          not is_nil(reference.property_array_index) ->
        {:error, :unknown_property}

      is_nil(priority) ->
        {:error, :priority_required}

      priority == 6 ->
        {:error, :write_access_denied}

      true ->
        with {:ok, native} <- native_value(identifier, value),
             {:ok, candidate} <- BinaryOutput.set_priority(object, priority, native) do
          ctx =
            Context.new({:property_write, :present_value, nil, priority},
              now: DateTime.add(@now, monotonic, :millisecond),
              monotonic_time: monotonic,
              state: stored.state
            )

          with {:ok, prepared} <- Lifecycle.prepare_write(object, candidate, ctx),
               {:ok, updated} <- Lifecycle.execute(prepared, ctx) do
            Agent.update(store, &%{&1 | output: updated})
          end
        end
    end
  end

  defp write_target(store, reference, value, priority, _monotonic) do
    {:ok, request} =
      WriteProperty.to_apdu(
        %WriteProperty{
          object_identifier: reference.object_identifier,
          property_identifier: reference.property_identifier,
          property_array_index: reference.property_array_index,
          property_value: value,
          priority: priority
        },
        []
      )

    Agent.update(store, &%{&1 | remote_requests: [request | &1.remote_requests]})
    if snapshot(store).remote_failure, do: {:error, :simulated_timeout}, else: :ok
  end

  @spec native_value(ObjectIdentifier.t(), Encoding.t()) :: {:ok, term()} | {:error, term()}
  defp native_value(identifier, value)

  defp native_value(_identifier, %Encoding{type: :null}), do: {:ok, nil}

  defp native_value(identifier, value),
    do: ObjectsUtility.cast_property_to_value(identifier, :present_value, value)

  @spec success_flags(Command.t()) :: [boolean()]
  defp success_flags(object) do
    {:ok, list} = BACnetArray.get_item(object.action, 1)
    Enum.map(list.actions, & &1.write_successful)
  end

  @spec show(pid(), String.t()) :: :ok
  defp show(store, label) do
    state = snapshot(store)

    IO.puts(
      "#{label}: busy=#{state.command.object.in_process}, all_success=#{state.command.object.all_writes_successful}, flags=#{inspect(success_flags(state.command.object))}, lighting=#{state.output.object.present_value}"
    )
  end
end

BACnet.Examples.CommandLifecycle.run()
