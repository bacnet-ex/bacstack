defmodule BACnet.Test.Protocol.ObjectTypes.AveragingTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.AnalogValue
  alias BACnet.Protocol.ObjectTypes.Averaging
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  @moduletag :object_test
  @now ~U[2026-11-09 08:00:00Z]
  @reset_properties [
    :attempted_samples,
    :object_property_reference,
    :window_interval,
    :window_samples
  ]

  doctest Averaging

  test "default sample capacity is usable and computed properties are read-only" do
    {:ok, object} = Averaging.create(1, "Statistics", %{window_interval: 15})
    assert object.window_samples == 15
    assert :ok = Averaging.validate_execution(object, context(:initialization))

    for property <- [:min_value, :max_value, :average_value, :valid_samples] do
      refute Averaging.property_writable?(object, property)
    end

    assert Averaging.property_writable?(object, :attempted_samples)
    assert Averaging.property_writable?(object, :window_interval)
    assert Averaging.property_writable?(object, :window_samples)
  end

  test "initialization resets retained statistics and waits one sample period without I/O" do
    object =
      object(%{
        attempted_samples: 3,
        valid_samples: 3,
        min_value: 1.0,
        max_value: 5.0,
        average_value: 3.0,
        variance_value: 8.0
      })

    ctx =
      context(:initialization,
        monotonic_time: -5000,
        read_property: fn _reference -> flunk("early read") end
      )

    assert {:ok, initial} = Lifecycle.execute(object, ctx)
    assert_empty(initial.object)
    assert initial.next_execution.monotonic_time == -4000
    assert initial.next_execution.wall_time == nil
    assert initial.state.samples == []
  end

  test "rolling statistics use the latest attempts and population variance" do
    stored = initial()
    first = step(stored, 1000, 1)
    second = step(first, 2000, 3)
    third = step(second, 3000, 5)
    assert third.object.attempted_samples == 3
    assert third.object.valid_samples == 3
    assert third.object.min_value == 1.0
    assert third.object.max_value == 5.0
    assert third.object.average_value == 3.0
    assert third.object.variance_value == 2.67
    assert third.object.min_value_timestamp == timestamp(1000)
    assert third.object.max_value_timestamp == timestamp(3000)

    fourth = step(third, 4000, 7)
    assert fourth.object.attempted_samples == 3
    assert fourth.object.valid_samples == 3
    assert fourth.object.min_value == 3.0
    assert fourth.object.max_value == 7.0
    assert fourth.object.average_value == 5.0
    assert fourth.object.min_value_timestamp == timestamp(2000)
  end

  test "at least fifteen samples are retained and larger windows also work" do
    for capacity <- [15, 20] do
      stored = initial(object(%{window_interval: capacity, window_samples: capacity}))

      stored =
        Enum.reduce(1..(capacity + 5), stored, fn value, previous ->
          step(previous, value * 1000, value)
        end)

      assert stored.object.attempted_samples == capacity
      assert stored.object.valid_samples == capacity
      assert stored.object.min_value == 6.0
      assert stored.object.max_value == capacity + 5.0
      assert stored.object.average_value == (capacity + 11) / 2
    end
  end

  test "one sample has zero population variance" do
    stored = step(initial(), 1000, 12)
    assert stored.object.average_value == 12.0
    assert stored.object.variance_value == 0.0
  end

  test "failed reads are missed attempts, not zero values, and age out" do
    first = step(initial(), 1000, 10)
    failed = step(first, 2000, {:error, :timeout})
    assert failed.object.attempted_samples == 2
    assert failed.object.valid_samples == 1
    assert failed.object.average_value == 10.0
    assert failed.state.last_error == {reference(), :timeout}

    assert {:error, {:unknown_property, :reliability}} =
             Averaging.get_property(failed.object, :reliability)

    recovered =
      failed
      |> step(3000, 20)
      |> step(4000, 30)

    assert recovered.object.attempted_samples == 3
    assert recovered.object.valid_samples == 2
    assert recovered.object.average_value == 25.0
    assert recovered.state.last_error == nil
    aged = step(recovered, 5000, 40)
    assert aged.object.valid_samples == 3
    assert aged.object.average_value == 30.0
  end

  test "a window containing only missed samples has empty statistics" do
    stored =
      initial()
      |> step(1000, 4)
      |> step(2000, {:error, :timeout})
      |> step(3000, {:error, :timeout})
      |> step(4000, {:error, :timeout})

    assert stored.object.attempted_samples == 3
    assert stored.object.valid_samples == 0
    assert stored.object.min_value == :inf
    assert stored.object.max_value == :infn
    assert stored.object.average_value == :NaN
    assert stored.object.variance_value == :NaN
    assert stored.object.min_value_timestamp == ObjectsMacro.get_default_bacnet_datetime()
  end

  test "native Boolean, integer and REAL values convert to single precision" do
    for {value, expected} <- [
          {false, 0.0},
          {true, 1.0},
          {-2, -2.0},
          {5, 5.0},
          {2.5, 2.5},
          {2 / 3, 0.67},
          {16_777_217, 16_777_216.0}
        ] do
      stored = step(initial(), 1000, value)
      assert stored.object.valid_samples == 1
      assert stored.object.average_value == expected
    end
  end

  test "primitive encodings and singleton encoding lists preserve BACnet numeric types" do
    for {type, value, expected} <- [
          {:boolean, true, 1.0},
          {:boolean, false, 0.0},
          {:unsigned_integer, 10, 10.0},
          {:signed_integer, -10, -10.0},
          {:enumerated, 2, 2.0},
          {:real, 2.5, 2.5}
        ] do
      for input <- [Encoding.create!({type, value}), [Encoding.create!({type, value})]] do
        stored = step(initial(), 1000, input)
        assert stored.object.valid_samples == 1
        assert stored.object.average_value == expected
      end
    end
  end

  test "unsupported or malformed values occupy a missed slot" do
    for value <- [
          nil,
          :active,
          "4",
          [],
          [Encoding.create!({:real, 1.0}), Encoding.create!({:real, 2.0})],
          Encoding.create!({:double, 1.0}),
          Encoding.create!({:null, nil}),
          %Encoding{encoding: :primitive, type: :unsigned_integer, value: -1, extras: []},
          %Encoding{encoding: :primitive, type: :boolean, value: 1, extras: []},
          %Encoding{encoding: :constructed, type: :real, value: 1.0, extras: []}
        ] do
      stored = step(initial(), 1000, value)
      assert stored.object.attempted_samples == 1
      assert stored.object.valid_samples == 0
      assert stored.state.last_error == {reference(), :invalid_sample_value}
    end
  end

  test "infinities are valid samples with IEEE aggregate results" do
    positive =
      initial()
      |> step(1000, :inf)
      |> step(2000, 2)

    assert positive.object.valid_samples == 2
    assert positive.object.min_value == 2.0
    assert positive.object.max_value == :inf
    assert positive.object.average_value == :inf
    assert positive.object.variance_value == :NaN
    mixed = step(positive, 3000, :infn)
    assert mixed.object.min_value == :infn
    assert mixed.object.max_value == :inf
    assert mixed.object.average_value == :NaN
    assert mixed.object.variance_value == :NaN

    negative =
      initial()
      |> step(1000, :infn)
      |> step(2000, 2)

    assert negative.object.average_value == :infn
  end

  test "NaN is a valid REAL sample, propagates to aggregates and ages out" do
    stored =
      initial()
      |> step(1000, 1)
      |> step(2000, Encoding.create!({:real, :NaN}))

    assert stored.object.valid_samples == 2
    assert stored.object.min_value == :NaN
    assert stored.object.max_value == :NaN
    assert stored.object.average_value == :NaN
    assert stored.object.variance_value == :NaN
    assert stored.object.min_value_timestamp == ObjectsMacro.get_default_bacnet_datetime()

    aged =
      stored
      |> step(3000, 2)
      |> step(4000, 3)
      |> step(5000, 4)

    assert aged.object.min_value == 2.0
    assert aged.object.average_value == 3.0
  end

  test "equal extrema retain the oldest acquisition timestamp still in the window" do
    stored =
      initial()
      |> step(1000, 5)
      |> step(2000, 5)
      |> step(3000, 5)

    assert stored.object.min_value_timestamp == timestamp(1000)
    assert stored.object.max_value_timestamp == timestamp(1000)
    aged = step(stored, 4000, 5)
    assert aged.object.min_value_timestamp == timestamp(2000)
    assert aged.object.max_value_timestamp == timestamp(2000)
  end

  test "fractional periods round absolute deadlines up without accumulating drift" do
    stored = initial(object(%{window_interval: 1, window_samples: 3}))
    assert stored.next_execution.monotonic_time == 334
    early = step(stored, 333, fn _reference -> flunk("early read") end)
    assert early == stored
    first = step(early, 334, 1)
    assert first.next_execution.monotonic_time == 667
    second = step(first, 667, 2)
    assert second.next_execution.monotonic_time == 1000
    third = step(second, 1000, 3)
    assert third.next_execution.monotonic_time == 1334
  end

  test "late delivery marks skipped slots missed and acquires the current slot once" do
    stored = initial()
    parent = self()

    late =
      step(stored, 3500, fn ref ->
        send(parent, {:read, ref})
        {:ok, 9}
      end)

    assert_received {:read, _ref}
    refute_received {:read, _ref}
    assert late.object.attempted_samples == 3
    assert late.object.valid_samples == 1
    assert late.object.average_value == 9.0
    assert late.object.min_value_timestamp == timestamp(3500)
    assert late.next_execution.monotonic_time == 4000
    repeated = step(late, 3500, fn _reference -> flunk("duplicate acquisition") end)
    assert repeated == late
  end

  test "a long pause retains at most the configured sample count" do
    stored =
      initial()
      |> step(1000, 4)
      |> step(1_000_000_000, 8)

    assert stored.object.attempted_samples == 3
    assert stored.object.valid_samples == 1
    assert stored.object.average_value == 8.0
    assert length(stored.state.samples) == 3
    assert stored.next_execution.monotonic_time == 1_000_001_000
  end

  test "computed reads and other triggers only sample when due" do
    stored = initial()

    for trigger <- [
          :periodic,
          :clock_change,
          :continuation,
          {:property_read, :average_value, nil},
          {:object_changed,
           %BACnet.Protocol.DeviceObjectRef{
             device_identifier: nil,
             object_identifier: reference().object_identifier
           }}
        ] do
      ctx =
        context(trigger,
          monotonic_time: 500,
          state: stored.state,
          read_property: fn _reference -> flunk("not due") end
        )

      assert {:ok, ^stored} = Lifecycle.execute(stored.object, ctx)
    end

    ctx =
      context({:property_read, :average_value, nil}, state: stored.state, monotonic_time: 1000)

    assert {:ok, refreshed} = Lifecycle.prepare_read(stored.object, ctx)
    assert refreshed.object.attempted_samples == 1
  end

  test "wall-clock corrections affect acquisition timestamps but not sampling deadlines" do
    stored = step(initial(), 1000, 5)

    changed =
      context(:clock_change,
        monotonic_time: 1500,
        now: ~U[2025-01-01 00:00:00Z],
        state: stored.state,
        read_property: fn _reference -> flunk("not due") end
      )

    assert {:ok, ^stored} = Lifecycle.execute(stored.object, changed)

    due = %{
      changed
      | trigger: :timer,
        monotonic_time: 2000,
        read_property: fn _reference -> {:ok, 1} end
    }

    assert {:ok, sampled} = Lifecycle.execute(stored.object, due)
    assert sampled.object.min_value_timestamp == BACnetDateTime.from_datetime(due.now)
    assert sampled.next_execution.monotonic_time == 3000
  end

  test "each reset property clears statistics and restarts the period even for a same-value write" do
    stored = step(initial(), 1000, 4)

    for property <- @reset_properties do
      value = if property == :attempted_samples, do: 0, else: Map.fetch!(stored.object, property)
      {:ok, candidate} = Averaging.update_property(stored.object, property, value)

      ctx =
        context({:property_write, property, nil, nil},
          state: stored.state,
          monotonic_time: 1500,
          read_property: fn _reference -> flunk("reset must not read") end
        )

      assert {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
      assert_empty(prepared)
      assert {:ok, reset} = Lifecycle.execute(prepared, ctx)
      assert_empty(reset.object)
      assert reset.state.samples == []
      assert reset.next_execution.monotonic_time == 2500
    end
  end

  test "numeric reset identifiers use the same write semantics" do
    stored = step(initial(), 1000, 4)

    for property <- @reset_properties do
      value = if property == :attempted_samples, do: 0, else: Map.fetch!(stored.object, property)
      {:ok, candidate} = Averaging.update_property(stored.object, property, value)
      {:ok, numeric} = Constants.by_name(:property_identifier, property)

      ctx =
        context({:property_write, numeric, nil, nil}, state: stored.state, monotonic_time: 1500)

      assert {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
      assert {:ok, reset} = Lifecycle.execute(prepared, ctx)
      assert_empty(reset.object)
    end
  end

  test "changed configuration replaces the buffer, reference and sampling period" do
    stored = step(initial(), 1000, 4)
    {:ok, candidate} = Averaging.update_property(stored.object, :window_interval, 6)

    ctx =
      context({:property_write, :window_interval, nil, nil},
        state: stored.state,
        monotonic_time: 1500
      )

    assert {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    assert {:ok, reset} = Lifecycle.execute(prepared, ctx)
    assert reset.next_execution.monotonic_time == 3500
    assert_empty(reset.object)
    new_ref = %{reference() | property_array_index: 2}

    {:ok, candidate} =
      Averaging.update_property(reset.object, :object_property_reference, new_ref)

    ctx = %{
      ctx
      | trigger: {:property_write, :object_property_reference, nil, nil},
        state: reset.state
    }

    assert {:ok, prepared} = Lifecycle.prepare_write(reset.object, candidate, ctx)
    assert {:ok, reset} = Lifecycle.execute(prepared, ctx)

    sampled =
      step(reset, 3500, fn ref ->
        assert ref == new_ref
        {:ok, 8}
      end)

    assert sampled.object.average_value == 8.0
  end

  test "only zero may be written to attempted_samples" do
    stored = step(initial(), 1000, 1)
    {:ok, candidate} = Averaging.update_property(stored.object, :attempted_samples, 2)
    ctx = context({:property_write, :attempted_samples, nil, nil}, state: stored.state)
    assert {:error, :value_out_of_range} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    assert {:error, :value_out_of_range} = Lifecycle.execute(candidate, ctx)
    assert stored.object.attempted_samples == 1
  end

  test "writes to computed fields are denied before commit, including numeric identifiers" do
    stored = initial()

    for property <- [
          :min_value,
          :max_value,
          :average_value,
          :variance_value,
          :valid_samples,
          :min_value_timestamp,
          :max_value_timestamp
        ] do
      {:ok, numeric} = Constants.by_name(:property_identifier, property)

      for identifier <- [property, numeric] do
        ctx = context({:property_write, identifier, nil, nil}, state: stored.state)

        assert {:error, {:write_access_denied, ^property}} =
                 Lifecycle.prepare_write(stored.object, stored.object, ctx)
      end
    end
  end

  test "ordinary writes preserve the window and pending deadline" do
    stored = step(initial(), 1000, 3)
    {:ok, candidate} = Averaging.add_property(stored.object, :description, "Statistics")

    ctx =
      context({:property_write, :description, nil, nil},
        state: stored.state,
        monotonic_time: 1500
      )

    assert {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    assert {:ok, result} = Lifecycle.execute(prepared, ctx)
    assert result.state == stored.state
    assert result.next_execution == stored.next_execution
    assert result.object.average_value == 3.0
  end

  test "optional aggregates and timestamps can be absent" do
    {:ok, object} =
      Averaging.create(1, "Basic", %{
        window_interval: 3,
        window_samples: 3,
        object_property_reference: reference()
      })

    object =
      Enum.reduce(
        [:variance_value, :min_value_timestamp, :max_value_timestamp],
        object,
        fn property, current ->
          {:ok, updated} = Averaging.remove_property(current, property)
          updated
        end
      )

    stored = step(initial(object), 1000, 3)
    assert stored.object.average_value == 3.0
    assert stored.object.variance_value == nil
    assert stored.object.min_value_timestamp == nil
    assert stored.object.max_value_timestamp == nil
  end

  test "restart discards opaque state and every previously retained sample" do
    stored = step(initial(), 1000, 3)

    assert {:ok, restarted} =
             Lifecycle.execute(
               stored.object,
               context(:initialization, state: :old_vm_state, monotonic_time: -9000)
             )

    assert_empty(restarted.object)
    assert restarted.next_execution.monotonic_time == -8000
  end

  test "configuration and missing callback errors occur without host I/O" do
    for {changes, property} <- [
          {%{window_interval: 0}, :window_interval},
          {%{window_samples: 0}, :window_samples},
          {%{window_samples: 3001}, :window_samples},
          {%{object_property_reference: nil}, :object_property_reference},
          {%{object_property_reference: %{reference() | property_array_index: -1}},
           :object_property_reference}
        ] do
      invalid = struct(object(), changes)

      assert {:error, {:invalid_configuration, ^property}} =
               Lifecycle.execute(
                 invalid,
                 context(:initialization,
                   read_property: fn _reference -> flunk("preflight must not read") end
                 )
               )
    end

    assert {:error, {:unsupported_operation, :read_property}} =
             Lifecycle.execute(object(), context(:initialization, read_property: nil))

    assert {:ok, _result} =
             Lifecycle.execute(
               object(%{window_interval: 1, window_samples: 1000}),
               context(:initialization)
             )
  end

  test "bad runtime state and configuration changed outside lifecycle are rejected" do
    stored = initial()

    for state <- [
          nil,
          :bad,
          %{},
          %{stored.state | samples: [:bad]},
          %{stored.state | next_slot: 0},
          %{stored.state | origin: 2000}
        ] do
      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(
                 stored.object,
                 context(:timer, state: state, monotonic_time: 1000)
               )
    end

    {:ok, changed} = Averaging.update_property(stored.object, :window_interval, 6)

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(
               changed,
               context(:timer, state: stored.state)
             )
  end

  test "local references, explicit self references and remote references preserve array index" do
    self_device = %ObjectIdentifier{type: :device, instance: 42}
    remote = %ObjectIdentifier{type: :device, instance: 43}

    for device <- [nil, self_device, remote] do
      ref = %{
        reference()
        | device_identifier: device,
          property_array_index: 0,
          property_identifier: 87
      }

      stored = initial(object(%{object_property_reference: ref}))
      expected = if device == self_device, do: %{ref | device_identifier: nil}, else: ref

      ctx =
        context(:timer,
          state: stored.state,
          monotonic_time: 1000,
          device_identifier: self_device,
          read_property: fn actual ->
            assert actual == expected
            {:ok, Encoding.create!({:unsigned_integer, 7})}
          end
        )

      assert {:ok, sampled} = Lifecycle.execute(stored.object, ctx)
      assert sampled.object.average_value == 7.0
    end
  end

  test "qualified references remain remote without local device identity" do
    ref = %{reference() | device_identifier: %ObjectIdentifier{type: :device, instance: 42}}
    stored = initial(object(%{object_property_reference: ref}))

    stored =
      step(stored, 1000, fn actual ->
        assert actual == ref
        {:ok, 5}
      end)

    assert stored.object.average_value == 5.0
  end

  test "remote snapshots remain passive and reject local write preparation" do
    {:ok, remote} =
      Averaging.create(
        1,
        "Remote",
        %{
          window_interval: 0,
          window_samples: 0,
          object_property_reference: reference(),
          min_value: :inf,
          max_value: :infn,
          average_value: :NaN,
          attempted_samples: 0,
          valid_samples: 0
        },
        remote_object: 42
      )

    ctx = context(:periodic, state: :retained, read_property: nil)

    assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil}} =
             Lifecycle.execute(remote, ctx)

    assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil}} =
             Averaging.execute(remote, ctx)

    assert :ok = Averaging.validate_execution(remote, ctx)
    ctx = %{ctx | trigger: {:property_write, :window_interval, nil, nil}}

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(remote, remote, ctx)
  end

  test "intrinsic reporting creation stays unsupported but does not block lifecycle execution" do
    assert_raise ArgumentError, fn ->
      Averaging.create(1, "IR", %{window_interval: 3}, intrinsic_reporting: true)
    end

    object = object()
    object = %{object | _metadata: %{object._metadata | intrinsic_reporting: true}}

    assert {:ok, %Result{object: result}} = Lifecycle.execute(object, context(:initialization))
    assert result._metadata.intrinsic_reporting
  end

  test "callback exceptions and malformed results remain programming errors" do
    stored = initial()

    assert_raise RuntimeError, "callback failed", fn ->
      step(stored, 1000, fn _reference -> raise "callback failed" end)
    end

    assert_raise WithClauseError, fn -> step(stored, 1000, fn _reference -> :invalid end) end
  end

  test "a local host refreshes source properties and retains a computed read result" do
    {:ok, source} = AnalogValue.create(2, "Source", %{present_value: 14.0})
    host = Host.new([{object(), []}, {source, []}], @now, 0)
    assert :ok = Host.execute(host, AnalogValue.get_object_identifier(source), :initialization)
    id = Averaging.get_object_identifier(object())
    assert :ok = Host.execute(host, id, :initialization)
    Host.advance(host, DateTime.add(@now, 1000, :millisecond), 1000)
    ref = %{reference() | object_identifier: id, property_identifier: :average_value}
    assert {:ok, 14.0} = Host.read(host, ref)
    assert Host.snapshot(host, id).object.valid_samples == 1
  end

  defp object(properties \\ %{}) do
    {:ok, object} =
      Averaging.create(
        1,
        "Statistics",
        Map.merge(
          %{
            window_interval: 3,
            window_samples: 3,
            object_property_reference: reference(),
            variance_value: :NaN,
            min_value_timestamp: ObjectsMacro.get_default_bacnet_datetime(),
            max_value_timestamp: ObjectsMacro.get_default_bacnet_datetime()
          },
          properties
        )
      )

    object
  end

  defp reference() do
    %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: %ObjectIdentifier{type: :analog_value, instance: 2},
      property_identifier: :present_value,
      property_array_index: nil
    }
  end

  defp context(trigger, options \\ []) do
    Context.new(
      trigger,
      Keyword.merge(
        [now: @now, monotonic_time: 0, read_property: fn _reference -> {:ok, 1.0} end],
        options
      )
    )
  end

  defp initial(object \\ object()) do
    {:ok, result} = Lifecycle.execute(object, context(:initialization))
    result
  end

  defp step(stored, milliseconds, value) do
    callback =
      if is_function(value, 1),
        do: value,
        else: fn _reference ->
          case value do
            {:error, _reason} = error -> error
            other -> {:ok, other}
          end
        end

    ctx =
      context(:timer,
        state: stored.state,
        monotonic_time: milliseconds,
        now: DateTime.add(@now, milliseconds, :millisecond),
        read_property: callback
      )

    {:ok, result} = Lifecycle.execute(stored.object, ctx)
    result
  end

  defp timestamp(milliseconds) do
    BACnetDateTime.from_datetime(DateTime.add(@now, milliseconds, :millisecond))
  end

  defp assert_empty(object) do
    assert object.attempted_samples == 0
    assert object.valid_samples == 0
    assert object.min_value == :inf
    assert object.max_value == :infn
    assert object.average_value == :NaN
    assert object.variance_value in [nil, :NaN]
  end
end
