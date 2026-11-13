# Run from the repository root: mix run examples/objects_lifecycle/averaging_lifecycle.exs
defmodule BACnet.Examples.AveragingLifecycle do
  @moduledoc """
  Finite Averaging walkthrough with retained results and controlled clocks.

  Local reads use an in-memory AnalogValue. Remote reads construct a ReadProperty request
  and simulate its response. No network traffic or sleeping is involved. A running host
  needs the timer integration described by `BACnet.Protocol.ObjectExecution.Lifecycle`.
  """

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.AnalogValue
  alias BACnet.Protocol.ObjectTypes.Averaging
  alias BACnet.Protocol.Services.ReadProperty

  @now ~U[2026-11-09 08:00:00Z]

  @spec run() :: :ok
  def run() do
    {:ok, source} = AnalogValue.create(2, "Measured temperature", %{present_value: 10.0})

    {:ok, object} =
      Averaging.create(1, "Three-second statistics", %{
        object_property_reference: reference(),
        window_interval: 3,
        window_samples: 3,
        variance_value: :NaN
      })

    {:ok, store} =
      Agent.start_link(fn ->
        %{
          source: source,
          result: %Result{object: object, state: nil, next_execution: nil},
          source_error: nil,
          remote_requests: []
        }
      end)

    try do
      {:ok, stored} = Lifecycle.execute(object, context(store, :initialization, 0))
      retain(store, stored)
      0 = stored.object.valid_samples
      1000 = stored.next_execution.monotonic_time
      show(store, "Initialized - first sample due after one second")

      :ok = timer(store, 999)
      0 = snapshot(store).result.object.attempted_samples
      :ok = timer(store, 1000)
      10.0 = snapshot(store).result.object.average_value
      show(store, "First local acquisition")

      Agent.update(store, &%{&1 | source_error: :unavailable})
      :ok = timer(store, 2000)
      2 = snapshot(store).result.object.attempted_samples
      1 = snapshot(store).result.object.valid_samples
      10.0 = snapshot(store).result.object.average_value
      show(store, "Failed acquisition occupies a missed slot")

      source(store, 20.0)
      :ok = timer(store, 3000)
      source(store, 30.0)
      :ok = timer(store, 4000)
      25.0 = snapshot(store).result.object.average_value
      show(store, "Oldest valid value displaced - missed slot remains")

      source(store, 40.0)
      :ok = timer(store, 5000)
      3 = snapshot(store).result.object.valid_samples
      30.0 = snapshot(store).result.object.average_value
      show(store, "Missed slot aged out")

      # A same-value write still requires preparation, commit and execution.
      :ok = write(store, :window_samples, 3, 5000)
      0 = snapshot(store).result.object.valid_samples
      6000 = snapshot(store).result.next_execution.monotonic_time
      show(store, "Same-value configuration write cleared the window")

      source(store, 50.0)
      :ok = timer(store, 8500)
      3 = snapshot(store).result.object.attempted_samples
      1 = snapshot(store).result.object.valid_samples
      9000 = snapshot(store).result.next_execution.monotonic_time
      show(store, "Late timer - two missed slots and one current acquisition")

      remote = %{reference() | device_identifier: %ObjectIdentifier{type: :device, instance: 42}}
      :ok = write(store, :object_property_reference, remote, 8500)
      :ok = timer(store, 9500)
      21.5 = snapshot(store).result.object.average_value
      1 = length(snapshot(store).remote_requests)
      show(store, "Remote request encoded - simulated REAL response sampled")
      :ok
    after
      Agent.stop(store)
    end
  end

  @spec reference() :: DeviceObjectPropertyRef.t()
  defp reference() do
    %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: %ObjectIdentifier{type: :analog_value, instance: 2},
      property_identifier: :present_value,
      property_array_index: nil
    }
  end

  @spec context(pid(), Context.trigger(), integer()) :: Context.t()
  defp context(store, trigger, milliseconds) do
    Context.new(trigger,
      now: DateTime.add(@now, milliseconds, :millisecond),
      monotonic_time: milliseconds,
      state: snapshot(store).result.state,
      read_property: &read(store, &1)
    )
  end

  @spec read(pid(), DeviceObjectPropertyRef.t()) :: {:ok, term()} | {:error, term()}
  defp read(store, reference)

  defp read(store, %DeviceObjectPropertyRef{device_identifier: nil} = ref) do
    data = snapshot(store)

    cond do
      data.source_error ->
        {:error, data.source_error}

      ref.object_identifier != AnalogValue.get_object_identifier(data.source) ->
        {:error, :unknown_object}

      not is_nil(ref.property_array_index) ->
        {:error, :property_is_not_an_array}

      true ->
        AnalogValue.get_property(data.source, ref.property_identifier)
    end
  end

  defp read(store, %DeviceObjectPropertyRef{} = ref) do
    request = %ReadProperty{
      object_identifier: ref.object_identifier,
      property_identifier: ref.property_identifier,
      property_array_index: ref.property_array_index
    }

    {:ok, apdu} = ReadProperty.to_apdu(request, [])

    Agent.update(
      store,
      &%{&1 | remote_requests: [{ref.device_identifier, apdu} | &1.remote_requests]}
    )

    {:ok, Encoding.create!({:real, 21.5})}
  end

  @spec timer(pid(), integer()) :: :ok | {:error, term()}
  defp timer(store, milliseconds) do
    stored = snapshot(store).result
    ctx = context(store, :timer, milliseconds)

    if Wakeup.due?(stored.next_execution, ctx) do
      with {:ok, result} <- Lifecycle.execute(stored.object, ctx) do
        retain(store, result)
      end
    else
      :ok
    end
  end

  @spec write(pid(), atom(), term(), integer()) :: :ok | {:error, term()}
  defp write(store, property, value, milliseconds) do
    stored = snapshot(store).result
    ctx = context(store, {:property_write, property, nil, nil}, milliseconds)

    with {:ok, candidate} <- Averaging.update_property(stored.object, property, value),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      # Commit the accepted candidate while retaining state and scheduling information.
      retain(store, %{stored | object: prepared})
      with {:ok, result} <- Lifecycle.execute(prepared, ctx), do: retain(store, result)
    end
  end

  @spec source(pid(), float()) :: :ok
  defp source(store, value) do
    {:ok, object} = AnalogValue.update_property(snapshot(store).source, :present_value, value)
    Agent.update(store, &%{&1 | source: object, source_error: nil})
  end

  @spec retain(pid(), Result.t()) :: :ok
  defp retain(store, result), do: Agent.update(store, &%{&1 | result: result})

  @spec snapshot(pid()) :: map()
  defp snapshot(store), do: Agent.get(store, & &1)

  @spec show(pid(), String.t()) :: :ok
  defp show(store, label) do
    object = snapshot(store).result.object

    IO.puts(
      "#{label}: attempts=#{object.attempted_samples}, valid=#{object.valid_samples}, " <>
        "min=#{inspect(object.min_value)}, mean=#{inspect(object.average_value)}, max=#{inspect(object.max_value)}"
    )
  end
end

:ok = BACnet.Examples.AveragingLifecycle.run()
