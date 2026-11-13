defmodule BACnet.Protocol.ObjectTypes.NotificationClass do
  @moduledoc """
  A Notification Class determines where an event notification should go and
  how to send it. Event sources reference the class by its Notification_Class
  number. The class defines these settings.

  - per-transition priorities (to-offnormal, to-fault, to-normal)
  - whether each transition requires operator acknowledgment
  - the recipients and their valid days, time windows, and process identifiers

  Because many objects can share the same Notification Class, a site can enforce
  consistent alarming policy (e.g. "all critical alarms go to the BMS at priority 8
  and require ack") without repeating the recipient list in every object.

  ### Object Description (ASHRAE 135)

  > The Notification Class object type defines a standardized object that represents
  > and contains information required for the distribution of event notifications
  > within BACnet systems.

  ### Behaviour and Operation

  Use `routing_plan/3` when an event transition needs routing. Supply the
  transition and the device's local date and time. A destination is eligible
  when its day and transition bits are set and the time is within its inclusive
  window. Each matching `BACnet.Protocol.Destination` retains the recipient,
  process identifier, and confirmed or unconfirmed delivery setting. The plan
  includes the configured transition priority and acknowledgment flag and maps
  the priority to a BACnet network priority.

  Use `add_destination/2` and `remove_destination/2` to edit Recipient_List one
  entry at a time. Entries are matched by the complete destination, so a
  recipient can have multiple entries with different delivery settings.

  ### Host responsibilities

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  needs to look up the class referenced by the event source and apply the source's
  Event_Enable and Notify_Type rules. It needs to resolve recipient device
  identifiers, deliver the notifications, and track acknowledgments on the event
  source. The plan reports the class's acknowledgment flag. When building a
  notification, the host needs to apply source-specific rules for Access Point
  and Alert Enrollment and omit AckRequired from acknowledgment notifications.

  Recipient_List entries do not expire. The host needs to persist the configured
  list across restarts. If the host exposes Recipient_List as read-only, it needs
  to meet the local forwarder or local broadcast requirements in ASHRAE 135-2016
  Clause 12.21.8. Recipient_List filtering applies to external notification
  distribution. Delivery to local objects such as Event Logs is handled by the
  host under Clause 13.2.5.

  For a BACnet RemoveListElement request, a `false` removal result indicates
  `LIST_ELEMENT_NOT_FOUND`. The host needs to apply access checks and commit
  a multi-element update only when the entire request succeeds.

  Routing needs no lifecycle state or timer. Event detection and notification
  delivery are driven by the integrating application.

  ### Examples

  Route a Monday morning TO_OFFNORMAL transition to a confirmed recipient.

      iex> alias BACnet.Protocol.{BACnetTime, DaysOfWeek, Destination, EventTransitionBits}
      iex> alias BACnet.Protocol.{NotificationClassPriority, ObjectIdentifier, Recipient}
      iex> alias BACnet.Protocol.ObjectTypes.NotificationClass
      iex> offnormal = %EventTransitionBits{to_offnormal: true, to_fault: false, to_normal: false}
      iex> workstation = %Recipient{
      ...>   type: :device,
      ...>   device: %ObjectIdentifier{type: :device, instance: 123},
      ...>   address: nil
      ...> }
      iex> destination = %Destination{
      ...>   recipient: workstation,
      ...>   process_identifier: 10,
      ...>   issue_confirmed_notifications: true,
      ...>   transitions: offnormal,
      ...>   valid_days: DaysOfWeek.from_bitstring({true, true, true, true, true, false, false}),
      ...>   from_time: BACnetTime.from_time(~T[08:00:00]),
      ...>   to_time: BACnetTime.from_time(~T[18:00:00])
      ...> }
      iex> {:ok, class} = NotificationClass.create(700, "Alarms", %{
      ...>   notification_class: 700,
      ...>   priority: %NotificationClassPriority{to_offnormal: 8, to_fault: 80, to_normal: 220},
      ...>   ack_required: offnormal
      ...> })
      iex> {:ok, class} = NotificationClass.add_destination(class, destination)
      iex> plan = NotificationClass.routing_plan(class, :to_offnormal, ~U[2026-11-09 08:00:00Z])
      iex> {plan.priority, plan.network_priority, plan.ack_required}
      {8, :life_safety_message, true}
      iex> [target] = plan.destinations
      iex> {target.process_identifier, target.issue_confirmed_notifications}
      {10, true}
      iex> {:ok, class, true} = NotificationClass.remove_destination(class, destination)
      iex> {:ok, ^class, removed} = NotificationClass.remove_destination(class, destination)
      iex> removed
      false

  ### See Also
  - `BACnet.Protocol.Destination`
  - `BACnet.Protocol.EventTransitionBits`
  - `BACnet.Protocol.NotificationClassPriority`
  """

  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DaysOfWeek
  alias BACnet.Protocol.Destination
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.NotificationClassPriority
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Notification Class object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Class settings and eligible destinations for a single transition.

  `ack_required` is the configured bit for the transition. `destinations`
  contains the matching entries from Recipient_List in their original order.
  """
  @type routing_plan :: %{
          priority: 0..255,
          network_priority: Constants.npdu_control_priority(),
          ack_required: boolean(),
          destinations: [Destination.t()]
        }

  @typedoc """
  Represents a Notification Class object. Treat struct fields as read-only and
  use the property operations or destination helpers to update the object.
  """
  bac_object Constants.macro_assert_name(:object_type, :notification_class) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:notification_class, non_neg_integer(), required: true)

    field(:priority, NotificationClassPriority.t(),
      required: true,
      default: %NotificationClassPriority{}
    )

    field(:ack_required, EventTransitionBits.t(),
      required: true,
      default: ObjectsMacro.get_default_event_transbits()
    )

    field(:recipient_list, [Destination.t()], required: true, default: [])
  end

  @doc """
  Appends a destination to Recipient_List. If the complete destination already
  exists, returns the original object. Existing entries keep their order.
  """
  @doc group: "Functions Operational"
  @spec add_destination(t(), Destination.t()) :: {:ok, t()} | property_update_error()
  def add_destination(%__MODULE__{} = object, %Destination{} = destination) do
    with {:ok, destinations} <- get_property(object, :recipient_list) do
      if destination in destinations do
        {:ok, object}
      else
        update_property(object, :recipient_list, List.insert_at(destinations, -1, destination))
      end
    end
  end

  @doc """
  Removes all entries equal to the complete destination. The other entries
  keep their order. Returns `{:ok, updated, true}` when an entry was removed,
  or `{:ok, object, false}` if the destination was absent.
  """
  @doc group: "Functions Operational"
  @spec remove_destination(t(), Destination.t()) ::
          {:ok, updated :: t(), removed :: boolean()} | property_update_error()
  def remove_destination(%__MODULE__{} = object, %Destination{} = destination) do
    with {:ok, destinations} <- get_property(object, :recipient_list) do
      case Enum.reject(destinations, &(&1 === destination)) do
        ^destinations ->
          {:ok, object, false}

        remaining ->
          with {:ok, updated} <- update_property(object, :recipient_list, remaining) do
            {:ok, updated, true}
          end
      end
    end
  end

  @doc """
  Selects the destinations and class settings for a transition.

  Pass a datetime expressed in the device's local timezone. The date determines
  the weekday and the time is evaluated at BACnet's hundredth-of-a-second
  precision. Both endpoints are included. Each window applies within a single
  day. To cover both sides of midnight, configure separate windows.

  A transition with no matching recipients still returns its priority and
  acknowledgment settings. Network priority follows ASHRAE 135-2016 Table 13-6.
  """
  @doc group: "Functions Operational"
  @spec routing_plan(t(), Constants.event_transition_bit(), DateTime.t()) :: routing_plan()
  def routing_plan(%__MODULE__{} = object, transition, %DateTime{} = local_datetime)
      when transition in [:to_offnormal, :to_fault, :to_normal] do
    day_index = Date.day_of_week(DateTime.to_date(local_datetime)) - 1
    local_time = DateTime.to_time(local_datetime)

    time =
      local_time
      |> BACnetTime.from_time()
      |> BACnetTime.to_time!(local_time)

    priority = Map.fetch!(object.priority, transition)

    %{
      priority: priority,
      network_priority: network_priority(priority),
      ack_required: Map.fetch!(object.ack_required, transition),
      destinations:
        Enum.filter(object.recipient_list, &eligible?(&1, transition, day_index, time))
    }
  end

  @spec eligible?(Destination.t(), Constants.event_transition_bit(), 0..6, Time.t()) ::
          boolean()
  defp eligible?(destination, transition, day_index, time) do
    {:bitstring, days} = DaysOfWeek.to_bitstring(destination.valid_days)

    elem(days, day_index) and Map.fetch!(destination.transitions, transition) and
      Time.compare(time, BACnetTime.to_time!(destination.from_time, time)) != :lt and
      Time.compare(time, BACnetTime.to_time!(destination.to_time, time)) != :gt
  end

  @spec network_priority(0..255) :: Constants.npdu_control_priority()
  defp network_priority(priority) do
    case div(priority, 64) do
      0 -> :life_safety_message
      1 -> :critical_equipment_message
      2 -> :urgent
      3 -> :normal
    end
  end
end
