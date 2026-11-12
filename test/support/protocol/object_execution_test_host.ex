defmodule BACnet.Test.Support.Protocol.ObjectExecutionTestHost do
  @moduledoc false

  # Deliberately synchronous and test-only. Storage belongs to the test process
  # Advancing supplied time never sleeps or creates timers
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility

  @type t :: %__MODULE__{key: reference()}
  @type record :: %{
          object: struct(),
          state: term(),
          options: keyword(),
          next_execution: nil | :immediate | Wakeup.t()
        }
  @enforce_keys [:key]
  defstruct @enforce_keys

  @spec new(
          [{object :: struct(), execution_options :: keyword()}],
          DateTime.t(),
          integer(),
          keyword()
        ) :: t()
  def new(objects, now, monotonic_time, options \\ []) do
    records =
      Map.new(objects, fn {object, options} ->
        {ObjectsUtility.get_object_identifier(object),
         %{object: object, state: nil, next_execution: nil, options: options}}
      end)

    host = %__MODULE__{key: make_ref()}

    Process.put(host.key, %{
      records: records,
      now: now,
      monotonic_time: monotonic_time,
      device_identifier: Keyword.get(options, :device_identifier),
      active: MapSet.new(),
      failures: %{},
      writes: [],
      remote_write: Keyword.get(options, :remote_write),
      after_commit: Keyword.get(options, :after_commit)
    })

    host
  end

  @spec snapshot(t(), ObjectIdentifier.t()) :: record()
  def snapshot(host, identifier), do: Map.fetch!(data(host).records, identifier)

  @spec writes(t()) :: [{DeviceObjectPropertyRef.t(), value :: term(), priority :: 1..16 | nil}]
  def writes(host), do: Enum.reverse(data(host).writes)

  @spec fail_writes(t(), ObjectIdentifier.t(), term()) :: map()
  def fail_writes(host, identifier, reason) do
    change(host, &%{&1 | failures: Map.put(&1.failures, identifier, reason)})
  end

  @spec advance(t(), DateTime.t(), integer()) :: map()
  def advance(host, now, monotonic_time) do
    change(host, &%{&1 | now: now, monotonic_time: monotonic_time})
  end

  @spec execute(t(), ObjectIdentifier.t(), Context.trigger(), non_neg_integer()) ::
          :ok | {:error, term()}
  def execute(host, identifier, trigger, remaining \\ 100) do
    if MapSet.member?(data(host).active, identifier) do
      {:error, :cyclic_execution}
    else
      execute_step(host, identifier, trigger, remaining)
    end
  end

  @spec read(t(), DeviceObjectPropertyRef.t()) :: {:ok, term()} | {:error, term()}
  def read(host, reference)

  def read(
        host,
        %DeviceObjectPropertyRef{device_identifier: nil} = reference
      ) do
    with :ok <-
           execute(
             host,
             reference.object_identifier,
             {:property_read, reference.property_identifier, nil}
           ) do
      object = snapshot(host, reference.object_identifier).object

      with {:ok, value} <- object.__struct__.get_property(object, reference.property_identifier) do
        case reference.property_array_index do
          nil -> {:ok, value}
          index -> BACnetArray.get_item(value, index)
        end
      end
    end
  end

  def read(_host, _reference), do: {:error, :unsupported_test_reference}

  @spec write(t(), DeviceObjectPropertyRef.t(), term(), 1..16 | nil) :: :ok | {:error, term()}
  def write(host, reference, value, priority \\ nil)

  def write(
        host,
        %DeviceObjectPropertyRef{device_identifier: nil} = reference,
        value,
        priority
      ) do
    identifier = reference.object_identifier
    change(host, &%{&1 | writes: [{reference, value, priority} | &1.writes]})

    object =
      case Map.fetch(data(host).records, identifier) do
        {:ok, record} -> record.object
        :error -> nil
      end

    cond do
      is_struct(object, BACnet.Protocol.ObjectTypes.Command) and object.in_process and
          reference.property_identifier in [:present_value, 85] ->
        {:error, :busy}

      is_nil(object) ->
        {:error, :unknown_object}

      MapSet.member?(data(host).active, identifier) ->
        {:error, :cyclic_execution}

      Map.has_key?(data(host).failures, identifier) ->
        {:error, data(host).failures[identifier]}

      true ->
        prepare_and_write(host, reference, value, priority)
    end
  end

  def write(host, reference, value, priority) do
    change(host, &%{&1 | writes: [{reference, value, priority} | &1.writes]})

    case data(host).remote_write do
      callback when is_function(callback, 3) -> callback.(reference, value, priority)
      nil -> {:error, :unsupported_test_reference}
    end
  end

  @spec run_due(t()) :: :ok
  def run_due(host) do
    Enum.each(Map.keys(data(host).records), fn identifier ->
      record = snapshot(host, identifier)
      context = context(host, record, :timer)

      if match?(%Wakeup{}, record.next_execution) and Wakeup.due?(record.next_execution, context) do
        :ok = execute(host, identifier, :timer)
      end
    end)
  end

  defp prepare_and_write(host, reference, value, priority)

  defp prepare_and_write(host, reference, value, priority)
       when is_integer(reference.property_identifier) do
    case Constants.by_value(:property_identifier, reference.property_identifier) do
      {:ok, property} ->
        prepare_and_write(host, %{reference | property_identifier: property}, value, priority)

      :error ->
        {:error, {:unknown_property, reference.property_identifier}}
    end
  end

  defp prepare_and_write(host, reference, value, priority) do
    identifier = reference.object_identifier
    record = snapshot(host, identifier)
    object = record.object
    module = object.__struct__

    trigger =
      {:property_write, reference.property_identifier, reference.property_array_index, priority}

    candidate =
      with {:ok, value} <- cast_write(object, reference, value) do
        cond do
          not is_nil(reference.property_array_index) ->
            with {:ok, array} <- module.get_property(object, reference.property_identifier),
                 {:ok, updated} <-
                   BACnetArray.set_item(array, reference.property_array_index, value) do
              module.update_property(object, reference.property_identifier, updated)
            end

          reference.property_identifier == :present_value and
              ObjectsUtility.has_priority_array?(object) ->
            if priority == 6,
              do: {:error, :write_access_denied},
              else: module.set_priority(object, priority || 16, value)

          module.property_writable?(object, reference.property_identifier) ->
            module.update_property(object, reference.property_identifier, value)

          true ->
            {:error, {:write_access_denied, reference.property_identifier}}
        end
      end

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <-
           Lifecycle.prepare_write(object, candidate, context(host, record, trigger)) do
      put_record(host, identifier, %{record | object: prepared})

      case execute(host, identifier, trigger) do
        :ok -> :ok
        {:error, reason} -> {:error, {:execution_failed_after_commit, reason}}
      end
    end
  end

  defp cast_write(object, reference, value)

  defp cast_write(object, reference, %Encoding{} = value),
    do: cast_encoding(object, reference, value)

  defp cast_write(object, reference, [%Encoding{} | _rest] = values),
    do: cast_encoding(object, reference, values)

  defp cast_write(_object, _reference, value), do: {:ok, value}

  defp cast_encoding(object, reference, value) do
    command =
      reference.property_identifier == :present_value and
        is_nil(reference.property_array_index) and ObjectsUtility.has_priority_array?(object)

    case {reference.property_array_index, value} do
      {0, %Encoding{type: :unsigned_integer, value: length}}
      when is_integer(length) and length >= 0 ->
        {:ok, length}

      {0, _value} ->
        {:error, :invalid_property_value}

      {nil, %Encoding{type: :null}} when command ->
        {:ok, nil}

      _other ->
        ObjectsUtility.cast_property_to_value(
          object.__struct__.get_object_identifier(object),
          reference.property_identifier,
          value,
          allow_partial: not is_nil(reference.property_array_index),
          allow_numeric_constants: true
        )
    end
  end

  defp execute_step(host, identifier, trigger, remaining)

  defp execute_step(_host, _identifier, _trigger, 0), do: raise("non-progressing continuation")

  defp execute_step(host, identifier, trigger, remaining) do
    record = snapshot(host, identifier)
    change(host, &%{&1 | active: MapSet.put(&1.active, identifier)})

    result =
      try do
        context = context(host, record, trigger)

        case trigger do
          {:property_read, _property, _index} -> Lifecycle.prepare_read(record.object, context)
          _other -> Lifecycle.execute(record.object, context)
        end
      after
        change(host, &%{&1 | active: MapSet.delete(&1.active, identifier)})
      end

    case result do
      {:ok, result} ->
        put_record(host, identifier, %{
          record
          | object: result.object,
            state: result.state,
            next_execution: result.next_execution
        })

        if callback = data(host).after_commit, do: callback.(host, identifier, result)

        if result.next_execution == :immediate do
          execute(host, identifier, :continuation, remaining - 1)
        else
          :ok
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp context(host, record, trigger) do
    %Context{
      now: data(host).now,
      timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
      monotonic_time: data(host).monotonic_time,
      trigger: trigger,
      state: record.state,
      options: record.options,
      device_identifier: data(host).device_identifier,
      lookup_object: fn reference ->
        case Map.fetch(data(host).records, reference.object_identifier) do
          {:ok, record} -> {:ok, record.object}
          :error -> {:error, :unknown_object}
        end
      end,
      read_property_multiple: nil,
      read_property: &read(host, &1),
      write_property: &write(host, &1, &2, &3)
    }
  end

  defp data(host), do: Process.get(host.key)
  defp change(host, fun), do: Process.put(host.key, fun.(data(host)))

  defp put_record(host, identifier, record),
    do: change(host, &%{&1 | records: Map.put(&1.records, identifier, record)})
end
