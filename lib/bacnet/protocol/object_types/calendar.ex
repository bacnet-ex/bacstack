defmodule BACnet.Protocol.ObjectTypes.Calendar do
  @moduledoc """
  The Calendar object type defines a standardized object used to describe
  a list of calendar dates, which might be thought of as "holidays", "special events",
  or simply as a list of dates.

  (ASHRAE 135 - Clause 12.9)
  """

  # TODO: Docs

  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.Constants

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Calendar object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :calendar) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:date_list, [CalendarEntry.t()], required: true, default: [])
    field(:present_value, boolean(), required: true, default: false)
    field(:profile_name, String.t())
  end
end
