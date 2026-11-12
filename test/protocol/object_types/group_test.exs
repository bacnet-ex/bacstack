defmodule BACnet.Test.Protocol.ObjectTypes.GroupTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.AccessSpecification.Property
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.AnalogValue
  alias BACnet.Protocol.ObjectTypes.Averaging
  alias BACnet.Protocol.ObjectTypes.Group
  alias BACnet.Protocol.ReadAccessResult
  alias BACnet.Protocol.ReadAccessResult.ReadResult
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  @moduletag :object_test
  @now ~U[2026-11-09 08:00:00Z]
  doctest Group

  test "members must be supplied and contain at least one read specification" do
    assert {:error, {:missing_required_property, :list_of_group_members}} =
             Group.create(1, "View")

    assert {:error, {:value_failed_property_validation, :list_of_group_members}} =
             Group.create(1, "View", %{list_of_group_members: []})

    refute Group.property_writable?(object(), :present_value)
    assert Group.property_writable?(object(), :list_of_group_members)
  end

  test "each present-value read reacquires members even with identical clocks and retained state" do
    parent = self()

    ctx =
      context({:property_read, :present_value, nil},
        read_property: fn reference ->
          send(parent, reference)
          {:ok, enc(:real, 12.5)}
        end
      )

    assert {:ok, first} = Lifecycle.prepare_read(object(), ctx)

    assert_received %DeviceObjectPropertyRef{
      device_identifier: nil,
      property_identifier: :present_value
    }

    assert first.state == :retained
    assert first.next_execution == nil

    assert [%ReadAccessResult{results: [%ReadResult{property_value: value, error: nil}]}] =
             first.object.present_value

    assert value == enc(:real, 12.5)
    assert {:ok, second} = Lifecycle.prepare_read(first.object, %{ctx | state: first.state})
    assert second == first
    assert_received %DeviceObjectPropertyRef{}
  end

  test "later reads replace the previous value and never serve the stored value as fresh" do
    first = read(object(), fn _reference -> {:ok, enc(:real, 1.0)} end)
    second = read(first.object, fn _reference -> {:ok, enc(:real, 2.0)} end)
    assert hd(hd(first.object.present_value).results).property_value.value == 1.0
    assert hd(hd(second.object.present_value).results).property_value.value == 2.0

    assert {:error, {:unsupported_operation, :read_property}} =
             Lifecycle.prepare_read(second.object, context({:property_read, :present_value, nil}))
  end

  test "member/property ordering, duplicates, numeric identifiers and array indices are retained" do
    members = [
      member(2, [property(85), property(:priority_array, 0), property(:priority_array, 4)]),
      member(3, [property(:description)]),
      member(2, [property(85)])
    ]

    parent = self()

    stored =
      read(object(members), fn reference ->
        send(
          parent,
          {reference.object_identifier.instance, reference.property_identifier,
           reference.property_array_index}
        )

        {:ok, enc(:unsigned_integer, 16)}
      end)

    assert_received {2, 85, nil}
    assert_received {2, :priority_array, 0}
    assert_received {2, :priority_array, 4}
    assert_received {3, :description, nil}
    assert_received {2, 85, nil}
    assert Enum.map(stored.object.present_value, & &1.object_identifier.instance) == [2, 3, 2]

    assert Enum.map(
             hd(stored.object.present_value).results,
             &{&1.property_identifier, &1.property_array_index}
           ) == [{85, nil}, {:priority_array, 0}, {:priority_array, 4}]
  end

  test "encoding lists, empty values and NULL are preserved without conversion" do
    values = [[enc(:unsigned_integer, 2), enc(:null, nil)], [], enc(:null, nil)]

    for value <- values do
      stored = read(object(), fn _reference -> {:ok, value} end)
      assert hd(hd(stored.object.present_value).results).property_value == value
    end
  end

  test "selectors expand through multiple-property maps and retain request ordering" do
    members = [member(2, [:all, property(:present_value), :required, :optional])]
    parent = self()

    multiple = fn reference, [selector] ->
      assert reference.device_identifier == nil
      assert reference.object_identifier.instance == 2
      send(parent, {:read, selector})

      case selector do
        :all ->
          {:ok, %{600 => enc(:unsigned_integer, 7), object_name: "Source", property_list: []}}

        :required ->
          {:ok, %{371 => [], present_value: 3.0}}

        :optional ->
          {:ok,
           %{description: {:error, %BACnetError{class: :property, code: :read_access_denied}}}}
      end
    end

    stored =
      read(
        object(members),
        fn reference ->
          send(parent, {:read, reference.property_identifier})
          {:ok, 2.0}
        end,
        multiple
      )

    assert_received {:read, :all}
    assert_received {:read, :present_value}
    assert_received {:read, :required}
    assert_received {:read, :optional}
    results = hd(stored.object.present_value).results

    assert Enum.map(results, & &1.property_identifier) == [
             :object_name,
             600,
             :present_value,
             :present_value,
             :description
           ]

    assert List.last(results).error.code == :read_access_denied
    assert Enum.at(results, 2).property_value == enc(:real, 2.0)
  end

  test "selector structs and numeric identifiers use the multiple-property operation" do
    {:ok, all} = Constants.by_name(:property_identifier, :all)

    for selector <- [property(:all), property(all)] do
      stored =
        read(object([member(2, [selector])]), nil, fn reference, selectors ->
          assert reference.object_identifier.instance == 2
          assert selectors == [:all]
          {:ok, %{present_value: 1.0}}
        end)

      assert hd(hd(stored.object.present_value).results).property_identifier == :present_value
    end
  end

  test "an OPTIONAL selector may expand to an empty map" do
    stored =
      read(object([member(2, [:optional])]), nil, fn _reference, [:optional] -> {:ok, %{}} end)

    assert [%ReadAccessResult{results: []}] = stored.object.present_value
  end

  test "an unavailable selection retains its access error and following reads continue" do
    stored =
      read(
        object([member(2, [:all, property(:object_name)])]),
        fn _reference -> {:ok, "Recovered"} end,
        fn _reference, [:all] -> {:error, :unknown_object} end
      )

    assert [error, success] = hd(stored.object.present_value).results
    assert error.property_identifier == :all
    assert error.error == %BACnetError{class: :object, code: :unknown_object}
    assert success.property_value.value == "Recovered"
  end

  test "per-property failures do not abort following properties or members" do
    object = object([member(2, [property(:present_value), property(:description)]), member(3)])

    stored =
      read(object, fn reference ->
        case {reference.object_identifier.instance, reference.property_identifier} do
          {2, :present_value} -> {:error, :read_access_denied}
          {2, :description} -> {:error, {:unknown_property, :description}}
          {3, :present_value} -> {:ok, enc(:real, 5.0)}
        end
      end)

    assert [first, second] = stored.object.present_value
    assert Enum.map(first.results, & &1.error.code) == [:read_access_denied, :unknown_property]
    assert hd(second.results).property_value.value == 5.0
  end

  test "recognized library errors become BACnet access errors" do
    for {reason, class, code} <- [
          {:unknown_object, :object, :unknown_object},
          {{:unknown_property_identifier, 600}, :property, :unknown_property},
          {:invalid_array_index, :property, :invalid_array_index},
          {:property_is_not_an_array, :property, :property_is_not_an_array},
          {:read_access_denied, :property, :read_access_denied},
          {:invalid_datatype, :property, :invalid_datatype},
          {:timeout, :device, :operational_problem},
          {:cyclic_execution, :device, :operational_problem}
        ] do
      stored = read(object(), fn _reference -> {:error, reason} end)

      assert hd(hd(stored.object.present_value).results).error == %BACnetError{
               class: class,
               code: code
             }
    end
  end

  test "BACnet error class and code, including vendor codes, are preserved" do
    for error <- [
          %BACnetError{class: :resources, code: :no_space_for_object},
          %BACnetError{class: 64, code: 600}
        ] do
      stored = read(object(), fn _reference -> {:error, error} end)
      assert hd(hd(stored.object.present_value).results).error == error
    end
  end

  test "all failed members still produce an encodable result" do
    stored = read(object(), fn _reference -> {:error, :unknown_object} end)
    assert ReadAccessResult.valid?(hd(stored.object.present_value))
    assert {:ok, tags} = ReadAccessResult.encode(hd(stored.object.present_value))
    {:ok, wire} = ApplicationTags.encode({:constructed, {0, tags, 0}})
    {:ok, {:constructed, {0, decoded, 0}}, <<>>} = ApplicationTags.decode(wire)
    assert {:ok, {result, []}} = ReadAccessResult.parse(decoded)
    assert result == hd(stored.object.present_value)
  end

  test "mixed success and error results round-trip through the wire codec" do
    stored =
      read(
        object([member(2, [property(:present_value), property(:description)])]),
        fn reference ->
          if reference.property_identifier == :present_value,
            do: {:ok, [enc(:real, 2.5), enc(:unsigned_integer, 4)]},
            else: {:error, :read_access_denied}
        end
      )

    original = hd(stored.object.present_value)
    {:ok, tags} = ReadAccessResult.encode(original)
    {:ok, wire} = ApplicationTags.encode({:constructed, {0, tags, 0}})
    {:ok, {:constructed, {0, decoded, 0}}, <<>>} = ApplicationTags.decode(wire)
    assert {:ok, {^original, []}} = ReadAccessResult.parse(decoded)
  end

  test "Group and Global Group present-value nesting is rejected for all identifier forms" do
    for type <- [:group, :global_group],
        selector <- [:present_value, 85, :all, :required, 8, 105] do
      specification = %AccessSpecification{
        object_identifier: %ObjectIdentifier{type: type, instance: 2},
        properties: [property(selector)]
      }

      assert {:error, {:value_failed_property_validation, :list_of_group_members}} =
               Group.create(1, "Nested", %{list_of_group_members: [specification]})
    end
  end

  test "Group metadata and OPTIONAL selection are permitted without nesting values" do
    for type <- [:group, :global_group], property <- [property(:object_name), :optional] do
      specification = %AccessSpecification{
        object_identifier: %ObjectIdentifier{type: type, instance: 2},
        properties: [property]
      }

      stored =
        read(
          object([specification]),
          fn _reference -> {:ok, enc(:character_string, "Group name")} end,
          fn _reference, [:optional] ->
            {:ok, %{description: enc(:character_string, "Metadata")}}
          end
        )

      assert hd(hd(stored.object.present_value).results).error == nil
    end
  end

  test "empty properties, write values and selector indices are invalid configuration" do
    for properties <- [
          [],
          [property(:all, 0)],
          [
            %Property{
              property_identifier: :present_value,
              property_array_index: nil,
              property_value: enc(:real, 1.0)
            }
          ]
        ] do
      assert {:error, _reason} =
               Group.create(1, "Invalid", %{list_of_group_members: [member(2, properties)]})
    end

    for members <- [[], [:invalid]] do
      malformed = %{object() | list_of_group_members: members}

      assert {:error, {:invalid_configuration, :list_of_group_members}} =
               Lifecycle.execute(malformed, context(:initialization))
    end
  end

  test "descriptive writes keep the current read results" do
    stored = read(object(), fn _ref -> {:ok, 9.0} end)
    assert {:ok, candidate} = Group.add_property(stored.object, :description, "Metadata")
    write = context({:property_write, :description, nil, nil})
    assert {:ok, ^candidate} = Group.prepare_write(stored.object, candidate, write)
    assert candidate.present_value == stored.object.present_value
  end

  test "initialization and unrelated triggers require no callbacks and perform no reads" do
    first = read(object(), fn _reference -> {:ok, enc(:real, 7.0)} end)

    for trigger <- [
          :initialization,
          :periodic,
          :timer,
          :clock_change,
          :continuation,
          {:property_read, :object_name, nil},
          {:property_read, :optional, nil}
        ] do
      assert {:ok, result} = Lifecycle.execute(first.object, context(trigger))
      assert result.next_execution == nil
      assert result.state == :retained
      expected = if trigger == :initialization, do: [], else: first.object.present_value
      assert result.object.present_value == expected
    end
  end

  test "top-level PV, ALL and REQUIRED read triggers refresh, including numeric identifiers" do
    for property <- [:present_value, 85, :all, 8, :required, 105] do
      ctx =
        context({:property_read, property, nil},
          read_property: fn _reference -> {:ok, enc(:real, 9.0)} end
        )

      assert {:ok, result} = Lifecycle.prepare_read(object(), ctx)
      assert hd(hd(result.object.present_value).results).property_value.value == 9.0
    end
  end

  test "present_value is a list, so indexed reads are rejected before member I/O" do
    for index <- [0, 1] do
      assert {:error, :property_is_not_an_array} =
               Lifecycle.prepare_read(
                 object(),
                 context({:property_read, :present_value, index},
                   read_property: fn _reference -> flunk("must not read") end
                 )
               )
    end
  end

  test "present-value writes are denied before acceptance for named and numeric identifiers" do
    for property <- [:present_value, 85] do
      assert {:error, {:write_access_denied, :present_value}} =
               Lifecycle.prepare_write(
                 object(),
                 object(),
                 context({:property_write, property, nil, nil})
               )
    end
  end

  test "membership changes clear the old value before commit without member I/O" do
    stored = read(object(), fn _reference -> {:ok, enc(:real, 1.0)} end)

    for property <- [:list_of_group_members, 53] do
      {:ok, candidate} = Group.update_property(stored.object, :list_of_group_members, [member(3)])
      ctx = context({:property_write, property, nil, nil})
      assert {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
      assert prepared.present_value == []
      assert {:ok, committed} = Lifecycle.execute(prepared, ctx)
      assert committed.object.list_of_group_members == [member(3)]
      assert committed.object.present_value == []

      refreshed =
        read(committed.object, fn reference ->
          assert reference.object_identifier.instance == 3
          {:ok, enc(:real, 3.0)}
        end)

      assert hd(hd(refreshed.object.present_value).results).property_value.value == 3.0
    end
  end

  test "invalid membership writes leave the original result usable" do
    object = object()
    assert {:error, _reason} = Group.update_property(object, :list_of_group_members, [])
    invalid = %{object | list_of_group_members: [member(2, [])]}

    assert {:error, {:invalid_configuration, :list_of_group_members}} =
             Lifecycle.prepare_write(
               object,
               invalid,
               context({:property_write, :list_of_group_members, nil, nil})
             )

    assert {:ok, _result} = Lifecycle.execute(object, context(:initialization))
  end

  test "malformed callback results and exceptions remain programming errors" do
    for value <- [
          enc(:real, 1.0),
          [value(:present_value, enc(:real, 1.0))],
          %{all: 1.0},
          %{{:present_value, -1} => 1.0}
        ] do
      assert_raise ArgumentError, fn ->
        read(object([member(2, [:all])]), nil, fn _reference, _properties -> {:ok, value} end)
      end
    end

    assert_raise ArgumentError, fn ->
      read(object(), fn _reference -> {:error, %BACnetError{class: :unknown, code: :unknown}} end)
    end

    assert_raise CaseClauseError, fn -> read(object(), fn _reference -> :invalid end) end

    assert_raise RuntimeError, "callback failed", fn ->
      read(object(), fn _reference -> raise "callback failed" end)
    end
  end

  test "multiple-property maps cannot introduce forbidden nested values" do
    spec = %AccessSpecification{
      object_identifier: %ObjectIdentifier{type: :group, instance: 2},
      properties: [:optional]
    }

    assert_raise ArgumentError, fn ->
      read(object([spec]), nil, fn _reference, _properties -> {:ok, %{present_value: []}} end)
    end
  end

  test "remote snapshots remain passive regardless of local member restrictions" do
    local = object()

    remote = %{
      local
      | list_of_group_members: [],
        _metadata: %{local._metadata | remote_object: 42}
    }

    assert :ok = Group.validate_execution(remote, context(:initialization))
    write = context({:property_write, :list_of_group_members, nil, nil})

    assert {:error, :operation_not_available_for_remote_objects} =
             Group.prepare_write(remote, remote, write)

    for trigger <- [:initialization, {:property_read, :present_value, nil}] do
      assert {:ok, %Result{object: ^remote, state: :retained, next_execution: nil}} =
               Lifecycle.execute(remote, context(trigger))

      assert {:ok, _result} = Group.execute(remote, context(trigger))
    end

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(
               remote,
               remote,
               context({:property_write, :list_of_group_members, nil, nil})
             )
  end

  test "intrinsic reporting creation stays unsupported but does not block lifecycle execution" do
    assert_raise ArgumentError, fn ->
      Group.create(1, "IR", %{list_of_group_members: [member(2)]}, intrinsic_reporting: true)
    end

    object = object()
    intrinsic = %{object | _metadata: %{object._metadata | intrinsic_reporting: true}}

    assert {:ok, %Result{object: initialized}} =
             Lifecycle.execute(intrinsic, context(:initialization))

    assert initialized._metadata.intrinsic_reporting
  end

  test "a computed dependency is refreshed through the host before it is encoded" do
    {:ok, source} = AnalogValue.create(2, "Source", %{present_value: 14.0})

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: AnalogValue.get_object_identifier(source),
      property_identifier: :present_value,
      property_array_index: nil
    }

    {:ok, average} =
      Averaging.create(3, "Mean", %{window_interval: 15, object_property_reference: reference})

    host = Host.new([{source, []}, {average, []}], @now, 0)
    assert :ok = Host.execute(host, AnalogValue.get_object_identifier(source), :initialization)
    assert :ok = Host.execute(host, Averaging.get_object_identifier(average), :initialization)
    Host.advance(host, DateTime.add(@now, 1000, :millisecond), 1000)

    ctx =
      context({:property_read, :present_value, nil},
        monotonic_time: 1000,
        now: DateTime.add(@now, 1000, :millisecond),
        read_property: fn reference -> Host.read(host, reference) end
      )

    spec = %AccessSpecification{
      object_identifier: Averaging.get_object_identifier(average),
      properties: [property(:average_value)]
    }

    assert {:ok, result} = Lifecycle.prepare_read(object([spec]), ctx)
    assert hd(hd(result.object.present_value).results).property_value == enc(:real, 14.0)
    assert Host.snapshot(host, Averaging.get_object_identifier(average)).object.valid_samples == 1
  end

  test "native values are converted through the property codec, including indexed array values" do
    spec =
      member(2, [
        property(:present_value),
        property(:priority_array, 0),
        property(:priority_array, 4)
      ])

    stored =
      read(object([spec]), fn reference ->
        case {reference.property_identifier, reference.property_array_index} do
          {:present_value, nil} -> {:ok, 12.5}
          {:priority_array, 0} -> {:ok, 16}
          {:priority_array, 4} -> {:ok, 2.5}
        end
      end)

    assert Enum.map(hd(stored.object.present_value).results, & &1.property_value) ==
             [enc(:real, 12.5), enc(:unsigned_integer, 16), enc(:real, 2.5)]
  end

  test "native virtual properties and null values are encoded without a wire-level callback" do
    spec =
      member(2, [
        property(:object_identifier),
        property(:object_type),
        property(:property_list),
        property(:priority_array, 4)
      ])

    stored =
      read(object([spec]), fn reference ->
        case reference.property_identifier do
          :object_identifier -> {:ok, reference.object_identifier}
          :object_type -> {:ok, :analog_value}
          :property_list -> {:ok, [:present_value, :object_name]}
          :priority_array -> {:ok, nil}
        end
      end)

    assert [id, type, properties, null] = hd(stored.object.present_value).results
    assert id.property_value == enc(:object_identifier, spec.object_identifier)
    assert type.property_value == enc(:enumerated, 2)
    assert properties.property_value == [enc(:enumerated, 85), enc(:enumerated, 77)]
    assert null.property_value == enc(:null, nil)
  end

  test "native property-list arrays are encoded as property identifiers" do
    array = BACnetArray.from_list([:present_value, :object_name])

    stored =
      read(object([member(2, [property(:property_list)])]), fn _reference -> {:ok, array} end)

    assert hd(hd(stored.object.present_value).results).property_value ==
             [enc(:enumerated, 85), enc(:enumerated, 77)]
  end

  test "expanded indexed properties retain vendor enumeration values" do
    stored =
      read(
        object([member(2, [:optional])]),
        fn _ref -> flunk("expected a multiple-property read") end,
        fn _ref, [:optional] -> {:ok, %{{:property_list, 1} => 600}} end
      )

    assert [
             %ReadResult{
               property_identifier: :property_list,
               property_array_index: 1,
               property_value: value
             }
           ] =
             hd(stored.object.present_value).results

    assert value == enc(:enumerated, 600)
  end

  test "invalid native enumeration values yield per-property errors" do
    for {property, value} <- [
          {:object_type, :unknown_type},
          {:object_type, "analog-value"},
          {:property_list, [:present_value, :unknown_property_name]},
          {:property_list, "present-value"}
        ] do
      stored = read(object([member(2, [property(property)])]), fn _ref -> {:ok, value} end)

      assert [%ReadResult{error: %BACnetError{class: :property, code: :invalid_datatype}}] =
               hd(stored.object.present_value).results
    end
  end

  test "unencodable native values become access errors and do not stop subsequent reads" do
    stored =
      read(
        object([member(2, [property(:present_value), property(:object_name)])]),
        fn reference ->
          if reference.property_identifier == :present_value,
            do: {:ok, "not a real"},
            else: {:ok, "Source"}
        end
      )

    assert [failure, success] = hd(stored.object.present_value).results
    assert failure.error == %BACnetError{class: :property, code: :invalid_datatype}
    assert success.property_value.value == "Source"
  end

  test "native array reads preserve their values and ordering" do
    spec = %AccessSpecification{
      object_identifier: %ObjectIdentifier{type: :multi_state_value, instance: 2},
      properties: [property(:state_text)]
    }

    array = BACnetArray.from_list(["Off", "On", "Off"])
    stored = read(object([spec]), fn _reference -> {:ok, array} end)

    assert hd(hd(stored.object.present_value).results).property_value ==
             Enum.map(["Off", "On", "Off"], &enc(:character_string, &1))
  end

  test "preflight requires only the operations used by the requested configuration" do
    explicit = object()
    selector = object([member(2, [:all])])

    ctx =
      context({:property_read, :present_value, nil},
        read_property: fn _reference -> {:ok, 1.0} end
      )

    assert :ok = Group.validate_execution(explicit, ctx)

    assert {:error, {:unsupported_operation, :read_property_multiple}} =
             Group.validate_execution(selector, ctx)

    multiple_ctx = %{
      ctx
      | read_property: nil,
        read_property_multiple: fn _reference, _properties -> {:ok, %{}} end
    }

    assert :ok = Group.validate_execution(selector, multiple_ctx)

    assert {:error, {:unsupported_operation, :read_property}} =
             Group.validate_execution(explicit, multiple_ctx)
  end

  defp member(instance, properties \\ [property(:present_value)]),
    do: %AccessSpecification{
      object_identifier: %ObjectIdentifier{type: :analog_value, instance: instance},
      properties: properties
    }

  defp property(name, index \\ nil),
    do: %Property{property_identifier: name, property_array_index: index, property_value: nil}

  defp object(members \\ [member(2)]) do
    {:ok, object} = Group.create(1, "View", %{list_of_group_members: members})
    object
  end

  defp context(trigger, options \\ []),
    do:
      Context.new(
        trigger,
        Keyword.merge([now: @now, monotonic_time: 0, state: :retained], options)
      )

  defp read(object, callback, multiple \\ nil) do
    {:ok, result} =
      Lifecycle.prepare_read(
        object,
        context({:property_read, :present_value, nil},
          read_property: callback,
          read_property_multiple: multiple
        )
      )

    result
  end

  defp enc(type, value), do: Encoding.create!({type, value})

  defp value(property, value),
    do: %ReadResult{
      property_identifier: property,
      property_array_index: nil,
      property_value: value,
      error: nil
    }
end
