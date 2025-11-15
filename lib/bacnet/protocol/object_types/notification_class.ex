defmodule BACnet.Protocol.ObjectTypes.NotificationClass do
  @moduledoc """
  The Notification Class object type defines a standardized object that represents
  and contains information required for the distribution of event notifications
  within BACnet systems. Notification Classes are useful for event-initiating objects
  that have identical needs in terms of how their notifications should be handled,
  what the destination(s) for their notifications should be, and how they should
  be acknowledged. A notification class defines how event notifications shall be
  prioritized in their handling according to TO_OFFNORMAL, TO_FAULT, and TO_NORMAL events;
  whether these categories of events require acknowledgment (nearly always by a
  human operator); and what destination devices or processes should receive notifications.

  The purpose of prioritization is to provide a means to ensure that alarms or event
  notifications with critical time considerations are not unnecessarily delayed.
  The possible range of priorities is 0 - 255. A lower number indicates a higher priority.
  The priority and the Network Priority (Clause 6.2.2) are associated as defined in Table 13-5.

  Priorities may be assigned to TO_OFFNORMAL, TO_FAULT, and TO_NORMAL events
  individually within a notification class. The purpose of acknowledgment is to
  provide assurance that a notification has been acted upon by some other agent,
  rather than simply having been received correctly by another device.
  In most cases, acknowledgments come from human operators.
  TO_OFFNORMAL, TO_FAULT, and TO_NORMAL events may, or may not, require individual
  acknowledgment within a notification class.
  It is often necessary for event notifications to be sent to multiple destinations or
  to different destinations based on the time of day or day of week.

  Notification Classes may specify a list of destinations, each of which is qualified by time
  day of week, and type of handling. A destination specifies a set of days of the week
  (Monday through Sunday) during which the destination is considered viable by
  the Notification Class object. In addition, each destination has a FromTime and ToTime,
  which specify a window using specific times, on those days of the week,
  during which the destination is viable. If an event that uses a Notification Class object
  occurs and the day is one of the days of the week that is valid for a given destination and
  the time is within the window specified in the destination, then the destination shall be
  sent a notification. Destinations may be further qualified, as applicable, by any combination
  of the three event transitions TO_OFFNORMAL, TO_FAULT, or TO_NORMAL.
  The destination also defines the recipient device to receive the notification and a process
  within the device. Processes are identified by numeric handles that are only meaningful to
  the destination device. The administration of these handles is a local matter.
  The recipient device may be specified by either its unique Device Object_Identifier
  or its BACnetAddress. In the latter case, a specific node address, a multicast address,
  or a broadcast address may be used. The destination further specifies whether the notification
  shall be sent using a confirmed or unconfirmed event notification.

  (ASHRAE 135 - Clause 12.21)
  """

  # TODO: Docs

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.Destination
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.NotificationClassPriority
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
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
