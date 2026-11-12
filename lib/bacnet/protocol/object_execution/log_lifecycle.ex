defmodule BACnet.Protocol.ObjectExecution.LogLifecycle do
  @moduledoc """
  Shared lifecycle operations for Event Log, Trend Log and Trend Log Multiple.
  Connects Event Log, Trend Log and Trend Log Multiple to their logger.

  The object modules select writable properties and supported logging modes.
  This module routes committed writes and sampling continuations to
  `BACnet.Stack.TrendLogger`.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.EventLog
  alias BACnet.Stack.TrendLogger

  @doc "Resolves the logger server from the context's `:trend_logger` option."
  @spec get_logger(Context.t()) :: {:ok, TrendLogger.server()} | {:error, term()}
  def get_logger(%Context{options: options}) do
    case Keyword.get(options, :trend_logger) do
      nil -> {:error, {:unsupported_operation, :trend_logger}}
      server when is_pid(server) or is_atom(server) -> {:ok, server}
      {name, node} = server when is_atom(name) and is_atom(node) -> {:ok, server}
      {:global, _name} = server -> {:ok, server}
      {:via, module, _name} = server when is_atom(module) -> {:ok, server}
      _other -> {:error, {:invalid_execution_option, :trend_logger}}
    end
  end

  @doc """
  Checks the write candidate before the host commits it.

  The object supplies its logger-owned read-only properties. Trend logs also
  check whether a trigger can start and whether another sample is pending.
  """
  @spec prepare_write(object, object, Context.t(), [atom()]) ::
          {:ok, object} | {:error, term()}
        when object: TrendLogger.object()
  def prepare_write(%module{} = original, candidate, context, readonly) do
    property = Context.written_property(context)
    trend_log? = module != EventLog

    cond do
      property in readonly ->
        {:error, {:write_access_denied, property}}

      trend_log? and property in [:buffer_size, :log_interval] and
          not module.property_writable?(original, property) ->
        {:error, {:write_access_denied, property}}

      property == :record_count and candidate.record_count != 0 ->
        {:error, {:invalid_property_value, :record_count}}

      property == :enable and candidate.enable and original.stop_when_full and
          original.record_count >= original.buffer_size ->
        {:error, :log_buffer_full}

      trend_log? and property == :trigger and
          IntrinsicReporting.log_execution_state(context.state) == :sample_pending ->
        {:error, :busy}

      trend_log? and property == :trigger and candidate.trigger == true and
          original.logging_type != :triggered ->
        {:error, :not_configured_for_triggered_logging}

      true ->
        {:ok, candidate}
    end
  end

  @doc """
  Runs one log step, updates the object's counters and checks for reporting transitions.

  Trend Log and Trend Log Multiple return an immediate continuation when a
  committed Trigger write starts a sample.
  """
  @spec execute(object, Context.t(), [atom()]) :: {:ok, Result.t(object)} | {:error, term()}
        when object: TrendLogger.object()
  def execute(object, context, logger_properties) do
    state = IntrinsicReporting.log_execution_state(context.state)
    trigger = Context.write_trigger(context) || context.trigger

    with {:ok, logger} <- get_logger(context),
         {:ok, object, state} <- apply_trigger(logger, object, trigger, state, logger_properties) do
      result = %Result{
        object: object,
        state: state,
        next_execution:
          if(state == :sample_pending and not is_struct(object, EventLog), do: :immediate)
      }

      IntrinsicReporting.evaluate_log(result, context, logger)
    end
  end

  @spec apply_trigger(TrendLogger.server(), object, Context.trigger(), term(), [atom()]) ::
          {:ok, object, term()} | {:error, term()}
        when object: TrendLogger.object()
  defp apply_trigger(logger, object, trigger, state, logger_properties)

  defp apply_trigger(logger, object, :initialization, state, _logger_properties) do
    with :ok <- TrendLogger.add_object(logger, object, :lifecycle) do
      if is_struct(object, EventLog),
        do: {:ok, object, state},
        else: {:ok, %{object | trigger: if(object.trigger != nil, do: false)}, nil}
    end
  end

  defp apply_trigger(logger, object, :continuation, :sample_pending, _logger_properties)
       when not is_struct(object, EventLog) do
    with :ok <- TrendLogger.sample(logger, object) do
      {:ok, %{object | trigger: false}, nil}
    end
  end

  defp apply_trigger(
         _logger,
         %{trigger: true} = object,
         {source, :trigger, _index, _priority},
         _state,
         _logger_properties
       )
       when source in [:property_write, :application_write] do
    if object.logging_type == :triggered,
      do: {:ok, object, :sample_pending},
      else: {:error, :not_configured_for_triggered_logging}
  end

  defp apply_trigger(
         logger,
         object,
         {source, :record_count, _index, _priority},
         state,
         _properties
       )
       when source in [:property_write, :application_write] do
    if object.record_count == 0 do
      with :ok <- TrendLogger.prune_buffer(logger, object), do: {:ok, object, state}
    else
      {:error, {:invalid_property_value, :record_count}}
    end
  end

  defp apply_trigger(
         logger,
         object,
         {source, property, _index, _priority},
         state,
         logger_properties
       )
       when source in [:property_write, :application_write] do
    if property in logger_properties do
      with :ok <- TrendLogger.update_object(logger, object, property), do: {:ok, object, state}
    else
      {:ok, object, state}
    end
  end

  defp apply_trigger(_logger, object, _trigger, state, _logger_properties),
    do: {:ok, object, state}
end
