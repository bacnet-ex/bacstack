defmodule BACnet.Protocol.ObjectTypes.NotificationClass do
  @moduledoc """
  The Notification Class object is the central configuration point for event/alarm
  routing in a BACnet device. Every object that can generate events (intrinsic or via
  Event Enrollment) references exactly one Notification Class. The class defines:

  - per-transition priorities (to-offnormal, to-fault, to-normal)
  - whether each transition requires operator acknowledgment
  - the list of recipients (who should receive the notification) together with
    optional time windows and process identifiers.

  Because many objects can share the same Notification Class, a site can enforce
  consistent alarming policy (e.g. "all critical alarms go to the BMS at priority 8
  and require ack") without repeating the recipient list in every object.

  ### Object Description (ASHRAE 135)

  > The Notification Class object type defines a standardized object that represents
  > and contains information required for the distribution of event notifications
  > within BACnet systems.

  ### Behaviour and Operation

  Notification Class objects are pure configuration objects that control *how* and
  *to whom* event notifications are sent. Multiple event-generating objects
  (intrinsic or Event Enrollments) reference the same Notification Class to get
  consistent routing, priorities, and acknowledgment requirements.

  The `recipient_list` (list of `BACnet.Protocol.Destination` entries) tells
  the notification engine which devices should receive
  Confirmed or Unconfirmed notifications for transitions, within
  optional time windows and with a given process identifier.

  `priority` and `ack_required` structs give per-transition settings. The local
  notification engine (part of the device server or a central event router) is
  responsible for consulting the class when an event transition occurs and for
  managing acknowledgment state (`acked_transitions` lives on the event source,
  not here).

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `notification_class`: Unique per class; used by event sources to reference
    which class handles their notifications.

  - `priority`: Per-transition (to-offnormal, to-fault, to-normal) priorities
    for the notifications.

  - `ack_required`: Which transitions require acknowledge by an operator (device).

  - `recipient_list`: Who gets notified (with filters for transitions, days, times, etc).
    Your notification router, when an event occurs for a source
    referencing this class, must evaluate the `recipient_list` (considering current
    time) and send the notifications (confirmed or unconfirmed) to the
    matching recipients. This is the "live" delivery list.

  The object is pure config for the notification engine. The engine (part of your
  server) is responsible for consulting it on event transitions and delivering.
  `acked_transitions` live on the event source objects (Enrollment or intrinsic
  sources), not here.

  ### Examples

  Creating a Notification Class:

      iex> {:ok, nc} = BACnet.Protocol.ObjectTypes.NotificationClass.create(700, "Alarms", %{notification_class: 700}); nc.object_name
      "Alarms"

  ### See Also
  - `BACnet.Protocol.Destination`
  - `BACnet.Protocol.EventTransitionBits`
  - `BACnet.Protocol.NotificationClassPriority`
  """

  alias BACnet.Protocol.Constants
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
  Represents a Notification Class object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
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

    field(:profile_name, String.t())
  end
end
