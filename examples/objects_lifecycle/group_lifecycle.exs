# Run from the repository root: mix run examples/objects_lifecycle/group_lifecycle.exs
defmodule BACnet.Examples.GroupLifecycle do
  @moduledoc """
  Finite Group walkthrough with retained local objects and explicit clocks.

  The example host reads a plain AnalogValue and a computed Calendar. Its selector catalog
  covers these examples' base property declarations without optional capability groups.
  A production property-service catalog needs the applicable conditional and proprietary rules.
  """

  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.AccessSpecification.Property
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.AnalogValue
  alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject
  alias BACnet.Protocol.ObjectTypes.Group
  alias BACnet.Protocol.ReadAccessResult.ReadResult

  @now ~U[2026-11-09 23:59:59Z]
  @selectors [:all, :required, :optional]

  @spec run() :: :ok
  def run() do
    {:ok, source} =
      AnalogValue.create(2, "Room temperature", %{
        present_value: 21.5,
        description: "Measured value"
      })

    {:ok, calendar} =
      CalendarObject.create(3, "Special day", %{
        date_list: [
          %CalendarEntry{
            type: :date,
            date: BACnetDate.from_date(~D[2026-11-09]),
            date_range: nil,
            week_n_day: nil
          }
        ]
      })

    members = [
      member(source, [property(:present_value), property(:description)]),
      member(calendar, [property(:present_value)])
    ]

    {:ok, group} = Group.create(1, "Zone view", %{list_of_group_members: members})

    {:ok, store} =
      Agent.start_link(fn ->
        %{
          group: retained(group),
          sources:
            Map.new([source, calendar], fn object ->
              {:ok, initialized} =
                Lifecycle.execute(
                  object,
                  Context.new(:initialization, now: @now, monotonic_time: 0)
                )

              {object.__struct__.get_object_identifier(object), initialized}
            end),
          denied: MapSet.new(),
          reads: []
        }
      end)

    try do
      {:ok, initialized} = Lifecycle.execute(group, context(store, :initialization, 0))
      retain_group(store, initialized)
      [] = snapshot(store).reads
      show(store, "Initialized without reading members")

      :ok = read_group(store, 0)
      [temperature, _description, special_day] = results(store)
      21.5 = temperature.property_value.value
      true = special_day.property_value.value
      show(store, "Read local temperature and refreshed Calendar")

      source_id = AnalogValue.get_object_identifier(source)
      current = snapshot(store).sources[source_id]
      {:ok, changed} = AnalogValue.update_property(current.object, :present_value, 22.5)

      ctx = %{
        context(store, {:application_write, :present_value, nil, nil}, 0)
        | state: current.state
      }

      {:ok, prepared} = Lifecycle.prepare_write(current.object, changed, ctx)
      {:ok, updated} = Lifecycle.execute(prepared, ctx)
      retain_source(store, source_id, updated)
      :ok = read_group(store, 0)
      22.5 = hd(results(store)).property_value.value
      show(store, "Same-clock read acquired the changed source again")

      :ok = read_group(store, 1000)
      false = List.last(results(store)).property_value.value
      show(store, "Read after midnight refreshed Calendar before returning its value")

      Agent.update(store, &%{&1 | denied: MapSet.put(&1.denied, {source_id, :description})})
      :ok = read_group(store, 1000)
      :read_access_denied = Enum.at(results(store), 1).error.code
      false = List.last(results(store)).property_value.value
      show(store, "One access error retained - following member still read")

      previous_reads = snapshot(store).reads
      :ok = configure(store, [member(source, [:all, :required, :optional])], 1000)
      ^previous_reads = snapshot(store).reads
      [] = snapshot(store).group.object.present_value
      :ok = read_group(store, 1000)
      false = Enum.any?(results(store), &(&1.property_identifier == :property_list))

      true =
        Enum.any?(
          results(store),
          &match?(%ReadResult{error: %BACnetError{code: :read_access_denied}}, &1)
        )

      show(store, "Selectors expanded into concrete property values and errors")

      missing = %AccessSpecification{
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 999},
        properties: [property(:present_value)]
      }

      :ok = configure(store, [missing], 1000)
      :ok = read_group(store, 1000)
      :unknown_object = hd(results(store)).error.code
      show(store, "Unavailable member represented as an object access error")
      :ok
    after
      Agent.stop(store)
    end
  end

  @spec retained(struct()) :: Result.t()
  defp retained(object), do: %Result{object: object, state: nil, next_execution: nil}

  @spec member(struct(), [Property.t() | atom()]) :: AccessSpecification.t()
  defp member(object, properties),
    do: %AccessSpecification{
      object_identifier: object.__struct__.get_object_identifier(object),
      properties: properties
    }

  @spec property(atom()) :: Property.t()
  defp property(name),
    do: %Property{property_identifier: name, property_array_index: nil, property_value: nil}

  @spec context(pid(), Context.trigger(), integer()) :: Context.t()
  defp context(store, trigger, milliseconds) do
    ctx =
      Context.new(trigger,
        now: DateTime.add(@now, milliseconds, :millisecond),
        monotonic_time: milliseconds,
        state: snapshot(store).group.state
      )

    %{
      ctx
      | read_property: &read(store, &1, ctx),
        read_property_multiple: &read_multiple(store, &1, &2, ctx)
    }
  end

  @spec read_group(pid(), integer()) :: :ok | {:error, term()}
  defp read_group(store, milliseconds) do
    stored = snapshot(store).group

    with {:ok, result} <-
           Lifecycle.prepare_read(
             stored.object,
             context(store, {:property_read, :present_value, nil}, milliseconds)
           ) do
      retain_group(store, result)
    end
  end

  @spec configure(pid(), [AccessSpecification.t()], integer()) :: :ok | {:error, term()}
  defp configure(store, members, milliseconds) do
    stored = snapshot(store).group
    ctx = context(store, {:property_write, :list_of_group_members, nil, nil}, milliseconds)

    with {:ok, candidate} <- Group.update_property(stored.object, :list_of_group_members, members),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      retain_group(store, %{stored | object: prepared})
      with {:ok, result} <- Lifecycle.execute(prepared, ctx), do: retain_group(store, result)
    end
  end

  @spec read(pid(), DeviceObjectPropertyRef.t(), Context.t()) :: {:ok, term()} | {:error, term()}
  defp read(store, reference, ctx) do
    Agent.update(store, &%{&1 | reads: [reference | &1.reads]})

    case Map.fetch(snapshot(store).sources, reference.object_identifier) do
      {:ok, _source} -> read_value(store, reference, ctx)
      :error -> {:error, %BACnetError{class: :object, code: :unknown_object}}
    end
  end

  @spec read_multiple(pid(), DeviceObjectRef.t(), [atom()], Context.t()) ::
          {:ok, map()} | {:error, term()}
  defp read_multiple(store, reference, [selector], ctx) when selector in @selectors do
    Agent.update(store, &%{&1 | reads: [{reference, selector} | &1.reads]})

    case Map.fetch(snapshot(store).sources, reference.object_identifier) do
      {:ok, source} ->
        values =
          Map.new(selected(source.object, selector), fn property ->
            ref = %DeviceObjectPropertyRef{
              device_identifier: reference.device_identifier,
              object_identifier: reference.object_identifier,
              property_identifier: property,
              property_array_index: nil
            }

            value =
              case read_value(store, ref, ctx) do
                {:ok, value} -> value
                {:error, _reason} = error -> error
              end

            {property, value}
          end)

        {:ok, values}

      :error ->
        {:error, %BACnetError{class: :object, code: :unknown_object}}
    end
  end

  @spec selected(struct(), :all | :required | :optional) :: [atom() | non_neg_integer()]
  defp selected(object, selector) do
    module = object.__struct__
    present = [:object_type | Enum.map(module.get_properties(object), &external_name/1)]

    names =
      case selector do
        :all ->
          present ++ Map.keys(object._unknown_properties)

        :required ->
          Enum.filter(
            present,
            &(&1 in [
                :object_type
                | Enum.map(module.get_required_properties(), fn name -> external_name(name) end)
              ])
          )

        :optional ->
          Enum.filter(present, &(&1 in module.get_optional_properties()))
      end

    names |> Enum.reject(&(&1 == :property_list)) |> Enum.sort()
  end

  @spec external_name(atom()) :: atom()
  defp external_name(name)
  defp external_name(:object_instance), do: :object_identifier
  defp external_name(name), do: name

  @spec read_value(pid(), DeviceObjectPropertyRef.t(), Context.t()) ::
          {:ok, term()} | {:error, term()}
  defp read_value(store, reference, ctx) do
    if MapSet.member?(
         snapshot(store).denied,
         {reference.object_identifier, reference.property_identifier}
       ) do
      {:error, %BACnetError{class: :property, code: :read_access_denied}}
    else
      source = snapshot(store).sources[reference.object_identifier]

      read_ctx = %{
        ctx
        | state: source.state,
          trigger: {:property_read, reference.property_identifier, reference.property_array_index}
      }

      with {:ok, refreshed} <- Lifecycle.prepare_read(source.object, read_ctx) do
        retain_source(store, reference.object_identifier, refreshed)
        native_value(refreshed.object, reference.property_identifier)
      end
    end
  end

  @spec native_value(struct(), atom() | non_neg_integer()) :: {:ok, term()} | {:error, term()}
  defp native_value(object, property)

  defp native_value(object, :object_identifier),
    do: {:ok, object.__struct__.get_object_identifier(object)}

  defp native_value(object, :object_type),
    do: {:ok, object.__struct__.get_object_identifier(object).type}

  defp native_value(object, property), do: object.__struct__.get_property(object, property)

  @spec results(pid()) :: [ReadResult.t()]
  defp results(store), do: Enum.flat_map(snapshot(store).group.object.present_value, & &1.results)

  @spec retain_group(pid(), Result.t()) :: :ok
  defp retain_group(store, result), do: Agent.update(store, &%{&1 | group: result})

  @spec retain_source(pid(), ObjectIdentifier.t(), Result.t()) :: :ok
  defp retain_source(store, identifier, result),
    do: Agent.update(store, &%{&1 | sources: Map.put(&1.sources, identifier, result)})

  @spec snapshot(pid()) :: map()
  defp snapshot(store), do: Agent.get(store, & &1)

  @spec displayed_value(Encoding.t() | [Encoding.t()]) :: term()
  defp displayed_value(value)
  defp displayed_value(%Encoding{value: value}), do: value
  defp displayed_value(values), do: Enum.map(values, & &1.value)

  @spec show(pid(), String.t()) :: :ok
  defp show(store, label) do
    values =
      Enum.map(results(store), fn result ->
        if result.error,
          do: {:error, result.error.class, result.error.code},
          else: displayed_value(result.property_value)
      end)

    IO.puts("#{label}: #{inspect(values, limit: 8)}")
  end
end

:ok = BACnet.Examples.GroupLifecycle.run()
