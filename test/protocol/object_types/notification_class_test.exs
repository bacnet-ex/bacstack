defmodule BACnet.Test.Protocol.ObjectTypes.NotificationClassTest do
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.DaysOfWeek
  alias BACnet.Protocol.Destination
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.NotificationClassPriority
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.NotificationClass
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.RecipientAddress

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_notification_class

  @monday ~U[2026-11-09 12:00:00Z]
  @monday_only DaysOfWeek.from_bitstring({true, false, false, false, false, false, false})
  @all_days DaysOfWeek.from_bitstring({true, true, true, true, true, true, true})
  @offnormal_only %EventTransitionBits{to_offnormal: true, to_fault: false, to_normal: false}
  @all_transitions %EventTransitionBits{to_offnormal: true, to_fault: true, to_normal: true}

  test "adds only new destinations and preserves order" do
    first = destination(2)
    second = %{first | from_time: BACnetTime.from_time(~T[10:00:00])}
    class = create(%{recipient_list: [first]})

    assert {:ok, ^class} = NotificationClass.add_destination(class, first)

    assert {:ok, %{recipient_list: [^first, ^second]} = updated} =
             NotificationClass.add_destination(class, second)

    assert {:ok, ^updated} = NotificationClass.add_destination(updated, second)

    assert {:error, {:invalid_property_type, :recipient_list}} =
             NotificationClass.add_destination(updated, %{first | process_identifier: -1})
  end

  test "removes all complete matches and reports a missing destination" do
    first = destination(2)
    second = %{first | from_time: BACnetTime.from_time(~T[10:00:00])}
    third = destination(1)
    class = create(%{recipient_list: [first, second, first, third]})

    assert {:ok, %{recipient_list: [^second, ^third]} = updated, true} =
             NotificationClass.remove_destination(class, first)

    assert {:ok, ^updated, false} = NotificationClass.remove_destination(updated, first)
  end

  test "selects by weekday, time and transition and retains matching destinations in order" do
    first = destination(2)

    second = %{
      destination(1)
      | recipient: %Recipient{
          type: :address,
          device: nil,
          address: %RecipientAddress{network: 0, address: <<7>>}
        },
        issue_confirmed_notifications: false
    }

    wrong_day = %{first | valid_days: %{first.valid_days | monday: false, tuesday: true}}
    wrong_time = %{first | to_time: BACnetTime.from_time(~T[11:00:00])}
    wrong_transition = %{first | transitions: %{first.transitions | to_offnormal: false}}

    class = create(%{recipient_list: [wrong_day, first, wrong_time, wrong_transition, second]})

    assert %{destinations: [^first, ^second]} =
             NotificationClass.routing_plan(class, :to_offnormal, @monday)
  end

  test "time windows include both endpoints at BACnet precision" do
    target = %{
      destination(1)
      | from_time: BACnetTime.from_time(~T[08:00:00.05]),
        to_time: BACnetTime.from_time(~T[18:00:00.10])
    }

    class = create(%{recipient_list: [target]})

    for time <- [~U[2026-11-09 08:00:00.05Z], ~U[2026-11-09 18:00:00.109999Z]] do
      assert %{destinations: [^target]} =
               NotificationClass.routing_plan(class, :to_offnormal, time)
    end

    for time <- [~U[2026-11-09 08:00:00.049999Z], ~U[2026-11-09 18:00:00.11Z]] do
      assert %{destinations: []} = NotificationClass.routing_plan(class, :to_offnormal, time)
    end
  end

  test "uses the supplied local day and supports the last hundredth of an all-day window" do
    midnight = %{
      destination(1)
      | from_time: BACnetTime.from_time(~T[00:00:00]),
        to_time: BACnetTime.from_time(~T[23:59:59.99])
    }

    class = create(%{recipient_list: [midnight]})

    local_monday = %{
      ~U[2026-11-09 00:05:00Z]
      | time_zone: "Europe/Zurich",
        zone_abbr: "CET",
        utc_offset: 3600
    }

    assert %{destinations: [^midnight]} =
             NotificationClass.routing_plan(class, :to_offnormal, local_monday)

    assert %{destinations: []} =
             NotificationClass.routing_plan(class, :to_offnormal, ~U[2026-11-08 23:05:00Z])

    assert %{destinations: [^midnight]} =
             NotificationClass.routing_plan(class, :to_offnormal, ~U[2026-11-09 23:59:59.999999Z])
  end

  test "windows apply within a day" do
    target = %{
      destination(1)
      | from_time: BACnetTime.from_time(~T[23:00:00]),
        to_time: BACnetTime.from_time(~T[01:00:00]),
        valid_days: @all_days
    }

    class = create(%{recipient_list: [target]})

    for time <- [~U[2026-11-09 23:30:00Z], ~U[2026-11-10 00:30:00Z]] do
      assert %{destinations: []} = NotificationClass.routing_plan(class, :to_offnormal, time)
    end
  end

  test "uses the selected transition's priority and acknowledgment bit even without recipients" do
    class =
      create(%{
        priority: %NotificationClassPriority{to_offnormal: 0, to_fault: 64, to_normal: 255},
        ack_required: %{@all_transitions | to_fault: false}
      })

    for {transition, priority, network_priority, ack_required} <- [
          {:to_offnormal, 0, :life_safety_message, true},
          {:to_fault, 64, :critical_equipment_message, false},
          {:to_normal, 255, :normal, true}
        ] do
      assert %{
               priority: ^priority,
               network_priority: ^network_priority,
               ack_required: ^ack_required,
               destinations: []
             } = NotificationClass.routing_plan(class, transition, @monday)
    end
  end

  test "maps each boundary to its BACnet network priority" do
    for {priority, expected} <- [
          {0, :life_safety_message},
          {63, :life_safety_message},
          {64, :critical_equipment_message},
          {127, :critical_equipment_message},
          {128, :urgent},
          {191, :urgent},
          {192, :normal},
          {255, :normal}
        ] do
      class =
        create(%{
          priority: %NotificationClassPriority{to_offnormal: priority, to_fault: 0, to_normal: 0}
        })

      assert %{network_priority: ^expected} =
               NotificationClass.routing_plan(class, :to_offnormal, @monday)
    end
  end

  defp create(properties) do
    {:ok, class} =
      NotificationClass.create(700, "Alarms", Map.put(properties, :notification_class, 700))

    class
  end

  defp destination(process_identifier) do
    %Destination{
      recipient: %Recipient{
        type: :device,
        device: %ObjectIdentifier{type: :device, instance: 123},
        address: nil
      },
      process_identifier: process_identifier,
      issue_confirmed_notifications: true,
      transitions: @offnormal_only,
      valid_days: @monday_only,
      from_time: BACnetTime.from_time(~T[08:00:00]),
      to_time: BACnetTime.from_time(~T[18:00:00])
    }
  end
end
