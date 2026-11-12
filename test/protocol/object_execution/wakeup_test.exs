defmodule BACnet.Test.Protocol.ObjectExecution.WakeupTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Wakeup

  @context %Context{
    device_identifier: nil,
    now: ~U[2026-11-07 12:00:00Z],
    timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
    monotonic_time: -1000,
    trigger: :timer,
    state: nil,
    lookup_object: nil,
    read_property_multiple: nil,
    read_property: nil,
    write_property: nil,
    options: []
  }

  test "wall and monotonic deadlines are inclusive, and either one is sufficient" do
    refute Wakeup.due?(%Wakeup{wall_time: nil, monotonic_time: nil}, @context)

    refute Wakeup.due?(
             %Wakeup{wall_time: DateTime.add(@context.now, 1), monotonic_time: -999},
             @context
           )

    for deadline <- [-1001, -1000] do
      assert Wakeup.due?(%Wakeup{wall_time: nil, monotonic_time: deadline}, @context)

      assert Wakeup.due?(
               %Wakeup{wall_time: DateTime.add(@context.now, 1), monotonic_time: deadline},
               @context
             )
    end

    for offset <- [-1, 0] do
      assert Wakeup.due?(
               %Wakeup{wall_time: DateTime.add(@context.now, offset), monotonic_time: nil},
               @context
             )

      assert Wakeup.due?(
               %Wakeup{wall_time: DateTime.add(@context.now, offset), monotonic_time: -999},
               @context
             )
    end
  end

  test "wall deadlines compare instants across UTC offsets" do
    deadline = %DateTime{
      @context.now
      | hour: 13,
        utc_offset: 3600,
        zone_abbr: "CET",
        time_zone: "Europe/Zurich"
    }

    assert Wakeup.due?(%Wakeup{wall_time: deadline, monotonic_time: nil}, @context)
    refute Wakeup.due?(%Wakeup{wall_time: %{deadline | second: 1}, monotonic_time: nil}, @context)
  end

  test "wall-clock adjustments do not shift monotonic deadlines" do
    wakeup = %Wakeup{wall_time: nil, monotonic_time: -500}

    for offset <- [-86_400, 86_400] do
      context = %{@context | now: DateTime.add(@context.now, offset)}
      refute Wakeup.due?(wakeup, context)
      assert Wakeup.due?(wakeup, %{context | monotonic_time: -500})
    end
  end
end
