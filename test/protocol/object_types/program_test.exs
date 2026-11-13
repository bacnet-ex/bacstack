defmodule BACnet.Test.Protocol.ObjectTypes.ProgramTest do
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.Program
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_program

  doctest Program

  test "Figure 12-3 self-loops complete without a runtime adapter" do
    self_loops = [
      idle: [:ready, :halt, :unload],
      loading: [:ready, :load, :run, :halt, :restart],
      running: [:ready, :run],
      waiting: [:ready, :load, :run, :restart],
      halted: [:ready, :halt],
      unloading: [:ready, :load, :run, :halt, :restart, :unload]
    ]

    for {state, requests} <- self_loops, request <- requests do
      stored = initialize(state)
      assert {:ok, %Result{object: current, next_execution: nil}} = request(stored, request)
      assert current.program_state == state
      assert current.program_change == :ready
      assert current.out_of_service == stored.object.out_of_service
    end
  end

  test "load and setup have distinct tokens and retain the busy request until setup completes" do
    parent = self()

    runtime = fn operation, token, object ->
      send(parent, {operation, token, object.program_state})
      :pending
    end

    stored = initialize(:idle, %{}, program_runtime: runtime)
    assert Program.property_writable?(stored.object, :program_change)
    assert stored.object.out_of_service
    assert stored.object.status_flags.out_of_service

    assert {:ok, staged} = request(stored, :run)

    assert %Result{
             object: %{program_state: :loading, program_change: :run},
             next_execution: :immediate
           } =
             staged

    refute_received {:load, _, _}
    refute Program.property_writable?(staged.object, :program_change)

    assert {:ok, loading} = continue(staged)
    assert loading.next_execution == nil
    assert loading.object.out_of_service
    assert_received {:load, load_token, :loading}
    assert {:error, :busy} = request(loading, :halt)
    assert {:error, :busy} = request(loading, :run)

    assert {:ok, ^loading} = event(loading, {:completed, make_ref(), :ok})
    assert {:ok, setup} = event(loading, {:completed, load_token, :ok})
    assert setup.next_execution == :immediate
    assert setup.object.program_change == :run

    assert {:ok, initializing} = continue(setup)
    assert_received {:restart, setup_token, :loading}
    refute setup_token == load_token
    assert {:ok, ^initializing} = event(initializing, {:completed, load_token, :ok})

    assert {:ok, running} = event(initializing, {:completed, setup_token, :ok})

    assert %Result{
             object: %{program_state: :running, program_change: :ready},
             next_execution: nil
           } =
             running

    refute running.object.out_of_service
    refute running.object.status_flags.out_of_service
  end

  test "a runtime halt during an incomplete load cancels the old token and Restart loads again" do
    parent = self()

    runtime = fn operation, token, _object ->
      send(parent, {operation, token})
      :pending
    end

    assert {:ok, staged} = request(initialize(:idle, %{}, program_runtime: runtime), :load)
    assert {:ok, loading} = continue(staged)
    assert_received {:load, old_token}

    assert {:ok, halted} = event(loading, {:halted, :internal, "Loader stopped", :incomplete})
    assert halted.object.program_state == :halted
    assert halted.object.program_change == :ready
    assert halted.object.out_of_service
    assert halted.object.status_flags.out_of_service
    assert halted.object.reason_for_halt == :internal
    assert halted.object.description_of_halt == "Loader stopped"

    assert {:ok, ^halted} = event(halted, {:completed, old_token, :ok})
    assert {:error, {:invalid_program_request, :run}} = request(halted, :run)
    {:ok, candidate} = Program.update_property(halted.object, :program_change, :run)

    assert {:error, {:invalid_program_request, :run}} =
             Program.execute(candidate, write_context(halted))

    assert {:ok, restarted} = request(halted, :restart)
    assert {:ok, loading} = continue(restarted)
    assert loading.object.program_state == :loading
    assert_received {:load, new_token}
    refute new_token == old_token
  end

  test "load failure returns to idle and setup failure retains a complete image" do
    load_failure = fn :load, _token, _object -> {:error, "Missing image"} end
    stored = initialize(:idle, %{}, program_runtime: load_failure)
    assert {:ok, staged} = request(stored, :restart)
    assert {:ok, failed} = continue(staged)
    assert failed.object.program_state == :idle
    assert failed.object.program_change == :ready
    assert failed.object.out_of_service
    assert failed.object.reason_for_halt == :load_failed
    assert failed.object.description_of_halt == "Missing image"

    runtime = fn
      :load, _token, _object -> :ok
      :restart, _token, %Program{program_state: :loading} -> {:error, "Invalid setup"}
      :restart, _token, %Program{program_state: :halted} -> :ok
    end

    stored = initialize(:idle, %{}, program_runtime: runtime)
    assert {:ok, staged} = request(stored, :load)
    assert {:ok, setup} = continue(staged)
    assert {:ok, halted} = continue(setup)
    assert halted.object.program_state == :halted
    assert halted.object.program_change == :ready
    assert halted.object.out_of_service
    assert halted.object.reason_for_halt == :internal
    assert halted.object.description_of_halt == "Invalid setup"

    assert {:ok, staged} = request(halted, :restart)
    assert {:ok, running} = continue(staged)
    assert running.object.program_state == :running
    assert running.object.reason_for_halt == :normal
    refute running.object.out_of_service
  end

  test "waiting, halt, run and unload project the runtime's confirmed state" do
    runtime = fn operation, _token, _object when operation in [:halt, :run, :unload] -> :ok end
    stored = initialize(:running, %{}, program_runtime: runtime)
    assert {:ok, waiting} = event(stored, :waiting)
    assert waiting.object.program_state == :waiting
    refute waiting.object.out_of_service
    assert {:ok, running} = event(waiting, :running)
    assert running.object.program_state == :running

    assert {:ok, staged} = request(waiting, :halt)
    assert staged.object.program_state == :waiting
    assert {:ok, halted} = continue(staged)
    assert halted.object.program_state == :halted
    assert halted.object.reason_for_halt == :program
    refute halted.object.out_of_service

    assert {:ok, staged} = request(halted, :run)
    assert {:ok, running} = continue(staged)
    assert running.object.program_state == :running

    assert {:ok, unloading} = request(running, :unload)
    assert unloading.object.program_state == :unloading
    assert {:ok, idle} = continue(unloading)
    assert idle.object.program_state == :idle
    assert idle.object.out_of_service
  end

  test "a failed unload restores the prior program state" do
    runtime = fn :unload, _token, _object -> {:error, "Resources busy"} end
    stored = initialize(:running, %{}, program_runtime: runtime)
    assert {:ok, unloading} = request(stored, :unload)
    assert unloading.object.program_state == :unloading
    assert {:ok, running} = continue(unloading)
    assert running.object.program_state == :running
    assert running.object.program_change == :ready
  end

  test "preflight requires a runtime for actions and rejects writes during a local override" do
    stored = initialize(:idle)
    context = write_context(stored)
    {:ok, candidate} = Program.update_property(stored.object, :program_change, :load)

    assert {:error, {:unsupported_operation, :program_runtime}} =
             Program.validate_execution(candidate, context)

    runtime = fn _operation, _token, _object -> flunk("runtime must be bound to the object") end

    assert {:error, {:unsupported_operation, :program_runtime}} =
             Program.validate_execution(candidate, %{
               context
               | options: [program_runtime: runtime]
             })

    invalid = initialize(:idle, %{}, program_runtime: :bad)
    {:ok, invalid_candidate} = Program.update_property(invalid.object, :program_change, :load)

    assert {:error, {:invalid_configuration, :program_runtime}} =
             Program.validate_execution(invalid_candidate, write_context(invalid))

    flags = %{stored.object.status_flags | overridden: true}
    assert {:ok, overridden} = Program.update_property(stored.object, :status_flags, flags)
    refute Program.property_writable?(overridden, :program_change)
    refute Program.property_writable?(overridden, :instance_of)

    assert {:error, {:write_access_denied, :program_change}} =
             Program.prepare_write(overridden, candidate, context)

    application = %{context | trigger: {:application_write, :program_change, nil, nil}}
    assert {:ok, ^candidate} = Program.prepare_write(overridden, candidate, application)
  end

  test "descriptive writes are accepted while a program request is ready" do
    stored = initialize(:idle, %{description: "old"})
    context = Context.new({:property_write, :description, nil, nil}, state: stored.state)
    {:ok, candidate} = Program.update_property(stored.object, :description, "new")
    assert {:ok, ^candidate} = Program.prepare_write(stored.object, candidate, context)
  end

  test "location events update selected locations and runtime-owned properties are read-only" do
    stored = initialize(:running, %{program_location: "entry"})
    assert {:ok, current} = event(stored, {:location, "line 12"})
    assert {:ok, "line 12"} = Program.get_property(current.object, :program_location)
    refute Program.property_writable?(current.object, :program_location)
    context = Context.new({:property_write, :program_location, nil, nil}, state: current.state)

    assert {:error, {:write_access_denied, :program_location}} =
             Program.prepare_write(current.object, current.object, context)

    without_location = initialize(:running)
    assert {:ok, ^without_location} = event(without_location, {:location, "line 12"})
  end

  test "initialization can adopt an already loading or unloading runtime" do
    assert {:ok, running} = event(initialize(:loading, %{program_change: :load}), :running)
    assert running.object.program_state == :running
    assert running.object.program_change == :ready
    refute running.object.out_of_service

    assert {:ok, idle} = event(initialize(:unloading), :idle)
    assert idle.object.program_state == :idle
    assert idle.object.out_of_service
  end

  test "reads and periodic ticks preserve valid state and reject invalid retained state" do
    stored = initialize(:running)
    read = Context.new({:property_read, :program_state, nil}, state: stored.state)
    assert {:ok, ^stored} = Program.execute(stored.object, read)

    assert {:ok, ^stored} =
             Program.execute(stored.object, Context.new(:periodic, state: stored.state))

    assert {:error, :invalid_program_event} = event(stored, :invalid)

    assert {:error, :invalid_execution_state} =
             Program.execute(stored.object, %{read | state: %{stored.state | instance: 42}})

    assert {:error, :invalid_program_state} =
             Program.execute(%{stored.object | program_state: :invalid}, read)
  end

  test "rejects an invalid runtime outcome at dispatch" do
    stored =
      initialize(:idle, %{}, program_runtime: fn _operation, _token, _object -> :invalid end)

    assert {:ok, staged} = request(stored, :load)

    assert_raise ArgumentError, "invalid Program runtime outcome: :invalid", fn ->
      continue(staged)
    end
  end

  test "remote objects remain passive" do
    {:ok, remote} =
      Program.create(
        1,
        "Remote",
        %{
          program_state: :running,
          program_change: :ready,
          out_of_service: false,
          status_flags: StatusFlags.from_bitstring({false, false, false, false})
        },
        remote_object: 42
      )

    context = Context.new(:initialization, state: :retained)
    assert :ok = Program.validate_execution(remote, context)

    assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil}} =
             Program.execute(remote, context)

    assert {:error, :operation_not_available_for_remote_objects} =
             Program.prepare_write(
               remote,
               remote,
               Context.new({:property_write, :program_change, nil, nil})
             )
  end

  test "reports program reliability with the program state and selected halt properties" do
    stored =
      initialize(
        :halted,
        %{
          reliability: :process_error,
          reason_for_halt: :internal,
          description_of_halt: "Runtime failure"
        },
        intrinsic_reporting: true
      )

    assert %{
             event_type: :change_of_reliability,
             to_state: :fault,
             event_values: %{
               property_values: [
                 %{property_identifier: :program_state},
                 %{property_identifier: :reason_for_halt},
                 %{property_identifier: :description_of_halt}
               ]
             }
           } =
             EventReporting.transition(stored)
  end

  defp initialize(state, overrides \\ %{}, options \\ []) do
    properties =
      Map.merge(
        %{
          program_state: state,
          reason_for_halt: :normal,
          description_of_halt: "",
          instance_of: "Sequence"
        },
        overrides
      )

    {:ok, object} = Program.create(1, "Program", properties, options)
    assert {:ok, stored} = Program.execute(object, Context.new(:initialization))
    stored
  end

  defp write_context(stored) do
    Context.new({:property_write, :program_change, nil, nil}, state: stored.state)
  end

  defp request(stored, request) do
    context = write_context(stored)
    {:ok, candidate} = Program.update_property(stored.object, :program_change, request)

    with {:ok, prepared} <- Program.prepare_write(stored.object, candidate, context) do
      Program.execute(prepared, context)
    end
  end

  defp continue(stored) do
    Program.execute(stored.object, Context.new(:continuation, state: stored.state))
  end

  defp event(stored, event) do
    Program.execute(
      stored.object,
      Context.new(:periodic, state: stored.state, options: [program_event: event])
    )
  end
end
